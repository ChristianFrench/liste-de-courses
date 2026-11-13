import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Ce que l'on a pu lire sur un ticket de caisse PDF.
class LectureTicket {
  const LectureTicket({this.date, this.montant, this.image = false});
  final DateTime? date;
  final double? montant;

  /// Le PDF ne contient qu'une image du ticket (Leclerc) : rien n'est lisible, date et prix inconnus.
  final bool image;
}

/// Lit le texte du ticket PDF puis y cherche la date et le montant payé.
Future<LectureTicket> lireTicketPdf(String chemin) async {
  var texte = '';
  try {
    final doc = PdfDocument(inputBytes: await File(chemin).readAsBytes());
    try {
      texte = PdfTextExtractor(doc).extractText(layoutText: true);
    } finally {
      doc.dispose();
    }
  } catch (_) {}
  if (texte.trim().length < 20) return const LectureTicket(image: true);
  final lu = analyserTicket(texte);
  debugPrint('Lecture ticket : ${texte.length} caractères, date ${lu.date}, montant ${lu.montant}');
  return lu;
}

String _sansAccents(String s) => s
    .toUpperCase()
    .replaceAll(RegExp('[ÀÂÄ]'), 'A')
    .replaceAll(RegExp('[ÉÈÊË]'), 'E')
    .replaceAll(RegExp('[ÎÏ]'), 'I')
    .replaceAll(RegExp('[ÔÖ]'), 'O')
    .replaceAll(RegExp('[ÙÛÜ]'), 'U')
    .replaceAll('Ç', 'C');

final _montant = RegExp(r'(?<![\d,.])(\d{1,4}(?:[ .]\d{3})*[,.]\d{2})(?![\d])');
final _date = RegExp(r'(?<!\d)(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)');

/// Repères du montant payé, du plus sûr au moins sûr.
const _reperes = [
  ('NET A PAYER', 6),
  ('A PAYER', 5),
  ('TOTAL TTC', 4),
  ('MONTANT TTC', 4),
  ('TOTAL A REGLER', 4),
  ('TOTAL', 3),
  ('MONTANT', 2),
  ('CARTE BANCAIRE', 1),
  ('CB ', 1),
];

/// Lignes qui contiennent un repère sans être le total payé.
const _exclus = ['SOUS-TOTAL', 'SOUS TOTAL', 'REMISE', 'ECONOMI', 'AVANTAGE', 'FIDELITE', 'TVA', ' HT', 'NB ARTICLE',
  'NOMBRE', 'CAGNOTTE', 'BON ', 'POINTS', 'RENDU'];

double? _nombre(String s) => double.tryParse(s.replaceAll(' ', '').replaceAll(RegExp(r'\.(?=\d{3})'), '').replaceAll(',', '.'));

LectureTicket analyserTicket(String texte) {
  final lignes = [for (final l in texte.split(RegExp(r'\r?\n'))) _sansAccents(l).replaceAll(RegExp(r'\s+'), ' ').trim()];

  // Montant : la ligne au repère le plus sûr ; le nombre est sur la ligne ou la suivante.
  double? montant;
  var meilleur = -1;
  for (var i = 0; i < lignes.length; i++) {
    final l = lignes[i];
    if (_exclus.any(l.contains)) continue;
    final repere = _reperes.where((r) => l.contains(r.$1)).fold<int>(-1, (m, r) => r.$2 > m ? r.$2 : m);
    if (repere < 0 || repere < meilleur) continue;
    var trouves = _montant.allMatches(l).toList();
    if (trouves.isEmpty && i + 1 < lignes.length) trouves = _montant.allMatches(lignes[i + 1]).toList();
    if (trouves.isEmpty) continue;
    final v = _nombre(trouves.last.group(1)!);
    if (v == null || v <= 0) continue;
    // À repère égal, le plus grand montant (le total, pas une ligne d'article).
    if (repere > meilleur || v > (montant ?? 0)) montant = v;
    meilleur = repere;
  }

  // Date : la première date plausible (pas dans le futur, après 2000).
  DateTime? date;
  final demain = DateTime.now().add(const Duration(days: 1));
  for (final l in lignes) {
    for (final m in _date.allMatches(l)) {
      final j = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
      var a = int.parse(m.group(3)!);
      if (a < 100) a += 2000;
      if (mo < 1 || mo > 12 || j < 1 || j > 31 || a < 2000) continue;
      final d = DateTime(a, mo, j);
      if (d.month != mo || d.isAfter(demain)) continue;
      date = d;
      break;
    }
    if (date != null) break;
  }
  return LectureTicket(date: date, montant: montant);
}
