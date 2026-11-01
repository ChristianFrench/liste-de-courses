import 'package:flutter/material.dart';

import '../theme.dart';
import 'icones_noto.dart';

/// Icône de l'application : l'image en couleur et en volume (famille Fluent 3D ou Noto, assets/icones/, au choix
/// dans Paramètres › Apparence) quand elle existe,
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
        child: Center(child: Image.asset('assets/icones/${Charte.familleIcones}/$nom.png', width: t * 0.92, height: t * 0.92, filterQuality: FilterQuality.medium)),
      ),
    );
  }
}
