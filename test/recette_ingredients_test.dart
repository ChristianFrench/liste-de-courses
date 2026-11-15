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
}
