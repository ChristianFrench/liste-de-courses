import 'dart:math' as math;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// Animation de l'accueil (scénario d'Aristide, 04/11/2026), jouée une fois par lancement :
// 1. la feuille apparaît seule en grandissant depuis son centre, à la taille de celle de Préparer, puis le crayon ;
// 2. les traits gris s'écrivent l'un après l'autre (le crayon les suit) ;
// 3. le crayon rapetisse puis éclate en petits fragments sur place (comme une application désinstallée sur un Xiaomi) ;
// 4. la liste rapetisse et se place comme dans l'image des courses ;
// 5. le caddie arrive de la gauche, vide, derrière la liste, en roulant dans l'axe de ses roues ;
// 6. les lignes se cochent une à une (3 vertes, 1 rouge, 1 verte) pendant que les articles tombent dans le caddie,
//    jusqu'à le remplir comme celui de l'image Emplettes ;
// 7. les courses sont finies : la liste éclate à son tour, puis le caddie plein rapetisse jusqu'à disparaître.
//    Aucun fondu (demande d'Aristide).
// 04/11/2026 (Aristide) : elle ne sert pas dans l'application, mais sur le mini site (docs/, rendue en image animée
// par test/site/animation_site_test.dart, ANIMATION=1).
// Images : planche d'Aristide (« Planche d'icônes courses en 3D »), découpée dans assets/emplettes/anim/.

const _dossier = 'outils/animation';

final _octets = <String, Uint8List>{};

/// Le contenu d'une image de outils/animation (lu une fois).
Uint8List octetsAnimation(String nom) => _octets.putIfAbsent(nom, () => File('$_dossier/$nom.png').readAsBytesSync());

/// Lignes de la liste ; la coche rouge est l'avant-dernière.
const _lignes = 5, _ligneRouge = 3;

/// Hauteur / largeur des images d'articles.
const _proportions = {
  'lait': 120 / 88, 'pomme': 120 / 113, 'pain': 120 / 99, 'fromage': 112 / 120, //
  'eau': 120 / 55, 'boite': 120 / 89, 'salade': 125 / 130,
};

