import '../composants/icone.dart';
import 'package:flutter/material.dart';

import '../composants/barre_ouverture.dart';
import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../theme.dart';
import 'listes.dart';

// Onglet Accueil : un bandeau ludique, « Comment ça marche », puis ce qui est en cours
// (préparations et courses) avec son action directe.

class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  /// Groupes de l'accueil, pour « Tout replier » / « Tout déplier » du bandeau.
  static List<String> get cles => [
        'accueil/preparation',
        'accueil/instance',
        if (Etat.instance.coursesEnCours != null) 'accueil/courses',
        if (Etat.instance.coursesEnInstance.isNotEmpty) 'accueil/terminees',
      ];

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final enPreparation = etat.listesStatut(StatutListe.enConstruction);
    final enCours = etat.coursesEnCours;
    final pretes = etat.listesStatut(StatutListe.prete);
    final terminees = etat.coursesEnInstance;
    // L'en-tête et la photo restent en haut ; seules les listes défilent.
    // Faire défiler les listes replie « Comment ça marche » pour leur laisser la place.
    // L'accueil n'a pas de bandeau de titre : la photo (version, synchronisation, aide) en tient lieu.
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _EnTetePhoto(),
      Expanded(
        // 02/11/2026 (Aristide) : glisser à gauche ou à droite, même sur la partie vide, passe à l'onglet voisin.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) glisserOnglet(context, v < 0 ? 1 : -1);
          },
          child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GroupeRetractable(
              cle: 'accueil/preparation',
              pliable: true,
              titre: 'En préparation',
              icone: Icons.checklist,
              nombre: enPreparation.length,
              vide: 'Aucune liste en préparation.',
              enfants: [
                for (final l in enPreparation)
                  listeGlissable(
                    context,
                    l,
                    LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.${etat.coursesPrevues(l).isEmpty ? '' : ' · ${etat.coursesPrevues(l)}'}${etat.mentionRectificative(l)}'),
                    detail: '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · '
                        '${l.interrompueLe != null ? 'interrompue ${quand(l.interrompueLe!)}' : quandJour(l.modifieeLe ?? l.dateCreation)}'
                        '${etat.coursesPrevues(l).isEmpty ? '' : ' · ${etat.coursesPrevues(l)}'}',
                  ),
              ],
            ),
            // Listes prêtes : en instance de courses.
            GroupeRetractable(
              cle: 'accueil/instance',
              pliable: true,
              titre: 'À faire',
              emplettes: 'liste_a_faire',
              nombre: pretes.length,
              vide: 'Aucune liste prête pour les courses.',
              enfants: [
                for (final l in pretes)
                  listeGlissable(
                    context,
                    l,
                    LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.${etat.mentionRectificative(l)}'),
                    detail: 'Prête · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}',
                  ),
              ],
            ),
            if (enCours != null)
              GroupeRetractable(
                cle: 'accueil/courses',
              pliable: true,
                titre: 'Courses en cours',
                icone: Icons.pause_circle_outline,
                nombre: 1,
                enfants: [
                  listeGlissable(
                    context,
                    enCours,
                    interrompue: true,
                    LigneMenu(titre: etat.nomListe(enCours), sousTitre: '${enCours.nbCoches} / ${enCours.lignes.length}'),
                    detail: 'Courses interrompues${enCours.interrompueLe != null ? ' ${quand(enCours.interrompueLe!)}' : ''} · '
                        '${enCours.nbCoches} article${enCours.nbCoches > 1 ? 's' : ''} coché${enCours.nbCoches > 1 ? 's' : ''} '
                        'sur ${enCours.lignes.length}',
                  ),
                ],
              ),
            // 09/11/2026 (Aristide) : les courses terminées, comme dans l'onglet Courses.
            if (terminees.isNotEmpty)
              GroupeRetractable(
                cle: 'accueil/terminees',
                pliable: true,
                titre: 'Terminées',
                emplettes: 'liste_terminee',
                nombre: terminees.length,
                enfants: [for (final c in terminees) ligneTerminee(context, c)],
              ),
            const SizedBox(height: 12),
          ],
        ),
        ),
      ),
      ]),
    );
  }
}

/// En-tête : la photo de légumes, le bonjour, puis « Comment ça marche » posé sur la même photo,
/// qui déborde jusque sous les cinq étapes (toujours visibles).
class _EnTetePhoto extends StatelessWidget {
  const _EnTetePhoto();

  // 09/11/2026 : la photo de fond suit le choix d'Apparence, même sur un bandeau déjà construit.
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<String>(valueListenable: Etat.fondChange, builder: (context, _, __) => _construire(context));

