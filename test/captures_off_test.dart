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
    final rep = await (await client.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 10));
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
    PhotoArticle.fournisseur = (url) => _photos.containsKey(url) ? MemoryImage(_photos[url]!) : const AssetImage('assets/icone_ronde.png');
    await _police('Atkinson', [
      'assets/polices/AtkinsonHyperlegible-Regular.ttf',
      'assets/polices/AtkinsonHyperlegible-Bold.ttf',
    ]);
    final racine = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _police('MaterialIcons', ['$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    Etat.instance.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
  });

  testWidgets('13 produits reels', (tester) async {
    final r = (await tester.runAsync(() => OpenFoodFacts.instance.rechercher('lait demi écrémé')))!;
    File('test/captures/off_recherche.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(r.map((a) => '${a.code} | ${a.nom} | ${a.marque} | ${a.quantite} | ${a.nutriscore} | ${a.imagePetite}').join('\n'));
    await _afficher(tester,
        EcranProduitsReels(rechercheInitiale: 'Lait demi-écrémé', resultatsInitiaux: r), [for (final a in r.take(10)) a.imagePetite]);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13 produits reels.png'));

    final a = r.firstWhere((x) => ean13Valide(x.code) && x.marqueTag != null, orElse: () => r.first);
    await _afficher(tester, EcranArticle(article: a), [a.imageGrande, a.imagePetite]);
    await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13b fiche article.png'));

    if (a.marqueTag != null) {
      final m = (await tester.runAsync(() => OpenFoodFacts.instance.parMarque(a.marqueTag!)))!;
      await _afficher(tester, EcranMarque(marque: a.marque, marqueTag: a.marqueTag!, initial: m),
          [for (final x in m.$2.take(10)) x.imagePetite]);
      await expectLater(find.byKey(_cle), matchesGoldenFile('captures/13c marque.png'));
    }
  }, skip: !_actif, timeout: const Timeout(Duration(minutes: 4)));
}
