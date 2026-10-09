import 'package:flutter/material.dart';

/// Charte de la maquette (spécification IHM, chapitre 4) : volontairement monochrome.
class Charte {
  Charte._();

  static const String police = 'Atkinson';

  // Couleurs
  static const Color encre = Color(0xFF222222);
  static const Color fond = Color(0xFFFFFFFF);
  static const Color fondSelection = Color(0xFFF2F2F2);
  static const Color fondBandeau = Color(0xFFF7F7F7);
  static const Color texteSecondaire = Color(0xFF555555);
  static const Color separateurZone = Color(0xFFCCCCCC);
  static const Color separateurLigne = Color(0xFFDDDDDD);
  static const Color texteBarre = Color(0xFF6E6E6E);
  static const Color placeholder = Color(0xFFE6E6E6);

  // Hauteurs de référence (points)
  static const double enTeteTravail = 48;
  static const double enTeteGestion = 60;
  static const double bandeauPuces = 44;
  static const double ligneConstruction = 44;
  static const double ligneCourses = 56;
  static const double ligneCompacte = 32;
  static const double barreAction = 64;
  static const double barreNavigation = 64;

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

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: police,
      colorScheme: ColorScheme.fromSeed(
        seedColor: encre,
        primary: encre,
        onPrimary: fond,
        surface: fond,
        onSurface: encre,
      ),
      scaffoldBackgroundColor: fond,
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      dividerColor: separateurLigne,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: encre,
        contentTextStyle: TextStyle(fontFamily: police, fontSize: 15, color: fond),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: encre, width: traitCadre),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: encre, width: traitCadre),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: encre, width: 3),
        ),
        hintStyle: TextStyle(fontFamily: police, color: texteSecondaire),
      ),
    );
  }
}
