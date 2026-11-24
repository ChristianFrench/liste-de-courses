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

/// Page d'aide d'une fenêtre (24/11/2026, Aristide) : en titre la fonction de l'écran, puis ce que l'on voit
/// (« À l'écran ») et ce que l'on peut faire (« Vous pouvez »), en quelques points « icône, titre, phrase courte ».
/// Les gestes communs sont derrière l'icône en haut à droite. Format des textes : voir [Aides].
Future<void> montrerAide(BuildContext context, String titre, String texte) {
  final lignes = texte.split('\n');
  final fonction = lignes.isNotEmpty && !lignes.first.contains('|') && !lignes.first.startsWith('#') ? lignes.first : null;
  final points = fonction == null ? texte : lignes.skip(1).join('\n');
  var gestes = false;
  return volet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(gestes ? 'Gestes communs' : 'Aide · $titre', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                    Text(gestes ? 'Les gestes valables sur tous les écrans' : (fonction ?? titre), style: Charte.texte(19, gras: true)),
                  ]),
                ),
              ),
              Tooltip(
                message: gestes ? 'Revenir à l\'aide de l\'écran' : 'Gestes communs',
                child: InkWell(
                  key: const ValueKey('aide-gestes'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => maj(() => gestes = !gestes),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icone(gestes ? Icons.help_outline : Icons.swipe_outlined, size: 36),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _pointsAide(gestes ? Aides.gestes : points)),
                ),
              ),
            ),
          ],
        ),
      ),
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
        if (l.startsWith('#'))
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(l.substring(1), style: Charte.texte(14, gras: true, couleur: Charte.cadre)),
          )
        else if (l.split('|') case [final i, final t, final p])
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
/// 24/11/2026 (Aristide) : seulement l'écran affiché, jamais les onglets du bas. Première ligne = la fonction
/// de l'écran (le titre de l'aide) ; « #À l'écran » puis « #Vous pouvez » ; un point par ligne
/// « icône|Titre court|Une phrase courte » (icônes : `_iconesAide`). Les gestes communs sont à part ([gestes]).
class Aides {
  Aides._();

  static const gestes = "glisser|Changer d'onglet|Glissez le doigt à gauche ou à droite sur le haut de l'écran ou sur une zone libre.\n"
      "toucher|Toucher une ligne|Ouvre son volet en bas : le détail, puis les actions.\n"
      "annuler|Glisser une ligne à gauche|La supprime ; « Annuler » apparaît quelques secondes en bas.\n"
      "fini|Glisser une ligne à droite|Fait son action principale.\n"
      "menu|Toucher le titre ou un bandeau|Propose les actions de l'écran ou du groupe.\n"
      "volet|Fermer un volet|Tirez la poignée vers le bas, ou touchez à côté.\n"
      "nuage|Le nuage|Barré : la synchronisation du foyer n'est pas active.";

  static const generale = "Utiliser cet écran\n"
      "#Vous pouvez\n"
      "menu|Toucher le titre|Il propose les actions de cet écran.\n"
      "glisser|Voir les gestes|L'icône en haut à droite rappelle les gestes communs.";

  static const accueil = "Voir d'un coup d'œil ce qui est en cours\n"
      "#À l'écran\n"
      "liste|Comment ça marche|Les quatre étapes, de la recette aux courses.\n"
      "crayon|En préparation|Les listes en construction.\n"
      "chariot|À faire|Les listes prêtes pour les courses.\n"
      "pause|Courses en cours|Les courses mises en pause.\n"
      "recette|Recettes choisies|Les recettes dont les ingrédients sont dans une liste.\n"
      "fini|Terminées|Les courses faites, repliées.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une étape|Lire son explication.\n"
      "toucher|Toucher une liste|La reprendre, la valider ou faire les courses.\n"
      "recette|Toucher une recette|L'ouvrir pour cuisiner ; appui long pour l'effacer.\n"
      "#En bas de l'écran\n"
      "accueil|Accueil|Cet écran : ce qui est en cours.\n"
      "recette|Recettes|Choisir des recettes et noter leurs ingrédients.\n"
      "crayon|Préparer|Construire les listes avant les courses.\n"
      "chariot|Courses|Faire les courses, puis retrouver les courses finies.\n"
      "gerer|Engrenage|Gérer : foyer, magasins, catalogues, paramètres.";

