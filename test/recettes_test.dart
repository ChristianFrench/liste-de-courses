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
}
