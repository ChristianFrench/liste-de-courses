import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ListeDeCoursesApp());

const vert = Color(0xFF2E7D32);

class ListeDeCoursesApp extends StatelessWidget {
  const ListeDeCoursesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liste de courses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: vert, useMaterial3: true),
      home: const EcranAccueil(),
      builder: (context, enfant) => FormatTelephone(child: enfant!),
    );
  }
}

/// Taille de référence de l'écran, identique sur toutes les versions.
const tailleTelephone = Size(412, 892);

/// Sous Windows, l'application est dessinée sur un écran virtuel de téléphone
/// (412 × 892) puis agrandie ou réduite pour remplir la fenêtre : la mise en page
/// est ainsi strictement celle du téléphone. Sur téléphone, rien ne change.
class FormatTelephone extends StatelessWidget {
  const FormatTelephone({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return child;
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: Colors.white,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: tailleTelephone,
          child: MediaQuery(
            data: media.copyWith(size: tailleTelephone, padding: EdgeInsets.zero),
            child: child,
          ),
        ),
      ),
    );
  }
}

String nomPlateforme() {
  if (kIsWeb) return 'Web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iPhone';
    case TargetPlatform.windows:
      return 'Windows';
    default:
      return defaultTargetPlatform.name;
  }
}

class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icone_ronde.png', width: 200, height: 200),
            const SizedBox(height: 24),
            const Text(
              'Liste de courses',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 0.2 — étape 1 (Flutter)',
              style: TextStyle(fontSize: 16, color: Color(0xFF546E7A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Plateforme : ${nomPlateforme()}',
              style: const TextStyle(fontSize: 16, color: Color(0xFF546E7A)),
            ),
          ],
        ),
      ),
    );
  }
}
