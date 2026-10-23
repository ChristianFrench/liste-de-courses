// « Vérifier le serveur MQTT.exe » : contrôle qu'un serveur MQTT (Mosquitto sur le PC, HiveMQ…)
// convient à la synchronisation de Liste de courses. Compilé par GitHub avec `dart compile exe`.
//
// Usage : Verifier-serveur-MQTT.exe [--hote 127.0.0.1] [--port 1883] [--tls] [--utilisateur u] [--mot-de-passe p] [--sans-pause]
// Sans paramètre, les réponses sont demandées à l'écran.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

var _echecs = 0, _alertes = 0;

void ok(String t) => stdout.writeln('  [OK]     $t');
void alerte(String t) {
  _alertes++;
  stdout.writeln('  [ATTENTION] $t');
}

void echec(String t) {
  _echecs++;
  stdout.writeln('  [ECHEC]  $t');
}

void info(String t) => stdout.writeln('           $t');

String demander(String question, String defaut) {
  stdout.write('$question [${defaut.isEmpty ? 'vide' : defaut}] : ');
  final r = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  return r.isEmpty ? defaut : r;
}

late String hote, utilisateur, motDePasse;
late int port;
late bool tls;

/// Client connecté, ou null (la raison est affichée).
Future<MqttServerClient?> client(String id, {bool propre = true, bool anonyme = false, bool silencieux = false, String? testament}) async {
  final c = MqttServerClient.withPort(hote, id, port)
    ..secure = tls
    ..keepAlivePeriod = 20
    ..connectTimeoutPeriod = 6000
    ..autoReconnect = false
    ..logging(on: false)
    ..setProtocolV311();
  var m = MqttConnectMessage().withClientIdentifier(id);
  if (propre) m = m.startClean();
  if (testament != null) {
    m = m.withWillTopic(testament).withWillMessage('{"enLigne":false}').withWillQos(MqttQos.atLeastOnce).withWillRetain();
  }
  c.connectionMessage = m;
  try {
    await c.connect(anonyme || utilisateur.isEmpty ? null : utilisateur, anonyme || motDePasse.isEmpty ? null : motDePasse);
  } catch (e) {
    if (!silencieux) {
      final code = c.connectionStatus?.returnCode;
      final raison = switch (code) {
        MqttConnectReturnCode.badUsernameOrPassword => 'identifiant ou mot de passe refusé',
        MqttConnectReturnCode.notAuthorized => 'connexion non autorisée (identifiant ou mot de passe)',
        MqttConnectReturnCode.identifierRejected => 'identifiant de client refusé',
        MqttConnectReturnCode.unacceptedProtocolVersion => 'version du protocole refusée',
        _ => '$e',
      };
      echec('connexion MQTT impossible : $raison');
    }
    c.disconnect();
    return null;
  }
  if (c.connectionStatus?.state != MqttConnectionState.connected) {
    if (!silencieux) echec('connexion MQTT refusée (${c.connectionStatus?.returnCode})');
    c.disconnect();
    return null;
  }
  return c;
}

/// Messages reçus par un client, rangés par sujet.
class Ecoute {
  Ecoute(this.c) {
    c.updates!.listen((liste) {
      for (final r in liste) {
        final p = r.payload;
        if (p is MqttPublishMessage) {
          final texte = utf8.decode(p.payload.message, allowMalformed: true);
          recus.add((r.topic, texte, p.header?.retain ?? false));
          _attente?.call();
        }
      }
    });
  }
  final MqttServerClient c;
  final recus = <(String, String, bool)>[];
  void Function()? _attente;

  Future<bool> attendre(bool Function() condition, {int ms = 5000}) async {
    if (condition()) return true;
    final fin = Completer<bool>();
    _attente = () {
      if (condition() && !fin.isCompleted) fin.complete(true);
    };
    final t = Timer(Duration(milliseconds: ms), () {
      if (!fin.isCompleted) fin.complete(false);
    });
    final r = await fin.future;
    t.cancel();
    _attente = null;
    return r;
  }
}

void publier(MqttServerClient c, String sujet, String texte, {bool retenu = false}) {
  final b = MqttClientPayloadBuilder()..addUTF8String(texte);
  c.publishMessage(sujet, MqttQos.atLeastOnce, b.payload!, retain: retenu);
}

Future<void> pause() async => Future<void>.delayed(const Duration(milliseconds: 300));

