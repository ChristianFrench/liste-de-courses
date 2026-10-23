import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Ce que l'on a pu lire sur un ticket de caisse PDF.
class LectureTicket {
  const LectureTicket({this.date, this.montant});
  final DateTime? date;
  final double? montant;
}

/// Lit le texte du ticket PDF puis y cherche la date et le montant payé.
/// Ticket en image (Leclerc : le PDF ne contient qu'une photo du ticket) : sur Android, le texte est
/// reconnu sur l'image (ML Kit, sur le téléphone, sans réseau). Sinon, ou si rien n'est lisible, lecture vide.
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
  if (texte.trim().length < 20 && Platform.isAndroid) {
    try {
      texte = await _reconnaitre(chemin);
    } catch (e) {
      debugPrint('Lecture ticket : reconnaissance impossible ($e)');
    }
  }
  final lu = analyserTicket(texte);
  debugPrint('Lecture ticket : ${texte.length} caractères, date ${lu.date}, montant ${lu.montant}');
  return lu;
}

/// Reconnaissance du texte sur les pages dessinées en image, ligne par ligne.
Future<String> _reconnaitre(String chemin) async {
  final doc = await px.PdfDocument.openFile(chemin);
  final lecteur = TextRecognizer(script: TextRecognitionScript.latin);
  final dossier = await getTemporaryDirectory();
  final lignes = <String>[];
  try {
    for (var i = 1; i <= min(doc.pagesCount, 8); i++) {
      final page = await doc.getPage(i);
      final image = await page.render(
          width: page.width * 3, height: page.height * 3, format: px.PdfPageImageFormat.png, backgroundColor: '#FFFFFF');
      await page.close();
      if (image == null) continue;
      final f = File('${dossier.path}${Platform.pathSeparator}ticket-page-$i.png');
      await f.writeAsBytes(image.bytes);
      final resultat = await lecteur.processImage(InputImage.fromFilePath(f.path));
      debugPrint('Lecture ticket : page $i ${image.width}x${image.height}, ${resultat.blocks.length} blocs');
      await f.delete();
      lignes.addAll(lignesParPosition([
        for (final b in resultat.blocks)
          for (final l in b.lines) (l.boundingBox.left, l.boundingBox.top, l.boundingBox.bottom, l.text),
      ]));
    }
  } finally {
    await lecteur.close();
    await doc.close();
  }
  return lignes.join('\n');
}

/// Remet sur une même ligne les morceaux de texte alignés horizontalement (libellé à gauche,
/// montant à droite, que la reconnaissance rend séparément).
List<String> lignesParPosition(List<(double gauche, double haut, double bas, String texte)> morceaux) {
  final tries = [...morceaux]..sort((a, b) => (a.$2 + a.$3).compareTo(b.$2 + b.$3));
  final groupes = <List<(double, double, double, String)>>[];
  for (final m in tries) {
    final centre = (m.$2 + m.$3) / 2, hauteur = m.$3 - m.$2;
    final g = groupes.isEmpty ? null : groupes.last;
    if (g != null) {
      final r = g.first;
      if ((centre - (r.$2 + r.$3) / 2).abs() < max(hauteur, r.$3 - r.$2) / 2) {
        g.add(m);
        continue;
      }
    }
    groupes.add([m]);
  }
  return [
    for (final g in groupes) (g..sort((a, b) => a.$1.compareTo(b.$1))).map((m) => m.$4).join('   '),
  ];
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
