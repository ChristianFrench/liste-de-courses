// Règles contre les mauvais usages du catalogue partagé (31/10/2026).
//
// Chaque foyer dépose ses ajouts (Etat.apports) ; chaque application les filtre à la réception, si bien
// qu'un tricheur qui publie directement sur le serveur, sans l'application, n'y échappe pas :
//   C  plafond : un dépôt de plus de 300 produits (ou 60 rayons et secteurs) est écarté en entier ;
//   E  noms refusés : trop courts ou trop longs, adresses, numéros, majuscules, caractères répétés,
//      chiffres seuls, mots grossiers ;
//   F  doublons : « tomate », « Tomates » et « TOMATES » sont le même produit ; un nom à une lettre près
//      d'un produit du secteur est mis de côté (Etat.appliquerApports) ;
//   I  signalements : un produit signalé par 3 foyers disparaît ; un foyer dont 3 produits le sont est écarté ;
//   B  foyers bloqués par l'éditeur (liste publiée dans le catalogue commun, signé).
// La preuve d'usage (D : seul un produit acheté part) est appliquée au départ, dans Etat.apports.

class Moderation {
  static const plafondProduits = 300;
  static const plafondStructure = 60;
  static const seuilSignalements = 3;

  static const _grossiers = [
    'merde', 'putain', 'pute', 'putes', 'connard', 'connards', 'connasse', 'conne', 'salope', 'salopes',
    'salaud', 'encule', 'enculer', 'encules', 'bite', 'bites', 'couille', 'couilles', 'nique', 'niquer', 'fdp', 'ntm',
    'pd', 'pede', 'batard', 'bordel', 'chier', 'chiotte', 'branleur', 'pouffiasse', 'tapette', 'negre', 'bougnoule',
    'youpin', 'fuck', 'shit', 'bitch', 'porn', 'porno', 'sexe', 'xxx', 'nazi', 'hitler',
  ];