  static const recettes = "Choisir des recettes et noter leurs ingrédients\n"
      "#À l'écran\n"
      "recherche|Recherche|Tapez un mot du titre ou d'un ingrédient.\n"
      "rayons|Filtres|Type, difficulté, temps, régime, saison, coût, cuisson, occasion, origine.\n"
      "livre|Types et sous-types|Des bandeaux pliables ; « notée » marque une recette déjà choisie.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une recette|Ouvrir sa fiche.\n"
      "volet|Tout déplier, tout replier|L'icône en haut à droite.";

  static const ficheRecette = "Lire une recette et ajouter ses ingrédients à une liste\n"
      "#À l'écran\n"
      "voir|Photo et caractéristiques|Personnes, temps, difficulté, saison…\n"
      "liste|Ingrédients|Avec leur quantité.\n"
      "livre|Recette|Les étapes, numérotées.\n"
      "#Vous pouvez\n"
      "ajout|Noter les ingrédients|Cocher ceux à acheter : ils iront dans la liste en préparation.\n"
      "corbeille|Retirer|Enlever la recette de la note.";

  static const preparer = "Construire les listes avant les courses\n"
      "#À l'écran\n"
      "crayon|En préparation|Les listes en construction.\n"
      "chariot|Prêtes pour les courses|Les listes validées.\n"
      "#Vous pouvez\n"
      "plus|Nouvelle liste|Choisir le magasin, puis la façon de remplir la liste.\n"
      "toucher|Toucher une liste|La reprendre, la renommer ou la supprimer.\n"
      "annuler|Glisser une liste prête à droite|La remettre en préparation.";

  static const courses = "Suivre les courses, de la liste prête au ticket\n"
      "#À l'écran\n"
      "chariot|À faire|Les listes prêtes.\n"
      "pause|En cours|Les courses mises en pause.\n"
      "fini|Terminées|Les courses faites ; une icône signale le ticket joint.\n"
      "#Vous pouvez\n"
      "chariot|Faire les courses|Toucher une liste à faire.\n"
      "ticket|Joindre le ticket|Toucher une course terminée.\n"
      "historique|Ranger dans l'historique|Glisser une course terminée à droite.\n"
      "envoi|Recevoir un ticket|Depuis l'appli du magasin : « Partager » vers Emplettes.";

  static const gerer = "Régler ce qui sert une fois pour toutes\n"
      "#À l'écran\n"
      "foyer|Mon foyer|Le foyer, ses membres, la collaboration.\n"
      "magasin|Courses|Magasins, catalogues des produits et des marques, types.\n"
      "palette|Paramètres|Apparence, données, corbeille.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une rubrique|L'ouvrir.";

  static const nouvelleListe = "Créer une liste pour un magasin\n"
      "#À l'écran\n"
      "magasin|Magasin et nom|Le nom est proposé ; il doit être unique.\n"
      "calendrier|Courses|Aujourd'hui, demain ou un autre jour.\n"
      "liste|Façons de remplir la liste|Une ligne par façon.\n"
      "#Vous pouvez\n"
      "rayons|Par secteur|Chercher les articles ; ils se rangent sous leur secteur.\n"
      "liste|Liste simple|Garder l'ordre de saisie.\n"
      "livre|Liste type|Partir d'une liste enregistrée, ou d'une liste vide.\n"
      "fini|Achats habituels|Tout est coché ; décocher l'inutile.\n"
      "historique|Course passée|Cocher les articles à reprendre.\n"
      "fichier|Depuis un texte|Coller un mail ou une note.\n"
      "ajout|Compléter des courses|Ajouter des articles à des courses en cours.";

  static const preparation = "Remplir la liste avant les courses\n"
      "#À l'écran\n"
      "recherche|Champ de recherche|Sous le titre.\n"
      "recette|Recettes choisies|En haut : les ingrédients à choisir ou à placer.\n"
      "rayons|La liste|Sous de minces bandeaux de secteur, dans l'ordre du parcours.\n"
      "promo|Sur une ligne|P = promotion, ×6 = packaging, puis la consigne.\n"
      "#Vous pouvez\n"
      "recherche|Ajouter un article|Taper trois lettres, toucher l'article.\n"
      "plus|Créer un article|« Créer « … » » s'il manque au catalogue.\n"
      "calcul|− et +|Régler la quantité ; à 0, l'article est retiré.\n"
      "toucher|Toucher une ligne|Packaging, consigne, promotion, marque.\n"
      "fini|Liste prête|Valider : commentaire, liste type, mail.";

