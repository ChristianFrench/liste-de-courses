import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// [certificat] reçoit le certificat (DER) d'un serveur non signé par une autorité.
MqttClient creerClientMqtt(String hote, int port, bool tls, String identifiant, bool Function(List<int>) certificat) =>
    MqttServerClient.withPort(hote, identifiant, port)
      ..secure = tls
      ..onBadCertificate = (Object c) => certificat((c as X509Certificate).der);

String get nomSysteme => Platform.isAndroid
    ? 'Android'
    : Platform.isIOS
        ? 'iPhone'
        : Platform.isWindows
            ? 'Windows'
            : Platform.operatingSystem;
