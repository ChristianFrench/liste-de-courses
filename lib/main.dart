import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'composants/composants.dart' show voletsEnFenetre;
import 'donnees/sauvegarde.dart';
import 'donnees/catalogue_commun.dart';
import 'donnees/recettes_recues.dart';
import 'donnees/demonstration.dart';
import 'donnees/messages.dart';
import 'donnees/modele.dart';
import 'donnees/base_locale.dart' show retirerEcranOuverture;
import 'donnees/ouverture.dart';
import 'donnees/reparation.dart';
import 'donnees/synchro.dart';
import 'donnees/ticket_recu.dart';
import 'ecrans/coquille.dart';
import 'ecrans/recettes.dart' show chercherRecette;
import 'composants/entete.dart' show EnTeteFenetre;
import 'ecrans/ouverture.dart';
import 'ecrans/outil_editeur.dart';
import 'navigation.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 21/11/2026 (Aristide) : la barre d'état d'Android visible par-dessus l'image du haut : icônes blanches sur
  // un léger voile sombre.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x40000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  // 12/11/2026 (Aristide) : l'écran d'abord, avec une fenêtre de progression, puis la lecture de la base.
  if (!outilEditeur) {
    // 20/11/2026 : l'icône recette de l'en-tête disparaît avec l'onglet « Cuisiner ».
    if (!Nav.avecCuisiner) EnTeteFenetre.chercherRecette = chercherRecette;
    ouvertureAffichee = true;
    runApp(const ListeDeCoursesApp(accueil: EcranOuverture()));
    WidgetsBinding.instance.addPostFrameCallback((_) => retirerEcranOuverture());
    // Sans attendre l'image : la base se charge (fichiers, sqlite) pendant que l'écran se dessine.
    etapeOuverture.value = (texte: 'Ouverture de la base', valeur: 0.25);
  }
  await Etat.instance.charger();
  // 12/11/2026 : emplacements effacés par la conversion de la version 511c095, replacés une fois.
  if (!outilEditeur && Etat.instance.stockageFoyer != null && emplacementsPerdus(Etat.instance)) {
    await annoncerEtape('Réparation des secteurs', 0.6);
    await reparerEmplacementsPerdus();
  }
  // 12/11/2026 : produits de même nom (libre-service / au comptoir) rangés deux fois dans le même secteur.
  if (!outilEditeur && Etat.instance.stockageFoyer != null) {
    try {
      Etat.instance.retenirHomonymes(await CatalogueCommun.instance.dernier());
      Etat.instance.corrigerHomonymes();
    } catch (e) {
      Etat.instance.noter('Homonymes du catalogue : $e');
    }
  }
  // Les images de l'accueil se décodent pendant la suite de la préparation.
  final images = ouvertureAffichee ? preparerImages() : Future<void>.value();
  Etat.instance.avertir = MessagesFoyer.instance.avertir;
  // Démonstration : ses trois magasins seulement (les magasins par enseigne alourdiraient chaque ouverture).
  if (!demonstration) await Etat.instance.ajouterMagasinsEnseignes();
  if (Etat.instance.apparence != null) Charte.choisirPalette(Etat.instance.apparence!);
  // Outil de l'éditeur du catalogue commun : rien d'autre que son écran (ni foyer, ni partage).
  if (outilEditeur) {
    await Etat.instance.chargerMarquesType();
    if (Synchro.instance.mode == '') await Synchro.instance.choisirSeul();
    // Le code secret est demandé à chaque lancement.
    CatalogueCommun.instance.verrouiller();
    voletsEnFenetre = true;
    runApp(const OutilEditeurApp());
    return;
  }
  // Démonstration : un foyer seul, sans partage ni catalogue commun (rien n'en sort, rien n'y entre)
  if (demonstration && Synchro.instance.mode == '') await Synchro.instance.choisirSeul();
  // Catalogue Open Food Facts (écran d'essai) : chargé en arrière-plan ; pas dans le navigateur
  // Sauvegarde aux jalons (pas dans la démonstration)
  Sauvegarde.actif = !demonstration;
  await annoncerEtape('Affichage', 0.9);
  await images;
  final avecOuverture = ouvertureAffichee;
  ouvertureAffichee = false;
  runApp(ListeDeCoursesApp(accueil: avecOuverture ? const AttenteImages(child: Coquille()) : null));
  // Marques et natures Open Food Facts (12/11/2026) : utiles à la recherche seulement, lues après la première
  // image au lieu de retarder l'ouverture (0,4 s dans le navigateur).
  WidgetsBinding.instance.addPostFrameCallback((_) => Future<void>.delayed(const Duration(milliseconds: 300), Etat.instance.chargerMarquesType));
  if (!kIsWeb) TicketRecu.demarrer();
  if (demonstration) {
    // Le catalogue commun du moment, embarqué à la compilation (rien n'est échangé avec le serveur).
    CatalogueCommun.instance.appliquerDemonstration();
    return;
  }
  // Partage du foyer entre appareils (si cet appareil partage)
  Synchro.instance.demarrer();
  // Catalogue commun : les nouveautés publiées par l'éditeur s'ajoutent au foyer
  CatalogueCommun.instance.verifier();
  // Catalogue des recettes (20/11/2026) : nouvelle version publiée par l'éditeur, puis ses images.
  RecettesRecues.instance.verifier();
}

