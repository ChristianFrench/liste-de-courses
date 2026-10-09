import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'open_food_facts.dart';

/// Décompresse et lit un fichier du catalogue (exécuté hors de l'interface).
Map<String, dynamic> _decoder(Uint8List octets) =>
    jsonDecode(utf8.decode(gzip.decode(octets))) as Map<String, dynamic>;

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', 'ñ': 'n',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Clé de recherche : minuscules, sans accents, mots au singulier.
String cleRecherche(String texte) {
  final b = StringBuffer();
  for (final c in texte.toLowerCase().split('')) {
    b.write(_accents[c] ?? c);
  }
  final mots = b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(' ')
      .where((m) => m.isNotEmpty)
      .map((m) => m.length > 3 && (m.endsWith('s') || m.endsWith('x')) ? m.substring(0, m.length - 1) : m);
  return mots.join(' ');
}

/// Résultat d'une recherche dans le catalogue.
class ResultatRecherche {
  ResultatRecherche(this.articles, this.explication);
  final List<ArticleOff> articles;
  final String explication;
}

/// Catalogue Open Food Facts gardé sur l'appareil : recherche sans réseau,
/// mise à jour automatique selon un délai réglable.
class CatalogueOff extends ChangeNotifier {
  CatalogueOff._();
  static final CatalogueOff instance = CatalogueOff._();

  static const String page = 'https://github.com/ChristianFrench/liste-de-courses/releases/download/catalogue-off';
  static const String photos = 'https://images.openfoodfacts.org/images/products/';
  static const String assetBase = 'assets/catalogue/catalogue.json.gz';
  static const List<int> delais = [1, 7, 30, 0]; // jours ; 0 = manuel
  static const int delaiParDefaut = 7;

  // Contenu
  List<List<String>> _categories = []; // [tag, nom, synonymes…]
  List<Set<String>> _clesCategories = [];
  final Map<String, List<dynamic>> _produits = {};
  final Map<String, String> _clesNoms = {};
  String baseVersion = '';
  String baseDate = '';
  int majJusqua = 0;
  int nbMaj = 0;

  // Réglages et état
  int delaiJours = delaiParDefaut;
  DateTime? derniereVerification;
  bool enCours = false;
  bool charge = false;
  String? message;
  Timer? _minuterie;

  int get nbProduits => _produits.length;
  bool get vide => _produits.isEmpty;
  String get majDate => majJusqua == 0 ? '' : _jjmmaaaa(DateTime.fromMillisecondsSinceEpoch(majJusqua * 1000));

  static String _jjmmaaaa(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String dateHeure(DateTime d) =>
      '${_jjmmaaaa(d)} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ Démarrage

  /// Charge le catalogue, puis vérifie les mises à jour au démarrage
  /// et toutes les heures tant que l'application est ouverte.
  Future<void> demarrer() async {
    await charger();
    unawaited(verifier());
    final enTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!enTest) {
      _minuterie ??= Timer.periodic(const Duration(hours: 1), (_) => verifier());
    }
  }

