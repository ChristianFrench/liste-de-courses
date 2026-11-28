// Contenu de départ d'un foyer neuf, et reprise d'un appareil qui affichait l'ancienne démonstration.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/stockage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un foyer neuf : six enseignes au catalogue complet et trois listes exemples', () async {
    final dossier = Directory.systemTemp.createTempSync('depart');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    expect(etat.magasins.map((m) => m.nom), Etat.enseignesDeDepart);
    for (final m in etat.magasins) {
      expect(etat.rayonsDu(m.id).length, greaterThan(25), reason: m.nom);
    }
    final exemples = etat.listes.where((l) => (l.nom ?? '').startsWith(Etat.prefixeExemple)).toList();
    expect(exemples.map((l) => l.statut), [StatutListe.enConstruction, StatutListe.prete, StatutListe.enCours]);
    expect(exemples.every((l) => l.lignes.length >= 6), isTrue);
    expect(exemples.last.interrompueLe, isNotNull);
    expect(exemples.last.nbCoches, 2);

    // Remettre les exemples ne les double pas.
    etat.creerExemples();
    expect(etat.listes.where((l) => (l.nom ?? '').startsWith(Etat.prefixeExemple)).length, 3);

    // Relu depuis la base.
    await etat.charger(dossier: dossier);
    expect(etat.listes.where((l) => (l.nom ?? '').startsWith(Etat.prefixeExemple)).length, 3);
  });

  test('l\'appareil qui affichait la démonstration la garde comme foyer', () async {
    final dossier = Directory.systemTemp.createTempSync('fusion');
    final demo = jsonDecode(File(Etat.fichierDonnees).readAsStringSync()) as Map<String, dynamic>;
    final d = Stockage.ouvrir('${dossier.path}/${Etat.baseDemo}')..ecrire(demo);
    d.fermer();
    final f = Stockage.ouvrir('${dossier.path}/${Etat.baseFoyer}');
    f.definirReglage('mode_demo', '1');
    f.fermer();
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    expect(etat.produits.length, (demo['produits'] as List).length);
    expect(etat.listes.length, (demo['listes'] as List).length);
    expect(File('${dossier.path}/${Etat.baseDemo}').existsSync(), isFalse);
    expect(dossier.listSync().any((e) => e.path.contains('.avant-fusion-')), isTrue);
    expect(etat.stockageFoyer!.reglage('mode_demo'), isNot('1'));
  });
}
