import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'moteur.dart';

/// Transport réel : client MQTT, QoS 1, session persistante, reconnexion automatique.
class TransportMqtt implements Transport {
  TransportMqtt({required this.hote, required this.port, required this.tls, this.utilisateur = '', this.motDePasse = ''});

  final String hote;
  final int port;
  final bool tls;
  final String utilisateur, motDePasse;

  MqttServerClient? _client;
  final _messages = StreamController<(String, String)>.broadcast();
  final _etats = StreamController<String>.broadcast();
  StreamSubscription? _sub;
  Timer? _relance;
  bool _ferme = false;
  late String _abonnement;

  @override
  Stream<(String, String)> get messages => _messages.stream;
  @override
  Stream<String> get etats => _etats.stream;
  @override
  bool get connecte => _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<void> connecter({
    required String identifiant,
    required String sujetTestament,
    required String testament,
    required String abonnement,
  }) async {
    _abonnement = abonnement;
    final c = MqttServerClient.withPort(hote, identifiant, port)
      ..secure = tls
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..connectTimeoutPeriod = 8000
      ..logging(on: false);
    c.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(identifiant)
        .withWillTopic(sujetTestament)
        .withWillMessage(testament)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain(); // pas de startClean : le serveur garde la session et les messages manqués
    c.onConnected = () => _connecte();
    c.onAutoReconnect = () => _etats.add('connexion');
    c.onAutoReconnected = () => _connecte();
    c.onDisconnected = () {
      if (!_ferme) _etats.add('deconnecte');
    };
    _client = c;
    await _premiereConnexion();
  }

  Future<void> _premiereConnexion() async {
    final c = _client!;
    _etats.add('connexion');
    try {
      await c.connect(utilisateur.isEmpty ? null : utilisateur, motDePasse.isEmpty ? null : motDePasse);
    } catch (e) {
      _etats.add('Connexion impossible à $hote:$port (${_court(e)}), nouvel essai dans 10 s');
      _etats.add('deconnecte');
      c.disconnect();
      if (!_ferme) _relance = Timer(const Duration(seconds: 10), _premiereConnexion);
      return;
    }
    await _sub?.cancel();
    _sub = c.updates!.listen((liste) {
      for (final r in liste) {
        final p = r.payload;
        if (p is MqttPublishMessage) {
          _messages.add((r.topic, utf8.decode(p.payload.message, allowMalformed: true)));
        }
      }
    });
  }

  void _connecte() {
    _client!.subscribe(_abonnement, MqttQos.atLeastOnce);
    _etats.add('connecte');
  }

  String _court(Object e) {
    final s = '$e';
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  @override
  void publier(String sujet, String contenu, {bool retenu = false}) {
    if (!connecte) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(contenu);
    _client!.publishMessage(sujet, MqttQos.atLeastOnce, b.payload!, retain: retenu);
  }

  @override
  Future<void> fermer() async {
    _ferme = true;
    _relance?.cancel();
    await _sub?.cancel();
    _client?.disconnect();
  }
}