/// Les images de l'animation (outils/animation), à précharger avant de dessiner.
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
  static const duree = Duration(milliseconds: 14000);

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

  /// Une image ; [echelle] la fait grandir depuis [depuis] (0 à 1 dans l'image, le centre par défaut).
  Widget _img(String nom, double l, double t, double largeur,
          {double echelle = 1, Alignment depuis = Alignment.center, double angle = 0}) =>
      Positioned(
        left: l,
        top: t,
        width: largeur,
        child: Transform.scale(
          scale: echelle,
          alignment: depuis,
          child: Transform.rotate(angle: angle, child: Image.memory(octetsAnimation(nom), width: largeur, filterQuality: FilterQuality.medium)),
        ),
      );

  /// Effet « désinstallation Xiaomi » : le groupe [enfants] (coordonnées de la scène) rapetisse de moitié,
  /// puis éclate en petits fragments qui partent dans tous les sens en rapetissant jusqu'à disparaître.
  /// [p] de 0 (intact) à 1 (disparu).
  List<Widget> _eclatement(List<Widget> enfants, Rect zone, double p, double h) {
    if (p <= 0) return enfants;
    if (p >= 1) return const [];
    const n = 16, finSerre = .45;
    final groupe = Stack(clipBehavior: Clip.none, children: enfants);
    final serre = 1 - .55 * _entre(p, 0, finSerre, Curves.easeInCubic);
    final c = zone.center;
    Matrix4 serrer() => Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(serre, serre, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    if (p < finSerre) return [Positioned.fill(child: Transform(transform: serrer(), child: groupe))];
    final res = <Widget>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final tuile = Rect.fromLTWH(zone.left + zone.width * i / n, zone.top + zone.height * j / n, zone.width / n + .3, zone.height / n + .3);
        double hasard(int k) => ((math.sin(i * 12.9898 + j * 78.233 + k * 37.719) * 43758.5453) % 1.0).abs();
        final q = _entre(p, finSerre + .1 * hasard(1), .8 + .2 * hasard(4), Curves.easeOutCubic);
        if (q >= 1) continue;
        // Chaque fragment part depuis le centre, un peu au hasard, et rapetisse jusqu'à rien.
        final dir = tuile.center - c;
        final angle = math.atan2(dir.dy, dir.dx) + (hasard(2) - .5) * 1.2;
        final loin = h * (.25 + .45 * hasard(3)) * q;
        final m = serrer()
          ..translateByDouble(tuile.center.dx, tuile.center.dy, 0, 1)
          ..translateByDouble(math.cos(angle) * loin / serre, math.sin(angle) * loin / serre, 0, 1)
          ..scaleByDouble(1 - q, 1 - q, 1, 1)
          ..translateByDouble(-tuile.center.dx, -tuile.center.dy, 0, 1);
        res.add(Positioned.fill(child: Transform(transform: m, child: ClipRect(clipper: _Tuile(tuile), child: groupe))));
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
    // Pas de fondu : tout arrive en grandissant ou en roulant, et part en éclatant ou en roulant.
    // Moments en secondes, ramenés à la durée totale.
    final d = AnimationEmplettes.duree.inMilliseconds / 1000;
    double sec(double a, double b, [Curve c = Curves.easeInOut]) => _entre(t, a / d, b / d, c);
    final apparition = sec(0, .7, Curves.easeOutBack);
    final crayonVenu = sec(.7, 1.2, Curves.easeOutBack);
    final traits = [for (var i = 0; i < _lignes; i++) sec(1.3 + i * .9, 2.05 + i * .9, Curves.easeOut)];
    final crayonParti = sec(5.75, 6.7, Curves.linear);
    final rapetisse = sec(6.7, 7.5);
    final caddie = sec(7.1, 8.1, Curves.easeOut);
    final listeFinie = sec(11.9, 12.8, Curves.linear);
    final caddieParti = sec(12.9, 13.8, Curves.easeInBack); // il rapetisse vers son centre, à l'inverse de la feuille

    // La feuille (rapport 214 × 240) : à la taille de Préparer, puis à droite comme dans l'image des courses.
    final fh = _mix(h, h * .78, rapetisse);
    final fw = fh * 214 / 240;
    final ech = fw / 214;
    final fx = _mix((w - fw) / 2 - h * .08, w - fw, rapetisse);
    final fy = _mix(0, h * .02, rapetisse);

    // Les traits et les coches, dans le carré de la face
    const lignesY = [10.0, 27.0, 44.0, 61.0, 78.0];
    const traitX = 42.0, traitW = 40.0, traitH = traitW * 38 / 160;

    // (nom, taille, position dans le panier de 0 à 1, début de la chute en secondes, inclinaison, bas de l'objet arrivé)
    // Les premiers tombent au fond ; les suivants s'entassent et dépassent du panier, comme dans l'image Emplettes.
    final articles = [
      ('fromage', .24, .22, 7.90, -.1, 150.0),
      ('boite', .24, .78, 8.35, .1, 150.0),
      ('eau', .30, .48, 8.80, -.08, 148.0),
      ('salade', .32, .80, 9.25, .15, 100.0),
      ('pain', .38, .58, 9.70, .35, 96.0),
      ('lait', .30, .10, 10.15, -.12, 100.0),
      ('pomme', .30, .34, 10.60, 0.0, 104.0),
    ];
    // Caddie (260 × 257) : arrive de la gauche, derrière la liste ; au centre à la fin.
    final cw = h * .86;
    final ce = cw / 260;
    // Il arrive de la gauche, hors du champ.
    final avance = _mix(-cw * 1.05, 0, caddie);
    final cx = avance;
    final cy = h * .10 + avance * _pente;

    final chariot = <Widget>[_img('caddie', cx, cy, cw)];
    // Les articles tombent dans le panier : devant sa paroi du fond, derrière sa face avant (caddie_avant.png).
    for (final (nom, taille, x, debut, angle, bas) in articles) {
      final p = sec(debut, debut + .8, Curves.bounceOut);
      if (p <= 0) continue;
      final aw = h * taille;
      final ah = aw * _proportions[nom]!; // hauteur de l'image
      final px = 72 + x * 120; // dans la largeur de la face avant (pixels de caddie.png)
      final fond = bas + (px - 70) * .06;
      chariot.add(_img(nom, cx + px * ce - aw / 2, _mix(-h - ah, cy + fond * ce - ah, p), aw,
          angle: angle));
    }
    chariot.add(_img('caddie_avant', cx, cy, cw));
    // Le caddie entre et sort par les côtés : on le coupe à gauche et à droite (le crayon et la liste, non).
    final centreCaddie = Offset(cx + cw / 2, cy + cw / 2);
    final reste = 1 - caddieParti;
    final scene = <Widget>[
      if (reste > 0)
        Positioned.fill(
          child: ClipRect(
            clipper: _Tuile(Rect.fromLTWH(0, -h * .9, w, h * 2)),
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(centreCaddie.dx, centreCaddie.dy, 0, 1)
                ..scaleByDouble(reste, reste, 1, 1)
                ..translateByDouble(-centreCaddie.dx, -centreCaddie.dy, 0, 1),
              child: Stack(clipBehavior: Clip.none, children: chariot),
            ),
          ),
        ),
    ];

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
            child: Image.memory(octetsAnimation('trait'), width: traitW, filterQuality: FilterQuality.medium),
          ),
        ),
      ));
      // Une coche à chaque article ou presque : 3 vertes, 1 rouge (article pas trouvé), 1 verte
      final coche = sec(8.2 + i * .7, 8.8 + i * .7, Curves.elasticOut);
      if (coche > 0) {
        final cW = 16 * coche.clamp(0.0, 1.3);
        face.add(Positioned(
          left: 24 - cW / 2,
          top: lignesY[i] - cW * .6,
          width: cW,
          child: Image.memory(octetsAnimation(i == _ligneRouge ? 'coche_rouge' : 'coche_verte'), width: cW, filterQuality: FilterQuality.medium),
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
    // La feuille grandit depuis son centre au début.
    final centreFeuille = Offset(fx + fw / 2, fy + fh / 2);
    scene.add(Positioned.fill(
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(centreFeuille.dx, centreFeuille.dy, 0, 1)
          ..scaleByDouble(apparition, apparition, 1, 1)
          ..translateByDouble(-centreFeuille.dx, -centreFeuille.dy, 0, 1),
        child: Stack(clipBehavior: Clip.none, children: _eclatement(liste, Rect.fromLTWH(fx - 4, fy - 4, fw + 8, fh + 8), listeFinie, h)),
      ),
    ));

    // Le crayon suit la fin du trait en cours, puis part en poussière sur place
    if (crayonVenu > 0 && crayonParti < 1) {
      final enCours = traits.indexWhere((p) => p < 1);
      final i = enCours < 0 ? _lignes - 1 : enCours;
      final pointe = _surFeuille(traitX + traitW * traits[i], lignesY[i], fx, fy, ech);
      final cwr = h * .42; // assez petit pour rester entier dans le cadre
      final chr = cwr * 200 / 143;
      final l = pointe.dx - cwr * .04, hautCrayon = pointe.dy - chr * .97;
      final crayon = _img('crayon', l, hautCrayon, cwr,
          echelle: crayonVenu, depuis: const Alignment(-.92, .94), angle: crayonParti > 0 ? 0 : math.sin(t * 60) * .03);
      scene.addAll(_eclatement([crayon], Rect.fromLTWH(l, hautCrayon, cwr, chr), crayonParti, h));
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
