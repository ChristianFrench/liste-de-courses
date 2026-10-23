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
    this.deplier,
  });
  final String titre;

  /// Icône de gauche ; par défaut celle de l'onglet affiché.
  final IconData? icone;
  final String? sousTitre;

  /// Flèche de retour avant l'icône (sous-niveaux et fenêtres de travail).
  final bool retour;

  /// Actions propres à la fenêtre : dans le menu « ⋮ », avec l'aide.
  final List<ActionLigne> actions;

  /// Élément de droite particulier (ex. : choix du magasin).
  final Widget? droite;

  /// Texte d'aide de la fenêtre (« ? ») ; par défaut l'aide générale.
  final String? aide;
  final VoidCallback? onAppuiLong;

  /// Groupes visés par l'icône « tout déplier / tout replier » ; par défaut, les groupes rétractables de la fenêtre.
  final List<String>? deplier;

  static const hauteur = 64.0;

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
      // Fond : la photo de l'accueil, assombrie pour que le texte blanc reste lisible
      // (la couleur pleine est réservée aux bandeaux des groupes de listes).
      child: Container(
        height: hauteur,
        decoration: const BoxDecoration(
          color: Color(0xFF3A4A3A),
          image: DecorationImage(
            image: AssetImage('assets/accueil_photo.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.35),
            colorFilter: ColorFilter.mode(Color(0x38000000), BlendMode.darken),
          ),
        ),
        padding: EdgeInsets.only(left: retour ? 0 : 12, right: 4),
        child: Row(
          children: [
            if (retour) bouton(Icons.chevron_left, 'Retour', () => Navigator.of(context).maybePop()),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: Charte.blanc, shape: BoxShape.circle),
              child: Icon(ico, size: 23, color: Charte.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: surPhoto(Charte.texte(21, gras: true, couleur: Charte.blanc))),
                  if (sousTitre != null)
                    Text(sousTitre!,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: surPhoto(Charte.texte(12, couleur: const Color(0xEEFFFFFF)))),
                ],
              ),
            ),
            if (droite != null) ...[droite!, const SizedBox(width: 4)],
            _BoutonDeplier(deplier),
            bouton(Icons.cloud_off_outlined, 'Synchronisation', () => montrerSynchro(context)),
            // Le menu « ⋮ », toujours à droite : les actions de la fenêtre, puis l'aide.
            bouton(Icons.more_vert, 'Plus d\'actions', () => menuActions(context, titre: titre, actions: [
                  ...actions,
                  ActionLigne(Icons.help_outline, 'Aide', () => montrerAide(context, titre, aide ?? Aides.generale)),
                ])),
          ],
        ),
      ),
    );
  }
}

/// Icône « tout déplier / tout replier » de l'en-tête : sur les groupes donnés ([cles]),
/// sinon sur les groupes rétractables de la fenêtre (elle n'apparaît que s'il y en a).
class _BoutonDeplier extends StatelessWidget {
  const _BoutonDeplier(this.cles);
  final List<String>? cles;

  @override
  Widget build(BuildContext context) {
    final page = PorteeGroupes.de(context);
    return ListenableBuilder(
      listenable: Listenable.merge([Retractables.i, if (page != null) page]),
      builder: (context, _) {
        if (cles case final c?) {
          final a = reduireTout(c);
          return boutonEnTete(a.icone, a.texte, a.faire);
        }
        if (page == null || page.cles.isEmpty) return const SizedBox.shrink();
        final fermes = page.tousFermes;
        return boutonEnTete(fermes ? Icons.unfold_more : Icons.unfold_less, fermes ? 'Tout déplier' : 'Tout replier',
            () => Retractables.i.tous(page.cles.keys, page.tousFermes));
      },
    );
  }
}

/// Texte blanc posé sur la photo : une ombre douce le détache des légumes clairs.
TextStyle surPhoto(TextStyle s) =>
    s.copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6), Shadow(color: Color(0x99000000), blurRadius: 2)]);

/// Icône blanche de l'en-tête.
Widget boutonEnTete(IconData i, String libelle, VoidCallback onTap) => Tooltip(
      message: libelle,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(width: 44, height: EnTeteFenetre.hauteur, child: Icon(i, size: 24, color: Charte.blanc, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)])),
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

/// Textes d'aide des fenêtres (menu « ⋮ » › Aide). Un paragraphe par ligne.
class Aides {
  Aides._();

