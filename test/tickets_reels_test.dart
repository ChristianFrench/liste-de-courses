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

  test('Leclerc (ticket en image) : lignes reconstituées après reconnaissance', () {
    // Morceaux tels que la reconnaissance de texte les rend : libellé et montant séparés.
    final lignes = lignesParPosition([
      (40, 100, 130, 'Caisse 007-0122 01 octobre 2026 16:00'),
      (40, 140, 170, 'Ticket 01/10/26 @ 07H06'),
      (40, 600, 630, 'Total 60 articles'),
      (700, 602, 632, '253.94'),
      (40, 700, 730, 'CB'),
      (700, 698, 728, '253.94'),
      (40, 800, 830, '4   5%50'),
      (500, 800, 830, '237.19   13.05   250.24'),
    ]);
    expect(lignes[2], 'Total 60 articles   253.94');
    final l = analyserTicket(lignes.join('\n'));
    expect(l.montant, 253.94);
    expect(l.date, DateTime(2026, 10, 1));
  });
}
