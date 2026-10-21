// Tests de recette de la maquette IHM v0.2 (Spécification IHM, « Critères de recette »).
// Lancés automatiquement par GitHub (travail « verification ») ; rien à faire à la main.
// Un débordement de texte ou de mise en page fait échouer le test qui l'affiche.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Axis, Scrollable, ValueKey, axisDirectionToAxis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/composants.dart';
import 'package:liste_de_courses/composants/pictogramme.dart';
import 'package:liste_de_courses/donnees/catalogue_off.dart';
import 'package:liste_de_courses/donnees/envoi.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/open_food_facts.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
import 'package:liste_de_courses/ecrans/travail.dart' show codeCourtPackaging, ordreAlpha;
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

/// Lance l'application (onglet Accueil) et va dans l'onglet Préparer.
Future<void> _accueil(WidgetTester tester) async {
  await _lancer(tester);
  await tester.tap(_onglet('Préparer'));
  await tester.pumpAndSettle();
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

Future<void> _voir(WidgetTester tester, Finder f) async {
  if (f.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(f, 150,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
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
      expect(e.nomListe(l), contains(' à '), reason: 'magasin, date et heure');
      expect(e.nomPris(e.nomListe(l)), isTrue, reason: 'deux listes ne peuvent pas porter le même nom');
      e.renommerListe(l, 'Barbecue');
      expect(e.nomListe(l), 'Barbecue');
      expect(e.nomPris('barbecue '), isTrue);
      expect(e.nomPris('Barbecue', sauf: l), isFalse);
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

    test('courses interrompues remises en préparation : coches perdues', () {
      final e = Etat.instance;
      final l = e.liste('l4')!;
      expect(l.nbCoches, greaterThan(0));
      e.coursesEnPreparation(l);
      expect(l.statut, StatutListe.enConstruction);
      expect(l.nbCoches, 0);
    });

    test('variante : la marque et le packaging créent l\'article', () {
      final e = Etat.instance;
      final l = e.liste('l1')!;
      final g = l.lignes.first;
      final p = e.produit(g.produitId)!;
      final k = e.packagingCompose('1,5 l', 'lot de 6')!;
      final q = e.produitVariante(l, p, marqueNom: 'Président', packagingId: k.id);
      expect(q.nom, '${p.nom.split(' · ').first} Président · lot de 6 × 1,5 l');
      expect(l.lignes.any((x) => x.produitId == q.id), isTrue);
      expect(e.produit(p.id), isNotNull);
    });

    test('packaging : mesure et lot séparés, puis recomposés', () {
      final e = Etat.instance;
      expect(Etat.mesureEtLot('lot de 6 × 1,5 l'), ('1,5 l', 'lot de 6'));
      expect(Etat.mesureEtLot('lot de 4'), (null, 'lot de 4'));
      expect(Etat.mesureEtLot('500 g'), ('500 g', null));
      expect(e.packagingCompose('1,5 l', 'lot de 6')!.libelle, 'lot de 6 × 1,5 l');
      expect(e.packagingCompose(null, null), isNull);
    });

    test('foyer : membre ajouté sans invitation ; course sans ticket en instance puis classée', () {
      final e = Etat.instance;
      final n = e.membres.length;
      final m = e.ajouterMembre(' Paul ', 'paul@exemple.fr');
      expect(e.membres.length, n + 1);
      expect(m.nomAffiche, 'Paul');
      final sans = e.coursesEnInstance;
      expect(sans, isNotEmpty);
      e.classerSansTicket(sans.first);
      expect(e.coursesEnInstance.length, sans.length - 1);
    });

    test('magasins : pas de doublon de nom ; listes en cours effacées à la suppression', () {
      final e = Etat.instance;
      expect(e.magasinNomme(' magasin 1 '), isNotNull);
      final m1 = e.magasin('mg1')!;
      expect(e.suppressionImpossible(m1), isNull);
      e.supprimer(m1);
      expect(e.listes.where((l) => l.magasinId == 'mg1' && l.statut != StatutListe.terminee), isEmpty);
    });

    test('formats de vente : appliqués aux produits, corrigés et fusionnés pour tous leurs articles', () async {
      final e = Etat.instance;
      final p = e.produits.firstWhere((x) => x.packagingIds.isEmpty, orElse: () => e.produits.first..packagingIds.clear());
      await e.appliquerFormats(catalogue: {
        'rayons': [
          {
            'nom': 'R',
            'secteurs': [
              {
                'nom': 'S',
                'taille': 1,
                'produits': [
                  {'nom': p.nom, 'taille': 1, 'formats': ['lot de 4', '500 g']}
                ],
              }
            ],
          }
        ],
      });
      expect(p.packagingIds.map((id) => e.packaging(id)!.libelle), ['lot de 4', '500 g']);
      final lot = p.packagingIds.first;
      expect(e.typesPackaging, contains(lot));
      e.renommerPackaging(lot, 'lot de 6');
      expect(e.packaging(lot)!.libelle, 'lot de 6');
      final g500 = p.packagingIds.last;
      e.renommerPackaging(g500, 'lot de 6'); // libellé existant : fusion
      expect(p.packagingIds, [lot]);
      expect(e.formatsAppliques, isTrue);
      expect(codeCourtPackaging('lot de 6'), '×6');
      expect(codeCourtPackaging('500 g'), '500g');
      expect(codeCourtPackaging('au poids'), 'kg');
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

    test('parcours appris : ordre des articles cochés, puis secteurs nouveaux insérés à leur place', () {
      expect(Etat.insererSecteurs(['a', 'c', 'e'], ['a', 'b', 'c']), ['a', 'b', 'c', 'e']);
      expect(Etat.insererSecteurs(['a', 'c'], ['z', 'c']), ['a', 'z', 'c']);
      expect(Etat.insererSecteurs(['a'], ['x']), ['a', 'x']);

      final e = Etat.instance;
      final l = e.liste('l3')!;
      final membre = e.membres.last.id;
      e.parcours.removeWhere((p) => p.magasinId == l.magasinId && p.membreId == membre);
      e.demarrerCourses(l, membre, null);
      expect(e.apprend(l), isTrue, reason: 'sans parcours, on propose de l\'enregistrer');
      final lignes = [...l.lignes.where((g) => e.secteurDe(l.magasinId, g.produitId) != null)];
      for (final g in lignes.reversed) {
        g.cocheLe = DateTime(2026, 1, 1, 10, lignes.length - lignes.indexOf(g));
      }
      final attendu = e.secteursDansLOrdre(l);
      expect(attendu, isNotEmpty);
      e.terminerCourses(l);
      final appris = e.parcoursDe(l.magasinId, membre).single;
      expect(appris.etapes, attendu);
      expect(appris.parDefaut, isTrue);
      expect(e.parcoursAppris, contains(appris.id));
    });

    test('enregistrement : les données relues sont identiques', () {
      final e = Etat.instance;
      final avant = jsonEncode(e.versJson());
      e.lire(jsonDecode(avant) as Map<String, dynamic>);
      expect(jsonEncode(e.versJson()), avant);
    });
  });

  group('Écrans', () {
    testWidgets('10. accueil : comment ça marche, et ce qui est en cours à reprendre', (tester) async {
      await _lancer(tester);
      expect(find.text('Bonjour !'), findsOneWidget);
      expect(find.text('COMMENT ÇA MARCHE'), findsOneWidget);
      await _voir(tester, find.text('Reprendre').last);
      expect(find.text('Reprendre'), findsWidgets);
      expect(find.text('Faire les courses'), findsOneWidget, reason: 'la liste prête reste dans « En préparation »');
      await _ciblesTactiles(tester);
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
      await _voir(tester, find.text('Non rattaché à une course'));
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
      expect(find.text('+ Nouveau parcours'), findsNothing, reason: 'les parcours s\'apprennent pendant les courses');
      expect(find.byType(GroupeRetractable), findsWidgets);
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
      await _toucher(tester, find.text('CRÈMERIE'));
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
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)));
      expect(find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)), findsOneWidget);
      expect(find.text('Il en faut 3 pour la promotion'), findsWidgets);
      await _ciblesTactiles(tester);

      // 6 : Lait demi-écrémé, lot 3 = 1 avec 2 → alerte ; passer à 3 la fait disparaître
      final lait = find.ancestor(of: find.textContaining('Lait demi-écrémé', findRichText: true), matching: find.byType(LigneChoix)).first;
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsOneWidget);
      await _toucher(tester, find.descendant(of: lait, matching: find.text('+')));
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsNothing);

      // 6 bis : la fenêtre de l'article (icône à droite de la coche) : mesure et lot, promotion, marque, consigne
      final yaourts = find.ancestor(of: find.textContaining('Yaourts nature', findRichText: true), matching: find.byType(LigneChoix)).first;
      expect(find.descendant(of: yaourts, matching: find.byType(Pastille)), findsNothing, reason: 'plus de pastilles dans la liste');
      await _toucher(tester, find.descendant(of: yaourts, matching: find.byTooltip('Packaging, promotion, marque')));
      expect(find.text('Ajouter une marque'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byType(ChoixDeroulant<String>).at(2)); // promotion
      await _toucher(tester, find.text('Lot').last);
      await tester.enterText(find.byKey(const ValueKey('precision-promo')), '3 dont 1 gratuit');
      await tester.enterText(find.byKey(const ValueKey('consigne-article')), 'les moins sucrés');
      await tester.enterText(find.byKey(const ValueKey('marque-article')), 'Danone');
      await _voir(tester, find.text('Enregistrer'));
      await _toucher(tester, find.text('Enregistrer'));
      final gy = Etat.instance.liste('l1')!.lignes.firstWhere((g) => Etat.instance.produit(g.produitId)!.nom.startsWith('Yaourts nature'));
      expect(Etat.instance.produit(gy.produitId)!.nom, 'Yaourts nature Danone', reason: 'la marque crée un produit');
      expect(Etat.instance.produits.any((p) => p.nom == 'Yaourts nature'), isTrue, reason: 'le produit sans marque reste');
      expect(gy.promotion!.type, 'lot');
      expect(gy.promotion!.libelle, '3 dont 1 gratuit');
      expect(gy.consigne, 'les moins sucrés');
      expect(Etat.instance.packaging(gy.packagingId)!.libelle, 'Pack de 12', reason: 'packaging gardé');

      // 5 : cocher → quantité et icône de la fenêtre article ; ramener à 0 décoche
      if (find.textContaining('Beurre doux', findRichText: true).evaluate().isEmpty) {
        await tester.scrollUntilVisible(find.textContaining('Beurre doux', findRichText: true), -150,
            scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      }
      final beurre = find.ancestor(of: find.textContaining('Beurre doux', findRichText: true), matching: find.byType(LigneChoix)).first;
      await _toucher(tester, find.descendant(of: beurre, matching: find.byType(CaseACocher)));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsOneWidget);
      expect(find.descendant(of: beurre, matching: find.byTooltip('Packaging, promotion, marque')), findsOneWidget);
      expect(find.text('Ajouter une marque'), findsNothing, reason: 'cocher n\'ouvre rien');
      await _toucher(tester, find.descendant(of: beurre, matching: find.text('−')));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsNothing);

      // 4 : une seule liste, comme en courses : plus de barres de rayons et de secteurs
      expect(find.byType(BandeauPuces), findsNothing);
      await tester.dragUntilVisible(find.text('CHARCUTERIE'), find.byType(Scrollable).last, const Offset(0, -300));
      expect(find.byType(TitreGroupe), findsWidgets);
      // Un seul secteur ouvert : ouvrir Charcuterie replie Crèmerie
      await _toucher(tester, find.text('CHARCUTERIE'));
      expect(find.textContaining('Beurre doux', findRichText: true), findsNothing);
      final jambon = find.ancestor(of: find.textContaining('Jambon', findRichText: true), matching: find.byType(LigneChoix)).first;
      await _toucher(tester, find.descendant(of: jambon, matching: find.byType(CaseACocher)));
      expect(Etat.instance.liste('l1')!.repriseSecteurId, 's4', reason: 'secteur du dernier article touché');

      // 8 : quitter puis revenir ramène au même secteur
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('+ Nouvelle liste'), findsOneWidget);
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)));
      expect(find.text('CHARCUTERIE'), findsOneWidget);

      // Ma liste : seulement les articles choisis ; Tout : tout le catalogue
      final n = Etat.instance.liste('l1')!.lignes.length;
      await _toucher(tester, find.text('Ma liste · $n'));
      expect(find.text('+ Produit absent de ce secteur'), findsNothing);
      expect(find.textContaining('Œufs', findRichText: true), findsNothing);
      await _toucher(tester, find.text('Tout'));
      await _ciblesTactiles(tester);
    });

    testWidgets('2. nouvelle liste : la préliste coche les produits fréquents', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      expect(find.text('Liste calculée'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Liste personnalisée'));
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Liste type'));
      await _toucher(tester, find.text('Liste complète'));
      expect(find.textContaining('Ma liste · 0'), findsOneWidget);
      expect(find.byType(LigneChoix), findsNothing, reason: 'à la première ouverture, tous les secteurs sont repliés');
      await _toucher(tester, find.text('CRÈMERIE'));
      // Ordre alphabétique dans le secteur
      final noms = [for (final e in find.byType(LigneChoix).evaluate()) (e.widget as LigneChoix).nom];
      expect(noms, [...noms]..sort((a, b) => ordreAlpha(a).compareTo(ordreAlpha(b))));
      // Toucher le nom ouvre la fenêtre de l'article (et le coche) ; Annuler le décoche
      await _toucher(tester, find.textContaining('Œufs', findRichText: true));
      expect(find.text('Ajouter une marque'), findsOneWidget);
      await _toucher(tester, find.text('Annuler'));
      expect(find.textContaining('Ma liste · 0'), findsOneWidget);
      final oeufs = find.ancestor(of: find.textContaining('Œufs', findRichText: true), matching: find.byType(LigneChoix)).first;
      await _toucher(tester, find.descendant(of: oeufs, matching: find.byType(CaseACocher)));
      await _toucher(tester, find.text('Liste prête'));
      expect(find.text('Fin de la liste'), findsOneWidget, reason: 'fenêtre modale de fin de liste');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Enregistrer comme liste type'));
      await tester.enterText(find.byKey(const ValueKey('nom-liste-type')), 'Petit-déjeuner');
      await _toucher(tester, find.text('Valider'));
      expect(find.text('LISTES PRÊTES'), findsOneWidget);
      expect(Etat.instance.listesTypes.map((t) => t.nom), contains('Petit-déjeuner'));

      // La liste type est proposée pour une nouvelle liste, avec ses articles (après disparition du message)
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('+ Nouvelle liste'));
      await _toucher(tester, find.text('Liste type'));
      await _toucher(tester, find.text('Petit-déjeuner'));
      expect(find.textContaining('Ma liste · 1'), findsOneWidget);
    });

    testWidgets('9. Une seule liste dans l\'ordre du parcours ; Reste à faire ; Pause puis Interrompre', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      expect(find.text('Courses interrompues'.toUpperCase()), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Reprendre'));
      expect(find.text('Magasin 1 · 4 / 9'), findsOneWidget);
      expect(find.byType(BandeauPuces), findsNothing, reason: 'plus de barre des secteurs : ils sont dans la liste');
      expect(find.text('CRÈMERIE'), findsOneWidget);
      await _ciblesTactiles(tester);

      // Cocher un article, puis « Reste à faire » : les articles cochés disparaissent ; « Tout » les remet.
      await _toucher(tester, find.text('Fromage râpé'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);
      await _toucher(tester, find.text('Reste à faire'));
      expect(find.text('Fromage râpé'), findsNothing);
      await _toucher(tester, find.text('Tout'));
      expect(find.text('Fromage râpé'), findsOneWidget);

      await _toucher(tester, find.text('Pause'));
      expect(find.text('Interrompre les courses ?'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Interrompre'));
      expect(find.text('Courses interrompues'.toUpperCase()), findsOneWidget);
      final l4 = Etat.instance.liste('l4')!;
      final premier = Etat.instance.etapes(l4, l4.parcoursId).firstWhere((x) => x.lignes.any((g) => !g.coche));
      expect(l4.repriseSecteurId, premier.id, reason: 'secteur où l\'on en est, enregistré à l\'interruption');

      await _toucher(tester, find.text('Reprendre'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);

      // Terminer depuis la zone de décision (articles restants : confirmation)
      await _toucher(tester, find.text('Terminer les courses'));
      expect(find.text('Terminer les courses ?'), findsOneWidget);
      await _toucher(tester, find.text('Terminer les courses').last);
      expect(find.text('TERMINÉES SANS TICKET'), findsOneWidget, reason: 'la course attend son ticket dans l\'onglet Courses');
      expect(Etat.instance.coursesEnInstance.any((c) => c.id == 'l4'), isTrue);
    });

    testWidgets('démarrer des courses depuis une liste prête', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l3')!)));
      expect(find.text('Faire les courses'), findsWidgets, reason: 'fenêtre modale de départ');
      expect(find.text('Enregistrer le parcours'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Faire les courses').last);
      expect(find.text('Pause'), findsOneWidget);
      expect(Etat.instance.liste('l3')!.statut, StatutListe.enCours);
    });

    testWidgets('historique : rattacher un ticket', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Historique');
      await _voir(tester, find.text('Non rattaché à une course'));
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
      await _toucher(tester, find.text('NON PLACÉS DANS CE MAGASIN'));
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
