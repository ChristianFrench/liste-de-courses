import 'dart:math' as math;

import 'package:flutter/material.dart';

// Animation de l'accueil (scénario d'Aristide, 04/11/2026), jouée une fois par lancement :
// 1. la feuille apparaît en fondu, seule, à la taille de celle de Préparer, puis le crayon ;
// 2. les traits gris s'écrivent l'un après l'autre (le crayon les suit) ;
// 3. le crayon part en poussière sur place (comme une application désinstallée sur un Xiaomi) ;
// 4. la liste rapetisse et se place comme dans l'image des courses ;
// 5. le caddie arrive, vide, derrière la liste, en roulant dans l'axe de ses roues ;
// 6. les lignes se cochent une à une (3 vertes, 1 rouge, 1 verte) pendant que les articles tombent dans le caddie,
//    jusqu'à le remplir comme celui de l'image Emplettes ;
// 7. les courses sont finies : la liste part en poussière, le caddie plein se recentre puis s'efface ;
//    l'image Emplettes apparaît et reste.
// Images : planche d'Aristide (« Planche d'icônes courses en 3D »), découpée dans assets/emplettes/anim/.

const _dossier = 'assets/emplettes/anim';

/// Lignes de la liste ; la coche rouge est l'avant-dernière.
const _lignes = 5, _ligneRouge = 3;

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
  static const duree = Duration(milliseconds: 12000);

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

  Widget _img(String nom, double l, double t, double largeur, {double opacite = 1, double angle = 0, String dossier = _dossier}) =>
      Positioned(
        left: l,
        top: t,
        width: largeur,
        child: Opacity(
          opacity: opacite.clamp(0.0, 1.0),
          child: Transform.rotate(angle: angle, child: Image.asset('$dossier/$nom.png', width: largeur, filterQuality: FilterQuality.medium)),
        ),
      );

  /// Effet « désinstallation Xiaomi » : le groupe [enfants] (coordonnées de la scène) rapetisse un peu,
  /// puis se brise en petits carrés qui s'envolent et s'effacent. [p] de 0 (intact) à 1 (disparu).
  List<Widget> _poussiere(List<Widget> enfants, Rect zone, double p, double h) {
    if (p <= 0) return enfants;
    if (p >= 1) return const [];
    const n = 11;
    final groupe = Stack(clipBehavior: Clip.none, children: enfants);
    final serre = 1 - .08 * _entre(p, 0, .25);
    final res = <Widget>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final tuile = Rect.fromLTWH(zone.left + zone.width * i / n, zone.top + zone.height * j / n, zone.width / n + .5, zone.height / n + .5);
        double hasard(int k) => (math.sin((i * 12.9898 + j * 78.233 + k * 37.719)) * 43758.5453) % 1.0;
        final r1 = hasard(1).abs(), r2 = hasard(2).abs(), r3 = hasard(3).abs();
        // Les carrés partent l'un après l'autre, du haut à droite vers le bas à gauche, avec un peu de hasard.
        final depart = .22 + .45 * ((n - 1 - i + j) / (2 * n - 2)) * .7 + .15 * r1;
        final q = _entre(p, depart, depart + .3, Curves.easeIn);
        if (q >= 1) continue;
        final dx = (r2 - .5) * h * .5 * q, dy = -(.15 + r3 * .35) * h * q;
        final centre = tuile.center;
        final m = Matrix4.identity()
          ..translateByDouble(zone.center.dx, zone.center.dy, 0, 1)
          ..scaleByDouble(serre, serre, 1, 1)
          ..translateByDouble(-zone.center.dx, -zone.center.dy, 0, 1)
          ..translateByDouble(centre.dx + dx, centre.dy + dy, 0, 1)
          ..scaleByDouble(1 - .6 * q, 1 - .6 * q, 1, 1)
          ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
        res.add(Positioned.fill(
          child: Opacity(
            opacity: 1 - q,
            child: Transform(transform: m, child: ClipRect(clipper: _Tuile(tuile), child: groupe)),
          ),
        ));
      }
    }
    return res;
  }

  // La face de la feuille est vue en perspective : un parallélogramme, en pixels de feuille.png (214 × 240).
  // Coin haut gauche, bord du haut, bord de gauche. Traits et coches y sont dessinés dans un carré de 100 × 100.
  static const _origine = Offset(14, 24), _haut = Offset(136, -12), _gauche = Offset(40, 168);

  /// Le caddie roule dans l'axe de ses roues (pixels de caddie.png : il descend de 17 pour 100 vers la droite).
  static const _pente = .17;

  /// Point (x, y) de la face (0 à 100), en coordonnées de la scène.
  Offset _surFeuille(double x, double y, double fx, double fy, double ech) =>
      Offset(fx, fy) + (_origine + _haut * (x / 100) + _gauche * (y / 100)) * ech;

  List<Widget> _scene(double t, double w, double h) {
    // Moments (fractions de la durée totale)
    final apparition = _entre(t, 0, .05);
    final crayonVenu = _entre(t, .05, .09);
    final traits = [for (var i = 0; i < _lignes; i++) _entre(t, .10 + i * .06, .15 + i * .06, Curves.easeOut)];
    final crayonParti = _entre(t, .40, .47, Curves.linear);
    final rapetisse = _entre(t, .47, .54);
    final caddie = _entre(t, .52, .60, Curves.easeOut);
    final listeFinie = _entre(t, .82, .89, Curves.linear);
    final recentre = _entre(t, .88, .93);
    final caddieParti = _entre(t, .95, .985);
    final imageFinale = _entre(t, .97, 1);

    // La feuille (rapport 214 × 240) : à la taille de Préparer, puis à droite comme dans l'image des courses.
    final fh = _mix(h, h * .78, rapetisse);
    final fw = fh * 214 / 240;
    final ech = fw / 214;
    final fx = _mix((w - fw) / 2 - h * .08, w - fw, rapetisse);
    final fy = _mix(0, h * .02, rapetisse);

    // Les traits et les coches, dans le carré de la face
    const lignesY = [12.0, 27.0, 42.0, 57.0, 72.0];
    const traitX = 42.0, traitW = 40.0, traitH = traitW * 38 / 160;

    // (nom, taille, position dans le panier de 0 à 1, moment de la chute, inclinaison, bas de l'objet arrivé)
    // Les premiers tombent au fond ; les suivants s'entassent et dépassent du panier, comme dans l'image Emplettes.
    final articles = [
      ('fromage', .24, .22, .60, -.1, 150.0),
      ('boite', .24, .78, .63, .1, 150.0),
      ('eau', .30, .48, .66, -.08, 148.0),
      ('salade', .32, .80, .70, .15, 100.0),
      ('pain', .38, .58, .73, .35, 96.0),
      ('lait', .30, .10, .77, -.12, 100.0),
      ('pomme', .30, .34, .80, 0.0, 104.0),
    ];
    // Caddie (260 × 257) : arrive de la gauche, derrière la liste ; au centre à la fin.
    final cw = h * .86;
    final ce = cw / 260;
    final avance = _mix(-h * .45, 0, caddie) + recentre * (w - cw) / 2;
    final cx = avance;
    final cy = h * .10 + avance * _pente;
    final opaciteCaddie = caddie * (1 - caddieParti);

    final scene = <Widget>[_img('caddie', cx, cy, cw, opacite: opaciteCaddie)];
    // Les articles tombent dans le panier : devant sa paroi du fond, derrière sa face avant (caddie_avant.png).
    for (final (nom, taille, x, debut, angle, bas) in articles) {
      final p = _entre(t, debut, debut + .06, Curves.bounceOut);
      if (p <= 0) continue;
      final aw = h * taille;
      final ah = aw * _proportions[nom]!; // hauteur de l'image
      final px = 72 + x * 120; // dans la largeur de la face avant (pixels de caddie.png)
      final fond = bas + (px - 70) * .06;
      scene.add(_img(nom, cx + px * ce - aw / 2, _mix(-h * .6, cy + fond * ce - ah, p), aw,
          opacite: _entre(t, debut, debut + .02) * (1 - caddieParti), angle: angle));
    }
    scene.add(_img('caddie_avant', cx, cy, cw, opacite: opaciteCaddie));

    // La liste par-dessus
    final liste = <Widget>[_img('feuille', fx, fy, fw)];
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
      // Une coche à chaque article ou presque : 3 vertes, 1 rouge (article pas trouvé), 1 verte
      final coche = _entre(t, .62 + i * .045, .67 + i * .045, Curves.elasticOut);
      if (coche > 0) {
        final cW = 16 * coche.clamp(0.0, 1.3);
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
    liste.add(Positioned(
      left: 0,
      top: 0,
      width: 100,
      height: 100,
      child: Transform(
        transform: Matrix4(_haut.dx * ech / 100, _haut.dy * ech / 100, 0, 0, _gauche.dx * ech / 100, _gauche.dy * ech / 100, 0, 0,
            0, 0, 1, 0, o.dx, o.dy, 0, 1),
        child: Stack(clipBehavior: Clip.none, children: face),
      ),
    ));
    scene.add(Positioned.fill(
      child: Opacity(
        opacity: apparition,
        child: Stack(clipBehavior: Clip.none, children: _poussiere(liste, Rect.fromLTWH(fx - 4, fy - 4, fw + 8, fh + 8), listeFinie, h)),
      ),
    ));

    // Le crayon suit la fin du trait en cours, puis part en poussière sur place
    if (crayonVenu > 0 && crayonParti < 1) {
      final enCours = traits.indexWhere((p) => p < 1);
      final i = enCours < 0 ? _lignes - 1 : enCours;
      final pointe = _surFeuille(traitX + traitW * traits[i], lignesY[i], fx, fy, ech);
      final cwr = h * .62;
      final chr = cwr * 200 / 143;
      final l = pointe.dx - cwr * .04, hautCrayon = pointe.dy - chr * .97;
      final crayon = _img('crayon', l, hautCrayon, cwr,
          opacite: crayonVenu, angle: crayonParti > 0 ? 0 : math.sin(t * 60) * .03);
      scene.addAll(_poussiere([crayon], Rect.fromLTWH(l, hautCrayon, cwr, chr), crayonParti, h));
    }

    // Les courses sont finies : l'image Emplettes reste.
    if (imageFinale > 0) {
      scene.add(_img('complet', (w - h) / 2, 0, h, opacite: imageFinale, dossier: 'assets/emplettes'));
    }
    return scene;
  }
}

class _Tuile extends CustomClipper<Rect> {
  _Tuile(this.r);
  final Rect r;
  @override
  Rect getClip(Size size) => r;
  @override
  bool shouldReclip(_Tuile old) => old.r != r;
}
