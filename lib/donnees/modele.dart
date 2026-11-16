import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'affichage.dart';
import 'base_locale.dart';
import 'catalogue_type.dart';
import 'demonstration.dart';
import 'ouverture.dart';
import 'images_perso.dart';
import 'univers.dart';
import 'moderation.dart';
import 'sauvegarde.dart';
import 'images_choisies.dart';
import 'liste_suivie.dart';
import 'stockage.dart';
import 'version.dart';

part 'modele/entites.dart';
part 'modele/etat_chargement.dart';
part 'modele/etat_listes.dart';
part 'modele/etat_courses.dart';
part 'modele/etat_catalogue.dart';
part 'modele/etat_corbeille.dart';
part 'modele/etat_foyer.dart';
part 'modele/etat_catalogue_commun.dart';
part 'modele/etat_marques.dart';

// Modèle de données (« Données maquette.json »), gardé dans la base locale SQLite de l'appareil
// au schéma v2 (stockage.dart). Chaque action est enregistrée immédiatement.

class Etat extends ChangeNotifier {
  Etat._();
  static final Etat instance = Etat._();

  static const String fichierDonnees = 'assets/donnees_maquette.json';
  static const String baseFoyer = 'liste_de_courses.db';
  static const String baseDemo = 'demonstration.db'; // ancienne base de démonstration (avant le 24/10/2026)

  /// Désactive l'enregistrement sur disque (tests).
  bool enregistrementActif = true;

  /// Enseignes présentes dans tout nouveau foyer, chacune avec le catalogue complet.
  static const enseignesDeDepart = ['Carrefour', 'E.Leclerc', 'Auchan', 'Intermarché', 'Super U', 'Lidl'];

  /// Début du nom des listes exemples (une en préparation, une prête, une course en cours).
  static const prefixeExemple = 'Exemple · ';

  late Map<String, dynamic> _brut; // champs conservés tels quels (description, écarts…)
  String foyerId = 'f1';
  String foyerNom = '';
  DateTime foyerCreation = DateTime(2026, 10, 1);
  List<Membre> membres = [];
  String invitationCode = '';
  DateTime invitationExpiration = DateTime(2026, 10, 16);
  int prelistePresencesMin = 3;
  int prelisteSur = 6;

  /// Préparer la liste secteur par secteur (sinon : tout le rayon d'un coup).
  bool parSecteurs = true;

  /// Envoi de la liste par mail : adresses de tous les membres déjà remplies.
  bool envoiFoyer = false;

  /// Préparation (26/10/2026), trois modes : 'condense' (la liste serrée, P devant les promotions),
  /// 'liste' (la liste par rayons et secteurs, avec ses détails) et 'detail' (tout le catalogue à parcourir).
  /// Dans les deux premiers, l'article trouvé est aussitôt ajouté ; dans le dernier, la recherche amène à lui.
  String modePreparation = 'liste';
  bool get ajoutParRecherche => modePreparation != 'detail';
  set ajoutParRecherche(bool oui) => modePreparation = oui ? 'liste' : 'detail';
  List<TypePromotion> typesPromotion = [];
  List<Magasin> magasins = []; // magasins actifs

  /// Magasins supprimés qui avaient un historique : gardés dans Courses › Archives avec leurs courses.
  List<Magasin> magasinsArchives = [];

  /// Couleurs choisies (Paramètres) : « promo:<type> » et « pack:<packaging> » → 0xAARRGGBB.
  Map<String, int> couleurs = {};
  /// Courses pendant lesquelles on enregistre le parcours (identifiants de listes).
  Set<String> apprentissage = {};

  /// Courses terminées passées dans l'historique (glissement à droite dans « Terminées »), avec ou sans ticket.
  /// 03/11/2026 (Aristide) : un ticket ne classe plus la course ; la clé garde son ancien nom « sansTicket ».
  Set<String> sansTicket = {};

  /// Les courses qui avaient déjà un ticket avant le 03/11/2026 ont été mises dans l'historique une fois pour toutes.
  bool terminees2 = false;

  /// Courses passées de l'historique aux archives (à la main, ou d'elles-mêmes après [delaiHistorique] mois).
  Set<String> archivees = {};

  /// Courses remises dans l'historique depuis les archives : elles n'y repartent plus d'elles-mêmes.
  Set<String> gardeesEnHistorique = {};

  /// Délai, en mois, après lequel une course de l'historique passe dans les archives (0 : jamais).
  int delaiHistorique = 3;

  /// Commentaire saisi à la validation d'une liste (identifiant de liste → texte), repris en courses et dans le mail.
  Map<String, String> commentaires = {};

  /// Articles manquants en rayon, signalés pendant les courses (identifiant de liste → produits).
  Map<String, Set<String>> manquants = {};

  /// Listes simples : préparées sans rayons ni secteurs, dans l'ordre où les articles ont été ajoutés.
  /// Elles le restent en préparation, même reprises après « Liste prête ».
  Set<String> simples = {};

  /// Date prévue des courses, par liste (aaaa-mm-jj), choisie à la création.
  Map<String, String> datesPrevues = {};

  /// Libellés donnés aux tickets de caisse (par identifiant de ticket).
  Map<String, String> libellesTickets = {};

  /// Tickets PDF qui ne sont qu'une image (aucun texte) : date et prix inconnus.
  Set<String> ticketsImage = {};

  /// Listes simples à suivre dans l'ordre de saisie pendant les courses (« Ranger par rayons et secteurs »
  /// décoché à « Liste prête ») ; les autres suivent les rayons et secteurs.
  Set<String> nonRangees = {};

