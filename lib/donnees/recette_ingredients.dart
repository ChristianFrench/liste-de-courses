import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'import_texte.dart';
import 'demonstration.dart';
import 'modele.dart';
import 'recettes_recues.dart';

// 15/11/2026 (Aristide) : une recette (catalogue de recettes, lien internet ou texte) propose ses ingrédients,
// à cocher, pour compléter la liste en préparation. Pas de rayon à ce stade ; les produits du placard
// (sel, poivre, huile, farine…) sont décochés au départ. Première version dans la démonstration.

/// Une recette : son titre et ses lignes d'ingrédients telles qu'écrites (« 200 g de lardons fumés »).
class RecetteLue {
  const RecetteLue(this.titre, this.ingredients,
      {this.id,
      this.types = const [],
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
      this.occasions = const [],
      this.quantites = const []});
  final String titre;
  final List<String> ingredients;
  final List<String> types;

  /// Identifiant dans le catalogue des recettes (null pour une recette lue d'un lien ou d'un texte).
  final String? id;

  /// Le contenu, pour voir ce qu'une nouvelle version a changé.
  String get signature => jsonEncode([titre, ingredients, types, pour, etapes, conseils, source, tempsPreparation, tempsCuisson,
        difficulte, cout, regimes, saisons, cuissons, occasions]);

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

  /// Quantité de chaque ingrédient (même ordre que [ingredients], null si sans quantité), pour changer le
  /// nombre de personnes (20/11/2026, Aristide). Vide pour les recettes lues d'un lien ou d'un texte.
  final List<String?> quantites;

  /// Nombre de personnes (ou de parts) de la recette, s'il se lit : « 4 personnes » → 4 ; null sinon.
  int? get personnes {
    final m = RegExp(r'^(\d+)\s+(?!à)\D').firstMatch(pour ?? '');
    return m == null ? null : int.parse(m[1]!);
  }

  /// « 4 personnes » pour [n] : « 6 personnes », « 1 personne ».
  String pourN(int n) {
    final reste = (pour ?? '').replaceFirst(RegExp(r'^\d+\s*'), '');
    final mot = RegExp(r'^personnes?\b').hasMatch(reste) ? reste.replaceFirst(RegExp(r'^personnes?'), n > 1 ? 'personnes' : 'personne') : reste;
    return '$n $mot';
  }

  /// Les lignes d'ingrédients pour [n] personnes (quantités recalculées) ; telles quelles sans [personnes].
  List<String> ingredientsPour(int? n) {
    final base = personnes;
    if (n == null || base == null || n == base || quantites.length != ingredients.length) return ingredients;
    return [
      for (var i = 0; i < ingredients.length; i++)
        if (quantites[i] case final q?) ingredients[i].replaceFirst(q, ajusterQuantite(q, n / base)) else ingredients[i],
    ];
  }

  /// Préparation + cuisson, ou null si l'un des deux temps manque.
  int? get tempsTotal => tempsPreparation == null || tempsCuisson == null ? null : tempsPreparation! + tempsCuisson!;

  /// « Pour 4 personnes · Préparation 20 min · Cuisson 40 min · Facile ».
  String get ligneEnTete => ligne(avecPour: true);

  String ligne({required bool avecPour}) => [
        if (avecPour && pour != null) 'Pour $pour',
        if (tempsPreparation != null) 'Préparation ${duree(tempsPreparation!)}',
        if (tempsCuisson != null) tempsCuisson == 0 ? 'Sans cuisson' : 'Cuisson ${duree(tempsCuisson!)}',
        if (difficulte != null) difficulte!,
      ].join(' · ');

  /// Les pastilles de critères : régimes, saison (« Toute l'année » si les quatre), coût, cuisson, occasions.
  List<String> get pastilles => [
        ...regimes,
        if (saisons.length >= 4) 'Toute l\'année' else ...saisons,
        if (cout != null) cout!,
        // « Sans cuisson » est déjà dans l'en-tête quand le temps de cuisson vaut 0.
        for (final c in cuissons)
          if (!(tempsCuisson == 0 && c == 'Sans cuisson')) c,
        ...occasions,
      ];

