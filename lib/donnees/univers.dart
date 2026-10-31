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

/// Univers d'un rayon ; « Autres rayons » pour un rayon créé par un foyer.
String universDuRayon(String rayon) {
  for (final e in universDesRayons.entries) {
    if (e.value.contains(rayon)) return e.key;
  }
  return autresRayons;
}

const autresRayons = 'Autres rayons';
