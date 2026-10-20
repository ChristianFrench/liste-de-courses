// Captures des 19 écrans de la maquette IHM v0.2 au format téléphone (390 × 844),
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
import 'package:liste_de_courses/donnees/pictos.dart';
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
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 150,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _onglet(String l) => find.descendant(of: find.byType(BarreOnglets), matching: find.text(l));

void main() {
  setUpAll(_polices);

  testWidgets('écrans', (tester) async {
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
      for (final c in pictosDisponibles) {
        await precacheImage(AssetImage('assets/pictos/png/$c.png'), tester.element(find.byType(Scaffold).first));
      }
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
    await _toucher(tester, find.descendant(of: lait, matching: find.byType(BoutonPromo)).last);
    await _capture('04 Construire-Promo');
    Nav.i.racine.currentState!.pop();
    await tester.pumpAndSettle();
    await _toucher(tester, find.descendant(of: lait, matching: find.byType(BoutonPromo)).first);
    await _capture('20 Construire-Packaging');
    Nav.i.racine.currentState!.pop();
    await tester.pumpAndSettle();
    await _toucher(tester, find.byTooltip('Retour'));

    await _toucher(tester, _onglet('Gérer'));
    await _capture('19 Gerer');
    await _toucher(tester, find.text('Parcours'));
    await _capture('05 Gerer-Parcours');
    if (find.text('Parcours habituel').evaluate().isNotEmpty) {
      await _toucher(tester, find.text('Parcours habituel'));
      await _capture('21 Parcours-Detail');
    }
    await _toucher(tester, _onglet('Courses'));
    await _capture('06 Courses');

    await _toucher(tester, find.text('Reprendre les courses'));
    await _capture('08 Courses-Secteur');
    await _toucher(tester, find.text('Reste à faire'));
    await _capture('07 Courses-Reste-a-faire');
    await _toucher(tester, find.text('Tout'));
    await _toucher(tester, find.text('Pause'));
    await _capture('09 Courses-Interrompre');
    await _toucher(tester, find.text('Interrompre'));

    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, find.text('Historique'));
    await _capture('11 Historique-Courses');
    await _toucher(tester, find.text('Par magasin'));
    await _capture('12 Historique-Par-magasin');

    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, find.text('Magasins et catalogue'));
    await _capture('22 Magasins');
    await _toucher(tester, find.text('Magasin 1'));
    await _capture('13 Magasin-Rayons');
    await _toucher(tester, find.text('Frais'));
    await _capture('14 Magasin-Secteurs');
    await _toucher(tester, find.text('Crèmerie'));
    await _capture('15 Magasin-Produits');
    await _toucher(tester, find.text('Lait demi-écrémé'));
    await _capture('16 Fiche-Produit');
    await _toucher(tester, find.byTooltip('Retour'));

    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, _onglet('Gérer'));
    await _toucher(tester, find.text('Paramètres'));
    await _capture('17 Parametres');
    await _toucher(tester, find.text('Types de promotion'));
    await _capture('18 Parametres-Promos');
    await _toucher(tester, find.byTooltip('Retour'));
    await _toucher(tester, find.text('Types de packaging'));
    await _capture('23 Parametres-Packagings');

    for (final (rubrique, nom) in [('Archives', '24 Archives'), ('Mon foyer', '25 Mon-foyer'), ('Corbeille', '26 Corbeille')]) {
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, find.text(rubrique));
      await _capture(nom);
    }
  }, skip: !_actif);
}
