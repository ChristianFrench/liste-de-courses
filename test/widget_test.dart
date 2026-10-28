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
import 'package:liste_de_courses/donnees/catalogue_commun.dart' show Brouillon;
import 'package:liste_de_courses/donnees/envoi.dart';
import 'package:liste_de_courses/donnees/import_texte.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/synchro.dart' show ServeurMqtt;
import 'package:liste_de_courses/ecrans/foyer.dart' show choisirPersonne;
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';
import 'package:liste_de_courses/donnees/ticket_recu.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
import 'package:liste_de_courses/ecrans/archives.dart';
import 'package:liste_de_courses/ecrans/corbeille.dart' show EcranCorbeille;
import 'package:liste_de_courses/ecrans/historique.dart' show BlocTicket, SousEcranHistorique;
import 'package:liste_de_courses/ecrans/listes.dart' show SousEcranCourses;
import 'package:liste_de_courses/ecrans/travail.dart' show EcranConstruction, EcranConsultation, EcranCoursesSecteur, FeuillePromotion, LigneArticle, codeCourtPackaging;
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

/// Touche le titre de la fenêtre (ses actions s'ouvrent dans un volet), puis l'action donnée.
Future<void> _actionTitre(WidgetTester tester, String action) async {
  await _toucher(tester, find.byKey(const ValueKey('titre-actions')).hitTestable().first);
  await _toucher(tester, find.text(action).last);
}

/// Vérifie que le titre de la fenêtre propose l'action donnée, puis referme le volet.
Future<void> _menuTitre(WidgetTester tester, String action) async {
  await _toucher(tester, find.byKey(const ValueKey('titre-actions')).hitTestable().first);
  expect(find.text(action), findsOneWidget);
  await _fermerVolet(tester);
}

/// Ferme le volet du bas ouvert (appui au-dessus de lui).
Future<void> _fermerVolet(WidgetTester tester) async {
  await tester.tapAt(const Offset(195, 20));
  await tester.pumpAndSettle();
}

/// Touche une liste (son volet s'ouvre), puis l'action donnée.
Future<void> _ouvrirListe(WidgetTester tester, String nom, String action) async {
  await _toucher(tester, find.text(nom).first);
  await _toucher(tester, find.text(action).last);
}

/// Nombre d'articles de la liste en préparation à l'écran.
int _nbEnPreparation(WidgetTester tester) =>
    Etat.instance.liste(tester.widget<EcranConstruction>(find.byType(EcranConstruction)).listeId)!.lignes.length;

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

/// Historique, Archives, Corbeille : pages complètes (aussi déployées sur place en fin d'onglet Courses).
Future<void> _depuisCourses(WidgetTester tester, String titre) async {
  await _toucher(tester, _onglet('Courses'));
  Nav.i.retourOnglet(Nav.courses);
  await tester.pumpAndSettle();
  final page = switch (titre) {
    'Archives' => const EcranArchives(),
    'Corbeille' => const EcranCorbeille(),
    _ => const PageBase(entete: EnTeteFenetre(retour: true, titre: 'Historique'), corps: SousEcranHistorique()),
  };
  Nav.aller<void>(tester.element(find.byType(SousEcranCourses)), page);
  await tester.pumpAndSettle();
}

