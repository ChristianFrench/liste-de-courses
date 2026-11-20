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
  const RecetteLue(this.titre, this.ingredients,
      {this.types = const [],
      this.image,
      this.pour,
      this.etapes = const [],
      this.conseils = const [],
      this.source,
      this.tempsPreparation,
      this.tempsCuisson,
      this.difficulte,
      this.cout,
      this.regimes = const [],
      this.saisons = const [],
      this.cuissons = const [],
      this.occasions = const []});
  final String titre;
  final List<String> ingredients;
  final List<String> types;

  /// Le texte de la recette (18/11/2026) : « 4 personnes », étapes, conseils, source (« Emplettes »).
  final String? pour;
  final List<String> etapes;
  final List<String> conseils;
  final String? source;

  /// Critères (20/11/2026, console) : temps en minutes (absents pour les recettes maison ; cuisson 0 = sans cuisson),
  /// difficulté (Facile, Moyen, Difficile, Avancé), coût (€, €€, €€€), régimes, saisons, modes de cuisson, occasions.
  final int? tempsPreparation;
  final int? tempsCuisson;
  final String? difficulte;
  final String? cout;
  final List<String> regimes;
  final List<String> saisons;
  final List<String> cuissons;
  final List<String> occasions;

  /// Préparation + cuisson, ou null si l'un des deux temps manque.
  int? get tempsTotal => tempsPreparation == null || tempsCuisson == null ? null : tempsPreparation! + tempsCuisson!;

  /// « Pour 4 personnes · Préparation 20 min · Cuisson 40 min · Facile ».
  String get ligneEnTete => [
        if (pour != null) 'Pour $pour',
        if (tempsPreparation != null) 'Préparation ${duree(tempsPreparation!)}',
        if (tempsCuisson != null) tempsCuisson == 0 ? 'Sans cuisson' : 'Cuisson ${duree(tempsCuisson!)}',
        if (difficulte != null) difficulte!,
      ].join(' · ');

  /// Les pastilles de critères : régimes, saison (« Toute l'année » si les quatre), coût, cuisson, occasions.
  List<String> get pastilles => [
        ...regimes,
        if (saisons.length >= 4) 'Toute l\'année' else if (saisons.isNotEmpty) saisons.join(' · '),
        if (cout != null) cout!,
        // « Sans cuisson » est déjà dans l'en-tête quand le temps de cuisson vaut 0.
        for (final c in cuissons)
          if (!(tempsCuisson == 0 && c == 'Sans cuisson')) c,
        ...occasions,
      ];

  /// Illustration : chemin d'un fichier de l'application (« assets/… ») ou adresse internet (page de recette).
  final String? image;
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

/// 70 → « 1 h 10 », 60 → « 1 h », 20 → « 20 min ».
String duree(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Image par défaut d'un type de recette (icônes d'Aristide), pour les recettes encore sans illustration.
String imageDuType(List<String> types) {
  final t = types.isEmpty ? '' : normaliser(types.first);
  if (t.startsWith('dessert')) return 'assets/recettes/desserts.png';
  if (t.startsWith('entree')) return 'assets/recettes/entrees.png';
  if (t.contains('accompagnement')) return 'assets/recettes/plats-accompagnement.png';
  if (t.startsWith('plat')) return 'assets/recettes/plats-complets.png';
  if (t.startsWith('sauce')) return 'assets/recettes/sauces.png';
  return 'assets/recettes/recettes-de-cuisine.png';
}

/// Les filtres du choix d'une recette (20/11/2026, Aristide) : plusieurs valeurs d'un critère en « ou »,
/// des critères différents en « et ». La recherche porte sur le titre et les ingrédients.
class FiltreRecettes {
  String texte = '';
  final Map<String, Set<String>> choix = {for (final c in criteres.keys) c: <String>{}};

