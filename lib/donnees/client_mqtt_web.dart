import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Un navigateur ne parle MQTT qu'en WebSocket, et n'accepte que les certificats signés par une
/// autorité : HiveMQ Cloud convient (port 8884, chemin /mqtt), pas un Mosquitto à certificat maison.
MqttClient creerClientMqtt(String hote, int port, bool tls, String identifiant, bool Function(List<int>) certificat) {
  final p = port == 8883 ? 8884 : port;
  return MqttBrowserClient.withPort('${tls ? 'wss' : 'ws'}://$hote/mqtt', identifiant, p)
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
}

const nomSysteme = 'Web';