/// L'outil de l'éditeur du catalogue commun : la même charte, un seul écran.
class OutilEditeurApp extends StatelessWidget {
  const OutilEditeurApp({super.key});

  @override
  Widget build(BuildContext context) => ListeDeCoursesApp(accueil: const EcranOutilEditeur(), titre: outilCatalogues ? 'Emplettes · catalogues' : 'Emplettes · administration');
}

class ListeDeCoursesApp extends StatelessWidget {
  const ListeDeCoursesApp({super.key, this.accueil, this.titre = 'Emplettes'});
  final Widget? accueil;
  final String titre;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: titre,
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(),
      scrollBehavior: Charte.defilement(),
      navigatorKey: Nav.i.racine,
      scaffoldMessengerKey: Nav.i.messager,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // L'accueil montre ce qui est en cours (préparations, courses) avec de quoi le reprendre.
      home: accueil ?? const Coquille(),
      builder: (context, enfant) => CallbackShortcuts(
        // Sous Windows, Échap = retour système
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Nav.i.racine.currentState?.maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: FormatTelephone(
            child: BarreEtatVisible(
              child: demonstration
                  ? Banner(message: 'DÉMO', location: BannerLocation.topEnd, color: const Color(0xFFC62828), child: enfant!)
                  : enfant!,
            ),
          ),
        ),
      ),
    );
  }
}

/// Taille de référence de l'écran (Charte.tokens.json : 390 × 844), identique sur toutes les versions.
const tailleTelephone = Size(390, 844);

/// Sous Windows, l'application est dessinée sur un écran virtuel de téléphone (390 × 844)
/// puis ajustée à la fenêtre (390 × 844 si l'écran le permet) ; de même dans le navigateur d'un PC.
/// Sur téléphone, seule la taille des caractères choisie dans les réglages est bornée, pour éviter
/// les textes coupés.
class FormatTelephone extends StatelessWidget {
  const FormatTelephone({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bornee = media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15));
    // Console d'administration (Windows) : toute la largeur de la fenêtre.
    if (outilEditeur) return child;
    final navigateurPc = kIsWeb && media.size.width > 600;
    if (!navigateurPc && (kIsWeb || defaultTargetPlatform != TargetPlatform.windows)) {
      return MediaQuery(data: bornee, child: child);
    }
    return ColoredBox(
      color: navigateurPc ? const Color(0xFFDDE5DF) : Colors.white,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: tailleTelephone,
          child: MediaQuery(
            data: bornee.copyWith(
              size: tailleTelephone,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 26/11/2026 (Aristide) : la barre d'état d'Android doit rester visible. Depuis Android 15, l'application
/// s'étend sous elle et sa couleur de fond est ignorée : un bandeau sombre est dessiné sous ses icônes blanches,
/// au-dessus de tout (en-têtes clairs, volets).
class BarreEtatVisible extends StatelessWidget {
  const BarreEtatVisible({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Stack(children: [
        child,
        if (haut > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: haut,
            child: const IgnorePointer(child: ColoredBox(color: Color(0x66000000))),
          ),
      ]),
    );
  }
}
