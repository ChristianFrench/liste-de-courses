import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'import_texte.dart';
import 'modele.dart';

// 15/11/2026 (Aristide) : une recette (catalogue de recettes, lien internet ou texte) propose ses ingrédients,
// à cocher, pour compléter la liste en préparation. Pas de rayon à ce stade ; les produits du placard
// (sel, poivre, huile, farine…) sont décochés au départ. Première version dans la démonstration.

/// Une recette : son titre et ses lignes d'ingrédients telles qu'écrites (« 200 g de lardons fumés »).
class RecetteLue {
  const RecetteLue(this.titre, this.ingredients, {this.types = const []});
  final String titre;
  final List<String> ingredients;
  final List<String> types;
}

/// Un ingrédient lu : la ligne d'origine, le nom nettoyé, le produit reconnu (ou null : produit à créer).
class IngredientLu {
  const IngredientLu(this.texte, this.nom, this.produit, {this.placard = false});
  final String texte;
  final String nom;
  final Produit? produit;

  /// Produit du placard (sel, poivre, huile…), qu'on a en général : décoché au départ.
  final bool placard;
}

List<RecetteLue>? _fournies;

/// Les recettes fournies avec l'application (le catalogue de recettes d'Aristide).
Future<List<RecetteLue>> recettesFournies() async {
  if (_fournies != null) return _fournies!;
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/recettes/recettes.json')) as Map<String, dynamic>;
    _fournies = [
      for (final r in (j['recettes'] as List).cast<Map<String, dynamic>>())
        RecetteLue(
          r['titre'] as String,
          [
            for (final i in (r['ingredients'] as List).cast<Map<String, dynamic>>())
              [i['quantite'], i['nom']].whereType<String>().join(' '),
          ],
          types: (r['types'] as List? ?? const []).cast<String>(),
        ),
    ];
  } catch (_) {
    _fournies = const [];
  }
  return _fournies!;
}

const _unites = r'(kg|g|mg|cl|ml|dl|l|litres?|grammes?|kilos?|c\.?\s*à\s*(soupe|café|s|c)|cuill[eè]res?\s*à\s*(soupe|café)|'
    r'cuil\.?\s*à\s*(soupe|café)|cs|cc|càs|càc|pincées?|gousses?|tranches?|bo[iî]tes?|sachets?|verres?|bouquets?|brins?|'
    r'bottes?|feuilles?|morceaux?|pots?|paquets?|branches?|filets?|zestes?|t[eê]tes?|tasses?|bols?|noix|noisettes?|'
    r'poignées?|barquettes?|rouleaux?|briques?|bouteilles?|doses?|tablettes?|carrés?|cubes?|petits?|grosses?|gros|belles?|beaux?)';

/// « 3 à 4 c. à soupe d'huile d'olive (de qualité) » → « huile d'olive ».
String nomIngredient(String ligne) {
  var t = ligne.trim().replaceFirst(RegExp(r'^[-–—*•·+o>]+\s*'), '');
  t = t.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Quantités : « 1 », « 1,5 », « 1/2 », « ½ », « 3 à 4 », « 2-3 ».
  final nombre = r'(\d+([.,]\d+)?(\s*/\s*\d+)?|[½¼¾⅓⅔]|(un|une|deux|trois|quatre|cinq|six|quelques)(?=\s))';
  t = t.replaceFirst(RegExp('^$nombre(\\s*(à|-|–|ou)\\s*$nombre)?\\s*', caseSensitive: false), '');
  for (var i = 0; i < 2; i++) {
    t = t.replaceFirst(RegExp('^$_unites(?![a-zA-Zà-ÿ])\\.?\\s*', caseSensitive: false), '');
  }
  t = t.replaceFirst(RegExp(r"^(de\s+la\s+|de\s+l['’]\s*|de\s+|d['’]\s*|du\s+|des\s+)", caseSensitive: false), '');
  // Fin de ligne : « , pour la garniture », « : facultatif ».
  t = t.replaceFirst(RegExp(r'\s*[:;].*$'), '').trim();
  if (t.isNotEmpty) t = t[0].toUpperCase() + t.substring(1);
  return t;
}

const _placard = {'sel', 'poivre', 'huile', 'farine', 'sucre', 'levure', 'vinaigre', 'muscade', 'piment', 'thym', 'origan',
    'laurier', 'safran', 'cumin', 'curry', 'paprika', 'cannelle', 'bouillon', 'maizena', 'fecule', 'bicarbonate', 'epice',
    'epices', 'vanille', 'gingembre', 'curcuma', 'coriandre', 'romarin', 'herbe', 'herbes', 'fleur', 'clou', 'clous',
    'chapelure', 'moutarde', 'concentre', 'ketchup', 'mayonnaise', 'sauce'};

bool estDuPlacard(String nom) {
  final mots = normaliser(nom).split(' ');
  if (mots.isEmpty) return false;
  if (mots.first == 'noix' && mots.contains('muscade')) return true;
  if (mots.first == 'gros' && mots.length > 1 && mots[1] == 'sel') return true;
  return _placard.contains(mots.first);
}

