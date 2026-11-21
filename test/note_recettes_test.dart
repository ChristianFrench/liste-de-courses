// Note préparée (21/11/2026) : recettes choisies sans liste, traitées ou ignorées à la préparation, communes au
// foyer (gardées dans les options du foyer).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/demonstration.dart';
import 'package:liste_de_courses/donnees/import_texte.dart';
import 'package:liste_de_courses/donnees/modele.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('noter, renoter, traiter pour une liste, ignorer, reprendre', () async {
    final dossier = Directory.systemTemp.createTempSync('note');
    final etat = Etat.instance;
    await etat.charger(dossier: dossier);
    final l = etat.creerListe(etat.magasins.first.id, []);
    final autre = etat.creerListe(etat.magasins.first.id, [], nom: 'Autre');
    etat.noterRecette(recette: 'quiche', titre: 'Quiche', personnes: 4, ingredients: ['200 g Lardons', '3 Œufs']);
    etat.noterRecette(recette: 'quiche', titre: 'Quiche', personnes: 6, ingredients: ['200 g Lardons']);
    etat.noterRecette(recette: 'crumble', titre: 'Crumble', ingredients: ['4 Pommes']);
    expect(etat.noteRecettes.length, 2, reason: 'renoter remplace');
    expect(etat.noteATraiter('quiche', 'Quiche')!.personnes, 6);
    expect(etat.recettesDeListe(l).map((n) => n.titre), ['Quiche', 'Crumble']);
    final quiche = etat.noteATraiter('quiche', 'Quiche')!;
    etat.marquerRecette(quiche, NoteRecette.traitee, l);
    final crumble = etat.noteATraiter('crumble', 'Crumble')!;
    etat.marquerRecette(crumble, NoteRecette.ignoree, l);
    expect(etat.recettesDeListe(l).map((n) => '${n.titre}:${n.etat}'), ['Quiche:t', 'Crumble:i']);
    expect(etat.recettesDeListe(autre), isEmpty, reason: 'traitées ou ignorées pour une autre liste');
    expect(etat.recettesTraitees(l).single.titre, 'Quiche');
    etat.marquerRecette(crumble, NoteRecette.aTraiter, l);
    expect(etat.recettesDeListe(autre).single.titre, 'Crumble');
    // Gardée dans les options du foyer (partagées).
    final relue = NoteRecette.depuis(quiche.versJson());
    expect((relue.titre, relue.etat, relue.liste), ('Quiche', 't', l.id));
    expect(relue.ingredients, ['200 g Lardons']);
  });

  test('ingrédients à régler : un par secteur quand le nom est dans plusieurs, gardés dans la note', () async {
    final etat = Etat.instance;
    await etat.charger(dossier: Directory.systemTemp.createTempSync('regler'));
    etat.remplirDemonstration();
    final parmesan = candidatsProduit(etat, 'Parmesan');
    expect(parmesan.length, 2);
    expect({for (final p in parmesan) etat.secteurCatalogue(p.id)?.id}.length, 2);
    expect(candidatsProduit(etat, 'Lardons fumés').length, 1);
    expect(candidatsProduit(etat, 'Zzz introuvable'), isEmpty);
    final l = etat.creerListe(etat.magasins.first.id, []);
    etat.recetteTraitee(l, titre: 'Risotto', ingredients: ['50 g Parmesan'], aRegler: [
      {'t': '50 g Parmesan', 'n': 'Parmesan', 'c': [for (final p in parmesan) p.id]},
    ]);
    final n = etat.recettesTraitees(l).single;
    final relu = NoteRecette.depuis(n.versJson());
    expect(relu.aRegler.single['n'], 'Parmesan');
    etat.reglerIngredient(n, n.aRegler.single);
    expect(n.aRegler, isEmpty);
  });
}
