import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ecrans/historique.dart' show recevoirTicketPdf;
import '../navigation.dart';

/// Réception des tickets de caisse PDF envoyés par une autre application (Android : « Partager »,
/// « Ouvrir avec » depuis les téléchargements). Le code Android (outils/android/MainActivity.kt) copie
/// le PDF et en donne le chemin sur le canal « fr.listecourses/ticket ».
class TicketRecu {
  TicketRecu._();
  static const _canal = MethodChannel('fr.listecourses/ticket');

  static void demarrer() {
    _canal.setMethodCallHandler((appel) async {
      if (appel.method == 'ticket' && appel.arguments is String) _traiter(appel.arguments as String);
    });
    // Application lancée par le partage : le ticket attend que le premier écran soit affiché.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final chemin = await _canal.invokeMethod<String>('ticketRecu');
        if (chemin != null) _traiter(chemin);
      } on MissingPluginException {
        // Windows, iPhone : pas encore de réception par partage (le bouton « Joindre le ticket PDF » reste).
      } on PlatformException {
        // idem
      }
    });
  }

  static void _traiter(String chemin) {
    if (chemin.isEmpty) return;
    final c = Nav.i.racine.currentContext;
    if (c == null || !c.mounted) return;
    recevoirTicketPdf(c, chemin);
  }
}
