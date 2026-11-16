// Filet de sécurité (16/11/2026) : trois appareils modifient le même foyer au hasard, hors ligne puis en ligne ;
// les messages arrivent en désordre, en double, en retard. À la fin, les trois bases doivent être identiques.
// Plusieurs graines fixes : un échec se rejoue à l'identique.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/stockage.dart';
import 'package:liste_de_courses/donnees/synchro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> demo() =>
      jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;

  Map<String, dynamic> parLeModele(Map<String, dynamic> j) {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(j);
    return jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>;
  }

  Map<String, dynamic> vide(Map<String, dynamic> d, String n) => {
        'foyer': {'id': 'f-$n', 'nom': 'Mon foyer', 'dateCreation': '2026-10-23'},
        'membres': [
          {'id': 'm-$n', 'nomAffiche': n, 'role': 'membre', 'moi': true}
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

  /// Ce qui doit être identique partout : listes (lignes triées), magasins, produits, emplacements, secteurs,
  /// objet par objet ; rend les écarts lisibles (au plus 12).
  Map<String, String> objets(Stockage s) {
    final j = s.lire();
    final res = <String, String>{};
    for (final (c, cle) in [('listes', 'id'), ('magasins', 'id'), ('produits', 'id'), ('emplacements', 'produitId'), ('secteurs', 'id')]) {
      for (final o in (j[c] as List).cast<Map>()) {
        if (c == 'listes') {
          for (final g in (o['lignes'] as List).cast<Map>()) {
            res['ligne ${o['id']}/${g['produitId']}'] = jsonEncode(g);
          }
          res['liste ${o['id']}'] = jsonEncode({...o}..remove('lignes'));
        } else {
          // nbUtilisations : compteur propre à chaque appareil, connu pour ne pas converger (le plus récent
          // l'emporte, les ajouts concurrents se perdent) ; sans effet sur les listes.
          res['$c ${o[cle]}'] = jsonEncode({...o}..remove('nbUtilisations'));
        }
      }
    }
    return res;
  }

  List<String> ecarts(Stockage a, Stockage b) {
    final oa = objets(a), ob = objets(b);
    return [
      for (final k in {...oa.keys, ...ob.keys})
        if (oa[k] != ob[k]) '$k\n    A: ${oa[k] ?? '(absent)'}\n    autre: ${ob[k] ?? '(absent)'}'
    ].take(12).toList();
  }

  /// Une modification au hasard, faite par l'application de l'appareil.
  String modifier(Stockage s, Random r, String n) {
    final j = parLeModele(s.lire());
    final listes = (j['listes'] as List).cast<Map>();
    final produits = (j['produits'] as List).cast<Map>();
    final membres = [for (final m in (demo()['membres'] as List).cast<Map>()) m['id']];
    final quoi = r.nextInt(7);
    String fait;
    if (quoi <= 3 && listes.isNotEmpty) {
      final l = listes[r.nextInt(listes.length)];
      final lignes = (l['lignes'] as List).cast<Map>();
      if (quoi == 0 || lignes.isEmpty) {
        final dedans = {for (final g in lignes) g['produitId']};
        final libres = [for (final p in produits) if (!dedans.contains(p['id'])) p['id']];
        if (libres.isEmpty) return 'rien';
        (l['lignes'] as List).add({'produitId': libres[r.nextInt(libres.length)], 'quantite': 1 + r.nextInt(3)});
        fait = 'ajoute une ligne à ${l['id']}';
      } else if (quoi == 1) {
        final g = lignes[r.nextInt(lignes.length)];
        (l['lignes'] as List).remove(g);
        fait = 'retire ${g['produitId']} de ${l['id']}';
      } else if (quoi == 2) {
        final g = lignes[r.nextInt(lignes.length)];
        g['quantite'] = 1 + r.nextInt(9);
        fait = 'quantité de ${g['produitId']}';
      } else {
        final g = lignes[r.nextInt(lignes.length)];
        if (g['coche'] == null) {
          g['coche'] = {'par': membres[r.nextInt(membres.length)], 'le': DateTime.now().toIso8601String()};
        } else {
          g.remove('coche');
        }
        fait = 'coche ${g['produitId']}';
      }
    } else if (quoi == 4) {
      final m = (j['magasins'] as List).cast<Map>();
      final x = m[r.nextInt(m.length)];
      x['nom'] = 'Magasin $n${r.nextInt(1000)}';
      fait = 'renomme ${x['id']}';
    } else if (quoi == 5) {
      final e = (j['emplacements'] as List).cast<Map>();
      final s2 = (j['secteurs'] as List).cast<Map>();
      if (e.isEmpty) return 'rien';
      final x = e[r.nextInt(e.length)];
      x['secteurId'] = s2[r.nextInt(s2.length)]['id'];
      fait = 'déplace ${x['produitId']}';
    } else {
      final p = produits[r.nextInt(produits.length)];
      p['nom'] = '${(p['nom'] as String).split(' #').first} #$n${r.nextInt(100)}';
      fait = 'renomme ${p['id']}';
    }
    s.ecrire(parLeModele(j));
    return fait;
  }

  // GRAINES=200 flutter test test/convergence_test.dart : essai plus long, à la main.
  final n = int.tryParse(Platform.environment['GRAINES'] ?? '');
  for (final graine in n == null ? [1, 2, 3, 5, 8, 13, 21, 34, 55, 89] : [for (var i = 1; i <= n; i++) i]) {
    test('trois appareils, modifications au hasard, messages en désordre : tout converge (graine $graine)', () {
      final r = Random(graine);
      final d = demo();
      final noms = ['A', 'B', 'C'];
      final bases = <String, Stockage>{};
      bases['A'] = Stockage.ouvrir(':memory:')..ecrire(parLeModele(d));
      bases['A']!.horloge = Horloge('A');
      bases['A']!.toutJournaliser(bases['A']!.lire());
      final initial = envoi(bases['A']!, 'A');
      for (final n in ['B', 'C']) {
        final s = Stockage.ouvrir(':memory:')..ecrire(parLeModele(vide(d, n)));
        s.horloge = Horloge(n);
        s.appliquer(initial);
        bases[n] = s;
      }
      // Ce que chaque appareil a déjà envoyé (dernière heure partie) et les messages en route vers chacun.
      final parti = {for (final n in noms) n: n == 'A' ? initial.last['h'] as String : ''};
      final enRoute = {for (final n in noms) n: <List<Map<String, dynamic>>>[]};
      final journal = <String>[];

      void publier(String n) {
        final nouveaux = envoi(bases[n]!, n, parti[n]!);
        if (nouveaux.isEmpty) return;
        parti[n] = nouveaux.last['h'] as String;
        for (final autre in noms) {
          if (autre != n) enRoute[autre]!.add(nouveaux);
        }
      }

      void recevoir(String n, {bool tout = false}) {
        final file = enRoute[n]!;
        if (file.isEmpty) return;
        file.shuffle(r);
        final k = tout ? file.length : 1 + r.nextInt(file.length);
        final lot = file.sublist(0, k);
        file.removeRange(0, k);
        for (final paquet in lot) {
          final p = [...paquet]..shuffle(r);
          bases[n]!.appliquer(p);
          if (r.nextInt(5) == 0) bases[n]!.appliquer(paquet); // reçu deux fois
        }
      }

      /// Lignes vivantes selon le journal d'échange de [x] (dernier objet par clé) contre lignes lues dans sa base.
      String? incoherence(String x) {
        final dernier = <String, Map<String, dynamic>>{};
        for (final auteur in noms) {
          for (final o in envoi(bases[x]!, auteur).where((o) => o['t'] == 'ligne_liste')) {
            final k = o['k'] as String;
            if (dernier[k] == null || (o['h'] as String).compareTo(dernier[k]!['h'] as String) > 0) dernier[k] = o;
          }
        }
        final vivantes = {
          for (final e in dernier.entries)
            if (e.value['v'] != null && (jsonDecode(e.value['v'] as String) as Map)['supprime'] == 0) (jsonDecode(e.key) as List).first as String
        };
        final lues = {
          for (final l in (bases[x]!.lire()['listes'] as List).cast<Map>())
            for (final g in (l['lignes'] as List).cast<Map>()) '${l['id']}|${g['produitId']}'
        };
        final d1 = vivantes.difference(lues), d2 = lues.difference(vivantes);
        return d1.isEmpty && d2.isEmpty ? null : 'vivantes non lues $d1, lues non vivantes $d2';
      }

      for (var pas = 0; pas < 60; pas++) {
        final n = noms[r.nextInt(3)];
        journal.add('$n : ${modifier(bases[n]!, r, n)}');
        if (Platform.environment['TRACE'] != null) {
          for (final x in noms) {
            final i = incoherence(x);
            if (i != null) print('PAS $pas après « ${journal.last} » : chez $x $i');
          }
        }
        // Hors ligne une fois sur trois : l'envoi attend.
        if (r.nextInt(3) != 0) publier(n);
        final qui = noms[r.nextInt(3)];
        recevoir(qui);
        if (Platform.environment['TRACE'] != null) {
          final i = incoherence(qui);
          if (i != null) print('PAS $pas après réception chez $qui : $i');
        }
      }
      // Tout le monde se reconnecte : tout part, tout arrive.
      for (var tour = 0; tour < 3; tour++) {
        for (final n in noms) {
          publier(n);
        }
        for (final n in noms) {
          recevoir(n, tout: true);
        }
      }
      for (final n in noms) {
        expect(bases[n]!.erreurs, isEmpty, reason: 'erreurs de $n');
        expect(bases[n]!.nbEnAttente, 0, reason: 'objets en attente chez $n');
      }
      for (final n in ['B', 'C']) {
        final e = ecarts(bases['A']!, bases[n]!);
        if (e.isNotEmpty && Platform.environment['TRACE'] != null) {
          final cible = Platform.environment['TRACE']!;
          for (final x in noms) {
            for (final auteur in noms) {
              for (final o in envoi(bases[x]!, auteur).where((o) => '${o['k']}'.contains(cible))) {
                print('chez $x, objet de $auteur : ${o['t']} ${o['k']} h=${o['h']} v=${o['v']}');
              }
            }
          }
        }
        if (e.isNotEmpty) print('ÉCARTS $n (graine $graine) :\n${e.join('\n')}\nJOURNAL :\n${journal.join('\n')}');
        expect(e, isEmpty, reason: '$n diffère de A');
      }
    });
  }

  test('une ligne cochée par un membre encore inconnu de l\'appareil est gardée (coché par : vidé)', () {
    final d = demo();
    final a = Stockage.ouvrir(':memory:')..ecrire(parLeModele(d));
    final j = parLeModele(a.lire());
    final l3 = (j['listes'] as List).cast<Map>().firstWhere((l) => l['id'] == 'l3');
    final g = (l3['lignes'] as List).cast<Map>().first;
    g['coche'] = {'par': 'membre-pas-encore-recu', 'le': '2026-11-16T10:00:00'};
    a.ecrire(parLeModele(j));
    final relu = ((a.lire()['listes'] as List).cast<Map>().firstWhere((l) => l['id'] == 'l3')['lignes'] as List).cast<Map>();
    expect(relu.map((x) => x['produitId']), contains(g['produitId']), reason: 'avant le 16/11, la ligne disparaissait');
    expect(relu.length, (l3['lignes'] as List).length);
  });

  test('deux appareils appliquent le même catalogue commun hors ligne : mêmes objets, aucun doublon après échange', () {
    final d = demo();
    final cat = jsonDecode(File('assets/catalogue_type.json').readAsStringSync()) as Map<String, dynamic>;
    cat['version'] = 999;
    final a = Stockage.ouvrir(':memory:')..ecrire(parLeModele(d));
    a.horloge = Horloge('A');
    a.toutJournaliser(a.lire());
    final b = Stockage.ouvrir(':memory:')..ecrire(parLeModele(vide(d, 'B')));
    b.horloge = Horloge('B');
    b.appliquer(envoi(a, 'A'));
    final da = envoi(a, 'A').last['h'] as String;

    final e = Etat.instance..enregistrementActif = false;
    for (final s in [a, b]) {
      e.lire(s.lire());
      expect(e.appliquerCatalogueCommun(cat), isNotEmpty);
      s.ecrire(jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>);
      // Appliqué une seconde fois : rien de nouveau, rien à envoyer.
      final avant = envoi(s, s == a ? 'A' : 'B').length;
      e.lire(s.lire());
      expect(e.appliquerCatalogueCommun(cat), isEmpty);
      s.ecrire(jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>);
      expect(envoi(s, s == a ? 'A' : 'B').length, avant);
    }
    b.appliquer(envoi(a, 'A', da));
    a.appliquer(envoi(b, 'B'));
    expect(ecarts(a, b), isEmpty);
    // Aucun produit en double (même nom) dans un même secteur.
    final j = b.lire();
    final parSecteur = <String, List<String>>{};
    final nom = {for (final p in (j['produits'] as List).cast<Map>()) p['id']: p['nom']};
    for (final x in (j['emplacements'] as List).cast<Map>()) {
      (parSecteur[x['secteurId'] as String] ??= []).add('${nom[x['produitId']]}');
    }
    for (final e in parSecteur.entries) {
      expect(e.value.toSet().length, e.value.length, reason: 'doublon dans ${e.key}');
    }
  });

  test('base sur disque : fermée puis rouverte, rien de perdu, et relue puis réécrite, rien à renvoyer', () {
    final dossier = Directory.systemTemp.createTempSync('base');
    final chemin = '${dossier.path}/base.db';
    final a = Stockage.ouvrir(chemin)..ecrire(parLeModele(demo()));
    a.horloge = Horloge('A');
    a.toutJournaliser(a.lire());
    final avant = objets(a);
    final n = envoi(a, 'A').length;
    a.fermer();
    final b = Stockage.ouvrir(chemin);
    b.horloge = Horloge('A');
    expect(objets(b), avant);
    b.ecrire(parLeModele(b.lire()));
    expect(envoi(b, 'A').length, n, reason: 'relire et réécrire ne doit rien journaliser');
    b.fermer();
    dossier.deleteSync(recursive: true);
  });
}

