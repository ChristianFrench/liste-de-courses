// Tests de recette de la maquette (spécification IHM, chapitre 12).
// Lancés automatiquement par GitHub (travail « verification ») ; rien à faire à la main.
// Un débordement de texte ou de mise en page fait échouer le test qui l'affiche.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/composants.dart';
import 'package:liste_de_courses/donnees/catalogue_off.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/open_food_facts.dart';
import 'package:liste_de_courses/main.dart';

Future<void> _chargerPolice() async {
  final loader = FontLoader('Atkinson');
  for (final f in [
    'assets/polices/AtkinsonHyperlegible-Regular.ttf',
    'assets/polices/AtkinsonHyperlegible-Bold.ttf',
  ]) {
    final octets = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(octets).buffer)));
  }
  await loader.load();
}

void _chargerDonnees() {
  final texte = File('assets/donnees_maquette.json').readAsStringSync();
  Etat.instance.lire(jsonDecode(texte) as Map<String, dynamic>);
}

/// Écran d'iPhone de référence : 390 × 844 avec encoche et barre du bas.
void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
}

Future<void> _demarrer(WidgetTester tester) async {
  _telephone(tester);
  await tester.pumpWidget(const ListeDeCoursesApp());
  await tester.pumpAndSettle();
}

/// Fait défiler jusqu'à l'élément puis l'amène entièrement à l'écran.
Future<void> _montrer(WidgetTester tester, Finder element, {Finder? scrollable}) async {
  await tester.scrollUntilVisible(element, 150, scrollable: scrollable ?? find.byType(Scrollable).first);
  await tester.ensureVisible(element);
  await tester.pumpAndSettle();
}

