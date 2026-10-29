import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/import_texte.dart';

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
}
