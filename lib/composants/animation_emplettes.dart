import 'dart:math' as math;

import 'package:flutter/material.dart';

// Animation de l'accueil (scénario d'Aristide, 04/11/2026), jouée une fois par lancement :
// 1. la liste apparaît, à la taille de celle de Préparer, avec le crayon, sans traits ;
// 2. les traits gris s'écrivent l'un après l'autre (le crayon les suit) ;
// 3. le crayon disparaît ;
// 4. la liste rapetisse et se place comme dans l'image des courses ;
// 5. le caddie apparaît, vide, derrière la liste ;
// 6. les lignes se cochent une à une (la rouge au milieu) pendant que les articles tombent au fond du caddie ;
// 7. les courses sont finies : la liste s'efface sur place, il reste le caddie plein.
// Images : planche d'Aristide (« Planche d'icônes courses en 3D »), découpée dans assets/emplettes/anim/.

const _dossier = 'assets/emplettes/anim';

/// Lignes de la liste ; la coche rouge est au milieu.
const _lignes = 5, _ligneRouge = 2;

/// Hauteur / largeur des images d'articles.
const _proportions = {
  'lait': 120 / 88, 'pomme': 120 / 113, 'pain': 120 / 99, 'fromage': 112 / 120, //
  'eau': 120 / 55, 'boite': 120 / 89, 'salade': 125 / 130,
};

/// Les images de l'animation, à précharger (essais, captures).
const imagesAnimationEmplettes = [
  'feuille', 'crayon', 'trait', 'coche_rouge', 'coche_verte', 'caddie', 'caddie_avant', //
  'lait', 'pomme', 'pain', 'fromage', 'eau', 'boite', 'salade',
];

class AnimationEmplettes extends StatefulWidget {
  const AnimationEmplettes({super.key, this.hauteur = 96});
  final double hauteur;

  /// Déjà jouée depuis le lancement : l'image finale s'affiche directement.
  static bool jouee = false;

  /// Durée totale.
  static const duree = Duration(milliseconds: 11000);

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

  // La face de la feuille est vue en perspective : un parallélogramme, en pixels de feuille.png (214 × 240).
  // Coin haut gauche, bord du haut, bord de gauche. Traits et coches y sont dessinés dans un carré de 100 × 100.
  static const _origine = Offset(14, 24), _haut = Offset(136, -12), _gauche = Offset(40, 168);

  /// Point (x, y) de la face (0 à 100), en coordonnées de la scène.
  Offset _surFeuille(double x, double y, double fx, double fy, double ech) =>
      Offset(fx, fy) + (_origine + _haut * (x / 100) + _gauche * (y / 100)) * ech;

