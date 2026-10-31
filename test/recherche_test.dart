// Recherche d'articles enrichie par Open Food Facts (31/10/2026) : classement par habitudes puis popularité,
// marques proposées par nature, recherche par marque.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/composants/recherche.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/univers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('popularité, marques de la nature et recherche par marque', () {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(jsonDecode(File(Etat.fichierDonnees).readAsStringSync()) as Map<String, dynamic>);
    final a = e.creerProduit('Pâte à tartiner chocolat');
    final b = e.creerProduit('Pâte à tartiner noisette');
    e.lireNaturesOff({
      'natures': {
        'Pâte à tartiner chocolat': {'n': 244, 'm': ['Bovetti']},
        'Pâte à tartiner noisette': {'n': 784, 'm': ['Nutella', 'Bonne Maman']},
      }
    });
    // À habitudes égales, la nature la plus courante d'abord ; puis la plus achetée par le foyer l'emporte.
    expect(chercherProduits([a, b], 'pâte à tar'), [b, a]);
    a.nbUtilisations = 3;
    expect(chercherProduits([a, b], 'pâte à tar'), [a, b]);
    // « nut » : la nature qui porte la marque Nutella.
    final m = chercherMarques([a, b], 'nut');
    expect(m.single.$1, b);
    expect(m.single.$2, 'Nutella');
    expect(chercherMarques([a, b], 'xyz'), isEmpty);
    // Les marques de la nature sont proposées dans la liste déroulante « Marque ».
    expect(e.marquesProposees(null, b), containsAll(['Nutella', 'Bonne Maman']));
    expect(e.marquesProposees(null, a), contains('Bovetti'));
  });

  test('le fichier Open Food Facts livré est lisible et raisonnable', () {
    final j = jsonDecode(File(Etat.fichierNaturesOff).readAsStringSync()) as Map<String, dynamic>;
    final e = Etat.instance..lireNaturesOff(j);
    expect(e.naturesOff.length, greaterThan(1000));
    expect(e.naturesOff.values.every((v) => v.marques.length <= 10), isTrue);
    expect(e.naturesOff['camembert']?.marques, contains('Président'));
  });

  test('chaque rayon du catalogue livré a son univers', () {
    final j = jsonDecode(File(Etat.fichierCatalogueType).readAsStringSync()) as Map<String, dynamic>;
    for (final r in (j['rayons'] as List).cast<Map>()) {
      expect(universDuRayon(r['nom'] as String), isNot(autresRayons), reason: r['nom'] as String);
    }
  });
}
