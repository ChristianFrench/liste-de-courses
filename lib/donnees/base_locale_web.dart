import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

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

/// Met de côté une base illisible (abîmée) : copie octet par octet, puis suppression de l'original.
Future<void> mettreDeCote(String de, String vers) async {
  final f = _fichiers!;
  const lecture = SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_MAIN_DB;
  const creation = lecture | SqlFlag.SQLITE_OPEN_CREATE;
  final source = f.xOpen(Sqlite3Filename(de), lecture).file;
  final copie = f.xOpen(Sqlite3Filename(vers), creation).file;
  try {
    final octets = Uint8List(source.xFileSize());
    source.xRead(octets, 0);
    copie.xWrite(octets, 0);
  } finally {
    source.xClose();
    copie.xClose();
  }
  for (final x in [de, '$de-journal', '$de-wal']) {
    if (f.xAccess(x, 0) != 0) f.xDelete(x, 0);
  }
  await f.flush();
}

// Une seule instance de l'application par navigateur (29/10/2026) : deux onglets, ou l'icône de l'écran
// d'accueil et un onglet, écrivant chacun de son côté dans la même base l'ont abîmée. Verrou « Web Locks » :
// gardé tant que la page est ouverte, rendu par le navigateur quand elle se ferme.
@JS('navigator.locks')
external _Verrous? get _verrous;

extension type _Verrous._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(String nom, JSObject options, JSFunction rappel);
}

/// true si cette page a la main sur la base ; false si l'application est déjà ouverte ailleurs dans ce navigateur.
Future<bool> prendreVerrou() async {
  final verrous = _verrous;
  if (verrous == null) return true; // navigateur trop ancien : pas de protection
  final obtenu = Completer<bool>();
  JSPromise<JSAny?> rappel(JSAny? verrou) {
    obtenu.complete(verrou != null);
    // Tenu jusqu'à la fermeture de la page : une promesse qui ne se termine jamais.
    return verrou == null ? Future<JSAny?>.value(null).toJS : Completer<JSAny?>().future.toJS;
  }

  verrous.request('liste-de-courses-base', {'ifAvailable': true}.jsify() as JSObject, rappel.toJS);
  return obtenu.future;
}
