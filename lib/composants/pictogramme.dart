import 'package:flutter/material.dart';

import '../donnees/pictos.dart';

// Images des rayons et des secteurs (assets/pictos/png), retrouvées par le nom.
// Un rayon ou un secteur qui ne figure pas au catalogue type reçoit l'image la plus proche, ou aucune.

String _slug(String s) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae'
  };
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(accents[c] ?? c);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
}

const _alias = {
  'frais': 'cremerie',
  'epicerie': 'epicerie-salee',
  'boissons': 'eaux-et-boissons-sans-alcool',
  'liquides': 'eaux-et-boissons-sans-alcool',
  'droguerie': 'entretien-droguerie',
  'entretien': 'entretien-droguerie',
  'soins-dentaires': 'parfumerie-et-soins--sante-dentaire',
};

String? cleRayon(String nom) {
  final s = _slug(nom);
  if (pictosDisponibles.contains(s)) return s;
  final a = _alias[s];
  return a != null && pictosDisponibles.contains(a) ? a : null;
}

String? cleSecteur(String rayon, String nom) {
  final s = _slug(nom);
  final r = cleRayon(rayon) ?? _slug(rayon);
  if (pictosDisponibles.contains('$r--$s')) return '$r--$s';
  for (final c in pictosDisponibles) {
    if (c.endsWith('--$s')) return c;
  }
  final commeRayon = cleRayon(nom);
  if (commeRayon != null) return commeRayon;
  for (final c in pictosDisponibles) {
    final i = c.indexOf('--');
    if (i > 0 && s.contains(c.substring(i + 2))) return c;
  }
  return null;
}

class Pictogramme extends StatelessWidget {
  const Pictogramme(this.cle, {super.key, this.taille = 24});
  final String? cle;
  final double taille;

  @override
  Widget build(BuildContext context) => cle == null
      ? SizedBox(width: taille, height: taille)
      : Image.asset('assets/pictos/png/$cle.png',
          width: taille, height: taille, filterQuality: FilterQuality.medium, excludeFromSemantics: true);
}
