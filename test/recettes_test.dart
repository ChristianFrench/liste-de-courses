// Console › Catalogue des recettes (10/11/2026) : découpage ingrédients / préparation des notes Keep et import
// dans une base séparée, mise à jour sans doublon.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/recettes.dart';
import 'package:liste_de_courses/donnees/recettes_communes.dart';
import 'package:liste_de_courses/ecrans/console_recettes_edition.dart';

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
         'preparation': '1. Fondre.', 'photos': [], 'etapes': ['Faire fondre le chocolat.'], 'pour': '6 personnes', 'source': 'Emplettes'},
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
    expect(b.recettes.first.pour, '6 personnes');
    expect(b.recettes.first.source, 'Emplettes');
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

  test('recettes livrées : 597, temps de préparation et de cuisson, difficulté', () {
    final j = jsonDecode(File('outils/recettes/illustrations/recettes-fournies.json').readAsStringSync()) as Map<String, dynamic>;
    final r = [for (final x in j['recettes'] as List) Recette.lire(x as Map<String, dynamic>)];
    expect(r.length, 597);
    final poulet = r.firstWhere((x) => x.titre == 'Poulet aux champignons et cidre');
    expect(poulet.tempsPreparation, 20);
    expect(poulet.tempsCuisson, 40);
    expect(poulet.pour, '4 personnes');
    expect(poulet.repereTemps, 'Préparation 20 min · Cuisson 40 min · Facile');
    expect(Recette.lire(poulet.versJson()).difficulte, 'Facile');
    for (final x in r.where((x) => !x.memo)) {
      expect(niveauxDifficulte, contains(x.difficulte), reason: x.titre);
    }
    expect(poulet.regimes, contains('Sans gluten'));
    expect(poulet.cuissons, isNotEmpty);
    expect(poulet.cout, isNotNull);
    expect(Recette.lire(poulet.versJson()).occasions, poulet.occasions);
    expect(r.firstWhere((x) => x.titre == 'Houmous').regimes, contains('Végétalien'));
    expect(dureeRecette(70), '1 h 10');
    expect(dureeRecette(120), '2 h');
  });

  test('classement livré : 9 types, un sous-type par type, origine (21/11/2026)', () {
    final j = jsonDecode(File('outils/recettes/illustrations/recettes-fournies.json').readAsStringSync()) as Map<String, dynamic>;
    final r = [for (final x in j['recettes'] as List) Recette.lire(x as Map<String, dynamic>)];
    for (final x in r) {
      expect(x.types, isNotEmpty, reason: x.titre);
      for (final t in x.types) {
        expect(typesRecettes[t], contains(x.sousTypes[t]), reason: '${x.titre} : $t');
      }
      expect(originesRecettes, contains(x.origine), reason: x.titre);
    }
    final tikka = r.firstWhere((x) => x.titre == 'Poulet tikka masala');
    expect(tikka.sousTypes, {'Plats': 'Volaille'});
    expect(tikka.origine, 'Inde');
    expect(tikka.classement, ['Plats · Volaille']);
    expect(Recette.lire(tikka.versJson()).sousTypes, tikka.sousTypes);
    expect(r.firstWhere((x) => x.memo).types, ['Bases culinaires']);
    expect(r.firstWhere((x) => x.titre == 'Sauce caramel au beurre salé').types, ['Sauces', 'Dessert']);
    final b = BaseRecettes(Directory.systemTemp, r);
    expect(b.parType().keys.first, 'Apéritif');
    expect(b.parType().keys.last, 'Bases culinaires');
  });

  test('versions des recettes : journal, valider, revenir, changements depuis la publication', () async {
    final d = Directory.systemTemp.createTempSync('recettes-versions');
    Recette r(String id, String titre) =>
        Recette(id: id, titre: titre, types: ['Plats'], ingredients: const [], preparation: '', photos: const []);
    final b = BaseRecettes(d, [r('a', 'Gratin'), r('b', 'Soupe')]);
    await b.demarrerJournal();
    expect(b.journal.etapes.single.nom, 'Point de départ');
    expect(RecettesCommunes.aPublier(b), isTrue);
    expect(RecettesCommunes.libelleSuivant(b), '1.0');

    final avant = b.recettes.first;
    final apres = avant.copie()
      ..titre = 'Gratin dauphinois'
      ..tempsCuisson = 60;
    await b.modifier(avant, apres);
    expect(b.enCours, 1);
    expect(b.journal.enCours.single.lignes.single, 'Recette modifiée : Gratin → Gratin dauphinois (titre, cuisson)');
    expect(b.recettes.first.retouchee, isTrue);
    await b.supprimer(b.recettes.last);
    await b.valider('Essai');
    expect(b.enCours, 0);
    expect(b.journal.etapes.length, 2);

    // Relue du disque : journal compris.
    final relue = await BaseRecettes.ouvrir(dossier: d);
    expect(relue.journal.etapes.map((e) => e.nom), ['Point de départ', 'Essai']);
    expect(relue.recettes.map((x) => x.titre), ['Gratin dauphinois']);

    await relue.revenirA(0);
    expect(relue.recettes.map((x) => x.titre), ['Gratin', 'Soupe']);

    // Après une publication, seuls les écarts comptent.
    relue.publiee = {
      'numero': 1,
      'libelle': '1.0',
      'empreintes': {for (final x in relue.recettes) x.id: RecettesCommunes.empreinteRecette(x)},
      'titres': {for (final x in relue.recettes) x.id: x.titre},
    };
    expect(RecettesCommunes.aPublier(relue), isFalse);
    expect(RecettesCommunes.libelleSuivant(relue), '1.1');
    relue.recettes.removeLast();
    relue.recettes.add(r(relue.nouvelIdentifiant('Tarte'), 'Tarte'));
    final (a, m, s) = RecettesCommunes.changements(relue);
    expect(a, ['Tarte']);
    expect(m, isEmpty);
    expect(s, ['Soupe']);
    final (contenu, _) = await RecettesCommunes.contenu(relue);
    expect((contenu['recettes'] as List).first, isNot(contains('retouchee')));
  });

  test('ingrédient en une ligne « Nom · quantité · précision »', () {
    final i = lireLigneIngredient('Pommes de terre · 1 kg · type Charlotte')!;
    expect((i.nom, i.quantite, i.precision), ('Pommes de terre', '1 kg', 'type Charlotte'));
    expect(ligneIngredient(i), 'Pommes de terre · 1 kg · type Charlotte');
    expect(ligneIngredient(IngredientRecette('Sel')), 'Sel');
    expect(lireLigneIngredient('  '), isNull);
  });
}
