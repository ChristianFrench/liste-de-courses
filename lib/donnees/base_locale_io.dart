import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Dossier des bases : [dossier] (essais) ou celui de l'application.
Future<String> preparerDossierBases(String? dossier) async {
  final d = dossier != null ? Directory(dossier) : await getApplicationSupportDirectory();
  if (!d.existsSync()) d.createSync(recursive: true);
  return d.path;
}

String cheminBase(String dossier, String nom) => '$dossier${Platform.pathSeparator}$nom';

CommonDatabase ouvrirBase(String chemin) => sqlite3.open(chemin);

bool baseExiste(String chemin) => File(chemin).existsSync();

/// La base doit être fermée.
Future<void> renommerBase(String de, String vers) async => File(de).renameSync(vers);
