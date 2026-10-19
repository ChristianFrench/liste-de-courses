import 'package:flutter/material.dart';

import '../donnees/images_choisies.dart';
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

/// Clés sous lesquelles l'image choisie par l'utilisateur est gardée.
String cleChoixRayon(String rayon) => _slug(rayon);
String cleChoixSecteur(String rayon, String secteur) => '${_slug(rayon)}--${_slug(secteur)}';

/// Images de réserve, à choisir pour les rayons et secteurs ajoutés par l'utilisateur.
List<String> get pictosReserve => [for (final c in pictosDisponibles) if (c.startsWith('reserve--')) c];

String? cleRayon(String nom) {
  final s = _slug(nom);
  final choisie = imagesChoisies[s];
  if (choisie != null && pictosDisponibles.contains(choisie)) return choisie;
  if (pictosDisponibles.contains(s)) return s;
  final a = _alias[s];
  if (a != null && pictosDisponibles.contains(a)) return a;
  return pictosDisponibles.contains('reserve--$s') ? 'reserve--$s' : null;
}

String? cleSecteur(String rayon, String nom) {
  final s = _slug(nom);
  final choisie = imagesChoisies['${_slug(rayon)}--$s'];
  if (choisie != null && pictosDisponibles.contains(choisie)) return choisie;
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

/// Valeur rendue par [choisirPictogramme] pour revenir à l'image automatique.
const imageAutomatique = '';

/// Grille de choix d'une image : d'abord les images de réserve, puis celles du catalogue.
/// Renvoie le nom du pictogramme, [imageAutomatique], ou null si l'on annule.
Future<String?> choisirPictogramme(BuildContext context, {required String titre}) {
  final reserve = pictosReserve;
  final autres = [for (final c in pictosDisponibles) if (!c.startsWith('reserve--')) c];
  Widget grille(BuildContext ctx, List<String> cles) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final c in cles)
            Semantics(
              button: true,
              label: c,
              child: InkWell(
                key: ValueKey('picto-$c'),
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.of(ctx).pop(c),
                child: Padding(padding: const EdgeInsets.all(4), child: Pictogramme(c, taille: 52)),
              ),
            ),
        ],
      );
  Widget intertitre(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
      );
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(imageAutomatique),
                child: const Text('Image automatique (selon le nom)', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (reserve.isNotEmpty) ...[intertitre('Images de réserve'), grille(ctx, reserve)],
            intertitre('Images du catalogue'),
            grille(ctx, autres),
          ],
        ),
      ),
    ),
  );
}

/// Image d'un rayon ou d'un secteur, touchable pour en choisir une autre ; un cadre vide s'il n'y en a pas.
class ImageModifiable extends StatelessWidget {
  const ImageModifiable({super.key, required this.cle, required this.taille, required this.onTap});
  final String? cle;
  final double taille;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: "Changer l'image",
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: taille < 44 ? 44 : taille,
            height: taille < 44 ? 44 : taille,
            child: Center(
              child: cle != null
                  ? Pictogramme(cle, taille: taille)
                  : Container(
                      width: taille,
                      height: taille,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBBBBBB)),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, size: taille * 0.5, color: const Color(0xFF777777)),
                    ),
            ),
          ),
        ),
      );
}
