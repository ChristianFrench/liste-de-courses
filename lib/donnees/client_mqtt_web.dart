import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Un navigateur ne parle MQTT qu'en WebSocket, et n'accepte que les certificats signés par une
/// autorité : EMQX Cloud (WebSocket 8084) ou HiveMQ (8884) conviennent, avec le chemin /mqtt ;
/// pas un Mosquitto à certificat maison. Le port 8883 réglé pour les autres appareils est remplacé
/// par le port WebSocket du service.
MqttClient creerClientMqtt(String hote, int port, bool tls, String identifiant, bool Function(List<int>) certificat) {
  final p = port == 8883 ? (hote.contains('hivemq') ? 8884 : 8084) : port;
  return MqttBrowserClient.withPort('${tls ? 'wss' : 'ws'}://$hote/mqtt', identifiant, p)
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
}

const nomSysteme = 'Web';
