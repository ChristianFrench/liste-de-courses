// Base locale SQLite : un état écrit puis relu doit être identique, et un objet supprimé
// ne doit pas revenir. Lancé automatiquement par GitHub ; rien à faire à la main.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/stockage.dart';

void main() {
  late Directory dossier;
  setUp(() => dossier = Directory.systemTemp.createTempSync('stockage'));
  tearDown(() => dossier.deleteSync(recursive: true));

  Map<String, dynamic> demo() =>
      jsonDecode(File('assets/donnees_maquette.json').readAsStringSync()) as Map<String, dynamic>;

  test('écrire puis relire redonne le même état', () {
    final chemin = '${dossier.path}/essai.db';
    final s = Stockage.ouvrir(chemin);
    expect(s.vide, isTrue);
    final etat = demo();
    s.ecrire(etat);
    s.fermer();

    final relu = Stockage.ouvrir(chemin);
    expect(relu.vide, isFalse);
    final lu = relu.lire();
    for (final cle in etat.keys) {
      expect(jsonEncode(lu[cle]), jsonEncode(etat[cle]), reason: cle);
    }
    relu.fermer();
  });

  test('un magasin supprimé ne revient pas', () {
    final chemin = '${dossier.path}/essai.db';
    final s = Stockage.ouvrir(chemin);
    final etat = demo();
    s.ecrire(etat);
    final avant = (etat['magasins'] as List).length;
    (etat['magasins'] as List).removeAt(0);
    s.ecrire(etat);
    s.fermer();

    final lu = Stockage.ouvrir(chemin).lire();
    expect((lu['magasins'] as List).length, avant - 1);
  });

  test('les réglages de l\'appareil ne font pas partie de l\'état', () {
    final s = Stockage.ouvrir('${dossier.path}/essai.db');
    s.definirReglage('modeDemo', 'oui');
    expect(s.vide, isTrue);
    expect(s.reglage('modeDemo'), 'oui');
    expect(s.lire().containsKey('modeDemo'), isFalse);
    s.fermer();
  });
}
