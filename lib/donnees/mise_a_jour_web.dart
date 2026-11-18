// Mise à jour, web : la page se recharge sur la nouvelle version (window.emplettesRecharger,
// outils/web/flutter_bootstrap.js).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

String get systeme => 'web';

Future<void> recharger() async {
  final f = globalContext['emplettesRecharger'];
  if (f.isA<JSFunction>()) {
    await ((f as JSFunction).callAsFunction() as JSPromise?)?.toDart;
  } else {
    (globalContext['location'] as JSObject).callMethod('reload'.toJS);
  }
}

Future<String> telechargerEtInstaller(Uri url, String nom, Map<String, String> entetes, void Function(double) progression) async =>
    'web';
