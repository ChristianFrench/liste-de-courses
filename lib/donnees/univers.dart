import 'package:flutter/material.dart';

// Univers (domaines) : regroupement des rayons au-dessus d'eux, seulement pour présenter le catalogue
// (Gérer › Catalogue). Absent des listes et des courses (31/10/2026).
// 08/11/2026 (Aristide) : ils font partie du catalogue commun (« univers ») ; l'éditeur les règle dans la console.
// Faute de catalogue reçu, l'application garde ceux d'origine ci-dessous.

const universParDefaut = <String, List<String>>{
  'Produits frais': [
    'Fruits et légumes', 'Boucherie', 'Volaille', 'Poissonnerie', 'Crèmerie', 'Fromagerie', 'Charcuterie', 'Traiteur', //
    'Boulangerie', 'Viennoiserie et pâtisserie',
  ],
  'Épicerie et boissons': [
    'Épicerie salée', 'Bio, vrac et terroir', 'Apéritif', 'Cuisine du monde', 'Petit-déjeuner', 'Biscuits et sucré', //
    'Eaux et boissons sans alcool', 'Cave', 'Animaux',
  ],
  'Surgelés': ['Surgelés', 'Glaces'],
  'Droguerie, parfumerie, hygiène': ['Entretien / Droguerie', 'Parfumerie et soins', 'Hygiène', 'Parapharmacie', 'Bébé'],
  'Textile et habillement': ['Textile'],
  'Équipement de la maison': ['Cuisine et arts de la table', 'Électroménager et décoration'],
  'Bricolage, auto et jardin': ['Bricolage, auto et jardin'],
  'Culture, papeterie et jouets': ['Loisirs'],
  'Espace saisonnier': ['Saisonnier'],
};

final _univers = copieUnivers(universParDefaut);

/// Univers en vigueur (ceux du catalogue commun reçu, sinon ceux d'origine), dans leur ordre.
Map<String, List<String>> get universDesRayons => _univers;

Map<String, List<String>> copieUnivers(Map<String, List<String>> m) => {for (final e in m.entries) e.key: [...e.value]};

/// Remplace les univers en vigueur ; vide ou absent : ceux d'origine.
void remplacerUnivers(Map<String, List<String>>? m) {
  _univers
    ..clear()
    ..addAll(copieUnivers(m == null || m.isEmpty ? universParDefaut : m));
}

/// Univers lus dans le catalogue commun : [{nom, rayons: [...]}, ...] ; null s'il n'y en a pas.
Map<String, List<String>>? lireUnivers(Object? j) {
  if (j is! List) return null;
  final m = <String, List<String>>{
    for (final o in j)
      if (o is Map && o['nom'] is String) o['nom'] as String: [for (final r in (o['rayons'] as List? ?? const [])) '$r'],
  };
  return m.isEmpty ? null : m;
}

List<Map<String, Object>> universVersJson(Map<String, List<String>> m) => [
      for (final e in m.entries) {'nom': e.key, 'rayons': [...e.value]},
    ];

/// Univers d'un rayon ; « Autres rayons » pour un rayon créé par un foyer sans univers choisi.
/// Univers d'un rayon ; [choisis] : univers choisis par le foyer pour ses rayons ajoutés.
String universDuRayon(String rayon, [Map<String, String> choisis = const {}]) {
  if (choisis[rayon] case final u? when universDesRayons.containsKey(u) || u == autresRayons) return u;
  for (final e in universDesRayons.entries) {
    if (e.value.contains(rayon)) return e.key;
  }
  return autresRayons;
}

const autresRayons = 'Autres rayons';

/// Icône et couleur de fond du bandeau de chaque univers (01/11/2026, demandé par Aristide).
const apparenceUnivers = <String, (IconData, Color)>{
  'Produits frais': (Icons.eco_outlined, Color(0xFF2E7D32)),
  'Épicerie et boissons': (Icons.shopping_basket_outlined, Color(0xFF8D5524)),
  'Surgelés': (Icons.ac_unit, Color(0xFF1565C0)),
  'Droguerie, parfumerie, hygiène': (Icons.soap_outlined, Color(0xFF6A1B9A)),
  'Textile et habillement': (Icons.checkroom_outlined, Color(0xFFAD1457)),
  'Équipement de la maison': (Icons.chair_outlined, Color(0xFF00695C)),
  'Bricolage, auto et jardin': (Icons.handyman_outlined, Color(0xFFD84315)),
  'Culture, papeterie et jouets': (Icons.menu_book_outlined, Color(0xFF283593)),
  'Espace saisonnier': (Icons.celebration_outlined, Color(0xFFC62828)),
  autresRayons: (Icons.category_outlined, Color(0xFF546E7A)),
};
