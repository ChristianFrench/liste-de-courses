import 'package:flutter/material.dart';

import 'icones_noto.dart';

/// Icône de l'application : l'image en couleur et en volume (Noto 3D de Google, assets/icones/noto3d/) quand elle existe,
/// sinon l'icône Material (commandes : chevrons, poignées, coches…). Mêmes paramètres que [Icon].
/// 01/11/2026 (Aristide) : des icônes plus « fun », homogènes avec les images du catalogue.
class Icone extends StatelessWidget {
  const Icone(this.icon, {super.key, this.size, this.color, this.shadows, this.semanticLabel});
  final IconData? icon;
  final double? size;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final nom = icon == null ? null : iconesNoto[icon];
    if (nom == null) return Icon(icon, size: size, color: color, shadows: shadows, semanticLabel: semanticLabel);
    final t = size ?? IconTheme.of(context).size ?? 24;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: t,
        height: t,
        child: Center(child: Image.asset('assets/icones/noto3d/$nom.png', width: t * 0.92, height: t * 0.92, filterQuality: FilterQuality.medium)),
      ),
    );
  }
}

/// 03/11/2026 (Aristide) : les trois images d'Emplettes (assets/emplettes/) :
/// « complet » (chariot, liste et crayon) = l'application et l'Accueil, « liste_crayon » = Préparer, « liste_chariot » = Courses.
class ImageEmplettes extends StatelessWidget {
  const ImageEmplettes(this.nom, {super.key, required this.taille});
  final String nom;
  final double taille;

  /// Image de l'onglet dont l'en-tête porte cette icône, sinon l'image complète.
  static String pourIcone(IconData? i) => switch (i) {
        Icons.checklist => 'liste_crayon',
        Icons.shopping_cart_outlined => 'liste_chariot',
        _ => 'complet',
      };

  @override
  Widget build(BuildContext context) => Image.asset('assets/emplettes/$nom.png',
      width: taille, height: taille, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}
