import 'dart:io';


import 'dossier_application.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Dossier des bases : [dossier] (essais) ou celui de l'application.
Future<String> preparerDossierBases(String? dossier) async {
  final d = dossier != null ? Directory(dossier) : await dossierApplication();
  if (!d.existsSync()) d.createSync(recursive: true);
  return d.path;
}

/// Rien à retirer hors du navigateur.
void retirerEcranOuverture() {}

String cheminBase(String dossier, String nom) => '$dossier${Platform.pathSeparator}$nom';

CommonDatabase ouvrirBase(String chemin) => sqlite3.open(chemin);

bool baseExiste(String chemin) => File(chemin).existsSync();

/// La base doit être fermée.
Future<void> renommerBase(String de, String vers) async => File(de).renameSync(vers);

/// Met de côté une base illisible (abîmée).
Future<void> mettreDeCote(String de, String vers) async {
  File(de).renameSync(vers);
  for (final x in ['$de-journal', '$de-wal']) {
    if (File(x).existsSync()) File(x).deleteSync();
  }
}

/// Sur Windows et Android, une seule instance de l'application : pas de verrou à prendre.
Future<bool> prendreVerrou() async => true;

/// Sur disque, SQLite écrit directement : rien à attendre.
Future<void> ecrireSurDisque() async {}

/// Journal de l'appareil, à côté des bases.
String lireJournal(String d) {
  final f = File('$d${Platform.pathSeparator}journal.txt');
  return f.existsSync() ? f.readAsStringSync() : '';
}

void ecrireJournal(String d, String texte) {
  try {
    File('$d${Platform.pathSeparator}journal.txt').writeAsStringSync(texte);
  } catch (_) {}
}
