import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Images ajoutées à la bibliothèque par l'éditeur du catalogue commun (07/11/2026, Aristide) : une image collée ou
// prise dans un fichier, mise à la taille des autres (96 × 96, fond transparent), avec un texte associé.
// Clé « perso--<texte en minuscules sans accents> » ; elles voyagent avec le catalogue commun (« imagesPerso ») et
// chaque appareil les garde dans son réglage « images_perso ».

/// Côté des images de la bibliothèque, en pixels.
const coteImagePerso = 96;

class ImagePerso {
  ImagePerso(this.texte, this.png);
  final String texte;

  /// L'image PNG, en base64.
  final String png;

  Map<String, String> versJson() => {'t': texte, 'i': png};
}

/// Les images ajoutées connues de cet appareil (clé → image).
final imagesPerso = <String, ImagePerso>{};
final _octets = <String, Uint8List>{};

Map<String, ImagePerso> lireImagesPerso(Object? j) => {
      if (j is Map)
        for (final e in j.entries)
          if (e.value is Map && (e.value as Map)['i'] is String)
            '${e.key}': ImagePerso('${(e.value as Map)['t'] ?? ''}', (e.value as Map)['i'] as String),
    };

Map<String, Map<String, String>> imagesPersoVersJson(Map<String, ImagePerso> m) => {for (final e in m.entries) e.key: e.value.versJson()};

void remplacerImagesPerso(Map<String, ImagePerso> m) {
  imagesPerso
    ..clear()
    ..addAll(m);
  _octets.clear();
}

Uint8List? octetsImagePerso(String cle) {
  final i = imagesPerso[cle];
  if (i == null) return null;
  try {
    return _octets[cle] ??= base64Decode(i.png);
  } catch (_) {
    return null;
  }
}

String _sansAccents(String s) {
  const a = {'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae'};
  return s.toLowerCase().split('').map((c) => a[c] ?? c).join();
}

/// Clé d'une image ajoutée d'après son texte (« Pot de miel » → « perso--pot-de-miel »).
String clePerso(String texte) =>
    'perso--${_sansAccents(texte).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';

/// Met une image (PNG, JPEG, GIF, BMP, WebP…) à la taille de la bibliothèque : un fond uni clair touchant les bords
/// devient transparent, les marges vides sont ôtées, l'image est centrée dans un carré de 96 pixels.
/// Rend le PNG, ou null si l'image n'est pas lisible.
Uint8List? preparerImagePerso(Uint8List octets) {
  img.Image? src;
  try {
    src = img.decodeImage(octets);
  } catch (_) {
    return null;
  }
  if (src == null || src.width == 0 || src.height == 0) return null;
  // Assez petite pour aller vite, assez grande pour un beau rendu.
  if (src.width > 600 || src.height > 600) {
    src = src.width >= src.height ? img.copyResize(src, width: 600, interpolation: img.Interpolation.average)
        : img.copyResize(src, height: 600, interpolation: img.Interpolation.average);
  }
  final im = src.convert(numChannels: 4, format: img.Format.uint8);
  final w = im.width, h = im.height;

  // Fond clair et uni (capture d'écran, image sur fond blanc ou pâle) : transparent, de proche en proche depuis les
  // bords. Le fond est la couleur commune d'au moins trois coins.
  final coins = [im.getPixel(0, 0), im.getPixel(w - 1, 0), im.getPixel(0, h - 1), im.getPixel(w - 1, h - 1)];
  bool proches(img.Pixel a, img.Pixel b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() < 36;
  img.Color? fond;
  for (final c in coins) {
    final pale = c.a > 200 && c.r > 170 && c.g > 170 && c.b > 170;
    if (pale && coins.where((d) => proches(c, d)).length >= 3) {
      fond = c.clone();
      break;
    }
  }
  if (fond != null) {
    final f = fond;
    bool clair(img.Pixel p) => p.a > 200 && (p.r - f.r).abs() + (p.g - f.g).abs() + (p.b - f.b).abs() < 48;
    final vu = Uint8List(w * h);
    final pile = <int>[];
    void pousser(int x, int y) {
      final i = y * w + x;
      if (vu[i] == 1) return;
      vu[i] = 1;
      if (clair(im.getPixel(x, y))) pile.add(i);
    }

    for (var x = 0; x < w; x++) {
      pousser(x, 0);
      pousser(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      pousser(0, y);
      pousser(w - 1, y);
    }
    while (pile.isNotEmpty) {
      final i = pile.removeLast();
      final x = i % w, y = i ~/ w;
      im.getPixel(x, y).a = 0;
      if (x > 0) pousser(x - 1, y);
      if (x < w - 1) pousser(x + 1, y);
      if (y > 0) pousser(x, y - 1);
      if (y < h - 1) pousser(x, y + 1);
    }
  }

  // Marges vides ôtées.
  var x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (im.getPixel(x, y).a > 16) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return null; // tout transparent
  final rogne = img.copyCrop(im, x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1);

  // Centrée dans le carré, avec une petite marge comme les emojis.
  const utile = coteImagePerso - 8;
  final echelle = utile / (rogne.width > rogne.height ? rogne.width : rogne.height);
  final rw = (rogne.width * echelle).round().clamp(1, utile), rh = (rogne.height * echelle).round().clamp(1, utile);
  final petite = img.copyResize(rogne,
      width: rw, height: rh, interpolation: echelle < 1 ? img.Interpolation.average : img.Interpolation.cubic);
  final carre = img.Image(width: coteImagePerso, height: coteImagePerso, numChannels: 4);
  img.compositeImage(carre, petite, dstX: (coteImagePerso - rw) ~/ 2, dstY: (coteImagePerso - rh) ~/ 2);
  return Uint8List.fromList(img.encodePng(carre, level: 9));
}
