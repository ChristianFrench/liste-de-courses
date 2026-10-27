// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';
import 'accueil.dart';
import 'archives.dart';
import 'bienvenue.dart';
import 'catalogue.dart';
import 'corbeille.dart';
import 'editeur_catalogue.dart';
import 'foyer.dart';
import 'historique.dart';
import 'listes.dart';
import 'parametres.dart';
import 'partage.dart';

/// Barre d'onglets (64) : 3 entrées icône 22 + libellé ; onglet actif = pastille 56 × 30 pleine.
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.actif, required this.onChoix});
  final int actif;
  final ValueChanged<int> onChoix;

  static const entrees = <(IconData, String)>[
    (Icons.home_outlined, 'Accueil'),
    (Icons.checklist, 'Préparer'),
    (Icons.shopping_cart_outlined, 'Courses'),
    (Icons.tune, 'Gérer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.barreOnglets + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Charte.fondBandeau,
        border: Border(top: BorderSide(color: Charte.separateurZone, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entrees.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == actif,
                label: entrees[i].$2,
                child: InkWell(
                  onTap: () => onChoix(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(
                          color: i == actif ? Charte.accent : null,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(entrees[i].$1, size: 24, color: i == actif ? Charte.blanc : Charte.cadre),
                      ),
                      const SizedBox(height: 2),
                      Text(entrees[i].$2, style: Charte.texte(Charte.tNavigation, gras: i == actif)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les trois onglets, chacun avec sa pile d'écrans.
class Coquille extends StatelessWidget {
  const Coquille({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Nav.i;
    // Premier lancement (ou partage interrompu) : seul ou en foyer ?
    return ListenableBuilder(
      listenable: Synchro.instance,
      builder: (context, coquille) {
        final s = Synchro.instance;
        return s.mode.isEmpty || (s.suspendu != null && !s.actif) ? const EcranBienvenue() : coquille!;
      },
      child: GuetteurQuiSuisJe(child: GuetteurNouveautes(child: ListenableBuilder(
      listenable: nav,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (aFerme, _) {
          if (!aFerme) nav.retour();
        },
        child: Scaffold(
          backgroundColor: Charte.fond,
          body: IndexedStack(
            index: nav.onglet,
            children: [
              for (var o = 0; o < Nav.nbOnglets; o++)
                Navigator(
                  key: nav.piles[o],
                  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => RacineOnglet(onglet: o)),
                ),
            ],
          ),
          bottomNavigationBar: BarreOnglets(actif: nav.onglet, onChoix: (o) => nav.allerOnglet(o)),
        ),
      ),
      ))),
    );
  }
}

/// Écran racine d'un onglet : Préparer, Courses, ou le menu de Gérer.
class RacineOnglet extends StatelessWidget {
  const RacineOnglet({super.key, required this.onglet});
  final int onglet;

  @override
  Widget build(BuildContext context) {
    Nav.ecranRubrique ??= (r) => EcranRubrique(rubrique: r);
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.i, Etat.instance]),
      builder: (context, _) => switch (onglet) {
        // Contenus recréés à chaque changement de données (pas de « const ») pour qu'ils se redessinent.
        Nav.accueil => EcranAccueil(),
        Nav.preparer => PageBase(
            entete: const EnTeteFenetre(icone: Icons.checklist, titre: 'Préparer', aide: Aides.preparer),
            corps: SousEcranPreparer(),
          ),
        Nav.courses => PageBase(entete: const EnTeteFenetre(icone: Icons.shopping_cart_outlined, titre: 'Courses', aide: Aides.courses), corps: SousEcranCourses()),
        _ => const MenuGerer(),
      },
    );
  }
}

/// Onglet Gérer : tout ce qui n'est ni la préparation ni les courses.
class MenuGerer extends StatelessWidget {
  const MenuGerer({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final n = etat.magasins.length;
    Widget ecran(IconData icone, String titre, String sousTitre, Widget e) =>
        LigneMenu(icone: icone, titre: titre, sousTitre: sousTitre, onTap: () => Nav.aller<void>(context, e));
    return PageBase(
      entete: const EnTeteFenetre(icone: Icons.tune, titre: 'Gérer', aide: Aides.gerer),
      corps: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          GroupeRetractable(cle: 'gerer/foyer', titre: 'Mon foyer', icone: Icons.home_outlined, enfants: [
            ecran(Icons.home_outlined, 'Foyer',
                '${etat.foyerNom} · ${etat.membresVisibles.length} membre${etat.membresVisibles.length > 1 ? 's' : ''}', const EcranFoyer()),
          ]),
          GroupeRetractable(cle: 'gerer/courses', titre: 'Courses', icone: Icons.shopping_cart_outlined, enfants: [
            ecran(Icons.storefront_outlined, 'Magasins', '$n magasin${n > 1 ? 's' : ''} · leurs parcours', const EcranMagasins()),
            if (CatalogueCommun.instance.editeur)
              ecran(Icons.public, 'Catalogue commun', 'Éditeur : modifier et publier pour tous les foyers', const EcranEditeurCatalogue()),
            ecran(Icons.menu_book_outlined, 'Catalogue',
                '${etat.produits.length} produits · le même dans tous les magasins', const EcranCatalogue()),
            ecran(Icons.local_offer_outlined, 'Types de promotion', '${etat.typesPromotion.length} types · chacun avec sa couleur',
                const EcranTypesPromotion()),
            ecran(Icons.scale_outlined, 'Types de mesure', '${etat.typesMesure.length} mesures : poids, volume, à la pièce',
                const EcranTypesPackaging(lots: false)),
            ecran(Icons.inventory_2_outlined, 'Types de packaging', '${etat.typesLot.length} packagings : lots de 2 à 10…',
                const EcranTypesPackaging()),
            ecran(Icons.sell_outlined, 'Marques', '${etat.marques.length} marque${etat.marques.length > 1 ? 's' : ''} · leurs produits',
                const EcranMarques()),
          ]),
          GroupeRetractable(cle: 'gerer/parametres', titre: 'Paramètres', icone: Icons.settings_outlined, enfants: [
            ecran(Icons.palette_outlined, 'Apparence', 'Couleurs de l\'application', const EcranApparence()),
            ecran(Icons.storage_outlined, 'Données', 'Listes exemples, préliste, suppression des archives', const EcranDonnees()),
            ecran(Icons.delete_outline, 'Corbeille', '${etat.corbeille.length} élément${etat.corbeille.length > 1 ? 's' : ''}',
                const EcranCorbeille()),
            if (Synchro.instance.mode != 'seul')
              ecran(Icons.sync, 'Synchronisation', 'État des échanges entre les appareils du foyer', const EcranPartage()),
          ]),
        ],
      ),
    );
  }
}

/// Rubrique de Gérer, ouverte au-dessus du menu : en-tête avec retour, sous-onglets éventuels.
class EcranRubrique extends StatelessWidget {
  const EcranRubrique({super.key, required this.rubrique});
  final int rubrique;

  @override
  Widget build(BuildContext context) => switch (rubrique) {
        Nav.parametres => const EcranDonnees(),
        Nav.foyer => const EcranFoyer(),
        Nav.archives => const EcranArchives(),
        Nav.corbeille => const EcranCorbeille(),
        Nav.historique => PageBase(
            entete: const EnTeteFenetre(retour: true, icone: Icons.tune, sousTitre: 'Gérer', titre: 'Historique', aide: Aides.historique),
            corps: const SousEcranHistorique(),
          ),
        _ => const EcranMagasins(),
      };
}