  /// Listes types nommées (Préparer › Nouvelle liste › Liste type).
  List<ListeType> listesTypes = [];
  /// Parcours issus de l'apprentissage : de nouvelles courses enregistrées les complètent.
  Set<String> parcoursAppris = {};

  /// Parcours issus d'une fusion : prioritaires au départ des courses (03/11/2026, Aristide).
  Set<String> parcoursFusionnes = {};

  /// Date et heure du dernier apprentissage ou de la fusion de chaque parcours (03/11/2026).
  Map<String, DateTime> datesParcours = {};

  /// 10/11/2026 (Aristide) : ordre des secteurs des derniers passages de chaque parcours (5 au plus),
  /// pour lisser l'ordre appris (voir [lisserParcours]).
  Map<String, List<List<String>>> passagesParcours = {};
  static const maxPassages = 5;

  /// Produits ajoutés (« a ») ou modifiés (« m ») par le foyer, par rapport au catalogue de départ.
  Map<String, String> produitsPerso = {};

  /// Catalogue des marques livré (assets/marques_catalogue.json) : « Rayon/Secteur » → marques.
  Map<String, List<String>> marquesType = {};

  /// Les magasins des enseignes à marques distributeur ont été créés (une fois : un magasin supprimé ne revient pas).
  bool magasinsEnseignes = false;

  /// Marques distributeur livrées (assets/marques_distributeur.json), par enseigne.
  Map<String, List<MarqueDistributeur>> marquesDistributeur = {};

  /// Changements du foyer au catalogue des marques : « Rayon/Secteur » → {'+': ajoutées, '-': retirées}.
  Map<String, Map<String, List<String>>> marquesSecteurs = {};

  /// Membres radiés ('r') ou supprimés ('s') par l'administrateur.
  Map<String, String> statutsMembres = {};

  /// Rayons (« Animalerie ») et secteurs (« Animalerie/Chats ») ajoutés par le foyer.
  Set<String> structurePerso = {};

  /// Univers choisi pour un rayon ajouté par le foyer (nom du rayon → univers), 01/11/2026.
  Map<String, String> universRayons = {};

  /// Rayons et secteurs renommés par le foyer (02/11/2026, Aristide) : nom actuel → nom d'origine
  /// (« r:Nouveau » → rayon d'origine, « s:Rayon d'origine/Nouveau » → secteur d'origine). Le catalogue des marques
  /// et les mises à jour du catalogue commun restent reliés aux noms d'origine.
  Map<String, String> renommages = {};

  /// Univers renommés (nom d'origine → nom affiché).
  Map<String, String> nomsUnivers = {};

  String nomUnivers(String u) => nomsUnivers[u] ?? u;
  String origineRayon(String nom) => renommages['r:$nom'] ?? nom;
  String origineSecteur(String rayonNom, String nom) => renommages['s:${origineRayon(rayonNom)}/$nom'] ?? nom;

  /// Ordre des rayons dans le catalogue (noms), fixé en les faisant glisser ; vide = ordre de départ.
  List<String> ordreRayons = [];

  /// Le foyer ne montre que le catalogue commun et ses propres modifications. 05/11/2026 (Aristide) : les ajouts
  /// des foyers ne circulent plus de l'un à l'autre, ils sont proposés à l'éditeur ; ce qu'un foyer avait déjà
  /// reçu d'un autre est caché (et retiré s'il ne sert à aucune liste). Toujours vrai désormais.
  bool catalogueIsole = true;

  /// Produits du catalogue commun que le foyer a masqués chez lui (05/11/2026) : ni dans le catalogue, ni dans
  /// la recherche ; ils restent dans les listes qui les ont.
  Set<String> masques = {};

  /// Produits du catalogue commun que le foyer a rangés ailleurs : un nouveau catalogue commun ne les remet pas
  /// à leur place d'origine (05/11/2026, « toutes les modifications du foyer sont reprises »).
  Set<String> deplacesFoyer = {};

  /// Identifiant sous lequel le foyer dépose ses ajouts au catalogue (tiré une fois, le même sur ses appareils).
  String? idApports;

  /// Rayons (« Animalerie ») et secteurs (« Animalerie/Chats ») reçus d'autres foyers.
  Set<String> structureRecue = {};

  /// Marques reçues d'autres foyers, par « Rayon/Secteur ».
  Map<String, List<String>> marquesRecues = {};

  /// Ce que l'éditeur a retiré ou renommé dans le catalogue commun (clés de [cleExclue]) : ni déposé, ni
  /// repris des autres foyers.
  Set<String> exclusCommun = {};

  /// Produits reçus que ce foyer a signalés (clés « secteur|nom » de Moderation.cleProduit) : cachés chez
  /// lui, et comptés chez les autres (3 foyers : le produit disparaît partout).
  Set<String> signalements = {};

  /// Foyers (identifiants d'apports) dont l'éditeur a bloqué les ajouts (catalogue commun « bloques »).
  Set<String> foyersBloques = {};

  /// Version du catalogue commun déjà ajoutée au foyer (0 : catalogue livré avec l'application),
  /// et ses nouveautés, montrées une fois sur chaque appareil.
  int versionCatalogueCommun = 0;

  /// Numéro de la version du catalogue commun appliquée (« v7 » de la console), affiché dans Gérer.
  int numeroCatalogueCommun = 0;

