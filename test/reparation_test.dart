// 12/11/2026 : la conversion vers la structure commune avait effacé tous les emplacements des bases existantes
// (magasin fictif « Structure commune » absent). Cause corrigée, et réparation à l'ouverture.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/catalogue_type.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/reparation.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void sql(Directory d, String requete) {
    final db = sqlite3.open('${d.path}/liste_de_courses.db');
    db.execute('PRAGMA foreign_keys = OFF');
    db.execute(requete);
    db.dispose();
  }

  test('une base sans le magasin « Structure commune » garde ses emplacements', () async {
    final dossier = Directory.systemTemp.createTempSync('sans_commun');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    final n = etat.emplacements.length;
    expect(n, greaterThan(100));
    // Base d'avant le 12/11/2026 : pas de magasin fictif (le déclencheur qui interdit la suppression est levé).
    final db = sqlite3.open('${dossier.path}/liste_de_courses.db');
    for (final r in db.select("SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'magasin'")) {
      db.execute('DROP TRIGGER "${r['name']}"');
    }
    db.dispose();
    sql(dossier, "DELETE FROM magasin WHERE id = 'commun'");
    await etat.charger(dossier: dossier);
    // Un enregistrement qui ajoute un emplacement (ici : un produit créé dans un secteur).
    final p = etat.creerProduit('Spécialité maison', secteur: etat.secteurs.last);
    await etat.enregistrer();
    await etat.charger(dossier: dossier);
    expect(etat.emplacements.length, n + 1);
    expect(etat.secteurDe(etat.magasins.first.id, p.id)?.id, etat.secteurs.last.id);
    expect(emplacementsPerdus(etat), isFalse);
  });

  test('emplacements perdus : replacés d\'après une sauvegarde, puis d\'après le catalogue', () async {
    final dossier = Directory.systemTemp.createTempSync('perdus');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    // Un produit ajouté par le foyer, rangé ailleurs que dans le catalogue : seule la sauvegarde le connaît.
    final secteur = etat.secteurs.last;
    final ajoute = etat.creerProduit('Spécialité maison', secteur: secteur);
    final copie = etat.versJson();
    final avant = {for (final e in etat.emplacements) e.produitId: e.secteurId};
    sql(dossier, 'DELETE FROM emplacement');
    await etat.charger(dossier: dossier);
    expect(etat.emplacements, isEmpty);
    expect(emplacementsPerdus(etat), isTrue);

    final r = etat.reparerEmplacements(copies: [copie], catalogue: null);
    expect(r.copies, avant.length);
    expect(etat.secteurDe(etat.magasins.first.id, ajoute.id)?.id, secteur.id);

    // Sans sauvegarde : le catalogue commun replace les produits du catalogue.
    sql(dossier, 'DELETE FROM emplacement');
    await etat.charger(dossier: dossier);
    final catalogue = await CatalogueType.lireJson();
    final r2 = etat.reparerEmplacements(catalogue: catalogue);
    expect(r2.catalogue, greaterThan(avant.length - 10));
    expect(emplacementsPerdus(etat), isFalse);
    await etat.charger(dossier: dossier);
    expect(etat.emplacements.length, r2.catalogue);
  });
}
