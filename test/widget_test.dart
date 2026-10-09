// Tests de recette de la maquette IHM v0.2 (Spécification IHM, « Critères de recette »).
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
import 'package:liste_de_courses/navigation.dart';

Future<void> _chargerPolice() async {
  final loader = FontLoader('Atkinson');
  for (final f in ['assets/polices/AtkinsonHyperlegible-Regular.ttf', 'assets/polices/AtkinsonHyperlegible-Bold.ttf']) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void _donnees() {
  final e = Etat.instance;
  e.enregistrementActif = false;
  e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
  Nav.i.reinitialiser();
}

/// Écran de référence : 390 × 844 avec encoche et barre du bas.
void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
}

Future<void> _lancer(WidgetTester tester) async {
  _telephone(tester);
  await tester.pumpWidget(const ListeDeCoursesApp());
  await tester.pumpAndSettle();
}

/// Lance l'application et passe l'écran de reprise.
Future<void> _accueil(WidgetTester tester) async {
  await _lancer(tester);
  if (find.text('Aller à l\'accueil').evaluate().isNotEmpty) {
    await tester.tap(find.text('Aller à l\'accueil'));
    await tester.pumpAndSettle();
  }
}

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _onglet(String libelle) => find.descendant(of: find.byType(BarreOnglets), matching: find.text(libelle));
Finder _sousOnglet(String libelle) => find.descendant(of: find.byType(SousOnglets), matching: find.text(libelle));

Future<void> _ciblesTactiles(WidgetTester tester) => expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

