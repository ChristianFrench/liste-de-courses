import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'historique.dart';
import 'listes.dart';
import 'magasin.dart';
import 'parametres.dart';
import 'travail.dart';

/// Barre d'onglets (64) : 4 entrées icône 22 + libellé ; onglet actif = pastille 56 × 30 pleine.
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.actif, required this.onChoix});
  final int actif;
  final ValueChanged<int> onChoix;

  static const entrees = <(IconData, String)>[
    (Icons.checklist, 'Listes'),
    (Icons.schedule, 'Historique'),
    (Icons.storefront_outlined, 'Magasin'),
    (Icons.settings_outlined, 'Paramètres'),
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

/// Les quatre onglets, chacun avec sa pile d'écrans.
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
              for (var o = 0; o < 4; o++)
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

/// Écran racine d'un onglet : en-tête, sous-onglets, contenu du sous-onglet mémorisé.
class RacineOnglet extends StatelessWidget {
  const RacineOnglet({super.key, required this.onglet});
  final int onglet;

  @override
  Widget build(BuildContext context) {
    if (onglet == Nav.parametres) return const EcranParametres();
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.i, Etat.instance]),
      builder: (context, _) {
        final sous = Nav.i.sousOnglet[onglet];
        late final String titre;
        late final List<SousOnglet> onglets;
        late final Widget contenu;
        Widget? droite;
        switch (onglet) {
          case Nav.listes:
            titre = 'Listes';
            droite = const IndicateurSynchro();
            onglets = const [
              SousOnglet('Préparer', Icons.edit_outlined),
              SousOnglet('Parcours', Icons.route),
              SousOnglet('Courses', Icons.shopping_cart_outlined),
            ];
            contenu = switch (sous) {
              Nav.parcours => const SousEcranParcours(),
              Nav.courses => const SousEcranCourses(),
              _ => const SousEcranPreparer(),
            };
          case Nav.historique:
            titre = 'Historique';
            onglets = const [
              SousOnglet('Courses effectuées', Icons.shopping_cart_outlined),
              SousOnglet('Tickets de caisse', Icons.receipt_long_outlined),
            ];
            contenu = sous == Nav.tickets ? const SousEcranTickets() : const SousEcranCoursesEffectuees();
          default:
            titre = 'Magasin';
            droite = const SelecteurMagasin();
            onglets = const [
              SousOnglet('Rayons', Icons.view_agenda_outlined),
              SousOnglet('Secteurs', Icons.grid_view),
              SousOnglet('Produits', Icons.inventory_2_outlined),
            ];
            contenu = switch (sous) {
              Nav.secteurs => const SousEcranSecteurs(),
              Nav.produits => const SousEcranProduits(),
              _ => const SousEcranRayons(),
            };
        }
        return PageBase(
          entete: EnTeteNiveau(titre: titre, droite: droite),
          haut: [SousOnglets(onglets: onglets, actif: sous, onChoix: Nav.i.allerSous)],
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
                      Nav.i.sousOnglet[Nav.listes] = Nav.courses;
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