  /// Nom de la version du catalogue commun (« 3.1 », 09/11/2026) ; vide pour les versions qui n'en ont pas.
  String nomVersionCatalogueCommun = '';

  /// « Version 3.1 » (ou « Version 3 », « Version d'origine »).
  String get libelleCatalogueCommun =>
      nomVersionCatalogueCommun.isNotEmpty ? 'Version $nomVersionCatalogueCommun' : libelleVersion(numeroCatalogueCommun);
  Map<String, dynamic>? nouveautesCatalogue;

  /// Types de packaging proposés partout (Paramètres) : pack de 6, de 5…
  List<String> typesPackaging = [];

  /// Délai de suppression automatique des archives, en mois (0 : jamais).
  int delaiArchives = 0;

  /// Formats de vente du catalogue déjà appliqués aux produits (une seule fois, à la mise à jour).
  bool formatsAppliques = false;
  bool lotsCompletes = false;

  /// Palette de couleurs choisie (Paramètres › Apparence) ; null : la première.
  String? apparence;

  /// Images des secteurs dans les listes (Apparence, 02/11/2026) ; propre à l'appareil.
  bool iconesListes = true;

  /// Débordement des images de secteur dans les listes : 'normal', 'reduit' ou 'aucun' (07/11/2026) ; propre à l'appareil.
  String debordIcones = 'normal';

  /// Photo de fond des bandeaux (09/11/2026, Aristide) : 'auto' (selon la saison du jour), 'printemps', 'ete',
  /// 'automne' ou 'hiver'.
  String saisonFond = 'auto';

  /// Prévient les bandeaux (souvent construits une fois pour toutes) d'un changement de photo de fond.
  static final fondChange = ValueNotifier<String>('auto');

  /// Saison d'une date : printemps au 20 mars, été au 21 juin, automne au 22 septembre, hiver au 21 décembre.
  static String saisonDu(DateTime d) {
    final j = d.month * 100 + d.day;
    if (j >= 1221 || j < 320) return 'hiver';
    if (j < 621) return 'printemps';
    if (j < 922) return 'ete';
    return 'automne';
  }

  /// L'image de fond des bandeaux, selon le choix d'Apparence (en automatique, change le jour de la saison).
  String get photoFond => 'assets/fonds/${saisonFond == 'auto' ? saisonDu(DateTime.now()) : saisonFond}.jpg';

  void choisirSaisonFond(String s) {
    saisonFond = s;
    fondChange.value = s;
    modifie();
  }
  ListeSuivie<Rayon> _rayons = ListeSuivie([]);
  List<Rayon> get rayons => _rayons;
  set rayons(List<Rayon> l) => _rayons = l is ListeSuivie<Rayon> ? l : ListeSuivie(l);
  ListeSuivie<Secteur> _secteurs = ListeSuivie([]);
  List<Secteur> get secteurs => _secteurs;
  set secteurs(List<Secteur> l) => _secteurs = l is ListeSuivie<Secteur> ? l : ListeSuivie(l);
  List<Marque> marques = [];
  List<Packaging> packagings = [];
  ListeSuivie<Produit> _produits = ListeSuivie([]);
  List<Produit> get produits => _produits;
  set produits(List<Produit> l) => _produits = l is ListeSuivie<Produit> ? l : ListeSuivie(l);
  ListeSuivie<Emplacement> _emplacements = ListeSuivie([]);
  List<Emplacement> get emplacements => _emplacements;
  set emplacements(List<Emplacement> l) => _emplacements = l is ListeSuivie<Emplacement> ? l : ListeSuivie(l);
  List<Parcours> parcours = [];
  List<Liste> listes = [];
  List<Course> historique = [];
  List<Ticket> tickets = [];
  Map<String, Map<String, int>> frequences = {};
  List<ElementCorbeille> corbeille = [];

  /// Listes rectificatives envoyées ou acceptées, par liste qui les porte.
  Map<String, Rectificative> rectificatives = {};
  String regleFrequence = '';

  int _compteur = 0;
  String nouvelId(String prefixe) => '$prefixe-${DateTime.now().millisecondsSinceEpoch}-${++_compteur}';

  // ------------------------------------------------------------ Chargement et enregistrement

  String? _dossier;
  Stockage? _foyer;

  /// Appelé après chaque enregistrement de la base du foyer (synchronisation).
  VoidCallback? surEnregistrement;

  /// Erreur à l'ouverture de la base de l'appareil (null : base ouverte normalement).
  String? erreurBase;

  /// Web : l'application est déjà ouverte dans un autre onglet ou une autre fenêtre ; la base n'est pas ouverte ici.
  bool dejaOuverte = false;

  final Set<String> _dejaNote = {};
  DateTime? _dernierLent;

  /// Compte rendu de la réparation de la base faite au lancement, repris dans le journal du partage.
  String? reparationBase;

  static String _horodatage() => DateTime.now().toIso8601String().substring(0, 16).replaceAll(RegExp('[-:T]'), '');

  /// Repartir d'un foyer neuf : la base actuelle est gardée dans un fichier à part sur l'appareil.
  Future<void> repartirANeuf() async {
    if (_dossier == null) {
      lire(await _donneesDemo());
      return;
    }
    _foyer?.fermer();
    _foyer = null; // pendant le renommage (asynchrone sur le web), rien ne doit lire la base fermée
    final f = _chemin(baseFoyer);
    if (baseExiste(f)) await renommerBase(f, '$f.avant-neuf-${_horodatage()}');
    _foyer = Stockage.ouvrir(_chemin(baseFoyer));
    await _ouvrirActif();
    notifyListeners();
  } // lignes refusées par la base : notées au journal de l'appareil seulement (01/11/2026, Aristide)
  bool disqueBloque = false;
  List<String> refusBase = const [];
  DateTime? derniereEcritureDisque;
  int _ecritures = 0;

