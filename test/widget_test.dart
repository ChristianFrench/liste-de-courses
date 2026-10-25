// Tests de recette de la maquette IHM v0.2 (Spécification IHM, « Critères de recette »).
// Lancés automatiquement par GitHub (travail « verification ») ; rien à faire à la main.
// Un débordement de texte ou de mise en page fait échouer le test qui l'affiche.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Axis, Icons, Offset, Scrollable, TextField, ValueKey, axisDirectionToAxis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/composants.dart';
import 'package:liste_de_courses/composants/pictogramme.dart';
import 'package:liste_de_courses/composants/signe_perso.dart';
import 'package:liste_de_courses/donnees/catalogue_off.dart';
import 'package:liste_de_courses/donnees/envoi.dart';
import 'package:liste_de_courses/donnees/import_texte.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/open_food_facts.dart';
import 'package:liste_de_courses/donnees/ticket_recu.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
import 'package:liste_de_courses/ecrans/travail.dart' show EcranConstruction, codeCourtPackaging, ordreAlpha;
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
  e.ajoutParRecherche = false; // les essais de la préparation parcourent le catalogue, sauf mention contraire
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

/// Onglet Gérer, puis la rubrique donnée.
Future<void> _rubrique(WidgetTester tester, String titre) async {
  await _toucher(tester, _onglet('Gérer'));
  Nav.i.retourOnglet(Nav.gerer); // depuis une rubrique ouverte : retour au menu de Gérer
  await tester.pumpAndSettle();
  // Le menu a pu rester défilé vers le bas : on remonte en haut.
  await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first,
      const Offset(0, 2000));
  await tester.pumpAndSettle();
  await _toucher(tester, find.text(titre));
}

