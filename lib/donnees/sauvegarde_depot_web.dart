import 'dart:convert';
import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';

import 'demonstration.dart';

// Copies de sauvegarde dans le navigateur (localStorage) : elles disparaissent si l'on efface les données
// du site ; seul le fichier téléchargé (« Sauvegarder maintenant ») protège alors.

String? dossierSauvegardesEssai;

@JS('localStorage')
external _Stockage? get _local;

extension type _Stockage._(JSObject _) implements JSObject {
  external String? getItem(String cle);
  external void setItem(String cle, String valeur);
  external void removeItem(String cle);
}

String get _prefixe => demonstration ? 'ldc_demo_sauvegarde/' : 'ldc_sauvegarde/';
String get _index => '${_prefixe}index';

List<String> _noms() {
  try {
    return [for (final x in jsonDecode(_local?.getItem(_index) ?? '[]') as List) x as String];
  } catch (_) {
    return [];
  }
}

void _definirNoms(List<String> noms) => _local?.setItem(_index, jsonEncode(noms));

Future<String> emplacementCopies() async => 'ce navigateur';

Future<Map<String, String>> lireCopies() async {
  final res = <String, String>{};
  for (final n in _noms()) {
    final c = _local?.getItem('$_prefixe$n');
    if (c != null) res[n] = c;
  }
  return res;
}

Future<void> ecrireCopie(String nom, String contenu) async {
  try {
    _local?.setItem('$_prefixe$nom', contenu);
    _definirNoms({..._noms(), nom}.toList());
  } catch (_) {}
}

Future<void> effacerCopie(String nom) async {
  try {
    _local?.removeItem('$_prefixe$nom');
    _definirNoms(_noms()..remove(nom));
  } catch (_) {}
}

@JS('URL.createObjectURL')
external String _creerUrl(JSObject blob);

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external _Blob(JSArray<JSString> parts, JSObject options);
}

@JS('document.createElement')
external _Lien _creerElement(String nom);

extension type _Lien._(JSObject _) implements JSObject {
  external set href(String v);
  external set download(String v);
  external void click();
}

/// Téléchargement du fichier.
Future<bool> exporterFichier(String nom, String contenu) async {
  final blob = _Blob([contenu.toJS].toJS, {'type': 'application/octet-stream'}.jsify() as JSObject);
  final a = _creerElement('a')
    ..href = _creerUrl(blob)
    ..download = nom;
  a.click();
  return true;
}

Future<String?> importerFichier() async {
  final x = await openFile();
  if (x == null) return null;
  return x.readAsString();
}