/// Les ingrédients d'une recette, reconnus dans le catalogue ; un même produit n'apparaît qu'une fois.
/// L'eau n'est pas un achat : elle est ignorée.
List<IngredientLu> analyserIngredients(Etat etat, List<String> lignes) {
  final res = <IngredientLu>[];
  final vus = <String>{};
  for (final ligne in lignes) {
    final nom = nomIngredient(ligne);
    final n = normaliser(nom);
    if (n.isEmpty || n == 'eau' || n.startsWith('eau ') && !n.contains('gazeuse') && !n.contains('fleur')) continue;
    final p = reconnaitreProduit(etat, nom);
    if (!vus.add(p?.id ?? 'n:$n')) continue;
    res.add(IngredientLu(ligne.trim(), nom, p, placard: estDuPlacard(nom)));
  }
  return res;
}

final _debutIngredients = RegExp(r'^\s*(liste\s+des\s+)?ingr[ée]dients?\b', caseSensitive: false);
final _finIngredients = RegExp(
    r'^\s*(pr[ée]paration|[ée]tapes?|instructions?|r[ée]alisation|recette|progression|d[ée]roulement|ustensiles?|mat[ée]riel|'
    r'conseils?|astuces?|cuisson)\b',
    caseSensitive: false);

/// Une recette collée en texte (ou le texte d'une page) : les lignes entre « Ingrédients » et « Préparation »
/// quand ces titres existent, sinon les lignes courtes qui ne sont pas des étapes. Titre : la première ligne.
RecetteLue lireRecetteTexte(String texte, {String? titre}) {
  final lignes = depuisHtml(texte).split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final debut = lignes.indexWhere((l) => _debutIngredients.hasMatch(l) && l.length < 60);
  var corps = lignes;
  if (debut >= 0) {
    corps = lignes.sublist(debut + 1);
    final fin = corps.indexWhere((l) => _finIngredients.hasMatch(l) && l.length < 60);
    if (fin >= 0) corps = corps.sublist(0, fin);
    // « Ingrédients : farine, œufs, lait » sur une seule ligne
    final meme = lignes[debut].replaceFirst(_debutIngredients, '').replaceFirst(RegExp(r'^\s*(pour[^:]*)?:\s*'), '');
    if (meme.trim().isNotEmpty) corps = [...meme.split(RegExp(r',|;')), ...corps];
  }
  final ingredients = [
    for (final l in corps)
      if (l.length <= 90 &&
          !RegExp(r'^\d+\s*[.)]\s+\S+.{40,}').hasMatch(l) &&
          !RegExp(r'^pour\s+\d+|personnes?\s*$|^\d+\s*personnes?', caseSensitive: false).hasMatch(l) &&
          (debut >= 0 || l != lignes.first))
        l,
  ];
  return RecetteLue(titre ?? (debut > 0 ? lignes.first : (lignes.isEmpty ? 'RecetteLue' : lignes.first)), ingredients);
}

/// Les données de recette d'une page (balise schema.org Recipe, publiée par la plupart des sites de cuisine).
RecetteLue? recetteDansPage(String html) {
  for (final m in RegExp(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', caseSensitive: false, dotAll: true)
      .allMatches(html)) {
    try {
      final r = _chercherRecette(jsonDecode(m[1]!.trim()));
      if (r != null) return r;
    } catch (_) {}
  }
  return null;
}

RecetteLue? _chercherRecette(Object? j) {
  if (j is List) {
    for (final x in j) {
      final r = _chercherRecette(x);
      if (r != null) return r;
    }
  } else if (j is Map) {
    final type = j['@type'];
    final estRecette = type == 'Recipe' || (type is List && type.contains('Recipe'));
    final ing = j['recipeIngredient'] ?? j['ingredients'];
    if (estRecette && ing is List) {
      return RecetteLue(depuisHtml('<p>${j['name'] ?? 'RecetteLue'}</p>').trim(), [for (final i in ing) depuisHtml('<p>$i</p>').trim()]);
    }
    for (final k in ['@graph', 'mainEntity', 'itemListElement']) {
      final r = _chercherRecette(j[k]);
      if (r != null) return r;
    }
  }
  return null;
}

/// Lit la recette d'une page internet. Lève une exception si la page ne peut être lue
/// (réseau, ou navigateur qui refuse de lire un autre site).
Future<RecetteLue> recetteDepuisLien(String lien) async {
  var u = lien.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  final r = await http.get(Uri.parse(u), headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) Emplettes'})
      .timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) throw Exception('page inaccessible (${r.statusCode})');
  final html = utf8.decode(r.bodyBytes, allowMalformed: true);
  final structuree = recetteDansPage(html);
  if (structuree != null && structuree.ingredients.isNotEmpty) return structuree;
  final t = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html)?[1];
  return lireRecetteTexte(html, titre: t == null ? null : depuisHtml('<p>$t</p>').trim());
}
