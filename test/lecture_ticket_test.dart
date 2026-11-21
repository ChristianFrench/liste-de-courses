// Lecture de la date et du montant d'un ticket de caisse (texte extrait du PDF).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/lecture_ticket.dart';

void main() {
  test('total à payer et date', () {
    final l = analyserTicket('''
E.LECLERC VENDOME
LAIT DEMI ECREME        1,15
CAMEMBERT               2,89
SOUS-TOTAL             84,30
REMISE FIDELITE        -2,00
TOTAL A PAYER          82,30
CB                     82,30
TVA 5,5%  HT 78,01  TVA 4,29
Le 21/10/2026 a 18:42
''');
    expect(l.montant, 82.30);
    expect(l.date, DateTime(2026, 10, 21));
  });

  test('montant sur la ligne suivante, année sur deux chiffres', () {
    final l = analyserTicket('INTERMARCHE\n12.10.25 10:05\nTotal TTC\n1 234,56 EUR\nNb articles 40');
    expect(l.montant, 1234.56);
    expect(l.date, DateTime(2025, 10, 12));
  });

  test('rien de lisible', () {
    final l = analyserTicket('photo sans texte');
    expect(l.montant, isNull);
    expect(l.date, isNull);
  });

  test('lecture d\'un vrai PDF', () async {
    // PDF d'une page écrit à la main, comme ceux des applications des magasins (texte, police standard).
    const flux = 'BT /F1 18 Tf 30 340 Td (MAGASIN ESSAI 22/10/2026) Tj 0 -40 Td (SOUS-TOTAL 14,50) Tj '
        '0 -40 Td (TOTAL A PAYER 12,50 EUR) Tj ET';
    final objets = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Length ${flux.length} >>\nstream\n$flux\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final b = StringBuffer('%PDF-1.4\n');
    final positions = <int>[];
    for (var i = 0; i < objets.length; i++) {
      positions.add(b.length);
      b.write('${i + 1} 0 obj\n${objets[i]}\nendobj\n');
    }
    final xref = b.length;
    b.write('xref\n0 ${objets.length + 1}\n0000000000 65535 f \n');
    for (final p in positions) {
      b.write('${p.toString().padLeft(10, '0')} 00000 n \n');
    }
    b.write('trailer\n<< /Size ${objets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    final f = File('${Directory.systemTemp.createTempSync('ticket').path}/ticket.pdf')..writeAsBytesSync(latin1.encode(b.toString()));
    final l = await lireTicketPdf(f.path);
    expect(l.montant, 12.50);
    expect(l.date, DateTime(2026, 10, 22));
  });
}
