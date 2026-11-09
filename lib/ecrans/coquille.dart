import '../composants/icone.dart';
import 'dart:async';

// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

import '../composants/barre_ouverture.dart';
import '../composants/composants.dart';
import '../donnees/base_locale.dart' show ecrireSurDisque;
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';
import 'accueil.dart';
import 'archives.dart';
import 'bienvenue.dart';
import 'catalogue.dart';
import 'corbeille.dart';
import 'editeur_catalogue.dart';
import 'foyer.dart';
import 'messages.dart';
import 'historique.dart';
import 'listes.dart';
import 'parametres.dart';

/// Barre d'onglets (64) : 3 entrées icône 22 + libellé ; onglet actif = pastille 56 × 30 pleine.
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.actif, required this.onChoix});
  final int actif;
  final ValueChanged<int> onChoix;

  static const entrees = <(IconData, String)>[
    (Icons.home_outlined, 'Accueil'),
    (Icons.checklist, 'Préparer'),
    (Icons.shopping_cart_outlined, 'Courses'),
    (Icons.tune, 'Gérer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.barreOnglets + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Charte.fondBandeau,
        border: Border(top: BorderSide(color: Charte.separateurZone, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entrees.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == actif,
                label: entrees[i].$2,
                child: InkWell(
                  onTap: () => onChoix(i),
                  // 01/11/2026 (Aristide) : grande icône, le libellé posé dessus, en bas.
                  child: Center(
                    child: Container(
                      width: 72,
                      height: Charte.barreOnglets - 6,
                      decoration: BoxDecoration(
                        color: i == actif ? Charte.clair(Charte.accent, 0.55) : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Positioned(
                            top: 0,
                            child: i == 3
                                ? Icone(entrees[i].$1, size: 56, color: Charte.cadre)
                                : ImageEmplettes(i == 0 ? 'complet' : ImageEmplettes.pourIcone(entrees[i].$1), taille: 60)),
                        Positioned(
                          bottom: 1,
                          child: Text(entrees[i].$2,
                              style: Charte.texte(Charte.tNavigation + 1, gras: true, couleur: Charte.encre).copyWith(shadows: const [
                                Shadow(color: Color(0xFFFFFFFF), blurRadius: 3),
                                Shadow(color: Color(0xFFFFFFFF), blurRadius: 2),
                                Shadow(color: Color(0xFFFFFFFF), blurRadius: 1),
                              ])),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les trois onglets, chacun avec sa pile d'écrans.
class Coquille extends StatelessWidget {
  const Coquille({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Nav.i;
    // Premier lancement (ou partage interrompu) : seul ou en foyer ?
    return ListenableBuilder(
      listenable: Synchro.instance,
      builder: (context, coquille) {
        final s = Synchro.instance;
        if (Etat.instance.dejaOuverte) return const _DejaOuverte();
        if (Etat.instance.erreurBase != null) return _ErreurBase(Etat.instance.erreurBase!);
        return s.mode.isEmpty || (s.suspendu != null && !s.actif) ? const EcranBienvenue() : coquille!;
      },
      child: GuetteurQuiSuisJe(child: GuetteurMiseAJour(child: GuetteurNouveautes(child: AlerteEnregistrement(child: ListenableBuilder(
      listenable: nav,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (aFerme, _) {
          if (!aFerme) nav.retour();
        },
        child: Scaffold(
          backgroundColor: Charte.fond,
          body: IndexedStack(
            index: nav.onglet,
            children: [
              for (var o = 0; o < Nav.nbOnglets; o++)
                Navigator(
                  key: nav.piles[o],
                  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => RacineOnglet(onglet: o)),
                ),
            ],
          ),
          bottomNavigationBar: BarreOnglets(actif: nav.onglet, onChoix: (o) => nav.allerOnglet(o)),
        ),
      ),
      ))))),
    );
  }
}

/// Mise à jour faite à l'ouverture : plus de fenêtre (01/11/2026, Aristide), une barre de progression légère
/// sur la photo de l'accueil, au-dessus de « Comment ça marche » ([BarreOuverture]) : « Synchronisation » en
/// foyer, « Initialisation » pour un appareil seul.
class GuetteurMiseAJour extends StatefulWidget {
  const GuetteurMiseAJour({super.key, required this.child});
  final Widget child;

  @override
  State<GuetteurMiseAJour> createState() => _GuetteurMiseAJourState();
}

class _GuetteurMiseAJourState extends State<GuetteurMiseAJour> {
  final _debut = DateTime.now();
  Timer? _minuteur;
  DateTime? _finie;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(milliseconds: 100), (_) => _avancer());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  bool get _foyer => Synchro.instance.ouverture != null;

  /// Appareil seul : la base est déjà lue, la barre fait un court passage d'une seconde.
  double get _progres => _foyer ? Synchro.instance.progresOuverture : (DateTime.now().difference(_debut).inMilliseconds / 1000).clamp(0.0, 1.0);

  /// Valeur affichée : elle ne recule jamais (03/11/2026, Aristide : la barre faisait des retours en arrière
  /// à chaque paquet reçu) ; quand la synchronisation attend, elle avance encore doucement.
  double _affiche = 0;

  void _avancer() {
    if (!mounted) return;
    final o = Synchro.instance.ouverture;
    final brut = _progres;
    _affiche = brut >= 1 ? 1 : (brut > _affiche ? brut : _affiche + (0.95 - _affiche).clamp(0.0, 1.0) * 0.004);
    final valeur = _affiche;
    if (valeur >= 1) {
      _finie ??= DateTime.now();
      // La barre pleine reste un instant, puis disparaît.
      if (DateTime.now().difference(_finie!).inMilliseconds > 400) {
        _minuteur?.cancel();
        ouvertureEnCours.value = null;
        return;
      }
    }
    ouvertureEnCours.value = (
      texte: !_foyer ? 'Initialisation' : (o != null && o.horsLigne ? 'Hors ligne' : 'Synchronisation'),
      valeur: valeur,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Bandeau rouge en haut de l'application quand des modifications ne sont pas enregistrées (web : disque du
/// navigateur bloqué ; lignes refusées par la base). Web : quand la page est masquée ou fermée, on attend
/// que tout soit recopié sur le disque.
class AlerteEnregistrement extends StatefulWidget {
  const AlerteEnregistrement({super.key, required this.child});
  final Widget child;

  @override
  State<AlerteEnregistrement> createState() => _AlerteEnregistrementState();
}

class _AlerteEnregistrementState extends State<AlerteEnregistrement> {
  late final AppLifecycleListener _cycle = AppLifecycleListener(
    onInactive: ecrireSurDisque,
    onHide: () {
      Etat.instance.noterMiseEnRetrait();
      ecrireSurDisque();
    },
    onPause: ecrireSurDisque,
  );

  @override
  void initState() {
    super.initState();
    _cycle;
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Etat.instance,
        builder: (context, enfant) {
          final alerte = Etat.instance.alerteEnregistrement;
          return Column(children: [
            if (alerte != null)
              Material(
                key: const ValueKey('alerte-enregistrement'),
                color: Charte.rouge,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(children: [
                      const Icone(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(alerte, style: Charte.texte(14, gras: true, couleur: Colors.white))),
                    ]),
                  ),
                ),
              ),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: alerte != null, child: enfant!)),
          ]);
        },
        child: widget.child,
      );
}

/// Écran racine d'un onglet : Préparer, Courses, ou le menu de Gérer.
class RacineOnglet extends StatelessWidget {
  const RacineOnglet({super.key, required this.onglet});
  final int onglet;

  @override
  Widget build(BuildContext context) {
    Nav.ecranRubrique ??= (r) => EcranRubrique(rubrique: r);
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.i, Etat.instance]),
      builder: (context, _) => switch (onglet) {
        // Contenus recréés à chaque changement de données (pas de « const ») pour qu'ils se redessinent.
        Nav.accueil => EcranAccueil(),
        Nav.preparer => PageBase(
            entete: const EnTeteFenetre(icone: Icons.checklist, titre: 'Préparer', aide: Aides.preparer),
            corps: SousEcranPreparer(),
          ),
        Nav.courses => PageBase(entete: const EnTeteFenetre(icone: Icons.shopping_cart_outlined, titre: 'Courses', aide: Aides.courses), corps: SousEcranCourses()),
        _ => const MenuGerer(),
      },
    );
  }
}

/// Onglet Gérer : tout ce qui n'est ni la préparation ni les courses.
class MenuGerer extends StatelessWidget {
  const MenuGerer({super.key});

  // Les nombres (corbeille, magasins, produits…) suivent les changements faits dans les écrans ouverts depuis ici.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Etat.instance, builder: (context, _) => _construire(context));

  Widget _construire(BuildContext context) {
    final etat = Etat.instance;
    final n = etat.magasins.length;
    Widget ecran(IconData icone, String titre, String sousTitre, Widget e) =>
        LigneMenu(icone: icone, titre: titre, sousTitre: sousTitre, onTap: () => Nav.aller<void>(context, e));
    return PageBase(
      entete: const EnTeteFenetre(icone: Icons.tune, titre: 'Gérer', aide: Aides.gerer),
      corps: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // 02/11/2026 (Aristide) : sous-titres courts, les explications passent dans l'aide ; Messages regroupe
          // l'essai d'envoi de mail ; Synchronisation remonte dans Mon foyer ; Courses réordonné.
          GroupeRetractable(cle: 'gerer/foyer', titre: 'Mon foyer', icone: Icons.home_outlined, enfants: [
            ecran(Icons.home_outlined, 'Foyer',
                '${etat.foyerNom} · ${etat.membresVisibles.length} membre${etat.membresVisibles.length > 1 ? 's' : ''}', const EcranFoyer()),
            ecran(Icons.groups_outlined, 'Collaboration', 'Membres, notifications, mails, synchronisation', const EcranCollaboration()),
          ]),
          GroupeRetractable(cle: 'gerer/courses', titre: 'Courses', icone: Icons.shopping_cart_outlined, enfants: [
            ecran(Icons.storefront_outlined, 'Magasins', '$n magasin${n > 1 ? 's' : ''}', const EcranMagasins()),
            ecran(Icons.menu_book_outlined, 'Catalogue des produits',
                '${etat.libelleCatalogueCommun} · ${etat.produits.length} produits', const EcranCatalogue()),
            ecran(Icons.sell_outlined, 'Catalogue des marques',
                '${etat.libelleVersion(etat.versionCatalogueMarques)} · ${etat.nbMarquesConnues} marque${etat.nbMarquesConnues > 1 ? 's' : ''}', const EcranMarques()),
            ecran(Icons.local_offer_outlined, 'Types de promotion', '${etat.typesPromotion.length} types', const EcranTypesPromotion()),
            ecran(Icons.scale_outlined, 'Types de mesure', '${etat.typesMesure.length} mesures', const EcranTypesPackaging(lots: false)),
            ecran(Icons.inventory_2_outlined, 'Types de packaging', '${etat.typesLot.length} packagings', const EcranTypesPackaging()),
          ]),
          GroupeRetractable(cle: 'gerer/parametres', titre: 'Paramètres', icone: Icons.settings_outlined, enfants: [
            ecran(Icons.palette_outlined, 'Apparence', 'Palette de couleurs', const EcranApparence()),
            ecran(Icons.storage_outlined, 'Données', 'Sauvegardes, préliste, archives', const EcranDonnees()),
            ecran(Icons.delete_outline, 'Corbeille', '${etat.corbeille.length} élément${etat.corbeille.length > 1 ? 's' : ''}',
                const EcranCorbeille()),
          ]),
        ],
      ),
    );
  }
}

/// Rubrique de Gérer, ouverte au-dessus du menu : en-tête avec retour, sous-onglets éventuels.
class EcranRubrique extends StatelessWidget {
  const EcranRubrique({super.key, required this.rubrique});
  final int rubrique;

  @override
  Widget build(BuildContext context) => switch (rubrique) {
        Nav.parametres => const EcranDonnees(),
        Nav.foyer => const EcranFoyer(),
        Nav.archives => const EcranArchives(),
        Nav.corbeille => const EcranCorbeille(),
        Nav.historique => PageBase(
            entete: const EnTeteFenetre(retour: true, icone: Icons.tune, sousTitre: 'Gérer', titre: 'Historique', aide: Aides.historique),
            corps: const SousEcranHistorique(),
          ),
        _ => const EcranMagasins(),
      };
}

/// La base de l'appareil n'a pas pu s'ouvrir : on le dit, sans rien montrer ni enregistrer d'autre.
/// Une base abîmée peut être mise de côté, puis le foyer rechargé depuis le serveur (« Rejoindre un foyer »).
class _ErreurBase extends StatefulWidget {
  const _ErreurBase(this.erreur);
  final String erreur;

  @override
  State<_ErreurBase> createState() => _ErreurBaseState();
}

class _ErreurBaseState extends State<_ErreurBase> {
  bool _misDeCote = false;
  String? _echec;

  Future<void> _mettreDeCote() async {
    try {
      await Etat.instance.mettreBaseDeCote();
      setState(() => _misDeCote = true);
    } catch (e) {
      setState(() => _echec = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('La base de cet appareil n\'a pas pu s\'ouvrir', style: Charte.texte(20, gras: true)),
            Text('Version $versionApplication', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 12),
            if (_misDeCote)
              Text('La base abîmée est gardée à part sur cet appareil. Fermez puis rouvrez l\'application, choisissez '
                  '« Rejoindre un foyer », saisissez le code de partage (sur votre téléphone : Gérer › Mon foyer › Foyer), '
                  'puis votre nom : le foyer revient depuis le serveur.',
                  style: Charte.texte(16, gras: true))
            else ...[
              Text('Rien n\'a été modifié. Si le texte en rouge dit « malformed », la base est abîmée : mettez-la de côté, '
                  'puis rechargez le foyer depuis le serveur. Sinon, fermez puis rouvrez l\'application.',
                  style: Charte.texte(16)),
              const SizedBox(height: 12),
              Bouton(texte: 'Mettre la base abîmée de côté', icone: Icons.inventory_2_outlined, plein: true, onTap: _mettreDeCote),
            ],
            if (_echec != null) Text(_echec!, style: Charte.texte(14, couleur: const Color(0xFFB00020))),
            const SizedBox(height: 16),
            SelectableText(widget.erreur, style: Charte.texte(13, couleur: const Color(0xFFB00020))),
          ],
        ),
      ),
    );
  }
}

/// Web : l'application est déjà ouverte ailleurs dans ce navigateur ; cette page n'ouvre pas la base.
class _DejaOuverte extends StatelessWidget {
  const _DejaOuverte();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Emplettes est déjà ouverte', style: Charte.texte(20, gras: true)),
            const SizedBox(height: 12),
            Text('Elle est ouverte dans un autre onglet ou une autre fenêtre de ce navigateur (par exemple l\'icône de '
                'l\'écran d\'accueil). Pour protéger vos données, elle ne s\'ouvre qu\'une fois à la fois.\n\n'
                'Fermez cette page et utilisez l\'autre, ou fermez l\'autre puis rouvrez celle-ci.',
                style: Charte.texte(16)),
          ],
        ),
      ),
    );
  }
}
