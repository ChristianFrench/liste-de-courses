import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'dossier_application.dart';
import 'demonstration.dart';

// Où sont rangées les copies de sauvegarde (Android et Windows ; le navigateur : sauvegarde_depot_web.dart).
// Windows : Documents\Emplettes, hors du dossier de l'application.
// Android : dans l'application, et une copie de chaque fichier dans Documents/Emplettes du téléphone
// (MediaStore, sans autorisation), qui reste après une désinstallation.

const _canal = MethodChannel('fr.listecourses/ticket');

/// Dossier imposé par les essais.
String? dossierSauvegardesEssai;

Future<Directory> _dossier() async {
  final String base;
  if (dossierSauvegardesEssai != null) {
    base = dossierSauvegardesEssai!;
  } else if (Platform.isWindows) {
    base = '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}${outilEditeur ? 'Emplettes editeur' : 'Emplettes'}';
  } else {
    base = '${(await dossierApplication()).path}${Platform.pathSeparator}sauvegardes';
  }
  final d = Directory(base);
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// Où l'on trouve les copies, pour le dire à la personne.
Future<String> emplacementCopies() async {
  if (Platform.isAndroid) return 'Documents/Emplettes du téléphone';
  return (await _dossier()).path;
}

/// Les copies : nom et contenu.
Future<Map<String, String>> lireCopies() async {
  final d = await _dossier();
  final res = <String, String>{};
  for (final f in d.listSync().whereType<File>()) {
    final nom = f.uri.pathSegments.last;
    if (!nom.endsWith('.emplettes')) continue;
    try {
      res[nom] = await f.readAsString();
    } catch (_) {}
  }
  return res;
}

Future<void> ecrireCopie(String nom, String contenu) async {
  final d = await _dossier();
  final f = File('${d.path}${Platform.pathSeparator}$nom');
  await File('${f.path}.tmp').writeAsString(contenu, flush: true);
  await File('${f.path}.tmp').rename(f.path);
  if (Platform.isAndroid && dossierSauvegardesEssai == null) {
    try {
      await _canal.invokeMethod<bool>('copieDocuments', {'nom': nom, 'chemin': f.path});
    } catch (_) {}
  }
}

Future<void> effacerCopie(String nom) async {
  final d = await _dossier();
  final f = File('${d.path}${Platform.pathSeparator}$nom');
  if (f.existsSync()) await f.delete();
  if (Platform.isAndroid && dossierSauvegardesEssai == null) {
    try {
      await _canal.invokeMethod<bool>('effacerDocument', {'nom': nom});
    } catch (_) {}
  }
}

/// « Sauvegarder maintenant » : Windows demande où enregistrer le fichier ; Android le propose aux autres
/// applications (Drive, mail, Fichiers…). Rend vrai si le fichier est parti.
Future<bool> exporterFichier(String nom, String contenu) async {
  if (Platform.isAndroid) {
    final d = Directory('${(await dossierApplication()).path}${Platform.pathSeparator}envoi');
    if (!d.existsSync()) d.createSync(recursive: true);
    final f = File('${d.path}${Platform.pathSeparator}$nom');
    await f.writeAsString(contenu, flush: true);
    return await _canal.invokeMethod<bool>('partagerFichier', {'chemin': f.path, 'titre': 'Sauvegarde Emplettes'}) ?? false;
  }
  final ou = await getSaveLocation(suggestedName: nom, acceptedTypeGroups: const [
    XTypeGroup(label: 'Sauvegarde Emplettes', extensions: ['emplettes']),
  ]);
  if (ou == null) return false;
  await File(ou.path).writeAsString(contenu, flush: true);
  return true;
}

/// « Depuis un fichier… » : le contenu du fichier choisi.
Future<String?> importerFichier() async {
  final x = await openFile();
  if (x == null) return null;
  return x.readAsString();
}
