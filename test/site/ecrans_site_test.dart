// Écrans du mini site et des documents (docs/ecrans), pris dans le foyer de démonstration (Famille Martin).
// À la demande : ECRANS=1 flutter test --update-goldens test/site/ecrans_site_test.dart
// (les images vont dans test/site/ecrans ; outils/site/ecrans.py les convertit pour docs/ecrans).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/demonstration.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/pictos.dart';
import 'package:liste_de_courses/donnees/synchro.dart';
import 'package:liste_de_courses/ecrans/coquille.dart';
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
  } catch (e) {
    debugPrint('Écran « $nom » sauté : $e');
  }
}

void main() {
  final actif = Platform.environment['ECRANS'] == '1';
  if (!actif) {
    test('écrans du site (ECRANS=1)', () {}, skip: true);
    return;
  }
  setUpAll(() async {
    await _police('Atkinson', ['assets/polices/AtkinsonHyperlegible-Regular.ttf', 'assets/polices/AtkinsonHyperlegible-Bold.ttf']);
    final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('écrans de la démonstration', (tester) async {
    final e = Etat.instance;
    await tester.runAsync(() async {
      final dossier = Directory.systemTemp.createTempSync('ecrans_site');
      await e.charger(dossier: dossier);
      await e.chargerMarquesType();
      await e.ajouterMagasinsEnseignes();
      e.remplirDemonstration();
      await Synchro.instance.choisirSeul();
    });
    e.enregistrementActif = false;
    Nav.i.reinitialiser();

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp()));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold).first);
      for (final f in ['icone_ronde', 'accueil_photo', 'emplettes/complet', 'emplettes/liste_crayon', 'emplettes/liste_chariot', 'emplettes/filtre']) {
        await precacheImage(AssetImage('assets/$f.${f == 'accueil_photo' ? 'jpg' : 'png'}'), ctx);
      }
      for (final c in pictosDisponibles) {
        await precacheImage(AssetImage('assets/pictos/png/$c.png'), ctx);
      }
      for (final f in Directory('assets/icones/noto3d').listSync().whereType<File>()) {
        await precacheImage(AssetImage(f.path), ctx);
      }
    });
    await tester.pumpAndSettle();

    await _capture('01 Accueil');
    await _essayer('Préparer', () async {
      await _toucher(tester, _onglet('Préparer'));
      await _capture('02 Preparer');
    });
    await _essayer('Nouvelle liste', () async {
      await _toucher(tester, find.text('Nouvelle liste'));
      await _capture('03 Nouvelle-liste');
      await _toucher(tester, find.byTooltip('Retour'));
    });
    await _essayer('Remplir la liste', () async {
      await _toucher(tester, find.text('Courses de la semaine').first);
      await _capture('04 Volet-liste');
      await _toucher(tester, find.text('Continuer la préparation').last);
      await _capture('05 Remplir');
      await _essayer('Article', () async {
        await _toucher(tester, find.textContaining('Bananes', findRichText: true).first);
        await _capture('06 Article');
        await tester.tapAt(const Offset(195, 20));
        await tester.pumpAndSettle();
      });
      await _essayer('Liste prête', () async {
        await _toucher(tester, find.text('Liste prête'));
        await _capture('06 Liste-prete');
        await _toucher(tester, find.text('Continuer la préparation'));
      });
      await _toucher(tester, find.byTooltip('Retour'));
    });
    await _essayer('Courses', () async {
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, _onglet('Courses'));
      await _capture('07 Courses');
      await _essayer('Partir', () async {
        await _toucher(tester, find.text('Anniversaire de Léa').first);
        await _toucher(tester, find.text('Faire les courses').last);
        await _capture('07 Partir');
        await _toucher(tester, find.text('Annuler'));
      });
      await _toucher(tester, find.text('Dépannage').first);
      await _toucher(tester, find.text('Reprendre les courses'));
      await _capture('08 En-magasin');
      await _essayer('Terminer', () async {
        await _toucher(tester, find.text('Terminer'));
        await _capture('08 Terminer');
        await _toucher(tester, find.text('Continuer les courses'));
      });
      await _toucher(tester, find.text('Pause'));
      await _toucher(tester, find.text('Interrompre'));
    });
    await _essayer('Historique', () async {
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, _onglet('Courses'));
      await _toucher(tester, find.text('HISTORIQUE'));
      await _capture('09 Historique');
    });
    for (final (rubrique, nom) in [('Foyer', '10 Foyer'), ('Magasins', '11 Magasins'), ('Catalogue des produits', '12 Catalogue'), ('Catalogue des marques', '13 Marques'), ('Types de promotion', '14 Promotions'), ('Apparence', '15 Apparence'), ('Données', '16 Donnees'), ('Collaboration', '17 Collaboration')]) {
      await _essayer(rubrique, () async {
        await _toucher(tester, _onglet('Gérer'));
        await _toucher(tester, _onglet('Gérer'));
        if (nom == '10 Foyer') await _capture('10 Gerer');
        await _toucher(tester, find.text(rubrique));
        await _capture(nom);
      });
    }
  });
}
