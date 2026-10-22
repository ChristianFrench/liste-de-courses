import 'package:flutter/material.dart';

import '../ecrans/coquille.dart' show BarreOnglets;
import '../navigation.dart';
import '../theme.dart';
import 'composants.dart';

/// Version affichée en haut de l'accueil, fournie à la compilation (« 0.6.0 · 3d4d87c »).
const versionApplication = String.fromEnvironment('VERSION', defaultValue: 'essai');

/// En-tête unique de toutes les fenêtres (22 octobre 2026) : fond de la couleur de la palette,
/// à gauche l'icône de l'onglet (la même que dans la barre du bas), le titre, puis les actions
/// de la fenêtre, l'état de la synchronisation et l'aide « ? ».
/// Glisser le doigt à gauche ou à droite sur l'en-tête passe à l'onglet voisin.
class EnTeteFenetre extends StatelessWidget {
  const EnTeteFenetre({
    super.key,
    required this.titre,
    this.icone,
    this.sousTitre,
    this.retour = false,
    this.actions = const [],
    this.droite,
    this.aide,
    this.onAppuiLong,
  });
  final String titre;

  /// Icône de gauche ; par défaut celle de l'onglet affiché.
  final IconData? icone;
  final String? sousTitre;

  /// Flèche de retour avant l'icône (sous-niveaux et fenêtres de travail).
  final bool retour;

  /// Actions propres à la fenêtre : une seule s'affiche en icône, plusieurs dans le menu « ⋮ ».
  final List<ActionLigne> actions;

  /// Élément de droite particulier (ex. : choix du magasin).
  final Widget? droite;

  /// Texte d'aide de la fenêtre (« ? ») ; par défaut l'aide générale.
  final String? aide;
  final VoidCallback? onAppuiLong;

  static const hauteur = 56.0;

  @override
  Widget build(BuildContext context) {
    final ico = icone ?? BarreOnglets.entrees[Nav.i.onglet].$1;
    const bouton = boutonEnTete;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onAppuiLong,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 200) glisserOnglet(context, v < 0 ? 1 : -1);
      },
      child: Container(
        height: hauteur,
        color: Charte.accent,
        padding: EdgeInsets.only(left: retour ? 0 : 12, right: 4),
        child: Row(
          children: [
            if (retour) bouton(Icons.chevron_left, 'Retour', () => Navigator.of(context).maybePop()),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Charte.blanc, shape: BoxShape.circle),
              child: Icon(ico, size: 21, color: Charte.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(21, gras: true, couleur: Charte.blanc)),
                  if (sousTitre != null)
                    Text(sousTitre!,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(12, couleur: const Color(0xDDFFFFFF))),
                ],
              ),
            ),
            if (droite != null) ...[droite!, const SizedBox(width: 4)],
            if (actions.length == 1) bouton(actions.first.icone, actions.first.texte, actions.first.faire),
            if (actions.length > 1) bouton(Icons.more_vert, 'Plus d\'actions', () => menuActions(context, titre: titre, actions: actions)),
            bouton(Icons.cloud_off_outlined, 'Synchronisation', () => montrerSynchro(context)),
            bouton(Icons.help_outline, 'Aide', () => montrerAide(context, titre, aide ?? Aides.generale)),
          ],
        ),
      ),
    );
  }
}

/// Icône blanche de l'en-tête.
Widget boutonEnTete(IconData i, String libelle, VoidCallback onTap) => Tooltip(
      message: libelle,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(width: 44, height: EnTeteFenetre.hauteur, child: Icon(i, size: 24, color: Charte.blanc)),
      ),
    );

/// Passe à l'onglet voisin ([sens] = 1 : suivant, -1 : précédent), comme un appui sur la barre du bas.
void glisserOnglet(BuildContext context, int sens) {
  final o = Nav.i.onglet + sens;
  if (o < 0 || o >= Nav.nbOnglets) return;
  final enTravail = Nav.i.racine.currentState?.canPop() ?? false;
  if (enTravail) {
    // Pendant les courses, quitter passe par la pause.
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && route.popDisposition == RoutePopDisposition.doNotPop) {
      Navigator.of(context).maybePop();
      return;
    }
    Nav.i.retourOnglet(o);
    return;
  }
  Nav.i.allerOnglet(o);
}