void main() {
  setUpAll(_chargerPolice);
  setUp(_donnees);

  group('Règles', () {
    test('préliste : au moins 3 présences sur 6', () {
      final ids = Etat.instance.preliste('mg1').map((g) => g.produitId).toSet();
      expect(ids, containsAll(<String>['p1', 'p2', 'p3', 'p4', 'p15', 'p16', 'p17', 'p19', 'p5', 'p7']));
      expect(ids, isNot(contains('p18')));
    });

    test('7. ordre du parcours ; changer de parcours change l\'ordre ; « Non placé » en dernier', () {
      final e = Etat.instance;
      final l = e.liste('l4')!;
      final habituel = e.etapes(l, 'pc1').map((x) => x.nom).toList();
      final gros = e.etapes(l, 'pc2').map((x) => x.nom).toList();
      expect(habituel.first, 'Fruits et légumes');
      expect(gros.first, 'Papier et entretien');
      expect(habituel.last, 'Non placé');
      expect(gros.last, 'Non placé');
    });

    test('alerte de quantité : lot 3 = 1 avec 2 articles', () {
      final e = Etat.instance;
      final l = e.liste('l1')!;
      expect(e.quantiteInsuffisante(e.ligne(l, 'p2')!), 3);
      e.quantite(l, 'p2', 3);
      expect(e.quantiteInsuffisante(e.ligne(l, 'p2')!), isNull);
    });

    test('enregistrement : les données relues sont identiques', () {
      final e = Etat.instance;
      final avant = jsonEncode(e.versJson());
      e.lire(jsonDecode(avant) as Map<String, dynamic>);
      expect(jsonEncode(e.versJson()), avant);
    });
  });

  group('Écrans', () {
    testWidgets('10. écran de reprise au lancement', (tester) async {
      await _lancer(tester);
      expect(find.text('Reprendre où vous en étiez ?'), findsOneWidget);
      expect(find.textContaining('Courses en cours · Magasin 1'), findsOneWidget);
      expect(find.textContaining('Liste en préparation · Magasin 1'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Aller à l\'accueil'));
      expect(find.text('+ Nouvelle liste'), findsOneWidget);
    });

    testWidgets('1 et 2. les 4 onglets et leurs sous-onglets ; chaque onglet retient son sous-onglet', (tester) async {
      await _accueil(tester);
      await _ciblesTactiles(tester);
      for (final (onglet, sous) in [
        ('Listes', ['Parcours', 'Courses', 'Préparer']),
        ('Historique', ['Tickets de caisse', 'Courses effectuées']),
        ('Magasin', ['Secteurs', 'Produits', 'Rayons']),
      ]) {
        await _toucher(tester, _onglet(onglet));
        for (final s in sous) {
          await _toucher(tester, _sousOnglet(s));
          await _ciblesTactiles(tester);
        }
      }
      await _toucher(tester, _onglet('Paramètres'));
      expect(find.text('Types de promotion'), findsOneWidget);
      await _ciblesTactiles(tester);

      await _toucher(tester, _onglet('Listes'));
      await _toucher(tester, _sousOnglet('Parcours'));
      await _toucher(tester, _onglet('Historique'));
      await _toucher(tester, _onglet('Listes'));
      expect(find.text('Ordre de passage par secteur · glisser pour réordonner'), findsOneWidget);
    });

    testWidgets('3. la flèche de retour remonte d\'un niveau', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Magasin'));
      await _toucher(tester, _sousOnglet('Produits'));
      await _toucher(tester, find.text('Lait demi-écrémé'));
      expect(find.text('Magasin › Produits'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('Magasin › Produits'), findsNothing);
      expect(find.text('Rechercher un produit, une marque…'), findsOneWidget);

      await _toucher(tester, _onglet('Paramètres'));
      await _toucher(tester, find.text('Types de promotion'));
      expect(find.text('Remise immédiate'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('Remise immédiate'), findsNothing);
    });

    testWidgets('4, 5, 6 et 8. construction : rayons, secteurs, quantités, promotion, reprise', (tester) async {
      await _accueil(tester);
      // Liste interrompue (Magasin 1) : reprise en Crèmerie
      await _toucher(tester, find.text('Interrompue'));
      expect(find.text('Préparer · Magasin 1'), findsOneWidget);
      expect(find.text('Il en faut 3 pour la promotion'), findsWidgets);
      await _ciblesTactiles(tester);

      // 6 : Lait demi-écrémé, lot 3 = 1 avec 2 → alerte ; passer à 3 la fait disparaître
      final lait = find.ancestor(of: find.text('Lait demi-écrémé'), matching: find.byType(LigneChoix));
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsOneWidget);
      await _toucher(tester, find.descendant(of: lait, matching: find.text('+')));
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsNothing);

      // 6 bis : choisir « Lot » sur Yaourts nature (quantité 1) → alerte
      final yaourts = find.ancestor(of: find.text('Yaourts nature'), matching: find.byType(LigneChoix));
      await _toucher(tester, find.descendant(of: yaourts, matching: find.byType(BoutonPromo)));
      expect(find.text('Promotion visée'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Lot'));
      await _toucher(tester, find.text('Valider'));
      expect(find.descendant(of: yaourts, matching: find.text('Il en faut 3 pour la promotion')), findsOneWidget);

      // 5 : cocher → quantité et bouton promotion ; ramener à 0 décoche
      final beurre = find.ancestor(of: find.text('Beurre doux'), matching: find.byType(LigneChoix));
      await _toucher(tester, beurre);
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsOneWidget);
      expect(find.descendant(of: beurre, matching: find.byType(BoutonPromo)), findsOneWidget);
      await _toucher(tester, find.descendant(of: beurre, matching: find.text('−')));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsNothing);

      // 4 : changer de rayon et de secteur met à jour produits et compteurs
      await _toucher(tester, find.textContaining('Épicerie').first);
      expect(find.text('Pâtes'), findsOneWidget);
      await _toucher(tester, find.text('Charcuterie').first);
      expect(find.text('Charcuterie'), findsWidgets);
      await _toucher(tester, find.text('Frais').first);
      await _toucher(tester, find.text('Charcuterie').first);
      expect(find.text('Jambon'), findsOneWidget);

      // 8 : quitter puis revenir ramène au même secteur
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('+ Nouvelle liste'), findsOneWidget);
      await _toucher(tester, find.text('Interrompue'));
      expect(find.text('Jambon'), findsOneWidget);
      expect(Etat.instance.liste('l1')!.repriseSecteurId, 's4');

      // Ma liste → liste complète
      await _toucher(tester, find.textContaining('Ma liste'));
      expect(find.text('NON PLACÉ'), findsOneWidget);
      await _ciblesTactiles(tester);
    });

    testWidgets('2. nouvelle liste : la préliste coche les produits fréquents', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      expect(find.text('Garder 10 et compléter'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Garder 10 et compléter'));
      expect(find.textContaining('Ma liste · 10'), findsOneWidget);
      await _toucher(tester, find.text('Liste prête'));
      expect(find.text('Prêtes pour les courses'), findsOneWidget);
    });

    testWidgets('9. Pause puis Interrompre ; Reprendre ramène au même secteur avec les mêmes coches', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _sousOnglet('Courses'));
      expect(find.text('Courses interrompues'.toUpperCase()), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Reprendre les courses'));
      expect(find.text('Magasin 1 · 4 / 9'), findsOneWidget);
      expect(find.textContaining('rayon Frais'), findsOneWidget);
      await _ciblesTactiles(tester);

      // Cocher un article, aller au secteur suivant, puis Pause
      await _toucher(tester, find.text('Fromage râpé'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);
      await _toucher(tester, find.textContaining('Charcuterie').last);
      await _toucher(tester, find.text('Pause'));
      expect(find.text('Interrompre les courses ?'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Interrompre'));
      expect(find.text('Courses interrompues'.toUpperCase()), findsOneWidget);
      expect(find.textContaining('arrêt au secteur Charcuterie'), findsOneWidget);

      await _toucher(tester, find.text('Reprendre les courses'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);
      expect(find.textContaining('rayon Frais'), findsOneWidget);
      expect(find.text('Jambon'), findsOneWidget);

      // Liste complète depuis les courses
      await _toucher(tester, find.byTooltip('Liste complète'));
      expect(find.text('Reprendre les courses'), findsOneWidget);
      await _toucher(tester, find.text('Reprendre les courses'));

      // Aller jusqu'au bout et terminer
      var tours = 0;
      while (find.text('Terminer les courses').evaluate().isEmpty && tours < 15) {
        await tester.tap(find.byType(Bouton).last);
        await tester.pumpAndSettle();
        tours++;
      }
      await _toucher(tester, find.text('Terminer les courses'));
      await _toucher(tester, find.text('Terminer'));
      expect(find.text('Par date'), findsOneWidget);
    });

    testWidgets('démarrer des courses depuis une liste prête', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _sousOnglet('Courses'));
      await _toucher(tester, find.text('Voir la liste et partir'));
      expect(find.text('Commencer · secteur 1'), findsOneWidget);
      await _toucher(tester, find.text('Commencer · secteur 1'));
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('historique : rattacher un ticket', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Historique'));
      await _toucher(tester, _sousOnglet('Tickets de caisse'));
      expect(find.text('Non rattaché à une course'), findsOneWidget);
      await _toucher(tester, find.text('Rattacher'));
      await _toucher(tester, find.textContaining('Magasin 2').first);
      expect(find.text('Non rattaché à une course'), findsNothing);
    });

    testWidgets('magasin : indiquer le secteur d\'un produit non placé', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Magasin'));
      await _toucher(tester, _sousOnglet('Produits'));
      await _toucher(tester, find.text('Bougies chauffe-plat'));
      await _toucher(tester, find.text('Non placé · indiquer le secteur').first);
      expect(find.textContaining('Touchez son secteur'), findsOneWidget);
      await _toucher(tester, find.text('Papier et entretien'));
      expect(Etat.instance.secteurDe('mg1', 'p21')?.id, 's10');
    });
  });

  group('Open Food Facts', () {
    test('code-barres EAN-13', () {
      expect(ean13Valide('3017620422003'), isTrue);
      expect(ean13Valide('3017620422004'), isFalse);
      expect(modulesEan13('3017620422003').length, 95);
    });

    test('catalogue : « pâtes » ≠ « pâtes à tartiner » ≠ « pâtés »', () {
      final c = CatalogueOff.instance;
      c.lireBase({
        'version': '20261009',
        'jusqua': 1760000000,
        'date': '09/10/2026',
        'categories': [
          ['en:pastas', 'pâtes alimentaires', 'pâtes'],
          ['fr:pates-a-tartiner', 'Pâtes à tartiner', 'Pâte à tartiner'],
          ['en:pates', 'Pâtés'],
        ],
        'produits': [
          ['3017620422003', 'Nutella', 'Ferrero', '400 g', 'e', 5000, [1], ''],
          ['3038350208606', 'Spaghetti n°5', 'Panzani', '500 g', 'a', 800, [0], ''],
          ['3250390000000', 'Pâté de campagne', 'Hénaff', '78 g', 'd', 600, [2], ''],
        ],
      });
      expect(c.rechercher('Pâtes').articles.single.nom, 'Spaghetti n°5');
      expect(c.rechercher('pâte à tartiner').articles.single.nom, 'Nutella');
      expect(c.rechercher('Pâtés').articles.single.nom, 'Pâté de campagne');
      expect(c.rechercher('panzani').articles.single.nom, 'Spaghetti n°5');
    });

    testWidgets('écran d\'essai accessible depuis Paramètres', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Paramètres'));
      await _toucher(tester, find.text('Produits réels — essai Open Food Facts'));
      expect(find.text('Produits réels (essai)'), findsOneWidget);
      await _ciblesTactiles(tester);
    });
  });
}