  /// Web : attend la recopie sur le disque du navigateur ; au-delà de 15 s, alerte.
  void _verifierDisque() {
    final n = ++_ecritures;
    var fini = false;
    Timer(const Duration(seconds: 15), () {
      if (fini || disqueBloque) return;
      disqueBloque = true;
      debugPrint('Écriture sur le disque en attente depuis 15 s (écriture $n)');
      notifyListeners();
    });
    ecrireSurDisque().then((_) {
      fini = true;
      derniereEcritureDisque = DateTime.now();
      if (disqueBloque) {
        disqueBloque = false;
        notifyListeners();
      }
    }, onError: (Object e) {
      fini = true;
      debugPrint('Écriture sur le disque impossible : $e');
      disqueBloque = true;
      notifyListeners();
    });
  }

  Future<void> enregistrer() async {
    if (!enregistrementActif) return;
    final s = _actif;
    if (s == null) return;
    try {
      final chrono = Stopwatch()..start();
      s.ecrire(versJson());
      final duree = chrono.elapsedMilliseconds;
      final maintenant = DateTime.now();
      if (duree > 500 && (_dernierLent == null || maintenant.difference(_dernierLent!).inMinutes >= 1)) {
        _dernierLent = maintenant;
        noter('Enregistrement lent : ${duree} ms');
      }
      for (final e in s.erreurs) {
        debugPrint('Refusé par la base : $e');
        _noterUneFois('Refusé par la base : $e');
      }
      for (final a in s.avertissements) {
        _noterUneFois('Base corrigée : $a');
      }
      // La base a été corrigée : on la relit, pour que l'application n'y remette pas les liens retirés.
      if (s.avertissements.isNotEmpty) {
        lire(s.lire());
        _retrouverMoi(s);
      }
      if (s.erreurs.isNotEmpty || refusBase.isNotEmpty) {
        final avant = refusBase;
        refusBase = [...s.erreurs];
        if (avant.length != refusBase.length) scheduleMicrotask(notifyListeners);
      }
      if (kIsWeb) _verifierDisque();
      // Le compteur d'utilisation est tenu par la base (règle R4).
      final c = s.compteurs();
      for (final p in produits) {
        p.nbUtilisations = c[p.id] ?? p.nbUtilisations;
      }
      if (identical(s, _foyer)) surEnregistrement?.call();
    } catch (e) {
      debugPrint('Enregistrement impossible : $e');
      _noterUneFois('Enregistrement impossible : $e');
    }
  }

  /// Après avoir rejoint un foyer : dès que les membres du foyer sont reçus, la personne choisit
  /// son nom dans la liste (27/10/2026).
  void _retrouverMoi(Stockage s) {
    final provisoire = s.reglage('synchro_membre_provisoire');
    if (provisoire == null) return;
    if (_trouve(membres, (m) => m.id == provisoire) == null) {
      s.effacerReglage('synchro_membre_provisoire');
      return;
    }
    if (!quiSuisJe && membresVisibles.any((m) => m.id != provisoire)) {
      quiSuisJe = true;
      notifyListeners();
    }
  }

  /// Après avoir rejoint un foyer : la personne choisit qui elle est parmi les membres.
  bool quiSuisJe = false;

  /// Appareil partagé : au lancement, la personne qui l'utilise choisit son nom.
  bool choixPersonne = false;
  /// Appareil partagé par plusieurs membres (réglage de cet appareil seulement).
  bool get appareilPartage => _foyer?.reglage('appareil_partage') == '1';
  set appareilPartage(bool v) {
    if (v) {
      _foyer?.definirReglage('appareil_partage', '1');
    } else {
      _foyer?.effacerReglage('appareil_partage');
    }
    notifyListeners();
  }

  /// Cet appareil est à [m]. Le membre provisoire créé en rejoignant le foyer disparaît ;
  /// ses listes et ses courses (reprises de l'appareil) passent à [m]. Sinon, simple changement de personne.
  void devenir(Membre m) {
    final ancien = moi;
    final provisoire = moiProvisoire;
    _foyer?.effacerReglage('synchro_membre_provisoire');
    quiSuisJe = false;
    choixPersonne = false;
    if (ancien.id == m.id) {
      notifyListeners();
      return;
    }
    membres = [for (final x in membres) Membre(x.id, x.nomAffiche, x.role, x.id == m.id, email: x.email)];
    if (provisoire) {
      for (final l in listes) {
        if (l.membreId == ancien.id) l.membreId = m.id;
      }
      for (final c in historique) {
        if (c.membreId == ancien.id) c.membreId = m.id;
      }
      statutsMembres[ancien.id] = 's';
    }
    modifie();
  }

  /// Après avoir rejoint un foyer : « Je ne suis pas dans la liste » ; le membre de cet appareil prend [nom].
  void resterNouveau([String? nom]) {
    _foyer?.effacerReglage('synchro_membre_provisoire');
    quiSuisJe = false;
    choixPersonne = false;
    if (nom != null && nom.trim().isNotEmpty) {
      renommerMembre(moi, nom);
    } else {
      notifyListeners();
    }
  }

