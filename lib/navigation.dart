import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ecrans/coquille.dart' show BarreOnglets;
import 'theme.dart';

/// Navigation (agencement du 19 octobre 2026) : 3 onglets — Préparer, Courses, Gérer —
/// chacun avec sa propre pile d'écrans. Gérer ouvre des rubriques (magasins, parcours,
/// historique, paramètres, corbeille) dont certaines ont des sous-onglets mémorisés.
/// Les écrans de travail s'ouvrent par-dessus, en gardant la barre d'onglets en bas.
class Nav extends ChangeNotifier {
  Nav._();
  static final Nav i = Nav._();

  // Onglets
  static const int accueil = 0;
  static const int preparer = 1;
  static const int courses = 2;
  static const int gerer = 3;
  static const int nbOnglets = 4;

  // Rubriques de Gérer
  static const int magasin = 10, parcours = 11, historique = 12, parametres = 13, corbeille = 14, foyer = 15, archives = 16;

  // Sous-onglets des rubriques
  static const int coursesEffectuees = 0, tickets = 1;
  static const int rayons = 0, secteurs = 1, produits = 2;

  final racine = GlobalKey<NavigatorState>();
  final messager = GlobalKey<ScaffoldMessengerState>();
  final piles = List.generate(nbOnglets, (_) => GlobalKey<NavigatorState>());

  int onglet = accueil;

  /// Rubrique de Gérer affichée (null : menu de Gérer).
  int? rubrique;
  final sousOnglet = <int, int>{historique: coursesEffectuees, magasin: rayons};

  // État partagé de la rubrique Magasins
  String? magasinCourant;

  /// Rubrique Magasins ouverte sur la liste des magasins (avant d'en choisir un).
  bool choixMagasin = false;
  String? filtreRayonSecteurs; // null = Tous
  String? filtreRayonProduits;
  String? filtreSecteurProduits;

  /// Mode « indiquer le secteur » d'un produit (fiche produit → secteurs).
  String? produitAPlacer;

  /// Mode « rattacher un ticket » (tickets → courses effectuées).
  String? ticketARattacher;

  /// Liste prête choisie pour démarrer des courses (onglet Courses).
  String? listeAPartir;

  /// Ouvre une rubrique de Gérer ; le constructeur d'écran est fourni par la coquille.
  static Widget Function(int rubrique)? ecranRubrique;

  void reinitialiser() {
    onglet = accueil;
    rubrique = null;
    sousOnglet
      ..[historique] = coursesEffectuees
      ..[magasin] = rayons;
    magasinCourant = null;
    choixMagasin = false;
    filtreRayonSecteurs = filtreRayonProduits = filtreSecteurProduits = null;
    produitAPlacer = ticketARattacher = null;
    notifyListeners();
  }

  void signaler() => notifyListeners();

  /// Change d'onglet ; toucher l'onglet actif revient à sa racine.
  void allerOnglet(int o) {
    if (o == onglet) {
      piles[o].currentState?.popUntil((r) => r.isFirst);
      if (o == gerer) rubrique = null;
    }
    onglet = o;
    notifyListeners();
  }

  /// Sous-onglet de la rubrique affichée.
  void allerSous(int sous) {
    final r = rubrique;
    if (r != null) sousOnglet[r] = sous;
    notifyListeners();
  }

  /// Ouvre une rubrique de Gérer (depuis n'importe où) : onglet Gérer, au-dessus de son menu.
  void ouvrirRubrique(int r, {int? sous}) {
    racine.currentState?.popUntil((x) => x.isFirst);
    final pile = piles[gerer].currentState;
    pile?.popUntil((x) => x.isFirst);
    onglet = gerer;
    rubrique = r;
    if (sous != null) sousOnglet[r] = sous;
    notifyListeners();
    if (pile != null && ecranRubrique != null) {
      pile.push(MaterialPageRoute<void>(builder: (_) => ecranRubrique!(r))).then((_) => _fermeRubrique(r));
    }
  }

  void _fermeRubrique(int r) {
    if (rubrique == r) {
      rubrique = null;
      notifyListeners();
    }
  }

  /// Ferme les écrans de travail et revient à l'onglet donné.
  void retourOnglet(int o) {
    racine.currentState?.popUntil((r) => r.isFirst);
    piles[o].currentState?.popUntil((r) => r.isFirst);
    if (o == gerer) rubrique = null;
    onglet = o;
    notifyListeners();
  }

  /// Retour système (ou Échap sous Windows) sur les onglets : remonte d'un niveau ;
  /// sur un écran racine, va à Préparer, puis quitte.
  void retour() {
    final pile = piles[onglet].currentState;
    if (pile != null && pile.canPop()) {
      pile.pop();
      return;
    }
    if (onglet != accueil) {
      onglet = accueil;
      notifyListeners();
      return;
    }
    SystemNavigator.pop();
  }

  // ------------------------------------------------------------ Raccourcis

  /// Ouvre un écran dans la pile courante (sous-niveau : la barre d'onglets reste).
  static Future<T?> aller<T>(BuildContext context, Widget ecran) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => ecran));

  /// Ouvre un écran de travail, par-dessus les onglets ; la barre d'onglets reste en bas.
  static Future<T?> travail<T>(Widget ecran) =>
      i.racine.currentState!.push<T>(MaterialPageRoute<T>(builder: (_) => AvecOnglets(child: ecran)));

  static Future<T?> remplacerTravail<T>(Widget ecran) =>
      i.racine.currentState!.pushReplacement<T, Object?>(MaterialPageRoute<T>(builder: (_) => AvecOnglets(child: ecran)));

  static void message(BuildContext? context, String texte) {
    final m = i.messager.currentState;
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texte, style: Charte.texte(15, couleur: Charte.blanc)),
        duration: const Duration(seconds: 2),
      ));
  }

  static void plusTard(BuildContext? context) => message(context, 'Disponible plus tard');
}

/// Écran de travail avec la barre des onglets en bas. Toucher un onglet quitte l'écran de travail,
/// sauf pendant les courses : on passe alors par la pause.
class AvecOnglets extends StatelessWidget {
  const AvecOnglets({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: Charte.fond,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: MediaQuery.removePadding(context: context, removeBottom: true, child: child)),
            BarreOnglets(
              actif: Nav.i.onglet,
              onChoix: (o) {
                final route = ModalRoute.of(context);
                if (route != null && route.isCurrent && route.popDisposition == RoutePopDisposition.doNotPop) {
                  Navigator.of(context).maybePop();
                  return;
                }
                Nav.i.retourOnglet(o);
              },
            ),
          ],
        ),
      );
}
