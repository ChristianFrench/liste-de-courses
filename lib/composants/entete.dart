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
    this.onRetour,
  });
  final String titre;

  /// Flèche de retour sur un écran racine (Gérer, ouvert depuis l'accueil, 21/11/2026).
  final VoidCallback? onRetour;

  /// Choisit l'image de signature des onglets (sans flèche de retour) : liste et crayon (Préparer),
  /// liste et chariot (Courses), engrenage (Gérer), sinon l'image complète d'Emplettes.
  final IconData? icone;
  final String? sousTitre;

  /// Flèche de retour avant l'icône (sous-niveaux et fenêtres de travail).
  final bool retour;

  /// Actions propres à la fenêtre : proposées en touchant le titre, avec l'aide.
  final List<ActionLigne> actions;

  /// Recherche d'une recette (bouton de l'en-tête), fournie par l'application (ecrans/recettes.dart).
  static void Function(BuildContext context)? chercherRecette;

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
                if (!retour && onRetour != null) bouton(Icons.chevron_left, 'Retour', onRetour!),
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
                // 19/11/2026 (Aristide) : chercher une recette depuis toutes les fenêtres, à côté du nuage.
                if (EnTeteFenetre.chercherRecette case final f?)
                  boutonEnTete(Icons.restaurant_menu_outlined, 'Chercher une recette', () => f(context)),
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
  // 21/11/2026 : dans l'ordre de la barre (Gérer n'y est plus dans la démonstration).
  final k = Nav.ordre.indexOf(Nav.i.onglet) + sens;
  if (Nav.ordre.indexOf(Nav.i.onglet) < 0 || k < 0 || k >= Nav.ordre.length) return;
  final o = Nav.ordre[k];
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

/// Page d'aide d'une fenêtre (24/11/2026, Aristide : « quelques points avec une phrase courte, des icônes »).
/// Chaque ligne du texte est un point « icône|Titre|Phrase » (voir [Aides]) ; une ligne sans « | » est une phrase
/// d'introduction. Les gestes communs sont repliés en bas, sauf dans l'aide générale qui les montre.
Future<void> montrerAide(BuildContext context, String titre, String texte) {
  var gestes = texte == Aides.generale;
  return modale(
    context,
    titre: 'Aide · $titre',
    icone: Icons.help_outline,
    oui: null,
    non: null,
    contenu: (_, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._pointsAide(texte),
        if (texte != Aides.generale) ...[
          const SizedBox(height: 4),
          InkWell(
            key: const ValueKey('aide-gestes'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => maj(() => gestes = !gestes),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icone(Icons.swipe_outlined, size: 28, color: Charte.cadre),
                const SizedBox(width: 10),
                Expanded(child: Text('Gestes communs', style: Charte.texte(15, gras: true))),
                Icone(gestes ? Icons.expand_less : Icons.expand_more, size: 24),
              ]),
            ),
          ),
          if (gestes) ..._pointsAide(Aides.gestes),
        ],
      ],
    ),
  );
}

/// Icônes des points d'aide, par leur nom dans les textes de [Aides].
const _iconesAide = <String, IconData>{
  'accueil': Icons.home_outlined,
  'liste': Icons.checklist,
  'ajout': Icons.playlist_add,
  'chariot': Icons.shopping_cart_outlined,
  'gerer': Icons.settings_outlined,
  'recette': Icons.restaurant_menu_outlined,
  'magasin': Icons.storefront_outlined,
  'pause': Icons.pause_circle_outline,
  'ticket': Icons.receipt_long_outlined,
  'historique': Icons.history,
  'archives': Icons.inventory_2_outlined,
  'corbeille': Icons.delete_outline,
  'crayon': Icons.edit_outlined,
  'plus': Icons.add,
  'livre': Icons.menu_book_outlined,
  'monde': Icons.public,
  'parcours': Icons.route_outlined,
  'foyer': Icons.groups_outlined,
  'membre': Icons.person_outline,
  'fini': Icons.check_circle_outline,
  'drapeau': Icons.flag_outlined,
  'annuler': Icons.undo,
  'fichier': Icons.upload_file_outlined,
  'mail': Icons.mail_outline,
  'envoi': Icons.send,
  'calendrier': Icons.calendar_month_outlined,
  'promo': Icons.local_offer_outlined,
  'mesure': Icons.scale_outlined,
  'recherche': Icons.search,
  'nuage': Icons.cloud_outlined,
  'message': Icons.chat_outlined,
  'cle': Icons.key_outlined,
  'palette': Icons.palette_outlined,
  'alerte': Icons.warning_amber_rounded,
  'info': Icons.info_outline,
  'donnees': Icons.storage_outlined,
  'maison': Icons.add_home_outlined,
  'porte': Icons.login,
  'copier': Icons.copy,
  'cloche': Icons.notifications_active_outlined,
  'calcul': Icons.calculate_outlined,
  'rayons': Icons.category_outlined,
  'voir': Icons.visibility_outlined,
  'interdit': Icons.block,
  'glisser': Icons.swipe_outlined,
  'toucher': Icons.touch_app_outlined,
  'volet': Icons.expand_more,
  'menu': Icons.more_vert,
  'lot': Icons.local_mall_outlined,
};

