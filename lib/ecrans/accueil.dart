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
                  listeGlissable(context, l, LigneMenu(
                    icone: Icons.checklist,
                    titre: etat.nomListe(l),
                    sousTitre: '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · '
                        '${l.interrompueLe != null ? 'interrompue ${quand(l.interrompueLe!)}' : quandJour(l.modifieeLe ?? l.dateCreation)}',
                    onTap: () => Nav.travail(EcranConstruction(listeId: l.id)),
                    droite: BoutonAction('Reprendre', onTap: () => Nav.travail(EcranConstruction(listeId: l.id))),
                  )),
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
                  listeGlissable(context, l, LigneMenu(
                    icone: Icons.shopping_cart_outlined,
                    titre: etat.nomListe(l),
                    sousTitre: 'Prête · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}',
                    onTap: () => partirFaireLesCourses(context, l),
                    droite: BoutonAction('Faire les courses', onTap: () => partirFaireLesCourses(context, l)),
                  )),
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
                  listeGlissable(context, enCours, interrompue: true, LigneMenu(
                    gauche: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: Avancement(fait: enCours.nbCoches, total: enCours.lignes.length, couleur: Charte.accent)),
                    ),
                    titre: '${etat.nomListe(enCours)} · ${enCours.nbCoches} / ${enCours.lignes.length}',
                    sousTitre: 'Courses interrompues${enCours.interrompueLe != null ? ' ${quand(enCours.interrompueLe!)}' : ''}',
                    onTap: () => Nav.travail(EcranCoursesSecteur(listeId: enCours.id)),
                    droite: BoutonAction('Reprendre', plein: true, onTap: () => Nav.travail(EcranCoursesSecteur(listeId: enCours.id))),
                  )),
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
/// qui déborde jusque sous les cinq étapes. Un appui sur le titre replie les étapes.
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
            // Voile léger (la photo reste claire) ; une ombre portée garde le texte blanc lisible.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0x00000000), Color(0x26000000), Color(0x4D000000)],
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
                        Text('Bonjour !', style: _surPhoto(Charte.texte(30, gras: true, couleur: Charte.blanc))),
                        Text('Prêt(e) pour vos courses ?', style: _surPhoto(Charte.texte(16, couleur: Charte.blanc))),
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
                                style: _surPhoto(Charte.texte(15, gras: true, couleur: Charte.blanc, espacement: 0.8))),
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

/// Texte blanc posé sur la photo : une ombre douce le détache des légumes clairs.
TextStyle _surPhoto(TextStyle s) =>
    s.copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6), Shadow(color: Color(0x99000000), blurRadius: 2)]);

/// « Comment ça marche » : les cinq étapes, numérotées, du paramétrage au ticket.
class _Etapes extends StatelessWidget {
  const _Etapes();

  static const _etapes = [
    (Icons.tune, 'Je\nparamètre'),
    (Icons.checklist, 'Je prépare\nma liste'),
    (Icons.check_circle_outline, 'Je la\nvalide'),
    (Icons.shopping_cart_outlined, 'Je fais\nmes courses'),
    (Icons.receipt_long_outlined, 'Je garde\nle ticket'),
  ];

  // Explication de chaque étape, affichée quand on la touche.
  static const _explications = [
    (
      'Je paramètre',
      [
        'Une fois au début, dans l\'onglet Gérer :',
        '• Mon foyer : les membres qui préparent ou font les courses, avec leur adresse mail pour recevoir les listes.',
        '• Magasins et catalogue : vos magasins. Chacun reçoit le catalogue complet, rayons, secteurs et produits, '
            'que vous pouvez compléter.',
        '• Paramètres : l\'apparence, les types de promotion et de packaging.',
        'Le parcours de chaque magasin n\'est pas à décrire : il s\'apprend pendant vos premières courses.',
      ],
    ),
    (
      'Je prépare ma liste',
      [
        'Touchez « + Nouvelle liste », choisissez le magasin, puis comment commencer :',
        '• Liste type : une de vos listes types, ou la liste complète du magasin, rayon par rayon.',
        '• Liste personnalisée : vous reprenez des articles d\'une de vos dernières courses.',
        '• Liste depuis un mail : vous collez le texte d\'un mail, les articles sont reconnus dans le catalogue.',
        'Ouvrez un rayon, puis un secteur, et touchez les articles voulus pour les cocher. Touchez de nouveau un '
            'article coché pour préciser le packaging, la promotion, la marque ou une consigne.',
        '« Aperçu » montre la liste telle qu\'elle se présentera pendant les courses.',
        'Vous pouvez vous arrêter à tout moment : rien n\'est perdu, la liste reste « En préparation ».',
      ],
    ),
    (
      'Je la valide',
      [
        'Quand la liste est complète, touchez « Liste prête ». Vous pouvez y ajouter un commentaire.',
        'Vous pouvez la mettre en instance de courses, l\'enregistrer comme liste type sous un nom de votre choix '
            'pour la réutiliser, et l\'envoyer par mail.',
        'Une liste prête peut encore être remise en préparation.',
      ],
    ),
    (
      'Je fais mes courses',
      [
        'Au magasin, touchez « Faire les courses » : indiquez qui fait les courses et le parcours.',
        'Les articles sont rangés dans l\'ordre de votre parcours, secteur par secteur. Touchez un article pour le cocher.',
        'Avec « Enregistrer le parcours », l\'ordre dans lequel vous cochez apprend à l\'application le parcours de ce magasin.',
        'Une pause interrompt les courses ; vous les reprenez plus tard là où vous en étiez.',
      ],
    ),
    (
      'Je garde le ticket',
      [
        'À la fin, touchez « Terminer les courses ».',
        'La course attend son ticket de caisse dans l\'onglet Courses (« Terminées sans ticket ») : joignez le PDF '
            'fourni par l\'application du magasin.',
        'Avec son ticket, la course rejoint l\'historique (Gérer › Historique). Ces courses passées servent ensuite '
            'à préparer les prochaines listes.',
      ],
    ),
  ];

  static Future<void> _expliquer(BuildContext context, int i) => modale(
        context,
        titre: '${i + 1}. ${_explications[i].$1}',
        icone: _etapes[i].$1,
        oui: null,
        non: null,
        contenu: (context, maj) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in _explications[i].$2)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: Charte.texte(16))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _etapes.length; i++) Expanded(child: _etape(context, i)),
          ],
        ),
      );

  /// Une étape : un appui ouvre son explication.
  Widget _etape(BuildContext context, int i) => Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _expliquer(context, i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                Text(_etapes[i].$2, textAlign: TextAlign.center, style: _surPhoto(Charte.texte(13, gras: true, couleur: Charte.blanc))),
              ],
            ),
          ),
        ),
      );
}