  /// Illustration : chemin d'un fichier de l'application (« assets/… »), adresse internet (page de recette) ou
  /// « recette:<empreinte> », image reçue du catalogue commun des recettes.
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

/// Une quantité multipliée par [facteur] : « 200 g » × 1,5 → « 300 g », « 3 » × 0,5 → « 2 » (les pièces restent
/// entières), « 2 à 3 gousses » × 2 → « 4 à 6 gousses », « 1 cuillère à soupe » × 1,5 → « 1,5 cuillère à soupe ».
String ajusterQuantite(String quantite, double facteur) {
  const fractions = {'½': 0.5, '¼': 0.25, '¾': 0.75};
  final m = RegExp(r'^(\d+(?:[.,]\d+)?(?:/\d+)?|[½¼¾])(\s*à\s*(\d+(?:[.,]\d+)?))?').firstMatch(quantite);
  if (m == null) return quantite;
  final reste = quantite.substring(m.end);
  final unite = RegExp(r'^\s*([a-zA-Z]+)').firstMatch(reste)?[1]?.toLowerCase();
  double lire(String t) {
    if (fractions[t] case final f?) return f;
    if (t.contains('/')) {
      final p = t.split('/');
      return double.parse(p[0]) / double.parse(p[1]);
    }
    return double.parse(t.replaceAll(',', '.'));
  }

  String ecrire(double v, double origine) {
    double r;
    if (unite == 'g' || unite == 'ml') {
      r = v >= 20 ? (v / 5).round() * 5.0 : v.roundToDouble();
    } else if (unite == 'kg' || unite == 'l' || unite == 'litre' || unite == 'litres') {
      r = (v * 20).round() / 20;
    } else if (unite == null && origine >= 1 && origine == origine.roundToDouble()) {
      r = v.roundToDouble(); // des pièces : 3 œufs → 2 ou 5, jamais 2,5
    } else {
      r = (v * 2).round() / 2;
    }
    if (r <= 0) r = unite == null ? 1 : 0.5;
    if (r == 0.5 && unite != 'kg' && unite != 'l') return '½';
    final t = r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return t.replaceAll('.', ',');
  }

  final a = lire(m[1]!);
  final debut = ecrire(a * facteur, a);
  final fin = m[3] == null ? '' : ' à ${ecrire(lire(m[3]!) * facteur, lire(m[3]!))}';
  return '$debut$fin$reste';
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
Map<String, dynamic>? _embarque;

/// À relire au prochain appel de [recettesFournies] (nouvelle version reçue, image arrivée).
void oublierRecettes() => _fournies = null;

Future<Map<String, dynamic>> _lireEmbarque() async =>
    _embarque ??= jsonDecode(await rootBundle.loadString('assets/recettes/recettes.json')) as Map<String, dynamic>;

/// Empreintes des images embarquées (vers_application.py) : une version reçue ne les retélécharge pas.
Future<Set<String>> empreintesEmbarquees() async {
  try {
    return {
      for (final r in ((await _lireEmbarque())['recettes'] as List).cast<Map>())
        if (r['empreinte'] case final String e) e,
    };
  } catch (_) {
    return {};
  }
}

/// Une recette lue en JSON : celle embarquée (ingrédients { nom, quantite }) ou celle de la console
/// (ingrédients en texte, « detail » { nom, quantite, precision }).
RecetteLue recetteDepuisJson(Map r, {String? image}) {
  final List<Map> detail =
      (r['detail'] as List?)?.whereType<Map>().toList() ?? (r['ingredients'] as List? ?? const []).whereType<Map>().toList();
  final lignes = detail.isNotEmpty
      ? [for (final i in detail) [i['quantite'], i['nom']].whereType<String>().where((x) => x.isNotEmpty).join(' ')]
      : [for (final i in (r['ingredients'] as List? ?? const [])) '$i'];
  List<String> liste(String c) => (r[c] as List? ?? const []).cast<String>();
  return RecetteLue(
    r['titre'] as String,
    lignes,
    id: r['id'] as String?,
    types: liste('types'),
    image: image,
    pour: r['pour'] as String?,
    etapes: liste('etapes'),
    conseils: liste('conseils'),
    source: r['source'] as String?,
    tempsPreparation: (r['tempsPreparation'] as num?)?.toInt(),
    tempsCuisson: (r['tempsCuisson'] as num?)?.toInt(),
    difficulte: r['difficulte'] as String?,
    cout: r['cout'] as String?,
    regimes: liste('regimes'),
    saisons: liste('saisons'),
    cuissons: liste('cuissons'),
    occasions: liste('occasions'),
    quantites: detail.isNotEmpty ? [for (final i in detail) i['quantite'] as String?] : const [],
  );
}

/// Les recettes : la dernière version reçue du catalogue commun des recettes (20/11/2026), sinon celles
/// embarquées dans l'application (la démonstration garde toujours celles-ci).
Future<List<RecetteLue>> recettesFournies() async {
  if (_fournies != null) return _fournies!;
  try {
    final j = await _lireEmbarque();
    final embarquees = (j['recettes'] as List).cast<Map<String, dynamic>>();
    String? chemin(Map r) => r['image'] == null ? null : 'assets/recettes/illustrations/${r['image']}';
    final recu = demonstration ? null : RecettesRecues.instance.index;
    if (recu == null) {
      _fournies = [for (final r in embarquees) recetteDepuisJson(r, image: chemin(r))];
    } else {
      final parEmpreinte = {for (final r in embarquees) if (r['empreinte'] != null) r['empreinte']: chemin(r)};
      final parId = {for (final r in embarquees) if (r['id'] != null) r['id']: chemin(r)};
      String? image(Map r) {
        final e = r['image'] as String?;
        if (e != null) {
          if (parEmpreinte[e] case final c?) return c;
          if (RecettesRecues.instance.image(e) != null) return 'recette:$e';
        }
        // Image pas encore reçue : celle embarquée de la même recette, sinon l'image du type.
        return parId[r['id']];
      }

      _fournies = [for (final r in (recu['recettes'] as List).cast<Map>()) recetteDepuisJson(r, image: image(r))]
        ..sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
    }
  } catch (e) {
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
