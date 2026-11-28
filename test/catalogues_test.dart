// « Emplettes · catalogues » (22/11/2026) : la charpente Windows (barre de menus, barre d'outils, zone de travail,
// barre d'état), le changement de catalogue, l'aide, les raccourcis, à propos.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/ecrans/catalogues/fenetre_catalogues.dart';
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/navigation.dart';

void main() {
  testWidgets('catalogues : menus, barre d\'outils, barre d\'état, aide', (tester) async {
    final e = Etat.instance;
    e.enregistrementActif = false;
    e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    Nav.i.reinitialiser();
    EcranEditeurCatalogue.actualiserAuServeur = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ListeDeCoursesApp(accueil: FenetreCatalogues()));
    for (var i = 0; i < 30 && find.text('Fruits et légumes').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Les cinq zones : menus, outils, catalogue des produits, barre d'état.
    for (final m in ['menu-fichier', 'menu-edition', 'menu-affichage', 'menu-insertion', 'menu-version', 'menu-outils', 'menu-aide']) {
      expect(find.byKey(ValueKey(m)), findsOneWidget, reason: m);
    }
    expect(find.byKey(const ValueKey('barre-outils')), findsOneWidget);
    expect(find.byKey(const ValueKey('barre-etat')), findsOneWidget);
    expect(find.text('Fruits et légumes'), findsOneWidget, reason: 'le catalogue des produits dans la zone de travail');

    // Tout déplier depuis la barre d'outils : les secteurs apparaissent.
    await tester.tap(find.byKey(const ValueKey('outil-deplier')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('console-secteur-Fruits et légumes/Fruits')), findsOneWidget);
    expect(find.text('Tout déplié'), findsOneWidget, reason: 'message dans la barre d\'état');

    // Changer de catalogue : Recettes, puis Produits, par la barre d'outils.
    await tester.tap(find.byKey(const ValueKey('outil-recettes')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('etat-catalogue'))).data, 'Catalogue des recettes');
    await tester.tap(find.byKey(const ValueKey('outil-produits')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('etat-catalogue')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('etat-catalogue'))).data, 'Catalogue des produits');

    // Aide (F1), raccourcis et à propos par le menu « ? ».
    await tester.tap(find.byKey(const ValueKey('outil-aide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fenetre-aide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('aide-fermer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-aide')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-raccourcis')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fenetre-raccourcis')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('aide-fermer')));
    await tester.pumpAndSettle();

    // Masquer la barre d'état par le menu Affichage.
    await tester.tap(find.byKey(const ValueKey('menu-affichage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-barre-etat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('barre-etat')), findsNothing);
  });

  testWidgets('catalogues : écran d\'accueil', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccueilCatalogues()));
    expect(find.text('Gestion des catalogues'), findsOneWidget);
    expect(find.textContaining('Version'), findsOneWidget);
  });
}
