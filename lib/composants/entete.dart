import 'package:flutter/material.dart';

import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../ecrans/partage.dart' show montrerEtatSynchro;
import '../navigation.dart';
import '../theme.dart';
import 'composants.dart';
import 'icone.dart';

/// Version affichée en haut de l'accueil, fournie à la compilation (« 0.6.0 · 3d4d87c »).
export '../donnees/version.dart';

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

  /// Choisit l'image de signature des onglets (sans flèche de retour) : liste et crayon (Préparer),
  /// liste et chariot (Courses), engrenage (Gérer), sinon l'image complète d'Emplettes.
  final IconData? icone;
  final String? sousTitre;

  /// Flèche de retour avant l'icône (sous-niveaux et fenêtres de travail).
  final bool retour;

  /// Actions propres à la fenêtre : proposées en touchant le titre, avec l'aide.
  final List<ActionLigne> actions;

  /// Élément de droite particulier (ex. : choix du magasin).
  final Widget? droite;

  /// Texte d'aide de la fenêtre (« ? ») ; par défaut l'aide générale.
  final String? aide;
  final VoidCallback? onAppuiLong;

  /// Hauteur d'un bouton de l'en-tête (deuxième ligne).
  static const hauteurBouton = 44.0;

  // 09/11/2026 : la photo de fond suit le choix d'Apparence, même sur un bandeau déjà construit.
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<String>(valueListenable: Etat.fondChange, builder: (context, _, __) => _construire(context));

  Widget _construire(BuildContext context) {
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
      // Deux lignes : le titre en entier (sur deux lignes au besoin), puis le sous-titre et les boutons.
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3A4A3A),
          image: DecorationImage(
            image: AssetImage(Etat.instance.photoFond),
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.35),
            colorFilter: ColorFilter.mode(Color(0x38000000), BlendMode.darken),
          ),
        ),
        padding: EdgeInsets.only(left: retour ? 0 : 12, right: 4, top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (retour) bouton(Icons.chevron_left, 'Retour', () => Navigator.of(context).maybePop()),
                // 03/11/2026 (Aristide) : l'icône de l'application en signature sur les onglets
                if (!retour)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 8),
                    child: icone == Icons.tune
                        ? Icone(icone, key: const ValueKey('signature'), size: 44)
                        : ImageEmplettes(ImageEmplettes.pourIcone(icone), key: const ValueKey('signature'), taille: 46),
                  ),
                // Toucher le titre propose les actions de la fenêtre, puis l'aide, dans un volet.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Actions de la fenêtre',
                      child: InkWell(
                        key: const ValueKey('titre-actions'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => actions.isEmpty
                            ? montrerAide(context, titre, aide ?? Aides.generale)
                            : menuActions(context, titre: titre, actions: [
                                ...actions,
                                ActionLigne(Icons.help_outline, 'Aide', () => montrerAide(context, titre, aide ?? Aides.generale)),
                              ]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(
                              child: Text(titre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: surPhoto(Charte.texte(20, gras: true, couleur: Charte.blanc))),
                            ),
                            Icone(Icons.expand_more,
                                size: 26, color: Charte.blanc, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)]),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 02/11/2026 (Aristide) : sur toutes les fenêtres, le nuage puis l'aide, en haut à droite.
                const BoutonSynchro(),
                boutonEnTete(Icons.help_outline, 'Aide', () => montrerAide(context, titre, aide ?? Aides.generale)),
              ],
            ),
            Row(
              children: [
                SizedBox(width: retour ? 12 : 0),
                Expanded(
                  child: sousTitre == null
                      ? const SizedBox.shrink()
                      : Text(sousTitre!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: surPhoto(Charte.texte(13, couleur: const Color(0xEEFFFFFF)))),
                ),
                if (droite != null) ...[droite!, const SizedBox(width: 4)],
                const SizedBox(height: hauteurBouton), // hauteur fixe : le titre reste au même endroit sur toutes les fenêtres
              ],
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle surPhoto(TextStyle s) =>
    s.copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6), Shadow(color: Color(0x99000000), blurRadius: 2)]);

/// Icône blanche de l'en-tête.
Widget boutonEnTete(IconData i, String libelle, VoidCallback onTap) => Tooltip(
      message: libelle,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(width: 44, height: EnTeteFenetre.hauteurBouton, child: Icone(i, size: 24, color: Charte.blanc, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)])),
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

/// Icône de la synchronisation : un nuage et un point dont la couleur dit l'état du partage
/// (voir [Synchro.pastille]) ; le point vert clignote pendant un échange. Ouvre l'écran du partage.
class BoutonSynchro extends StatelessWidget {
  const BoutonSynchro({super.key});

