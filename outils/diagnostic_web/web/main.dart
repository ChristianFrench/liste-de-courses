// Diagnostic : le client MQTT du navigateur (même bibliothèque que l'application web) face au vrai
// serveur, sur un canal d'essai. Lancé par .github/workflows/diagnostic-mqtt.yml dans Chromium.
import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

const hote = String.fromEnvironment('MQTT_HOTE');
const utilisateur = String.fromEnvironment('MQTT_UTILISATEUR');
const motDePasse = String.fromEnvironment('MQTT_MOT_DE_PASSE');
const canal = 'ldc/DIAGNOSTIC-WEB';

Future<void> main() async {
  final id = 'ldc-diagnostic-web-${DateTime.now().millisecondsSinceEpoch}';
  final c = MqttBrowserClient.withPort('wss://$hote/mqtt', id, 8084)
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault
    ..keepAlivePeriod = 30
    ..setProtocolV311();
  c.connectionMessage = MqttConnectMessage().withClientIdentifier(id).startClean();
  c.onSubscribed = (s) => print('ABONNE $s');
  c.onDisconnected = () => print('DECONNECTE');
  try {
    await c.connect(utilisateur, motDePasse);
  } catch (e) {
    print('ECHEC CONNEXION $e');
    return;
  }
  print('CONNECTE');
  c.updates!.listen((l) {
    for (final r in l) {
      final p = r.payload as MqttPublishMessage;
      print('RECU ${r.topic} ${p.payload.message.length}');
    }
  });
  c.subscribe('$canal/#', MqttQos.atLeastOnce);
  await Future<void>.delayed(const Duration(seconds: 2));
  void publier(String sujet, String texte, {bool retenu = false}) {
    try {
      final b = MqttClientPayloadBuilder()..addUTF8String(texte);
      c.publishMessage(sujet, MqttQos.atLeastOnce, b.payload!, retain: retenu);
      print('ENVOYE $sujet ${texte.length}');
    } catch (e) {
      print('ECHEC ENVOI $sujet $e');
    }
  }

  publier('$canal/controle/a', jsonEncode({'de': 'a', 't': 1}));
  await Future<void>.delayed(const Duration(seconds: 2));
  publier('$canal/presence/a', jsonEncode({'de': 'a', 'nom': 'Christian · Web', 'enLigne': true}), retenu: true);
  await Future<void>.delayed(const Duration(seconds: 2));
  publier('$canal/controle/b', jsonEncode({'de': 'b', 't': 2}));
  await Future<void>.delayed(const Duration(seconds: 2));
  publier('$canal/modifs/a', jsonEncode({'de': 'a', 'objets': ['é' * 60000]}));
  await Future<void>.delayed(const Duration(seconds: 2));
  publier('$canal/controle/c', jsonEncode({'de': 'c', 't': 3}));
  await Future<void>.delayed(const Duration(seconds: 4));
  publier('$canal/presence/a', '', retenu: true);
  await Future<void>.delayed(const Duration(seconds: 1));
  print('FIN');
}
