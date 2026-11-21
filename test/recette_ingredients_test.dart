import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/recette_ingredients.dart';

void main() {
  test('nom d\'un ingrédient : quantité, unité et précisions retirées', () {
    expect(nomIngredient("3 à 4 c. à soupe Huile d'olive (de qualité)"), "Huile d'olive");
    expect(nomIngredient('200 g de lardons fumés'), 'Lardons fumés');
    expect(nomIngredient("1 kg Pommes de terre"), 'Pommes de terre');
    expect(nomIngredient("3 gousses d'ail"), 'Ail');
    expect(nomIngredient('20 cl de crème fraîche épaisse'), 'Crème fraîche épaisse');
    expect(nomIngredient('½ cuillère à café de sel'), 'Sel');
    expect(nomIngredient('- 3 œufs'), 'Œufs');
    expect(nomIngredient('1 pincée de noix de muscade'), 'Noix de muscade');
    expect(nomIngredient('Persil : facultatif'), 'Persil');
  });

  test('produits du placard', () {
    for (final n in ['Sel', 'Poivre', "Huile d'olive", 'Farine', 'Sucre vanillé', 'Noix de muscade', 'Gros sel']) {
      expect(estDuPlacard(n), isTrue, reason: n);
    }
    for (final n in ['Lardons', 'Œufs', 'Crème fraîche', 'Pommes de terre', 'Noix']) {
      expect(estDuPlacard(n), isFalse, reason: n);
    }
  });

  test('recette en texte : lignes entre Ingrédients et Préparation', () {
    final r = lireRecetteTexte('Quiche lorraine\nPour 4 personnes\nIngrédients\n200 g de lardons\n3 œufs\n'
        '20 cl de crème\nPréparation\n1. Préchauffer le four à 180 °C et étaler la pâte dans le moule.');
    expect(r.titre, 'Quiche lorraine');
    expect(r.ingredients, ['200 g de lardons', '3 œufs', '20 cl de crème']);
    final s = lireRecetteTexte('Crêpes\n250 g de farine\n4 œufs\n1/2 l de lait');
    expect(s.titre, 'Crêpes');
    expect(s.ingredients, ['250 g de farine', '4 œufs', '1/2 l de lait']);
  });

  test('page internet : données schema.org Recipe', () {
    const page = '<html><head><title>Blanquette</title><script type="application/ld+json">'
        '{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},{"@type":"Recipe","name":"Blanquette de veau",'
        '"recipeIngredient":["1 kg de veau","2 carottes","200 g de champignons de Paris","1 oignon"]}]}'
        '</script></head><body></body></html>';
    final r = recetteDansPage(page)!;
    expect(r.titre, 'Blanquette de veau');
    expect(r.ingredients.length, 4);
    expect(nomIngredient(r.ingredients[2]), 'Champignons de Paris');
  });

  test('20/11/2026 : quantités pour un autre nombre de personnes, durées, filtres', () {
    expect(ajusterQuantite('200 g', 1.5), '300 g');
    expect(ajusterQuantite('3', 0.5), '2');
    expect(ajusterQuantite('2 à 3 gousses', 2), '4 à 6 gousses');
    expect(ajusterQuantite('1 cuillère à soupe', 1.5), '1,5 cuillère à soupe');
    expect(ajusterQuantite('1 cuillère à soupe', 0.5), '½ cuillère à soupe');
    expect(ajusterQuantite('1,5 kg', 2), '3 kg');
    expect(ajusterQuantite('au goût', 2), 'au goût');
    expect(duree(20), '20 min');
    expect(duree(70), '1 h 10');
    expect(duree(60), '1 h');
    const r = RecetteLue('Crème', ['550 ml Lait', 'Sel'],
        quantites: ['550 ml', null],
        pour: '4 personnes',
        types: ['Dessert'],
        tempsPreparation: 15,
        tempsCuisson: 0,
        difficulte: 'Facile',
        saisons: ['Printemps', 'Été', 'Automne', 'Hiver'],
        regimes: ['Végétarien'],
        cuissons: ['Sans cuisson'],
        cout: '€');
    expect(r.personnes, 4);
    expect(r.pourN(1), '1 personne');
    expect(r.ingredientsPour(2), ['275 ml Lait', 'Sel']);
    expect(r.ligneEnTete, 'Pour 4 personnes · Préparation 15 min · Sans cuisson · Facile');
    expect(r.pastilles, ['Végétarien', 'Toute l\'année', '€']);
    const maison = RecetteLue('Gratin', ['Pommes de terre'], types: ['Plats']);
    final f = FiltreRecettes();
    expect(f.garde(r) && f.garde(maison), isTrue);
    f.texte = 'lait';
    expect(f.garde(r), isTrue, reason: 'un ingrédient trouve la recette');
    expect(f.garde(maison), isFalse);
    f.texte = '';
    f.choix['Type']!.addAll(['Dessert', 'Plats']);
    expect(f.garde(r) && f.garde(maison), isTrue, reason: '« ou » dans un critère');
    f.choix['Régime']!.add('Végétarien');
    expect(f.garde(maison), isFalse, reason: '« et » entre critères');
    f.effacer();
    f.choix['Temps']!.add('Moins de 30 min');
    expect(f.garde(r), isTrue);
    expect(f.garde(maison), isFalse, reason: 'sans temps : écartée par un filtre de temps seulement');
    expect(FiltreRecettes.saisonDu(DateTime(2026, 11, 20)), 'Automne');
  });
}
