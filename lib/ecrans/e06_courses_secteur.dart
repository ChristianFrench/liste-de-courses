import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e05_liste_complete.dart';
import 'e12_historique.dart';

/// Écran 6 — Courses par secteur, dans l'ordre du parcours.
class EcranCoursesSecteur extends StatelessWidget {
  const EcranCoursesSecteur({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final c = etat.courses;
        final l = etat.listeEnCours;
        if (c == null || l == null) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Courses'),
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Pas de courses en cours. Choisissez une liste depuis « Je fais les courses ».",
                  style: Charte.texte(16, couleur: Charte.texteSecondaire)),
            ),
          );
        }
        final etapes = etat.etapes(l, c.parcoursId);
        if (etapes.isEmpty) {
          return PageBase(
            entete: EnTeteTravail(titre: 'Courses · ${etat.magasin(l.magasinId)?.nom ?? ''}'),
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('La liste est vide.', style: Charte.texte(16, couleur: Charte.texteSecondaire)),
            ),
            bas: [
              BarreAction(boutons: [
                Bouton(texte: 'Terminer les courses', plein: true, onTap: () => _terminer(context, etat, l, c)),
              ]),
            ],
          );
        }
        if (c.etape >= etapes.length) c.etape = etapes.length - 1;
        final i = c.etape;
        final e = etapes[i];
        final total = l.lignes.length;
        final faits = l.lignes.where((g) => c.coches.contains(g.produitId)).length;
        final cochesSecteur = e.lignes.where((g) => c.coches.contains(g.produitId)).length;
        final secteurTermine = cochesSecteur == e.lignes.length;
        bool termine(Etape x) => x.lignes.every((g) => c.coches.contains(g.produitId));
        String nomEtape(int k) => etapes[k].nonPlace ? 'Non placé' : etapes[k].secteur!.nom;

        return PageBase(
          entete: EnTeteTravail(
            titre: 'Courses · ${etat.magasin(l.magasinId)?.nom ?? ''}',
            gauche: BoutonIcone(
              icone: Icons.format_list_bulleted,
              libelle: 'Liste complète',
              onTap: () => Nav.aller(context, EcranListeComplete(listeId: l.id, depuisCourses: true)),
            ),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BoutonIcone(
                  icone: Icons.alt_route,
                  libelle: 'Changer de parcours',
                  taille: 22,
                  onTap: () => _changerParcours(context, etat, l, c),
                ),
                Text('$faits / $total', style: Charte.texte(17, gras: true)),
              ],
            ),
          ),
          haut: [
            if (etat.horsReseau) const BandeauHorsReseau(),
            BandeauPuces(
              pastille: false,
              puces: [
                for (var k = 0; k < etapes.length; k++)
                  Puce(
                    etapes[k].nonPlace ? '? Non placé' : '${k + 1} ${nomEtape(k)}',
                    termine: termine(etapes[k]),
                  ),
              ],
              selection: i,
              onChoix: etat.allerEtape,
            ),
            Container(
              height: 32,
              color: Charte.fondSelection,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: nomEtape(i), style: Charte.texte(14, gras: true)),
                        if (!e.nonPlace)
                          TextSpan(
                            text: ' · rayon ${etat.rayon(e.secteur!.rayonId)?.nom ?? ''}',
                            style: Charte.texte(14),
                          ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$cochesSecteur / ${e.lignes.length} coché${cochesSecteur > 1 ? 's' : ''}',
                      style: Charte.texte(14)),
                ],
              ),
            ),
          ],
          corps: ListView(
            children: [
              for (final g in e.lignes) _ligne(etat, l, g, c),
              if (secteurTermine)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20, color: Charte.encre),
                      const SizedBox(width: 8),
                      Text(
                        i < etapes.length - 1 ? 'Secteur terminé' : 'Tout est coché',
                        style: Charte.texte(15, gras: true),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          bas: [
            BarreAction(boutons: [
              if (i > 0)
                Bouton(texte: '◀ ${nomEtape(i - 1)}', taille: 16, onTap: () => etat.allerEtape(i - 1))
              else
                const Bouton(texte: '◀', onTap: null),
              if (i < etapes.length - 1)
                Bouton(
                  texte: '${nomEtape(i + 1)} ▶',
                  taille: secteurTermine ? 17 : 16,
                  plein: true,
                  onTap: () => etat.allerEtape(i + 1),
                )
              else
                Bouton(
                  texte: 'Terminer les courses',
                  taille: 16,
                  plein: true,
                  onTap: () => _terminer(context, etat, l, c),
                ),
            ]),
          ],
        );
      },
    );
  }

  Widget _ligne(Etat etat, Liste l, LigneListe g, CoursesEnCours c) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    final promo = etat.promotion(g.promotionId) ?? etat.promotionActive(l.magasinId, p.id);
    return LigneCourse(
      key: ValueKey(p.id),
      nom: p.nom,
      complement: etat.complement(g, p),
      coche: c.coches.contains(p.id),
      quantite: g.quantite,
      promo: promo?.type,
      alerte: etat.quantiteInsuffisante(l, g),
      onTap: () => etat.cocher(p.id),
    );
  }

  Future<void> _changerParcours(BuildContext context, Etat etat, Liste l, CoursesEnCours c) async {
    final choix = <String, String>{
      for (final p in etat.parcoursDe(l.magasinId, c.membreId)) p.id: p.parDefaut ? '${p.nom} (par défaut)' : p.nom,
      '': 'Ordre des rayons du magasin',
    };
    final v = await choisirDansListe<String>(context, titre: 'Parcours', choix: choix);
    if (v == null) return;
    etat.changerParcours(v.isEmpty ? null : v);
  }

  Future<void> _terminer(BuildContext context, Etat etat, Liste l, CoursesEnCours c) async {
    final reste = l.lignes.where((g) => !c.coches.contains(g.produitId)).length;
    if (reste > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Charte.fond,
          title: Text('Terminer les courses ?', style: Charte.texte(18, gras: true)),
          content: Text(
            'Il reste $reste article${reste > 1 ? 's' : ''} non coché${reste > 1 ? 's' : ''}.',
            style: Charte.texte(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Continuer', style: Charte.texte(16)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Terminer', style: Charte.texte(16, gras: true)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    etat.terminerCourses();
    if (!context.mounted) return;
    Nav.depuisAccueil(context, const EcranHistorique());
  }
}
