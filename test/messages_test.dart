import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liste_de_courses/donnees/envoi.dart';
import 'package:liste_de_courses/donnees/messages.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  test('messages ntfy : envoi en JSON au canal, lecture des messages reçus', () async {
    Etat.instance.enregistrementActif = false;
    Etat.instance.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    final m = MessagesFoyer.instance;
    final envoyes = <Map<String, dynamic>>[];
    m.client = MockClient((r) async {
      if (r.method == 'POST') {
        envoyes.add(jsonDecode(r.body) as Map<String, dynamic>);
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
    // Au journal du foyer, puis sur le canal de chacun des autres membres
    final e = Etat.instance;
    expect([for (final x in envoyes) x['topic']],
        [m.canal, for (final x in e.membresVisibles) if (x.id != e.moi.id) m.canalDe(x.id)]);
    expect(envoyes.length, greaterThan(1));
    expect(envoyes.map((x) => x['topic']), isNot(contains(m.monCanal)), reason: 'jamais à soi-même');
    expect(envoyes.last['message'], 'Je passe chez Lidl');
    expect(m.canal, startsWith('ldc-'));
    expect(m.messages.single.texte, 'Il manque le lait é');
    expect(m.messages.single.titre, 'Zoé · Maison');
  });

  test('mail direct par EmailJS : destinataires, sujet et texte ; rien sans destinataire ni identifiants', () async {
    final envoyes = <Map<String, dynamic>>[];
    MailDirect.client = MockClient((r) async {
      expect(r.url.toString(), 'https://api.emailjs.com/api/v1.0/email/send');
      envoyes.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response('OK', 200);
    });
    MailDirect.disponibleEssai = false;
    expect(await MailDirect.envoyer(['a@exemple.fr'], 'Sujet', 'Texte'), isFalse);
    MailDirect.disponibleEssai = true;
    expect(await MailDirect.envoyer([], 'Sujet', 'Texte'), isFalse);
    expect(await MailDirect.envoyer(['a@exemple.fr', 'b@exemple.fr'], 'Liste', 'Lait'), isTrue);
    expect(envoyes.single['template_params'],
        allOf(containsPair('destinataires', 'a@exemple.fr,b@exemple.fr'), containsPair('sujet', 'Liste'), containsPair('texte', 'Lait'),
            containsPair('expediteur', Etat.instance.moi.nomAffiche)));
    expect(messageEnvoi(Envoi.parti, 2), 'Mail envoyé à 2 personnes');
    MailDirect.disponibleEssai = null;
  });
}
