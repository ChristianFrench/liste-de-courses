import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Une famille de couleurs : fond des écrans, barres du haut et du bas, boutons actifs ou non,
/// fonds plus ou moins pâles de la même teinte. Les textes et les traits restent foncés.
class Palette {
  const Palette(this.nom, this.accent, this.accentFonce, this.fond, this.fondBarre, this.fondSelection, this.separateur);
  final String nom;
  final Color accent; // boutons pleins, puces choisies, cases cochées
  final Color accentFonce; // cadres des boutons, icônes d'action
  final Color fond; // fond des écrans
  final Color fondBarre; // en-têtes, zone de décision, barre des onglets
  final Color fondSelection; // ligne choisie, titres de groupe
  final Color separateur;
}

const palettes = <Palette>[
  Palette('Sauge', Color(0xFF3F7D5A), Color(0xFF2B5A40), Color(0xFFF5F9F6), Color(0xFFE3EFE7), Color(0xFFD5E8DC), Color(0xFFB9D3C3)),
  Palette('Océan', Color(0xFF2F6EA5), Color(0xFF1F4E79), Color(0xFFF4F8FC), Color(0xFFE0ECF7), Color(0xFFD0E2F3), Color(0xFFB3CDE6)),
  Palette('Terracotta', Color(0xFFB85C38), Color(0xFF8A3F22), Color(0xFFFCF7F4), Color(0xFFF6E6DD), Color(0xFFF0D7C9), Color(0xFFE2BFAA)),
  Palette('Lavande', Color(0xFF6E5AA8), Color(0xFF4E3D80), Color(0xFFF8F6FC), Color(0xFFEAE5F5), Color(0xFFDDD5EF), Color(0xFFC7BCE3)),
  Palette('Noir et blanc', Color(0xFF222222), Color(0xFF222222), Color(0xFFFFFFFF), Color(0xFFF7F7F7), Color(0xFFF2F2F2), Color(0xFFCCCCCC)),
];

/// Palettes de plus, proposées dans une liste déroulante (Paramètres › Apparence › Autres palettes).
const autresPalettes = <Palette>[
  Palette('Framboise', Color(0xFFB02E5E), Color(0xFF7F2144), Color(0xFFFBF5F7), Color(0xFFF4E2E8), Color(0xFFEED3DD), Color(0xFFE3B6C7)),
  Palette('Moutarde', Color(0xFFA67C00), Color(0xFF785900), Color(0xFFFBF8F2), Color(0xFFF3EDDB), Color(0xFFECE3C9), Color(0xFFE0D1A6)),
  Palette('Pétrole', Color(0xFF1F6F78), Color(0xFF165056), Color(0xFFF4F8F8), Color(0xFFE0EBEC), Color(0xFFD0E1E3), Color(0xFFB1CDD0)),
  Palette('Ardoise', Color(0xFF4A5A6A), Color(0xFF35414C), Color(0xFFF6F7F8), Color(0xFFE6E8EA), Color(0xFFD9DCE0), Color(0xFFC0C5CB)),
  Palette('Olive', Color(0xFF6B702A), Color(0xFF4D511E), Color(0xFFF8F8F4), Color(0xFFEAEBE1), Color(0xFFE0E1D2), Color(0xFFCBCDB4)),
  Palette('Prune', Color(0xFF7A356A), Color(0xFF58264C), Color(0xFFF8F5F8), Color(0xFFECE3EA), Color(0xFFE3D5E0), Color(0xFFD0B8CB)),
  Palette('Corail', Color(0xFFD05A4E), Color(0xFF964138), Color(0xFFFDF7F6), Color(0xFFF8E8E6), Color(0xFFF5DCDA), Color(0xFFEFC5C1)),
  Palette('Menthe', Color(0xFF2E8B74), Color(0xFF216454), Color(0xFFF5F9F8), Color(0xFFE2EFEC), Color(0xFFD3E7E2), Color(0xFFB6D6CE)),
  Palette('Chocolat', Color(0xFF6B4530), Color(0xFF4D3223), Color(0xFFF8F6F5), Color(0xFFEAE5E2), Color(0xFFE0D8D4), Color(0xFFCBBEB7)),
  Palette('Marine', Color(0xFF233A6B), Color(0xFF192A4D), Color(0xFFF4F5F8), Color(0xFFE0E3EA), Color(0xFFD1D6E0), Color(0xFFB2BACB)),
  Palette('Cerise', Color(0xFFA81C2E), Color(0xFF791421), Color(0xFFFBF4F5), Color(0xFFF3DFE2), Color(0xFFEDCFD3), Color(0xFFE1B0B6)),
  Palette('Turquoise', Color(0xFF13849A), Color(0xFF0E5F6F), Color(0xFFF3F9FA), Color(0xFFDEEEF1), Color(0xFFCDE5EA), Color(0xFFACD4DC)),
];

