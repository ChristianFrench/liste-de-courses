// Foyer d'exemples de la version web de démonstration (…/liste-de-courses/demo/).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/demonstration.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('démonstration : membres, parcours appris, historique avec tickets, listes à tous les stades', () async {
    final dossier = Directory.systemTemp.createTempSync('demonstration');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    etat.remplirDemonstration();
    await etat.charger(dossier: dossier); // relu depuis la base

    expect(etat.foyerNom, 'Famille Martin');
    expect(etat.membres.map((m) => m.nomAffiche), containsAll(['Claire', 'Thomas', 'Léa', 'Hugo']));
    expect(etat.historique.length, 17);
    expect(etat.historique.first.dateCourses.isAfter(etat.historique.last.dateCourses), isTrue);
    expect(DateTime.now().difference(etat.historique.last.dateCourses).inDays, greaterThan(50));
    expect(etat.tickets.where((t) => t.montant > 0).length, 18);
    expect(etat.parcours.length, greaterThanOrEqualTo(6));
    expect(etat.listesTypes.map((t) => t.nom), containsAll(['Petit-déjeuner', 'Ménage du mois', 'Pour Mistigri']));
    final enVie = {for (final l in etat.listes.where((l) => l.statut != StatutListe.terminee)) l.nom: l};
    expect(enVie.keys, containsAll(['Courses de la semaine', 'Anniversaire de Léa', 'Dépannage', 'Apéro de samedi']));
    final semaine = enVie['Courses de la semaine']!;
    expect(semaine.lignes.where((g) => g.promotion != null).length, 3);
    expect(semaine.lignes.where((g) => g.consigne != null).length, 2);
    expect(semaine.lignes.any((g) => etat.produit(g.produitId)?.nom == 'Camembert Président'), isTrue);
    final depannage = enVie['Dépannage']!;
    expect(depannage.nbCoches, 4);
    expect(depannage.parcoursId, isNotNull);
    expect(enVie['Anniversaire de Léa']!.statut, StatutListe.prete);
  });
}