  /// Les critères et leurs valeurs, dans l'ordre d'affichage.
  static const criteres = <String, List<String>>{
    'Type': ['Entrée', 'Plats', 'Plats accompagnement', 'Sauces', 'Dessert'],
    'Difficulté': ['Facile', 'Moyen', 'Difficile', 'Avancé'],
    'Temps': ['Moins de 30 min', 'Moins d\'une heure', 'Plus d\'une heure'],
    'Régime': ['Végétarien', 'Végétalien', 'Sans gluten', 'Sans lactose'],
    'Saison': ['Printemps', 'Été', 'Automne', 'Hiver'],
    'Coût': ['€', '€€', '€€€'],
    'Cuisson': ['Sans cuisson', 'Four', 'Plaque', 'Cocotte-minute'],
    'Occasion': ['Quotidien', 'À l\'avance', 'À recevoir', 'À emporter'],
  };

  /// Libellé d'une valeur (« Plats accompagnement » → « Accompagnement »).
  static String libelle(String valeur) => valeur == 'Plats accompagnement' ? 'Accompagnement' : valeur;

  /// La saison du jour (« De saison »).
  static String saisonDu(DateTime d) => switch (d.month) {
        3 || 4 || 5 => 'Printemps',
        6 || 7 || 8 => 'Été',
        9 || 10 || 11 => 'Automne',
        _ => 'Hiver',
      };

  bool get actif => choix.values.any((v) => v.isNotEmpty);
  int get nombreActifs => choix.values.fold(0, (n, v) => n + v.length);

  void effacer() {
    for (final v in choix.values) {
      v.clear();
    }
  }

  bool garde(RecetteLue r) {
    final f = normaliser(texte);
    if (f.isNotEmpty && !normaliser(r.titre).contains(f) && !r.ingredients.any((i) => normaliser(i).contains(f))) return false;
    bool un(String critere, Iterable<String> valeurs) {
      final c = choix[critere]!;
      return c.isEmpty || valeurs.any(c.contains);
    }

    if (!un('Type', r.types)) return false;
    if (!un('Difficulté', [if (r.difficulte case final d?) d])) return false;
    if (!un('Régime', r.regimes)) return false;
    if (!un('Saison', r.saisons)) return false;
    if (!un('Coût', [if (r.cout case final c?) c])) return false;
    if (!un('Cuisson', r.cuissons)) return false;
    if (!un('Occasion', r.occasions)) return false;
    final t = choix['Temps']!;
    if (t.isNotEmpty) {
      // Les recettes sans temps (recettes maison) ne sont écartées que par ce filtre.
      final total = r.tempsTotal;
      if (total == null) return false;
      if (!((t.contains('Moins de 30 min') && total <= 30) ||
          (t.contains('Moins d\'une heure') && total <= 60) ||
          (t.contains('Plus d\'une heure') && total > 60))) {
        return false;
      }
    }
    return true;
  }
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
          image: r['image'] == null ? null : 'assets/recettes/illustrations/${r['image']}',
          pour: r['pour'] as String?,
          etapes: (r['etapes'] as List? ?? const []).cast<String>(),
          conseils: (r['conseils'] as List? ?? const []).cast<String>(),
          source: r['source'] as String?,
          tempsPreparation: (r['tempsPreparation'] as num?)?.toInt(),
          tempsCuisson: (r['tempsCuisson'] as num?)?.toInt(),
          difficulte: r['difficulte'] as String?,
          cout: r['cout'] as String?,
          regimes: (r['regimes'] as List? ?? const []).cast<String>(),
          saisons: (r['saisons'] as List? ?? const []).cast<String>(),
          cuissons: (r['cuissons'] as List? ?? const []).cast<String>(),
          occasions: (r['occasions'] as List? ?? const []).cast<String>(),
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
      return RecetteLue(depuisHtml('<p>${j['name'] ?? 'RecetteLue'}</p>').trim(), [for (final i in ing) depuisHtml('<p>$i</p>').trim()],
          image: _imageDe(j['image']));
    }
    for (final k in ['@graph', 'mainEntity', 'itemListElement']) {
      final r = _chercherRecette(j[k]);
      if (r != null) return r;
    }
  }
  return null;
}

/// L'image d'une recette schema.org : une adresse, une liste d'adresses ou un objet ImageObject.
String? _imageDe(Object? i) {
  if (i is String) return i.startsWith('http') ? i : null;
  if (i is List) {
    for (final x in i) {
      if (_imageDe(x) case final u?) return u;
    }
  }
  if (i is Map) return _imageDe(i['url'] ?? i['contentUrl']);
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
