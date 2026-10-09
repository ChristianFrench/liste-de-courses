import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Article commercial tel que décrit par Open Food Facts
/// (un produit précis : marque, quantité, code-barres).
class ArticleOff {
  ArticleOff({
    required this.code,
    required this.nom,
    required this.nomGenerique,
    required this.marques,
    required this.marquesTags,
    required this.quantite,
    required this.imagePetite,
    required this.imageGrande,
    required this.nutriscore,
  });

  final String code;
  final String nom;
  final String nomGenerique;

  /// Marques telles qu'écrites sur le produit (« Lactel, Lactalis »).
  final List<String> marques;

  /// Identifiants des marques chez Open Food Facts (« lactel »), pour lister une marque.
  final List<String> marquesTags;
  final String quantite;
  final String imagePetite;
  final String imageGrande;

  /// Nutri-Score : a à e, ou vide si non calculé.
  final String nutriscore;

  String get marque => marques.isEmpty ? '' : marques.first;
  String? get marqueTag => marquesTags.isEmpty ? null : marquesTags.first;

  static String _texte(dynamic v) => v is String ? v.trim() : '';

  factory ArticleOff.depuis(Map<String, dynamic> p) {
    final nomFr = _texte(p['product_name_fr']);
    final marques = _texte(p['brands']).split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    final ns = _texte(p['nutriscore_grade']).toLowerCase();
    return ArticleOff(
      code: _texte(p['code']),
      nom: nomFr.isNotEmpty ? nomFr : _texte(p['product_name']),
      nomGenerique: _texte(p['generic_name_fr']),
      marques: marques,
      marquesTags: [for (final t in (p['brands_tags'] as List? ?? const [])) if (t is String) t],
      quantite: _texte(p['quantity']),
      imagePetite: _texte(p['image_front_small_url']),
      imageGrande: _texte(p['image_front_url']),
      nutriscore: const ['a', 'b', 'c', 'd', 'e'].contains(ns) ? ns : '',
    );
  }
}

class ErreurOff implements Exception {
  ErreurOff(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Accès au service public d'Open Food Facts (données ODbL, photos CC-BY-SA).
class OpenFoodFacts {
  OpenFoodFacts._();
  static final OpenFoodFacts instance = OpenFoodFacts._();

  static const String hote = 'fr.openfoodfacts.org';
  static const String agent = 'ListeDeCourses/0.4 (maquette; github.com/ChristianFrench/liste-de-courses)';
  static const String champs = 'code,product_name_fr,product_name,generic_name_fr,brands,brands_tags,'
      'quantity,image_front_small_url,image_front_url,nutriscore_grade';

  Future<Map<String, dynamic>> _lire(Uri adresse) async {
    final client = HttpClient()
      ..userAgent = agent
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final requete = await client.getUrl(adresse);
      final reponse = await requete.close().timeout(const Duration(seconds: 25));
      final corps = await reponse.transform(utf8.decoder).join();
      if (reponse.statusCode == 429) {
        throw ErreurOff('Trop de recherches en peu de temps : patientez une minute.');
      }
      if (reponse.statusCode == 404) return {'status': 0};
      if (reponse.statusCode != 200) {
        throw ErreurOff('Open Food Facts a répondu par une erreur (${reponse.statusCode}).');
      }
      return jsonDecode(corps) as Map<String, dynamic>;
    } on SocketException {
      throw ErreurOff('Pas de connexion internet, ou Open Food Facts injoignable.');
    } on TimeoutException {
      throw ErreurOff('Open Food Facts ne répond pas : réessayez dans un moment.');
    } on HandshakeException {
      throw ErreurOff('Connexion sécurisée impossible avec Open Food Facts.');
    } on FormatException {
      throw ErreurOff('Réponse illisible d\'Open Food Facts.');
    } finally {
      client.close(force: true);
    }
  }

  List<ArticleOff> _articles(dynamic liste) => [
        for (final p in (liste as List? ?? const []))
          if (p is Map<String, dynamic>) ArticleOff.depuis(p)
      ].where((a) => a.nom.isNotEmpty && a.code.isNotEmpty).toList();

  /// Recherche par mots (produits vendus en France, les plus scannés d'abord).
  Future<List<ArticleOff>> rechercher(String texte, {int nombre = 24}) async {
    final adresse = Uri.https(hote, '/cgi/search.pl', {
      'search_terms': texte,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '$nombre',
      'sort_by': 'unique_scans_n',
      'tagtype_0': 'countries',
      'tag_contains_0': 'contains',
      'tag_0': 'france',
      'fields': champs,
    });
    final j = await _lire(adresse);
    return francaisDabord(_articles(j['products']));
  }

  /// Codes-barres attribués en France (préfixes 300 à 379) placés en tête,
  /// en gardant l'ordre de popularité à l'intérieur de chaque groupe.
  static List<ArticleOff> francaisDabord(List<ArticleOff> liste) {
    bool francais(ArticleOff a) => a.code.length == 13 && a.code.startsWith('3');
    return [...liste.where(francais), ...liste.where((a) => !francais(a))];
  }

  /// Article par code-barres ; null s'il est inconnu.
  Future<ArticleOff?> parCode(String code) async {
    final j = await _lire(Uri.https(hote, '/api/v2/product/$code', {'fields': champs}));
    final p = j['product'];
    if (j['status'] != 1 || p is! Map<String, dynamic>) return null;
    final a = ArticleOff.depuis({...p, 'code': p['code'] ?? code});
    return a.nom.isEmpty ? null : a;
  }

  /// Articles d'une marque ; renvoie le nombre total et une première page.
  Future<(int, List<ArticleOff>)> parMarque(String marqueTag, {int nombre = 48}) async {
    final j = await _lire(Uri.https(hote, '/api/v2/search', {
      'brands_tags': marqueTag,
      'countries_tags_en': 'france',
      'sort_by': 'unique_scans_n',
      'page_size': '$nombre',
      'fields': champs,
    }));
    final total = (j['count'] as num?)?.toInt() ?? 0;
    return (total, francaisDabord(_articles(j['products'])));
  }
}

/// Code EAN-13 valide (13 chiffres, clé de contrôle correcte).
bool ean13Valide(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  var somme = 0;
  for (var i = 0; i < 12; i++) {
    somme += int.parse(code[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - somme % 10) % 10 == int.parse(code[12]);
}

/// Modules (1 = barre, 0 = espace) d'un code EAN-13 : 95 modules.
List<bool> modulesEan13(String code) {
  const l = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
  const g = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
  const r = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
  const parite = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];
  final c = code.split('').map(int.parse).toList();
  final b = StringBuffer('101');
  for (var i = 0; i < 6; i++) {
    b.write(parite[c[0]][i] == 'L' ? l[c[i + 1]] : g[c[i + 1]]);
  }
  b.write('01010');
  for (var i = 7; i < 13; i++) {
    b.write(r[c[i]]);
  }
  b.write('101');
  return b.toString().split('').map((x) => x == '1').toList();
}
