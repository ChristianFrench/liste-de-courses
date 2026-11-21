// Sauvegarde aux jalons (03/11/2026) : copie seulement si les données ont changé, 3 dernières + une ancre,
// données relues à l'identique, restauration.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/modele.dart';
import 'package:liste_de_courses/donnees/sauvegarde.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('copies aux jalons, rangement, ouverture et restauration', () async {
    final d = Directory.systemTemp.createTempSync('sauvegardes');
    dossierSauvegardesEssai = d.path;
    final e = Etat.instance..enregistrementActif = false;
    e.lire(jsonDecode(File(Etat.fichierDonnees).readAsStringSync()) as Map<String, dynamic>);
    final s = Sauvegarde.instance;

    expect(await s.copier('Liste prête'), isTrue);
    expect(await s.copier('Liste prête'), isFalse, reason: 'rien n\'a changé');
    final nbProduits = e.produits.length;
    for (var i = 0; i < 5; i++) {
      e.creerProduit('Essai sauvegarde $i');
      expect(await s.copier('Catalogue modifié'), isTrue);
    }
    final copies = await s.liste();
    expect(copies.where((c) => !c.ancre).length, Sauvegarde.derniers);
    expect(copies.where((c) => c.ancre).length, 1);
    expect(d.listSync().length, 4);
    expect(copies.first.jalon, 'Catalogue modifié');
    expect(copies.first.compte['produits'], nbProduits + 5);

    // La copie la plus ancienne gardée (l'ancre) se rouvre et se restaure : un seul produit d'essai.
    final ancre = copies.firstWhere((c) => c.ancre);
    final donnees = await s.ouvrir(ancre);
    expect(donnees, isNotNull);
    await s.restaurer(donnees!);
    expect(e.produits.length, lessThan(nbProduits + 5));
    expect(e.produits.where((p) => p.nom.startsWith('Essai sauvegarde')).length, (ancre.compte['produits'] as int) - nbProduits);
    // La restauration a d'abord copié l'état d'avant.
    expect((await s.liste()).any((c) => c.jalon == 'Avant restauration'), isTrue);
    d.deleteSync(recursive: true);
  });
}
