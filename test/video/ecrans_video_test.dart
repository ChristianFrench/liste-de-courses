// Écrans du mini site et des documents (docs/ecrans), pris dans le foyer de démonstration (Famille Martin).
// À la demande : ECRANS=1 flutter test --update-goldens test/site/ecrans_site_test.dart
// (les images vont dans test/site/ecrans ; outils/site/ecrans.py les convertit pour docs/ecrans).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/demonstration.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/synchro.dart';
import 'dart:async';

import 'package:liste_de_courses/ecrans/travail.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/navigation.dart';

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

Future<void> _capture(String nom) => expectLater(find.byKey(_cle), matchesGoldenFile('ecrans/$nom.png'));

Future<void> _toucher(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final liste = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical).first;
    try {
      await tester.scrollUntilVisible(f, 150, scrollable: liste);
    } on StateError {
      await tester.scrollUntilVisible(f, -150, scrollable: liste);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 310));
  await tester.pumpAndSettle();
}

Finder _onglet(String l) => find.descendant(of: find.byType(BarreOnglets), matching: find.text(l));

/// Essaie une suite de gestes ; si un élément manque, l'écran est sauté.
Future<void> _essayer(String nom, Future<void> Function() gestes) async {
  try {
    await gestes();
  } catch (e, pile) {
    debugPrint('Écran « $nom » sauté : $e\n${pile.toString().split('\n').where((l) => l.contains('ecrans_video_test')).take(2).join('\n')}');
  }
}


