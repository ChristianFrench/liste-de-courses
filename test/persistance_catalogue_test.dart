// Les modifications du catalogue survivent à la fermeture (01/11/2026, perte signalée sur le web).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/catalogue_commun.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rayon ajouté, non-placé rangé, rayons déplacés : relus après fermeture', () async {
    final dossier = Directory.systemTemp.createTempSync('persist');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    // Non placés : créés sans secteur (comme depuis un mail importé), et un produit d'origine retiré de son secteur.
    final nonPlace = [etat.creerProduit('Bidule abc'), etat.creerProduit('Machin def')];
    final origine = etat.produits.firstWhere((x) => x.nom == 'Lait demi-écrémé');
    etat.emplacements.removeWhere((e) => e.produitId == origine.id);
    nonPlace.add(origine);
    final r = etat.ajouterRayonCatalogue('Jardinerie', univers: 'Bricolage, auto et jardin')!;
    final s = etat.secteursDu(r.id).first;
    final p = etat.enregistrerProduitAjoute(libelle: 'Terreau maison xyz', secteur: s);
    for (final x in nonPlace) {
      etat.placer(etat.magasinReference!.id, x.id, s.id);
    }
    etat.rangerRayons({'Bricolage, auto et jardin': ['Jardinerie']});
    await etat.enregistrer();
    // Comme à l'ouverture de l'application : relecture, puis catalogue commun.
    await etat.charger(dossier: dossier);
    expect(etat.journalAppareil.first, contains('Ouverture'), reason: 'journal de l\'appareil');
    await CatalogueCommun.instance.verifier();
    final r2 = etat.rayonsCatalogue.where((x) => x.nom == 'Jardinerie');
    expect(r2, isNotEmpty, reason: 'rayon ajouté');
    expect(etat.secteurCatalogue(etat.produits.firstWhere((x) => x.nom == p.nom).id)?.nom, 'Jardinerie');
    for (final x in nonPlace) {
      expect(etat.secteurCatalogue(x.id)?.nom, 'Jardinerie', reason: x.nom);
    }
    expect(etat.universRayons['Jardinerie'], 'Bricolage, auto et jardin');
  });
}
