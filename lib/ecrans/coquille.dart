// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';
import 'historique.dart';
import 'listes.dart';
import 'magasin.dart';
import 'parametres.dart';
import 'travail.dart';

/// Barre d'onglets (64) : 3 entrées icône 22 + libellé ; onglet actif = pastille 56 × 30 pleine.
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.actif, required this.onChoix});
  final int actif;
  final ValueChanged<int> onChoix;

  static const entrees = <(IconData, String)>[
    (Icons.edit_note, 'Préparer'),
    (Icons.shopping_cart_outlined, 'Courses'),
    (Icons.tune, 'Gérer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.barreOnglets + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Charte.fond,
        border: Border(top: BorderSide(color: Charte.encre, width: Charte.traitCadre)),
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
                          color: i == actif ? Charte.encre : null,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(entrees[i].$1, size: 22, color: i == actif ? Charte.fond : Charte.encre),
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
        Nav.preparer => PageBase(
            entete: const EnTeteNiveau(titre: 'Préparer', droite: IndicateurSynchro()),
            corps: SousEcranPreparer(),
          ),
        Nav.courses => PageBase(entete: const EnTeteNiveau(titre: 'Courses'), corps: SousEcranCourses()),
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
    Widget entree(int r, IconData icone, String titre, String sousTitre) => LigneMenu(
          gauche: Icon(icone, size: 28, color: Charte.encre),
          titre: titre,
          sousTitre: sousTitre,
          onTap: () => Nav.i.ouvrirRubrique(r),
        );
    return PageBase(
      entete: const EnTeteNiveau(titre: 'Gérer'),
      corps: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          entree(Nav.magasin, Icons.storefront_outlined, 'Magasins et catalogue',
              '$n magasin${n > 1 ? 's' : ''} · rayons, secteurs, produits'),
          entree(Nav.parcours, Icons.route, 'Parcours', 'Ordre de passage de chacun dans chaque magasin'),
          entree(Nav.historique, Icons.schedule, 'Historique', 'Courses terminées, tickets de caisse'),
          entree(Nav.parametres, Icons.settings_outlined, 'Foyer et paramètres',
              'Membres, préliste, promotions, démonstration'),
          entree(Nav.corbeille, Icons.delete_outline, 'Corbeille', 'Remettre ce qui a été supprimé'),
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
    if (rubrique == Nav.parametres) return const EcranParametres();
    if (rubrique == Nav.corbeille) return const EcranCorbeille();
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.i, Etat.instance]),
      builder: (context, _) {
        final sous = Nav.i.sousOnglet[rubrique] ?? 0;
        late final String titre;
        List<SousOnglet>? onglets;
        late final Widget contenu;
        Widget? droite;
        switch (rubrique) {
          case Nav.parcours:
            titre = 'Parcours';
            contenu = SousEcranParcours();
          case Nav.historique:
            titre = 'Historique';
            onglets = const [
              SousOnglet('Courses effectuées', Icons.shopping_cart_outlined),
              SousOnglet('Tickets de caisse', Icons.receipt_long_outlined),
            ];
            contenu = sous == Nav.tickets ? SousEcranTickets() : SousEcranCoursesEffectuees();
          default:
            titre = 'Magasins';
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
          entete: EnTeteSousNiveau(fil: 'Gérer', titre: titre, droite: droite),
          haut: [if (onglets != null) SousOnglets(onglets: onglets, actif: sous, onChoix: Nav.i.allerSous)],
          corps: contenu,
        );
      },
    );
  }
}

/// Écran 10 — « Reprendre où vous en étiez ? », au lancement.
class EcranRelance extends StatelessWidget {
  const EcranRelance({super.key});

  static void _versOnglets() {
    Nav.i.racine.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const Coquille()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final courses = etat.coursesEnCours;
    final prep = etat.preparationInterrompue;
    return Scaffold(
      backgroundColor: Charte.fond,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/icone_ronde.png', width: 64, height: 64),
                ),
              ),
              const SizedBox(height: 20),
              Text('Reprendre où vous en étiez ?', textAlign: TextAlign.center, style: Charte.texte(24, gras: true)),
              const SizedBox(height: 8),
              Text('Rien n\'a été perdu depuis votre dernière utilisation.',
                  textAlign: TextAlign.center, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              const SizedBox(height: 22),
              if (courses != null) ...[
                _carte(
                  icone: Icons.shopping_cart_outlined,
                  titre: 'Courses en cours · ${etat.magasin(courses.magasinId)?.nom ?? ''}',
                  texte: '${courses.nbCoches} / ${courses.lignes.length} cochés'
                      '${_arret(etat, courses)}'
                      '${courses.interrompueLe != null ? ' · ${quand(courses.interrompueLe!)}' : ''}',
                  bouton: Bouton(
                    texte: 'Reprendre les courses',
                    plein: true,
                    onTap: () {
                      Nav.i.onglet = Nav.courses;
                      _versOnglets();
                      Nav.travail(EcranCoursesSecteur(listeId: courses.id));
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (prep != null)
                _carte(
                  icone: Icons.edit_outlined,
                  titre: 'Liste en préparation · ${etat.magasin(prep.magasinId)?.nom ?? ''}',
                  texte: '${prep.lignes.length} articles'
                      '${etat.secteur(prep.repriseSecteurId) != null ? ' · secteur ${etat.secteur(prep.repriseSecteurId)!.nom}' : ''}'
                      ' · ${quand(prep.interrompueLe!)}',
                  bouton: Bouton(
                    texte: 'Reprendre la préparation',
                    plein: courses == null,
                    onTap: () {
                      _versOnglets();
                      Nav.travail(EcranConstruction(listeId: prep.id));
                    },
                  ),
                ),
              const Spacer(),
              Bouton(texte: 'Aller à l\'accueil', pointille: true, onTap: _versOnglets),
            ],
          ),
        ),
      ),
    );
  }

  static String _arret(Etat etat, Liste l) {
    final e = etat.etapes(l, l.parcoursId).where((x) => x.id == l.repriseSecteurId);
    return e.isEmpty ? '' : ' · arrêt au secteur ${e.first.nom}';
  }

  Widget _carte({required IconData icone, required String titre, required String texte, required Widget bouton}) {
    return Carte(
      chevron: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, size: 22, color: Charte.encre),
              const SizedBox(width: 8),
              Expanded(child: Text(titre, style: Charte.texte(18, gras: true))),
            ],
          ),
          const SizedBox(height: 6),
          Text(texte, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 12),
          bouton,
        ],
      ),
    );
  }
}
