import 'package:flutter/material.dart';

// Univers : regroupement des rayons au-dessus d'eux, seulement pour présenter le catalogue
// (Gérer › Catalogue). Absent des listes et des courses (31/10/2026).

const universDesRayons = <String, List<String>>{
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
