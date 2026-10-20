import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
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
            const _Bandeau(),
            GroupeRetractable(
              cle: 'accueil/comment',
              titre: 'Comment ça marche',
              icone: Icons.lightbulb_outline,
              enfants: const [_Etapes()],
            ),
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
            GroupeRetractable(
              cle: 'accueil/courses',
              titre: 'Courses',
              icone: Icons.shopping_cart_outlined,
              nombre: pretes.length + (enCours == null ? 0 : 1),
              vide: 'Aucune liste prête pour les courses.',
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
                for (final l in pretes)
                  LigneMenu(
                    icone: Icons.shopping_cart_outlined,
                    titre: etat.nomListe(l),
                    sousTitre: 'Prête · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}',
                    onTap: () => partirFaireLesCourses(context, l),
                    droite: BoutonAction('Partir', onTap: () => partirFaireLesCourses(context, l)),
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

/// Bandeau ludique : quelques images du catalogue sur la couleur de la palette, et le bonjour.
class _Bandeau extends StatelessWidget {
  const _Bandeau();

  static const _images = [
    ('fruits-et-legumes', 64.0, 0.0, 6.0, -0.15),
    ('boulangerie', 50.0, 58.0, 58.0, 0.12),
    ('cremerie', 46.0, 6.0, 74.0, -0.08),
    ('fromagerie', 40.0, 112.0, 14.0, 0.2),
    ('poissonnerie', 38.0, 104.0, 70.0, -0.18),
  ];

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return Container(
      height: 130 + haut,
      padding: EdgeInsets.only(top: haut),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Charte.accent, Charte.cadre],
        ),
      ),
      child: Stack(
        children: [
          for (final (cle, taille, droite, hautImage, angle) in _images)
            Positioned(
              right: 12 + droite,
              top: hautImage,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: taille + 10,
                  height: taille + 10,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Charte.blanc, shape: BoxShape.circle),
                  child: Pictogramme(cle, taille: taille),
                ),
              ),
            ),
          Positioned(
            left: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonjour !', style: Charte.texte(30, gras: true, couleur: Charte.blanc)),
                Text('Prêt(e) pour vos courses ?', style: Charte.texte(16, couleur: Charte.blanc)),
              ],
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                    Text(_etapes[i].$2, textAlign: TextAlign.center, style: Charte.texte(13)),
                  ],
                ),
              ),
          ],
        ),
      );
}