/// État de la synchronisation entre les membres du foyer (fenêtre d'information, croix pour fermer).
Future<void> montrerSynchro(BuildContext context) => modale(
      context,
      titre: 'Synchronisation',
      icone: Icons.cloud_off_outlined,
      oui: null,
      non: null,
      contenu: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pas encore active', style: Charte.texte(17, gras: true)),
          const SizedBox(height: 8),
          Text(
            'Vos listes, magasins et parcours sont enregistrés sur cet appareil seulement. '
            'Le partage avec les membres du foyer viendra dans une prochaine version : '
            'cette icône indiquera alors si tout est à jour, en cours d\'envoi ou en attente du réseau.',
            style: Charte.texte(15),
          ),
          const SizedBox(height: 10),
          Text('En attendant, une liste peut s\'envoyer par mail (menu de la liste).',
              style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ],
      ),
    );

/// Page d'aide d'une fenêtre (croix pour fermer).
Future<void> montrerAide(BuildContext context, String titre, String texte) => modale(
      context,
      titre: 'Aide · $titre',
      icone: Icons.help_outline,
      oui: null,
      non: null,
      contenu: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in texte.split('\n'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p, style: Charte.texte(15)),
            ),
        ],
      ),
    );

/// Textes d'aide des fenêtres (« ? » dans l'en-tête).
class Aides {
  Aides._();

  static const generale = 'Les onglets du bas mènent à l\'accueil, à la préparation des listes, aux courses et à la gestion.\n'
      'Glissez le doigt à gauche ou à droite sur le bandeau du haut pour passer d\'un onglet à l\'autre.\n'
      'Sur une ligne : glisser à gauche supprime (avec « Annuler »), glisser à droite fait l\'action principale, '
      'un appui long ouvre toutes les actions.';

  static const accueil = 'L\'accueil rassemble vos listes : en préparation, prêtes pour les courses, courses en cours.\n'
      'Touchez une liste pour la reprendre. « Comment ça marche » explique les étapes ; il se replie quand vous faites défiler les listes.\n'
      'Une nouvelle liste se crée dans l\'onglet Préparer.';

  static const preparer = 'Créez une nouvelle liste ou reprenez une liste en préparation.\n'
      'Une liste se prépare à partir de tout le catalogue du magasin, d\'une liste type, d\'une liste passée ou du texte d\'un mail.';

  static const courses = 'Choisissez une liste prête pour partir faire les courses, ou reprenez des courses interrompues.';

  static const gerer = 'Magasins et catalogue, parcours appris, historique, corbeille, foyer et paramètres.';

  static const nouvelleListe = 'Choisissez le magasin, puis le point de départ de la liste : liste vide (tout le catalogue), '
      'liste type, liste passée ou texte d\'un mail.';

  static const preparation = 'Les rayons sont repliés : touchez-en un pour voir ses secteurs, puis un secteur pour voir ses articles.\n'
      'Toucher un article le coche. L\'article touché affiche quatre pastilles : marque, mesure, packaging et promo ; '
      'touchez-en une pour la renseigner.\n'
      '« + Ajouter un rayon » et « + Ajouter un secteur » complètent le magasin.\n'
      '« Aperçu » montre la liste comme pendant les courses ; « Liste prête » la valide.';

  static const apercu = 'La liste telle qu\'elle sera pendant les courses, dans l\'ordre des rayons. Rien ne se coche ici.';

  static const enMagasin = 'Touchez la case d\'un article quand il est dans le chariot.\n'
      'Touchez deux fois de suite la case si l\'article manque en rayon : il est marqué « manquant ».\n'
      'En terminant, la liste des articles manquants et non cochés s\'affiche.';

  static const magasins = 'Les rayons, secteurs et produits de chaque magasin. Choisissez le magasin en haut à droite.';

  static const parcours = 'L\'ordre des rayons appris pendant vos courses, pour chaque membre et chaque magasin.';

  static const historique = 'Les courses terminées, avec leur ticket.';
}