/// Cibles tactiles d'au moins 30 points : la hauteur des lignes de toutes les listes, voulue serrée.
Future<void> _ciblesTactiles(WidgetTester tester) =>
    expectLater(tester, meetsGuideline(const MinimumTapTargetGuideline(size: Size(30, 30), link: 'lignes de 30 points')));

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

    test('liste rectificative : une par liste, fusionnée, envoyée, refusée puis « À faire » marquée', () {
      final e = Etat.instance;
      Liste l(String id) => e.liste(id)!;
      expect(e.ciblesRectificative().map((x) => x.id), ['l3', 'l4']);
      final r1 = e.creerRectificative(l('l4'));
      expect(e.estSimple(r1), isTrue);
      expect(e.rectificativeOuvertePour(l('l4'))?.listeId, r1.id, reason: 'une seule à la fois : elle sera reprise');
      e.ajouterLigne(r1, 'p20');
      e.ajouterLigne(r1, 'p1');
      expect(e.validerRectificative(r1), 'envoyee');
      expect(e.rectificativeEnAttente(l('l4'))?.listeId, r1.id);
      expect(e.mentionRectificative(r1), ' · rectificative envoyée');
      final avant = jsonEncode(e.versJson());
      e.lire(jsonDecode(avant) as Map<String, dynamic>);
      expect(jsonEncode(e.versJson()), avant);

      // Refusée : « À faire », marquée, jusqu'à sa remise en préparation
      e.refuserRectificative(e.rectificativeEnAttente(l('l4'))!);
      expect(l(r1.id).statut, StatutListe.prete);
      expect(e.mentionRectificative(l(r1.id)), ' · rectificative');
      e.remettreEnPreparation(l(r1.id));
      expect(e.mentionRectificative(l(r1.id)), '');

      // Liste « À faire » : fusion immédiate
      final r2 = e.creerRectificative(l('l3'));
      e.ajouterLigne(r2, 'p21');
      expect(e.validerRectificative(r2), 'fusionnee');
      expect(e.liste(r2.id), isNull);
      expect(e.ligne(l('l3'), 'p21'), isNotNull);

      // Courses en cours : acceptée, puis oubliée à la fin des courses
      final r3 = e.creerRectificative(l('l4'));
      e.ajouterLigne(r3, 'p18');
      e.ajouterLigne(r3, 'p7');
      e.validerRectificative(r3);
      final nb = l('l4').lignes.length;
      e.accepterRectificative(e.rectificativeEnAttente(l('l4'))!, fusion: true);
      expect(l('l4').lignes.length, nb + 2);
      expect(e.rectificativesAcceptees(l('l4')).single.produits, ['p18', 'p7']);

      // En attente à la fin des courses : « À faire »
      final r4 = e.creerRectificative(l('l3'));
      e.ajouterLigne(r4, 'p5');
      e.terminerCourses(l('l4'));
      expect(e.rectificativesAcceptees(l('l4')), isEmpty);
      expect(e.rectificatives.values.where((r) => r.cibleId == 'l4'), isEmpty);
      expect(e.rectificativeDe(r4)?.enRedaction, isTrue);
    });

    test('marques distributeur : enseigne reconnue dans le nom du magasin, marques selon le secteur', () {
      final e = Etat.instance;
      e.lireMarquesDistributeur(jsonDecode(File('assets/marques_distributeur.json').readAsStringSync()) as Map<String, dynamic>);
      final m = e.magasins.first;
      final s = e.secteurCatalogue(e.produits.first.id)!;
      e.renommerMagasin(m, 'Super U Nantes');
      expect(e.enseigneDe(m), 'Système U');
      expect(e.marquesDistributeurPour(m, s), containsAll(['U Bio', 'U Saveurs']), reason: 'marques valables partout');
      expect(e.marquesDistributeurPour(m, s), isNot(contains('U Tout Petits')), reason: 'rayon Bébé seulement');
      e.definirEnseigne(m, 'Leclerc');
      expect(e.marquesDistributeurPour(m, s), contains('Eco+'));
      e.definirEnseigne(m, '-');
      expect(e.enseigneDe(m), isNull, reason: '« Aucune » choisie');
      expect(e.marquesProposees(null, e.produits.first, magasinId: m.id), isNot(contains('Eco+')));
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
      expect(find.text('EN PRÉPARATION'), findsOneWidget);
      expect(find.text('À FAIRE'), findsOneWidget, reason: 'les listes prêtes');
      await _ciblesTactiles(tester);
      expect(find.text('Nouvelle liste'), findsNothing);
      // Toucher une liste ouvre son volet : détail et actions
      await _toucher(tester, find.text(Etat.instance.nomListe(Etat.instance.liste('l3')!)).first);
      expect(find.text('Faire les courses'), findsOneWidget);
      await _fermerVolet(tester);
      expect(find.text('Faire les courses'), findsNothing);
    });

    testWidgets('en-tête : glisser change d\'onglet ; synchronisation et aide dans un volet du bas', (tester) async {
      await _lancer(tester);
      expect(find.textContaining('Version '), findsOneWidget, reason: 'numéro de version en haut de l\'accueil');
      expect(find.byType(EnTeteFenetre), findsNothing, reason: 'pas de bandeau de titre sur l\'accueil');
      await tester.fling(find.text('Bonjour !'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle liste'), findsOneWidget, reason: 'glisser à gauche : onglet Préparer');
      await tester.fling(find.byType(EnTeteFenetre), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Courses').first, findsOneWidget);
      await tester.fling(find.byType(EnTeteFenetre), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle liste'), findsOneWidget, reason: 'glisser à droite : retour à Préparer');
      // Sur une zone libre de la fenêtre, le même geste change aussi d'onglet
      await tester.fling(find.textContaining('Touchez une liste pour voir'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle liste'), findsNothing, reason: 'glisser sur le texte : onglet Courses');
      await tester.fling(find.byType(EnTeteFenetre), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      await _toucher(tester, find.byTooltip('Synchronisation : foyer non partagé'));
      expect(find.text('Foyer non partagé'), findsOneWidget, reason: 'l\'icône ouvre l\'état du partage');
      await _fermerVolet(tester);
      await _actionTitre(tester, 'Aide');
      expect(find.text('Aide · Préparer'), findsOneWidget);
      await _fermerVolet(tester);
      expect(find.text('Aide · Préparer'), findsNothing);
    });

    testWidgets('1 et 2. les 3 onglets, les rubriques de Gérer et leurs sous-onglets mémorisés', (tester) async {
      await _accueil(tester);
      await _ciblesTactiles(tester);
      await _toucher(tester, _onglet('Courses'));
      expect(find.text('À FAIRE'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Magasins');
      await _menuTitre(tester, '+ Nouveau magasin');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Catalogue');
      await _menuTitre(tester, 'Produits ajoutés (0)');
      expect(find.text('FRAIS'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Catalogue des marques');
      await _ciblesTactiles(tester);
      await _depuisCourses(tester, 'Historique');
      expect(find.text('Par magasin'), findsOneWidget);
      await _voir(tester, find.text('TICKETS NON RATTACHÉS'));
      expect(find.text('TICKETS NON RATTACHÉS'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Foyer');
      expect(find.text('Seul sur cet appareil'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Types de promotion');
      await _ciblesTactiles(tester);
      Etat.instance.completerLots(); // fait à l'ouverture du foyer : lots de 2 à 10
      await _rubrique(tester, 'Types de packaging');
      expect(find.text('Lot de 7'), findsOneWidget);
      expect(find.text('Pack de 6'), findsOneWidget, reason: 'les lots existants sont gardés');
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Types de mesure');
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
      if (find.text('Crèmerie').evaluate().isEmpty) await _toucher(tester, find.text('FRAIS'));
      await _toucher(tester, find.text('Crèmerie').last);
      await _toucher(tester, find.text('Voir et modifier les produits'));
      await _toucher(tester, find.text('Lait demi-écrémé'));
      expect(find.textContaining('RANGEMENT'), findsOneWidget, reason: 'fiche produit');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.textContaining('RANGEMENT'), findsNothing);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('FRAIS'), findsOneWidget);

      await _rubrique(tester, 'Types de promotion');
      expect(find.text('Remise immédiate'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      expect(find.text('Remise immédiate'), findsNothing);
    });

    testWidgets('4, 5, 6 et 8. préparation condensée : secteurs, quantités, volet de l\'article, retrait', (tester) async {
      final etat = Etat.instance;
      final l = etat.liste('l1')!;
      await _accueil(tester);
      await _ouvrirListe(tester, etat.nomListe(l), 'Continuer la préparation');
      expect(find.text(etat.nomListe(l)), findsOneWidget);
      // 4 : une seule liste, sous de minces bandeaux de secteur ; ni rayons, ni catalogue, ni modes
      expect(find.text('CRÈMERIE'), findsOneWidget);
      expect(find.text('FRAIS'), findsNothing, reason: 'pas de rayons');
      expect(find.byKey(const ValueKey('mode-preparation')), findsNothing);
      expect(find.text('Aperçu'), findsNothing);
      expect(find.byType(LigneArticle), findsNWidgets(l.lignes.length));
      await _ciblesTactiles(tester);

      // 5 : − N + sur la ligne ; à 0 l'article est retiré, « Annuler » le remet
      final lait = etat.produits.firstWhere((p) => p.nom == 'Lait demi-écrémé');
      final q = etat.ligne(l, lait.id)!.quantite;
      await _toucher(tester, find.byKey(ValueKey('plus-${lait.id}')));
      expect(etat.ligne(l, lait.id)!.quantite, q + 1);
      expect(find.text('×${q + 1}'), findsNothing, reason: 'le nombre seul, sans x');
      for (var i = 0; i <= q; i++) {
        await _toucher(tester, find.byKey(ValueKey('moins-${lait.id}')));
      }
      expect(etat.ligne(l, lait.id), isNull, reason: 'à 0, l\'article quitte la liste');
      await _toucher(tester, find.text('Annuler'));
      expect(etat.ligne(l, lait.id), isNotNull);
      await tester.pump(const Duration(seconds: 6));

      // 6 : toucher la ligne ouvre le volet de l'article : packaging, consigne et promotion ensemble
      await _toucher(tester, find.byKey(ValueKey('condense-${lait.id}')));
      expect(find.byType(FeuillePromotion), findsOneWidget);
      expect(find.text('PACKAGING'), findsOneWidget);
      expect(find.text('PROMOTION VISÉE'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('consigne')), 'bien frais');
      await _toucher(tester, find.text('Valider'));
      expect(etat.ligne(l, lait.id)!.consigne, 'bien frais');
      expect(find.textContaining('« bien frais »', findRichText: true), findsOneWidget, reason: 'la consigne suit le nom');

      // La marque : liste déroulante des marques du secteur ; l'article devient « Lait demi-écrémé Lactel »
      etat.lireMarquesType({
        'secteurs': {etat.cleSecteur(etat.secteurCatalogue(lait.id)!): ['Lactel', 'Candia']}
      });
      await _toucher(tester, find.byKey(ValueKey('condense-${lait.id}')));
      expect(find.text('MARQUE'), findsOneWidget);
      await _toucher(tester, find.byKey(const ValueKey('choix-marque')));
      await _toucher(tester, find.text('Lactel').last);
      await _toucher(tester, find.text('Valider'));
      final lactel = etat.produits.firstWhere((p) => p.nom == 'Lait demi-écrémé Lactel');
      expect(etat.ligne(l, lactel.id)?.consigne, 'bien frais', reason: 'la ligne garde sa consigne');
      etat.marquesType = {};

      // 8 : appui long : retiré
      await tester.longPress(find.byKey(ValueKey('condense-${lactel.id}')));
      await tester.pumpAndSettle();
      expect(etat.ligne(l, lactel.id), isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('2. nouvelle liste : types, recherche, liste prête, liste type', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('Nouvelle liste'));
      expect(find.text('Liste calculée'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Liste personnalisée'));
      expect(find.text('Dernières courses dans ce magasin'), findsOneWidget, reason: 'dans un volet du bas');
      await _fermerVolet(tester);
      await _toucher(tester, find.text('Liste type'));
      await _toucher(tester, find.text('Liste vide'));
      expect(_nbEnPreparation(tester), 0);
      // La recherche ajoute l'article et va dessus
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'ja');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('option-recherche-0')), findsNothing, reason: 'moins de trois lettres');
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'jamb');
      await tester.pumpAndSettle();
      expect(find.text('Frais › Charcuterie'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(_nbEnPreparation(tester), 1);
      expect(find.text('CHARCUTERIE'), findsOneWidget);
      expect(find.text('Jambon'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await _toucher(tester, find.text('Liste prête'));
      await tester.enterText(find.byKey(const ValueKey('commentaire-liste')), 'Pharmacie aussi');
      expect(find.text('Fin de la liste'), findsOneWidget, reason: 'volet de fin de liste');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Enregistrer comme liste type'));
      await tester.enterText(find.byKey(const ValueKey('nom-liste-type')), 'Petit-déjeuner');
      await _toucher(tester, find.text('Valider'));
      expect(find.text('À FAIRE'), findsOneWidget);
      expect(Etat.instance.listesTypes.map((t) => t.nom), contains('Petit-déjeuner'));
      expect(Etat.instance.commentaires.values, contains('Pharmacie aussi'));

      // La liste type est proposée pour une nouvelle liste, avec ses articles (après disparition du message)
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('Nouvelle liste'));
      await _toucher(tester, find.text('Liste type'));
      await _toucher(tester, find.text('Petit-déjeuner'));
      expect(_nbEnPreparation(tester), 1);
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

    testWidgets('liste simple : saisie sans secteurs, rangement à « Liste prête »', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.text('Nouvelle liste'));
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
        if (find.text('Ajouter').evaluate().isNotEmpty) await _toucher(tester, find.text('Ajouter'));
      }
      expect([for (final g in l.lignes) etat.produit(g.produitId)!.nom], ['Jambon', 'Café moulu', 'pq maison'],
          reason: 'ajoutés en fin de liste, dans l\'ordre');
      expect(find.text('CHARCUTERIE'), findsNothing, reason: 'ni rayons ni secteurs');
      await tester.pump(const Duration(seconds: 4));
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

    testWidgets('préparation : l\'article trouvé s\'ajoute, P des promotions, toucher détaille l\'article', (tester) async {
      final etat = Etat.instance;
      final l = etat.liste('l1')!;
      await _accueil(tester);
      await _ouvrirListe(tester, etat.nomListe(l), 'Continuer la préparation');
      final huile = etat.produits.firstWhere((p) => p.nom == 'Huile d\'olive');
      expect(etat.ligne(l, huile.id), isNull);
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'huile oli');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(etat.ligne(l, huile.id), isNotNull, reason: 'ajouté à la liste');
      expect(find.byKey(const ValueKey('option-recherche-0')), findsNothing, reason: 'liste des trouvés fermée');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('champ-recherche'))).controller!.text, isEmpty);
      if (l.lignes.any((g) => g.promotion != null)) expect(find.text('P'), findsWidgets, reason: 'P devant les promotions');
      // Article déjà dans la liste : on va dessus, sans rien ajouter.
      final n = l.lignes.length;
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'huile oli');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      expect(l.lignes.length, n);
      await tester.pump(const Duration(seconds: 4));
      await _ciblesTactiles(tester);
    });

    test('historique, archives et corbeille : remettre, archiver, vider', () {
      final etat = Etat.instance;
      final c = etat.historique.first;
      etat.archiver(c);
      expect(etat.coursesArchivees, contains(c));
      etat.remettreEnHistorique(c);
      expect(etat.coursesArchivees, isNot(contains(c)));
      etat.delaiHistorique = 1;
      etat.archiverAnciennes();
      expect(etat.archivees.contains(c.id), isFalse, reason: 'remise à la main : elle reste dans l\'historique');
      etat.remettreSansTicket(c);
      expect(etat.enInstance(c), etat.ticketDe(c.id) == null);
      // Changer de personne (appareil partagé, ou mauvais choix) : l'ancien moi reste membre
      final ancien = etat.moi;
      final autre = etat.membres.firstWhere((m) => !m.moi);
      etat.devenir(autre);
      expect(etat.moi.id, autre.id);
      expect(etat.membresVisibles.map((m) => m.id), contains(ancien.id));
      etat.devenir(ancien);
      expect(etat.moi.id, ancien.id);
      etat.supprimer(etat.listes.first);
      expect(etat.corbeille, isNotEmpty);
      etat.viderCorbeille();
      expect(etat.corbeille, isEmpty);
    });

    testWidgets('non placés : visibles en fin de liste, sous leur bandeau', (tester) async {
      final etat = Etat.instance;
      final l = etat.liste('l1')!;
      for (var i = 1; i <= 25; i++) {
        etat.ajouterLigne(l, etat.creerProduit('Article inconnu $i').id);
      }
      final truc = etat.creerProduit('Truc mystère');
      etat.ajouterLigne(l, truc.id);
      await _accueil(tester);
      await _ouvrirListe(tester, etat.nomListe(l), 'Continuer la préparation');
      await _voir(tester, find.textContaining('Truc mystère', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Truc mystère', findRichText: true).hitTestable(), findsOneWidget);
      if (find.text('NON PLACÉ').evaluate().isEmpty) {
        await tester.scrollUntilVisible(find.text('NON PLACÉ'), -150,
            scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      }
      expect(find.text('NON PLACÉ'), findsOneWidget);
    });

    testWidgets('nouvelle liste depuis le texte d\'un mail', (tester) async {
      await tester.runAsync(chargerCorrespondances); // lecture réelle de l'asset, hors horloge simulée
      await _accueil(tester);
      await _toucher(tester, find.text('Nouvelle liste'));
      await _toucher(tester, find.text('Liste depuis un texte'));
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
      await _toucher(tester, find.text('Nouvelle liste'));
      await _toucher(tester, find.text('Liste depuis un texte'));
      await tester.enterText(find.byKey(const ValueKey('texte-mail')), 'Lait demi écrémé x2\nBeurre doux');
      await _toucher(tester, find.text('Ajouter un autre texte'));
      expect(find.text('1 texte déjà ajouté'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('texte-mail')), 'lait demi-écrémé\nbeurre doux\nbeurre doux');
      await _toucher(tester, find.text('Lire la liste'));
      // Le lait : 2 dans un mail, 1 dans l'autre → 2 ; le beurre : 1, puis 2 dans le même mail → 2
      expect(find.text('Lait demi-écrémé × 2'), findsOneWidget);
      expect(find.text('Beurre doux × 2'), findsOneWidget);
      expect(find.textContaining('Dans 2 mails'), findsNWidgets(2));
      await _toucher(tester, find.text('Créer la liste'));
      expect(Etat.instance.listes.last.lignes.length, 2);
    });

    testWidgets('liste rectificative : saisie depuis Nouvelle liste, acceptée à part pendant les courses', (tester) async {
      EcranCoursesSecteur.clignoter = false;
      final etat = Etat.instance;
      final l4 = etat.liste('l4')!;
      await _accueil(tester);
      await _toucher(tester, find.text('Nouvelle liste'));
      await _toucher(tester, find.text('Liste rectificative'));
      expect(find.text('Liste à rectifier'), findsOneWidget);
      await _toucher(tester, find.text(etat.nomListe(l4)).last);
      await tester.enterText(find.byKey(const ValueKey('champ-recherche')), 'dentif');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('option-recherche-0')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await _toucher(tester, find.text('Liste prête'));
      expect(find.textContaining('il l\'acceptera ou la refusera'), findsOneWidget);
      await _toucher(tester, find.text('Valider'));
      expect(etat.rectificativeEnAttente(l4), isNotNull);
      expect(find.textContaining('rectificative envoyée'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await _toucher(tester, _onglet('Courses'));
      await _ouvrirListe(tester, etat.nomListe(l4), 'Reprendre les courses');
      // Le résumé s'ouvre tout seul ; l'icône du titre reste tant que rien n'est décidé
      expect(find.text('Liste rectificative'), findsOneWidget);
      expect(find.textContaining('propose 1 article'), findsOneWidget);
      await _toucher(tester, find.text('Plus tard'));
      expect(find.byKey(const ValueKey('bouton-rectificative')), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('Voir et décider'), findsOneWidget, reason: 'rappel toutes les 60 s');
      await _toucher(tester, find.text('Voir et décider'));
      await _toucher(tester, find.text('Accepter'));
      await _toucher(tester, find.text('Garder à part'));
      expect(find.byKey(const ValueKey('bouton-rectificative')), findsNothing);
      expect(find.text('AJOUTS DE MEMBRE 1'), findsOneWidget);
      expect(find.text('Dentifrice'), findsOneWidget);
      expect(find.text('Magasin 1 · 4 / 10'), findsOneWidget);
      EcranCoursesSecteur.clignoter = true;
    });

    testWidgets('consulter une liste, quel que soit son état', (tester) async {
      final etat = Etat.instance;
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      await _ouvrirListe(tester, etat.nomListe(etat.liste('l4')!), 'Consulter');
      expect(find.byType(EcranConsultation), findsOneWidget);
      expect(find.textContaining('En cours de courses'), findsOneWidget);
      expect(find.byType(LigneArticle), findsNWidgets(9));
      expect(find.byType(Bouton), findsNothing, reason: 'consultation seule');
      await _toucher(tester, find.text('Fromage râpé'));
      expect(find.text('Quantité : 1'), findsOneWidget, reason: 'toucher un article en montre le détail');
    });

    testWidgets('9. Courses : la liste condensée, cocher, manquant, Pause puis Interrompre', (tester) async {
      final etat = Etat.instance;
      final l4 = etat.liste('l4')!;
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      expect(find.text('EN COURS'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _ouvrirListe(tester, etat.nomListe(l4), 'Reprendre les courses');
      expect(find.text('Magasin 1 · 4 / 9'), findsOneWidget);
      expect(find.text('CRÈMERIE'), findsOneWidget);
      expect(find.text('Reste à faire'), findsNothing, reason: 'les articles cochés restent à leur place');
      expect(find.byType(LigneArticle), findsNWidgets(9));
      await _ciblesTactiles(tester);

      // Cocher un article : il reste à sa place
      await _toucher(tester, find.text('Fromage râpé'));
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);
      expect(find.text('Fromage râpé'), findsOneWidget);

      await _toucher(tester, find.text('Pause'));
      expect(find.text('Interrompre les courses ?'), findsOneWidget);
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Interrompre'));
      expect(find.text('EN COURS'), findsOneWidget);
      final premier = etat.etapes(l4, l4.parcoursId).firstWhere((x) => x.lignes.any((g) => !g.coche));
      expect(l4.repriseSecteurId, premier.id, reason: 'secteur où l\'on en est, enregistré à l\'interruption');

      await _ouvrirListe(tester, etat.nomListe(l4), 'Reprendre les courses');
      expect(find.text('Magasin 1 · 5 / 9'), findsOneWidget);

      // Deux appuis rapprochés : l'article manque en rayon
      await tester.tap(find.text('Fromage râpé'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Fromage râpé'));
      await tester.pumpAndSettle();
      expect(etat.manquant(l4, l4.lignes.firstWhere((g) => etat.produit(g.produitId)!.nom == 'Fromage râpé').produitId), isTrue);
      expect(find.text('Magasin 1 · 4 / 9'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // Terminer depuis la zone de décision : la liste des manquants et des non cochés
      await _toucher(tester, find.text('Terminer'));
      expect(find.text('Terminer les courses ?'), findsOneWidget);
      expect(find.text('Manquants en rayon (1)'), findsOneWidget);
      expect(find.text('• Fromage râpé'), findsOneWidget);
      expect(find.text('Non cochés (4)'), findsOneWidget);
      await _fermerVolet(tester);
      expect(find.text('Terminer les courses ?'), findsOneWidget, reason: 'ce volet ne se ferme que par ses boutons');
      await _toucher(tester, find.text('Terminer les courses').last);
      expect(find.text('TERMINÉES SANS TICKET'), findsOneWidget, reason: 'la course attend son ticket dans l\'onglet Courses');
      expect(etat.coursesEnInstance.any((c) => c.id == 'l4'), isTrue);
    });

    testWidgets('démarrer des courses depuis une liste prête', (tester) async {
      await _accueil(tester);
      await _toucher(tester, _onglet('Courses'));
      await _ouvrirListe(tester, Etat.instance.nomListe(Etat.instance.liste('l3')!), 'Faire les courses');
      expect(find.text('Faire les courses'), findsWidgets, reason: 'volet de départ');
      expect(find.text('Enregistrer le parcours'), findsOneWidget);
      await _ciblesTactiles(tester);
      Etat.instance.commenter(Etat.instance.liste('l3')!, 'Pharmacie aussi');
      await _toucher(tester, find.text('Faire les courses').last);
      // Le commentaire s'affiche à l'ouverture, en fenêtre simple
      expect(find.text('Pharmacie aussi'), findsOneWidget);
      await _fermerVolet(tester);
      expect(find.text('Pharmacie aussi'), findsNothing);
      await _toucher(tester, find.byTooltip('Commentaire'));
      expect(find.text('Pharmacie aussi'), findsOneWidget);
      await _fermerVolet(tester);
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
      final etat = Etat.instance;
      int libres() => etat.tickets.where((t) => etat.course(t.listeId) == null).length;
      final avant = libres();
      await _voir(tester, find.byType(BlocTicket).first);
      await _toucher(tester, find.byType(BlocTicket).first);
      await _toucher(tester, find.text('Rattacher à une course'));
      await _toucher(tester, find.textContaining('Magasin 2').first);
      expect(libres(), avant - 1);
    });

    testWidgets('catalogue : ajouter un produit par sa fenêtre, le modifier ; les produits d\'origine ne se modifient pas', (tester) async {
      final etat = Etat.instance;
      etat.harmoniserCatalogue(); // fait à l'ouverture du foyer
      await _accueil(tester);
      await _rubrique(tester, 'Catalogue');
      expect(find.text('+ Nouveau produit'), findsNothing, reason: 'on ajoute depuis un rayon et un secteur');
      // Le rayon a pu rester ouvert (groupes mémorisés d'un test à l'autre).
      if (find.text('Crèmerie').evaluate().isEmpty) await _toucher(tester, find.text('FRAIS'));
      await _toucher(tester, find.text('Crèmerie').last);
      await _toucher(tester, find.text('+ Nouveau produit'));
      expect(find.textContaining('photo'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('produit-nom')), 'Camembert');
      await tester.enterText(find.byKey(const ValueKey('produit-marque')), 'Président');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('produit-nom-retenu')), matching: find.text('Camembert Président')), findsOneWidget,
          reason: 'le nom retenu, en haut, sans saisie');
      await _ciblesTactiles(tester);
      await _toucher(tester, find.text('Ajouter'));
      final p = etat.produits.firstWhere((x) => x.nom == 'Camembert Président');
      expect(etat.estAjoute(p), isTrue);
      expect(etat.marque(p.marqueIds.single)?.nom, 'Président');
      for (final m in etat.magasins) {
        expect(etat.secteurDe(m.id, p.id)?.nom, 'Crèmerie', reason: 'le même rangement dans tous les magasins');
      }
      await _toucher(tester, find.text('Crèmerie').last);
      await _toucher(tester, find.text('Voir et modifier les produits'));
      expect(find.byType(SignePerso), findsWidgets, reason: 'petit signe des produits ajoutés');

      // Produit d'origine : ni « Modifier » ni « Supprimer », mais « Avec une marque ».
      await _toucher(tester, find.text('Lait demi-écrémé'));
      await _toucher(tester, find.byKey(const ValueKey('titre-actions')).hitTestable().first);
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Avec une marque'), findsOneWidget);
      await _fermerVolet(tester);
      await _toucher(tester, find.byTooltip('Retour'));
      await _toucher(tester, find.byTooltip('Retour'));

      // Produits ajoutés : la fenêtre du produit pour le modifier.
      await _actionTitre(tester, 'Produits ajoutés (1)');
      await _toucher(tester, find.text('Camembert Président'));
      await _toucher(tester, find.text('Modifier'));
      expect(find.text('Modifier le produit'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('produit-nom')), 'Brie');
      await _toucher(tester, find.text('Enregistrer'));
      expect(p.nom, 'Brie Président');
      await _toucher(tester, find.text('Brie Président'));
      await _toucher(tester, find.text('Supprimer'));
      await _toucher(tester, find.text('Supprimer').last);
      expect(etat.produit(p.id), isNull, reason: 'un produit ajouté se supprime depuis la liste des produits ajoutés');
      await _ciblesTactiles(tester);
    });
  });

  group('Gérer', () {
    testWidgets('catalogue des marques : par secteur, renommer (ses produits aussi), retirer, ajouter ; types en liste', (tester) async {
      await _lancer(tester);
      final etat = Etat.instance;
      expect(etat.typesMesure, isEmpty, reason: 'données d\'essai : comme sur l\'appareil de M. Bezard');
      etat.formatsAppliques = true;
      await etat.reparerTypesMesure(
          catalogue: jsonDecode(File('assets/catalogue_type.json').readAsStringSync()) as Map<String, dynamic>);
      expect(etat.typesMesure.length, greaterThan(5), reason: 'les types de mesure reviennent du catalogue');
      final avecFormat = etat.produits.where((p) => p.packagingIds.isNotEmpty).length;
      final s = etat.secteurCatalogue(etat.produits.first.id)!;
      final p = etat.enregistrerProduitAjoute(libelle: 'Camembert', marqueNom: 'Président', secteur: s);
      expect(p.nom, 'Camembert Président');
      expect(etat.produits.where((p) => p.packagingIds.isNotEmpty).length, avecFormat, reason: 'articles inchangés');
      etat.lireMarquesType({
        'secteurs': {etat.cleSecteur(s): ['Lactel', 'Candia']}
      });
      expect(etat.marquesDuSecteur(s), ['Candia', 'Lactel', 'Président'], reason: 'catalogue des marques et marques des produits');
      // En préparation : les marques du secteur de l'article
      expect(etat.marquesProposees(null, etat.produits.first), containsAll(['Candia', 'Lactel']));

      await _rubrique(tester, 'Catalogue des marques');
      expect(find.text('Produits réels'), findsNothing);
      expect(find.text('Lactel'), findsNothing, reason: 'rayons repliés au départ');
      await _toucher(tester, find.byTooltip('Tout déplier'));
      expect(find.byTooltip('Tout replier'), findsOneWidget);
      // Les secteurs sans marque ne paraissent pas ; sous le secteur, ses marques puis « + Nouvelle marque »
      expect(find.byKey(ValueKey('secteur-marques-${s.nom}')), findsOneWidget);
      expect(find.text('Lactel'), findsOneWidget);
      expect(find.text('1 produit'), findsOneWidget, reason: 'Président porte Camembert Président');
      await _toucher(tester, find.byKey(const ValueKey('marque-Président')));
      expect(find.text('Modifier la marque'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('marque-libelle')), 'Président Fin');
      await _toucher(tester, find.text('Valider'));
      expect(p.nom, 'Camembert Président Fin');
      expect(etat.marquesDuSecteur(s), ['Candia', 'Lactel', 'Président Fin']);
      // La poubelle retire la marque du secteur
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await _voir(tester, find.byKey(const ValueKey('marque-Candia')));
      await _toucher(tester, find.descendant(of: find.byKey(const ValueKey('marque-Candia')), matching: find.byIcon(Icons.delete_outline)));
      expect(find.text('Candia'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await _toucher(tester, find.byKey(ValueKey('nouvelle-marque-${s.nom}')));
      expect(find.text('Nouvelle marque'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('marque-libelle')), 'Candia');
      await _toucher(tester, find.text('Valider'));
      expect(etat.marquesDuSecteur(s), ['Candia', 'Lactel', 'Président Fin']);
      await _ciblesTactiles(tester);
      await _rubrique(tester, 'Types de mesure');
      await _toucher(tester, find.text(etat.packaging(etat.typesMesure.first)!.libelle));
      expect(find.text('Fusionner avec un autre'), findsOneWidget);
      await _fermerVolet(tester);
      await _ciblesTactiles(tester);
    });

    testWidgets('Gérer › Paramètres › Synchronisation : état, serveur imposé caché sous « Avancé »', (tester) async {
      await _lancer(tester);
      await _rubrique(tester, 'Synchronisation');
      expect(find.text('Le code de partage et les membres sont dans Gérer › Foyer.'), findsOneWidget);
      expect(find.text('Partager ce foyer'), findsNothing);
      expect(find.byKey(const ValueKey('mqtt-hote')), findsNothing, reason: 'serveur dans un volet');
      await _actionTitre(tester, 'Avancé : serveur');
      final hote = tester.widget<TextField>(find.byKey(const ValueKey('mqtt-hote')));
      expect(hote.controller!.text, ServeurMqtt.hoteDefaut);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('mqtt-port'))).controller!.text, '8883');
      await _ciblesTactiles(tester);
    });

    testWidgets('Gérer › Foyer : passer en foyer ouvre le choix seul, créer, rejoindre', (tester) async {
      await _lancer(tester);
      await _rubrique(tester, 'Foyer');
      expect(find.text('Seul sur cet appareil'), findsOneWidget, reason: 'seul : ni membres ni code');
      expect(find.text('MEMBRES'), findsNothing);
      // Choisir son nom dans la liste des membres (après avoir rejoint, ou appareil partagé)
      final etat = Etat.instance;
      final autre = etat.membresVisibles.firstWhere((m) => !m.moi);
      final avant = etat.moi;
      choisirPersonne(tester.element(find.text('Seul sur cet appareil')));
      await tester.pumpAndSettle();
      expect(find.text('Qui utilise cet appareil ?'), findsOneWidget);
      await _toucher(tester, find.byKey(ValueKey('personne-${autre.nomAffiche}')));
      expect(etat.moi.id, autre.id);
      etat.devenir(avant);
      await tester.pumpAndSettle();
      await _actionTitre(tester, 'Passer en foyer');
      expect(find.text('Comment utilisez-vous l\'application ?'), findsOneWidget);
      expect(find.text('Seul, sur cet appareil'), findsOneWidget);
      expect(find.byKey(const ValueKey('bienvenue-nom-foyer')), findsNothing);
      await _toucher(tester, find.text('Créer un foyer'));
      expect(find.byKey(const ValueKey('bienvenue-nom-foyer')), findsOneWidget);
      expect(find.text('Créer le foyer'), findsOneWidget);
      await _toucher(tester, find.text('Rejoindre un foyer'));
      expect(find.byKey(const ValueKey('bienvenue-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('bienvenue-nom-foyer')), findsNothing);
      await _ciblesTactiles(tester);
    });

    testWidgets('éditeur du catalogue commun : rayons, secteurs, ajout depuis un texte', (tester) async {
      await _lancer(tester);
      await _rubrique(tester, 'Foyer');
      Nav.aller<void>(tester.element(find.text('Seul sur cet appareil')), const EcranEditeurCatalogue());
      await tester.pump();
      // Le catalogue livré se lit vraiment (fichier de l'application) : on lui laisse le temps.
      for (var i = 0; i < 20 && find.textContaining('Jamais publié').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Jamais publié'), findsOneWidget);
      expect(find.text('FRUITS ET LÉGUMES'), findsOneWidget);
      await _actionTitre(tester, 'Ajouter depuis un texte');
      await tester.enterText(find.byKey(const ValueKey('editeur-texte')), 'Animalerie / Chats :\nCroquettes\nLitière');
      await _toucher(tester, find.text('Lire le texte'));
      expect(find.text('Animalerie › Chats (nouveau rayon)'), findsOneWidget);
      await _toucher(tester, find.text('Ajouter au brouillon'));
      expect(find.textContaining('modifications à publier'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ANIMALERIE'), 300,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first);
      expect(find.text('ANIMALERIE'), findsOneWidget);
      await _ciblesTactiles(tester);
    });

    testWidgets('membres : renommer, retirer du foyer (marque, pas d\'effacement)', (tester) async {
      await _lancer(tester);
      final etat = Etat.instance;
      final autre = etat.ajouterMembre('Zoé', '');
      final n = etat.membres.length;
      etat.renommerMembre(autre, 'Zoé B');
      expect(autre.nomAffiche, 'Zoé B');
      expect(etat.membresVisibles, contains(autre));
      etat.supprimerMembre(autre);
      expect(etat.membresVisibles, isNot(contains(autre)));
      expect(etat.membres.length, n, reason: 'le membre reste pour ses listes et ses courses');
      expect(etat.moiExclu, isFalse);
    });

    testWidgets('catalogue : rayon et secteur ajoutés dans tous les magasins, marqués, supprimables vides', (tester) async {
      await _lancer(tester);
      final etat = Etat.instance;
      final r = etat.ajouterRayonCatalogue('Animalerie')!;
      for (final m in etat.magasins) {
        expect(etat.rayons.where((x) => x.magasinId == m.id && x.nom == 'Animalerie'), hasLength(1));
      }
      expect(etat.rayonAjoute(r), isTrue);
      expect(etat.ajouterRayonCatalogue('animalerie'), isNull, reason: 'déjà là');
      final s = etat.ajouterSecteurCatalogue(r, 'Chats')!;
      expect(etat.secteurAjoute(s), isTrue);
      expect(etat.secteursDu(r.id).map((x) => x.nom), containsAll(['Animalerie', 'Chats']));
      etat.renommerSecteurCatalogue(s, 'Chats et chiens');
      expect(etat.secteursDu(r.id).map((x) => x.nom), contains('Chats et chiens'));
      final origine = etat.rayonsCatalogue.firstWhere((x) => !etat.rayonAjoute(x));
      expect(etat.supprimerRayonCatalogue(origine), isFalse, reason: 'rayon d\'origine');
      expect(etat.supprimerRayonCatalogue(etat.rayonsCatalogue.firstWhere((x) => x.nom == 'Animalerie')), isTrue);
      expect(etat.rayons.where((x) => x.nom == 'Animalerie'), isEmpty);
      expect(etat.structurePerso, isEmpty);
    });

    testWidgets('le nuage montre seulement l\'état : voyant, sa signification, appareils', (tester) async {
      await _accueil(tester);
      await _toucher(tester, find.byIcon(Icons.cloud_outlined).first);
      expect(find.text('Synchronisation'), findsOneWidget);
      expect(find.text('Foyer non partagé'), findsOneWidget);
      expect(find.text('Signification du voyant'), findsOneWidget);
      expect(find.text('Rouge : pas de connexion au serveur MQTT ou pas de réseau'), findsOneWidget);
      expect(find.text('Avancé : serveur'), findsNothing);
    });
  });

  group('Ordre des secteurs', () {
    setUp(_donnees);

    testWidgets('catalogue du foyer : le bandeau du rayon propose de changer l\'ordre, dans tous les magasins', (tester) async {
      await _accueil(tester);
      await _rubrique(tester, 'Catalogue');
      final etat = Etat.instance;
      final frais = etat.rayonsCatalogue.firstWhere((r) => r.nom == 'Frais');
      final avant = [for (final s in etat.secteursDu(frais.id)) s.nom];
      await _toucher(tester, find.text('FRAIS'));
      await _toucher(tester, find.text('Changer l\'ordre des secteurs'));
      // Le dernier secteur glisse tout en haut
      final dernier = avant.last;
      final poignee = find.byKey(ValueKey('poignee-$dernier'));
      final haut = tester.getCenter(find.byKey(ValueKey('poignee-${avant.first}')));
      final g = await tester.startGesture(tester.getCenter(poignee));
      await tester.pump(const Duration(milliseconds: 100));
      for (var y = tester.getCenter(poignee).dy; y > haut.dy - 40; y -= 20) {
        await g.moveTo(Offset(haut.dx, y));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await g.up();
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('Valider'));
      expect([for (final s in etat.secteursDu(frais.id)) s.nom], [dernier, ...avant.take(avant.length - 1)]);
      for (final r in etat.rayons.where((r) => r.nom == 'Frais')) {
        expect(etat.secteursDu(r.id).first.nom, dernier);
      }
    });

    test('catalogue commun : le brouillon garde le nouvel ordre et compte une modification', () {
      final b = Brouillon.lire({'rayons': [
        {'nom': 'Frais', 'secteurs': [
          {'nom': 'A', 'taille': 1, 'produits': []},
          {'nom': 'B', 'taille': 1, 'produits': []},
          {'nom': 'C', 'taille': 1, 'produits': []},
        ]},
      ]});
      final r = b.catalogue.rayons.first;
      b.ordonnerSecteurs(r, ['C', 'A', 'B']);
      expect([for (final s in r.secteurs) s.nom], ['C', 'A', 'B']);
      expect(b.modifications, 1);
      b.ordonnerSecteurs(r, ['C', 'A', 'B']);
      expect(b.modifications, 1);
    });
  });
}
