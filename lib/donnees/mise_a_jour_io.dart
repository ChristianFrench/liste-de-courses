// Mise à jour, Android et Windows : téléchargement puis installation (voir mise_a_jour.dart).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dossier_application.dart';

String get systeme => Platform.isAndroid ? 'android' : (Platform.isWindows ? 'windows' : Platform.operatingSystem);

Future<void> recharger() async {}

/// Rend « ok », « autorisation » (Android : réglage à donner) ou la raison de l'échec.
Future<String> telechargerEtInstaller(Uri url, String nom, void Function(double) progression) async {
  final dossier = Platform.isAndroid
      ? Directory('${(await dossierApplication()).path}${Platform.pathSeparator}mise-a-jour')
      : Directory('${Directory.systemTemp.path}${Platform.pathSeparator}emplettes-mise-a-jour');
  if (!dossier.existsSync()) dossier.createSync(recursive: true);
  final fichier = File('${dossier.path}${Platform.pathSeparator}$nom');
  final client = http.Client();
  try {
    final reponse = await client.send(http.Request('GET', url));
    if (reponse.statusCode != 200) return 'fichier introuvable sur le serveur (${reponse.statusCode})';
    final total = reponse.contentLength ?? 0;
    var recu = 0;
    final sortie = fichier.openWrite();
    await for (final morceau in reponse.stream) {
      sortie.add(morceau);
      recu += morceau.length;
      if (total > 0) progression(recu / total);
    }
    await sortie.close();
  } finally {
    client.close();
  }
  if (Platform.isAndroid) {
    return await const MethodChannel('fr.listecourses/ticket').invokeMethod<String>('installerApk', fichier.path) ?? 'erreur';
  }
  if (Platform.isWindows) {
    // L'installateur ferme l'application (CloseApplications=force), la remplace et la rouvre.
    await Process.start(fichier.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
    exit(0);
  }
  return 'système non pris en charge';
}
