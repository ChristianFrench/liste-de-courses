import 'package:flutter/material.dart';

import '../donnees/open_food_facts.dart';
import '../theme.dart';

/// Code-barres EAN-13 dessiné, avec les chiffres dessous.
/// Pour un autre format (EAN-8, code interne…), seuls les chiffres sont affichés.
class CodeBarres extends StatelessWidget {
  const CodeBarres({super.key, required this.code, this.hauteur = 56, this.largeur = 190});
  final String code;
  final double hauteur;
  final double largeur;

  @override
  Widget build(BuildContext context) {
    final valide = ean13Valide(code);
    return Semantics(
      label: 'Code-barres $code',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (valide)
            SizedBox(
              width: largeur,
              height: hauteur,
              child: CustomPaint(painter: _PeintreEan13(modulesEan13(code))),
            ),
          const SizedBox(height: 2),
          Text(
            valide ? '${code[0]}  ${code.substring(1, 7)}  ${code.substring(7)}' : code,
            style: Charte.texte(13, espacement: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PeintreEan13 extends CustomPainter {
  _PeintreEan13(this.modules);
  final List<bool> modules;

  @override
  void paint(Canvas canvas, Size size) {
    // 95 modules + 7 de marge blanche de chaque côté
    final module = size.width / (modules.length + 14);
    final pinceau = Paint()..color = Charte.encre;
    for (var i = 0; i < modules.length; i++) {
      if (!modules[i]) continue;
      // Barres de garde (début, milieu, fin) plus longues
      final garde = i < 3 || (i >= 45 && i < 50) || i >= 92;
      final h = garde ? size.height : size.height * 0.88;
      canvas.drawRect(Rect.fromLTWH((i + 7) * module, 0, module + 0.2, h), pinceau);
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreEan13 ancien) => ancien.modules != modules;
}

/// Pastille Nutri-Score (lettre), monochrome comme le reste de la maquette.
class PastilleNutriscore extends StatelessWidget {
  const PastilleNutriscore({super.key, required this.lettre});
  final String lettre;

  @override
  Widget build(BuildContext context) {
    if (lettre.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Nutri-Score ${lettre.toUpperCase()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Charte.encre, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nutri-Score ', style: Charte.texte(11)),
            Text(lettre.toUpperCase(), style: Charte.texte(12, gras: true)),
          ],
        ),
      ),
    );
  }
}

/// Photo d'un article Open Food Facts, avec un cadre gris tant qu'elle n'est pas chargée.
class PhotoArticle extends StatelessWidget {
  const PhotoArticle({super.key, required this.url, required this.taille});
  final String url;
  final double taille;

  @override
  Widget build(BuildContext context) {
    Widget vide(String texte) => Container(
          width: taille,
          height: taille,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Charte.placeholder, borderRadius: BorderRadius.circular(6)),
          child: Text(texte, textAlign: TextAlign.center, style: Charte.texte(11, couleur: Charte.texteSecondaire)),
        );
    if (url.isEmpty) return vide('Pas de photo');
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: taille,
        height: taille,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          headers: const {'User-Agent': OpenFoodFacts.agent},
          loadingBuilder: (context, enfant, progression) => progression == null ? enfant : vide('…'),
          errorBuilder: (context, erreur, pile) => vide('Photo indisponible'),
        ),
      ),
    );
  }
}
