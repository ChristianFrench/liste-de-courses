// Console d'administration (application Windows, fenêtre large) : menu des fonctions, catalogue des produits
// (vue du téléphone à gauche, maintenance à droite). Avec APERCU=1, enregistre aussi des captures
// (test/apercus/administration/*.png) pour les montrer avant de compiler.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:liste_de_courses/composants/composants.dart' show voletsEnFenetre;
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/serveur.dart';
import 'package:liste_de_courses/donnees/serveur_acces_io.dart' as io;
import 'package:liste_de_courses/ecrans/administration.dart';
import 'package:liste_de_courses/ecrans/administration_serveur.dart';
import 'package:liste_de_courses/ecrans/console_images.dart';
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
    // Captures : une police à chasse fixe à la place de Consolas (police de Windows)
    await _police('Consolas', ['/mnt/skills/examples/canvas-design/canvas-fonts/IBMPlexMono-Regular.ttf']);
    await _police('MaterialIcons', ['${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('console : menu des fonctions, catalogue des produits en deux parties', (tester) async {
    final e = Etat.instance;
    e.enregistrementActif = false;
    e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    Nav.i.reinitialiser();
    EcranEditeurCatalogue.actualiserAuServeur = false;
    PageSuivi.automatique = false;
    PageShell.ouvrirAuto = false;
    io.AccesServeur.dossierEssai = Directory.systemTemp.createTempSync('console').path;
    // Une lecture du suivi comme celle d'un serveur installé (sortie de la commande de suivi).
    Serveur.instance.dernierSuivi = Serveur.lireSuivi([
      'uptime=up 3 days, 4 hours', 'charge=0.08 0.05 0.01', 'coeurs=2', 'memoire=812/3911', 'disque=6120/39250',
      for (final x in Serveur.services) 'service.$x=active',
      'majs=3', 'redemarrage=non', 'installe=oui',
      'certificat.emplettes.eu=Feb  4 09:12:00 2027 GMT', 'certificat.mqtt.emplettes.eu=Feb  4 09:12:01 2027 GMT',
      'certificat.ntfy.emplettes.eu=Feb  4 09:12:02 2027 GMT',
      'clients_mqtt=5', 'clients_web=1', 'sauvegarde=emplettes-2026-11-06.tar.gz', 'bannis=2',
    ].join('\n'));
    Serveur.instance.suiviLe = DateTime(2026, 11, 6, 10, 5);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(key: _cle, child: const ListeDeCoursesApp(accueil: ConsoleAdministration())));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(ConsoleAdministration));
      await precacheImage(const AssetImage('assets/emplettes/complet.png'), ctx);
      for (final f in [...Directory('assets/icones/noto3d').listSync(), ...Directory('assets/pictos/noto3d').listSync()].whereType<File>()) {
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
    voletsEnFenetre = true;
    expect(find.text('Fruits et légumes'), findsOneWidget, reason: 'le cadre du catalogue');
    expect(find.text('Catalogue commun'), findsOneWidget, reason: 'le titre commun');
    // 07/11/2026 (2e version) : un seul cadre ; rayon puis secteur dépliés, les produits dessous.
    await tester.tap(find.byKey(const ValueKey('console-rayon-Fruits et légumes')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('console-secteur-Fruits et légumes/Fruits')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Abricots'), findsOneWidget);
    await _capture('2-Catalogue-des-produits');

    // Clic droit sur un produit : son menu ; renommer sur place.
    await tester.tap(find.byKey(const ValueKey('console-produit-Fruits/Abricots')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Retirer le produit (Suppr)'), findsOneWidget);
    expect(find.text('Nouveau rayon…'), findsNothing); // un seul menu, pas celui du cadre par-dessus
    await _capture('2a-Menu-produit');
    await tester.tap(find.text('Renommer (F2)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('renommage')), 'Abricots secs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Abricots secs'), findsOneWidget);
    expect(find.byKey(const ValueKey('pastille-en-cours')), findsOneWidget);

    // Glisser un produit sur un autre secteur : il y est déplacé.
    await tester.tap(find.byKey(const ValueKey('console-secteur-Fruits et légumes/Fruits')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('console-secteur-Fruits et légumes/Fruits secs et graines')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final source = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('console-produit-Fruits secs et graines/')).first;
    final nom = (tester.widget(source).key as ValueKey<String>).value.split('/').last;
    final g = await tester.startGesture(tester.getCenter(source));
    await g.moveBy(const Offset(0, -20));
    await tester.pump();
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('console-secteur-Fruits et légumes/Légumes'))));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('console-produit-Légumes/$nom')), findsOneWidget, reason: 'déplacé à la souris');

    // Le menu ☰ : historique en fenêtre, iconographie en fenêtre, valider avec confirmation.
    await tester.tap(find.byKey(const ValueKey('console-menu')));
    await tester.pumpAndSettle();
    await _capture('2b-Menu-general');
    await tester.tap(find.textContaining('Iconographie…').last);
    await tester.pumpAndSettle();
    expect(find.text('Iconographie des rayons et secteurs'), findsOneWidget);
    await _capture('2c-Iconographie');
    await tester.tap(find.byKey(const ValueKey('icono-fermer')));
    await tester.pumpAndSettle();

    // Images ajoutées : une image collée, mise à la taille, avec son texte.
    lirePressePapiersImage = () async => File('assets/icone.png').readAsBytesSync();
    await tester.tap(find.byKey(const ValueKey('console-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Images ajoutées').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('images-ajouter')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('image-coller')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('image-texte')), 'Panier Emplettes');
    await tester.pumpAndSettle();
    await _capture('2e-Ajout-image');
    await tester.tap(find.byKey(const ValueKey('image-ajouter')));
    await tester.pumpAndSettle();
    expect(find.text('Panier Emplettes'), findsOneWidget);
    await _capture('2f-Images-ajoutees');
    await tester.tap(find.byKey(const ValueKey('images-fermer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('console-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Valider les modifications').last);
    await tester.pumpAndSettle();
    await _capture('2d-Valider');
    await tester.tap(find.text('Valider').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('console-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historique…'));
    await tester.pumpAndSettle();
    expect(find.text('Historique des modifications'), findsOneWidget);
    await _capture('3-Historique');
    await tester.tap(find.byKey(const ValueKey('historique-fermer')));
    await tester.pumpAndSettle();

    // Barre latérale repliée
    await tester.tap(find.byKey(const ValueKey('menu-replier')));
    await tester.pumpAndSettle();
    await _capture('3b-Menu-replie');
    await tester.tap(find.byKey(const ValueKey('menu-replier')));
    await tester.pumpAndSettle();

    for (final (r, nom) in [
      (Rubrique.initialisation, '4-Initialisation'),
      (Rubrique.suivi, '4b-Suivi-technique'),
      (Rubrique.shell, '4c-Console-shell'),
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