  static const vert = Color(0xFF2E9D46);
  static const rouge = Color(0xFFE53935);
  static const orange = Color(0xFFF59E0B);

  static Color couleur(String pastille) => switch (pastille) {
        'rouge' => rouge,
        'orange' => orange,
        'vert' => vert,
        _ => Charte.blanc,
      };

  static String resume(Synchro s) => switch (s.pastille) {
        'blanc' => 'Synchronisation : foyer non partagé',
        'rouge' => 'Synchronisation : pas de connexion au serveur',
        'orange' => 'Synchronisation : aucun autre appareil connecté',
        _ => s.enEchange
            ? 'Synchronisation en cours'
            : 'Synchronisation : à jour avec ${s.autresEnLigne} appareil${s.autresEnLigne > 1 ? 's' : ''}',
      };

  @override
  Widget build(BuildContext context) {
    final s = Synchro.instance;
    const ombre = [Shadow(color: Color(0x99000000), blurRadius: 4)];
    return ListenableBuilder(
      listenable: s,
      // Seul sur cet appareil : pas de nuage.
      builder: (context, _) => s.mode == 'seul' ? const SizedBox.shrink() : Tooltip(
        message: resume(s),
        child: Semantics(
          button: true,
          label: resume(s),
          child: InkResponse(
            onTap: () => montrerEtatSynchro(context),
            radius: 22,
            child: SizedBox(
              width: 44,
              height: EnTeteFenetre.hauteurBouton,
              child: Stack(alignment: Alignment.center, children: [
                const Icone(Icons.cloud_outlined, size: 26, color: Charte.blanc, shadows: ombre),
                Positioned(
                  right: 2,
                  top: EnTeteFenetre.hauteurBouton / 2 - 1,
                  child: PointSynchro(taille: 16, couleur: couleur(s.pastille), clignote: s.pastille == 'vert' && s.enEchange),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Point coloré de l'état du partage, qui peut clignoter (échange en cours).
class PointSynchro extends StatefulWidget {
  const PointSynchro({super.key, required this.taille, required this.couleur, this.clignote = false});
  final double taille;
  final Color couleur;
  final bool clignote;

  @override
  State<PointSynchro> createState() => _PointSynchroState();
}

class _PointSynchroState extends State<PointSynchro> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450), lowerBound: 0.25);

  @override
  void initState() {
    super.initState();
    _suivre();
  }

  @override
  void didUpdateWidget(PointSynchro avant) {
    super.didUpdateWidget(avant);
    if (avant.clignote != widget.clignote) _suivre();
  }

  void _suivre() {
    if (widget.clignote) {
      _anim.repeat(reverse: true);
    } else {
      _anim
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: widget.taille,
          height: widget.taille,
          decoration: BoxDecoration(
            color: widget.couleur,
            shape: BoxShape.circle,
            border: Border.all(color: widget.couleur == Charte.blanc ? const Color(0xFF9E9E9E) : Charte.blanc, width: 2),
          ),
        ),
      );
}

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

/// Textes d'aide des fenêtres (toucher le titre › Aide). Un paragraphe par ligne.
class Aides {
  Aides._();

  static const _gestes = 'Gestes communs : glisser le doigt à gauche ou à droite sur le bandeau du haut, ou sur une zone libre '
      'de la fenêtre, passe à l\'onglet voisin. Toutes les listes ont des lignes serrées sous de minces bandeaux. '
      'Toucher une ligne en ouvre le volet du bas : son détail, puis ses actions. Sur une ligne, glisser à gauche supprime '
      'ou retire (« Annuler » apparaît quelques secondes en bas), glisser à droite fait l\'action principale.\n'
      'Les fenêtres s\'ouvrent en volet du bas : tirez la poignée vers le bas (ou touchez à côté) pour le fermer.\n'
      'Toucher le titre de la fenêtre (en haut, avec la petite flèche) propose ses actions et cette aide ; '
      'toucher un bandeau propose les actions de son groupe. Seuls les boutons qui font avancer une liste '
      '(Nouvelle liste, Liste prête, Pause, Terminer) restent en bas de l\'écran. '
      'Le nuage barré indique que la synchronisation entre les membres du foyer n\'est pas encore active.';

  static const generale = 'L\'application compte quatre onglets, en bas de l\'écran : Accueil, Préparer, Courses et Gérer.\n$_gestes';

  static const accueil = 'L\'accueil rassemble ce qui est en cours.\n'
      '« Comment ça marche » rappelle les quatre étapes : je paramètre une fois, je prépare ma liste, je la valide, '
      'je fais mes courses. Touchez une étape pour son explication.\n'
      '« En préparation » : les listes que vous êtes en train de construire. « À faire » : les listes prêtes pour les courses. '
      '« Courses en cours » : des courses interrompues par « Pause ». Touchez une liste pour ce que vous pouvez en faire.\n'
      'Une nouvelle liste se crée dans l\'onglet Préparer.\n$_gestes';

  static const preparer = 'L\'onglet Préparer sert à construire les listes avant les courses.\n'
      '« Nouvelle liste » : choisissez le magasin, le nom de la liste (proposé d\'office), puis son type : '
      'liste simple (sans secteurs), liste type ou liste vide, liste personnalisée (reprise d\'une course passée), '
      'liste depuis un texte (collé), ou liste calculée (plus tard).\n'
      '« En préparation » et « Prêtes pour les courses » : touchez une liste pour voir ce que vous pouvez en faire '
      '(la reprendre, la remettre en préparation, la renommer, la supprimer). Glissez-la vers la gauche pour la supprimer, '
      'vers la droite pour la remettre en préparation.\n$_gestes';

  static const courses = 'L\'onglet Courses suit la vie des listes, en une seule liste :\n'
      '« À faire » : les listes prêtes (une liste arrive ici quand sa préparation est terminée par « Liste prête ») ; '
      'touchez-en une puis « Faire les courses » : une fenêtre demande qui fait les courses et avec quel parcours.\n'
      '« En cours » : des courses mises en pause, à reprendre.\n'
      '« Terminées » : les courses finies, avec ou sans ticket (une icône signale le ticket joint) ; touchez-en une pour '
      'joindre le ticket de caisse (fichier PDF), glissez-la vers la droite pour la mettre dans l\'historique.\n'
      '« Historique » et « Archives » : touchez une course pour voir ou joindre son ticket, en faire une liste type, '
      'la remettre dans « Terminées », l\'archiver ou la remettre en historique ; glisser une course de l\'historique vers la gauche la supprime. Les courses de plus de trois mois '
      'passent aux archives (réglable dans Données).\n'
      'En terminant les courses, vous pouvez envoyer un résumé au foyer : oubliés, absents des rayons, achetés.\n'
      'Ticket reçu dans l\'application du magasin : touchez « Partager » et choisissez Emplettes ; '
      'ou, dans les téléchargements, ouvrez le PDF avec Emplettes. L\'application demande à quelle course le joindre.\n$_gestes';

  static const gerer = 'L\'onglet Gérer regroupe tout ce qui se règle une fois pour toutes.\n'
      'Mon foyer : seul sur cet appareil ou en foyer partagé. En foyer, chacun peut ajouter un membre et lui envoyer '
      'l\'invitation par mail (code de partage et liens d\'installation), le renommer ou le retirer du foyer, et régénérer le code. '
      'En rejoignant le foyer, on choisit son nom dans la liste des membres ; « Changer de personne » corrige une erreur. '
      'Appareil partagé (tablette, PC de la famille) : on choisit son nom à chaque lancement.\n'
      'Messages : écrire à tout le foyer ; avec l\'appli ntfy (Android) ou la page ntfy du navigateur, on est prévenu même application fermée. '
      'L\'essai d\'envoi de mail (champs du modèle EmailJS et sa réponse) s\'y trouve aussi, en touchant le titre.\n'
      'Synchronisation : l\'état des échanges entre les appareils du foyer ; serveur sous « Avancé », pour un dépannage.\n'
      'Courses : les magasins (et les parcours appris dans chacun), le catalogue des produits (le même pour tous les magasins ; '
      'rayons, secteurs et produits ajoutés marqués d\'un petit +), le catalogue des marques (les marques de chaque secteur, '
      'proposées en préparation), puis les types de promotion, de mesure (poids, volume, à la pièce) et de packaging (lots de 2 à 10…).\n'
      'Paramètres : apparence (palette de couleurs, couleurs des cadres), données (listes exemples, préliste, passage aux archives et suppression des archives).\n'
      'La corbeille est dans Paramètres ; l\'historique et les archives sont dans l\'onglet Courses.\n$_gestes';

  static const nouvelleListe = 'Choisissez le magasin, puis vérifiez le nom de la liste (magasin, date et heure, à modifier si vous voulez ; '
      'deux listes ne peuvent pas porter le même nom).\n'
      'Nouvelle liste, par secteur : vous cherchez les articles un à un, ils se rangent sous leur secteur.\n'
      'Nouvelle liste simple : vous tapez le début du nom des articles, ils s\'ajoutent les uns sous les autres, sans rayons ni secteurs. '
      'À la fin, la liste peut être rangée par rayons et secteurs.\n'
      'Depuis une liste type : une liste enregistrée sous un nom (ex. « Petit-déjeuner »), ou une liste vide.\n'
      'Mes achats habituels : les articles que vous achetez régulièrement dans ce magasin (réglage dans Gérer › Paramètres › Données), '
      'tous cochés ; décochez ceux dont vous n\'avez pas besoin cette fois.\n'
      'Depuis une course passée : une de vos dernières courses ; cochez les articles à reprendre.\n'
      'Depuis un texte : collez le texte d\'une liste (mail, message, note) ; les articles sont reconnus dans le catalogue, '
      'vous décochez ceux à ne pas garder.\n'
      'Compléter des courses : rectificative : des articles à ajouter à des courses en cours ; celui qui les fait accepte ou refuse.\n'
      'Liste calculée : à partir de vos tickets de caisse, prévue plus tard.';

  static const preparation = 'Le champ de recherche, sous le titre : tapez au moins trois lettres, la liste des articles '
      'dont un mot commence ainsi s\'affiche. Touchez-en un : il s\'ajoute à la liste et l\'écran va sur lui. '
      'Absent du catalogue ? Touchez « Créer « … » ».\n'
      'La liste a la même présentation que pendant les courses : de minces bandeaux de secteur dans l\'ordre de votre parcours, '
      'une ligne par article. Un P signale une promotion, un petit code le packaging (ex. ×6), une consigne suit le nom.\n'
      '− et + règlent la quantité ; à 0, l\'article est retiré (« Annuler » le remet). Touchez la ligne pour le packaging, '
      'la consigne et la promotion. Un appui long retire l\'article.\n'
      '« Liste prête » la valide : commentaire, enregistrement comme liste type, envoi par mail.\n$_gestes';

  static const listeSimple = 'Une liste simple se construit sans secteurs : les articles restent dans l\'ordre de saisie.\n'
      'Dans le champ sous le titre, tapez au moins trois lettres : les articles dont un mot commence ainsi s\'affichent. '
      'Touchez-en un : il s\'ajoute en fin de liste. Absent du catalogue ? Touchez « Créer « … » ».\n'
      '− et + règlent la quantité ; touchez la ligne pour le packaging, la consigne et la promotion ; un appui long retire l\'article.\n'
      '« Liste prête » : cochez « Ranger par rayons et secteurs » pour que la liste suive l\'ordre du magasin pendant les courses ; '
      'sinon elle garde l\'ordre de saisie.\n$_gestes';

  static const enMagasin = 'La liste suit l\'ordre des allées, sous de minces bandeaux de secteur.\n'
      'Seule la grande case à gauche réagit : touchez-la quand l\'article est dans le chariot, il est barré et grisé, à sa place, '
      'et son secteur remonte en haut de l\'écran. Touchez-la de nouveau pour le décocher.\n'
      'Touchez deux fois de suite la case d\'un article absent du rayon : il est marqué « manquant », en rouge.\n'
      'Un appui long sur la case montre le détail de l\'article (promotion, packaging, consigne), en bas, pendant 4 secondes.\n'
      '« Pause » interrompt les courses sans rien perdre. '
      '« Terminer » affiche les articles manquants et non cochés, puis range la course en attente de son ticket.\n'
      'L\'ordre dans lequel vous cochez apprend le parcours du magasin pour les prochaines fois.\n'
      'Pendant les courses, rien ne modifie la liste ni les produits : pas de glissement ni de menu sur les lignes, seule la case réagit.';

  static const foyer = 'Foyer : son nom, partagé ou seul sur cet appareil. Seul : pas de membres ni de synchronisation ; pour '
      'partager les listes avec d\'autres personnes, touchez la ligne du foyer puis « Passer en foyer ».\n'
      'Code de partage : à saisir sur un autre appareil (« Rejoindre un foyer »), puis chacun choisit son nom dans la liste '
      'des membres. L\'invitation envoyée à un membre contient ce code. Touchez-le pour le copier ou le régénérer.\n'
      'Appareil partagé : tablette ou PC de la famille ; à chaque lancement, on choisit son nom.\n'
      'Membres : touchez un membre pour lui envoyer l\'invitation, le renommer ou le retirer du foyer. '
      '« + Nouveau membre » et « Changer de personne » sont dans le titre.\n'
      'Listes : « Envoyer la liste à tout le foyer » prépare le mail avec les adresses de tous les membres.\n'
      'Catalogue : le catalogue commun est le même pour tous les foyers ; vos ajouts et modifications restent chez vous, '
      'et sont proposés à l\'éditeur du catalogue commun.\n$_gestes';

  static const collaboration = 'Membres : touchez un membre pour voir les notifications et les mails qu\'il a envoyés et reçus.\n'
      'Communication : une notification part à tous les membres, par le service gratuit ntfy ; « Envoyer un mail » '
      'montre les champs du mail (destinataires, sujet, texte) et la réponse du service d\'envoi.\n'
      'Pour recevoir les notifications même quand l\'application est fermée, touchez le titre puis « Recevoir les '
      'notifications sur cet appareil » : sur Android, installez d\'abord l\'appli ntfy ; dans un navigateur, autorisez les '
      'notifications sur la page qui s\'ouvre. « Copier mon adresse de notification » donne cette adresse, à saisir à la main '
      'dans ntfy si besoin.\n'
      'Synchronisation : l\'état des échanges entre les appareils du foyer.\n$_gestes';

  static const historiqueMembre = 'Les notifications et les mails envoyés et reçus par ce membre, du plus récent au plus '
      'ancien. Le journal est gardé sur cet appareil depuis qu\'il le lit : le service de notifications n\'en garde que '
      'quelques heures.';

  static const magasins = 'Vos magasins. Ils ont tous le même catalogue ; touchez un magasin pour ses parcours, '
      'le renommer ou le supprimer. Supprimer un magasin efface ses parcours et ses listes en cours (après confirmation) ; '
      'son historique de courses part dans les archives.\n$_gestes';

  static const typesPromotion = 'Les types de promotion, proposés quand on indique une promotion sur une ligne de la liste. '
      'Touchez un type pour le modifier ou le supprimer ; « + Nouveau type » est dans le titre. Leur couleur se choisit dans '
      'Gérer › Paramètres › Apparence.\n$_gestes';

  static const typesMesure = 'Les mesures : le poids (g, kg), le volume (cl, l) ou la vente à la pièce. Touchez-en une pour la '
      'modifier, voir ses articles ou la supprimer ; « + Nouvelle mesure » est dans le titre. La couleur se choisit dans '
      'Gérer › Paramètres › Apparence.\n$_gestes';

  static const typesPackaging = 'Les packagings, essentiellement des lots de 2 à 10. Touchez-en un pour le modifier, voir ses '
      'articles ou le supprimer ; « + Nouveau packaging » est dans le titre. La couleur se choisit dans Gérer › Paramètres › '
      'Apparence.\n$_gestes';

  static const catalogue = 'Le catalogue du foyer, le même dans tous les magasins : ses rayons, ses secteurs et ses produits. '
      'Les rayons, les secteurs et les produits d\'origine ne changent pas.\n'
      'Touchez un secteur : « Voir et modifier les produits » affiche ses produits, « + Nouveau produit » demande le nom, '
      'sa marque éventuelle, sa mesure et son packaging. Le produit s\'appelle « nom marque » (ex. « Camembert Président »). '
      'Sur un produit d\'origine, « Ajouter une marque au produit » la rattache au produit (« Camembert · Président ») sans créer de produit.\n'
      'Un petit + signale un produit ajouté par le foyer ; « Produits ajoutés » (en touchant le titre) les rassemble pour les modifier ou les supprimer. '
      'Toucher le bandeau d\'un rayon propose un nouveau secteur ou de changer l\'ordre des secteurs.\n$_gestes';

  static const marques = 'Les marques de chaque secteur, rangées comme le catalogue des produits : seuls les rayons et secteurs '
      'qui ont des marques paraissent, avec leur nombre. Touchez une marque pour la modifier (rayon, secteur, libellé ; '
      'un autre nom la renomme partout, ses produits aussi) ; la poubelle ou un glissement vers la gauche la retire du secteur ; '
      '« + Nouvelle marque », en fin de secteur ou en touchant le titre, en ajoute une. '
      'En préparation, le volet d\'un article propose les marques de son secteur dans une liste déroulante.\n$_gestes';

  static const parcours = 'L\'ordre des secteurs appris pendant vos courses, pour chaque membre et chaque magasin. '
      'Il se complète tout seul quand vous passez par de nouveaux secteurs.\n$_gestes';

  static const historique = 'Les courses terminées, rangées par date ou par magasin, avec leur ticket de caisse. '
      'Touchez une course pour voir ses articles ou son ticket.\n$_gestes';
}