Future<void> _retour(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Retour').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_chargerPolice);
  setUp(_chargerDonnees);

  group('Données', () {
    test('la préliste retient les produits présents au moins 3 fois sur 6', () {
      final ids = Etat.instance.preliste('mg1').map((g) => g.produitId).toSet();
      expect(ids, containsAll(<String>['p1', 'p2', 'p3', 'p4', 'p15', 'p16', 'p17', 'p19', 'p5', 'p7']));
      expect(ids, isNot(contains('p18')));
    });

    test('alerte de quantité : pâtes 2 au lieu de 3 (règle 11)', () {
      final e = Etat.instance;
      final l = e.liste('l1')!;
      expect(e.quantiteInsuffisante(l, e.ligne(l, 'p16')!), 3);
      expect(e.quantiteInsuffisante(l, e.ligne(l, 'p2')!), isNull);
    });

    test('changer de parcours change l\'ordre des secteurs ; « Non placé » en dernier', () {
      final e = Etat.instance;
      final l = e.liste('l1')!;
      final habituel = e.etapes(l, 'pc1');
      final grosProduits = e.etapes(l, 'pc2');
      expect(habituel.first.secteur!.nom, 'Fruits et légumes');
      expect(grosProduits.first.secteur!.nom, 'Papier et entretien');
      expect(habituel.last.nonPlace, isTrue);
      expect(grosProduits.last.nonPlace, isTrue);
    });
  });

  group('Open Food Facts', () {
    test('code-barres EAN-13 : clé de contrôle et 95 modules', () {
      expect(ean13Valide('3017620422003'), isTrue);
      expect(ean13Valide('3017620422004'), isFalse);
      expect(ean13Valide('12345'), isFalse);
      final m = modulesEan13('3017620422003');
      expect(m.length, 95);
      expect(m.take(3), [true, false, true]);
    });

    test('catalogue : « pâtes » trouve les pâtes alimentaires, pas la pâte à tartiner', () {
      final c = CatalogueOff.instance;
      c.lireBase({
        'version': '20261009',
        'jusqua': 1760000000,
        'date': '09/10/2026',
        'categories': [
          ['en:pastas', 'pâtes alimentaires', 'pâtes'],
          ['fr:pates-a-tartiner', 'Pâtes à tartiner', 'Pâte à tartiner'],
          ['en:semi-skimmed-milks', 'Laits demi-écrémés', 'lait demi-écrémé'],
        ],
        'produits': [
          ['3017620422003', 'Nutella', 'Ferrero', '400 g', 'e', 5000, [1], ''],
          ['3038350208606', 'Spaghetti n°5', 'Panzani', '500 g', 'a', 800, [0], '303/835/020/8606/front_fr.1.200.jpg'],
          ['8076800195057', 'Penne rigate', 'Barilla', '500 g', 'a', 900, [0], ''],
          ['3428272950057', 'Lait demi-écrémé UHT', 'Lactel', '1 L', 'b', 700, [2], ''],
        ],
      });
      final pates = c.rechercher('Pâtes');
      expect(pates.articles.map((a) => a.nom), ['Penne rigate', 'Spaghetti n°5']);
      expect(c.rechercher('pate a tartiner').articles.single.nom, 'Nutella');
      expect(c.rechercher('Laits demi-écrémés').articles.single.marque, 'Lactel');
      expect(c.rechercher('barilla').articles.single.nom, 'Penne rigate');
      expect(c.parCode('3038350208606')!.imagePetite, contains('/images/products/303/835/020/8606/front_fr.1.200.jpg'));
      expect(c.parMarque('PANZANI').length, 1);
      c.appliquerMaj({
        'base': '20261009',
        'jusqua': 1760090000,
        'categories': [],
        'produits': [
          ['3560070000000', 'Coquillettes', 'Carrefour', '1 kg', 'a', 3, [0], ''],
        ],
      });
      expect(c.rechercher('pâtes').articles.length, 3);
      expect(c.nbProduits, 5);
    });

    test('lecture d\'un article', () {
      final a = ArticleOff.depuis({
        'code': '3428272950057',
        'product_name_fr': 'Lait demi-écrémé',
        'brands': 'Marque X, Groupe Y',
        'brands_tags': ['marque-x', 'groupe-y'],
        'quantity': '1 L',
        'nutriscore_grade': 'B',
      });
      expect(a.marque, 'Marque X');
      expect(a.marqueTag, 'marque-x');
      expect(a.nutriscore, 'b');
      expect(a.imagePetite, '');
    });
  });

  group('Écrans', () {
    testWidgets('1. Accueil', (tester) async {
      await _demarrer(tester);
      expect(find.text('Préparer une liste'), findsOneWidget);
      expect(find.text('Je fais les courses'), findsOneWidget);
      expect(find.text('Foyer de démonstration'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('écrans de gestion accessibles depuis l\'accueil, sans débordement', (tester) async {
      await _demarrer(tester);
      for (final tuile in ['Produits', 'Magasins et parcours', 'Historique', 'Promotions', 'Foyer']) {
        await _montrer(tester, find.widgetWithText(Bouton, tuile));
        await tester.tap(find.widgetWithText(Bouton, tuile));
        await tester.pumpAndSettle();
        expect(find.byType(EnTeteGestion), findsOneWidget, reason: tuile);
        await _retour(tester);
      }
    });

    testWidgets('13. Produits réels : écran d\'essai sans recherche automatique', (tester) async {
      await _demarrer(tester);
      await _montrer(tester, find.textContaining('Produits réels'));
      await tester.tap(find.textContaining('Produits réels'));
      await tester.pumpAndSettle();
      expect(find.text('Produits réels (essai)'), findsOneWidget);
      expect(find.textContaining('Cherchez une catégorie'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('2. Nouvelle liste : la préliste coche les produits fréquents', (tester) async {
      await _demarrer(tester);
      await tester.tap(find.text('Préparer une liste'));
      await tester.pumpAndSettle();
      expect(find.text('Garder 10 et compléter'), findsOneWidget);
      await tester.tap(find.text('Garder 10 et compléter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Préparer ·'), findsOneWidget);
    });

    testWidgets('3. Construction : 12 lignes visibles, compteurs, quantité', (tester) async {
      await _demarrer(tester);
      await tester.tap(find.text('Magasin 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crèmerie'));
      await tester.pumpAndSettle();

      final basListe = tester.getRect(find.byType(BarreAction)).top;
      var visibles = 0;
      final lignes = find.byType(LigneChoix);
      for (var i = 0; i < lignes.evaluate().length; i++) {
        if (tester.getRect(lignes.at(i)).bottom <= basListe + 0.5) visibles++;
      }
      expect(visibles, greaterThanOrEqualTo(12), reason: 'lignes produits visibles sans défiler');

      final avant = find.byType(SelecteurQuantite).evaluate().length;
      await tester.tap(find.textContaining('Beurre doux'));
      await tester.pumpAndSettle();
      expect(find.byType(SelecteurQuantite).evaluate().length, avant + 1);
      await tester.tap(find.text('−').first);
      await tester.pumpAndSettle();
    });

    testWidgets('4 à 6 et 12. Courses complètes dans l\'ordre du parcours', (tester) async {
      await _demarrer(tester);
      await tester.tap(find.text('Je fais les courses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir la liste et partir'));
      await tester.pumpAndSettle();

      // Écran 5 : liste complète, « Non placé » en dernier
      expect(find.text('NON PLACÉ'), findsOneWidget);
      await tester.tap(find.text('Commencer · secteur 1'));
      await tester.pumpAndSettle();

      // Écran 6 : premier secteur du parcours habituel
      expect(find.textContaining('Fruits et légumes'), findsWidgets);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(find.byType(LigneCourse).first);
      await tester.pumpAndSettle();

      var tours = 0;
      while (find.text('Terminer les courses').evaluate().isEmpty && tours < 20) {
        await tester.tap(find.byType(Bouton).last);
        await tester.pumpAndSettle();
        tours++;
      }
      expect(find.text('Terminer les courses'), findsOneWidget);
      await tester.tap(find.text('Terminer les courses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(find.text('Historique et tickets'), findsOneWidget);
    });

    testWidgets('7 à 11. Foyer, produits, fiche, promotion, parcours', (tester) async {
      await _demarrer(tester);
      await tester.tap(find.text('Foyer de démonstration'));
      await tester.pumpAndSettle();
      expect(find.text('K 7 P 2 Q X'), findsOneWidget);
      await _retour(tester);

      await tester.tap(find.text('Produits').last);
      await tester.pumpAndSettle();
      final grille = find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)).first;
      await _montrer(tester, find.text('Lait demi-écrémé'), scrollable: grille);
      await tester.tap(find.text('Lait demi-écrémé'));
      await tester.pumpAndSettle();
      expect(find.text('Où le trouver'.toUpperCase()), findsOneWidget);
      await _montrer(tester, find.text('+ Signaler une promotion'));
      await tester.tap(find.text('+ Signaler une promotion'));
      await tester.pumpAndSettle();
      for (final t in ['Prix global', 'Remise', 'Packaging', 'Fidélité', 'Autre', 'Lot']) {
        await tester.tap(find.text(t).first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Magasins').last);
      await tester.pumpAndSettle();
      expect(find.text('Fruits et légumes'), findsOneWidget);
      await tester.tap(find.text('Rayons et secteurs'));
      await tester.pumpAndSettle();
      expect(find.text('Crèmerie'), findsOneWidget);
    });
  });
}