/// Historique, Archives, Corbeille : en bas de l'onglet Courses.
Future<void> _depuisCourses(WidgetTester tester, String titre) async {
  await _toucher(tester, _onglet('Courses'));
  Nav.i.retourOnglet(Nav.courses);
  await tester.pumpAndSettle();
  await _toucher(tester, find.descendant(of: find.byType(BarreAction), matching: find.text(titre)));
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
      expect(find.text('+ Nouvelle liste'), findsNothing);
    });

    testWidgets('en-tête : glisser change d\'onglet ; synchronisation et aide dans une fenêtre à croix', (tester) async {
      await _lancer(tester);
      expect(find.textContaining('Version '), findsOneWidget, reason: 'numéro de version en haut de l\'accueil');
      expect(find.byType(EnTeteFenetre), findsNothing, reason: 'pas de bandeau de titre sur l\'accueil');
      await tester.fling(find.text('Bonjour !'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('+ Nouvelle liste'), findsOneWidget, reason: 'glisser à gauche : onglet Préparer');
      await tester.fling(find.byType(EnTeteFenetre), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Courses').first, findsOneWidget);
      await tester.fling(find.byType(EnTeteFenetre), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('+ Nouvelle liste'), findsOneWidget, reason: 'glisser à droite : retour à Préparer');
      // Sur une zone libre de la fenêtre, le même geste change aussi d'onglet
      await tester.fling(find.textContaining('Touchez une liste pour la reprendre'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('+ Nouvelle liste'), findsNothing, reason: 'glisser sur le texte : onglet Courses');
      await tester.fling(find.byType(EnTeteFenetre), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      await _toucher(tester, find.byTooltip('Synchronisation : foyer non partagé'));
      expect(find.text('Foyer non partagé'), findsOneWidget, reason: 'l\'icône ouvre l\'état du partage');
      await _toucher(tester, find.byTooltip('Fermer'));
      await _toucher(tester, find.byTooltip('Plus d\'actions'));
      await _toucher(tester, find.text('Aide'));
      expect(find.text('Aide · Préparer'), findsOneWidget);
      await _toucher(tester, find.byTooltip('Fermer'));
      expect(find.text('Aide · Préparer'), findsNothing);
    });

    testWidgets('1 et 2. les 3 onglets, les rubriques de Gérer et leurs sous-onglets mémorisés', (tester) async {
      await _accueil(tester);
      await _ciblesTactiles(tester);
      await _toucher(tester, _onglet('Courses'));
      expect(find.text('LISTES PRÊTES'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Magasins');
      expect(find.text('+ Nouveau magasin'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Catalogue');
      expect(find.text('+ Nouveau produit'), findsOneWidget);
      expect(find.text('FRAIS'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Marques');
      await _ciblesTactiles(tester);
      await _depuisCourses(tester, 'Historique');
      expect(find.text('Par magasin'), findsOneWidget);
      await _voir(tester, find.text('Rattacher à une course'));
      expect(find.text('Rattacher à une course'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Foyer');
      expect(find.text('+ Membre'), findsOneWidget, reason: 'les membres sont dans le foyer');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Types de promotion');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Packaging');
      await _ciblesTactiles(tester);
      await _depuisCourses(tester, 'Archives');
      await _ciblesTactiles(tester);
      // Les parcours d'un magasin sont dans sa fiche (Gérer › Courses › Magasins).
      final mien = Etat.instance.parcoursDuMembre(Etat.instance.moi.id).first;
      await _rubrique(tester, 'Magasins');
      await _toucher(tester, find.text(Etat.instance.magasin(mien.magasinId)!.nom));
      expect(find.text('+ Nouveau parcours'), findsNothing, reason: 'les parcours s\'apprennent pendant les courses');
      expect(find.byType(GroupeRetractable), findsWidgets);
      await _toucher(tester, find.text(mien.nom).first);
      expect(find.textContaining('Glissez un rayon entier'), findsOneWidget);
      await _ciblesTactiles(tester);
      // Arborescence : les secteurs n'apparaissent qu'en ouvrant le rayon
      final premier = Etat.instance.secteur(mien.etapes.first)!;
      expect(find.text(premier.nom), findsNothing);
      await _toucher(tester, find.textContaining(Etat.instance.rayon(premier.rayonId)!.nom, findRichText: true).first);
      expect(find.text(premier.nom), findsOneWidget);
      await _ciblesTactiles(tester);
      await _depuisCourses(tester, 'Corbeille');
      expect(find.text('Corbeille'), findsWidgets);
    });

    testWidgets('3. la flèche de retour remonte d\'un niveau', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Catalogue');
      await _toucher(tester, find.text('FRAIS'));
      await _toucher(tester, find.text('Crèmerie').last);
      await _toucher(tester, find.text('Lait demi-écrémé'));
      expect(find.text('À la liste'), findsOneWidget, reason: 'fiche produit');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('À la liste'), findsNothing);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('+ Nouveau produit'), findsOneWidget);

      await _rubrique(tester, 'Types de promotion');
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
      await _voir(tester, find.text('Il en faut 3 pour la promotion'));
      expect(find.text('Il en faut 3 pour la promotion'), findsWidgets);
      await _ciblesTactiles(tester);

      // 6 : Lait demi-écrémé, lot 3 = 1 avec 2 → alerte ; passer à 3 la fait disparaître
      final lait = find.ancestor(of: find.textContaining('Lait demi-écrémé', findRichText: true), matching: find.byType(LigneChoix)).first;
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsOneWidget);
      await _toucher(tester, find.descendant(of: lait, matching: find.text('+')));
      expect(find.descendant(of: lait, matching: find.text('Il en faut 3 pour la promotion')), findsNothing);

      // 6 bis : l'article touché montre ses quatre pastilles ; la marque crée « Yaourts nature Danone »
      expect(find.text('+ Marque'), findsNothing, reason: 'pas de pastilles tant qu\'on n\'a pas touché l\'article');
      await _toucher(tester, find.textContaining('Yaourts nature', findRichText: true));
      expect(find.text('+ Marque'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('+ Marque'));
      await _toucher(tester, find.text('Autre marque…'));
      await tester.enterText(find.byType(TextField).last, 'Danone');
      await _toucher(tester, find.text('Valider'));
      expect(Etat.instance.liste('l1')!.lignes.any((g) => Etat.instance.produit(g.produitId)?.nom == 'Yaourts nature Danone'), isTrue);
      expect(find.text('Danone'), findsOneWidget, reason: 'pastille marque de l\'article touché');
      // Toucher un autre article coché : les pastilles passent sur lui
      await tester.scrollUntilVisible(find.textContaining('Lait demi-écrémé', findRichText: true), -150,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      await _toucher(tester, find.textContaining('Lait demi-écrémé', findRichText: true));
      expect(find.text('Danone'), findsNothing);
      final gy = Etat.instance.liste('l1')!.lignes.firstWhere((g) => Etat.instance.produit(g.produitId)!.nom.startsWith('Yaourts nature'));
      expect(Etat.instance.produits.any((p) => p.nom == 'Yaourts nature'), isTrue, reason: 'le produit sans marque reste');
      expect(Etat.instance.packaging(gy.packagingId)!.libelle, 'Pack de 12', reason: 'packaging gardé');
      // Sans marque : l'article redevient « Yaourts nature »
      await _toucher(tester, find.textContaining('Yaourts nature Danone', findRichText: true));
      await _toucher(tester, find.text('Danone'));
      await _toucher(tester, find.text('Sans marque'));
      expect(Etat.instance.liste('l1')!.lignes.any((g) => Etat.instance.produit(g.produitId)?.nom == 'Yaourts nature'), isTrue);

      // 5 : cocher → quantité et icône de la fenêtre article ; ramener à 0 décoche
      if (find.textContaining('Beurre doux', findRichText: true).evaluate().isEmpty) {
        await tester.scrollUntilVisible(find.textContaining('Beurre doux', findRichText: true), -150,
            scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      }
      final beurre = find.ancestor(of: find.textContaining('Beurre doux', findRichText: true), matching: find.byType(LigneChoix)).first;
      await _toucher(tester, find.descendant(of: beurre, matching: find.byType(CaseACocher)));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsOneWidget);
      expect(find.descendant(of: beurre, matching: find.text('+ Marque')), findsOneWidget, reason: 'l\'article coché montre ses pastilles');
      await _toucher(tester, find.descendant(of: beurre, matching: find.text('−')));
      expect(find.descendant(of: beurre, matching: find.byType(SelecteurQuantite)), findsNothing);

      // 4 : une seule liste, comme en courses : plus de barres de rayons et de secteurs
      expect(find.byType(BandeauPuces), findsNothing);
      await tester.dragUntilVisible(find.text('CHARCUTERIE'), find.byType(Scrollable).last, const Offset(0, -300));
      expect(find.byType(TitreGroupe), findsWidgets);
      // Un seul secteur ouvert : ouvrir Charcuterie replie Crèmerie
      await _toucher(tester, find.text('CHARCUTERIE'));
      expect(find.textContaining('Beurre doux', findRichText: true), findsNothing);
      // Rayons repliables au-dessus de leurs secteurs : Frais est ouvert, les autres repliés
      await tester.scrollUntilVisible(find.text('FRAIS'), -150,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      expect(find.text('FRAIS'), findsOneWidget);
      await _voir(tester, find.textContaining('Jambon', findRichText: true));
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
      await _toucher(tester, find.text('Ma liste · $n'));
      await _ciblesTactiles(tester);

      // Un seul rayon ouvert : ouvrir Épicerie replie Frais
      await _toucher(tester, find.text('ÉPICERIE').first);
      expect(find.text('CHARCUTERIE'), findsNothing);
      await _voir(tester, find.text('PETIT-DÉJEUNER'));
      expect(find.text('PETIT-DÉJEUNER'), findsOneWidget);
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
      expect(find.byType(LigneChoix), findsNothing, reason: 'à la première ouverture, tous les rayons sont repliés');
      expect(find.text('CRÈMERIE'), findsNothing, reason: 'on voit les rayons, pas les secteurs');
      await _toucher(tester, find.text('FRAIS').first);
      await _toucher(tester, find.text('CRÈMERIE'));
      // Ordre alphabétique dans le secteur
      final noms = [for (final e in find.byType(LigneChoix).evaluate()) (e.widget as LigneChoix).nom];
      expect(noms, [...noms]..sort((a, b) => ordreAlpha(a).compareTo(ordreAlpha(b))));
      // Article non coché : toucher le nom le coche et montre ses pastilles ; toucher encore les replie
      await _toucher(tester, find.textContaining('Œufs', findRichText: true));
      expect(find.textContaining('Ma liste · 1'), findsOneWidget);
      expect(find.text('+ Marque'), findsOneWidget);
      await _toucher(tester, find.textContaining('Œufs', findRichText: true));
      expect(find.text('+ Marque'), findsNothing);
      expect(find.textContaining('Ma liste · 1'), findsOneWidget, reason: 'l\'article reste coché');
      // Produit absent : son nom suffit
      await _toucher(tester, find.text('+ Produit absent de ce secteur'));
      await tester.enterText(find.byType(TextField).last, 'Kéfir');
      await _toucher(tester, find.text('Ajouter').last);
      expect(Etat.instance.produits.any((p) => p.nom == 'Kéfir'), isTrue);
      expect(find.textContaining('Ma liste · 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      // Aperçu : la liste comme en courses, sans case à cocher
      await _toucher(tester, find.text('Aperçu'));
      expect(find.byType(LigneCourse), findsNothing, reason: 'condensé par défaut');
      expect(find.text('Kéfir'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Détail'));
      expect(find.byType(LigneCourse), findsWidgets);
      expect(find.descendant(of: find.byType(LigneCourse), matching: find.byType(CaseACocher)), findsNothing);
      await _toucher(tester, find.text('Continuer la préparation'));
      await _toucher(tester, find.text('Liste prête'));
      await tester.enterText(find.byKey(const ValueKey('commentaire-liste')), 'Pharmacie aussi');
      expect(find.text('Fin de la liste'), findsOneWidget, reason: 'fenêtre modale de fin de liste');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Enregistrer comme liste type'));
      await tester.enterText(find.byKey(const ValueKey('nom-liste-type')), 'Petit-déjeuner');
      await _toucher(tester, find.text('Valider'));
      expect(find.text('LISTES PRÊTES'), findsOneWidget);
      expect(Etat.instance.listesTypes.map((t) => t.nom), contains('Petit-déjeuner'));
      expect(Etat.instance.commentaires.values, contains('Pharmacie aussi'));

      // La liste type est proposée pour une nouvelle liste, avec ses articles (après disparition du message)
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('+ Nouvelle liste'));
      await _toucher(tester, find.text('Liste type'));
      await _toucher(tester, find.text('Petit-déjeuner'));
      expect(find.textContaining('Ma liste · 2'), findsOneWidget);
    });

    testWidgets('préparation : la recherche ouvre le rayon et le secteur de l\'article', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)));
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'ja');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('option-recherche-0')), findsNothing, reason: 'moins de trois lettres');
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'jamb');
      await tester.pumpAndSettle();
      expect(find.text('Frais › Charcuterie'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(find.text('Jambon'), findsOneWidget);
      expect(find.text('Beurre doux'), findsNothing, reason: 'un seul secteur ouvert : Crèmerie s\'est refermé');
      await tester.pump(const Duration(seconds: 4));
      // Icône « tout déplier / replier » à droite du bandeau, aide dans le menu des trois points
      expect(find.byTooltip('Tout replier'), findsOneWidget);
    });

    testWidgets('ticket PDF reçu d\'une autre application : choix de la course, puis montant', (tester) async {
      final dossier = Directory.systemTemp.createTempSync('tickets');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dossier.path);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null));
      final pdf = File('${dossier.path}/recu.pdf')..writeAsStringSync('%PDF-1.4 essai');
      await _lancer(tester);
      TicketRecu.demarrer();
      await tester.pumpAndSettle();
      final etat = Etat.instance;
      final sansTicket = etat.historique.where((c) => etat.ticketDe(c.id) == null).length;
      await tester.runAsync(() => tester.binding.defaultBinaryMessenger.handlePlatformMessage('fr.listecourses/ticket',
          const StandardMethodCodec().encodeMethodCall(MethodCall('ticket', '')), (_) {}));
      // chemin réel transmis ensuite (le premier appel, vide, ne doit rien casser)
      await tester.runAsync(() => tester.binding.defaultBinaryMessenger.handlePlatformMessage('fr.listecourses/ticket',
          StandardMethodCodec().encodeMethodCall(MethodCall('ticket', pdf.path)), (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Ticket de caisse reçu · à quelle course le joindre ?'), findsOneWidget);
      expect(find.text('Le garder sans course, à rattacher plus tard'), findsOneWidget);
      await tester.tap(find.textContaining(RegExp(r'^\d\d/\d\d · ')).first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 20 && find.byKey(const ValueKey('ticket-montant')).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
      }
      expect(find.text('Ticket de caisse'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('ticket-libelle')), 'Leclerc samedi');
      await tester.enterText(find.byKey(const ValueKey('ticket-montant')), '12,50');
      await _toucher(tester, find.text('Valider'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(etat.historique.where((c) => etat.ticketDe(c.id) == null).length, sansTicket - 1);
      final t = etat.tickets.last;
      expect(t.montant, 12.5);
      expect(etat.libelleTicket(t), 'Leclerc samedi');
      expect(File('${dossier.path}/tickets/${t.id}.pdf').existsSync(), isTrue);
    });

    testWidgets('liste simple : saisie, aperçu sans rayons, rangement à « Liste prête »', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      await _toucher(tester, find.text('Liste simple'));
      final etat = Etat.instance;
      final l = etat.listes.firstWhere((x) => etat.estSimple(x));
      for (final t in ['jamb', 'cafe mou', 'pq maison']) {
        await tester.enterText(find.byKey(const ValueKey('champ-recherche')), t);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
        await tester.pumpAndSettle();
        // Article absent du catalogue : on peut le ranger, ou non.
        if (find.text('Ne pas ranger').evaluate().isNotEmpty) await _toucher(tester, find.text('Ne pas ranger'));
      }
      expect([for (final g in l.lignes) etat.produit(g.produitId)!.nom], ['Jambon', 'Café moulu', 'pq maison'],
          reason: 'ajoutés en fin de liste, dans l\'ordre');
      expect(find.text('CHARCUTERIE'), findsNothing, reason: 'ni rayons ni secteurs');
      await tester.pump(const Duration(seconds: 4));
      await _toucher(tester, find.text('Aperçu'));
      expect(find.text('CHARCUTERIE'), findsNothing);
      await _toucher(tester, find.text('Rayons et secteurs'));
      expect(find.text('CHARCUTERIE'), findsOneWidget);
      await _toucher(tester, find.text('Continuer la préparation'));
      await _toucher(tester, find.text('Liste prête'));
      await _toucher(tester, find.text('Valider'));
      expect(etat.estRangee(l), isTrue, reason: 'rangée par rayons et secteurs pour les courses');
      expect(etat.estSimple(l), isTrue, reason: 'elle reste une liste simple en préparation');
      // Reprise en préparation : toujours le mode simple, sans rayons
      Nav.travail(EcranConstruction(listeId: l.id));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter un article (3 lettres ou plus)'), findsOneWidget);
      expect(find.text('CHARCUTERIE'), findsNothing);
    });

    testWidgets('préparation, mode Rechercher : l\'article trouvé s\'ajoute, seul son secteur est ouvert', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l1')!)));
      await _toucher(tester, find.text('Parcourir'));
      expect(Etat.instance.ajoutParRecherche, isTrue, reason: '« Parcourir » relâché : mode recherche');
      final l = Etat.instance.liste('l1')!;
      final huile = Etat.instance.produits.firstWhere((p) => p.nom == 'Huile d\'olive');
      expect(Etat.instance.ligne(l, huile.id), isNull);
      expect(find.text('Lait demi-écrémé'), findsNothing, reason: 'seule la liste est montrée, rayons repliés');
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'huile oli');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(Etat.instance.ligne(l, huile.id), isNotNull, reason: 'ajouté à la liste');
      expect(find.text('Huile d\'olive'), findsOneWidget);
      expect(find.text('+ Marque'), findsOneWidget, reason: 'on est sur l\'article, ses pastilles sont visibles');
      expect(find.text('+ Produit absent de ce secteur'), findsNothing, reason: 'la liste seule, pas le catalogue');
      expect(find.byKey(const ValueKey('option-recherche-0')), findsNothing, reason: 'liste des trouvés fermée');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('champ-recherche'))).controller!.text, isEmpty);

      // Article déjà dans la liste : on va dessus, sans rien ajouter.
      final n = l.lignes.length;
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'huile oli');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('option-recherche-0')), findsOneWidget, reason: 'la recherche répond encore');
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(l.lignes.length, n);
      await tester.pump(const Duration(seconds: 4));
      await _ciblesTactiles(tester);
    });

    testWidgets('non placés : visibles en fin de liste, toucher propose un secteur', (tester) async {
      final etat = Etat.instance;
      final l = etat.liste('l1')!;
      for (var i = 1; i <= 25; i++) {
        etat.ajouterLigne(l, etat.creerProduit('Article inconnu $i').id);
      }
      final truc = etat.creerProduit('Truc mystère');
      etat.ajouterLigne(l, truc.id);
      await _accueil(tester);
      await _toucher(tester, find.text(etat.nomListe(l)));
      await _toucher(tester, find.text('NON PLACÉ'));
      await _voir(tester, find.textContaining('Truc mystère', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Truc mystère', findRichText: true).hitTestable(), findsOneWidget);
      // Toucher son nom propose un secteur (pas la fenêtre de l'article)
      await _toucher(tester, find.textContaining('Truc mystère', findRichText: true));
      expect(find.text('Ajouter une marque'), findsNothing);
      expect(find.textContaining('Où ranger « Truc mystère »'), findsOneWidget);
      await _toucher(tester, find.text('FRAIS').last);
      await _toucher(tester, find.text('CRÈMERIE').last);
      expect(etat.secteurDe(l.magasinId, truc.id)?.nom, 'Crèmerie');
    });

    testWidgets('nouvelle liste depuis le texte d\'un mail', (tester) async {
      await tester.runAsync(chargerCorrespondances); // lecture réelle de l'asset, hors horloge simulée
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      await _toucher(tester, find.text('Liste depuis un mail'));
      await tester.enterText(find.byKey(const ValueKey('texte-mail')),
          'Bonjour,\n\nCRÈMERIE\n- Lait demi écrémé x2\n- beurre doux, bidule introuvable\n\nEnvoyé de mon iPhone');
      await _toucher(tester, find.text('Lire la liste'));
      expect(find.text('Lait demi-écrémé × 2'), findsOneWidget);
      expect(find.text('Beurre doux'), findsOneWidget);
      expect(find.text('Bidule introuvable (nouveau)'), findsOneWidget);
      await _toucher(tester, find.text('Bidule introuvable (nouveau)'));
      await _toucher(tester, find.text('Créer la liste'));
      final l = Etat.instance.listes.last;
      expect([for (final g in l.lignes) Etat.instance.produit(g.produitId)!.nom], ['Lait demi-écrémé', 'Beurre doux']);
      expect(l.lignes.first.quantite, 2);
    });

    testWidgets('liste depuis plusieurs mails, fusionnés', (tester) async {
      await tester.runAsync(chargerCorrespondances);
      await _accueil(tester);
      await _toucher(tester, find.text('+ Nouvelle liste'));
      await _toucher(tester, find.text('Liste depuis un mail'));
      await tester.enterText(find.byKey(const ValueKey('texte-mail')), 'Lait demi écrémé x2\nBeurre doux');
      await _toucher(tester, find.text('Ajouter un autre mail'));
      expect(find.text('1 mail déjà ajouté'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('texte-mail')), 'lait demi-écrémé\nbeurre doux\nbeurre doux');
      await _toucher(tester, find.text('Lire la liste'));
      // Le lait : 2 dans un mail, 1 dans l'autre → 2 ; le beurre : 1, puis 2 dans le même mail → 2
      expect(find.text('Lait demi-écrémé × 2'), findsOneWidget);
      expect(find.text('Beurre doux × 2'), findsOneWidget);
      expect(find.textContaining('Dans 2 mails'), findsNWidgets(2));
      await _toucher(tester, find.text('Créer la liste'));
      expect(Etat.instance.listes.last.lignes.length, 2);
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
      await _toucher(tester, find.text('Reste à faire'));
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

      // Deux appuis rapprochés : l'article manque en rayon
      await tester.tap(find.text('Fromage râpé'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Fromage râpé'));
      await tester.pumpAndSettle();
      expect(find.text('Manquant en rayon'), findsOneWidget);
      expect(Etat.instance.manquant(Etat.instance.liste('l4')!, Etat.instance.liste('l4')!.lignes.firstWhere(
          (g) => Etat.instance.produit(g.produitId)!.nom == 'Fromage râpé').produitId), isTrue);
      expect(find.text('Magasin 1 · 4 / 9'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // Terminer depuis la zone de décision : la liste des manquants et des non cochés
      await _toucher(tester, find.text('Terminer les courses'));
      expect(find.text('Terminer les courses ?'), findsOneWidget);
      expect(find.text('Manquants en rayon (1)'), findsOneWidget);
      expect(find.text('• Fromage râpé'), findsOneWidget);
      expect(find.text('Non cochés (4)'), findsOneWidget);
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
      Etat.instance.commenter(Etat.instance.liste('l3')!, 'Pharmacie aussi');
      await _toucher(tester, find.text('Faire les courses').last);
      // Le commentaire s'affiche à l'ouverture, en fenêtre simple
      expect(find.text('Pharmacie aussi'), findsOneWidget);
      await _toucher(tester, find.byTooltip('Fermer'));
      expect(find.text('Pharmacie aussi'), findsNothing);
      await _toucher(tester, find.byTooltip('Commentaire'));
      expect(find.text('Pharmacie aussi'), findsOneWidget);
      await _toucher(tester, find.byTooltip('Fermer'));
      expect(find.text('Pause'), findsOneWidget);
      expect(Etat.instance.liste('l3')!.statut, StatutListe.enCours);
    });

    testWidgets('gestes : glisser une liste, Annuler, appui long', (tester) async {
      final etat = Etat.instance;
      final nom = etat.nomListe(etat.liste('l3')!);
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      // Vers la droite : la liste prête retourne en préparation.
      await tester.drag(find.text(nom), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(etat.liste('l3')!.statut, StatutListe.enConstruction);
      await tester.pump(const Duration(seconds: 6));
      await _toucher(tester, _onglet('Préparer'));
      // Vers la gauche : supprimée, puis « Annuler » la remet.
      await tester.drag(find.text(nom), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(etat.liste('l3'), isNull);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(etat.liste('l3'), isNotNull);
      await tester.pump(const Duration(seconds: 6));
      // Appui long : le menu des actions.
      await tester.longPress(find.text(nom));
      await tester.pumpAndSettle();
      expect(find.text('Renommer'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('historique : rattacher un ticket', (tester) async {
      await _accueil(tester);
      await _depuisCourses(tester, 'Historique');
      await _voir(tester, find.text('Rattacher à une course'));
      await _toucher(tester, find.text('Rattacher à une course'));
      await _toucher(tester, find.textContaining('Magasin 2').first);
      expect(find.text('Rattacher à une course'), findsNothing);
    });

    testWidgets('catalogue : ranger un produit non rangé, créer un produit, le retrouver dans « Ajoutés ou modifiés »', (tester) async {
      final etat = Etat.instance;
      etat.harmoniserCatalogue(); // fait à l'ouverture du foyer
      final truc = etat.creerProduit('Truc mystère');
      await _accueil(tester);
      await _rubrique(tester, 'Catalogue');
      await _voir(tester, find.text('Truc mystère'));
      await _toucher(tester, find.text('Truc mystère'));
      expect(find.byType(SignePerso), findsWidgets, reason: 'petit signe des produits ajoutés');
      await _toucher(tester, find.text('Changer'));
      await _toucher(tester, find.text('FRAIS').last);
      await _toucher(tester, find.text('CRÈMERIE').last);
      for (final m in etat.magasins) {
        expect(etat.secteurDe(m.id, truc.id)?.nom, 'Crèmerie', reason: 'le même rangement dans tous les magasins');
      }
      await _toucher(tester, find.byTooltip('Retour'));
      await _rubrique(tester, 'Catalogue');
      await _toucher(tester, find.textContaining('Ajoutés, modifiés'));
      expect(find.text('Truc mystère'), findsOneWidget);
      await _ciblesTactiles(tester);
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

    testWidgets('écran d\'essai accessible depuis Gérer › Courses', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Produits réels');
      expect(find.text('Produits réels (essai)'), findsOneWidget);
      await _ciblesTactiles(tester);
    });

    testWidgets('Gérer › Paramètres › MQTT : serveur HiveMQ prérempli', (tester) async {
      await _lancer(tester);
      await _rubrique(tester, 'MQTT');
      expect(find.text('Partager ce foyer'), findsOneWidget);
      expect(find.text('Rejoindre un foyer'), findsOneWidget);
      expect(find.text('SERVEUR MQTT'), findsOneWidget, reason: 'configuration seulement, serveur déplié');
      final hote = tester.widget<TextField>(find.byKey(const ValueKey('mqtt-hote')));
      expect(hote.controller!.text, 'broker.hivemq.com');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('mqtt-port'))).controller!.text, '8883');
      await _ciblesTactiles(tester);
      // « Annuler » ne crée pas de partage
      await _toucher(tester, find.text('Partager ce foyer'));
      expect(find.text('Créer le code du foyer'), findsOneWidget);
      await _toucher(tester, find.text('Annuler'));
      expect(find.text('Partager ce foyer'), findsOneWidget);
    });

    testWidgets('le nuage montre seulement l\'état : voyant, sa signification, appareils', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.byIcon(Icons.cloud_outlined).first);
      expect(find.text('Synchronisation'), findsOneWidget);
      expect(find.text('Foyer non partagé'), findsOneWidget);
      expect(find.text('Signification du voyant'), findsOneWidget);
      expect(find.text('Rouge : pas de connexion au serveur MQTT ou pas de réseau'), findsOneWidget);
      expect(find.text('Partager ce foyer'), findsNothing);
      expect(find.text('SERVEUR MQTT'), findsNothing);
    });
  });
}
