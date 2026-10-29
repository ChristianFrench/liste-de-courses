import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  test('changer le magasin et la date d\'une liste : le nom proposé suit, un nom choisi reste', () {
    final e = Etat.instance
      ..enregistrementActif = false
      ..lire(jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>);
    final l = e.listes.first;
    final m1 = e.magasins.first, m2 = e.magasins[1];
    final d1 = DateTime(2026, 11, 2), d2 = DateTime(2026, 11, 5);
    e.changerMagasinEtDate(l, m1.id, d1);
    e.renommerListeAuto(l, m1.id, d1);
    l.parcoursId = 'x';
    e.changerMagasinEtDate(l, m2.id, d2);
    expect(l.magasinId, m2.id);
    expect(e.datePrevue(l), d2);
    expect(l.nom, startsWith(e.nomPrevu(m2.id, d2)));
    expect(l.parcoursId, isNull);
    l.nom = 'Mes courses';
    e.changerMagasinEtDate(l, m1.id, d1);
    expect(l.nom, 'Mes courses');
  });
}

extension on Etat {
  void renommerListeAuto(Liste l, String m, DateTime d) => l.nom = nomPrevu(m, d);
}
