// Tickets réels fournis par Aristide : ils restent hors du dépôt (données personnelles) ;
// l'essai ne tourne que là où ils sont présents (/mnt/project-files/modele/tickets).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/lecture_ticket.dart';

void main() {
  const dossier = '/mnt/project-files/modele/tickets';
  final attendus = {
    'Carrefour': (DateTime(2026, 10, 9), 304.02),
    'Intermarche': (DateTime(2026, 10, 20), 106.08),
  };
  attendus.forEach((n, a) {
    final f = File('$dossier/$n.pdf');
    test('ticket $n', () async {
      final l = await lireTicketPdf(f.path);
      expect(l.date, a.$1);
      expect(l.montant, a.$2);
    }, skip: f.existsSync() ? false : 'ticket absent');
  });

  final leclerc = File('$dossier/Leclerc.pdf');
  test('Leclerc : ticket en image, date et prix inconnus', () async {
    final l = await lireTicketPdf(leclerc.path);
    expect(l.image, isTrue);
    expect(l.montant, isNull);
  }, skip: leclerc.existsSync() ? false : 'ticket absent');
}
