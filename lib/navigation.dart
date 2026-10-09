import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Navigation de la maquette v0.2 (Ecrans.yaml, chapitre « navigation ») :
/// 4 onglets, chacun avec ses sous-onglets mémorisés et sa propre pile d'écrans
/// (sous-niveaux : fiche, réglage). Les écrans de travail s'ouvrent par-dessus,
/// sans barre d'onglets.
class Nav extends ChangeNotifier {
  Nav._();
  static final Nav i = Nav._();

  static const int listes = 0;
  static const int historique = 1;
  static const int magasin = 2;
  static const int parametres = 3;

  // Sous-onglets
  static const int preparer = 0, parcours = 1, courses = 2;
  static const int coursesEffectuees = 0, tickets = 1;
  static const int rayons = 0, secteurs = 1, produits = 2;

  final racine = GlobalKey<NavigatorState>();
  final messager = GlobalKey<ScaffoldMessengerState>();
  final piles = List.generate(4, (_) => GlobalKey<NavigatorState>());

  int onglet = listes;
  final sousOnglet = [preparer, coursesEffectuees, rayons, 0];

  // État partagé de l'onglet Magasin
  String? magasinCourant;
  String? filtreRayonSecteurs; // null = Tous
  String? filtreRayonProduits;
  String? filtreSecteurProduits;

  /// Mode « indiquer le secteur » d'un produit (fiche produit → secteurs).
  String? produitAPlacer;

  /// Mode « rattacher un ticket » (tickets → courses effectuées).
  String? ticketARattacher;

  /// Liste prête choisie pour démarrer des courses (Listes › Courses).
  String? listeAPartir;

  void reinitialiser() {
    onglet = listes;
    sousOnglet.setAll(0, [preparer, coursesEffectuees, rayons, 0]);
    magasinCourant = null;
    filtreRayonSecteurs = filtreRayonProduits = filtreSecteurProduits = null;
    produitAPlacer = ticketARattacher = null;
    notifyListeners();
  }

  void signaler() => notifyListeners();

  /// Change d'onglet ; toucher l'onglet actif revient à sa racine.
  void allerOnglet(int o, {int? sous}) {
    if (o == onglet && sous == null) {
      piles[o].currentState?.popUntil((r) => r.isFirst);
    }
    onglet = o;
    if (sous != null) sousOnglet[o] = sous;
    notifyListeners();
  }

  void allerSous(int sous) {
    sousOnglet[onglet] = sous;
    notifyListeners();
  }

  /// Ferme les écrans de travail et revient aux onglets, sur l'onglet et le sous-onglet donnés.
  void retourOnglets(int o, int sous) {
    racine.currentState?.popUntil((r) => r.isFirst);
    piles[o].currentState?.popUntil((r) => r.isFirst);
    onglet = o;
    sousOnglet[o] = sous;
    notifyListeners();
  }

  /// Retour système (ou Échap sous Windows) sur les onglets : remonte d'un niveau ;
  /// sur un écran racine, va à Listes › Préparer, puis quitte.
  void retour() {
    final pile = piles[onglet].currentState;
    if (pile != null && pile.canPop()) {
      pile.pop();
      return;
    }
    if (onglet != listes || sousOnglet[listes] != preparer) {
      onglet = listes;
      sousOnglet[listes] = preparer;
      notifyListeners();
      return;
    }
    SystemNavigator.pop();
  }

  // ------------------------------------------------------------ Raccourcis

  /// Ouvre un écran dans la pile courante (sous-niveau : la barre d'onglets reste).
  static Future<T?> aller<T>(BuildContext context, Widget ecran) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => ecran));

  /// Ouvre un écran de travail, par-dessus les onglets (barre d'onglets masquée).
  static Future<T?> travail<T>(Widget ecran) =>
      i.racine.currentState!.push<T>(MaterialPageRoute<T>(builder: (_) => ecran));

  static Future<T?> remplacerTravail<T>(Widget ecran) =>
      i.racine.currentState!.pushReplacement<T, Object?>(MaterialPageRoute<T>(builder: (_) => ecran));

  static void message(BuildContext? context, String texte) {
    final m = i.messager.currentState;
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texte, style: Charte.texte(15, couleur: Charte.fond)),
        duration: const Duration(seconds: 2),
      ));
  }

  static void plusTard(BuildContext? context) => message(context, 'Disponible plus tard');
}
