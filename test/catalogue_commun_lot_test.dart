import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';


// 06/11/2026 : recevoir la v1 du catalogue commun bloquait l'APK et l'exe (un enregistrement complet de la base
// par produit rangé). L'application d'un catalogue complet ne doit plus prévenir l'écran qu'une fois.
void main() {
  test('catalogue commun complet appliqué en un seul enregistrement', () {
    final e = Etat.instance..enregistrementActif = false;
    e.lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    final j = jsonDecode(File('assets/catalogue_type.json').readAsStringSync()) as Map<String, dynamic>;
    j['version'] = DateTime.now().millisecondsSinceEpoch;
    j['numero'] = 1;
    var avis = 0;
    void compter() => avis++;
    e.addListener(compter);
    final chrono = Stopwatch()..start();
    e.appliquerCatalogueCommun(j);
    chrono.stop();
    e.removeListener(compter);
    // ignore: avoid_print
    print('catalogue complet appliqué en ${chrono.elapsedMilliseconds} ms, $avis avis, ${e.produits.length} produits');
    expect(avis, 1);
    expect(e.numeroCatalogueCommun, 1);
    expect(chrono.elapsedMilliseconds, lessThan(5000));
  });
}