  /// À appeler après chaque action : prévient les écrans et enregistre.
  void modifie() {
    if (_enLot) {
      _modifieEnAttente = true;
      return;
    }
    notifyListeners();
    enregistrer();
  }

  void lire(Map<String, dynamic> j) {
    _brut = j;
    final f = j['foyer'] as Map;
    foyerId = f['id'] as String;
    foyerNom = f['nom'] as String;
    foyerCreation = _date(f['dateCreation']) ?? foyerCreation;
    membres = [
      for (final m in (j['membres'] as List).cast<Map>())
        Membre(m['id'] as String, m['nomAffiche'] as String, m['role'] as String, m['moi'] as bool? ?? false,
            email: m['email'] as String? ?? '')
    ];
    final inv = j['invitation'] as Map;
    invitationCode = inv['code'] as String;
    invitationExpiration = _date(inv['expiration']) ?? invitationExpiration;
    final pl = (j['parametres'] as Map?)?['preliste'] as Map?;
    prelistePresencesMin = (pl?['presencesMin'] as num? ?? 3).toInt();
    prelisteSur = (pl?['sur'] as num? ?? 6).toInt();
    final options = (j['parametres'] as Map?)?['options'] as Map?;
    parSecteurs = options?['parSecteurs'] as bool? ?? true;
    envoiFoyer = options?['envoiFoyer'] as bool? ?? false;
    modePreparation = options?['modePreparation'] as String? ?? ((options?['ajoutParRecherche'] as bool? ?? true) ? 'liste' : 'detail');
    delaiHistorique = (options?['delaiHistorique'] as num? ?? 3).toInt();
    archivees = _ids(options?['archivees']).toSet();
    gardeesEnHistorique = _ids(options?['gardeesEnHistorique']).toSet();
    couleurs = {for (final e in (options?['couleurs'] as Map? ?? {}).entries) e.key as String: (e.value as num).toInt()};
    apprentissage = _ids(options?['apprentissage']).toSet();
    sansTicket = _ids(options?['sansTicket']).toSet();
    terminees2 = options?['terminees2'] == true;
    commentaires = {for (final e in (options?['commentaires'] as Map? ?? {}).entries) e.key as String: e.value as String};
    manquants = {for (final e in (options?['manquants'] as Map? ?? {}).entries) e.key as String: _ids(e.value).toSet()};
    simples = _ids(options?['simples']).toSet();
    datesPrevues = {for (final e in (options?['datesPrevues'] as Map? ?? {}).entries) e.key as String: e.value as String};
    libellesTickets = {for (final e in (options?['libellesTickets'] as Map? ?? {}).entries) e.key as String: e.value as String};
    ticketsImage = _ids(options?['ticketsImage']).toSet();
    nonRangees = _ids(options?['nonRangees']).toSet();
    listesTypes = [for (final t in (options?['listesTypes'] as List? ?? const []).cast<Map>()) ListeType.depuis(t)];
    parcoursAppris = _ids(options?['parcoursAppris']).toSet();
    parcoursFusionnes = _ids(options?['parcoursFusionnes']).toSet();
    datesParcours = {
      for (final e in (options?['datesParcours'] as Map? ?? {}).entries)
        if (_date(e.value) case final d?) e.key as String: d
    };
    passagesParcours = {
      for (final e in (options?['passagesParcours'] as Map? ?? {}).entries)
        e.key as String: [for (final p in (e.value as List? ?? const [])) _ids(p)]
    };
    produitsPerso = {for (final e in (options?['produitsPerso'] as Map? ?? {}).entries) e.key as String: e.value as String};
    marquesSecteurs = {
      for (final e in (options?['marquesSecteurs'] as Map? ?? {}).entries)
        e.key as String: {for (final x in (e.value as Map).entries) x.key as String: _ids(x.value)}
    };
    statutsMembres = {for (final e in (options?['statutsMembres'] as Map? ?? {}).entries) e.key as String: e.value as String};
    structurePerso = {for (final x in (options?['structurePerso'] as List? ?? const [])) x as String};
    universRayons = {for (final e in (options?['universRayons'] as Map? ?? {}).entries) e.key as String: e.value as String};
    renommages = {for (final e in (options?['renommages'] as Map? ?? {}).entries) e.key as String: e.value as String};
    nomsUnivers = {for (final e in (options?['nomsUnivers'] as Map? ?? {}).entries) e.key as String: e.value as String};
    ordreRayons = [for (final x in (options?['ordreRayons'] as List? ?? const [])) x as String];
    masques = _ids(options?['masques']).toSet();
    deplacesFoyer = _ids(options?['deplacesFoyer']).toSet();
    idApports = options?['idApports'] as String?;
    structureRecue = {for (final x in (options?['structureRecue'] as List? ?? const [])) x as String};
    marquesRecues = {for (final e in (options?['marquesRecues'] as Map? ?? {}).entries) e.key as String: _ids(e.value)};
    exclusCommun = _ids(options?['exclusCommun']).toSet();
    signalements = _ids(options?['signalements']).toSet();
    foyersBloques = _ids(options?['foyersBloques']).toSet();
    typesPackaging = _ids(options?['typesPackaging']);
    delaiArchives = (options?['delaiArchives'] as num? ?? 0).toInt();
    apparence = options?['apparence'] as String?;
    iconesListes = options?['iconesListes'] as bool? ?? true;
    debordIcones = options?['debordIcones'] as String? ?? 'normal';
    saisonFond = options?['saisonFond'] as String? ?? 'auto';
    fondChange.value = saisonFond;
    taillePictoListes = tailleDebord(debordIcones);
    formatsAppliques = options?['formats'] == 1;
    lotsCompletes = options?['lots'] == 1;
    magasinsEnseignes = options?['magasinsEnseignes'] == 1;
    versionCatalogueCommun = (options?['catalogueCommun'] as num? ?? 0).toInt();
    numeroCatalogueCommun = (options?['catalogueCommunNumero'] as num? ?? 0).toInt();
    nomVersionCatalogueCommun = options?['catalogueCommunLibelle'] as String? ?? '';
    nouveautesCatalogue = (options?['nouveautesCatalogue'] as Map?)?.cast<String, dynamic>();
    imagesChoisies
      ..clear()
      ..addAll(Map<String, String>.from(options?['images'] as Map? ?? {}));
    // Images ajoutées à la bibliothèque par l'éditeur, reçues avec le catalogue commun.
    try {
      final ip = _actif?.reglage('images_perso');
      remplacerImagesPerso(ip == null || ip.isEmpty ? {} : lireImagesPerso(jsonDecode(ip)));
    } catch (e) {
      noter('Images du catalogue commun illisibles : $e');
    }
    // Univers (domaines) reçus avec le catalogue commun (08/11/2026) ; sinon ceux d'origine.
    try {
      final u = _actif?.reglage('univers_catalogue');
      remplacerUnivers(u == null || u.isEmpty ? null : lireUnivers(jsonDecode(u)));
    } catch (e) {
      noter('Univers du catalogue commun illisibles, ceux d\'origine sont pris : $e');
      remplacerUnivers(null);
    }
    typesPromotion = [
      for (final t in (j['typesPromotion'] as List).cast<Map>())
        TypePromotion(t['id'] as String, t['code'] as String, t['nom'] as String, t['exemple'] as String? ?? '',
            _ids(t['parametres']))
    ];
    // 03/11/2026 (Aristide) : le prix promotionnel, code PX, saisi directement sur la ligne.
    if (!typesPromotion.any((t) => t.id == 'prix')) {
      typesPromotion.insert(0, TypePromotion('prix', 'PX', 'Prix promo', '2,50 € au lieu de 3,20 €', ['prix']));
    }
    magasins = [];
    magasinsArchives = [];
    for (final m in (j['magasins'] as List).cast<Map>()) {
      final mg = Magasin(m['id'] as String, m['nom'] as String, m['enseigne'] as String? ?? '', m['ville'] as String? ?? '');
      final archive = m['archive'] == true || _ids(options?['magasinsArchives']).contains(mg.id);
      (archive ? magasinsArchives : magasins).add(mg);
    }
    // Un magasin restauré depuis la corbeille n'est plus archivé.
    magasinsArchives.removeWhere((a) => magasins.any((m) => m.id == a.id));
    rayons = [
      for (final r in (j['rayons'] as List).cast<Map>()) Rayon(r['id'] as String, r['magasinId'] as String, r['nom'] as String)
    ];
    secteurs = [
      for (final s in (j['secteurs'] as List).cast<Map>()) Secteur(s['id'] as String, s['rayonId'] as String, s['nom'] as String)
    ];
    marques = [for (final m in (j['marques'] as List).cast<Map>()) Marque(m['id'] as String, m['nom'] as String)];
    packagings = [for (final k in (j['packagings'] as List).cast<Map>()) Packaging(k['id'] as String, k['libelle'] as String)];
    if (options?['typesPackaging'] == null) {
      // Types de packaging de départ : pack de 6, 5, 4, 3, 2.
      typesPackaging = [for (final n in [6, 5, 4, 3, 2]) _packagingNomme('Pack de $n').id];
    }
    typesPackaging.removeWhere((id) => packaging(id) == null);
    produits = [
      for (final p in (j['produits'] as List).cast<Map>())
        Produit(p['id'] as String, p['nom'] as String, _ids(p['marqueIds']), _ids(p['packagingIds']),
            (p['nbUtilisations'] as num? ?? 0).toInt())
    ];
    emplacements = [
      for (final e in (j['emplacements'] as List).cast<Map>())
        Emplacement(e['magasinId'] as String, e['produitId'] as String, e['secteurId'] as String)
    ];
    parcours = [
      for (final p in (j['parcours'] as List).cast<Map>())
        Parcours(p['id'] as String, p['magasinId'] as String, p['membreId'] as String, p['nom'] as String,
            p['parDefaut'] as bool? ?? false, _ids(p['etapes']))
    ];
    listes = [for (final l in (j['listes'] as List)) Liste.depuis(Map<String, dynamic>.from(l as Map))];
    historique = [
      for (final h in (j['historique'] as List).cast<Map>())
        Course(h['id'] as String, h['magasinId'] as String, _date(h['dateCourses']) ?? DateTime.now(),
            h['membreId'] as String, (h['nbArticles'] as num? ?? 0).toInt(), nom: h['nom'] as String?)
    ]..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));
    tickets = [
      for (final t in (j['tickets'] as List? ?? []).cast<Map>())
        Ticket(t['id'] as String, t['listeId'] as String?, t['magasinId'] as String, _date(t['date']) ?? DateTime.now(),
            (t['montant'] as num? ?? 0).toDouble(), t['source'] as String? ?? 'photo')
    ]..sort((a, b) => b.date.compareTo(a.date));
    corbeille = [
      for (final c in (j['corbeille'] as List? ?? []).cast<Map>())
        ElementCorbeille(c['id'] as String, c['type'] as String, c['libelle'] as String, _date(c['le']) ?? DateTime.now(),
            Map<String, dynamic>.from(c['contenu'] as Map))
    ];
    rectificatives = {
      for (final r in (j['rectificatives'] as List? ?? []).cast<Map>()) r['listeId'] as String: Rectificative.depuis(r)
    };
    frequences = {};
    (j['frequencesPreliste'] as Map? ?? {}).forEach((cle, valeur) {
      if (cle == '_regle') {
        regleFrequence = valeur as String;
      } else {
        frequences[cle as String] = (valeur as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      }
    });
    // 03/11/2026 : avant, une course avec ticket était d'office dans l'historique ; elle y reste.
    if (!terminees2) {
      terminees2 = true;
      sansTicket.addAll([for (final c in historique) if (ticketDe(c.id) != null) c.id]);
    }
    // 12/11/2026 : données à l'ancienne (une structure par magasin) ramenées tout de suite à la structure
    // commune ; [unifierStructure] l'enregistre ensuite.
    if (_unifier()) _structureAConvertir = true;
    notifyListeners();
  }

  // ------------------------------------------------------------ Recherche

  static T? _trouve<T>(Iterable<T> l, bool Function(T) test) {
    for (final e in l) {
      if (test(e)) return e;
    }
    return null;
  }
  final _indexRayons = Index<Rayon>((r) => r.id);
  final _indexSecteurs = Index<Secteur>((s) => s.id);
  final _indexProduits = Index<Produit>((p) => p.id);

  final _indexEmplacements = Index<Emplacement>((e) => e.produitId);

  // ------------------------------------------------------------ Mesure et lot d'un packaging

  /// Un lot (« lot de 6 », « pack de 4 ») ; le reste est une mesure (« 500 g », « 1,5 l », « à la pièce »).
  static bool estLot(String libelle) => RegExp(r'^(lot|pack|paquet|boîte) ', caseSensitive: false).hasMatch(libelle.trim());

  /// « lot de 6 × 1,5 l » → (mesure « 1,5 l », lot « lot de 6 »).
  static (String?, String?) mesureEtLot(String? libelle) {
    if (libelle == null || libelle.trim().isEmpty) return (null, null);
    final parts = libelle.split(' × ');
    if (parts.length == 2) return (parts[1].trim(), parts[0].trim());
    return estLot(libelle) ? (null, libelle.trim()) : (libelle.trim(), null);
  }

  // ------------------------------------------------------------ Notifications (décision du 28/10/2026)

  /// Envoi d'une notification aux membres [a] (tout le foyer si null) ; branché sur ntfy au démarrage,
  /// absent dans les essais. Celui qui agit n'est jamais prévenu.
  void Function(String texte, Iterable<String>? a)? avertir;

  /// 10/11/2026 (Aristide) : lissage de l'ordre appris sur les derniers passages. Un secteur passe devant
  /// celui qui le précède si, dans au moins 2 passages et dans la majorité de ceux où les deux ont été visités,
  /// il a été visité avant lui. Un écart isolé (un oubli rattrapé, un retour en arrière) ne déplace donc rien ;
  /// une erreur du premier passage se corrige au bout de 3 ou 4 passages.
  static List<String> lisserParcours(List<String> etapes, List<List<String>> passages) {
    if (passages.length < 2) return etapes;
    int avant(String a, String b) {
      var n = 0;
      for (final p in passages) {
        final i = p.indexOf(a), j = p.indexOf(b);
        if (i >= 0 && j >= 0 && i < j) n++;
      }
      return n;
    }
    final res = <String>[];
    for (final s in etapes) {
      var pos = res.length;
      while (pos > 0) {
        final g = res[pos - 1];
        final pour = avant(s, g), contre = avant(g, s);
        if (pour >= 2 && pour > contre) {
          pos--;
        } else {
          break;
        }
      }
      res.insert(pos, s);
    }
    return res;
  }

  /// Insère dans [etapes] les secteurs de [suite] qui n'y sont pas, à leur place relative.
  static List<String> insererSecteurs(List<String> etapes, List<String> suite) {
    final res = [...etapes];
    for (var i = 0; i < suite.length; i++) {
      final s = suite[i];
      if (res.contains(s)) continue;
      var pos = -1;
      for (var j = i - 1; j >= 0 && pos < 0; j--) {
        final k = res.indexOf(suite[j]);
        if (k >= 0) pos = k + 1;
      }
      for (var j = i + 1; j < suite.length && pos < 0; j++) {
        final k = res.indexOf(suite[j]);
        if (k >= 0) pos = k;
      }
      res.insert(pos < 0 ? res.length : pos, s);
    }
    return res;
  }

  static const String fichierCatalogueType = 'assets/catalogue_type.json';

  /// Un nouveau magasin reçoit toujours le catalogue complet, quelle que soit sa taille (décision du 19/10/2026).
  static const int tailleComplete = 3;

  // ------------------------------------------------------------ Catalogue unique (25/10/2026)
  //
  // Un seul catalogue pour le foyer : les mêmes rayons, secteurs et produits dans tous les magasins,
  // chaque produit dans le même secteur partout. Depuis le 12/11/2026, la base n'en garde qu'un exemplaire
  // (magasin fictif [magasinCommun]) ; seul le parcours est propre à un magasin.

  /// Identifiants tirés des noms : les mêmes sur tous les appareils.
  static String _cleStructure(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüœ]+'), '-');

  /// Pendant un lot (catalogue commun reçu), [modifie] n'enregistre qu'une fois, à la fin.
  bool _enLot = false, _modifieEnAttente = false;

  bool _structureAConvertir = false;

  // ------------------------------------------------------------ Catalogue commun (26/10/2026)
  //
  // Tenu par l'éditeur (une seule personne), publié sur le serveur, ajouté à chaque foyer à la connexion.
  // Mêmes règles partout : identifiants calculés depuis les noms (deux appareils du foyer qui
  // l'ajoutent en même temps créent les mêmes objets) ; rien de ce que le foyer utilise n'est retiré.

  static String _cleNom(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüœ]+'), '-');

  /// Clé d'un rayon (« r:rayon »), d'un secteur (« s:rayon/secteur ») ou d'un produit (« p:secteur|nom »),
  /// en minuscules.
  static String cleExclue(String type, String nom, {String? rayon, String? secteur}) => switch (type) {
        'rayon' => 'r:${nom.trim().toLowerCase()}',
        'secteur' => 's:${(rayon ?? '').trim().toLowerCase()}/${nom.trim().toLowerCase()}',
        _ => 'p:${(secteur ?? '').trim().toLowerCase()}|${nom.trim().toLowerCase()}',
      };

  /// Ce que le catalogue commun [j] retire ou renomme (les anciens noms).
  static Set<String> exclusDu(Map<String, dynamic> j) => {
        for (final o in (j['retires'] as List? ?? const []).cast<Map>())
          cleExclue(o['type'] as String, o['nom'] as String, rayon: o['rayon'] as String?, secteur: o['secteur'] as String?),
        // Un changement de casse seul (09/11/2026) n'exclut pas le nom : c'est le même, mieux écrit.
        for (final o in (j['renommes'] as List? ?? const []).cast<Map>())
          if ('${o['ancien']}'.trim().toLowerCase() != '${o['nouveau']}'.trim().toLowerCase())
            cleExclue(o['type'] as String, o['ancien'] as String, rayon: o['rayon'] as String?, secteur: o['secteur'] as String?),
      };

  /// Retiré ou renommé par l'éditeur (un produit retiré sans secteur l'est dans tous les secteurs).
  static bool estExclu(Set<String> exclus, {required String rayon, String? secteur, String? produit}) {
    if (exclus.isEmpty) return false;
    if (exclus.contains(cleExclue('rayon', rayon))) return true;
    if (secteur == null) return false;
    if (exclus.contains(cleExclue('secteur', secteur, rayon: rayon))) return true;
    if (produit == null) return false;
    return exclus.contains(cleExclue('produit', produit, secteur: secteur)) || exclus.contains(cleExclue('produit', produit));
  }

  /// 12/11/2026 (Aristide) : rayons et secteurs dans l'ordre du catalogue commun (celui de l'éditeur), pas dans
  /// celui de la base de l'appareil. Rang retenu à l'ouverture (reparation.dart, retenirCatalogue) ; les rayons et
  /// secteurs ajoutés par les foyers viennent après, dans leur ordre.
  Map<String, int> rangCatalogue = {};

  /// Foyers dont les dépôts ont été écartés à la dernière réception (bloqués, trop gros, trop signalés).
  Set<String> foyersEcartes = {};

  // ------------------------------------------------------------ Catalogue des marques (28/10/2026)

  static const fichierMarques = 'assets/marques_catalogue.json';

  static const fichierMarquesDistributeur = 'assets/marques_distributeur.json';

  /// Popularité et marques de chaque nature d'après Open Food Facts (outils/off/natures.py, 31/10/2026).
  static const fichierNaturesOff = 'assets/natures_off.json';

  /// Par nature (nom en minuscules) : nombre de produits vendus en France selon Open Food Facts, et les marques
  /// les plus présentes. Sert à classer les recherches et à proposer des marques ; ne crée aucun produit.
  Map<String, ({int n, List<String> marques})> naturesOff = {};

  /// Marque (minuscules) → natures qui la portent : « nut » trouve « Pâte à tartiner chocolat · Nutella ».
  Map<String, List<String>> naturesParMarque = {};

  /// Mots qui reconnaissent une enseigne dans l'enseigne ou le nom d'un magasin.
  static const _motsEnseignes = {
    'Intermarché': ['intermarch'],
    'Carrefour': ['carrefour'],
    'Leclerc': ['leclerc'],
    'Système U': ['système u', 'systeme u', 'super u', 'hyper u', 'u express', 'marché u', 'magasins u'],
    'Auchan': ['auchan'],
    'Casino': ['casino', 'géant'],
    'Monoprix': ['monoprix', 'monop\''],
  };

  /// Version du catalogue des marques : celui livré avec l'application tant que la console ne publie pas
  /// de catalogue des marques (06/11/2026 : numéro prévu, affiché dans Gérer).
  int versionCatalogueMarques = 0;

  /// Couleurs des pastilles (Gérer › Paramètres › Apparence) : une pour les promotions, une pour les mesures,
  /// une pour les packagings (lots). Par défaut (02/11/2026, Aristide) : promotion en rouge, mesure en bleu,
  /// packaging en vert.
  static const couleurPromoDefaut = 0xFFE53935;
  static const couleurMesureDefaut = 0xFF1E88E5;
  static const couleurLotDefaut = 0xFF43A047;

  static double tailleDebord(String d) => switch (d) { 'reduit' => 32, 'aucun' => 26, _ => 40 };
}

extension _Let<T> on T {
  void let(void Function(T) f) => f(this);
}
