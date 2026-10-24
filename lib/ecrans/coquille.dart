// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'accueil.dart';
import 'archives.dart';
import 'corbeille.dart';
import 'e13_produits_reels.dart';
import 'historique.dart';
import 'listes.dart';
import 'magasin.dart';
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
    return ListenableBuilder(
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
    Widget entree(int r, IconData icone, String titre, String sousTitre) => LigneMenu(
          icone: icone,
          titre: titre,
          sousTitre: sousTitre,
          onTap: () {
            if (r == Nav.magasin) Nav.i.choixMagasin = true;
            Nav.i.ouvrirRubrique(r);
          },
        );
    return PageBase(
      entete: const EnTeteFenetre(icone: Icons.tune, titre: 'Gérer', aide: Aides.gerer),
      corps: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          GroupeRetractable(cle: 'gerer/foyer', titre: 'Mon foyer', icone: Icons.home_outlined, enfants: [
            ecran(Icons.home_outlined, 'Foyer', '${etat.foyerNom} · repartir d\'un foyer neuf', const EcranFoyer()),
            ecran(Icons.group_outlined, 'Membres', '${etat.membres.length} membre${etat.membres.length > 1 ? 's' : ''} · adresses mail',
                const EcranMembres()),
          ]),
          GroupeRetractable(cle: 'gerer/magasins', titre: 'Magasins', icone: Icons.storefront_outlined, enfants: [
            entree(Nav.magasin, Icons.storefront_outlined, 'Magasins et catalogue', '$n magasin${n > 1 ? 's' : ''} · rayons, secteurs, produits'),
            entree(Nav.parcours, Icons.route_outlined, 'Parcours', 'Appris pendant les courses, pour chacun dans chaque magasin'),
            ecran(Icons.checklist, 'Listes', 'Types de promotion, types de packaging, préliste', const EcranReglagesListes()),
            ecran(Icons.science_outlined, 'Produits réels', 'Essai Open Food Facts : catalogue de vrais produits', const EcranProduitsReels()),
          ]),
          GroupeRetractable(cle: 'gerer/parametres', titre: 'Paramètres', icone: Icons.settings_outlined, enfants: [
            ecran(Icons.palette_outlined, 'Apparence', 'Couleurs de l\'application', const EcranApparence()),
            ecran(Icons.storage_outlined, 'Données', 'Listes exemples, suppression automatique des archives', const EcranDonnees()),
            ecran(Icons.sync, 'MQTT', 'Configuration du partage entre appareils', const EcranPartage()),
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
  Widget build(BuildContext context) {
    if (rubrique == Nav.parametres) return const EcranDonnees();
    if (rubrique == Nav.foyer) return const EcranFoyer();
    if (rubrique == Nav.archives) return const EcranArchives();
    if (rubrique == Nav.corbeille) return const EcranCorbeille();
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.i, Etat.instance]),
      builder: (context, _) {
        final sous = Nav.i.sousOnglet[rubrique] ?? 0;
        late final String titre;
        var aide = Aides.magasins;
        List<SousOnglet>? onglets;
        late final Widget contenu;
        Widget? droite;
        switch (rubrique) {
          case Nav.parcours:
            titre = 'Parcours';
            aide = Aides.parcours;
            contenu = SousEcranParcours();
          case Nav.historique:
            titre = 'Historique';
            aide = Aides.historique;
            contenu = const SousEcranHistorique();
          default:
            titre = 'Magasins';
            if (Nav.i.choixMagasin) {
              contenu = const SousEcranListeMagasins();
              break;
            }
            droite = const SelecteurMagasin();
            onglets = const [
              SousOnglet('Rayons', Icons.view_agenda_outlined),
              SousOnglet('Secteurs', Icons.grid_view),
              SousOnglet('Produits', Icons.inventory_2_outlined),
            ];
            contenu = switch (sous) {
              Nav.secteurs => SousEcranSecteurs(),
              Nav.produits => SousEcranProduits(),
              _ => SousEcranRayons(),
            };
        }
        return PageBase(
          entete: EnTeteFenetre(retour: true, icone: Icons.tune, sousTitre: 'Gérer', titre: titre, droite: droite, aide: aide),
          haut: [if (onglets != null) SousOnglets(onglets: onglets, actif: sous, onChoix: Nav.i.allerSous)],
          corps: contenu,
        );
      },
    );
  }
}
