import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'listes.dart';
import 'travail.dart';

// Onglet Accueil : un bandeau ludique, « Comment ça marche », puis ce qui est en cours
// (préparations et courses) avec son action directe.

class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final enPreparation = etat.listesStatut(StatutListe.enConstruction);
    final enCours = etat.coursesEnCours;
    final pretes = etat.listesStatut(StatutListe.prete);
    return Scaffold(
      backgroundColor: Charte.fond,
      body: AvecDecision(
        boutons: [Bouton(texte: '+ Nouvelle liste', plein: true, taille: 18, onTap: () => Nav.travail(const EcranPreliste()))],
        contenu: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _EnTetePhoto(),
            GroupeRetractable(
              cle: 'accueil/preparation',
              titre: 'En préparation',
              icone: Icons.checklist,
              nombre: enPreparation.length,
              vide: 'Aucune liste en préparation.',
              enfants: [
                for (final l in enPreparation)
                  LigneMenu(
                    icone: Icons.checklist,
                    titre: etat.nomListe(l),
                    sousTitre: '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · '
                        '${l.interrompueLe != null ? 'interrompue ${quand(l.interrompueLe!)}' : quandJour(l.modifieeLe ?? l.dateCreation)}',
                    onTap: () => Nav.travail(EcranConstruction(listeId: l.id)),
                    droite: BoutonAction('Reprendre', onTap: () => Nav.travail(EcranConstruction(listeId: l.id))),
                  ),
              ],
            ),
            // Listes prêtes : en instance de courses, avec de quoi partir les faire.
            GroupeRetractable(
              cle: 'accueil/instance',
              titre: 'En instance de courses',
              icone: Icons.shopping_cart_outlined,
              nombre: pretes.length,
              vide: 'Aucune liste prête pour les courses.',
              enfants: [
                for (final l in pretes)
                  LigneMenu(
                    icone: Icons.shopping_cart_outlined,
                    titre: etat.nomListe(l),
                    sousTitre: 'Prête · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}',
                    onTap: () => partirFaireLesCourses(context, l),
                    droite: BoutonAction('Faire les courses', onTap: () => partirFaireLesCourses(context, l)),
                  ),
              ],
            ),
            GroupeRetractable(
              cle: 'accueil/courses',
              titre: 'Courses en cours',
              icone: Icons.pause_circle_outline,
              nombre: enCours == null ? 0 : 1,
              vide: 'Aucune course en cours.',
              enfants: [
                if (enCours != null)
                  LigneMenu(
                    gauche: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: Avancement(fait: enCours.nbCoches, total: enCours.lignes.length, couleur: Charte.accent)),
                    ),
                    titre: '${etat.nomListe(enCours)} · ${enCours.nbCoches} / ${enCours.lignes.length}',
                    sousTitre: 'Courses interrompues${enCours.interrompueLe != null ? ' ${quand(enCours.interrompueLe!)}' : ''}',
                    onTap: () => Nav.travail(EcranCoursesSecteur(listeId: enCours.id)),
                    droite: BoutonAction('Reprendre', plein: true, onTap: () => Nav.travail(EcranCoursesSecteur(listeId: enCours.id))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// En-tête : la photo de légumes, le bonjour, puis « Comment ça marche » posé sur la même photo,
/// qui déborde jusque sous les quatre étapes. Un appui sur le titre replie les étapes.
class _EnTetePhoto extends StatelessWidget {
  const _EnTetePhoto();

  static const _cle = 'accueil/comment';

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: Retractables.i,
      builder: (context, _) {
        final ouvert = Retractables.i.ouvert(_cle);
        return Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/accueil_photo.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter)),
            // Voile : lisibilité du texte blanc, plus sombre en bas sous les étapes.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x22000000), Color(0x8C000000), Color(0xB3000000)],
                    stops: [0, 0.3, 0.6, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: haut),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 40, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour !', style: Charte.texte(30, gras: true, couleur: Charte.blanc)),
                        Text('Prêt(e) pour vos courses ?', style: Charte.texte(16, couleur: Charte.blanc)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Retractables.i.basculer(_cle),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x55FFFFFF)))),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: Charte.blanc, shape: BoxShape.circle),
                            child: Icon(Icons.lightbulb_outline, size: 19, color: Charte.cadre),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('COMMENT ÇA MARCHE',
                                style: Charte.texte(15, gras: true, couleur: Charte.blanc, espacement: 0.8)),
                          ),
                          Icon(ouvert ? Icons.expand_less : Icons.expand_more, size: 30, color: Charte.blanc),
                        ],
                      ),
                    ),
                  ),
                  if (ouvert) const _Etapes(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// « Comment ça marche » : les quatre étapes, numérotées.
class _Etapes extends StatelessWidget {
  const _Etapes();

  static const _etapes = [
    (Icons.checklist, 'Je prépare\nma liste'),
    (Icons.check_circle_outline, 'Je la\nvalide'),
    (Icons.shopping_cart_outlined, 'Je fais\nmes courses'),
    (Icons.receipt_long_outlined, 'Je garde\nle ticket'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _etapes.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconeRonde(_etapes[i].$1),
                        Positioned(
                          left: -4,
                          top: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Charte.accent, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: Charte.texte(12, gras: true, couleur: Charte.blanc)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_etapes[i].$2, textAlign: TextAlign.center, style: Charte.texte(13, gras: true, couleur: Charte.blanc)),
                  ],
                ),
              ),
          ],
        ),
      );
}
