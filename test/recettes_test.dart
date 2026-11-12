// Console › Catalogue des recettes (10/11/2026) : découpage ingrédients / préparation des notes Keep et import
// dans une base séparée, mise à jour sans doublon.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/recettes.dart';

void main() {
  test('découpage : titre, ingrédients à tirets, préparation', () {
    final (t, ing, prep) = decouperRecette('Pour 4 personnes\nIngrédients :\n- un kg de pommes de terre\n- 3 gousses d’ail\n\n'
        '- Sel et poivre\n\nCuire les pommes de terre dans l’eau bouillante salée pendant vingt minutes environ.\nÉgoutter.');
    expect(t, 'Ingrédients :');
    expect(ing, ['un kg de pommes de terre', '3 gousses d’ail', 'Sel et poivre']);
    expect(prep, startsWith('Pour 4 personnes\n\nCuire'));
    expect(prep, endsWith('Égoutter.'));
    // Variante sans accent, étapes numérotées qui arrêtent la liste.
    final (_, ing2, prep2) = decouperRecette('INGREDIENTS (pour 2)\nBeurre\nFarine\n1. Mélanger le tout.');
    expect(ing2, ['Beurre', 'Farine']);
    expect(prep2, '1. Mélanger le tout.');
    // Sans titre : tout est préparation.
    final (t3, ing3, prep3) = decouperRecette('Haricots verts : 5 min\nPommes de terre : 8 min');
    expect(t3, isNull);
    expect(ing3, isEmpty);
    expect(prep3, contains('Haricots'));
    expect(typeDuLibelle('Recettes Plats Accompagnement'), 'Plats accompagnement');
    expect(typeDuLibelle('Recettes Entrée'), 'Entrée');
    expect(slugRecette('Mousse au chocolat sans œufs'), 'mousse-au-chocolat-sans-oeufs');
    expect(slugRecette("Écrasé de pommes de terre à l'huile d'olive"), 'ecrase-de-pommes-de-terre-a-l-huile-d-olive');
    // Les desserts en dernier.
    final base = BaseRecettes(Directory.systemTemp)
      ..recettes.addAll([
        for (final t in ['Dessert', 'Sauces', 'Entrée', 'Plats'])
          Recette(id: t, titre: t, types: [t], ingredients: const [], preparation: '', photos: const []),
      ]);
    expect(base.parType().keys, ['Entrée', 'Plats', 'Sauces', 'Dessert']);
  });

  test('import Keep : notes « Recettes », photos copiées, mise à jour sans doublon', () async {
    final source = Directory.systemTemp.createTempSync('keep');
    final dest = Directory.systemTemp.createTempSync('base');
    File('${source.path}/photo.jpg').writeAsBytesSync([1, 2, 3]);
    Map<String, dynamic> note(String titre) => {
          'title': titre,
          'textContent': 'Ingrédients :\n- œufs\n- lait\n\nBattre les œufs avec le lait, puis cuire doucement à la poêle.',
          'createdTimestampUsec': 1757943863867000,
          'userEditedTimestampUsec': 1757944284385000,
          'attachments': [
            {'filePath': 'photo.jpg', 'mimetype': 'image/jpeg'}
          ],
          'labels': [
            {'name': 'Recettes Plats'},
            {'name': 'Recettes Plats Accompagnement'}
          ],
        };
    File('${source.path}/Œufs brouillés.json').writeAsStringSync(jsonEncode(note('Œufs brouillés')));
    File('${source.path}/Courses.json').writeAsStringSync(jsonEncode({'title': 'Courses', 'textContent': 'pain', 'labels': []}));
    final b = BaseRecettes(dest);
    final bilan = await b.importerKeep(source);
    expect(bilan.ajoutees, 1);
    expect(bilan.ignorees, 1);
    expect(b.recettes.single.ingredients, ['œufs', 'lait']);
    expect(b.recettes.single.types, ['Plats', 'Plats accompagnement']);
    expect(b.photo('photo.jpg').existsSync(), isTrue);
    expect(b.parType().keys, ['Plats', 'Plats accompagnement']);
    // Deuxième import de la même note, titre corrigé : mise à jour.
    File('${source.path}/Œufs brouillés.json').writeAsStringSync(jsonEncode(note('Œufs brouillés au lait')));
    final bilan2 = await b.importerKeep(source);
    expect(bilan2.misesAJour, 1);
    expect(b.recettes.single.titre, 'Œufs brouillés au lait');
    // Relue depuis le disque.
    final relue = await BaseRecettes.ouvrir(dossier: dest);
    expect(relue.recettes.single.titre, 'Œufs brouillés au lait');
    source.deleteSync(recursive: true);
    dest.deleteSync(recursive: true);
  });

  test('import Keep avec recettes-normalisees.json : quantité / nom / précision, étapes, remarques', () async {
    final source = Directory.systemTemp.createTempSync('keepn');
    final dest = Directory.systemTemp.createTempSync('basen');
    File('${source.path}/Ecrase.json').writeAsStringSync(jsonEncode({
      'title': 'ecrase',
      'textContent': 'patates, huile. Cuire.',
      'createdTimestampUsec': 42,
      'labels': [
        {'name': 'Recettes Plats'}
      ],
    }));
    File('${source.path}/$fichierNormalise').writeAsStringSync(jsonEncode([
      {
        'fichier': 'Ecrase.json',
        'titre': 'Écrasé de pommes de terre',
        'types': ['Plats', 'Plats Accompagnement'],
        'ingredients': [
          {'nom': 'Pommes de terre', 'quantite': '1 kg', 'precision': 'type Charlotte'},
          {'nom': 'Huile d\'olive', 'quantite': '', 'precision': ''},
        ],
        'etapes': ['Cuire les pommes de terre.', 'Écraser à la fourchette.'],
        'conseils': [],
        'remarques': ['Quantité d\'huile à préciser.'],
        'memo': false,
        'texte_origine': 'patates, huile. Cuire.',
      }
    ]));
    Directory('${source.path}/Illustrations').createSync();
    File('${source.path}/Illustrations/ecrase-de-pommes-de-terre.jpg').writeAsBytesSync([9, 9]);
    final b = BaseRecettes(dest);
    final bilan = await b.importerKeep(source);
    expect(bilan.ajoutees, 1);
    expect(bilan.normalisees, 1);
    expect(bilan.illustrations, 1);
    expect(b.recettes.single.illustration, startsWith('illustration-ecrase-de-pommes-de-terre'));
    expect(b.photo(b.recettes.single.illustration!).existsSync(), isTrue);
    final r = b.recettes.single;
    expect(r.id, 'keep-42');
    expect(r.titre, 'Écrasé de pommes de terre');
    expect(r.types, ['Plats', 'Plats accompagnement']);
    expect(r.detail.first.quantite, '1 kg');
    expect(r.ingredients, ['1 kg Pommes de terre (type Charlotte)', 'Huile d\'olive']);
    expect(r.etapes, hasLength(2));
    expect(r.remarques, hasLength(1));
    final relue = (await BaseRecettes.ouvrir(dossier: dest)).recettes.single;
    expect(relue.detail.last.nom, 'Huile d\'olive');
    expect(relue.etapes.last, 'Écraser à la fourchette.');
    expect(relue.texteOrigine, contains('patates'));
    source.deleteSync(recursive: true);
    dest.deleteSync(recursive: true);
  });

  test('illustrations livrées avec la console : posées par identifiant, une seule fois', () async {
    final fourni = Directory.systemTemp.createTempSync('fourni');
    final dest = Directory.systemTemp.createTempSync('basei');
    File('${fourni.path}/mousse.jpg').writeAsBytesSync([1, 2, 3]);
    File('${fourni.path}/illustrations.json').writeAsStringSync(jsonEncode({'keep-1': 'mousse.jpg'}));
    final b = BaseRecettes(dest)
      ..recettes.addAll([
        Recette(id: 'keep-1', titre: 'Mousse', types: const ['Dessert'], ingredients: const [], preparation: '', photos: const []),
        Recette(id: 'keep-2', titre: 'Autre', types: const ['Plats'], ingredients: const [], preparation: '', photos: const []),
      ]);
    expect(await b.appliquerIllustrationsFournies(fourni), 1);
    expect(b.recettes.first.illustration, isNotNull);
    expect(b.photo(b.recettes.first.illustration!).existsSync(), isTrue);
    expect(b.recettes.last.illustration, isNull);
    expect(await b.appliquerIllustrationsFournies(fourni), 0);
    final relue = await BaseRecettes.ouvrir(dossier: dest);
    expect(await relue.appliquerIllustrationsFournies(fourni), 0);
    fourni.deleteSync(recursive: true);
    dest.deleteSync(recursive: true);
  });

  test('recettes reformulées livrées avec la console : texte remplacé, photos Keep retirées, une fois', () async {
    final fourni = Directory.systemTemp.createTempSync('fournies');
    final dest = Directory.systemTemp.createTempSync('basef');
    File('${dest.path}/vieille.jpg').writeAsBytesSync([1]);
    File('${fourni.path}/recettes-fournies.json').writeAsStringSync(jsonEncode({
      'version': 1,
      'recettes': [
        {'id': 'keep-1', 'titre': 'Mousse au chocolat', 'types': ['Dessert'], 'ingredients': ['200 g Chocolat'],
         'preparation': '1. Fondre.', 'photos': [], 'etapes': ['Faire fondre le chocolat.']},
        {'id': 'keep-3', 'titre': 'Nouvelle', 'types': ['Plats'], 'ingredients': [], 'preparation': '', 'photos': []},
      ],
    }));
    final b = BaseRecettes(dest)
      ..recettes.add(Recette(id: 'keep-1', titre: 'mousse', types: const ['Dessert'], ingredients: const ['choco'],
          preparation: 'brut', photos: const ['vieille.jpg'], illustration: 'illustration-x.jpg'));
    File('${dest.path}/illustration-x.jpg').writeAsBytesSync([2]);
    expect(await b.appliquerRecettesFournies(fourni), 2);
    expect(b.recettes, hasLength(2));
    expect(b.recettes.first.titre, 'Mousse au chocolat');
    expect(b.recettes.first.etapes.single, 'Faire fondre le chocolat.');
    expect(b.recettes.first.photos, isEmpty);
    expect(b.recettes.first.illustration, 'illustration-x.jpg');
    expect(File('${dest.path}/vieille.jpg').existsSync(), isFalse);
    expect(File('${dest.path}/illustration-x.jpg').existsSync(), isTrue);
    final relue = await BaseRecettes.ouvrir(dossier: dest);
    expect(relue.versionFournie, 1);
    expect(await relue.appliquerRecettesFournies(fourni), 0);
    fourni.deleteSync(recursive: true);
    dest.deleteSync(recursive: true);
  });
}