  List<Widget> _scene(double t, double w, double h) {
    // Moments (fractions de la durée totale)
    final apparition = _entre(t, 0, .06);
    final traits = [for (var i = 0; i < _lignes; i++) _entre(t, .07 + i * .07, .13 + i * .07, Curves.easeOut)];
    final crayonParti = _entre(t, .42, .47);
    final rapetisse = _entre(t, .47, .55);
    final caddie = _entre(t, .53, .59, Curves.easeOut);
    final listeFinie = _entre(t, .86, .92); // la liste s'efface sur place
    final recentre = _entre(t, .92, .98);

    // La feuille (rapport 214 × 240) : à la taille de Préparer, puis à droite comme dans l'image des courses.
    final fh = _mix(h, h * .78, rapetisse);
    final fw = fh * 214 / 240;
    final ech = fw / 214;
    final fx = _mix((w - fw) / 2 - h * .08, w - fw, rapetisse);
    final fy = _mix(0, h * .02, rapetisse);

    // Les traits et les coches, dans le carré de la face
    const lignesY = [16.0, 29.0, 42.0, 55.0, 68.0];
    const traitX = 42.0, traitW = 40.0, traitH = traitW * 38 / 160;

    // (nom, taille, position dans le panier de 0 à 1, moment de la chute, inclinaison)
    final articles = [
      ('pain', .24, .80, .60, .45),
      ('lait', .21, .30, .64, -.12),
      ('eau', .21, .08, .68, -.15),
      ('salade', .21, .58, .72, .15),
      ('pomme', .18, .42, .76, 0.0),
      ('fromage', .18, .20, .80, -.1),
      ('boite', .17, .95, .83, .1),
    ];
    // Caddie (260 × 257) : à gauche, derrière la liste ; au centre à la fin.
    final cw = h * .86;
    final ce = cw / 260;
    final cx = _mix(-h * .3, 0, caddie) + recentre * (w - cw) / 2;
    final cy = h * .14;

    final scene = <Widget>[_img('caddie', cx, cy, cw, opacite: caddie)];
    // Les articles tombent au fond du panier : devant sa paroi du fond, derrière sa face avant (caddie_avant.png).
    for (final (k, (nom, taille, x, debut, angle)) in articles.indexed) {
      final p = _entre(t, debut, debut + .07, Curves.bounceOut);
      if (p <= 0) continue;
      final aw = h * taille;
      final ah = aw * _proportions[nom]!; // hauteur de l'image
      final px = 72 + x * 120; // dans la largeur de la face avant (pixels de caddie.png)
      final fond = 150 + (px - 70) * .06 - k * 7; // le fond du panier, puis sur les articles déjà tombés
      scene.add(_img(nom, cx + px * ce - aw / 2, _mix(-h * .6, cy + fond * ce - ah, p), aw,
          opacite: _entre(t, debut, debut + .02), angle: angle));
    }
    scene.add(_img('caddie_avant', cx, cy, cw, opacite: caddie));

    // La liste par-dessus
    final liste = (apparition * (1 - listeFinie)).clamp(0.0, 1.0);
    if (liste > 0) {
      scene.add(_img('feuille', fx, fy, fw, opacite: liste));
      final face = <Widget>[];
      for (var i = 0; i < _lignes; i++) {
        if (traits[i] <= 0) continue;
        face.add(Positioned(
          left: traitX,
          top: lignesY[i] - traitH / 2,
          width: traitW * traits[i],
          height: traitH,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: traitW,
              minWidth: traitW,
              child: Image.asset('$_dossier/trait.png', width: traitW, filterQuality: FilterQuality.medium),
            ),
          ),
        ));
        // Une coche à chaque article tombé ; la rouge (article pas trouvé) au milieu
        final coche = _entre(t, .63 + i * .045, .68 + i * .045, Curves.elasticOut);
        if (coche > 0) {
          final cW = 18 * coche.clamp(0.0, 1.3);
          face.add(Positioned(
            left: 24 - cW / 2,
            top: lignesY[i] - cW * .6,
            width: cW,
            child: Image.asset('$_dossier/${i == _ligneRouge ? 'coche_rouge' : 'coche_verte'}.png', width: cW, filterQuality: FilterQuality.medium),
          ));
        }
      }
      // Le carré 100 × 100 posé sur la face, en perspective
      final o = _surFeuille(0, 0, fx, fy, ech);
      scene.add(Positioned(
        left: 0,
        top: 0,
        width: 100,
        height: 100,
        child: Opacity(
          opacity: liste,
          child: Transform(
            transform: Matrix4(_haut.dx * ech / 100, _haut.dy * ech / 100, 0, 0, _gauche.dx * ech / 100, _gauche.dy * ech / 100, 0, 0,
                0, 0, 1, 0, o.dx, o.dy, 0, 1),
            child: Stack(clipBehavior: Clip.none, children: face),
          ),
        ),
      ));
      // Le crayon suit la fin du trait en cours, puis s'en va
      if (crayonParti < 1) {
        final enCours = traits.indexWhere((p) => p < 1);
        final i = enCours < 0 ? _lignes - 1 : enCours;
        final pointe = _surFeuille(traitX + traitW * traits[i], lignesY[i], fx, fy, ech);
        final cwr = h * .62;
        final chr = cwr * 200 / 143;
        scene.add(_img('crayon', pointe.dx - cwr * .04, pointe.dy - chr * .97, cwr, // s'efface sur place
            opacite: apparition * (1 - crayonParti), angle: math.sin(t * 60) * .03 * (1 - crayonParti)));
      }
    }
    return scene;
  }
}
