// Essai sur le vrai serveur MQTT (lancé par la compilation sur GitHub, pas par « flutter test » seul).
import 'dart:io';
import 'dart:math';

import 'package:essai_synchro/moteur.dart';
import 'package:essai_synchro/transport_mqtt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

void main() {
  test('deux appareils sur broker.hivemq.com', () async {
    final foyer = 'CI${Random().nextInt(1 << 30).toRadixString(36).toUpperCase()}';
    Moteur creer(String nom, SqliteCrdt crdt) => Moteur(
          crdt: crdt,
          transport: TransportMqtt(hote: 'broker.hivemq.com', port: 8883, tls: true),
          foyer: foyer,
          nom: nom,
          plateforme: 'Linux',
        );
    final a = creer('A', await ouvrirBase(null)), b = creer('B', await ouvrirBase(null));
    await a.demarrer();
    await b.demarrer();
    for (var i = 0; i < 40 && !(a.pairs[b.id]?.enLigne ?? false); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await a.ajouterListe('Courses', articles: [('lait', 2), ('pain', 1)]);
    await a.ping(nombre: 5);
    await a.essaiVolume(2000);
    a.comparerEmpreintes();
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final e in a.journal.reversed) {
      stdout.writeln('${e.type == 'erreur' ? '::warning' : '::notice'} title=Serveur réel::${e.texte}');
    }
    expect(a.journal.any((e) => e.texte.contains('bases identiques')), isTrue);
    await a.arreter();
    await b.arreter();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
