import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'donnees/catalogue_off.dart';
import 'donnees/modele.dart';
import 'ecrans/e01_accueil.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Etat.instance.charger();
  // Catalogue Open Food Facts : chargé en arrière-plan, mis à jour selon le délai réglé
  CatalogueOff.instance.demarrer();
  runApp(const ListeDeCoursesApp());
}

class ListeDeCoursesApp extends StatelessWidget {
  const ListeDeCoursesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liste de courses',
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const EcranAccueil(),
      builder: (context, enfant) => FormatTelephone(child: enfant!),
    );
  }
}

/// Taille de référence de l'écran (spécification IHM : 390 × 844), identique sur toutes les versions.
const tailleTelephone = Size(390, 844);

/// Sous Windows, l'application est dessinée sur un écran virtuel de téléphone
/// (390 × 844) puis agrandie ou réduite pour remplir la fenêtre : la mise en page
/// est ainsi strictement celle du téléphone. Sur téléphone, seule la taille des
/// caractères choisie dans les réglages est bornée, pour éviter les textes coupés.
class FormatTelephone extends StatelessWidget {
  const FormatTelephone({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bornee = media.copyWith(
      textScaler: media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15),
    );
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return MediaQuery(data: bornee, child: child);
    }
    return ColoredBox(
      color: Colors.white,
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