  static const _gestes = 'Gestes communs : glisser le doigt à gauche ou à droite sur le bandeau du haut, ou sur une zone libre '
      'de la fenêtre, passe à l\'onglet voisin. Sur une ligne de liste : glisser à gauche supprime ou retire '
      '(« Annuler » apparaît quelques secondes en bas), glisser à droite fait l\'action principale, '
      'un appui long ouvre le menu de toutes les actions de la ligne.\n'
      'Les groupes (rayons, secteurs, magasins…) s\'ouvrent et se ferment d\'un appui sur leur bandeau ; '
      'l\'icône à double flèche du bandeau du haut les déplie ou les replie tous.\n'
      'Le menu des trois points, en haut à droite, regroupe les actions de la fenêtre et cette aide. '
      'Le nuage barré indique que la synchronisation entre les membres du foyer n\'est pas encore active.';

  static const generale = 'L\'application compte quatre onglets, en bas de l\'écran : Accueil, Préparer, Courses et Gérer.\n$_gestes';

  static const accueil = 'L\'accueil rassemble ce qui est en cours.\n'
      '« Comment ça marche » rappelle les cinq étapes : je paramètre, je prépare ma liste, je la valide, je fais mes courses, '
      'je garde le ticket. Touchez une étape pour son explication. Ce bloc se replie quand vous faites défiler l\'écran.\n'
      '« En préparation » : les listes que vous êtes en train de construire ; « Reprendre » les rouvre là où vous en étiez.\n'
      '« En instance de courses » : les listes prêtes ; « Faire les courses » lance les courses.\n'
      '« Courses en cours » : des courses interrompues par « Pause » ; « Reprendre » les continue au secteur où vous vous étiez arrêté.\n'
      'Une nouvelle liste se crée dans l\'onglet Préparer.\n$_gestes';

  static const preparer = 'L\'onglet Préparer sert à construire les listes avant les courses.\n'
      '« + Nouvelle liste » : choisissez le magasin, le nom de la liste (proposé d\'office), puis son type : '
      'liste simple (on tape les articles, sans rayons), liste type ou liste complète (tout le catalogue, rayon par rayon), '
      'liste personnalisée (reprise d\'une course passée), liste depuis un mail (texte collé), ou liste calculée (plus tard).\n'
      '« En préparation » : touchez une liste pour la reprendre. Glisser à gauche la supprime (avec « Annuler »).\n'
      '« Prêtes pour les courses » : les listes validées ; un appui long permet de les remettre en préparation.\n$_gestes';

  static const courses = 'L\'onglet Courses sert pendant les courses.\n'
      '« Prêtes pour les courses » : touchez « Faire les courses » ; une fenêtre demande qui fait les courses et avec quel parcours, '
      'puis la liste s\'affiche dans l\'ordre des allées.\n'
      '« Courses interrompues » : des courses mises en pause ; « Reprendre » les continue.\n'
      '« Terminées sans ticket » : joignez le ticket de caisse (fichier PDF), ou classez la course sans ticket ; '
      'elle rejoint alors l\'historique (Gérer).\n$_gestes';

  static const gerer = 'L\'onglet Gérer regroupe tout ce qui se règle une fois pour toutes.\n'
      'Magasins et catalogue : vos magasins, leurs rayons, secteurs et produits ; vous pouvez ajouter, renommer, déplacer, '
      'supprimer, et choisir l\'image d\'un rayon ou d\'un secteur.\n'
      'Parcours : l\'ordre des secteurs appris pendant vos courses, pour chaque membre et chaque magasin.\n'
      'Historique : les courses terminées, par date ou par magasin, avec leur ticket. Archives : les magasins supprimés qui ont un historique. '
      'Corbeille : ce qui a été supprimé, à remettre ou à effacer pour de bon.\n'
      'Mon foyer : son nom et ses membres (avec leur adresse mail pour l\'envoi des listes).\n'
      'Paramètres : couleurs de l\'application, réglages des listes, types de promotion et de packaging, sauvegarde des données.\n$_gestes';

