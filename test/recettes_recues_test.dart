// Catalogue commun des recettes reçu par l'application (20/11/2026) : une version publiée remplace les recettes
// embarquées, garde les images déjà présentes, et prépare la fenêtre « Nouveautés ».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/recette_ingredients.dart';
import 'package:liste_de_courses/donnees/recettes_recues.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('une version reçue remplace les recettes, images embarquées reprises, nouveautés', () async {
    final dossier = Directory.systemTemp.createTempSync('recettes');
    await Etat.instance.charger(dossier: dossier);
    final embarquees = await recettesFournies();
    expect(embarquees.length, greaterThan(400));
    final accras = embarquees.firstWhere((r) => r.titre == 'Accras de morue');
    expect(accras.id, isNotNull);
    final empreintes = await empreintesEmbarquees();
    expect(empreintes.length, greaterThan(400));
    // La version publiée par la console : format de la console (ingrédients en texte, « detail »).
    final e = empreintes.first;
    final version = {
      'numero': 1,
      'libelle': '1.0',
      'recettes': [
        {
          'id': accras.id,
          'titre': 'Accras de morue',
          'types': ['Entrée'],
          'sousTypes': {'Entrée': 'Entrée chaude'},
          'ingredients': ['250 g Morue'],
          'detail': [
            {'nom': 'Morue', 'quantite': '250 g'}
          ],
          'pour': '4 personnes',
          'etapes': ['Dessaler la morue.'],
          'image': 'ffffffffffffffff',
        },
        {
          'id': 'emplettes-nouvelle',
          'titre': 'Zeste de nouveauté',
          'types': ['Dessert'],
          'ingredients': ['Citron'],
          'image': e,
        },
      ],
    };
    // 22/11/2026 : une version d'avant le classement (sans sous-types) ne remplace pas les recettes embarquées.
    final ancienne = {
      'numero': 1,
      'recettes': [
        {'titre': 'Ancienne', 'types': ['Entrée'], 'ingredients': ['Sel']},
      ],
    };
    await RecettesRecues.instance.appliquer(ancienne);
    expect((await recettesFournies()).length, embarquees.length);
    await RecettesRecues.instance.appliquer(version);
    final recues = await recettesFournies();
    expect(recues.map((r) => r.titre), ['Accras de morue', 'Zeste de nouveauté']);
    expect(recues.first.ingredients, ['250 g Morue']);
    expect(recues.first.ingredientsPour(8), ['500 g Morue']);
    // Image pas encore reçue : celle embarquée de la même recette ; empreinte embarquée : reprise.
    expect(recues.first.image, accras.image);
    expect(recues.last.image, startsWith('assets/recettes/illustrations/'));
    final (v, resume, lignes) = RecettesRecues.instance.aMontrer!;
    expect(v, '1.0');
    expect(resume, contains('1 ajoutée'));
    expect(resume, contains('1 modifiée'));
    expect(lignes, contains('Nouvelle : Zeste de nouveauté'));
    RecettesRecues.instance.nouveautesVues();
    expect(RecettesRecues.instance.aMontrer, isNull);
  });
}
