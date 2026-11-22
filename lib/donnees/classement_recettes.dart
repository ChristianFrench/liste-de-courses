// Classement des recettes (types, sous-types, origines), commun à la console et à l'application (sans dart:io,
// pour le web). Déplacé de recettes.dart le 22/11/2026.

/// Les 9 types et leurs sous-types (21/11/2026, Aristide : « ajouter un niveau dans le classement »), dans
/// l'ordre d'affichage. Source du classement livré : outils/recettes/classement.py.
const typesRecettes = <String, List<String>>{
  'Apéritif': ['Amuse-bouche', 'Tartinade et dip', 'Bouchées et feuilletés'],
  'Entrée': ['Soupe et velouté', 'Salade composée', 'Entrée froide', 'Entrée chaude'],
  'Plats': ['Viande', 'Volaille', 'Poisson et fruits de mer', 'Végétarien'],
  'Plats complets': ['Gratin et lasagnes', 'Mijoté complet', 'Tarte salée et pizza', 'Riz et pâtes garnis', 'Bowl et salade-repas'],
  'Plats accompagnement': ['Légumes', 'Féculents', 'Légumineuses'],
  'Sauces': ['Sauce chaude', 'Sauce froide et vinaigrette', 'Condiment', 'Sauce sucrée'],
  'Dessert': ['Gâteau', 'Tarte', 'Crème et mousse', 'Fruits', 'Glace', 'Sauce sucrée'],
  'Petit-déjeuner et goûter': ['Crêpes et gaufres', 'Biscuits et petits gâteaux', 'Brioches et viennoiseries', 'Pains',
      'Confitures et pâtes à tartiner'],
  'Bases culinaires': ['Pâtes', 'Fonds et bouillons', 'Crèmes de base', 'Mémos techniques'],
};

/// Origines d'une recette (21/11/2026), une par recette.
const originesRecettes = [
  'France', 'Italie', 'Espagne et Portugal', "Autres pays d'Europe", 'Maghreb et Moyen-Orient', 'Afrique', 'Inde', 'Asie',
  'Amériques',
];

/// Rang d'un sous-type dans son type (les sous-types inconnus ou absents à la fin).
int rangSousType(String type, String? sousType) {
  final i = (typesRecettes[type] ?? const <String>[]).indexOf(sousType ?? '');
  return i >= 0 ? i : 999;
}

/// Les 9 types dans l'ordre d'affichage.
const typesRecettesOrdre = ['Apéritif', 'Entrée', 'Plats', 'Plats complets', 'Plats accompagnement', 'Sauces', 'Dessert',
    'Petit-déjeuner et goûter', 'Bases culinaires'];

/// Rang d'un type : l'ordre de [typesRecettes], puis les autres, « Autres recettes » à la fin.
int rangTypeRecette(String t) {
  final i = typesRecettesOrdre.indexOf(t);
  return i >= 0 ? i : (t.startsWith('Autres') ? 1000 : 999);
}
