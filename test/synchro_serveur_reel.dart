// Essai sur le vrai serveur MQTT public (broker.hivemq.com) : l'application (appareil A) partage
// son foyer ; un second appareil simulé (B) le rejoint, reçoit tout, coche un article qui revient à A.
// Lancé par GitHub (étape « Deux appareils sur le vrai serveur MQTT »), pas par « flutter test » seul.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/stockage.dart';
import 'package:liste_de_courses/donnees/synchro.dart';

void notice(String titre, String texte) => print('::notice title=$titre::$texte');

Future<void> attendre(bool Function() condition, {int secondes = 60}) async {
  final fin = DateTime.now().add(Duration(seconds: secondes));
  while (!condition()) {
    if (DateTime.now().isAfter(fin)) {
      for (final e in Synchro.instance.journal.reversed) {
        print('journal A : ${e.texte}');
      }
      throw TimeoutException('délai dépassé');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deux appareils sur broker.hivemq.com', () async {
    final dossier = Directory.systemTemp.createTempSync('synchro');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    final listeA = etat.creerListe(etat.magasins.first.id, [for (final p in etat.produits.take(5)) LigneListe(produitId: p.id)]);
    final s = Synchro.instance;
    await s.demarrer();
    // MQTT_HOTE=localhost MQTT_PORT=1883 : essai sur un serveur local, sans chiffrement.
    final env = Platform.environment;
    final serveur = env['MQTT_HOTE'] == null
        ? const ServeurMqtt()
        : ServeurMqtt(
            hote: env['MQTT_HOTE']!,
            port: int.parse(env['MQTT_PORT'] ?? '1883'),
            tls: false,
            utilisateur: env['MQTT_UTILISATEUR'] ?? '',
            motDePasse: env['MQTT_MDP'] ?? '');
    await s.changerServeur(serveur);
    final debut = DateTime.now();
    await s.creerPartage();
    await attendre(() => s.etatReseau == 'connecte', secondes: 30);
    await attendre(() => s.liaisonOk, secondes: 15);
    expect(s.role, 'maitre');
    notice('A connecté', 'code ${s.code}, ${DateTime.now().difference(debut).inMilliseconds} ms');

    // Appareil B : base vide, rejoint avec le code.
    final b = Stockage.ouvrir('${dossier.path}/b.db');
    final demo = jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;
    b.ecrire({
      'foyer': {'id': 'f-B', 'nom': 'Mon foyer', 'dateCreation': '2026-10-23'},
      'membres': [
        {'id': 'm-B', 'nomAffiche': 'Bob', 'role': 'membre', 'moi': true}
      ],
      'invitation': {'code': 'ABCDEF', 'expiration': '2026-10-30'},
      'parametres': {...(demo['parametres'] as Map), 'options': {'formats': 1, 'typesPackaging': <String>[]}},
      'typesPromotion': demo['typesPromotion'],
      for (final c in ['magasins', 'rayons', 'secteurs', 'marques', 'packagings', 'produits', 'emplacements', 'parcours', 'listes', 'historique', 'tickets'])
        c: <dynamic>[],
    });
    b.horloge = Horloge('NOEUDB');
    final base = 'ldc/${s.code}';
    final tb = TransportMqtt(serveur);
    var recusB = 0;
    tb.messages.listen((m) {
      if (!m.$1.startsWith('$base/modifs/')) return;
      final j = jsonDecode(m.$2) as Map;
      if (j['de'] == 'NOEUDB' || (j['pour'] != null && j['pour'] != 'NOEUDB')) return;
      recusB += b.appliquer([for (final o in j['objets'] as List) Map<String, dynamic>.from(o as Map)]);
    });
    final connecteB = Completer<void>();
    tb.etats.listen((e) {
      if (e == 'connecte' && !connecteB.isCompleted) connecteB.complete();
    });
    await tb.connecter(identifiant: 'ldc-essai-B-${s.code}', sujetTestament: '$base/presence/NOEUDB', testament: '{}', abonnement: '$base/#');
    await connecteB.future.timeout(const Duration(seconds: 30));
    final t0 = DateTime.now();
    tb.publier('$base/bonjour', jsonEncode({'de': 'NOEUDB', 'nom': 'Bob · essai', 'connus': {}}));
    final attendus = etat.produits.length;
    await attendre(() => (b.lire()['produits'] as List).length >= attendus, secondes: 90);
    final jb = b.lire();
    notice('B a reçu le foyer',
        '$recusB objets en ${DateTime.now().difference(t0).inMilliseconds} ms : ${(jb['produits'] as List).length} produits, '
        '${(jb['listes'] as List).length} listes, ${b.nbEnAttente} en attente');
    expect(b.nbEnAttente, 0);

    // B coche le premier article de la liste : A le voit.
    final liste = (jb['listes'] as List).firstWhere((l) => l['id'] == listeA.id) as Map;
    final ligne = (liste['lignes'] as List).first as Map;
    ligne['coche'] = {'par': 'm-B', 'le': '2026-10-23T10:00:00'};
    b.ecrire(jb);
    final dernierA = etat.stockageFoyer!.objetsDe(s.noeud, '').last['h'] as String;
    final t1 = DateTime.now();
    tb.publier('$base/modifs/NOEUDB', jsonEncode({'de': 'NOEUDB', 'objets': b.objetsDe('NOEUDB', '')}));
    await attendre(() => etat.liste(listeA.id)!.lignes.any((g) => g.produitId == ligne['produitId'] && g.cocheLe != null), secondes: 30);
    notice('Coche de B reçue par A', '${DateTime.now().difference(t1).inMilliseconds} ms');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(etat.stockageFoyer!.objetsDe(s.noeud, dernierA), isEmpty, reason: 'A ne renvoie pas ce qu\'il a reçu');

    // A ajoute un article : B le reçoit.
    final t2 = DateTime.now();
    etat.ajouterLigne(etat.liste(listeA.id)!, etat.produits[10].id);
    await attendre(() {
      final l = (b.lire()['listes'] as List).firstWhere((l) => l['id'] == listeA.id) as Map;
      return (l['lignes'] as List).any((g) => g['produitId'] == etat.produits[10].id);
    }, secondes: 30);
    notice('Ajout de A reçu par B', '${DateTime.now().difference(t2).inMilliseconds} ms');

    await tb.fermer();
    await s.arreterPartage();
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('l\'application rejoint un foyer existant', () async {
    final dossier = Directory.systemTemp.createTempSync('synchro2');
    final etat = Etat.instance;
    final s = Synchro.instance;
    final env = Platform.environment;
    final serveur = env['MQTT_HOTE'] == null
        ? const ServeurMqtt()
        : ServeurMqtt(
            hote: env['MQTT_HOTE']!,
            port: int.parse(env['MQTT_PORT'] ?? '1883'),
            tls: false,
            utilisateur: env['MQTT_UTILISATEUR'] ?? '',
            motDePasse: env['MQTT_MDP'] ?? '');
    // Appareil A : le foyer de démonstration, déjà partagé ; il répond aux « bonjour ».
    final a = Stockage.ouvrir('${dossier.path}/a.db');
    final demo = jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;
    a.ecrire(demo);
    a.horloge = Horloge('NOEUDA');
    a.toutJournaliser(a.lire());
    final code = 'ESSAI${DateTime.now().millisecondsSinceEpoch % 100000}'.padRight(10, 'X');
    final base = 'ldc/$code';
    final ta = TransportMqtt(serveur);
    ta.messages.listen((m) {
      final j = jsonDecode(m.$2) as Map;
      if (j['de'] == 'NOEUDA') return;
      if (m.$1 == '$base/bonjour') {
        ta.publier('$base/modifs/NOEUDA', jsonEncode({'de': 'NOEUDA', 'pour': j['de'], 'objets': a.objetsDe('NOEUDA', '')}));
      } else if (m.$1.startsWith('$base/modifs/')) {
        a.appliquer([for (final o in j['objets'] as List) Map<String, dynamic>.from(o as Map)]);
      }
    });
    final pret = Completer<void>();
    ta.etats.listen((e) {
      if (e == 'connecte' && !pret.isCompleted) pret.complete();
    });
    await ta.connecter(identifiant: 'ldc-essai-A-$code', sujetTestament: '$base/presence/NOEUDA', testament: '{}', abonnement: '$base/#');
    await pret.future.timeout(const Duration(seconds: 30));

    // L'application rejoint sous le nom d'un membre qui existe déjà dans le foyer.
    final nom = ((demo['membres'] as List)[1] as Map)['nomAffiche'] as String;
    final t0 = DateTime.now();
    await s.rejoindre(code, nom);
    await attendre(() => etat.produits.length == (demo['produits'] as List).length && etat.listes.isNotEmpty);
    notice('Foyer rejoint', '${DateTime.now().difference(t0).inMilliseconds} ms : ${etat.produits.length} produits, '
        '${etat.listes.length} listes, ${etat.membres.length} membres, moi = ${etat.moi.nomAffiche}');
    expect(etat.moi.nomAffiche, nom);
    expect(etat.moi.id, ((demo['membres'] as List)[1] as Map)['id'], reason: 'le membre existant est repris');
    expect(etat.membres.length, (demo['membres'] as List).length);
    expect(dossier.listSync().isNotEmpty, isTrue);
    await ta.fermer();
    await s.arreterPartage();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
