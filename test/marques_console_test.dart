// Console › Catalogue des marques (08/11/2026) : marques = déclinaisons des produits du catalogue commun,
// intégration des marques achetées par les foyers, cas « À examiner » trouvés seuls et leur correction.

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/catalogue_commun.dart';

void main() {
  Brouillon brouillon() => Brouillon.lire({
        'rayons': [
          {
            'nom': 'Frais',
            'secteurs': [
              {
                'nom': 'Yaourts',
                'taille': 1,
                'produits': [
                  {'nom': 'Yaourt nature', 'taille': 1, 'listes': 5, 'marques': ['Yaos', 'Danone']},
                  {'nom': 'Yaourt nature Danone', 'taille': 1, 'listes': 2, 'marques': ['Danone']},
                  {'nom': 'Yaourt aux fruits', 'taille': 1, 'marques': ['Danonne']},
                  {'nom': 'Yaourts aux fruits', 'taille': 1},
                ]
              }
            ]
          }
        ]
      });

  test('marques des produits, renommer, fusionner, retirer', () {
    final b = brouillon();
    final m = b.marquesDesProduits();
    expect(m.keys, ['Danone', 'Danonne', 'Yaos']);
    expect(m['Danone']!.map((x) => x.$3.nom), ['Yaourt nature', 'Yaourt nature Danone']);
    expect(b.renommerMarque('Danonne', 'Danone'), 1, reason: 'fusion');
    expect(b.marquesDesProduits().keys, ['Danone', 'Yaos']);
    expect(b.retirerMarque('Yaos'), 1);
    expect(b.marquesDesProduits().keys, ['Danone']);
  });

  test('marques achetées par les foyers : nouvelles, comptées, intégrées', () {
    final b = brouillon();
    final lots = <String, Map<String, dynamic>>{
      'a': {'Frais/Yaourts/Yaourt nature': ['Yaos', 'Activia']},
      'b': {'Frais/Yaourts/Yaourt nature': ['Activia'], 'Frais/Inconnu/Truc': ['X']},
    };
    final n = b.declinaisonsNouvelles(lots);
    expect(n.map((x) => (x.$3.nom, x.$4, x.$5)), [('Yaourt nature', 'Activia', 2)]);
    expect(b.integrerDeclinaisons(lots), 1);
    expect(b.declinaisonsNouvelles(lots), isEmpty);
    b.bloques.add('a');
    expect(b.declinaisonsNouvelles({'a': {'Frais/Yaourts/Yaourt aux fruits': ['Yoplait']}}), isEmpty, reason: 'foyer bloqué');
  });

  test('à examiner : marques en double, produit de marque, produits en double ; corriger, accepter', () {
    final b = brouillon();
    final x = b.aExaminer();
    expect(x.map((e) => e.type), containsAll([TypeExamen.marques, TypeExamen.produitDeMarque, TypeExamen.produits]));
    final pdm = x.firstWhere((e) => e.type == TypeExamen.produitDeMarque);
    expect(pdm.produit!.nom, 'Yaourt nature Danone');
    expect(b.corriger(pdm), contains('converti'));
    final s = b.catalogue.rayons.first.secteurs.first;
    expect(s.produits.map((p) => p.nom), isNot(contains('Yaourt nature Danone')));
    expect(s.produits.first.marques, contains('Danone'));
    expect(s.produits.first.listes, 7);
    final reste = b.aExaminer();
    expect(reste.any((e) => e.type == TypeExamen.produitDeMarque), isFalse);
    expect(b.aExaminer(acceptes: {for (final e in reste) e.cle}), isEmpty);
  });
}
