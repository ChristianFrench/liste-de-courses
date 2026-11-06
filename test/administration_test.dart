// Console d'administration (application Windows, fenêtre large) : menu des fonctions, catalogue des produits
// (vue du téléphone à gauche, maintenance à droite). Avec APERCU=1, enregistre aussi des captures
// (test/apercus/administration/*.png) pour les montrer avant de compiler.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/ecrans/administration.dart';
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';
import 'package:liste_de_courses/ecrans/outil_editeur.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/navigation.dart';

final bool _apercu = Platform.environment['APERCU'] == '1';
final _cle = GlobalKey();

Future<void> _police(String famille, List<String> fichiers) async {
  final loader = FontLoader(famille);
  for (final f in fichiers) {
    final fichier = File(f);
    if (fichier.existsSync()) loader.addFont(Future.value(ByteData.sublistView(fichier.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _capture(String nom) async {
  if (_apercu) await expectLater(find.byKey(_cle), matchesGoldenFile('apercus/administration/$nom.png'));
}

void main() {
  setUpAll(() async {
    await _police('Atkinson', ['assets/polices/AtkinsonHyperlegible-Regular.ttf', 'assets/polices/AtkinsonHyperlegible-Bold.ttf']);
    await _police('MaterialIcons', ['${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('console : menu des fonctions, catalogue des produits en deux parties', (tester) async {
    final e = Etat.instance;
    e.enregistrementActif = false;
    e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    Nav.i.reinitialiser();
    EcranEditeurCatalogue.actualiserAuServeur = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp(accueil: ConsoleAdministration())));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(ConsoleAdministration));
      await precacheImage(const AssetImage('assets/emplettes/complet.png'), ctx);
      for (final f in Directory('assets/icones/noto3d').listSync().whereType<File>()) {
        await precacheImage(AssetImage(f.path), ctx);
      }
    });
    // Le catalogue livré se lit vraiment (fichier de l'application) : on lui laisse le temps.
    for (var i = 0; i < 30 && find.textContaining('Aucune version publiée').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Catalogue des produits'), findsWidgets);
    expect(find.text('FRUITS ET LÉGUMES'), findsOneWidget, reason: 'la vue du téléphone, à gauche');
    expect(find.byKey(const ValueKey('maintenance-repartir')), findsOneWidget, reason: 'les actions, à droite');
    expect(find.byKey(const ValueKey('generaliser')), findsOneWidget);
    await _capture('2-Catalogue-des-produits');

    // Une action de droite s'ouvre (nouveau rayon) et modifie la vue de gauche
    await tester.tap(find.byKey(const ValueKey('maintenance-rayon')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Animalerie');
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 modification à généraliser'), findsOneWidget);
    expect(find.text('Rayons ajoutés (1)'), findsOneWidget, reason: 'le récapitulatif suit le brouillon');
    await _capture('3-Catalogue-modifie');

    for (final (r, nom) in [
      (Rubrique.ressources, '4-Ressources-techniques'),
      (Rubrique.utilisateurs, '5-Utilisateurs'),
      (Rubrique.marques, '6-Catalogue-des-marques'),
      (Rubrique.apparence, '7-Apparence'),
    ]) {
      await tester.tap(find.byKey(ValueKey('rubrique-${r.name}')));
      await tester.pumpAndSettle();
      await _capture(nom);
    }
    expect(find.text('Palette de la console'), findsOneWidget);
  });

  testWidgets('console : connexion par le code secret', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp(accueil: EcranOutilEditeur())));
    await tester.runAsync(() => precacheImage(const AssetImage('assets/emplettes/complet.png'), tester.element(find.byType(EcranOutilEditeur))));
    await tester.pumpAndSettle();
    expect(find.text('Code secret'), findsOneWidget);
    await _capture('1-Connexion');
  });
}
