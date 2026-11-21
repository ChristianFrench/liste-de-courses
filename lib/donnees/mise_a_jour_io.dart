// Mise à jour, Android et Windows : téléchargement puis installation (voir mise_a_jour.dart).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dossier_application.dart';

String get systeme => Platform.isAndroid ? 'android' : (Platform.isWindows ? 'windows' : Platform.operatingSystem);

Future<void> recharger() async {}

/// Rend « ok », « autorisation » (Android : réglage à donner) ou la raison de l'échec.
Future<String> telechargerEtInstaller(Uri url, String nom, Map<String, String> entetes, void Function(double) progression) async {
  const canal = MethodChannel('fr.listecourses/ticket');
  // Android : l'autorisation d'installer d'abord (le réglage s'ouvre ; on reprend au retour, sans retélécharger).
  if (Platform.isAndroid && !(await canal.invokeMethod<bool>('peutInstaller') ?? false)) return 'autorisation';
  final dossier = Platform.isAndroid
      ? Directory('${(await dossierApplication()).path}${Platform.pathSeparator}mise-a-jour')
      : Directory('${Directory.systemTemp.path}${Platform.pathSeparator}emplettes-mise-a-jour');
  if (!dossier.existsSync()) dossier.createSync(recursive: true);
  final fichier = File('${dossier.path}${Platform.pathSeparator}$nom');
  // Déjà téléchargé en entier (même version) : pas de second téléchargement. Les anciennes versions sont effacées.
  for (final f in dossier.listSync().whereType<File>()) {
    if (f.path != fichier.path) f.deleteSync();
  }
  if (!fichier.existsSync()) await _telecharger(url, entetes, fichier, progression);
  if (Platform.isAndroid) {
    return await canal.invokeMethod<String>('installerApk', fichier.path) ?? 'erreur';
  }
  if (Platform.isWindows) {
    // L'installateur ferme l'application (CloseApplications=force), la remplace et la rouvre.
    await Process.start(fichier.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
    exit(0);
  }
  return 'système non pris en charge';
}

/// Téléchargement dans un fichier « .partiel », renommé une fois complet.
Future<void> _telecharger(Uri url, Map<String, String> entetes, File fichier, void Function(double) progression) async {
  final partiel = File('${fichier.path}.partiel');
  final client = http.Client();
  try {
    final reponse = await client.send(http.Request('GET', url)..headers.addAll(entetes));
    if (reponse.statusCode != 200) throw Exception('fichier introuvable sur le serveur (${reponse.statusCode})');
    final total = reponse.contentLength ?? 0;
    var recu = 0;
    final sortie = partiel.openWrite();
    await for (final morceau in reponse.stream) {
      sortie.add(morceau);
      recu += morceau.length;
      if (total > 0) progression(recu / total);
    }
    await sortie.close();
    if (total > 0 && recu != total) throw Exception('téléchargement incomplet');
    partiel.renameSync(fichier.path);
  } finally {
    client.close();
  }
}
