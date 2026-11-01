// Chiffrement par foyer (01/11/2026) : ce qu'un foyer dépose sur le serveur n'est lisible qu'avec son code.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/chiffrement.dart';
import 'package:liste_de_courses/donnees/synchro.dart';

/// Un serveur en mémoire : chaque message publié est rendu à tous les transports.
class _Serveur {
  final publies = <(String, String)>[];
  final _flux = StreamController<(String, String)>.broadcast();
}

class _Transport implements Transport {
  _Transport(this.s);
  final _Serveur s;
  @override
  Stream<(String, String)> get messages => s._flux.stream;
  @override
  Stream<String> get etats => const Stream.empty();
  @override
  bool get connecte => true;
  String? testament;
  @override
  Future<void> connecter({required String identifiant, required String sujetTestament, required String testament, required String abonnement}) async {
    this.testament = '$sujetTestament=$testament';
  }

  @override
  void publier(String sujet, String contenu, {bool retenu = false}) {
    s.publies.add((sujet, contenu));
    s._flux.add((sujet, contenu));
  }

  @override
  Future<void> fermer() async {}
}

void main() {
  test('chiffré sous un sujet qui ne montre pas le code ; lu par le foyer seul, dans l\'ordre', () async {
    final serveur = _Serveur();
    final a = TransportChiffre(_Transport(serveur), 'ABCDEFGHJK');
    final b = TransportChiffre(_Transport(serveur), 'ABCDEFGHJK');
    final intrus = TransportChiffre(_Transport(serveur), 'ZZZZZZZZZZ');
    final recusB = <(String, String)>[], recusIntrus = <(String, String)>[];
    b.messages.listen(recusB.add);
    intrus.messages.listen(recusIntrus.add);
    final dessousA = a.dessous as _Transport;
    await a.connecter(identifiant: 'a', sujetTestament: 'ldc/ABCDEFGHJK/presence/A', testament: '{"nom":"Alice"}', abonnement: 'ldc/ABCDEFGHJK/#');
    expect(dessousA.testament, startsWith('${sujetFoyer('ABCDEFGHJK')}/presence/A=chf:'));

    for (var i = 0; i < 5; i++) {
      a.publier('ldc/ABCDEFGHJK/modifs/A', '{"de":"A","n":$i,"liste":"Courses de Noël"}');
    }
    a.publier('ldc/ABCDEFGHJK/presence/A', '', retenu: true);
    a.publier('ldc/annuaire/mon-foyer', '{"cree":1}', retenu: true);
    await a.fermer();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final duFoyer = [for (final p in serveur.publies) if (!p.$1.startsWith('ldc/annuaire')) p];
    expect(duFoyer.every((p) => !p.$1.contains('ABCDEFGHJK')), isTrue, reason: 'le code n\'est pas dans les sujets');
    expect(duFoyer.where((p) => p.$2.isNotEmpty).every((p) => p.$2.startsWith('chf:') && !p.$2.contains('Noël')), isTrue);
    expect(serveur.publies.last, ('ldc/annuaire/mon-foyer', '{"cree":1}'), reason: 'l\'annuaire reste en clair');

    expect([for (final r in recusB) if (r.$1 == 'ldc/ABCDEFGHJK/modifs/A') r.$2],
        [for (var i = 0; i < 5; i++) '{"de":"A","n":$i,"liste":"Courses de Noël"}']);
    expect(recusB, contains(('ldc/ABCDEFGHJK/presence/A', '')), reason: 'l\'effacement d\'un message retenu passe');
    expect([for (final r in recusIntrus) if (r.$1.startsWith('ldc/ZZZZZZZZZZ')) r], isEmpty, reason: 'un autre code ne lit rien');
  });

  test('un message en clair de l\'ancienne version, ou altéré, est ignoré', () async {
    final serveur = _Serveur();
    final b = TransportChiffre(_Transport(serveur), 'ABCDEFGHJK');
    final recus = <(String, String)>[];
    b.messages.listen(recus.add);
    final reel = sujetFoyer('ABCDEFGHJK');
    final bon = await (await ChiffreFoyer.pour('ABCDEFGHJK')).chiffrer('{"de":"A"}');
    b.dessous.publier('$reel/modifs/A', '{"de":"A"}');
    b.dessous.publier('$reel/modifs/A', '${bon.substring(0, bon.length - 4)}AAAA');
    b.dessous.publier('$reel/modifs/A', bon);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(recus, [('ldc/ABCDEFGHJK/modifs/A', '{"de":"A"}')]);
    expect(b.ignores, 2);
  });
}
