/// Fichiers des bases SQLite : sur disque (Windows, Android, iPhone) ou dans le navigateur (web).
library;

export 'base_locale_io.dart' if (dart.library.js_interop) 'base_locale_web.dart';
