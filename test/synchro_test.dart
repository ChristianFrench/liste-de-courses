// Synchronisation entre deux appareils (deux bases locales), sans serveur : ce que l'un envoie,
// l'autre l'intègre ; rien ne repart en écho ; la modification la plus récente l'emporte.
// Lancé automatiquement par GitHub ; rien à faire à la main.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:liste_de_courses/donnees/catalogue_commun.dart';
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

  test('catalogue commun : nouveautés ajoutées, ajouts du foyer intégrés, rien d\'utilisé retiré', () {
    final d = demo();
    final e = Etat.instance..enregistrementActif = false;
    e.lire(parLeModele(d));
    final perso = e.creerProduit('Croquettes Félix');
    final utilise = e.listes.first.lignes.first.produitId;
    final nomUtilise = e.produit(utilise)!.nom;
    final rayonExistant = e.rayonsCatalogue.first, secteurExistant = e.secteursDu(rayonExistant.id).first;
    final nb = e.produits.length;
    Map<String, dynamic> version(int v) => {
          'version': v,
          'rayons': [
            {
              'nom': 'Animalerie',
              'secteurs': [
                {
                  'nom': 'Chats',
                  'taille': 1,
                  'produits': [
                    {'nom': 'Croquettes Félix', 'taille': 1},
                    {'nom': 'Litière', 'taille': 1, 'formats': ['10 l']},
                  ]
                }
              ]
            },
            {
              'nom': rayonExistant.nom,
              'secteurs': [
                {'nom': secteurExistant.nom, 'taille': 1, 'produits': [{'nom': 'Nouveauté du rayon', 'taille': 1}]}
              ]
            },
          ],
          'retires': [
            {'type': 'produit', 'nom': nomUtilise}
          ],
        };
    final lignes = e.appliquerCatalogueCommun(version(10));
    expect(lignes, containsAll(['Nouveau rayon : Animalerie', 'Chats : Litière', '${secteurExistant.nom} : Nouveauté du rayon']));
    expect(e.produits.length, nb + 2);
    expect(e.estAjoute(perso), isFalse, reason: 'au catalogue commun maintenant');
    expect(e.secteurCatalogue(perso.id)?.nom, 'Chats');
    for (final m in e.magasins) {
      expect(e.rayons.where((r) => r.magasinId == m.id && r.nom == 'Animalerie'), hasLength(1));
    }
    expect(e.produit(utilise), isNotNull, reason: 'dans une liste : pas retiré');
    expect(e.nouveautesCatalogue?['version'], 10);
    expect(e.appliquerCatalogueCommun(version(10)), isEmpty, reason: 'déjà ajoutée');
    // Le même nom dans deux secteurs : deux produits, chacun dans son secteur.
    final v11 = version(11);
    ((v11['rayons'] as List).first['secteurs'] as List).add({
      'nom': 'Chiens',
      'taille': 1,
      'produits': [
        {'nom': 'Litière', 'taille': 1}
      ]
    });
    e.appliquerCatalogueCommun(v11);
    final litieres = e.produits.where((p) => p.nom == 'Litière').toList();
    expect(litieres.map((p) => e.secteurCatalogue(p.id)?.nom).toSet(), {'Chats', 'Chiens'});
    e.appliquerCatalogueCommun(version(12)..['rayons'] = v11['rayons']);
    expect(e.produits.where((p) => p.nom == 'Litière'), hasLength(2), reason: 'rien de doublé à la version suivante');
    // Un deuxième appareil du foyer qui l'ajoute aussi crée les mêmes identifiants.
    final ids = {for (final p in e.produits) p.id};
    expect(ids, contains('pc-litière'));
  });

  test('catalogue ouvert à tous les foyers : apports reçus, renommer crée un produit, foyer isolé', () {
    final e = Etat.instance..enregistrementActif = false;
    // Foyer A : un rayon, un secteur, un produit rangé et une marque de secteur ajoutés.
    e.lire(parLeModele(demo()));
    final r = e.ajouterRayonCatalogue('Animalerie')!;
    final chats = e.ajouterSecteurCatalogue(r, 'Chats')!;
    e.enregistrerProduitAjoute(libelle: 'Croquettes', marqueNom: 'Félix', secteur: chats);
    e.ajouterMarqueSecteur(chats, 'Whiskas');
    e.creerProduit('Non placé du foyer A');
    final apportsA = jsonDecode(jsonEncode(e.apports())) as Map<String, dynamic>;
    expect(apportsA['rayons'], ['Animalerie']);
    expect(apportsA['secteurs'], containsAll(['Animalerie/Animalerie', 'Animalerie/Chats']));
    expect([for (final p in apportsA['produits'] as List) p['nom']], ['Croquettes Félix'], reason: 'un non placé reste au foyer');
    expect(jsonEncode(e.apports()), jsonEncode(apportsA), reason: 'le même texte tant que rien ne change');

    // Foyer B (le catalogue de départ) reçoit les apports de A.
    e.lire(parLeModele(demo()));
    final nb = e.produits.length;
    expect(e.appliquerApports([apportsA]), greaterThan(0));
    final ref = e.rayonsCatalogue.firstWhere((x) => x.nom == 'Animalerie');
    final chatsB = e.secteursDu(ref.id).firstWhere((x) => x.nom == 'Chats');
    final croquettes = e.produitsDuSecteur(chatsB).single;
    expect(croquettes.nom, 'Croquettes Félix');
    expect(e.estRecu(croquettes), isTrue);
    expect(e.marque(croquettes.marqueIds.first)?.nom, 'Félix');
    expect(e.marquesDuSecteur(chatsB), contains('Whiskas'));
    for (final m in e.magasins) {
      expect(e.rayons.where((x) => x.magasinId == m.id && x.nom == 'Animalerie'), hasLength(1));
    }
    expect(e.produits.length, nb + 1);
    expect(e.appliquerApports([apportsA]), 0, reason: 'rien de doublé à la lecture suivante');
    expect(e.apports()['produits'], isEmpty, reason: 'ce qui est reçu ne repart pas');

    // Foyer isolé : les apports reçus sont gardés mais cachés.
    e.isolerCatalogue(true);
    expect(e.produitsDuSecteur(chatsB), isEmpty);
    expect(e.produitsVisibles.contains(croquettes), isFalse);
    expect(e.rayonsVisibles.any((x) => x.nom == 'Animalerie'), isFalse);
    expect(e.marquesDuSecteur(chatsB), isNot(contains('Whiskas')));
    e.isolerCatalogue(false);
    expect(e.produitsDuSecteur(chatsB), [croquettes]);

    // Renommer et ranger ailleurs un article d'une liste : un nouveau produit, l'ancien reste.
    final l = e.listes.firstWhere((x) => x.lignes.isNotEmpty);
    final g = l.lignes.first;
    final ancien = e.produit(g.produitId)!;
    final autre = e.secteursDu(e.rayonsCatalogue.first.id).last;
    final q = e.remplacerArticle(l, ancien, 'Noix de cajou', autre);
    expect(q.id, isNot(ancien.id));
    expect(e.produit(ancien.id), isNotNull);
    expect(l.lignes.first.produitId, q.id);
    expect(l.lignes.first.quantite, g.quantite);
    expect(e.secteurCatalogue(q.id)?.id, autre.id);
    expect(e.estAjoute(q), isTrue);
    expect([for (final p in e.apports()['produits'] as List) p['nom']], contains('Noix de cajou'));
    expect(e.remplacerArticle(l, q, 'Noix de cajou', autre).id, q.id, reason: 'rien ne change');
  });

  test('éditeur : les ajouts des foyers entrent dans son brouillon ; ce qu\'il retire ne revient plus', () {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(parLeModele(demo()));
    final r = e.ajouterRayonCatalogue('Animalerie')!;
    final chats = e.ajouterSecteurCatalogue(r, 'Chats')!;
    e.enregistrerProduitAjoute(libelle: 'Croquettes', marqueNom: 'Félix', secteur: chats);
    e.enregistrerProduitAjoute(libelle: 'Croquetes', secteur: chats); // une faute de frappe
    final apportsA = jsonDecode(jsonEncode(e.apports())) as Map<String, dynamic>;

    // L'éditeur reprend les ajouts, retire la faute, publie.
    final b = Brouillon.lire({'rayons': [], 'version': 1});
    expect(b.absorber([apportsA]), greaterThanOrEqualTo(4));
    final ry = b.rayon('Animalerie')!, sc = b.secteur(ry, 'Chats')!;
    expect([for (final p in sc.produits) p.nom], containsAll(['Croquettes Félix', 'Croquetes']));
    b.retirerProduit(sc, b.produitDans(sc, 'Croquetes')!);
    expect(b.absorber([apportsA]), 0, reason: 'ce qui est retiré ne revient pas dans le brouillon');
    final commun = jsonDecode(jsonEncode(b.versJson()..['version'] = 50)) as Map<String, dynamic>;

    // Le foyer A reçoit la correction : la faute disparaît, et n'est plus déposée.
    e.appliquerCatalogueCommun(commun);
    expect(e.produits.any((p) => p.nom == 'Croquetes'), isFalse);
    expect(e.estAjoute(e.produits.firstWhere((p) => p.nom == 'Croquettes Félix')), isFalse, reason: 'au catalogue commun');
    expect(e.apports()['produits'], isEmpty);

    // Un foyer B qui reçoit encore l'ancien dépôt de A ne reprend pas la faute.
    e.lire(parLeModele(demo()));
    e.appliquerCatalogueCommun(commun);
    e.appliquerApports([apportsA]);
    expect(e.produits.any((p) => p.nom == 'Croquetes'), isFalse);
    expect(e.produits.where((p) => p.nom == 'Croquettes Félix'), hasLength(1));
  });

  test('ajout au catalogue commun depuis un texte : titres de secteur, puis produits', () {
    final b = Brouillon.lire(demo()..['rayons'] = [
          {
            'nom': 'Fruits et légumes',
            'secteurs': [
              {'nom': 'Fruits', 'taille': 1, 'produits': [{'nom': 'Pommes', 'taille': 1}]}
            ]
          }
        ]);
    final lu = lireTexteCatalogue(b, 'Fruits :\n- Pommes\n- Kakis\n\nAnimalerie / Chats :\nCroquettes\nlitière\nLitière\n');
    expect(lu.groupes.map((g) => '${g.rayon}/${g.secteur}'), ['Fruits et légumes/Fruits', 'Animalerie/Chats']);
    expect(lu.groupes.first.nouveaux, ['Kakis']);
    expect(lu.groupes.first.connus, ['Pommes']);
    expect(lu.groupes.last.rayonNeuf, isTrue);
    expect(lu.groupes.last.nouveaux, ['Croquettes', 'Litière']);
    expect(ajouterLecture(b, lu), 3);
    expect(b.produit('kakis')?.$2.nom, 'Fruits');
    b.renommerProduit(b.produit('Kakis')!.$3, 'Kaki');
    b.retirerProduit(b.produit('Croquettes')!.$2, b.produit('Croquettes')!.$3);
    final j = b.versJson();
    expect(j['renommes'], [
      {'type': 'produit', 'secteur': 'Fruits', 'ancien': 'Kakis', 'nouveau': 'Kaki'}
    ]);
    expect((j['retires'] as List).single['nom'], 'Croquettes');
    final chats = b.secteur(b.rayon('Animalerie')!, 'Chats')!;
    final chiens = b.ajouterSecteur(b.rayon('Animalerie')!, 'Chiens');
    expect(b.ajouterProduit(chiens, 'Litière'), isTrue, reason: 'même nom, autre secteur');
    expect(b.ajouterProduit(chats, 'litière'), isFalse, reason: 'déjà dans ce secteur');
    expect(lireTexteCatalogue(b, 'Animalerie / Chiens :\nLitière\nOs\n').groupes.single.nouveaux, ['Os']);
    b.retirerSecteur(b.rayon('Animalerie')!, chiens);
  
    // Envoi compressé : le même catalogue une fois relu, bien plus court
    final paquet = CatalogueCommun.emballer(b.versJson());
    expect(paquet, startsWith('gz:'));
    expect(jsonEncode(CatalogueCommun.deballer(paquet)), jsonEncode(b.versJson()));
    expect(CatalogueCommun.deballer(jsonEncode({'version': 1}))['version'], 1, reason: 'ancien format lu aussi');
    // Titre simple inconnu : pas de rayon créé d'office, le rayon est à choisir.
    final l2 = lireTexteCatalogue(b, 'Oiseaux :\nGraines\n');
    expect(l2.groupes.single.rayonAChoisir, isTrue);
    expect(ajouterLecture(b, l2), 0);
    expect(b.rayon('Oiseaux'), isNull);
    l2.groupes.single.rayon = 'Animalerie';
    expect(ajouterLecture(b, l2), 1);
    expect(b.produit('Graines')?.$2.nom, 'Oiseaux');
    // Depuis un rayon : le secteur inconnu y est créé.
    expect(lireTexteCatalogue(b, 'Poissons :\nAquarium\n', rayonDefaut: 'Animalerie').groupes.single.rayon, 'Animalerie');
    // Déplacer un secteur, supprimer un rayon non vide.
    b.deplacerSecteur(b.rayon('Animalerie')!, b.secteur(b.rayon('Animalerie')!, 'Oiseaux')!, b.rayon('Fruits et légumes')!);
    expect(b.produit('Graines')?.$1.nom, 'Fruits et légumes');
    b.retirerRayon(b.rayon('Animalerie')!);
    expect(b.rayon('Animalerie'), isNull);
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

  test('réparation du journal d\'échange : index reconstruits, rien de perdu', () {
    final a = Stockage.ouvrir(':memory:');
    a.ecrire(parLeModele(demo()));
    a.horloge = Horloge('A');
    a.toutJournaliser(a.lire());
    final avant = envoi(a, 'A').length;
    final r = a.reparerJournal();
    expect(r, startsWith('index reconstruits'));
    expect(r, contains('ok'));
    expect(envoi(a, 'A').length, avant, reason: 'rien n\'est renoté : la base et le journal concordent');
  });

  test('base abîmée : toutes les lignes recopiées dans une base neuve', () {
    final dossier = Directory.systemTemp.createTempSync('reparation');
    final a = Stockage.ouvrir('${dossier.path}/abimee.db');
    a.ecrire(parLeModele(demo()));
    expect(a.verifier(), isNull);
    final (n, echecs, pertes) = a.recopierDans('${dossier.path}/neuve.db');
    expect(echecs, isEmpty);
    expect(pertes, isEmpty);
    expect(n, greaterThan(100));
    final b = Stockage.ouvrir('${dossier.path}/neuve.db');
    expect(b.verifier(), isNull);
    expect(jsonEncode(b.lire()), jsonEncode(a.lire()));
    a.fermer();
    b.fermer();
    dossier.deleteSync(recursive: true);
  });

  test('base abîmée dans une table : les lignes lisibles sont recopiées une à une', () {
    final dossier = Directory.systemTemp.createTempSync('reparation');
    final chemin = '${dossier.path}/abimee.db';
    final a = Stockage.ouvrir(chemin);
    a.ecrire(parLeModele(demo()));
    for (var i = 0; i < 600; i++) {
      a.definirReglage('essai_$i', 'x' * 200);
    }
    a.fermer();
    // Page racine de la table parametre : le premier enfant pointe vers une page qui n'existe pas.
    final brut = sqlite3.open(chemin);
    final racine = brut.select("SELECT rootpage FROM sqlite_master WHERE name = 'parametre'").first['rootpage'] as int;
    final taille = brut.select('PRAGMA page_size').first.values.first as int;
    brut.dispose();
    final f = File(chemin).openSync(mode: FileMode.append);
    final debut = (racine - 1) * taille;
    f.setPositionSync(debut);
    final entete = f.readSync(12);
    expect(entete[0], 5, reason: 'page intérieure');
    f.setPositionSync(debut + 12);
    final cellule = f.readSync(2);
    f.setPositionSync(debut + (cellule[0] << 8 | cellule[1]));
    f.writeFromSync([13, 0, 0, 0]);
    f.closeSync();

    final b = Stockage.ouvrir(chemin);
    expect(b.verifier(), isNotNull);
    final (n, echecs, pertes) = b.recopierDans('${dossier.path}/neuve.db');
    expect(echecs, isEmpty);
    expect(pertes.single, startsWith('parametre'));
    final c = Stockage.ouvrir('${dossier.path}/neuve.db');
    expect(c.verifier(), isNull);
    expect(c.reglage('essai_599'), 'x' * 200);
    expect((c.lire()['listes'] as List).length, 4);
    b.fermer();
    c.fermer();
    dossier.deleteSync(recursive: true);
  });
}
