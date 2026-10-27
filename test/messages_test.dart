import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liste_de_courses/donnees/messages.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  test('messages ntfy : envoi en JSON au canal, lecture des messages reçus', () async {
    Etat.instance.enregistrementActif = false;
    Etat.instance.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    final m = MessagesFoyer.instance;
    Map<String, dynamic>? envoye;
    m.client = MockClient((r) async {
      if (r.method == 'POST') {
        envoye = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      expect(r.url.path, '/${m.canal}/json');
      expect(r.url.queryParameters['poll'], '1');
      return http.Response.bytes(
          utf8.encode('{"id":"a","time":1761560000,"event":"open"}\n'
              '{"id":"b","time":1761560100,"event":"message","topic":"x","title":"Zoé · Maison","message":"Il manque le lait é"}\n'),
          200);
    });
    expect(await m.envoyer('  '), isNotNull);
    expect(await m.envoyer('Je passe chez Lidl'), isNull);
    expect(envoye!['topic'], m.canal);
    expect(envoye!['message'], 'Je passe chez Lidl');
    expect(m.canal, startsWith('ldc-'));
    expect(m.messages.single.texte, 'Il manque le lait é');
    expect(m.messages.single.titre, 'Zoé · Maison');
  });
}
