import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'donnees/catalogue_off.dart';
import 'donnees/modele.dart';
import 'donnees/synchro.dart';
import 'donnees/ticket_recu.dart';
import 'ecrans/coquille.dart';
import 'navigation.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Etat.instance.charger();
  if (Etat.instance.apparence != null) Charte.choisirPalette(Etat.instance.apparence!);
  // Catalogue Open Food Facts (écran d'essai) : chargé en arrière-plan ; pas dans le navigateur
  if (!kIsWeb) CatalogueOff.instance.demarrer();
  runApp(const ListeDeCoursesApp());
  if (!kIsWeb) TicketRecu.demarrer();
  // Partage du foyer entre appareils (si cet appareil partage)
  Synchro.instance.demarrer();
}

class ListeDeCoursesApp extends StatelessWidget {
  const ListeDeCoursesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liste de courses',
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
      home: const Coquille(),
      builder: (context, enfant) => CallbackShortcuts(
        // Sous Windows, Échap = retour système
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Nav.i.racine.currentState?.maybePop(),
        },
        child: Focus(autofocus: true, child: FormatTelephone(child: enfant!)),
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
