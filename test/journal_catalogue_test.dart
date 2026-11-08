import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:liste_de_courses/donnees/images_perso.dart';
import 'package:liste_de_courses/composants/pictogramme.dart';
import 'package:liste_de_courses/donnees/catalogue_commun.dart';
import 'package:liste_de_courses/donnees/journal_catalogue.dart';
import 'package:liste_de_courses/donnees/univers.dart';
import 'package:liste_de_courses/ecrans/editeur_catalogue.dart';

Map<String, dynamic> cat(Map<String, Map<String, List<String>>> r, {List<Map<String, dynamic>> renommes = const []}) => {
      'rayons': [
        for (final e in r.entries)
          {
            'nom': e.key,
            'secteurs': [
              for (final s in e.value.entries) {'nom': s.key, 'taille': 1, 'produits': [for (final p in s.value) {'nom': p, 'taille': 1}]}
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

  test('console : produit déplacé, icônes proposées et état', () {
    final b = Brouillon.lire(cat({'Frais': {'Fruits': ['Pommes'], 'Légumes': []}}));
    final fruits = b.catalogue.rayons.single.secteurs.first, legumes = b.catalogue.rayons.single.secteurs.last;
    expect(b.deplacerProduit(fruits, fruits.produits.single, legumes), isTrue);
    expect(legumes.produits.single.nom, 'Pommes');
    expect(propositionsIcone('Chats', ['Croquettes']), isNotEmpty);
    expect(etatIconeSecteur('Animaux', 'Chats', const {}), EtatIcone.exacte);
    expect(etatIconeSecteur('Animaux', 'Chats', {cleChoixSecteur('Animaux', 'Chats'): 'reserve--cafe'}), EtatIcone.choisie);
  });

  test('console : secteur en rayon, rayon en secteur', () {
    final b = Brouillon.lire(cat({'Frais': {'Fruits': ['Pommes'], 'Légumes': ['Ail']}, 'Épicerie': {'Pâtes': ['Penne']}}));
    final frais = b.rayon('Frais')!;
    final r = b.secteurEnRayon(frais, b.secteur(frais, 'Fruits')!);
    expect([for (final x in b.catalogue.rayons) x.nom], ['Frais', 'Fruits', 'Épicerie']);
    expect(r.secteurs.single.nom, 'Fruits');
    expect(r.secteurs.single.produits.single.nom, 'Pommes');
    final s = b.rayonEnSecteur(b.rayon('Frais')!, b.rayon('Épicerie')!);
    expect(b.rayon('Frais'), isNull);
    expect(s.nom, 'Frais');
    expect([for (final p in s.produits) p.nom], ['Ail']);
    expect([for (final x in b.rayon('Épicerie')!.secteurs) x.nom], ['Pâtes', 'Frais']);
  });

  test('images ajoutées : mise à la taille, bibliothèque, historique', () {
    // Un carré rouge sur un grand fond blanc : fond transparent, carré centré et agrandi dans 96 × 96.
    final src = img.Image(width: 300, height: 200);
    img.fill(src, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(src, x1: 100, y1: 50, x2: 160, y2: 110, color: img.ColorRgb8(220, 30, 30));
    final png = preparerImagePerso(Uint8List.fromList(img.encodePng(src)))!;
    final r = img.decodePng(png)!;
    expect([r.width, r.height], [96, 96]);
    expect(r.getPixel(2, 2).a, 0);
    expect(r.getPixel(48, 48).r, greaterThan(200));
    expect(preparerImagePerso(Uint8List.fromList([1, 2, 3])), isNull);

    final b = Brouillon.lire(cat({'Frais': {'Fruits': ['Pommes']}}));
    final avant = b.versJson();
    final cle = b.ajouterImagePerso('Pot de miel', png);
    expect(cle, 'perso--pot-de-miel');
    b.choisirImage('frais', cle);
    expect(gestesEntre(avant, b.versJson()), contains('Image ajoutée à la bibliothèque : Pot de miel'));
    expect(b.versJsonSansImages().containsKey('imagesPerso'), isFalse);
    expect(Brouillon.lire(b.versJson()).imagesPerso[cle]!.texte, 'Pot de miel');
    final nouvelle = b.renommerImagePerso(cle, 'Miel');
    expect(b.images['frais'], nouvelle);
    b.retirerImagePerso(nouvelle);
    expect(b.images.containsKey('frais'), isFalse);
  });

  test('secteurs au comptoir : icône composée (libre-service + sonnette)', () {
    expect(cleSecteur('Fromagerie', 'Fromages au comptoir'), 'fromagerie--fromages-au-comptoir');
    expect(cleSecteur('Boucherie', 'Viandes et volailles au comptoir'), 'boucherie--viandes-et-volailles-au-comptoir');
    expect(cleSecteur('Volaille', 'Rôtisserie'), 'volaille--rotisserie');
    expect(etatIconeSecteur('Traiteur', 'Traiteur au comptoir', const {}), EtatIcone.exacte);
  });

  test('icônes maison des rayons', () {
    expect(cleRayon('Saisonnier'), 'saisonnier');
    for (final u in universDesRayons.keys) {
      expect(cleUnivers(u), isNotNull, reason: u);
    }
    expect(cleUnivers(autresRayons), isNull);
    expect(etatIconeRayon('Saisonnier', const {}), EtatIcone.exacte);
    expect(cleRayon('Entretien / Droguerie'), 'entretien-droguerie');
  });
}
