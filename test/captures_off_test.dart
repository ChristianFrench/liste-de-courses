// Captures de l'écran d'essai « Produits réels » avec de VRAIES données
// Open Food Facts, interrogées depuis GitHub. Lancé seulement si CAPTURES=1 ;
// un échec (réseau, service indisponible) n'empêche pas la publication.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/code_barres.dart';
import 'package:liste_de_courses/donnees/catalogue_off.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/open_food_facts.dart';
import 'package:liste_de_courses/ecrans/e13_produits_reels.dart';
import 'package:liste_de_courses/main.dart';
import 'package:liste_de_courses/theme.dart';

final bool _actif = Platform.environment['CAPTURES'] == '1';
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

Future<void> _afficher(WidgetTester tester, Widget ecran, List<String> images) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
  tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _cle,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Charte.theme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, enfant) => FormatTelephone(child: enfant!),
      home: ecran,
    ),
  ));
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Navigator).first);
    for (final url in images.where((u) => u.isNotEmpty)) {
      try {
        await _telecharger(url);
        if (!_photos.containsKey(url)) continue;
        await precacheImage(PhotoArticle.fournisseur(url), ctx).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

final Map<String, Uint8List> _photos = {};

/// Télécharge une photo (10 s au plus) ; elle est ensuite servie depuis la mémoire.
Future<void> _telecharger(String url) async {
  if (_photos.containsKey(url)) return;
  final client = HttpClient()..userAgent = OpenFoodFacts.agent;
  try {
    final rep = await (await client.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 20));
    final octets = <int>[];
    await for (final morceau in rep.timeout(const Duration(seconds: 10))) {
      octets.addAll(morceau);
    }
    if (rep.statusCode == 200) _photos[url] = Uint8List.fromList(octets);
  } finally {
    client.close(force: true);
  }
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null; // accès réel au réseau pour ces captures
    PhotoArticle.fournisseur = (url) => MemoryImage(_photos[url] ?? Uint8List(0)); // photo absente : cadre « Photo indisponible »
    await _police('Atkinson', [
      'assets/polices/AtkinsonHyperlegible-Regular.ttf',
      'assets/polices/AtkinsonHyperlegible-Bold.ttf',
    ]);
    final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    Etat.instance.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
  });

  testWidgets('13 produits reels', (tester) async {
    final fichier = File('assets/catalogue/catalogue.json.gz');
    final c = CatalogueOff.instance;
    c.lireBase(jsonDecode(utf8.decode(gzip.decode(fichier.readAsBytesSync()))) as Map<String, dynamic>);
    c.charge = true;

    final r = c.rechercher('Pâtes');
    File('test/captures/catalogue_recherches.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync([
        for (final q in ['Pâtes', 'pâte à tartiner', 'Lait demi-écrémé', 'Café moulu', 'Yaourt nature', 'Beurre doux', 'Jambon', 'Panzani'])
          '== $q : ${c.rechercher(q).explication}\n${c.rechercher(q).articles.take(8).map((a) => '   ${a.code} | ${a.nom} | ${a.marque} | ${a.quantite}').join('\n')}'
      ].join('\n'));
    await _afficher(tester, EcranProduitsReels(rechercheInitiale: 'Pâtes', resultatsInitiaux: r.articles, explicationInitiale: r.explication),
        [for (final a in r.articles.take(8)) a.imagePetite]);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13 produits reels.png'));

    final a = r.articles.first;
    await _afficher(tester, EcranArticle(article: a), [a.imageGrande, a.imagePetite]);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13b fiche article.png'));

    final m = c.parMarque(a.marque);
    await _afficher(tester, EcranMarque(marque: a.marque), [for (final x in m.take(8)) x.imagePetite]);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13c marque.png'));

    await _afficher(tester, const EcranCatalogue(), const []);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13d catalogue.png'));
  }, skip: !_actif, timeout: const Timeout(Duration(minutes: 4)));
}
