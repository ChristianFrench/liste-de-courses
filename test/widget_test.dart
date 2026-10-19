// Tests de recette de la maquette IHM v0.2 (Spécification IHM, « Critères de recette »).
// Lancés automatiquement par GitHub (travail « verification ») ; rien à faire à la main.
// Un débordement de texte ou de mise en page fait échouer le test qui l'affiche.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Axis, Scrollable, Text, ValueKey, axisDirectionToAxis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/composants.dart';
import 'package:liste_de_courses/composants/pictogramme.dart';
import 'package:liste_de_courses/donnees/catalogue_off.dart';
import 'package:liste_de_courses/donnees/envoi.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/open_food_facts.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
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
  if (f.evaluate().isEmpty) {
    // Élément pas encore construit : faire défiler la liste verticale jusqu'à lui
    await tester.scrollUntilVisible(f, 150,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _onglet(String libelle) => find.descendant(of: find.byType(BarreOnglets), matching: find.text(libelle));
Finder _sousOnglet(String libelle) => find.descendant(of: find.byType(SousOnglets), matching: find.text(libelle));

/// Onglet Gérer, puis la rubrique donnée.
Future<void> _rubrique(WidgetTester tester, String titre) async {
  await _toucher(tester, _onglet('Gérer'));
  await _toucher(tester, find.text(titre));
}

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

    test('mail : la liste est rangée par rayon ; option « tout le foyer » pour les adresses', () {
      final e = Etat.instance;
      final l = e.liste('l4')!;
      final texte = texteListe(e, l);
      expect(texte, startsWith('Liste de courses · Magasin 1 · 9 articles'));
      expect(texte.indexOf('FRAIS'), lessThan(texte.indexOf('ÉPICERIE')));
      expect(texte, contains('NON PLACÉ'));
      e.modifierEmail(e.membres.first, 'a@exemple.fr');
      expect(lienMail(e, l).path, '');
      e.options(envoiFoyer: true);
      expect(lienMail(e, l).path, 'a@exemple.fr');
      expect(lienMail(e, l).toString(), isNot(contains('+')));
      final relu = jsonEncode(e.versJson());
      e.lire(jsonDecode(relu) as Map<String, dynamic>);
      expect(e.envoiFoyer, isTrue);
      expect(e.membres.first.email, 'a@exemple.fr');
    });

    test('images : une image choisie pour un rayon ajouté est gardée', () {
      final e = Etat.instance;
      expect(cleRayon('Mon rayon perso'), isNull);
      e.choisirImage(cleChoixRayon('Mon rayon perso'), 'animaux');
      e.choisirImage(cleChoixSecteur('Mon rayon perso', 'Croquettes'), 'animaux--chats');
      final relu = jsonEncode(e.versJson());
      e.choisirImage(cleChoixRayon('Mon rayon perso'), null);
      expect(cleRayon('Mon rayon perso'), isNull);
      e.lire(jsonDecode(relu) as Map<String, dynamic>);
      expect(cleRayon('Mon rayon perso'), 'animaux');
      expect(cleSecteur('Mon rayon perso', 'Croquettes'), 'animaux--chats');
    });

    test('listes : nom par défaut, renommage, consigne, reprise d\'une course passée', () {
      final e = Etat.instance;
      final l = e.creerListe('mg1', [LigneListe(produitId: e.produits.first.id, quantite: 2, consigne: 'bio')]);
      expect(e.nomListe(l), startsWith('Magasin 1 du '));
      e.renommerListe(l, 'Barbecue');
      expect(e.nomListe(l), 'Barbecue');
      final relu = jsonEncode(e.versJson());
      e.lire(jsonDecode(relu) as Map<String, dynamic>);
      final l2 = e.liste(l.id)!;
      expect(l2.nom, 'Barbecue');
      expect(l2.lignes.first.consigne, 'bio');
      final reprise = e.lignesReprises(l2);
      expect(reprise.first.quantite, 2);
      expect(reprise.first.coche, isFalse);
      e.listePrete(l2);
      e.remettreEnPreparation(l2);
      expect(l2.statut, StatutListe.enConstruction);
    });

    test('magasins : pas de doublon de nom ; listes en cours effacées à la suppression', () {
      final e = Etat.instance;
      expect(e.magasinNomme(' magasin 1 '), isNotNull);
      final m1 = e.magasin('mg1')!;
      expect(e.suppressionImpossible(m1), isNull);
      e.supprimer(m1);
      expect(e.listes.where((l) => l.magasinId == 'mg1' && l.statut != StatutListe.terminee), isEmpty);
    });

    test('paramètres : couleurs des promotions et des packagings, délai des archives', () {
      final e = Etat.instance;
      expect(e.typesPackaging.map((id) => e.packaging(id)?.libelle), contains('Pack de 6'));
      e.choisirCouleur('promo:Remise', 0xFF1565C0);
      expect(e.couleurs['promo:Remise'], 0xFF1565C0);
      e.reglerDelaiArchives(12);
      e.lire(jsonDecode(jsonEncode(e.versJson())) as Map<String, dynamic>);
      expect(e.couleurs['promo:Remise'], 0xFF1565C0);
      expect(e.delaiArchives, 12);
    });

    test('parcours : déplacer un rayon déplace tous ses secteurs', () {
      final e = Etat.instance;
      final p = e.creerParcours('mg1', e.moi.id, 'Essai');
      final rayons = e.rayonsDuParcours(p);
      expect(rayons.length, greaterThan(1));
      e.deplacerRayonParcours(p, rayons.length - 1, 0);
      expect(e.secteur(p.etapes.first)!.rayonId, rayons.last.id);
      expect(e.rayonsDuParcours(p).first.id, rayons.last.id);
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

    testWidgets('1 et 2. les 3 onglets, les rubriques de Gérer et leurs sous-onglets mémorisés', (tester) async {
      await _accueil(tester);
      await _ciblesTactiles(tester);
      await _toucher(tester, _onglet('Courses'));
      expect(find.text('LISTES PRÊTES'), findsOneWidget);
      await _ciblesTactiles(tester);
      for (final (rubrique, sous) in [
        ('Magasins et catalogue', ['Secteurs', 'Produits', 'Rayons']),
      ]) {
        await _rubrique(tester, rubrique);
        if (rubrique == 'Magasins et catalogue') {
          expect(find.text('+ Nouveau magasin'), findsOneWidget);
          await _ciblesTactiles(tester);
          await _toucher(tester, find.text('Magasin 1'));
        }
        for (final s in sous) {
          await _toucher(tester, _sousOnglet(s));
          await _ciblesTactiles(tester);
        }
      }
      await _rubrique(tester, 'Historique');
      expect(find.text('Par magasin'), findsOneWidget);
      expect(find.text('Non rattaché à une course'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Mon foyer');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Paramètres');
      expect(find.text('Types de promotion'), findsOneWidget);
      expect(find.text('Types de packaging'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Archives');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Parcours');
      expect(find.text('+ Nouveau parcours'), findsOneWidget);
      final mien = Etat.instance.parcoursDuMembre(Etat.instance.moi.id).first;
      await _toucher(tester, find.text(mien.nom).first);
      expect(find.textContaining('Glissez un rayon entier'), findsOneWidget);
      await _ciblesTactiles(tester);
      // Arborescence : les secteurs n'apparaissent qu'en ouvrant le rayon
      final premier = Etat.instance.secteur(mien.etapes.first)!;
      expect(find.text(premier.nom), findsNothing);
      await _toucher(tester, find.textContaining(Etat.instance.rayon(premier.rayonId)!.nom, findRichText: true).first);
      expect(find.text(premier.nom), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Corbeille');
      expect(find.text('Corbeille'), findsWidgets);
    });

    testWidgets('3. la flèche de retour remonte d\'un niveau', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Magasins et catalogue');
      await _toucher(tester, find.text('Magasin 1'));
      await _toucher(tester, _sousOnglet('Produits'));
      await _toucher(tester, find.text('Lait demi-écrémé'));
      expect(find.text('Gérer › Produits'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('Gérer › Produits'), findsNothing);
      expect(find.text('Rechercher un produit, une marque…'), findsOneWidget);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('Magasins et catalogue'), findsOneWidget);

      await _rubrique(tester, 'Paramètres');
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
      expect(find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)), findsOneWidget);
      expect(find.text('Il en faut 3 pour la promotion'), findsWidgets);
      await _ciblesTactiles(tester);

      // 6 : Lait demi-écrémé, lot 3 = 1 avec 2 → alerte ; passer à 3 la fait disparaître
      final lait = find.ancestor(of: find.textContaining('Lait demi-écrémé', findRichText: true), matching: find.byType(LigneChoix)).first;
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsOneWidget);
      await _toucher(tester, find.descendant(of: lait, matching: find.text('+')));
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsNothing);

      // 6 bis : choisir « Lot 3 dont 1 » sur Yaourts nature (quantité 1) → la quantité passe à 3 ; consigne gardée
      final yaourts = find.ancestor(of: find.textContaining('Yaourts nature', findRichText: true), matching: find.byType(LigneChoix)).first;
      // Bouton packaging (avant la promotion) : volet séparé
      await _toucher(tester, find.descendant(of: yaourts, matching: find.byType(BoutonPromo)).first);
      expect(find.text('PACKAGING'), findsOneWidget);
      expect(find.text('PROMOTION VISÉE'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('consigne')), 'les moins sucrés');
      await _toucher(tester, find.text('Valider'));
      await _toucher(tester, find.descendant(of: yaourts, matching: find.byType(BoutonPromo)).last);
      expect(find.text('PROMOTION VISÉE'), findsOneWidget);
      expect(find.text('PACKAGING'), findsNothing);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Lot x dont y'));
      await _toucher(tester, find.text('Valider'));
      final gy = Etat.instance.liste('l1')!.lignes.firstWhere((g) => Etat.instance.produit(g.produitId)!.nom.startsWith('Yaourts nature'));
      expect(gy.quantite, 3);
      expect(gy.promotion!.libelle, '3 dont 1 gratuit');
      expect(gy.consigne, 'les moins sucrés');
      expect(find.descendant(of: yaourts, matching: find.text('Il en faut 3 pour la promotion')), findsNothing);

      // 5 : cocher → quantité et bouton promotion ; ramener à 0 décoche
      final beurre = find.ancestor(of: find.textContaining('Beurre doux', findRichText: true), matching: find.byType(LigneChoix)).first;
      await _toucher(tester, beurre);
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsOneWidget);
      expect(find.descendant(of: beurre, matching: find.byType(BoutonPromo)), findsNWidgets(2)); // packaging et promotion
      await _toucher(tester, find.descendant(of: beurre, matching: find.text('−')));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsNothing);

      // 4 : changer de rayon et de secteur met à jour produits et compteurs
      await _toucher(tester, find.textContaining('Épicerie').first);
      expect(find.textContaining('Pâtes', findRichText: true), findsOneWidget);
      await _toucher(tester, find.text('Frais').first);
      await _toucher(tester, find.text('Charcuterie').first);
      expect(find.textContaining('Jambon', findRichText: true), findsOneWidget);

      // 8 : quitter puis revenir ramène au même secteur
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('+ Nouvelle liste'), findsOneWidget);
      await _toucher(tester, find.text('Interrompue'));
      expect(find.textContaining('Jambon', findRichText: true), findsOneWidget);
      expect(Etat.instance.liste('l1')!.repriseSecteurId, 's4');

      // Ma liste → liste complète
      await _toucher(tester, find.textContaining('Ma liste'));
      await tester.dragUntilVisible(find.text('NON PLACÉ'), find.byType(Scrollable).last, const Offset(0, -300));
      expect(find.text('NON PLACÉ'), findsOneWidget);
      await _ciblesTactiles(tester);
    });

    testWidgets('construction : « Tout le rayon » montre les produits de tous ses secteurs', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('Interrompue'));
      await _toucher(tester, find.text('Tout le rayon'));
      expect(find.textContaining('Jambon', findRichText: true), findsOneWidget);
      expect(find.textContaining('Lait demi-écrémé', findRichText: true), findsOneWidget);
      expect(find.text('+ Produit absent de ce rayon'), findsNothing); // en bas de la liste, pas encore construit
    });

    testWidgets('2. nouvelle liste : la préliste coche les produits fréquents', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      expect(find.text('Générer par IA'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Historique'));
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Liste vide'));
      expect(find.textContaining('Ma liste · 0'), findsOneWidget);
      await _toucher(tester, find.text('Liste prête'));
      expect(find.text('PRÊTES POUR LES COURSES'), findsOneWidget);
    });

    testWidgets('9. Pause puis Interrompre ; Reprendre ramène au même secteur avec les mêmes coches', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
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
      final l4 = Etat.instance.liste('l4')!;
      expect(l4.repriseSecteurId, 's4', reason: 'étape enregistrée à l\'interruption');
      expect(find.textContaining('arrêt au secteur Charcuterie'), findsOneWidget,
          reason: [for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? ''].join(' | '));

      await _toucher(tester, find.text('Reprendre les courses'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);
      expect(find.textContaining('rayon Frais'), findsOneWidget);
      expect(find.text('Jambon'), findsOneWidget);

      // Liste complète depuis les courses (zone de décision en bas)
      await _toucher(tester, find.text('Liste'));
      expect(find.text('Reprendre les courses'), findsOneWidget);
      await _toucher(tester, find.text('Reprendre les courses'));

      // Terminer depuis la zone de décision (articles restants : confirmation)
      await _toucher(tester, find.text('Terminer les courses'));
      await _toucher(tester, find.text('Terminer'));
      expect(find.text('Par date'), findsOneWidget);
    });

    testWidgets('démarrer des courses depuis une liste prête', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l3')!)));
      if (find.text('Partir').evaluate().isNotEmpty) await _toucher(tester, find.text('Partir'));
      expect(find.text('Pause'), findsOneWidget);
      expect(Etat.instance.liste('l3')!.statut, StatutListe.enCours);
    });

    testWidgets('historique : rattacher un ticket', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Historique');
      expect(find.text('Non rattaché à une course'), findsOneWidget);
      await _toucher(tester, find.text('Rattacher'));
      await _toucher(tester, find.textContaining('Magasin 2').first);
      expect(find.text('Non rattaché à une course'), findsNothing);
    });

    testWidgets('magasin : indiquer le secteur d\'un produit non placé', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Magasins et catalogue');
      await _toucher(tester, find.text('Magasin 1'));
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
      await _rubrique(tester, 'Paramètres');
      await _toucher(tester, find.text('Produits réels — essai Open Food Facts'));
      expect(find.text('Produits réels (essai)'), findsOneWidget);
      await _ciblesTactiles(tester);
    });
  });
}
