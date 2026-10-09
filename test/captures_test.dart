// Captures des 12 écrans au format téléphone (390 × 844), produites par GitHub
// (travail « verification ») et rangées dans la branche « captures » du dépôt.
// Ignoré lors d'un « flutter test » ordinaire (variable CAPTURES absente).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/ecrans/e01_accueil.dart';
import 'package:liste_de_courses/ecrans/e02_nouvelle_liste.dart';
import 'package:liste_de_courses/ecrans/e03_construction.dart';
import 'package:liste_de_courses/ecrans/e04_je_fais_les_courses.dart';
import 'package:liste_de_courses/ecrans/e05_liste_complete.dart';
import 'package:liste_de_courses/ecrans/e06_courses_secteur.dart';
import 'package:liste_de_courses/ecrans/e07_foyer.dart';
import 'package:liste_de_courses/ecrans/e08_produits.dart';
import 'package:liste_de_courses/ecrans/e09_fiche_produit.dart';
import 'package:liste_de_courses/ecrans/e10_promotion.dart';
import 'package:liste_de_courses/ecrans/e11_magasins_parcours.dart';
import 'package:liste_de_courses/ecrans/e12_historique.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/theme.dart';

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
  await _police('Atkinson', [
    'assets/polices/AtkinsonHyperlegible-Regular.ttf',
    'assets/polices/AtkinsonHyperlegible-Bold.ttf',
  ]);
  final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
  await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

void _donnees() {
  final texte = File('assets/donnees_maquette.json').readAsStringSync();
  Etat.instance.lire(jsonDecode(texte) as Map<String, dynamic>);
}

Future<void> _capturer(WidgetTester tester, String nom, Widget ecran) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
  tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _cle,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, enfant) => FormatTelephone(child: enfant!),
      home: ecran,
    ),
  ));
  await tester.pumpAndSettle();
  // Charger réellement les images (icône) avant la capture
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Navigator).first);
    await precacheImage(const AssetImage('assets/icone_ronde.png'), ctx);
  });
  await tester.pumpAndSettle();
  await expectLater(find.byKey(_cle), matchesGoldenFile('captures/$nom.png'));
}

void main() {
  setUpAll(_polices);
  setUp(_donnees);

  final e = Etat.instance;

  testWidgets('01 accueil', (t) => _capturer(t, '01 accueil', const EcranAccueil()), skip: !_actif);
  testWidgets('01b accueil courses en cours', (t) async {
    final l = e.liste('l1')!;
    e.demarrerCourses(l, 'm1', 'pc1');
    for (final id in ['p1', 'p16', 'p17', 'p2']) {
      e.cocher(id);
    }
    await _capturer(t, '01b accueil courses en cours', const EcranAccueil());
  }, skip: !_actif);
  testWidgets('02 nouvelle liste', (t) => _capturer(t, '02 nouvelle liste', const EcranNouvelleListe()),
      skip: !_actif);
  testWidgets('03 construction', (t) async {
    await _capturer(t, '03 construction', const EcranConstruction(listeId: 'l1'));
    await t.tap(find.text('Crèmerie'));
    await t.pumpAndSettle();
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/03b construction cremerie.png'));
    await t.tap(find.text('Épicerie'));
    await t.pumpAndSettle();
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/03c construction epicerie.png'));
  }, skip: !_actif);
  testWidgets('04 je fais les courses',
      (t) => _capturer(t, '04 je fais les courses', const EcranJeFaisLesCourses()),
      skip: !_actif);
  testWidgets('05 liste complete', (t) async {
    e.demarrerCourses(e.liste('l1')!, 'm1', 'pc1');
    await _capturer(t, '05 liste complete', const EcranListeComplete(listeId: 'l1'));
  }, skip: !_actif);
  testWidgets('06 courses par secteur', (t) async {
    e.demarrerCourses(e.liste('l1')!, 'm1', 'pc1');
    e.cocher('p1');
    e.cocher('p16');
    e.allerEtape(2);
    e.cocher('p3');
    e.basculerReseau();
    await _capturer(t, '06 courses par secteur', const EcranCoursesSecteur());
  }, skip: !_actif);
  testWidgets('06b dernier secteur', (t) async {
    e.demarrerCourses(e.liste('l1')!, 'm1', 'pc1');
    final n = e.etapes(e.liste('l1')!, 'pc1').length;
    e.allerEtape(n - 1);
    await _capturer(t, '06b dernier secteur', const EcranCoursesSecteur());
  }, skip: !_actif);
  testWidgets('07 foyer', (t) => _capturer(t, '07 foyer', const EcranFoyer()), skip: !_actif);
  testWidgets('08 produits', (t) => _capturer(t, '08 produits', const EcranProduits()), skip: !_actif);
  testWidgets('09 fiche produit', (t) => _capturer(t, '09 fiche produit', const EcranFicheProduit(produitId: 'p2')),
      skip: !_actif);
  testWidgets('10 promotion', (t) => _capturer(t, '10 promotion', const EcranPromotion(produitId: 'p2')),
      skip: !_actif);
  testWidgets('11 magasins et parcours', (t) async {
    await _capturer(t, '11 magasins et parcours', const EcranMagasinsParcours());
    await t.tap(find.text('Rayons et secteurs'));
    await t.pumpAndSettle();
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/11b rayons et secteurs.png'));
  }, skip: !_actif);
  testWidgets('12 historique', (t) => _capturer(t, '12 historique', const EcranHistorique()), skip: !_actif);
}
