// « Gestion du catalogue » : échange avec Excel et écran principal.
// Lancé automatiquement par GitHub ; rien à faire à la main.

import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/catalogue_type.dart';
import 'package:liste_de_courses/gestion_catalogue.dart';
import 'package:liste_de_courses/gestion_catalogue/tableur.dart';

CatalogueType livre() =>
    CatalogueType.lire(jsonDecode(File(CatalogueType.fichierLivre).readAsStringSync()) as Map<String, dynamic>);

CatalogueType petit() => CatalogueType([
      CatRayon('Fruits et légumes', [
        CatSecteur('Fruits', 1, [CatProduit('Pommes', 1, listes: 20), CatProduit('Brugnons', 1, listes: 45)]),
        CatSecteur('Légumes', 1, [CatProduit('Ail', 1)]),
      ]),
      CatRayon('Crèmerie', [
        CatSecteur('Yaourts', 1, [CatProduit('Yaos', 1, listes: 18, marques: ['Yaos'])]),
      ]),
    ]);

List<int> tableau(List<List<String>> lignes) {
  final x = Excel.createExcel();
  final f = x[x.getDefaultSheet()!];
  for (final l in lignes) {
    f.appendRow([for (final v in l) TextCellValue(v)]);
  }
  return x.save()!;
}

void main() {
  test('le catalogue livré contient les produits des listes du foyer', () {
    final c = livre();
    expect(c.tousLesProduits.length, greaterThan(1500));
    expect(c.tousLesProduits.where((x) => x.$3.listes > 0).length, greaterThan(500));
  });

  test('exporter puis appliquer le même tableau ne change rien', () {
    final c = livre();
    final avant = jsonEncode(c.versJson());
    final bilan = importerExcel(c, exporterExcel(c));
    expect(bilan.total, 0, reason: bilan.toString());
    expect(jsonEncode(c.versJson()), avant);
  });

  test('la colonne « À faire » supprime, renomme et déplace', () {
    final c = petit();
    final bilan = importerExcel(c, tableau([
      ['Rayon', 'Secteur', 'Produit', 'À faire', 'Nouveau nom / rayon / secteur'],
      ['Fruits et légumes', 'Fruits', 'Pommes', 'Supprimer', ''],
      ['Fruits et légumes', 'Fruits', 'Brugnons', 'Renommer', 'Nectarines'],
      ['Fruits et légumes', 'Légumes', 'Ail', 'Déplacer', 'Épicerie / Condiments'],
      ['Crèmerie', 'Yaourts', 'Skyr', 'Garder', ''],
    ]));
    expect(bilan.supprimes, 1);
    expect(bilan.renommes, 1);
    expect(bilan.deplaces, 1);
    expect(bilan.ajoutes, 1);
    final noms = {for (final (r, s, p) in c.tousLesProduits) p.nom: '${r.nom}/${s.nom}'};
    expect(noms.containsKey('Pommes'), isFalse);
    expect(noms['Nectarines'], 'Fruits et légumes/Fruits');
    expect(noms['Ail'], 'Épicerie/Condiments');
    expect(noms['Skyr'], 'Crèmerie/Yaourts');
  });

  testWidgets("l'écran montre rayons, secteurs et produits, et filtre « Mes produits »", (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(MaterialApp(home: EcranCatalogue(catalogue: petit())));
    await t.pumpAndSettle();
    expect(find.text('Fruits et légumes'), findsOneWidget);
    expect(find.text('Pommes'), findsOneWidget);
    expect(find.text('★45'), findsOneWidget);
    await t.tap(find.text('Légumes'));
    await t.pumpAndSettle();
    expect(find.text('Ail'), findsOneWidget);
    await t.tap(find.text('★ Mes produits'));
    await t.pumpAndSettle();
    expect(find.text('Ail'), findsNothing);
    await t.enterText(find.byType(TextField).first, 'yao');
    await t.pumpAndSettle();
    expect(find.text('Yaos'), findsOneWidget);
    expect(find.textContaining('Crèmerie › Yaourts'), findsOneWidget);
  });
}