List<Widget> _pointsAide(String texte) => [
      for (final l in texte.split('\n'))
        if (l.split('|') case [final i, final t, final p])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 30, child: Icone(_iconesAide[i] ?? Icons.info_outline, size: 28, color: Charte.cadre)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$t\n', style: Charte.texte(15, gras: true)),
                  TextSpan(text: p, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ])),
              ),
            ]),
          )
        else if (l.trim().isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(l, style: Charte.texte(15))),
    ];

/// Textes d'aide des fenêtres (toucher le titre › Aide, ou la bouée en haut à droite).
/// Une ligne par point : « icône|Titre court|Une phrase courte ». Les gestes communs s'ajoutent repliés.
class Aides {
  Aides._();

  static const gestes = 'glisser|Changer d\'onglet|Glissez le doigt à gauche ou à droite sur le haut de l\'écran ou sur une zone libre.\n'
      'toucher|Toucher une ligne|Ouvre son volet en bas : le détail, puis les actions.\n'
      'annuler|Glisser une ligne à gauche|La supprime ; « Annuler » apparaît quelques secondes en bas.\n'
      'fini|Glisser une ligne à droite|Fait son action principale.\n'
      'menu|Toucher le titre ou un bandeau|Propose les actions de la fenêtre ou du groupe.\n'
      'volet|Fermer un volet|Tirez la poignée vers le bas, ou touchez à côté.\n'
      'nuage|Le nuage|Barré : la synchronisation du foyer n\'est pas active.';

  static const generale = 'accueil|Accueil|Ce qui est en cours : listes, courses, recettes choisies.\n'
      'recette|Recettes|Choisir des recettes et ajouter leurs ingrédients à une liste.\n'
      'liste|Préparer|Construire les listes avant les courses.\n'
      'chariot|Courses|Faire les courses, puis retrouver les courses finies.\n'
      'gerer|Gérer (engrenage)|Foyer, magasins, catalogues et paramètres.\n'
      '$gestes';

  static const accueil = 'liste|Comment ça marche|Les quatre étapes ; touchez-en une pour son explication.\n'
      'crayon|En préparation|Les listes en construction.\n'
      'chariot|À faire|Les listes prêtes pour les courses.\n'
      'pause|Courses en cours|Les courses mises en pause, à reprendre.\n'
      'recette|Recettes choisies|Touchez pour cuisiner ; appui long pour effacer.\n'
      'fini|Terminées|Les courses faites, repliées.\n'
      'gerer|Engrenage, en bas|Ouvre Gérer.';

  static const preparer = 'plus|Nouvelle liste|Choisissez le magasin, puis la façon de remplir la liste.\n'
      'crayon|En préparation|Touchez une liste pour la reprendre, la renommer ou la supprimer.\n'
      'chariot|Prêtes pour les courses|Glissez à droite pour la remettre en préparation.';

  static const courses = 'chariot|À faire|Touchez une liste puis « Faire les courses ».\n'
      'pause|En cours|Les courses mises en pause, à reprendre.\n'
      'fini|Terminées|Joignez le ticket ; glissez à droite pour l\'historique.\n'
      'ticket|Ticket du magasin|« Partager » vers Emplettes, ou ouvrez le PDF avec Emplettes.\n'
      'historique|Historique et archives|Voir le ticket, en faire une liste type, archiver.\n'
      'archives|Archives|Les courses de plus de trois mois (réglable dans Données).';

  static const gerer = 'foyer|Mon foyer|Seul ou partagé, membres, invitations et code.\n'
      'message|Collaboration|Notifications, mails et synchronisation du foyer.\n'
      'magasin|Magasins|Vos magasins et leurs parcours appris.\n'
      'rayons|Catalogues|Produits et marques, les mêmes dans tous les magasins.\n'
      'promo|Types|Promotions, mesures (poids, volume, pièce) et packagings.\n'
      'palette|Paramètres|Apparence, données, corbeille.';

  static const nouvelleListe = 'magasin|Magasin et nom|Le nom est proposé ; deux listes ne peuvent pas avoir le même.\n'
      'rayons|Par secteur|Cherchez les articles, ils se rangent sous leur secteur.\n'
      'liste|Liste simple|Les articles restent dans l\'ordre de saisie.\n'
      'livre|Liste type|Une liste enregistrée sous un nom, ou une liste vide.\n'
      'fini|Achats habituels|Tout est coché ; décochez l\'inutile.\n'
      'historique|Course passée|Cochez les articles à reprendre.\n'
      'fichier|Depuis un texte|Collez un mail ou une note ; les articles sont reconnus.\n'
      'ajout|Compléter des courses|Des articles à ajouter à des courses en cours.';

