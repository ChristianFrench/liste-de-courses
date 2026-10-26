// Synchronisation entre deux appareils (deux bases locales), sans serveur : ce que l'un envoie,
// l'autre l'intègre ; rien ne repart en écho ; la modification la plus récente l'emporte.
// Lancé automatiquement par GitHub ; rien à faire à la main.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/stockage.dart';
import 'package:liste_de_courses/donnees/synchro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> demo() =>
      jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;

  /// Aller-retour par le modèle de l'application, comme après chaque relecture de la base.
  Map<String, dynamic> parLeModele(Map<String, dynamic> j) {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(j);
    return jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>;
  }

  /// Foyer vide d'un appareil qui rejoint : son foyer à lui, un membre, rien d'autre.
  Map<String, dynamic> vide(Map<String, dynamic> d) => {
        'foyer': {'id': 'f-B', 'nom': 'Mon foyer', 'dateCreation': '2026-10-23'},
        'membres': [
          {'id': 'm-B', 'nomAffiche': 'Bob', 'role': 'membre', 'moi': true}
        ],
        'invitation': {'code': 'ABCDEF', 'expiration': '2026-10-30'},
        'parametres': {
          ...(d['parametres'] as Map),
          'options': {'formats': 1, 'typesPackaging': <String>[]},
        },
        'typesPromotion': d['typesPromotion'],
        for (final c in ['magasins', 'rayons', 'secteurs', 'marques', 'packagings', 'produits', 'emplacements', 'parcours', 'listes', 'historique', 'tickets'])
          c: <dynamic>[],
      };

  List<Map<String, dynamic>> envoi(Stockage s, String noeud, [String apres = '']) =>
      jsonDecode(jsonEncode(s.objetsDe(noeud, apres))).cast<Map<String, dynamic>>() as List<Map<String, dynamic>>;

  test('un appareil qui rejoint reçoit tout le foyer, sans écho', () {
    final d = demo();
    final a = Stockage.ouvrir(':memory:');
    a.ecrire(parLeModele(d));
    a.horloge = Horloge('A');
    a.toutJournaliser(a.lire());

    final b = Stockage.ouvrir(':memory:');
    b.ecrire(parLeModele(vide(d)));
    b.horloge = Horloge('B');
    b.toutJournaliser(b.lire(), tables: {'membre'});

    final objets = envoi(a, 'A');
    expect(objets.length, greaterThan(50));
    expect(b.appliquer(objets), objets.length);
    expect(b.erreurs, isEmpty);
    expect(b.nbEnAttente, 0);

    final ja = a.lire(), jb = b.lire();
    for (final c in ['magasins', 'rayons', 'secteurs', 'produits', 'emplacements', 'parcours', 'historique', 'tickets']) {
      expect((jb[c] as List).length, (ja[c] as List).length, reason: c);
    }
    expect(jsonEncode(jb['listes']), jsonEncode(ja['listes']));
    expect((jb['membres'] as List).length, (ja['membres'] as List).length + 1);
    expect(jb['foyer']['id'], 'f-B', reason: 'chaque appareil garde son identifiant de foyer');

    // Relu puis réécrit par l'application : rien de nouveau à envoyer (pas d'écho).
    final avant = envoi(b, 'B').length;
    b.ecrire(parLeModele(jb));
    expect(envoi(b, 'B').length, avant);
    a.ecrire(parLeModele(ja));
    expect(envoi(a, 'A').length, objets.length);

    // B coche un article : A le voit. Puis A le décoche plus tard : B aussi.
    final dernierB = envoi(b, 'B').last['h'] as String;
    final jb2 = parLeModele(b.lire());
    final liste = (jb2['listes'] as List).first as Map;
    final ligne = (liste['lignes'] as List).first as Map;
    ligne['coche'] = {'par': 'm-B', 'le': '2026-10-23T10:00:00'};
    b.ecrire(jb2);
    final modifB = envoi(b, 'B', dernierB);
    expect(modifB.length, 1);
    expect(a.appliquer(modifB), 1);
    final la = ((a.lire()['listes'] as List).firstWhere((l) => l['id'] == liste['id']) as Map)['lignes'] as List;
    expect(la.firstWhere((g) => g['produitId'] == ligne['produitId'])['coche'], isNotNull);

    final dernierA = envoi(a, 'A').last['h'] as String;
    final ja2 = parLeModele(a.lire());
    final g2 = ((ja2['listes'] as List).firstWhere((l) => l['id'] == liste['id'])['lignes'] as List)
        .firstWhere((g) => g['produitId'] == ligne['produitId']) as Map;
    g2.remove('coche');
    // A retire aussi un autre article de la liste
    final retire = ((ja2['listes'] as List).firstWhere((l) => l['id'] == liste['id'])['lignes'] as List).removeLast() as Map;
    a.ecrire(ja2);
    final modifA = envoi(a, 'A', dernierA);
    expect(b.appliquer(modifA), modifA.length);
    final lb = ((b.lire()['listes'] as List).firstWhere((l) => l['id'] == liste['id']) as Map)['lignes'] as List;
    expect(lb.firstWhere((g) => g['produitId'] == ligne['produitId'])['coche'], isNull);
    expect(lb.any((g) => g['produitId'] == retire['produitId']), isFalse);

    // Un message reçu deux fois, ou en retard, ne change rien.
    expect(b.appliquer(modifA), 0);
    expect(b.appliquer(modifB), 0);
  });

  test('rejoindre un foyer : produits ajoutés et listes en préparation gardés, ajoutés au foyer', () {
    final d = demo();
    final e = Etat.instance..enregistrementActif = false;
    e.lire(parLeModele(d));
    final s = e.secteursDu(e.rayonsCatalogue.first.id).first;
    final p = e.creerProduit('Croquettes Félix', secteur: s);
    p.marqueIds.add(e.marqueNommee('Purina').id);
    final l = e.creerListe(e.magasins.first.id, [], nom: 'Ma liste à garder');
    e.ajouterLigne(l, p.id);
    e.ajouterLigne(l, e.produits.first.id);
    l.lignes.first.quantite = 3;
    final garde = jsonDecode(jsonEncode(e.aReprendre())) as Map<String, dynamic>;

    // Le foyer rejoint : données du foyer (ici la démonstration), sans les ajouts de cet appareil.
    e.lire(parLeModele(d));
    expect(e.produits.any((x) => x.nom == 'Croquettes Félix'), isFalse);
    expect(e.reprendre(garde), isTrue);
    final repris = e.produits.firstWhere((x) => x.nom == 'Croquettes Félix');
    expect(e.estAjoute(repris), isTrue);
    expect(e.secteurCatalogue(repris.id)?.nom, s.nom);
    expect(repris.marqueIds.map((id) => e.marque(id)?.nom), contains('Purina'));
    final lr = e.listes.firstWhere((x) => x.nom == 'Ma liste à garder');
    expect(lr.lignes.length, 2);
    expect(lr.lignes.first.quantite, 3);

    // Un foyer encore vide (rien reçu) : on attend.
    e.lire(parLeModele(vide(d)));
    expect(e.reprendre(garde), isFalse);
  });

  test('modification simultanée du même objet : la plus récente l\'emporte partout', () {
    final d = demo();
    final a = Stockage.ouvrir(':memory:')..ecrire(parLeModele(d));
    a.horloge = Horloge('A');
    a.toutJournaliser(a.lire());
    final b = Stockage.ouvrir(':memory:')..ecrire(parLeModele(vide(d)));
    b.horloge = Horloge('B');
    b.appliquer(envoi(a, 'A'));
    final da = envoi(a, 'A').last['h'] as String;

    final ja = parLeModele(a.lire());
    ((ja['magasins'] as List).first as Map)['nom'] = 'Nom donné par A';
    a.ecrire(ja);
    final jb = parLeModele(b.lire());
    ((jb['magasins'] as List).first as Map)['nom'] = 'Nom donné par B';
    b.ecrire(jb); // plus tard que A

    final deA = envoi(a, 'A', da), deB = envoi(b, 'B');
    a.appliquer(deB);
    b.appliquer(deA);
    expect(((a.lire()['magasins'] as List).first as Map)['nom'], 'Nom donné par B');
    expect(((b.lire()['magasins'] as List).first as Map)['nom'], 'Nom donné par B');
  });

  test('l\'horloge avance toujours, même après une heure reçue d\'un appareil en avance', () {
    final h = Horloge('X');
    final a = h.suivante();
    final futur = '${(DateTime.now().millisecondsSinceEpoch + 60000).toString().padLeft(15, '0')}-00003-Y';
    h.recevoir(futur);
    final b = h.suivante();
    expect(b.compareTo(a), greaterThan(0));
    expect(b.compareTo(futur), greaterThan(0));
  });
}
