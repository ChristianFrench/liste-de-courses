import 'package:flutter/material.dart';

import 'donnees/modele.dart';
import 'ecrans/e04_je_fais_les_courses.dart';
import 'ecrans/e05_liste_complete.dart';
import 'ecrans/e08_produits.dart';
import 'ecrans/e11_magasins_parcours.dart';
import 'ecrans/e12_historique.dart';

/// Enchaînement des écrans (spécification IHM, chapitre 7).
class Nav {
  Nav._();

  static Future<T?> aller<T>(BuildContext context, Widget ecran) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => ecran));

  static Future<T?> remplacer<T>(BuildContext context, Widget ecran) =>
      Navigator.of(context).pushReplacement<T, Object?>(MaterialPageRoute<T>(builder: (_) => ecran));

  /// Ouvre un écran au-dessus de l'accueil (barre de navigation).
  static void depuisAccueil(BuildContext context, Widget ecran) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ecran),
      (route) => route.isFirst,
    );
  }

  static void accueil(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  /// Onglets de la barre de navigation : Accueil · Liste · Produits · Magasins · Historique.
  static void onglet(BuildContext context, int index) {
    switch (index) {
      case 0:
        accueil(context);
        break;
      case 1:
        final l = Etat.instance.listeEnCours;
        depuisAccueil(
          context,
          l != null ? EcranListeComplete(listeId: l.id) : const EcranJeFaisLesCourses(),
        );
        break;
      case 2:
        depuisAccueil(context, const EcranProduits());
        break;
      case 3:
        depuisAccueil(context, const EcranMagasinsParcours());
        break;
      case 4:
        depuisAccueil(context, const EcranHistorique());
        break;
    }
  }

  static void message(BuildContext context, String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte), duration: const Duration(seconds: 2)));
  }

  static void nonDisponible(BuildContext context) =>
      message(context, 'Non disponible dans la maquette');
}
