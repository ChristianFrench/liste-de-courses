// Base locale SQLite (schéma v2) : un état écrit puis relu doit être identique, un objet retiré
// ne doit pas revenir, le compteur d'utilisation suit la règle R4, et une base de la version 1
// est reprise. Lancé automatiquement par GitHub ; rien à faire à la main.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/stockage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dossier;
  setUp(() => dossier = Directory.systemTemp.createTempSync('stockage'));
  tearDown(() => dossier.deleteSync(recursive: true));

  Map<String, dynamic> demo() =>
      jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;

  /// État tel que l'application l'écrit (après passage par le modèle).
  Map<String, dynamic> parLeModele(Map<String, dynamic> j) {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(j);
    return jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>;
  }

  /// Retire les valeurs nulles et les commentaires, pour comparer deux états.
  Object? net(Object? v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.value != null && !(e.key as String).startsWith('_')) e.key: net(e.value)
      };
    }
    if (v is List) return [for (final x in v) net(x)];
    return v;
  }

  test('écrire puis relire redonne le même état', () {
    final chemin = '${dossier.path}/essai.db';
    final s = Stockage.ouvrir(chemin);
    expect(s.vide, isTrue);
    final etat = parLeModele(demo());
    s.ecrire(etat);
    expect(s.erreurs, isEmpty);
    s.fermer();

    final relu = Stockage.ouvrir(chemin);
    expect(relu.vide, isFalse);
    final lu = parLeModele(relu.lire());
    for (final cle in etat.keys.where((c) => !c.startsWith('_'))) {
      expect(net(lu[cle]), net(etat[cle]), reason: cle);
    }
    relu.fermer();
  });

  test('un magasin retiré ne revient pas', () {
    final chemin = '${dossier.path}/essai.db';
    final s = Stockage.ouvrir(chemin);
    final etat = parLeModele(demo());
    s.ecrire(etat);
    final avant = (etat['magasins'] as List).length;
    (etat['magasins'] as List).add({'id': 'mg-essai', 'nom': 'Essai', 'enseigne': '', 'ville': ''});
    s.ecrire(etat);
    (etat['magasins'] as List).removeLast();
    s.ecrire(etat);
    s.fermer();

    final lu = Stockage.ouvrir(chemin).lire();
    expect((lu['magasins'] as List).length, avant);
  });

  test("le compteur d'utilisation monte à l'entrée dans une liste", () {
    final s = Stockage.ouvrir('${dossier.path}/essai.db');
    final etat = parLeModele(demo());
    s.ecrire(etat);
    final avant = s.compteurs()['p1']!;
    final lignes = (etat['listes'] as List).first['lignes'] as List;
    lignes.removeWhere((g) => g['produitId'] == 'p1');
    s.ecrire(etat);
    expect(s.compteurs()['p1'], avant, reason: 'retirer ne fait pas baisser');
    lignes.add({'produitId': 'p1', 'quantite': 1});
    s.ecrire(etat);
    expect(s.compteurs()['p1'], avant + 1);
    s.fermer();
  });

  test('les réglages de l\'appareil ne font pas partie de l\'état', () {
    final s = Stockage.ouvrir('${dossier.path}/essai.db');
    s.definirReglage('mode_demo', '1');
    expect(s.vide, isTrue);
    expect(s.reglage('mode_demo'), '1');
    s.fermer();
  });

  test('une base de la version 1 est reprise', () {
    final chemin = '${dossier.path}/ancienne.db';
    final db = sqlite3.open(chemin);
    db.execute('CREATE TABLE objets (type TEXT, id TEXT, rang INTEGER, contenu TEXT, modifie TEXT, '
        'supprime INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (type, id))');
    final etat = parLeModele(demo());
    const types = {
      'membres': 'membre', 'typesPromotion': 'typePromotion', 'magasins': 'magasin', 'rayons': 'rayon',
      'secteurs': 'secteur', 'marques': 'marque', 'packagings': 'packaging', 'produits': 'produit',
      'emplacements': 'emplacement', 'parcours': 'parcours', 'listes': 'liste', 'historique': 'course', 'tickets': 'ticket',
    };
    etat.forEach((cle, valeur) {
      final type = types[cle];
      if (type == null) {
        db.execute("INSERT INTO objets VALUES ('config', ?, 0, ?, '', 0)", [cle, jsonEncode(valeur)]);
        return;
      }
      final l = valeur as List;
      for (var i = 0; i < l.length; i++) {
        final o = l[i] as Map;
        final id = type == 'emplacement' ? '${o['magasinId']}|${o['produitId']}' : o['id'];
        db.execute('INSERT INTO objets VALUES (?, ?, ?, ?, ?, 0)', [type, id, i, jsonEncode(o), '']);
      }
    });
    db.execute("INSERT INTO objets VALUES ('local', 'modeDemo', 0, '\"oui\"', '', 0)");
    db.dispose();

    final s = Stockage.ouvrir(chemin);
    expect(s.reglage('mode_demo'), '1');
    final lu = parLeModele(s.lire());
    expect(net(lu['produits']), net(etat['produits']));
    expect(net(lu['listes']), net(etat['listes']));
    s.fermer();
  });

  test('un magasin créé depuis le modèle « supermarché » reçoit ses rayons', () async {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(demo());
    final catalogue = jsonDecode(File(Etat.fichierCatalogueType).readAsStringSync()) as Map<String, dynamic>;
    final m = e.creerMagasin('Super essai');
    final n = await e.appliquerModele(m, 2, catalogue: catalogue);
    expect(n, greaterThan(500));
    expect(e.rayonsDu(m.id).length, greaterThan(20));
    expect(e.produits.where((p) => p.nom.toLowerCase() == 'lait demi-écrémé').length, lessThanOrEqualTo(1));
  });

  test('un magasin supprimé va dans la corbeille et se restaure, même après relecture', () {
    final chemin = '${dossier.path}/essai.db';
    final e = Etat.instance..enregistrementActif = false;
    e.lire(demo());
    final s = Stockage.ouvrir(chemin);
    s.ecrire(e.versJson());
    final mg = e.magasins.last;
    e.ajouterSecteur(e.ajouterRayon(mg.id, 'Rayon essai').id, 'Secteur essai');
    s.ecrire(e.versJson());
    final nbRayons = e.rayonsDu(mg.id).length;
    final nomRayon = e.rayonsDu(mg.id).first.nom;
    e.supprimer(mg);
    expect(e.magasin(mg.id), isNull);
    expect(e.corbeille, hasLength(1));
    s.ecrire(e.versJson());
    expect(s.erreurs, isEmpty);
    s.fermer();

    // Relue depuis la base : le magasin est absent, la corbeille est gardée.
    final s2 = Stockage.ouvrir(chemin);
    e.lire(s2.lire());
    expect(e.magasin(mg.id), isNull);
    e.restaurer(e.corbeille.single);
    s2.ecrire(e.versJson());
    expect(s2.erreurs, isEmpty);
    s2.fermer();

    e.lire(Stockage.ouvrir(chemin).lire());
    expect(e.magasin(mg.id)?.nom, mg.nom);
    expect(e.rayonsDu(mg.id), hasLength(nbRayons));
    expect(e.rayonsDu(mg.id).map((r) => r.nom), contains(nomRayon));
    expect(e.corbeille, isEmpty);

    // Un nouveau rayon peut reprendre le nom d'un rayon supprimé.
    final s3 = Stockage.ouvrir(chemin);
    e.lire(s3.lire());
    e.supprimer(e.rayonsDu(mg.id).firstWhere((r) => r.nom == 'Rayon essai'));
    s3.ecrire(e.versJson());
    e.ajouterRayon(mg.id, 'Rayon essai');
    s3.ecrire(e.versJson());
    expect(s3.erreurs, isEmpty);
    s3.fermer();
  });

  test('un produit déjà utilisé ne peut pas être supprimé', () {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(demo());
    final utilise = e.produits.firstWhere(e.produitUtilise);
    expect(e.suppressionImpossible(utilise), isNotNull);
    expect(e.suppressionImpossible(e.magasins.last), isNull);
  });
}