  static const preparation = 'recherche|Rechercher|Tapez trois lettres, touchez l\'article : il s\'ajoute.\n'
      'plus|Absent du catalogue|Touchez « Créer « … » ».\n'
      'recette|Recette|Cochez les ingrédients voulus ; ils s\'ajoutent « pour : » la recette.\n'
      'calcul|− et +|Règlent la quantité ; à 0, l\'article est retiré.\n'
      'toucher|Toucher la ligne|Packaging, consigne, promotion, marque.\n'
      'fini|Liste prête|Valide la liste : commentaire, liste type, mail.';

  static const listeSimple = 'liste|Ordre de saisie|Pas de secteurs : les articles s\'ajoutent en fin de liste.\n'
      'recherche|Rechercher|Tapez trois lettres, touchez l\'article ; « Créer » s\'il manque.\n'
      'calcul|− et +|Règlent la quantité.\n'
      'fini|Liste prête|« Ranger par rayons et secteurs » pour suivre le magasin.';

  static const enMagasin = 'fini|La case à gauche|Touchez-la quand l\'article est dans le chariot.\n'
      'alerte|Deux touches|L\'article est absent du rayon : marqué « manquant ».\n'
      'voir|Appui long|Montre le détail de l\'article quelques secondes.\n'
      'pause|Pause|Interrompt les courses sans rien perdre.\n'
      'drapeau|Terminer|Montre les manquants, puis range la course.\n'
      'parcours|Parcours|L\'ordre où vous cochez apprend le magasin.\n'
      'interdit|Liste figée|Pendant les courses, seule la case réagit.';

  static const foyer = 'foyer|Foyer|Seul sur cet appareil, ou partagé avec d\'autres.\n'
      'cle|Code de partage|À saisir sur un autre appareil pour rejoindre le foyer.\n'
      'membre|Membres|Touchez un membre pour l\'inviter, le renommer ou le retirer.\n'
      'maison|Appareil partagé|On choisit son nom à chaque lancement.\n'
      'mail|Mails|Envoyer une liste à tout le foyer.\n'
      'monde|Catalogue|Commun à tous les foyers ; vos ajouts restent chez vous.';

  static const collaboration = 'membre|Membres|Touchez un membre pour ses notifications et mails.\n'
      'cloche|Notification|Part à tous les membres du foyer.\n'
      'mail|Mail|Montre le mail envoyé et la réponse du service.\n'
      'info|Application fermée|Titre › « Recevoir les notifications sur cet appareil ».\n'
      'nuage|Synchronisation|L\'état des échanges entre les appareils.';

  static const historiqueMembre = 'historique|Journal|Notifications et mails du membre, du plus récent au plus ancien.\n'
      'info|Sur cet appareil|Le journal n\'est gardé qu\'ici.';

  static const magasins = 'magasin|Vos magasins|Tous ont le même catalogue.\n'
      'toucher|Toucher un magasin|Ses parcours, le renommer, le supprimer.\n'
      'corbeille|Supprimer|Efface parcours et listes en cours ; l\'historique va aux archives.';

  static const typesPromotion = 'promo|Types de promotion|Proposés pour une ligne en promotion.\n'
      'toucher|Toucher un type|Le modifier ou le supprimer.\n'
      'plus|Nouveau type|En touchant le titre.\n'
      'palette|Couleur|Gérer › Paramètres › Apparence.';

  static const typesMesure = 'mesure|Mesures|Poids (g, kg), volume (cl, l) ou à la pièce.\n'
      'toucher|Toucher une mesure|La modifier, voir ses articles, la supprimer.\n'
      'plus|Nouvelle mesure|En touchant le titre.\n'
      'palette|Couleur|Gérer › Paramètres › Apparence.';

  static const typesPackaging = 'lot|Packagings|Surtout des lots de 2 à 10.\n'
      'toucher|Toucher un packaging|Le modifier, voir ses articles, le supprimer.\n'
      'plus|Nouveau packaging|En touchant le titre.\n'
      'palette|Couleur|Gérer › Paramètres › Apparence.';

  static const catalogue = 'rayons|Un seul catalogue|Rayons, secteurs et produits, les mêmes partout.\n'
      'toucher|Toucher un secteur|Voir ses produits, en ajouter un.\n'
      'promo|Marque|« Ajouter une marque » sans créer de produit.\n'
      'plus|Petit +|Signale un produit ajouté par le foyer.\n'
      'crayon|Crayon|Modifier un rayon ou un secteur.';

  static const marques = 'promo|Marques par secteur|Seuls les secteurs qui en ont paraissent.\n'
      'toucher|Toucher une marque|La modifier ou la renommer partout.\n'
      'corbeille|Retirer|Poubelle ou glissement à gauche.\n'
      'plus|Nouvelle marque|En fin de secteur ou par le titre.';

  static const parcours = 'parcours|Parcours appris|L\'ordre des secteurs, par membre et par magasin.\n'
      'fini|Tout seul|Il se complète à chaque course.';

  static const historique = 'historique|Courses terminées|Par date ou par magasin.\n'
      'ticket|Toucher une course|Voir ses articles ou son ticket.';
}
