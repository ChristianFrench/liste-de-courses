/// Client MQTT : TCP (Windows, Android, iPhone) ou WebSocket sécurisé (navigateur).
library;

export 'client_mqtt_io.dart' if (dart.library.js_interop) 'client_mqtt_web.dart';