  /// Pourquoi ce nom (produit, rayon, secteur ou marque) n'est pas partagé, ou null s'il est accepté.
  /// Une marque peut s'écrire en majuscules (« HARIBO »).
  static String? nomRefuse(String nom, {bool marque = false}) {
    final n = nom.trim();
    if (n.length < 2) return 'trop court';
    if (n.length > 40) return 'trop long';
    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(n)) return 'sans lettre';
    if (n.contains('@') || RegExp(r'(https?:|www\.|\.(com|fr|net|org|io|be|ch|eu|info|biz|xyz)\b)', caseSensitive: false).hasMatch(n)) {
      return 'adresse';
    }
    if (RegExp(r'\d').allMatches(n).length >= 6) return 'numéro';
    if (RegExp(r'(.)\1{3,}').hasMatch(n.toLowerCase())) return 'caractères répétés';
    final lettres = n.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (!marque && lettres.length > 4 && lettres == lettres.toUpperCase() && lettres != lettres.toLowerCase()) return 'majuscules';
    final mots = sansAccents(n.toLowerCase()).split(RegExp(r'[^a-z]+'));
    if (mots.any(_grossiers.contains)) return 'grossier';
    return null;
  }

  static String sansAccents(String t) => t
      .replaceAll(RegExp('[àâäá]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îïí]'), 'i')
      .replaceAll(RegExp('[ôöó]'), 'o')
      .replaceAll(RegExp('[ùûüú]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ÿ', 'y')
      .replaceAll('œ', 'oe')
      .replaceAll('æ', 'ae');

  /// Forme comparable d'un nom : minuscules, sans accents ni ponctuation, chaque mot au singulier
  /// (« Tomates cerises » et « tomate cerise » sont égaux).
  static String normaliser(String nom) => [
        for (final m in sansAccents(nom.trim().toLowerCase()).split(RegExp(r'[^a-z0-9]+')))
          if (m.isNotEmpty) m.length > 3 && (m.endsWith('s') || m.endsWith('x')) ? m.substring(0, m.length - 1) : m
      ].join(' ');

  /// Deux noms différents à une lettre près (ajoutée, retirée ou changée), assez longs pour que ce soit
  /// une faute de frappe : le second est mis de côté.
  static bool presque(String a, String b) {
    final x = normaliser(a), y = normaliser(b);
    if (x == y || x.length < 5 || y.length < 5 || (x.length - y.length).abs() > 1) return false;
    var i = 0;
    while (i < x.length && i < y.length && x[i] == y[i]) {
      i++;
    }
    var j = 0;
    while (j < x.length - i && j < y.length - i && x[x.length - 1 - j] == y[y.length - 1 - j]) {
      j++;
    }
    return x.length - i - j <= 1 && y.length - i - j <= 1;
  }

  /// Clé d'un produit pour les signalements : « secteur|nom », normalisée.
  static String cleProduit(String secteur, String nom) => '${normaliser(secteur)}|${normaliser(nom)}';

  /// Filtre les dépôts reçus des autres foyers. Chaque dépôt porte son identifiant (« id », tiré du sujet
  /// sur le serveur) ; [bloques] : foyers bloqués par l'éditeur ; [signales] : produits signalés par ce foyer.
  /// Rend les dépôts nettoyés, les produits retirés par signalement et les foyers écartés.
  static ({List<Map<String, dynamic>> lots, Set<String> signales, Set<String> ecartes}) filtrer(
    Iterable<Map<String, dynamic>> recus, {
    Set<String> bloques = const {},
    Set<String> signales = const {},
  }) {
    final ecartes = <String>{};
    final valides = <Map<String, dynamic>>[];
    for (final j in recus) {
      final id = '${j['id'] ?? ''}';
      final nbProduits = (j['produits'] as List? ?? const []).length;
      final nbStructure = (j['rayons'] as List? ?? const []).length + (j['secteurs'] as List? ?? const []).length;
      if (bloques.contains(id) || nbProduits > plafondProduits || nbStructure > plafondStructure) {
        ecartes.add(id);
      } else {
        valides.add(j);
      }
    }
    // Signalements : chaque foyer compte une fois par produit ; ceux de ce foyer suffisent pour lui.
    final compte = <String, Set<String>>{};
    for (final j in valides) {
      for (final c in (j['signales'] as List? ?? const []).cast<String>().toSet()) {
        compte.putIfAbsent(c, () => {}).add('${j['id'] ?? ''}');
      }
    }
    final retires = {
      ...signales,
      for (final e in compte.entries)
        if (e.value.length >= seuilSignalements) e.key
    };
    // Un foyer dont plusieurs produits sont signalés par d'autres est écarté en entier.
    final lots = <Map<String, dynamic>>[];
    for (final j in valides) {
      final produits = (j['produits'] as List? ?? const []).cast<Map>();
      final touches = produits.where((p) {
        final c = cleProduit('${p['secteur'] ?? ''}', '${p['nom'] ?? ''}');
        return (compte[c] ?? const {}).length >= seuilSignalements;
      }).length;
      if (touches >= seuilSignalements) {
        ecartes.add('${j['id'] ?? ''}');
        continue;
      }
      lots.add(nettoyer(j, retires));
    }
    return (lots: lots, signales: retires, ecartes: ecartes);
  }

  /// Un dépôt sans ses noms refusés ni ses produits signalés.
  static Map<String, dynamic> nettoyer(Map<String, dynamic> j, Set<String> signales) {
    bool secteurOk(String c) {
      final i = c.indexOf('/');
      return i > 0 && i < c.length - 1 && nomRefuse(c.substring(0, i)) == null && nomRefuse(c.substring(i + 1)) == null;
    }

    return {
      'id': j['id'],
      'rayons': [for (final r in (j['rayons'] as List? ?? const []).cast<String>()) if (nomRefuse(r) == null) r],
      'secteurs': [for (final c in (j['secteurs'] as List? ?? const []).cast<String>()) if (secteurOk(c)) c],
      'produits': [
        for (final p in (j['produits'] as List? ?? const []).cast<Map>())
          if (p['nom'] is String && p['rayon'] is String && p['secteur'] is String)
            if (nomRefuse(p['nom'] as String) == null &&
                nomRefuse(p['rayon'] as String) == null &&
                nomRefuse(p['secteur'] as String) == null &&
                !signales.contains(cleProduit(p['secteur'] as String, p['nom'] as String)))
              {
                'nom': p['nom'],
                'rayon': p['rayon'],
                'secteur': p['secteur'],
                if (p['marque'] case final String m when nomRefuse(m, marque: true) == null) 'marque': m,
                if (p['formats'] is List) 'formats': [for (final f in (p['formats'] as List).take(2)) if (f is String && f.length <= 40) f],
              }
      ],
      'marques': {
        for (final e in (j['marques'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is List)
            e.key as String: [for (final m in (e.value as List).take(50)) if (m is String && nomRefuse(m, marque: true) == null) m]
      },
    };
  }
}