  static const nouvelleListe = 'Choisissez le magasin, puis vérifiez le nom de la liste (magasin, date et heure, à modifier si vous voulez ; '
      'deux listes ne peuvent pas porter le même nom).\n'
      'Liste simple : vous tapez le début du nom des articles, ils s\'ajoutent les uns sous les autres, sans rayons ni secteurs. '
      'À la fin, la liste peut être rangée par rayons et secteurs.\n'
      'Liste type : une liste enregistrée sous un nom (ex. « Petit-déjeuner »), ou la liste complète, vide, avec tout le catalogue du magasin.\n'
      'Liste personnalisée : une de vos dernières courses ; cochez les articles à reprendre.\n'
      'Liste depuis un mail : collez le texte d\'une liste reçue par mail ; les articles sont reconnus dans le catalogue, '
      'vous décochez ceux à ne pas garder.\n'
      'Liste calculée : à partir de vos tickets de caisse, prévue plus tard.';

  static const preparation = 'Le champ de recherche, sous le titre : tapez au moins trois lettres, la liste des articles '
      'dont un mot commence ainsi s\'affiche. Touchez-en un : son rayon et son secteur s\'ouvrent et l\'article est signalé.\n'
      'Sinon, les rayons sont repliés : touchez-en un pour voir ses secteurs, puis un secteur pour voir ses articles. '
      'Un seul rayon et un seul secteur sont ouverts à la fois ; leurs bandeaux restent en haut pendant que les articles défilent.\n'
      'Toucher un article le coche ; − et + règlent la quantité. L\'article touché affiche quatre pastilles : marque, mesure, '
      'packaging et promo ; touchez-en une pour la renseigner. Un appui long ajoute une consigne (« bien mûres »).\n'
      '« + Produit absent de ce secteur », « + Ajouter un secteur » et « + Ajouter un rayon » complètent le magasin.\n'
      '« Ma liste » ne montre que les articles choisis. « Aperçu » montre la liste comme pendant les courses. '
      '« Liste prête » la valide : commentaire, enregistrement comme liste type, envoi par mail.\n$_gestes';

  static const listeSimple = 'Une liste simple se construit sans rayons ni secteurs.\n'
      'Dans le champ sous le titre, tapez au moins trois lettres : les articles dont un mot commence ainsi s\'affichent. '
      'Touchez-en un : il s\'ajoute en fin de liste. Absent du catalogue ? Touchez « Créer « … » ».\n'
      'Toucher un article affiche ses pastilles (marque, mesure, packaging, promo) ; − et + règlent la quantité ; '
      'glisser à gauche le retire.\n'
      '« Aperçu » montre la liste telle qu\'elle sera en magasin, avec ou sans rayons et secteurs.\n'
      '« Liste prête » : cochez « Ranger par rayons et secteurs » pour que la liste suive l\'ordre du magasin pendant les courses ; '
      'sinon elle garde l\'ordre de saisie.\n$_gestes';

  static const apercu = 'La liste telle qu\'elle sera pendant les courses, dans l\'ordre des rayons et de votre parcours. '
      'Rien ne se coche ici. « Continuer la préparation » revient à la liste.';

  static const enMagasin = 'La liste suit l\'ordre des allées, secteur par secteur ; chaque bandeau montre l\'avancement du secteur.\n'
      'Touchez un article quand il est dans le chariot : il est barré. Touchez-le de nouveau pour le décocher.\n'
      'Touchez deux fois de suite un article absent du rayon : il est marqué « manquant ».\n'
      '« Reste à faire » cache ce qui est déjà pris. « Pause » interrompt les courses sans rien perdre. '
      '« Terminer les courses » affiche les articles manquants et non cochés, puis range la course en attente de son ticket.\n'
      'L\'ordre dans lequel vous cochez apprend le parcours du magasin pour les prochaines fois.\n$_gestes';

  static const magasins = 'Vos magasins, avec leurs rayons, secteurs et produits. Choisissez le magasin en haut à droite.\n'
      'Touchez un rayon pour ses secteurs, un secteur pour ses produits, un produit pour sa fiche. '
      'Un appui long ouvre les actions de la ligne.\n$_gestes';

  static const parcours = 'L\'ordre des secteurs appris pendant vos courses, pour chaque membre et chaque magasin. '
      'Il se complète tout seul quand vous passez par de nouveaux secteurs.\n$_gestes';

  static const historique = 'Les courses terminées, rangées par date ou par magasin, avec leur ticket de caisse. '
      'Touchez une course pour voir ses articles ou son ticket.\n$_gestes';
}
