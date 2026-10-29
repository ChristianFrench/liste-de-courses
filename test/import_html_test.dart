import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/import_texte.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  test('HTML d\'un mail Gmail ramené à une ligne par article', () {
    const html = '<div dir="ltr"><div>Liste de courses &middot; Carrefour</div><div><br></div>'
        '<div><b>BOUCHERIE</b></div><div>- Steak hach&eacute; Bigard,&nbsp;lot de 2</div>'
        '<ul><li>Poulet entier</li><li>Cr&#232;me fra&#xEE;che</li></ul></div>';
    expect(depuisHtml(html).split('\n'), [
      'Liste de courses · Carrefour',
      'BOUCHERIE',
      '- Steak haché Bigard, lot de 2',
      'Poulet entier',
      'Crème fraîche',
    ]);
  });

  test('un texte simple reste tel quel', () {
    expect(depuisHtml('Lait\n2 baguettes\nTomates <3'), 'Lait\n2 baguettes\nTomates <3');
  });

  test('titres de rayon et de secteur : produits rangés dessous, compte rendu', () {
    final e = Etat.instance
      ..enregistrementActif = false
      ..lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    final rapport = <Difficulte>[];
    final lus = lireTexte(e, 'FRUITS ET LÉGUMES\n- Pommes\n- Kakis\n\nCharcuterie :\n- Saucisson brioché\n\nANIMAUX\n- Croquettes\n',
        rapport: rapport);
    expect(lus.map((a) => a.nom), ['Pommes', 'Kakis', 'Saucisson brioché', 'Croquettes']);
    expect(lus[0].produit?.nom, 'Pommes');
    expect(lus[1].produit, isNull);
    expect(lus[1].secteur?.nom, 'Fruits et légumes', reason: 'produit inconnu rangé sous son titre');
    expect(lus[2].secteur?.nom, 'Charcuterie');
    expect(lus[3].secteur, isNull, reason: 'ANIMAUX n\'est pas du catalogue : plus de titre');
    final textes = rapport.map((d) => '${d.ligne} : ${d.explication}').join('\n');
    expect(textes, contains('FRUITS ET LÉGUMES : Titre reconnu : Frais › Fruits et légumes.'));
    expect(textes, contains('Kakis : Produit inconnu : sera créé dans Frais › Fruits et légumes.'));
    expect(textes, contains('ANIMAUX : En capitales mais inconnu'));
  });
}