Future<void> main(List<String> args) async {
  String? arg(String nom) {
    final i = args.indexOf('--$nom');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (Platform.isWindows) {
    // Console en UTF-8, pour les accents
    try {
      Process.runSync('cmd', ['/c', 'chcp 65001 >nul']);
    } catch (_) {}
    stdout.encoding = utf8;
  }
  stdout.writeln('Vérification d\'un serveur MQTT pour Liste de courses');
  stdout.writeln('====================================================');
  final interactif = arg('hote') == null;
  hote = arg('hote') ?? demander('Adresse du serveur', '127.0.0.1');
  port = int.tryParse(arg('port') ?? (interactif ? demander('Port', '1883') : '1883')) ?? 1883;
  tls = args.contains('--tls') || (interactif && demander('Connexion chiffrée TLS (o/n)', port == 8883 ? 'o' : 'n').toLowerCase().startsWith('o'));
  utilisateur = arg('utilisateur') ?? (interactif ? demander('Identifiant', '') : '');
  motDePasse = arg('mot-de-passe') ?? (interactif && utilisateur.isNotEmpty ? demander('Mot de passe', '') : '');
  stdout.writeln();

  await verifier();

  stdout.writeln();
  if (_echecs == 0) {
    stdout.writeln('RESULTAT : le serveur convient à la synchronisation${_alertes > 0 ? ' ($_alertes point(s) d\'attention ci-dessus)' : ''}.');
    stdout.writeln();
    stdout.writeln('A saisir dans l\'application (Gérer > Mon foyer > Partage entre appareils > Serveur MQTT) :');
    final adresses = await adressesDuPc();
    final locale = hote == '127.0.0.1' || hote == 'localhost';
    info('Adresse du serveur : ${locale && adresses.isNotEmpty ? adresses.join('  ou  ') : hote}');
    info('Port : $port');
    info('Connexion chiffrée (TLS) : ${tls ? 'cochée' : 'décochée'}');
    if (utilisateur.isNotEmpty) info('Identifiant : $utilisateur   (et son mot de passe)');
    if (locale) info('Le téléphone doit être sur le même réseau Wi-Fi que ce PC.');
  } else {
    stdout.writeln('RESULTAT : $_echecs vérification(s) en échec, le serveur ne convient pas encore.');
  }
  if (!args.contains('--sans-pause')) {
    stdout.write('\nAppuyez sur Entrée pour fermer.');
    stdin.readLineSync();
  }
  exit(_echecs == 0 ? 0 : 1);
}

Future<List<String>> adressesDuPc() async {
  try {
    return [
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
        for (final a in i.addresses)
          if (!a.isLoopback && !a.address.startsWith('169.254.')) a.address
    ];
  } catch (_) {
    return [];
  }
}

Future<void> verifier() async {
  final essai = 'ESSAI${Random().nextInt(1 << 30).toRadixString(36).toUpperCase()}';
  final base = 'ldc/$essai';

  stdout.writeln('1. Réseau');
  try {
    final s = await Socket.connect(hote, port, timeout: const Duration(seconds: 5));
    s.destroy();
    ok('$hote répond sur le port $port');
  } catch (e) {
    echec('$hote ne répond pas sur le port $port ($e)');
    info('Le service Mosquitto est-il démarré ? Le pare-feu laisse-t-il passer le port $port ?');
    return;
  }

  stdout.writeln('2. Connexion MQTT 3.1.1${utilisateur.isEmpty ? ' sans identifiant' : ' avec l\'identifiant « $utilisateur »'}${tls ? ', chiffrée' : ''}');
  final a = await client('ldc-verif-a-$essai');
  if (a == null) return;
  ok('connecté');
  if (utilisateur.isNotEmpty) {
    final anonyme = await client('ldc-verif-anonyme-$essai', anonyme: true, silencieux: true);
    if (anonyme != null) {
      alerte('le serveur accepte aussi les connexions sans identifiant (n\'importe qui sur le réseau peut lire les listes)');
      anonyme.disconnect();
    } else {
      ok('les connexions sans identifiant sont refusées');
    }
  } else if (!tls) {
    alerte('serveur sans identifiant ni chiffrement : à réserver au réseau de la maison');
  }

  stdout.writeln('3. Sujets de l\'application (ldc/<code>/presence, modifs, bonjour), qualité de service 1');
  final ea = Ecoute(a);
  a.subscribe('$base/#', MqttQos.atLeastOnce);
  await pause();
  final t0 = DateTime.now();
  for (final s in ['presence/VERIF', 'modifs/VERIF', 'bonjour']) {
    publier(a, '$base/$s', jsonEncode({'de': 'VERIF', 'essai': s}));
  }
  if (await ea.attendre(() => ea.recus.where((r) => r.$1.startsWith(base)).length >= 3)) {
    ok('publication et abonnement sur ldc/... : aller-retour en ${DateTime.now().difference(t0).inMilliseconds} ms');
  } else {
    echec('les messages publiés sur ldc/... ne reviennent pas (droits d\'accès du serveur ?)');
  }

  stdout.writeln('4. Messages retenus (présence des appareils)');
  publier(a, '$base/presence/RETENU', '{"de":"RETENU","enLigne":true}', retenu: true);
  await pause();
  final b = await client('ldc-verif-b-$essai');
  if (b != null) {
    final eb = Ecoute(b);
    b.subscribe('$base/presence/#', MqttQos.atLeastOnce);
    if (await eb.attendre(() => eb.recus.any((r) => r.$1 == '$base/presence/RETENU' && r.$3))) {
      ok('un appareil qui arrive reçoit la présence des autres');
    } else {
      echec('le message retenu n\'est pas redonné (option retain désactivée ?)');
    }
    b.disconnect();
  }
  publier(a, '$base/presence/RETENU', '', retenu: true); // efface le message retenu

  stdout.writeln('5. Session persistante (messages gardés pour un appareil hors ligne)');
  final idP = 'ldc-verif-p-$essai';
  var p = await client(idP, propre: false);
  if (p != null) {
    p.subscribe('$base/modifs/#', MqttQos.atLeastOnce);
    await pause();
    await pause();
    p.disconnect();
    await pause();
    publier(a, '$base/modifs/HORSLIGNE', '{"de":"A","pendant":"absence"}');
    await pause();
    await pause();
    p = await client(idP, propre: false);
    if (p != null) {
      final ep = Ecoute(p);
      if (await ep.attendre(() => ep.recus.any((r) => r.$1 == '$base/modifs/HORSLIGNE'), ms: 6000)) {
        ok('le message envoyé pendant l\'absence est remis au retour');
      } else {
        echec('le message envoyé pendant l\'absence est perdu (persistence ou sessions désactivées ?)');
      }
      p.disconnect();
      // Nettoyage : la session d'essai est effacée
      (await client(idP, silencieux: true))?.disconnect();
    }
  }

  stdout.writeln('6. Gros lot (300 objets, comme l\'envoi d\'un catalogue)');
  final objets = [
    for (var i = 0; i < 300; i++)
      {'t': 'produit', 'k': '["p-$i"]', 'h': '${DateTime.now().millisecondsSinceEpoch}-00000-VERIF', 'n': 'VERIF', 'v': jsonEncode({'id': 'p-$i', 'nom': 'Produit d\'essai n° $i avec un nom assez long', 'archive': 0})}
  ];
  final gros = jsonEncode({'de': 'VERIF', 'objets': objets});
  final t1 = DateTime.now();
  publier(a, '$base/modifs/GROS', gros);
  if (await ea.attendre(() => ea.recus.any((r) => r.$1 == '$base/modifs/GROS' && r.$2.length == gros.length), ms: 10000)) {
    ok('${(gros.length / 1024).round()} Ko reçus intacts en ${DateTime.now().difference(t1).inMilliseconds} ms');
  } else {
    echec('un message de ${(gros.length / 1024).round()} Ko ne passe pas (taille maximale des messages trop petite ?)');
  }

  stdout.writeln('7. Testament (un appareil qui disparaît sans prévenir est noté hors ligne)');
  final w = await client('ldc-verif-w-$essai', testament: '$base/presence/TESTAMENT');
  if (w != null) {
    // Coupure brutale : la connexion est fermée sans message de déconnexion.
    try {
      // ignore: invalid_use_of_protected_member
      final s = (w.connectionHandler as dynamic).connection.client as Socket;
      s.destroy();
      if (await ea.attendre(() => ea.recus.any((r) => r.$1 == '$base/presence/TESTAMENT'), ms: 8000)) {
        ok('le testament est diffusé');
      } else {
        alerte('testament non reçu (les autres appareils verront l\'appareil « en ligne » un peu trop longtemps)');
      }
    } catch (_) {
      info('coupure brutale impossible à simuler ici : point non vérifié');
      w.disconnect();
    }
    publier(a, '$base/presence/TESTAMENT', '', retenu: true);
  }

  stdout.writeln('8. Foyers déjà présents sur ce serveur');
  final f = await client('ldc-verif-f-$essai');
  if (f != null) {
    final ef = Ecoute(f);
    f.subscribe('ldc/+/presence/+', MqttQos.atLeastOnce);
    await Future<void>.delayed(const Duration(seconds: 2));
    final presences = <String, List<String>>{};
    for (final r in ef.recus) {
      if (r.$2.isEmpty || r.$1.contains('/ESSAI')) continue;
      final code = r.$1.split('/')[1];
      try {
        final j = jsonDecode(r.$2) as Map;
        (presences[code] ??= []).add('${j['nom'] ?? j['de']}${j['enLigne'] == true ? ' (en ligne)' : ''}');
      } catch (_) {}
    }
    if (presences.isEmpty) {
      info('aucun appareil de Liste de courses n\'est encore passé par ce serveur');
    } else {
      presences.forEach((code, appareils) => info('code $code : ${appareils.join(', ')}'));
    }
    f.disconnect();
  }
  a.disconnect();
}