  static const listeSimple = "Écrire une liste sans secteurs\n"
      "#À l'écran\n"
      "liste|La liste|Les articles dans l'ordre de saisie.\n"
      "#Vous pouvez\n"
      "recherche|Ajouter un article|Taper trois lettres ; « Créer » s'il manque.\n"
      "calcul|− et +|Régler la quantité.\n"
      "fini|Liste prête|« Ranger par rayons et secteurs » pour suivre le magasin.";

  static const enMagasin = "Cocher les articles en faisant les courses\n"
      "#À l'écran\n"
      "rayons|La liste|Dans l'ordre des allées, sous de minces bandeaux de secteur.\n"
      "interdit|Liste figée|Pendant les courses, seule la case réagit.\n"
      "#Vous pouvez\n"
      "fini|Toucher la case|L'article est dans le chariot.\n"
      "alerte|Toucher deux fois|L'article manque au rayon.\n"
      "interdit|Toucher trois fois|Pas besoin cette fois : tiret gris, nom barré.\n"
      "voir|Appui long|Le détail, avec « Pas besoin » et « Manquant en rayon ».\n"
      "pause|Pause|Interrompre sans rien perdre.\n"
      "drapeau|Terminer|Voir les manquants, puis ranger la course.";

  static const consultation = "Consulter une liste\n"
      "#À l'écran\n"
      "liste|Les articles|Sous leurs secteurs, avec quantité et consigne.\n"
      "#Vous pouvez\n"
      "menu|Toucher le titre|Reprendre, envoyer par mail ou supprimer la liste.";

  static const foyer = "Partager les listes avec les membres du foyer\n"
      "#À l'écran\n"
      "foyer|Foyer|Son nom ; seul sur cet appareil ou partagé.\n"
      "cle|Code de partage|À saisir sur un autre appareil.\n"
      "membre|Membres|Un point vert : en ligne.\n"
      "mail|Mails|Les adresses du foyer.\n"
      "#Vous pouvez\n"
      "membre|Toucher un membre|L'inviter, le renommer ou le retirer.\n"
      "copier|Toucher le code|Le copier ou le régénérer.\n"
      "menu|Toucher le titre|Nouveau membre, changer de personne.";

  static const collaboration = "Échanger avec les membres du foyer\n"
      "#À l'écran\n"
      "membre|Membres|Leurs notifications et mails.\n"
      "message|Communication|Notification et mail à tout le foyer.\n"
      "nuage|Synchronisation|L'état des échanges entre appareils.\n"
      "#Vous pouvez\n"
      "cloche|Envoyer une notification|Elle part à tous les membres.\n"
      "info|Être prévenu application fermée|Titre › « Recevoir les notifications sur cet appareil ».";

  static const historiqueMembre = "Voir les messages d'un membre\n"
      "#À l'écran\n"
      "historique|Journal|Notifications et mails, du plus récent au plus ancien.\n"
      "info|Sur cet appareil|Le journal n'est gardé qu'ici.";

  static const synchronisation = "Vérifier les échanges entre les appareils du foyer\n"
      "#À l'écran\n"
      "nuage|État|Le voyant et sa signification.\n"
      "membre|Appareils|Ceux du foyer, et leur dernière liaison.\n"
      "#Vous pouvez\n"
      "annuler|Tout renvoyer|Dans « Dépannage », si un appareil n'est pas à jour.";

  static const essaiMail = "Envoyer un mail au foyer\n"
      "#À l'écran\n"
      "mail|Le mail|Destinataires, sujet et texte.\n"
      "info|La réponse|Ce que le service d'envoi a répondu.";

  static const magasins = "Gérer vos magasins\n"
      "#À l'écran\n"
      "magasin|Vos magasins|Tous ont le même catalogue.\n"
      "#Vous pouvez\n"
      "toucher|Toucher un magasin|Voir ses parcours, le renommer, le supprimer.\n"
      "plus|Nouveau magasin|En touchant le titre.";

  static const parcours = "Voir l'ordre des secteurs appris dans ce magasin\n"
      "#À l'écran\n"
      "parcours|Parcours|Par membre ; il se complète à chaque course.";

  static const typesPromotion = "Définir les types de promotion\n"
      "#À l'écran\n"
      "promo|Types|Proposés pour une ligne en promotion.\n"
      "#Vous pouvez\n"
      "toucher|Toucher un type|Le modifier ou le supprimer.\n"
      "plus|Nouveau type|En touchant le titre.";

  static const typesMesure = "Définir les mesures des produits\n"
      "#À l'écran\n"
      "mesure|Mesures|Poids, volume ou pièce, et leur nombre d'articles.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une mesure|La modifier, voir ses articles, la supprimer.\n"
      "plus|Nouvelle mesure|En touchant le titre.";