  Future<Directory?> _dossier() async {
    try {
      final d = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}catalogue');
      if (!d.existsSync()) d.createSync(recursive: true);
      return d;
    } catch (_) {
      return null;
    }
  }

  File _fichier(Directory d, String nom) => File('${d.path}${Platform.pathSeparator}$nom');

  Future<void> charger() async {
    final d = await _dossier();
    // Réglages
    if (d != null) {
      try {
        final e = jsonDecode(_fichier(d, 'etat.json').readAsStringSync()) as Map<String, dynamic>;
        delaiJours = (e['delaiJours'] as num?)?.toInt() ?? delaiParDefaut;
        final v = e['derniereVerification'] as String?;
        derniereVerification = v == null ? null : DateTime.tryParse(v);
      } catch (_) {}
    }
    // Base : téléchargée, sinon celle livrée avec l'application
    Uint8List? octets;
    if (d != null && _fichier(d, 'catalogue.json.gz').existsSync()) {
      octets = _fichier(d, 'catalogue.json.gz').readAsBytesSync();
    } else {
      try {
        octets = (await rootBundle.load(assetBase)).buffer.asUint8List();
      } catch (_) {}
    }
    if (octets != null) {
      try {
        lireBase(await compute(_decoder, octets));
        if (d != null && _fichier(d, 'catalogue-maj.json.gz').existsSync()) {
          appliquerMaj(await compute(_decoder, _fichier(d, 'catalogue-maj.json.gz').readAsBytesSync()));
        }
      } catch (e) {
        message = 'Catalogue illisible : $e';
      }
    }
    charge = true;
    notifyListeners();
  }

  void lireBase(Map<String, dynamic> j) {
    _produits.clear();
    _clesNoms.clear();
    _categories = [];
    _clesCategories = [];
    _ajouterCategories(j['categories'] as List);
    for (final p in (j['produits'] as List)) {
      _ajouterProduit(p as List);
    }
    baseVersion = j['version'] as String? ?? '';
    baseDate = j['date'] as String? ?? '';
    majJusqua = (j['jusqua'] as num?)?.toInt() ?? 0;
    nbMaj = 0;
  }

  void appliquerMaj(Map<String, dynamic> j) {
    if (j['base'] != baseVersion) return;
    _ajouterCategories(j['categories'] as List);
    final produits = j['produits'] as List;
    for (final p in produits) {
      _ajouterProduit(p as List);
    }
    majJusqua = (j['jusqua'] as num?)?.toInt() ?? majJusqua;
    nbMaj = produits.length;
  }

  void _ajouterCategories(List liste) {
    for (final c in liste) {
      final noms = [for (final x in c as List) x as String];
      _categories.add(noms);
      _clesCategories.add({for (final n in noms.skip(1)) cleRecherche(n)});
    }
  }

  void _ajouterProduit(List p) {
    final code = p[0] as String;
    _produits[code] = p;
    _clesNoms[code] = cleRecherche('${p[1]} ${p[2]}');
  }

  ArticleOff _article(List p) {
    final photo = p[7] as String;
    final cats = <String>[];
    for (final i in (p[6] as List)) {
      final n = (i as num).toInt();
      if (n < _categories.length && _categories[n].length > 1) cats.add(_categories[n][1]);
    }
    final marque = p[2] as String;
    return ArticleOff(
      code: p[0] as String,
      nom: p[1] as String,
      nomGenerique: '',
      marques: marque.isEmpty ? [] : [marque],
      marquesTags: marque.isEmpty ? [] : [cleRecherche(marque)],
      quantite: p[3] as String,
      imagePetite: photo.isEmpty ? '' : '$photos$photo',
      imageGrande: photo.isEmpty ? '' : '$photos${photo.replaceAll('.200.jpg', '.400.jpg')}',
      nutriscore: p[4] as String,
      categories: cats,
      scans: (p[5] as num).toInt(),
    );
  }

  // ------------------------------------------------------------ Recherche

  /// 1. Le texte correspond exactement à une catégorie (ou à l'un de ses synonymes) :
  ///    tous les produits de cette catégorie, les plus populaires d'abord.
  ///    « pâtes » → « Pâtes alimentaires », sans les pâtes à tartiner.
  /// 2. Sinon : produits dont le nom ou la marque contient tous les mots.
  ResultatRecherche rechercher(String texte, {int maximum = 100}) {
    final cle = cleRecherche(texte);
    if (cle.isEmpty || vide) return ResultatRecherche([], '');
    final exactes = <int>{
      for (var i = 0; i < _clesCategories.length; i++)
        if (_clesCategories[i].contains(cle)) i
    };
    if (exactes.isNotEmpty) {
      final trouves = _produits.values
          .where((p) => (p[6] as List).any((i) => exactes.contains((i as num).toInt())))
          .toList()
        ..sort((a, b) => (b[5] as num).compareTo(a[5] as num));
      final noms = exactes.map((i) => _categories[i][1]).toSet().join(', ');
      return ResultatRecherche(
        [for (final p in trouves.take(maximum)) _article(p)],
        'Catégorie « $noms » : ${trouves.length} produit${trouves.length > 1 ? 's' : ''}',
      );
    }
    final mots = cle.split(' ');
    final trouves = <List<dynamic>>[];
    _clesNoms.forEach((code, nom) {
      final motsNom = nom.split(' ');
      if (mots.every((m) => motsNom.any((n) => n.startsWith(m)))) trouves.add(_produits[code]!);
    });
    trouves.sort((a, b) => (b[5] as num).compareTo(a[5] as num));
    return ResultatRecherche(
      [for (final p in trouves.take(maximum)) _article(p)],
      'Nom ou marque contenant « $texte » : ${trouves.length} produit${trouves.length > 1 ? 's' : ''}',
    );
  }

  ArticleOff? parCode(String code) {
    final p = _produits[code] ?? _produits[code.padLeft(13, '0')];
    return p == null ? null : _article(p);
  }

  /// Produits d'une marque présents dans le catalogue.
  List<ArticleOff> parMarque(String marque) {
    final cle = cleRecherche(marque);
    final l = _produits.values.where((p) => cleRecherche(p[2] as String) == cle).toList()
      ..sort((a, b) => (b[5] as num).compareTo(a[5] as num));
    return [for (final p in l) _article(p)];
  }

  // ------------------------------------------------------------ Mise à jour

  bool get aVerifier {
    if (delaiJours == 0) return false;
    final d = derniereVerification;
    return d == null || DateTime.now().difference(d) >= Duration(days: delaiJours);
  }

  Future<void> changerDelai(int jours) async {
    delaiJours = jours;
    await _enregistrerEtat();
    notifyListeners();
  }

  Future<void> _enregistrerEtat() async {
    final d = await _dossier();
    if (d == null) return;
    try {
      _fichier(d, 'etat.json').writeAsStringSync(jsonEncode({
        'delaiJours': delaiJours,
        'derniereVerification': derniereVerification?.toIso8601String(),
      }));
    } catch (_) {}
  }

  Future<Uint8List> _telecharger(String nom) async {
    final client = HttpClient()
      ..userAgent = OpenFoodFacts.agent
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final rep = await (await client.getUrl(Uri.parse('$page/$nom'))).close().timeout(const Duration(seconds: 30));
      if (rep.statusCode != 200) throw ErreurOff('Téléchargement de $nom impossible (${rep.statusCode}).');
      final b = BytesBuilder(copy: false);
      await for (final morceau in rep.timeout(const Duration(seconds: 60))) {
        b.add(morceau);
      }
      return b.takeBytes();
    } on SocketException {
      throw ErreurOff('Pas de connexion internet.');
    } on TimeoutException {
      throw ErreurOff('Le serveur ne répond pas.');
    } finally {
      client.close(force: true);
    }
  }

  /// Vérifie s'il existe une mise à jour et la télécharge.
  /// Sans [force], ne fait rien tant que le délai de rafraîchissement n'est pas écoulé.
  Future<void> verifier({bool force = false}) async {
    if (enCours || (!force && !aVerifier)) return;
    enCours = true;
    message = 'Recherche d\'une mise à jour…';
    notifyListeners();
    try {
      final v = <String, String>{};
      for (final l in utf8.decode(await _telecharger('catalogue-version.txt')).split('\n')) {
        final i = l.indexOf('=');
        if (i > 0) v[l.substring(0, i).trim()] = l.substring(i + 1).trim();
      }
      final base = v['base'] ?? '';
      final maj = int.tryParse(v['maj'] ?? '') ?? 0;
      final d = await _dossier();
      var change = false;
      if (base.isNotEmpty && base != baseVersion) {
        message = 'Téléchargement du nouveau catalogue…';
        notifyListeners();
        final octets = await _telecharger('catalogue.json.gz');
        lireBase(await compute(_decoder, octets));
        if (d != null) {
          _fichier(d, 'catalogue.json.gz').writeAsBytesSync(octets);
          final ancien = _fichier(d, 'catalogue-maj.json.gz');
          if (ancien.existsSync()) ancien.deleteSync();
        }
        change = true;
      }
      if (maj > majJusqua) {
        message = 'Téléchargement de la mise à jour…';
        notifyListeners();
        final octets = await _telecharger('catalogue-maj.json.gz');
        final j = await compute(_decoder, octets);
        if (j['base'] == baseVersion) {
          // On repart de la base puis on applique la mise à jour cumulative complète
          if (!change && d != null && _fichier(d, 'catalogue.json.gz').existsSync()) {
            lireBase(await compute(_decoder, _fichier(d, 'catalogue.json.gz').readAsBytesSync()));
          } else if (!change) {
            lireBase(await compute(_decoder, (await rootBundle.load(assetBase)).buffer.asUint8List()));
          }
          appliquerMaj(j);
          if (d != null) _fichier(d, 'catalogue-maj.json.gz').writeAsBytesSync(octets);
          change = true;
        }
      }
      derniereVerification = DateTime.now();
      await _enregistrerEtat();
      message = change ? 'Catalogue mis à jour.' : 'Le catalogue est à jour.';
    } on ErreurOff catch (e) {
      message = 'Mise à jour impossible : ${e.message}';
    } catch (e) {
      message = 'Mise à jour impossible : $e';
    } finally {
      enCours = false;
      notifyListeners();
    }
  }
}
