import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';

// Courses › Archives : les courses passées de l'historique (d'elles-mêmes après quelques mois, ou à la main),
// qui peuvent y revenir, et celles des magasins supprimés, par magasin. Chaque course ou tout un magasin peut
// être supprimé ; un magasin peut aussi revenir parmi les magasins actifs.

class EcranArchives extends StatelessWidget {
  const EcranArchives({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteFenetre(retour: true, sousTitre: 'Courses', titre: 'Archives'),
        corps: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            if (etat.magasinsArchives.isEmpty && etat.coursesArchivees.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                    'Aucune archive. Les courses de l\'historique arrivent ici après quelques mois, ainsi que celles '
                    'd\'un magasin supprimé.',
                    style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              ),
            if (etat.coursesArchivees.isNotEmpty)
              GroupeRetractable(
                cle: 'archives/historique',
                titre: 'Courses de l\'historique',
                icone: Icons.history,
                nombre: etat.coursesArchivees.length,
                enfants: [
                  for (final c in etat.coursesArchivees)
                    LigneMenu(
                      icone: Icons.receipt_long_outlined,
                      titre: '${jjmmaaaa(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
                      sousTitre: '${etat.nomCourse(c)} · ${c.nbArticles} articles${etat.ticketDe(c.id) != null ? ' · ticket joint' : ''}',
                      droite: Lien('Remettre en historique', onTap: () {
                        etat.remettreEnHistorique(c);
                        Nav.message(context, 'La course est de nouveau dans l\'historique');
                      }),
                    ),
                ],
              ),
            for (final m in etat.magasinsArchives)
              GroupeRetractable(
                cle: 'archives/${m.id}',
                titre: m.nom,
                icone: Icons.inventory_2_outlined,
                enfants: [
              for (final l in etat.listesArchivees(m.id)) _course(context, etat, l),
              for (final c in etat.historique.where((c) => c.magasinId == m.id && etat.liste(c.id) == null))
                _ligne(context, '${jjmmaaaa(c.dateCourses)} · ${c.nbArticles} articles', etat.ticketDe(c.id) != null, null),
              Row(
                children: [
                  Expanded(
                    child: Bouton(
                      texte: 'Rétablir le magasin',
                      taille: 15,
                      onTap: () {
                        etat.restaurerMagasin(m);
                        Nav.message(context, '${m.nom} est de nouveau dans vos magasins');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Bouton(
                      texte: 'Tout supprimer',
                      taille: 15,
                      onTap: () => demanderSuppression(context, m, 'les archives de ${m.nom}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
                ],
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
              '${etat.delaiHistorique == 0 ? 'Les courses restent dans l\'historique' : 'Les courses de plus de ${etat.delaiHistorique} mois passent de l\'historique aux archives'}'
              ' ; ${etat.delaiArchives == 0 ? 'les archives sont gardées sans limite' : 'les archives de plus de ${etat.delaiArchives} mois sont supprimées'}'
              ' (réglages dans Gérer › Paramètres › Données).',
              style: Charte.texte(13, couleur: Charte.texteSecondaire),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _course(BuildContext context, Etat etat, Liste l) => _ligne(
        context,
        '${jjmmaaaa(etat.dateCourses(l))} · ${etat.nomListe(l)} · ${l.lignes.length} articles',
        etat.ticketDe(l.id) != null,
        () => demanderSuppression(context, l, 'la course du ${jjmm(etat.dateCourses(l))}'),
      );

  /// Glisser vers la gauche (ou appui long) pour supprimer.
  Widget _ligne(BuildContext context, String texte, bool pj, VoidCallback? supprimer) {
    final ligne = LigneMenu(
      icone: Icons.receipt_long_outlined,
      titre: texte,
      sousTitre: pj ? 'ticket' : null,
    );
    if (supprimer == null) return ligne;
    final a = ActionLigne(Icons.delete_outline, 'Supprimer', supprimer, danger: true);
    return Glissable(key: ValueKey('glisser-$texte'), titre: texte, versGauche: a, actions: [a], child: ligne);
  }
}