  static const typesPackaging = "Définir les packagings\n"
      "#À l'écran\n"
      "lot|Packagings|Surtout des lots de 2 à 10.\n"
      "#Vous pouvez\n"
      "toucher|Toucher un packaging|Le modifier, voir ses articles, le supprimer.\n"
      "plus|Nouveau packaging|En touchant le titre.";

  static const catalogue = "Parcourir et compléter le catalogue des produits\n"
      "#À l'écran\n"
      "rayons|Rayons et secteurs|Des bandeaux pliables, les mêmes dans tous les magasins.\n"
      "plus|Petit +|Un produit ajouté par le foyer.\n"
      "#Vous pouvez\n"
      "toucher|Toucher un secteur|Voir ses produits, en ajouter un.\n"
      "toucher|Toucher un produit|Le modifier, le déplacer, lui ajouter une marque.\n"
      "crayon|Crayon|Modifier un rayon ou un secteur.";

  static const produit = "Voir et modifier un produit\n"
      "#À l'écran\n"
      "voir|Le produit|Son rayon, son secteur, ses marques, mesures et packagings.\n"
      "#Vous pouvez\n"
      "menu|Toucher le titre|Modifier, déplacer, ajouter une marque, masquer chez nous.";

  static const marques = "Gérer les marques de chaque secteur\n"
      "#À l'écran\n"
      "promo|Marques|Rangées par rayon et secteur, avec leur nombre.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une marque|La modifier ou la renommer partout.\n"
      "corbeille|Retirer|Poubelle ou glissement à gauche.\n"
      "plus|Nouvelle marque|En fin de secteur ou par le titre.";

  static const historique = "Retrouver les courses passées\n"
      "#À l'écran\n"
      "historique|Courses|Par date ou par magasin.\n"
      "#Vous pouvez\n"
      "ticket|Toucher une course|Voir son ticket, en faire une liste type, l'archiver.";

  static const archives = "Retrouver les courses anciennes\n"
      "#À l'écran\n"
      "archives|Archives|Les courses archivées, par date.\n"
      "#Vous pouvez\n"
      "historique|Toucher une course|La remettre en historique ou la supprimer.";

  static const ticket = "Voir le ticket de caisse d'une course\n"
      "#À l'écran\n"
      "ticket|Ticket|Le PDF, sa date et son montant.\n"
      "#Vous pouvez\n"
      "crayon|Toucher le titre|Corriger libellé et montant, ou l'ouvrir ailleurs.";

  static const apparence = "Choisir les couleurs et la présentation\n"
      "#À l'écran\n"
      "palette|Palettes|Celle de l'application et celle des promotions, mesures, packagings.\n"
      "voir|Aperçu|Le résultat, en direct.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une liste déroulante|Choisir une autre palette ou présentation.";

  static const donnees = "Régler la conservation des données\n"
      "#À l'écran\n"
      "donnees|Sauvegardes|Copies automatiques et restauration.\n"
      "fini|Achats habituels|Le seuil de présence dans vos courses.\n"
      "archives|Archives|Quand archiver, quand supprimer.\n"
      "#Vous pouvez\n"
      "toucher|Toucher une ligne|Changer son réglage.";

  static const sauvegardes = "Protéger vos données\n"
      "#À l'écran\n"
      "donnees|Copies|Les sauvegardes de l'appareil, de la plus récente à la plus ancienne.\n"
      "#Vous pouvez\n"
      "plus|Sauvegarder maintenant|Faire une copie tout de suite.\n"
      "annuler|Toucher une copie|La restaurer.\n"
      "fichier|Depuis un fichier|Restaurer une copie enregistrée ailleurs.";

  static const corbeille = "Récupérer ce qui a été supprimé\n"
      "#À l'écran\n"
      "corbeille|Éléments supprimés|Listes, produits, magasins…\n"
      "#Vous pouvez\n"
      "annuler|Toucher un élément|Le restaurer ou le supprimer pour de bon.\n"
      "menu|Toucher le titre|Vider la corbeille.";

  static const bienvenue = "Commencer avec Emplettes\n"
      "#Vous pouvez\n"
      "membre|Seul|Utiliser l'application sur cet appareil uniquement.\n"
      "foyer|Créer un foyer|Partager les listes avec d'autres.\n"
      "porte|Rejoindre un foyer|Saisir le code reçu d'un membre.";
}