void main() {
  final actif = Platform.environment['VIDEO'] == '1';
  if (!actif) {
    test('écrans de la vidéo (VIDEO=1)', () {}, skip: true);
    return;
  }
  setUpAll(() async {
    await _police('Atkinson', ['assets/polices/AtkinsonHyperlegible-Regular.ttf', 'assets/polices/AtkinsonHyperlegible-Bold.ttf']);
    final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('écrans de la vidéo', (tester) async {
    final e = Etat.instance;
    await tester.runAsync(() async {
      final dossier = Directory.systemTemp.createTempSync('ecrans_video');
      await e.charger(dossier: dossier);
      await e.chargerMarquesType();
      await e.ajouterMagasinsEnseignes();
      e.remplirDemonstration();
      await Synchro.instance.choisirSeul();
    });
    e.enregistrementActif = false;
    // La vidéo ajoute elle-même le camembert (Thomas) et les yaourts (Claire).
    final semaine = e.listes.firstWhere((l) => l.nom == 'Courses de la semaine');
    String nomDe(LigneListe g) => e.produit(g.produitId)?.nom ?? '';
    final yaourts = semaine.lignes.firstWhere((g) => nomDe(g) == 'Yaourts nature');
    semaine.lignes.removeWhere((g) => nomDe(g) == 'Camembert' || nomDe(g) == 'Yaourts nature');
    Nav.i.reinitialiser();

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp()));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold).first);
      // 10/11/2026 : toutes les images (pictos maison, symboles, images d'Emplettes, fonds), sinon certaines manquent sur les écrans.
      for (final f in Directory('assets').listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.png') || f.path.endsWith('.jpg')) await precacheImage(AssetImage(f.path), ctx, onError: (_, __) {});
      }
    });
    await tester.pumpAndSettle();

    await _capture('v01 Accueil');
    await _essayer('Nouvelle liste', () async {
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('Nouvelle liste'));
      await _capture('v02 Nouvelle-liste');
      await _toucher(tester, find.byTooltip('Retour'));
    });
    await _essayer('Remplir', () async {
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('Courses de la semaine').first);
      await _toucher(tester, find.text('Continuer la préparation').last);
      await _capture('v03 Remplir');
      for (final t in ['c', 'ca', 'cam']) {
        await tester.enterText(find.byType(TextField).first, t);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await _capture('v03 Recherche-$t');
      }
      await _toucher(tester, find.text('Camembert').first);
      await _capture('v04 Promo-proposee');
      await _essayer('Sans promo', () => _toucher(tester, find.text('Sans promo')));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _capture('v04 Camembert-range');
      await _essayer('Article', () async {
        await _toucher(tester, find.textContaining('Camembert', findRichText: true).first);
        await _capture('v05 Article');
        await tester.tapAt(const Offset(195, 20));
        await tester.pumpAndSettle();
      });
      // Claire ajoute les yaourts depuis son téléphone.
      semaine.lignes.add(yaourts);
      e.modifie();
      await tester.pumpAndSettle();
      await _capture('v07 Yaourts-arrives');
      await _essayer('Liste prête', () async {
        await _toucher(tester, find.text('Liste prête'));
        await _capture('v08 Liste-prete');
        await _toucher(tester, find.text('Continuer la préparation'));
      });
      await _toucher(tester, find.byTooltip('Retour'));
    });
    await _essayer('Courses', () async {
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, _onglet('Courses'));
      await _capture('v12 Courses-suivi');
      await _essayer('Partir', () async {
        await _toucher(tester, find.text('Anniversaire de Léa').first);
        await _toucher(tester, find.text('Faire les courses').last);
        await _essayer('Thomas', () async {
          await _toucher(tester, find.text('Claire (moi)').last);
          await _toucher(tester, find.text('Thomas').last);
        });
        await _capture('v09 Partir');
        await _toucher(tester, find.text('Annuler'));
      });
      await _toucher(tester, find.text('Dépannage').first);
      await _toucher(tester, find.text('Reprendre les courses'));
      await _capture('v10 En-magasin');
      await _essayer('Terminer', () async {
        await _toucher(tester, find.text('Terminer'));
        await _capture('v13 Terminer');
        await _toucher(tester, find.text('Continuer les courses'));
      });
      // Un appui coche, deux appuis : manquant.
      final articles = find.byType(LigneArticle);
      if (articles.evaluate().isNotEmpty) {
        await tester.tap(articles.at(2));
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pumpAndSettle();
        await _capture('v10 En-magasin-coche');
        await tester.tap(articles.at(3));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(articles.at(3));
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pumpAndSettle();
        await _capture('v11 Manquant');
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      }
      await _toucher(tester, find.text('Pause'));
      await _toucher(tester, find.text('Interrompre'));
    });
    await _essayer('Depuis une course passée', () async {
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, _onglet('Préparer'));
      await _toucher(tester, find.text('Nouvelle liste'));
      await _toucher(tester, find.text('Depuis une course passée'));
      await _capture('v14 Course-passee');
      await _toucher(tester, find.byTooltip('Retour'));
      await _toucher(tester, find.text('Depuis une liste type'));
      await _capture('v15 Listes-types');
      await _toucher(tester, find.byTooltip('Retour'));
      await _toucher(tester, find.byTooltip('Retour'));
    });
    await _essayer('Parcours', () async {
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, find.text('Magasins'));
      await _capture('v16 Magasins');
      await _toucher(tester, find.textContaining('Intermarché').first);
      await _capture('v16 Magasin');
      await _essayer('Parcours du magasin', () async {
        await _toucher(tester, find.textContaining('Parcours').first);
        await _capture('v16 Parcours');
      });
    });
    await _essayer('Catalogue', () async {
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, find.text('Catalogue des produits'));
      await _toucher(tester, find.text('Fruits et légumes').first);
      await _capture('v18 Catalogue');
    });
    await _essayer('Nouveautés', () async {
      await _toucher(tester, _onglet('Accueil'));
      await _toucher(tester, _onglet('Accueil'));
      e.numeroCatalogueCommun = 2;
      e.nouveautesCatalogue = {
        'version': 2,
        'lignes': ['32 rayons, 214 secteurs, 2 263 produits', '57 modifications sur 2 263 produits'],
        'total': 2
      };
      final ctx = tester.element(find.byType(Scaffold).first);
      unawaited(montrerNouveautes(ctx));
      await tester.pumpAndSettle();
      await _capture('v19 Nouveautes');
      await _toucher(tester, find.text('Fermer'));
    });
    await _essayer('Foyer', () async {
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, _onglet('Gérer'));
      await _toucher(tester, find.text('Foyer'));
      await _capture('v20 Foyer');
    });
  });
}
