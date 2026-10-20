import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';

// Gérer › Archives : les courses des magasins supprimés, par magasin. Chaque course ou tout
// un magasin peut être supprimé ; un magasin peut aussi revenir parmi les magasins actifs.

class EcranArchives extends StatelessWidget {
  const EcranArchives({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Gérer', titre: 'Archives'),
        corps: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            if (etat.magasinsArchives.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                    'Aucune archive. Quand vous supprimez un magasin qui a un historique de courses, ses courses arrivent ici.',
                    style: Charte.texte(15, couleur: Charte.texteSecondaire)),
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
              etat.delaiArchives == 0
                  ? 'Les archives sont gardées sans limite (réglage dans Paramètres).'
                  : 'Les archives de plus de ${etat.delaiArchives} mois sont supprimées automatiquement (réglage dans Paramètres).',
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

  Widget _ligne(BuildContext context, String texte, bool pj, VoidCallback? supprimer) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
        child: Row(
          children: [
            Expanded(child: Text(texte, style: Charte.texte(15))),
            if (pj) const Etiquette('PJ', icone: Icons.attach_file),
            if (supprimer != null)
              IconButton(
                tooltip: 'Supprimer',
                icon: Icon(Icons.delete_outline, color: Charte.couleurIcone(Icons.delete_outline)),
                onPressed: supprimer,
              ),
          ],
        ),
      );
}
