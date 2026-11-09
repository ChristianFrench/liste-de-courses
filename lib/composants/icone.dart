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
    final t = size ?? IconTheme.of(context).size ?? 24;
    // 09/11/2026 (Aristide) : ses symboles (chevrons, coche, croix, menus, poignées) à la place des icônes au trait.
    final symbole = icon == null ? null : iconesSymboles[icon];
    if (symbole != null) {
      final image = Image.asset('assets/icones/symboles/${symbole.$1}.png', width: t, height: t, filterQuality: FilterQuality.medium);
      return Semantics(
        label: semanticLabel,
        child: SizedBox(width: t, height: t, child: symbole.$2 ? Transform.flip(flipX: true, child: image) : image),
      );
    }
    final nom = icon == null ? null : iconesNoto[icon];
    if (nom == null) return Icon(icon, size: size, color: color, shadows: shadows, semanticLabel: semanticLabel);
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

  /// Courses interrompues (03/11/2026, Aristide) : l'image des courses, avec le bouton pause en petit en bas à gauche.
  static Widget interrompue(double taille, {Key? key}) => SizedBox(
        key: key,
        width: taille,
        height: taille,
        child: Stack(children: [
          Positioned.fill(child: ImageEmplettes('liste_chariot', taille: taille)),
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset('assets/icones/noto3d/pause-button.png',
                width: taille * 0.5, height: taille * 0.5, filterQuality: FilterQuality.medium),
          ),
        ]),
      );

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

/// Icône Material → symbole d'Aristide (assets/icones/symboles/<nom>.png), et retourné en miroir ou non.
final iconesSymboles = <IconData, (String, bool)>{
  Icons.expand_more: ('chevron-bas', false),
  Icons.expand_less: ('chevron-haut', false),
  Icons.chevron_right: ('chevron-droite', false),
  Icons.chevron_left: ('chevron-droite', true),
  Icons.check: ('coche', false),
  Icons.close: ('croix-fermeture', false),
  Icons.menu: ('menu-hamburger', false),
  Icons.more_vert: ('menu-vertical', false),
  Icons.drag_handle: ('poignee-horizontale', false),
  Icons.drag_indicator: ('poignee-verticale', false),
  Icons.unfold_more: ('fleche-bas', false),
  Icons.unfold_less: ('fleche-haut', false),
  Icons.check_box: ('case-cochee', false),
  Icons.check_box_outline_blank: ('case-vide', false),
  Icons.radio_button_checked: ('radio-selectionne', false),
  Icons.radio_button_unchecked: ('radio-vide', false),
};
