import 'dart:math' as math;

import 'package:flutter/material.dart';

// Animation de l'accueil (scénario d'Aristide, 04/11/2026), jouée une fois par lancement :
// 1. la liste apparaît, à la taille de celle de Préparer, avec le crayon, sans traits ;
// 2. les traits gris s'écrivent l'un après l'autre (le crayon les suit) ;
// 3. le crayon disparaît ;
// 4. la liste rapetisse et se place comme dans l'image des courses ;
// 5. le caddie apparaît, vide, derrière la liste ;
// 6. les coches (deux vertes, une rouge) apparaissent pendant que les articles tombent dans le caddie ;
// 7. les courses sont finies : la liste disparaît, il reste le caddie plein.
// Images : planche d'Aristide (« Planche d'icônes courses en 3D »), découpée dans assets/emplettes/anim/.

const _dossier = 'assets/emplettes/anim';

/// Les images de l'animation, à précharger (essais, captures).
const imagesAnimationEmplettes = [
  'feuille', 'crayon', 'trait', 'coche_rouge', 'coche_verte', 'caddie', //
  'lait', 'pomme', 'pain', 'fromage', 'eau', 'boite', 'salade',
];

class AnimationEmplettes extends StatefulWidget {
  const AnimationEmplettes({super.key, this.hauteur = 96});
  final double hauteur;

  /// Déjà jouée depuis le lancement : l'image finale s'affiche directement.
  static bool jouee = false;

  /// Durée totale.
  static const duree = Duration(milliseconds: 6500);

  /// Essais : position imposée dans l'animation (0 à 1), sans horloge.
  static double? instantEssai;

  @override
  State<AnimationEmplettes> createState() => _AnimationEmplettesState();
}

/// Progression de 0 à 1 de [t] entre [a] et [b] (fractions de la durée totale).
double _entre(double t, double a, double b, [Curve c = Curves.easeInOut]) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

double _mix(double a, double b, double p) => a + (b - a) * p;

class _AnimationEmplettesState extends State<AnimationEmplettes> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AnimationEmplettes.duree);
    if (AnimationEmplettes.instantEssai != null) {
      _c.value = AnimationEmplettes.instantEssai!;
    } else if (AnimationEmplettes.jouee) {
      _c.value = 1;
    } else {
      AnimationEmplettes.jouee = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hauteur;
    final w = h * 1.3;
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(animation: _c, builder: (context, _) => Stack(clipBehavior: Clip.none, children: _scene(_c.value, w, h))),
    );
  }

  Widget _img(String nom, double l, double t, double largeur, {double opacite = 1, double angle = 0}) => Positioned(
        left: l,
        top: t,
        width: largeur,
        child: Opacity(
          opacity: opacite.clamp(0.0, 1.0),
          child: Transform.rotate(angle: angle, child: Image.asset('$_dossier/$nom.png', width: largeur, filterQuality: FilterQuality.medium)),
        ),
      );

  List<Widget> _scene(double t, double w, double h) {
    // Moments (fractions de la durée totale)
    final apparition = _entre(t, 0, .07);
    final traits = [for (var i = 0; i < 3; i++) _entre(t, .08 + i * .09, .16 + i * .09, Curves.easeOut)];
    final crayonParti = _entre(t, .36, .44);
    final rapetisse = _entre(t, .44, .56);
    final caddie = _entre(t, .54, .62, Curves.easeOut);
    final listeFinie = _entre(t, .88, .97);

    // La feuille (rapport 214 × 240) : à la taille de Préparer, puis à droite comme dans l'image des courses.
    final fh = _mix(h, h * .78, rapetisse);
    final fw = fh * 214 / 240;
    final fx = _mix((w - fw) / 2 - h * .08, w - fw, rapetisse) + listeFinie * h * .5;
    final fy = _mix(0, h * .02, rapetisse);

    // Les traits et les coches, en fractions de la feuille
    const lignesY = [.22, .42, .62];
    final traitX = fx + fw * .40, traitW = fw * .44, traitH = traitW * 38 / 160;

    // (nom, taille, position dans le panier de 0 à 1, moment de la chute, inclinaison)
    final articles = [
      ('pain', .34, .80, .62, .45),
      ('lait', .30, .30, .63, -.12),
      ('eau', .30, .10, .66, -.15),
      ('salade', .30, .60, .69, .15),
      ('pomme', .26, .45, .72, 0.0),
      ('fromage', .26, .22, .75, -.1),
      ('boite', .24, .95, .78, .1),
    ];
    // Caddie (rapport ≈ 1) : à gauche, derrière la liste ; au centre à la fin.
    final cw = h * .86;
    final cx = _mix(-h * .3, 0, caddie) + listeFinie * (w - cw) / 2;
    final cy = h * .14;

    final scene = <Widget>[];
    // Les articles tombent dans le caddie (dessinés avant lui : sa grille passe devant)
    for (final (nom, taille, x, debut, angle) in articles) {
      final p = _entre(t, debut, debut + .07, Curves.bounceOut);
      if (p <= 0) continue;
      final aw = h * taille * 1.15;
      final fondY = cy + cw * .24 - aw * .8;
      scene.add(_img(nom, cx + cw * (.30 + x * .52) - aw / 2, _mix(-h * .6, fondY, p), aw, opacite: _entre(t, debut, debut + .02), angle: angle));
    }
    scene.add(_img('caddie', cx, cy, cw, opacite: caddie));

    // La liste par-dessus
    final liste = (apparition * (1 - listeFinie)).clamp(0.0, 1.0);
    if (liste > 0) {
      scene.add(_img('feuille', fx, fy, fw, opacite: liste));
      for (var i = 0; i < 3; i++) {
        if (traits[i] <= 0) continue;
        scene.add(Positioned(
          left: traitX,
          top: fy + fh * lignesY[i] - traitH / 2,
          width: traitW * traits[i],
          height: traitH,
          child: Opacity(
            opacity: liste,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: traitW,
                minWidth: traitW,
                child: Image.asset('$_dossier/trait.png', width: traitW, filterQuality: FilterQuality.medium),
              ),
            ),
          ),
        ));
        // Les coches, en même temps que les articles : vert, vert, rouge
        final coche = _entre(t, .64 + i * .08, .70 + i * .08, Curves.elasticOut);
        if (coche > 0) {
          final cW = fw * .30 * coche.clamp(0.0, 1.3);
          scene.add(_img(i == 2 ? 'coche_rouge' : 'coche_verte', fx + fw * .22 - cW / 2, fy + fh * lignesY[i] - cW * .55, cW,
              opacite: liste));
        }
      }
      // Le crayon suit la fin du trait en cours, puis s'en va
      if (crayonParti < 1) {
        final enCours = traits.indexWhere((p) => p < 1);
        final i = enCours < 0 ? 2 : enCours;
        final pointeX = traitX + traitW * traits[i];
        final pointeY = fy + fh * lignesY[i];
        final cwr = h * .62;
        final chr = cwr * 200 / 143;
        scene.add(_img('crayon', pointeX - cwr * .04 + crayonParti * h * .4, pointeY - chr * .97 - crayonParti * h * .3, cwr,
            opacite: apparition * (1 - crayonParti), angle: math.sin(t * 60) * .03 * (1 - crayonParti)));
      }
    }
    return scene;
  }
}