/// Toutes les palettes : les cinq présentées en pastilles, puis les autres.
const toutesLesPalettes = <Palette>[...palettes, ...autresPalettes];

/// Charte de l'application : les couleurs viennent de la palette choisie dans Paramètres › Apparence.
class Charte {
  Charte._();

  static const String police = 'Atkinson';

  static Palette palette = palettes.first;

  /// Change de palette et redessine toute l'application, sans la relancer.
  static void choisirPalette(String nom) {
    palette = toutesLesPalettes.firstWhere((p) => p.nom == nom, orElse: () => palettes.first);
    void redessiner(Element e) {
      e.markNeedsBuild();
      e.visitChildren(redessiner);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(redessiner);
  }

  // Couleurs fixes : textes et traits
  static const Color encre = Color(0xFF222222);
  static const Color blanc = Color(0xFFFFFFFF);
  static const Color texteSecondaire = Color(0xFF555555);
  static const Color texteBarre = Color(0xFF777777); // texteCoche
  static const Color texteCoche = Color(0xFF777777);
  static const Color voile = Color(0x73000000); // noir 45 %
  static const Color placeholder = Color(0xFFE6E6E6);

  // Couleurs de la palette
  static Color get accent => palette.accent;
  static Color get cadre => palette.accentFonce;
  static Color get fond => palette.fond;
  static Color get fondBandeau => palette.fondBarre;
  static Color get fondSelection => palette.fondSelection;
  static Color get fondNavActive => palette.fondSelection;
  static Color get separateurZone => palette.separateur;
  static Color get separateurLigne => Color.alphaBlend(palette.separateur.withValues(alpha: 0.6), blanc);
  static Color get desactive => Color.alphaBlend(palette.accent.withValues(alpha: 0.35), blanc);

  /// Couleur d'une icône d'action, la même partout : rouge pour supprimer, bleu pour modifier…
  static Color couleurIcone(IconData i) {
    // Une seule famille d'icônes : au trait, d'une seule couleur (celle de la palette).
    if (i == Icons.drag_handle || i == Icons.drag_indicator) return texteSecondaire;
    return cadre;
  }

  // Hauteurs de référence (points)
  static const double enTeteTravail = 48;
  static const double enTeteGestion = 60;
  static const double bandeauPuces = 44;
  static const double ligneConstruction = 44;
  static const double ligneCourses = 56;
  static const double ligneCompacte = 32;
  static const double barreAction = 64;
  static const double barreNavigation = 64;
  static const double enTeteNiveau = 52;
  static const double sousOnglets = 44;
  static const double barreOnglets = 64;
  static const double puce = 36;
  static const double bouton = 48;
  static const double selecteurQuantite = 34;

  // Tailles de texte (Charte.tokens.json v0.2)
  static const double tTitreNiveau = 20;
  static const double tTitreTravail = 17;
  static const double tNavigation = 11;
  static const double tCodePromo = 9;

  // Espacements
  static const double e1 = 4;
  static const double e2 = 8;
  static const double e3 = 12;
  static const double e4 = 16;

  // Traits
  static const double traitCadre = 2;
  static const double traitSeparateur = 1;

  static TextStyle texte(double taille,
      {bool gras = false, Color couleur = encre, bool barre = false, double? espacement}) {
    return TextStyle(
      fontFamily: police,
      fontSize: taille,
      fontWeight: gras ? FontWeight.w700 : FontWeight.w400,
      color: couleur,
      decoration: barre ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: couleur,
      letterSpacing: espacement,
      height: 1.2,
    );
  }

  static TextStyle get titreEcran => texte(18, gras: true);
  static TextStyle get ligneChoix => texte(15);
  static TextStyle get ligneCourse => texte(17);
  static TextStyle get secondaire => texte(12, couleur: texteSecondaire);
  static TextStyle get titreGroupe => texte(12, gras: true, espacement: 1.0);

  /// Les bandeaux et listes défilent aussi en glissant à la souris (Windows).
  static ScrollBehavior defilement() => const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      });

  // Couleurs des icônes : une par onglet et par rubrique de Gérer.
  static const vert = Color(0xFF2E7D32);
  static const orange = Color(0xFFEF6C00);
  static const bleu = Color(0xFF1565C0);
  static const violet = Color(0xFF6A1B9A);
  static const turquoise = Color(0xFF00838F);
  static const brun = Color(0xFF6D4C41);
  static const rouge = Color(0xFFC62828);
  static const gris = Color(0xFF546E7A);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: police,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        onPrimary: blanc,
        surface: fond,
        onSurface: encre,
      ),
      scaffoldBackgroundColor: fond,
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      dividerColor: separateurLigne,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cadre,
        contentTextStyle: const TextStyle(fontFamily: police, fontSize: 15, color: blanc),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: blanc,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: cadre, width: traitCadre),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: cadre, width: traitCadre),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: accent, width: 3),
        ),
        hintStyle: const TextStyle(fontFamily: police, color: texteSecondaire),
      ),
    );
  }
}
