// Captures des 18 écrans de la maquette IHM v0.2 au format téléphone (390 × 844),
// numérotées comme dans ihm/v0.2/Captures, pour comparaison avec la maquette fil de fer.
// Produites par GitHub (travail « verification ») et rangées dans la branche « captures ».
// Ignoré lors d'un « flutter test » ordinaire (variable CAPTURES absente).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/composants.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/navigation.dart';

final bool _actif = Platform.environment['CAPTURES'] == '1';
final _cle = GlobalKey();

Future<void> _police(String famille, List<String> fichiers) async {
  final loader = FontLoader(famille);
  for (final f in fichiers) {
    final fichier = File(f);
    if (!fichier.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(fichier.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _polices() async {
  await _police('Atkinson', ['assets/polices/AtkinsonHyperlegible-Regular.ttf', 'assets/polices/AtkinsonHyperlegible-Bold.ttf']);
  final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
  await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

Future<void> _capture(String nom) => expectLater(find.byKey(_cle), matchesGoldenFile('captures/$nom.png'));

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _onglet(String l) => find.descendant(of: find.byType(BarreOnglets), matching: find.text(l));
Finder _sous(String l) => find.descendant(of: find.byType(SousOnglets), matching: find.text(l));

void main() {
  setUpAll(_polices);

  testWidgets('18 écrans IHM v0.2', (tester) async {
    final e = Etat.instance;
    e.enregistrementActif = false;
    e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    Nav.i.reinitialiser();

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp()));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/icone_ronde.png'), tester.element(find.byType(Scaffold).first));
    });
    await tester.pumpAndSettle();

    await _capture('10 Relance');
    await _toucher(tester, find.text('Aller à l\'accueil'));
    await _capture('01 Main');

    await _toucher(tester, find.text('+ Nouvelle liste'));
    await _capture('02 Preliste');
    await _toucher(tester, find.byTooltip('Retour'));

    await _toucher(tester, find.text('Interrompue'));
    await _capture('03 Construire');
    final lait = find.ancestor(of: find.textContaining('Lait demi-écrémé', findRichText: true), matching: find.byType(LigneChoix)).first;
    await _toucher(tester, find.descendant(of: lait, matching: find.byType(BoutonPromo)));
    await _capture('04 Construire-Promo');
    Nav.i.racine.currentState!.pop();
    await tester.pumpAndSettle();
    await _toucher(tester, find.byTooltip('Retour'));

    await _toucher(tester, _sous('Parcours'));
    await _capture('05 Listes-Parcours');
    await _toucher(tester, _sous('Courses'));
    await _capture('06 Listes-Courses');

    await _toucher(tester, find.text('Reprendre les courses'));
    await _capture('08 Courses-Secteur');
    await _toucher(tester, find.byTooltip('Liste complète'));
    await _capture('07 Liste-Complete');
    await _toucher(tester, find.text('Reprendre les courses'));
    await _toucher(tester, find.text('Pause'));
    await _capture('09 Courses-Interrompre');
    await _toucher(tester, find.text('Interrompre'));

    await _toucher(tester, _onglet('Historique'));
    await _capture('11 Historique-Courses');
    await _toucher(tester, _sous('Tickets de caisse'));
    await _capture('12 Historique-Tickets');

    await _toucher(tester, _onglet('Magasin'));
    await _capture('13 Magasin-Rayons');
    await _toucher(tester, find.text('Frais'));
    await _capture('14 Magasin-Secteurs');
    await _toucher(tester, find.text('Crèmerie'));
    await _capture('15 Magasin-Produits');
    await _toucher(tester, find.text('Lait demi-écrémé'));
    await _capture('16 Fiche-Produit');
    await _toucher(tester, find.byTooltip('Retour'));

    await _toucher(tester, _onglet('Paramètres'));
    await _capture('17 Parametres');
    await _toucher(tester, find.text('Types de promotion'));
    await _capture('18 Parametres-Promos');
  }, skip: !_actif);
}
