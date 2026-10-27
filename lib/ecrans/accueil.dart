import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../theme.dart';
import 'listes.dart';

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
    // L'en-tête et la photo restent en haut ; seules les listes défilent.
    // Faire défiler les listes replie « Comment ça marche » pour leur laisser la place.
    // L'accueil n'a pas de bandeau de titre : la photo (version, synchronisation, aide) en tient lieu.
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _EnTetePhoto(),
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GroupeRetractable(
              cle: 'accueil/preparation',
              titre: 'En préparation',
              icone: Icons.checklist,
              nombre: enPreparation.length,
              vide: 'Aucune liste en préparation.',
              enfants: [
                for (final l in enPreparation)
                  listeGlissable(
                    context,
                    l,
                    LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.'),
                    detail: '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · '
                        '${l.interrompueLe != null ? 'interrompue ${quand(l.interrompueLe!)}' : quandJour(l.modifieeLe ?? l.dateCreation)}',
                  ),
              ],
            ),
            // Listes prêtes : en instance de courses.
            GroupeRetractable(
              cle: 'accueil/instance',
              titre: 'À faire',
              icone: Icons.shopping_cart_outlined,
              nombre: pretes.length,
              vide: 'Aucune liste prête pour les courses.',
              enfants: [
                for (final l in pretes)
                  listeGlissable(
                    context,
                    l,
                    LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.'),
                    detail: 'Prête · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}',
                  ),
              ],
            ),
            if (enCours != null)
              GroupeRetractable(
                cle: 'accueil/courses',
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
            const SizedBox(height: 12),
          ],
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

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return GestureDetector(
          // Comme sur les bandeaux des autres fenêtres : glisser passe à l'onglet voisin.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) glisserOnglet(context, v < 0 ? 1 : -1);
          },
          child: Stack(
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
                  // Seuls ajouts au haut de l'accueil : la version, la synchronisation et l'aide.
                  Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text('Version $versionApplication',
                            style: _surPhoto(Charte.texte(11, couleur: const Color(0xEEFFFFFF)))),
                      ),
                      const BoutonSynchro(),
                      boutonEnTete(Icons.help_outline, 'Aide', () => montrerAide(context, 'Accueil', Aides.accueil)),
                      const SizedBox(width: 4),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour !', style: _surPhoto(Charte.texte(30, gras: true, couleur: Charte.blanc))),
                        Text('Prêt(e) pour vos courses ?', style: _surPhoto(Charte.texte(16, couleur: Charte.blanc))),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x55FFFFFF)))),
                    child: Text('COMMENT ÇA MARCHE', style: _surPhoto(Charte.texte(15, gras: true, couleur: Charte.blanc, espacement: 0.8))),
                  ),
                  const _Etapes(),
                ],
              ),
            ),
          ],
        ));
  }
}

/// Texte blanc posé sur la photo : une ombre douce le détache des légumes clairs.
TextStyle _surPhoto(TextStyle s) =>
    s.copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6), Shadow(color: Color(0x99000000), blurRadius: 2)]);

/// « Comment ça marche » : les cinq étapes, numérotées, du paramétrage au ticket.
class _Etapes extends StatelessWidget {
  const _Etapes();

  static const _etapes = [
    'Je\nparamètre',
    'Je prépare\nma liste',
    'Je la\nvalide',
    'Je fais\nmes courses',
    'Je garde\nle ticket',
  ];

  // Explication de chaque étape, affichée quand on la touche.
  static const _explications = [
    (
      'Je paramètre',
      [
        'Une fois au début, dans l\'onglet Gérer :',
        '• Mon foyer : le foyer et ses membres, avec leur adresse mail pour recevoir les listes.',
        '• Courses : vos magasins et leurs parcours, puis le catalogue, le même pour tous les magasins, '
            'auquel vous pouvez ajouter des produits ; les types de promotion, les marques et les packagings.',
        '• Paramètres : l\'apparence, les données, la synchronisation.',
        'Le parcours de chaque magasin n\'est pas à décrire : il s\'apprend pendant vos premières courses.',
      ],
    ),
    (
      'Je prépare ma liste',
      [
        'Dans l\'onglet Préparer, touchez « + Nouvelle liste », choisissez le magasin, puis comment commencer :',
        '• Liste type : une de vos listes types, ou la liste complète du magasin, rayon par rayon.',
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
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Charte.accent, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: Charte.texte(15, gras: true, couleur: Charte.blanc)),
                ),
                const SizedBox(height: 6),
                Text(_etapes[i], textAlign: TextAlign.center, style: _surPhoto(Charte.texte(13, gras: true, couleur: Charte.blanc))),
              ],
            ),
          ),
        ),
      );
}