  Widget _construire(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return GestureDetector(
          // Comme sur les bandeaux des autres fenêtres : glisser passe à l'onglet voisin.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) glisserOnglet(context, v < 0 ? 1 : -1);
          },
          child: Stack(
          children: [
            Positioned.fill(child: Image.asset(Etat.instance.photoFond, fit: BoxFit.cover, alignment: Alignment.topCenter)),
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
                  // Seuls ajouts au haut de l'accueil : la version, la synchronisation et l'aide.
                  Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text('Version $versionApplication',
                            style: _surPhoto(Charte.texte(12.5, couleur: const Color(0xEEFFFFFF)))),
                      ),
                      const BoutonSynchro(),
                      boutonEnTete(Icons.help_outline, 'Aide', () => montrerAide(context, 'Accueil', Aides.accueil)),
                      const SizedBox(width: 4),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 03/11/2026 (Aristide) : l'image d'Emplettes à la place de « Bonjour ! », le texte à sa droite en plus petit.
                        // Le bas du texte cadré sur le bas de l'image.
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const ImageEmplettes('complet', key: ValueKey('accueil-emplettes'), taille: 96),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(Etat.instance.moi.nomAffiche.trim().isEmpty ? 'Bonjour !' : 'Bonjour ${Etat.instance.moi.nomAffiche.trim()} !',
                                  key: const ValueKey('bonjour'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _surPhoto(Charte.texte(22, gras: true, couleur: Charte.blanc))),
                              Text('Prêt(e) pour vos courses ?', style: _surPhoto(Charte.texte(14, couleur: Charte.blanc))),
                              ]),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // Place toujours réservée : la barre d'ouverture n'agrandit pas la photo (02/11/2026, Aristide).
                  const SizedBox(height: 30, child: BarreOuverture()),
                  // 03/11/2026 (Aristide) : plus de titre « Comment ça marche » ni de trait au-dessus.
                  const _Etapes(),
                ],
              ),
            ),
            // 10/11/2026 (Aristide) : déplier / replier d'un coup tous les groupes, en bas à droite du bandeau.
            Positioned(
              right: 0,
              bottom: 0,
              child: ListenableBuilder(
                listenable: Retractables.i,
                builder: (context, _) {
                  final ferme = Retractables.i.tousFermes(EcranAccueil.cles);
                  return KeyedSubtree(
                      key: const ValueKey('accueil-tout'),
                      child: Tooltip(
                        message: ferme ? 'Tout déplier' : 'Tout replier',
                        child: InkResponse(
                          onTap: () => Retractables.i.tous(EcranAccueil.cles, ferme),
                          radius: 18,
                          // Étroit, collé au coin : ne chevauche pas « Je fais mes courses ».
                          child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icone(ferme ? Icons.unfold_more : Icons.unfold_less,
                                  size: 22, color: Charte.blanc, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)])),
                        ),
                      ));
                },
              ),
            ),
          ],
        ));
  }
}

/// Texte blanc posé sur la photo : une ombre douce le détache des légumes clairs.
TextStyle _surPhoto(TextStyle s) =>
    s.copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6), Shadow(color: Color(0x99000000), blurRadius: 2)]);

/// « Comment ça marche » : les quatre étapes, chacune avec son icône (02/11/2026 : plus d'étape du ticket).
class _Etapes extends StatelessWidget {
  const _Etapes();

  static const _etapes = [
    'Je prépare\nma liste',
    'Je la\nvalide',
    'Je fais\nmes courses',
  ];

  static const _icones = [Icons.checklist, Icons.check_circle_outline, Icons.shopping_cart_outlined];

  // Explication de chaque étape, affichée quand on la touche.
  static const _explications = [
    (
      'Je prépare ma liste',
      [
        'Dans l\'onglet Préparer, touchez « + Nouvelle liste », choisissez le magasin, puis comment commencer :',
        '• Liste type : une de vos listes types, ou la liste complète du magasin, rayon par rayon.',
        '• Mes achats habituels : les articles que vous achetez régulièrement dans ce magasin, à décocher si besoin.',
        '• Liste personnalisée : vous reprenez des articles d\'une de vos dernières courses.',
        '• Liste depuis un texte : vous collez le texte d\'un mail ou d\'un message, les articles sont reconnus dans le catalogue.',
        'Tapez le début du nom d\'un article dans le champ de recherche et touchez-le : il s\'ajoute à la liste, '
            'rangée par secteur dans l\'ordre de votre parcours. − et + règlent la quantité ; touchez la ligne pour '
            'préciser le packaging, la promotion ou une consigne ; un appui long retire l\'article.',
        'La liste a la même présentation que pendant les courses.',
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
        'Les articles sont rangés dans l\'ordre de votre parcours, secteur par secteur. Touchez un article pour le cocher ; '
            'touchez son P ou son packaging pour en voir le détail.',
        'Avec « Enregistrer le parcours », l\'ordre dans lequel vous cochez apprend à l\'application le parcours de ce magasin.',
        'Une pause interrompt les courses ; vous les reprenez plus tard là où vous en étiez.',
        'À la fin, touchez « Terminer les courses ». La course va dans l\'onglet Courses, « Terminées » : joignez-y le PDF '
            'du ticket fourni par l\'application du magasin, puis glissez-la vers la droite pour la mettre dans l\'historique ; '
            'ces courses passées servent ensuite à préparer les prochaines listes.',
      ],
    ),
  ];

  static Future<void> _expliquer(BuildContext context, int i) => modale(
        context,
        titre: _explications[i].$1,
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
                // 01/11/2026 (Aristide) : une icône à la place du numéro.
                // 03/11/2026 : les images d'Emplettes pour préparer et faire les courses.
                // 09/11/2026 (Aristide) : la liste validée attend les courses : chariot vide et liste non cochée.
                ImageEmplettes(i == 1 ? 'liste_a_faire' : ImageEmplettes.pourIcone(_icones[i]), taille: 52),
                const SizedBox(height: 6),
                Text(_etapes[i], textAlign: TextAlign.center, style: _surPhoto(Charte.texte(13, gras: true, couleur: Charte.blanc))),
              ],
            ),
          ),
        ),
      );
}
