import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/journal_catalogue.dart';
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';

Map<String, dynamic> cat(Map<String, Map<String, List<String>>> r, {List<Map<String, dynamic>> renommes = const []}) => {
      'rayons': [
        for (final e in r.entries)
          {
            'nom': e.key,
            'secteurs': [
              for (final s in e.value.entries) {'nom': s.key, 'produits': [for (final p in s.value) {'nom': p}]}
            ]
          }
      ],
      if (renommes.isNotEmpty) 'renommes': renommes,
    };

void main() {
  test('gestes lisibles : ajout, renommage, secteur déplacé', () {
    final a = cat({'Frais': {'Fruits': ['Pommes']}, 'Épicerie': {}});
    expect(gestesEntre(a, a), isEmpty);
    expect(gestesEntre(a, cat({'Frais': {'Fruits': ['Pommes', 'Kakis']}, 'Épicerie': {}})), ['Produit ajouté : Kakis (Frais › Fruits)']);
    expect(
        gestesEntre(a, cat({'Frais': {'Fruits': ['Pomme']}, 'Épicerie': {}}, renommes: [{'type': 'produit', 'ancien': 'Pommes', 'nouveau': 'Pomme'}])),
        ['Produit renommé : Pommes → Pomme']);
    expect(gestesEntre(a, cat({'Frais': {}, 'Épicerie': {'Fruits': ['Pommes']}})), ['Secteur déplacé : Fruits, de Frais vers Épicerie']);
  });

  test('étapes : valider, généraliser, revenir abandonne la suite', () {
    final j = JournalCatalogue([], []);
    j.valider('Point de départ', 'i0', numero: 3);
    j.noter(['Rayon ajouté : A']);
    j.valider('Étape 1', 'i1');
    j.noter(['Rayon ajouté : B']);
    final relu = JournalCatalogue.lire(j.ecrire());
    expect(relu.etapes.map((e) => e.nom), ['Point de départ', 'Étape 1']);
    expect(relu.enCours.single.lignes, ['Rayon ajouté : B']);
    relu.generalisee(4);
    expect(relu.etapes.map((e) => e.numero), [3, 4]);
    expect(relu.revenirA(0), 'i0');
    expect(relu.etapes, hasLength(1));
    expect(relu.enCours, isEmpty);
  });
}
