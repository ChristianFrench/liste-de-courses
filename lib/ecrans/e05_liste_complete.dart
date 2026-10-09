import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e06_courses_secteur.dart';

/// Écran 5 — Liste complète, groupée par secteur dans l'ordre du parcours.
class EcranListeComplete extends StatelessWidget {
  const EcranListeComplete({super.key, required this.listeId, this.depuisCourses = false});
  final String listeId;

  /// Vrai si l'écran a été ouvert depuis « Courses par secteur » (retour simple).
  final bool depuisCourses;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(listeId);
        if (l == null) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Liste'),
            corps: Center(child: Text("Cette liste n'existe plus.", style: Charte.texte(16))),
          );
        }
        final c = etat.courses?.listeId == l.id ? etat.courses : null;
        final membreId = c?.membreId ?? etat.moi.id;
        final parcoursId =
            c != null ? c.parcoursId : (l.parcoursId ?? etat.parcoursParDefaut(l.magasinId, membreId)?.id);
        final p = etat.unParcours(parcoursId);
        final etapes = etat.etapes(l, parcoursId);
        final nbSecteurs = etapes.where((e) => !e.nonPlace).length;
        final n = l.lignes.length;

        String texteBouton;
        if (c == null) {
          texteBouton = 'Commencer · secteur 1';
        } else if (c.coches.isEmpty && c.etape == 0) {
          texteBouton = 'Commencer · secteur 1';
        } else {
          texteBouton = 'Reprendre les courses';
        }

        var numero = 0;
        return PageBase(
          entete: EnTeteTravail(titre: '${etat.magasin(l.magasinId)?.nom ?? ''} · $n article${n > 1 ? 's' : ''}'),
          haut: [
            Container(
              color: Charte.fondBandeau,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '${p == null ? 'Ordre des rayons du magasin' : 'Parcours « ${p.nom} »'} · '
                '${etat.membre(membreId)?.nomAffiche ?? ''} · $nbSecteurs secteur${nbSecteurs > 1 ? 's' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
            ),
          ],
          corps: n == 0
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('La liste est vide.', style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : ListView(
                  children: [
                    for (final e in etapes) ...[
                      TitreGroupe(
                        nom: e.nonPlace ? 'Non placé' : e.secteur!.nom,
                        numero: e.nonPlace ? null : '${++numero}',
                        nonPlace: e.nonPlace,
                      ),
                      for (final g in e.lignes) _ligne(etat, l, g, c),
                    ],
                  ],
                ),
          bas: [
            BarreAction(boutons: [
              Bouton(
                texte: texteBouton,
                plein: true,
                onTap: n == 0
                    ? null
                    : () {
                        if (depuisCourses) {
                          Navigator.of(context).pop();
                          return;
                        }
                        if (c == null) etat.demarrerCourses(l, membreId, parcoursId);
                        Nav.remplacer(context, const EcranCoursesSecteur());
                      },
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _ligne(Etat etat, Liste l, LigneListe g, CoursesEnCours? c) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    final promo = etat.promotion(g.promotionId) ?? etat.promotionActive(l.magasinId, p.id);
    return LigneCompacte(
      nom: p.nom,
      complement: etat.complement(g, p),
      quantite: g.quantite,
      promo: promo?.type,
      coche: c?.coches.contains(p.id) ?? false,
    );
  }
}
