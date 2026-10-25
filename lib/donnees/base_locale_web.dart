import 'package:sqlite3/wasm.dart';

// Dans le navigateur, les bases sont rangées dans IndexedDB par sqlite3 compilé en WebAssembly
// (web/sqlite3.wasm).
WasmSqlite3? _sqlite;
IndexedDbFileSystem? _fichiers;

Future<String> preparerDossierBases(String? dossier) async {
  if (_sqlite == null) {
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final fichiers = await IndexedDbFileSystem.open(dbName: 'liste_de_courses');
    sqlite.registerVirtualFileSystem(fichiers, makeDefault: true);
    _sqlite = sqlite;
    _fichiers = fichiers;
  }
  return '';
}

String cheminBase(String dossier, String nom) => '/$nom';

CommonDatabase ouvrirBase(String chemin) => _sqlite!.open(chemin);

bool baseExiste(String chemin) => _fichiers!.xAccess(chemin, 0) != 0;

/// La base doit être fermée. IndexedDB ne sait pas renommer : copie puis suppression.
Future<void> renommerBase(String de, String vers) async {
  final db = _sqlite!.open(de);
  try {
    db.execute('VACUUM INTO ?', [vers]);
  } finally {
    db.dispose();
  }
  _fichiers!.xDelete(de, 0);
  await _fichiers!.flush();
}
