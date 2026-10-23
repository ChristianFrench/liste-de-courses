// Deux appareils reliés par un faux serveur MQTT en mémoire.
import 'dart:async';

import 'package:essai_synchro/moteur.dart';
import 'package:flutter_test/flutter_test.dart';

class Bus {
  final membres = <FauxTransport>[];
  final retenus = <String, String>{};
  void diffuser(String sujet, String contenu, {bool retenu = false}) {
    if (retenu) retenus[sujet] = contenu;
    for (final m in membres) {
      if (m.connecte) m.recu.add((sujet, contenu));
    }
  }
}

class FauxTransport implements Transport {
  FauxTransport(this.bus) {
    bus.membres.add(this);
  }
  final Bus bus;
  final recu = StreamController<(String, String)>.broadcast();
  final _etats = StreamController<String>.broadcast();
  bool _connecte = false;

  @override
  Stream<(String, String)> get messages => recu.stream;
  @override
  Stream<String> get etats => _etats.stream;
  @override
  bool get connecte => _connecte;

  @override
  Future<void> connecter({required String identifiant, required String sujetTestament, required String testament, required String abonnement}) async =>
      brancher();

  void brancher() {
    _connecte = true;
    bus.retenus.forEach((s, c) => recu.add((s, c)));
    _etats.add('connecte');
  }

  void debrancher() {
    _connecte = false;
    _etats.add('deconnecte');
  }

  @override
  void publier(String sujet, String contenu, {bool retenu = false}) {
    if (_connecte) bus.diffuser(sujet, contenu, retenu: retenu);
  }

  @override
  Future<void> fermer() async => _connecte = false;
}

Future<void> attendre() => Future<void>.delayed(const Duration(milliseconds: 300));

void main() {
  test('deux appareils convergent, y compris après une coupure', () async {
    final bus = Bus();
    final tA = FauxTransport(bus), tB = FauxTransport(bus);
    final a = Moteur(crdt: await ouvrirBase(null), transport: tA, foyer: 'T', nom: 'PC', plateforme: 'Windows');
    final b = Moteur(crdt: await ouvrirBase(null), transport: tB, foyer: 'T', nom: 'Tel', plateforme: 'Android');
    await a.demarrer();
    await b.demarrer();
    await attendre();
    expect(a.pairs.values.single.nom, 'Tel');

    final liste = await a.ajouterListe('Courses', articles: Moteur.lireArticles('2 lait\npain\n- oeufs x6'));
    await attendre();
    expect((await b.compter()).$2, 3);
    final lignes = await b.crdt.query('SELECT id, article, quantite FROM lignes ORDER BY article');
    expect(lignes.map((l) => '${l['article']}:${l['quantite']}'), ['lait:2', 'oeufs:6', 'pain:1']);

    // B coche hors ligne, A ajoute en même temps ; à la reconnexion tout se rejoint.
    tB.debrancher();
    await b.cocher(lignes.first['id'] as String, true);
    await a.ajouterLigne(liste, 'beurre');
    await attendre();
    expect((await b.compter()).$2, 3);
    tB.brancher();
    await attendre();
    expect((await a.empreinte()), await b.empreinte());
    expect((await a.compter()).$2, 4);

    // Accusés de réception : essai en volume.
    await a.essaiVolume(1000);
    expect(a.journal.any((e) => e.texte.contains('a reçu et enregistré les 1001 changements')), isTrue);
    expect((await b.compter()).$2, 1004);

    // Message et empreintes.
    final notes = <String>[];
    b.notifications.listen(notes.add);
    a.message('Je pars au magasin');
    a.comparerEmpreintes();
    await attendre();
    expect(notes, ['PC : Je pars au magasin']);
    expect(a.journal.any((e) => e.texte.contains('bases identiques')), isTrue);
  });

  test('un appareil effacé récupère les données des autres', () async {
    final bus = Bus();
    final tA = FauxTransport(bus), tB = FauxTransport(bus);
    final a = Moteur(crdt: await ouvrirBase(null), transport: tA, foyer: 'T', nom: 'PC', plateforme: 'Windows');
    await a.demarrer();
    await a.ajouterListe('Avant', articles: [('riz', 1), ('pâtes', 2)]);
    // B arrive après coup, sans session : il obtient tout par « bonjour ».
    final b = Moteur(crdt: await ouvrirBase(null), transport: tB, foyer: 'T', nom: 'Tel', plateforme: 'Android');
    await b.demarrer();
    await attendre();
    expect((await b.compter()), (1, 2));
  });

  test('lecture des fichiers d\'articles', () {
    expect(Moteur.lireArticles('3 x tomates\n\n• sel\nfarine 2'), [('tomates', 3), ('sel', 1), ('farine', 2)]);
  });
}
