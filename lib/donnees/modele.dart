import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'base_locale.dart';
import 'catalogue_type.dart';
import 'images_choisies.dart';
import 'stockage.dart';

// Modèle de données (« Données maquette.json »), gardé dans la base locale SQLite de l'appareil
// au schéma v2 (stockage.dart). Chaque action est enregistrée immédiatement.

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
String? _iso(DateTime? d) => d?.toIso8601String().substring(0, 19);
List<String> _ids(dynamic v) => v == null ? <String>[] : List<String>.from(v as List);
String? _texte(dynamic v) => v as String?;

String deux(int n) => n.toString().padLeft(2, '0');
String jjmmaaaa(DateTime d) => '${deux(d.day)}/${deux(d.month)}/${d.year}';
String jjmm(DateTime d) => '${deux(d.day)}/${deux(d.month)}';
const joursSemaine = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
String jourEtDate(DateTime d) => '${joursSemaine[d.weekday - 1]} ${jjmmaaaa(d)}';
String heure(DateTime d) => '${d.hour} h ${deux(d.minute)}';
String euros(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
String moisAnnee(DateTime d) => '${_mois[d.month - 1]} ${d.year}';

/// « aujourd'hui, 18 h 20 », « hier, 18 h 20 » ou « le 06/10, 18 h 20 ».
String quand(DateTime d) {
  final maintenant = DateTime.now();
  final jour = DateTime(d.year, d.month, d.day);
  final auj = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final ecart = auj.difference(jour).inDays;
  if (ecart == 0) return "aujourd'hui, ${heure(d)}";
  if (ecart == 1) return 'hier, ${heure(d)}';
  return 'le ${jjmm(d)}, ${heure(d)}';
}

/// « aujourd'hui », « hier » ou « le 06/10 ».
String quandJour(DateTime d) {
  final maintenant = DateTime.now();
  final ecart = DateTime(maintenant.year, maintenant.month, maintenant.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (ecart == 0) return "aujourd'hui";
  if (ecart == 1) return 'hier';
  return 'le ${jjmm(d)}';
}

// ---------------------------------------------------------------------------
// Entités
// ---------------------------------------------------------------------------

class Membre {
  Membre(this.id, this.nomAffiche, this.role, this.moi, {this.email = ''});
  final String id;
  String nomAffiche;
  String role;
  final bool moi;
  String email; // pour l'envoi de la liste par mail
  String get roleAffiche => role == 'administrateur' ? 'Administrateur' : 'Membre';
  String get initiales {
    final m = nomAffiche.split(' ');
    return m.length >= 2 ? '${m.first[0]}${m.last[0]}'.toUpperCase() : nomAffiche.substring(0, 1).toUpperCase();
  }
}

class TypePromotion {
  TypePromotion(this.id, this.code, this.nom, this.exemple, this.parametres);
  final String id;
  String code;
  String nom;
  final String exemple;
  final List<String> parametres;

  static const _noms = {
    'quantiteAchetee': 'achetés',
    'quantiteOfferte|remiseDernier': 'offerts ou remise',
    'quantiteMinimale': 'quantité minimale',
    'prixGlobal': 'prix',
    'pourcentage|montant': 'pourcentage ou montant',
    'packagingId': 'packaging',
    'gain': 'gain',
    'libelle': 'libellé libre',
  };
  String get parametresAffiches => parametres.map((p) => _noms[p] ?? p).join(', ');
  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'nom': nom, 'exemple': exemple, 'parametres': parametres};
}

class Magasin {
  Magasin(this.id, this.nom, this.enseigne, this.ville);
  final String id;
  String nom;
  String enseigne;
  final String ville;
}

/// Marque distributeur (MDD) d'une enseigne : proposée pour les articles des rayons ou secteurs [cibles]
/// (« Crèmerie », « Cave/Vins ») ; « * » : tous.
class MarqueDistributeur {
  MarqueDistributeur(this.marque, this.categorie, this.cibles);
  final String marque;
  final String categorie;
  final List<String> cibles;
}

class Rayon {
  Rayon(this.id, this.magasinId, this.nom);
  final String id;
  final String magasinId;
  String nom;
}

class Secteur {
  Secteur(this.id, this.rayonId, this.nom);
  final String id;
  final String rayonId;
  String nom;
}

class Marque {
  Marque(this.id, this.nom);
  final String id;
  String nom;
}

class Packaging {
  Packaging(this.id, this.libelle);
  final String id;
  String libelle;
}

class Produit {
  Produit(this.id, this.nom, this.marqueIds, this.packagingIds, this.nbUtilisations);
  final String id;
  String nom;
  final List<String> marqueIds;
  final List<String> packagingIds;
  int nbUtilisations;
}

class Emplacement {
  Emplacement(this.magasinId, this.produitId, this.secteurId);
  final String magasinId;
  final String produitId;
  String secteurId;
}

class Parcours {
  Parcours(this.id, this.magasinId, this.membreId, this.nom, this.parDefaut, this.etapes);
  final String id;
  final String magasinId;
  final String membreId;
  String nom;
  bool parDefaut;
  List<String> etapes;
}

/// Promotion visée, portée par la ligne de liste (écart avec le modèle de données).
class PromotionLigne {
  PromotionLigne(this.type, this.parametres, this.libelle);
  final String type;
  final Map<String, dynamic> parametres;
  final String libelle;

  /// Quantité nécessaire pour bénéficier de la promotion (règle 11), ou null.
  int? get quantiteRequise {
    num? v;
    if (type == 'lot') v = parametres['quantiteAchetee'] as num?;
    if (type == 'prixGlobal') v = parametres['quantiteMinimale'] as num?;
    return v?.toInt();
  }

  Map<String, dynamic> toJson() => {'type': type, 'parametres': parametres, 'libelle': libelle};
  static PromotionLigne? depuis(dynamic j) {
    if (j is! Map) return null;
    return PromotionLigne(j['type'] as String, Map<String, dynamic>.from(j['parametres'] as Map? ?? {}),
        j['libelle'] as String? ?? '');
  }
}

class LigneListe {
  LigneListe(
      {required this.produitId, this.marqueId, this.packagingId, this.quantite = 1, this.promotion, this.cochePar, this.cocheLe, this.consigne});
  final String produitId;
  String? marqueId;
  String? packagingId;
  int quantite;
  PromotionLigne? promotion;
  String? cochePar;
  DateTime? cocheLe;

  /// Consigne libre pour celui qui fait les courses (« bien mûres », « la moins chère »…).
  String? consigne;
  bool get coche => cocheLe != null;

  Map<String, dynamic> toJson() => {
        'produitId': produitId,
        if (marqueId != null) 'marqueId': marqueId,
        if (packagingId != null) 'packagingId': packagingId,
        'quantite': quantite,
        if (promotion != null) 'promotion': promotion!.toJson(),
        if (cocheLe != null) 'coche': {'par': cochePar, 'le': _iso(cocheLe)},
        if (consigne != null && consigne!.isNotEmpty) 'consigne': consigne,
      };

  static LigneListe depuis(Map<String, dynamic> g) {
    final c = g['coche'] as Map?;
    return LigneListe(
      produitId: g['produitId'] as String,
      marqueId: _texte(g['marqueId']),
      packagingId: _texte(g['packagingId']),
      quantite: (g['quantite'] as num? ?? 1).toInt(),
      promotion: PromotionLigne.depuis(g['promotion']),
      cochePar: c?['par'] as String?,
      cocheLe: _date(c?['le']),
      consigne: _texte(g['consigne']),
    );
  }
}

enum StatutListe { enConstruction, prete, enCours, terminee }

/// Liste type : une liste nommée, enregistrée à la fin d'une préparation, pour repartir de ses articles.
class ListeType {
  ListeType(this.id, this.nom, this.magasinId, this.lignes);
  final String id;
  String nom;
  final String magasinId;
  final List<LigneListe> lignes;

  Map<String, dynamic> toJson() => {'id': id, 'nom': nom, 'magasinId': magasinId, 'lignes': [for (final g in lignes) g.toJson()]};
  static ListeType depuis(Map j) => ListeType(j['id'] as String, j['nom'] as String, j['magasinId'] as String? ?? '',
      [for (final g in (j['lignes'] as List? ?? const []).cast<Map>()) LigneListe.depuis(Map<String, dynamic>.from(g))]);
}

class Liste {
  Liste({
    required this.id,
    required this.magasinId,
    required this.statut,
    required this.dateCreation,
    required this.lignes,
    this.parcoursId,
    this.membreId,
    this.interrompueLe,
    this.modifieePar,
    this.modifieeLe,
    this.repriseRayonId,
    this.repriseSecteurId,
    this.nom,
  });
  final String id;

  /// Nom donné par l'utilisateur ; null = nom par défaut (magasin et date, voir Etat.nomListe).
  String? nom;
  final String magasinId;
  StatutListe statut;
  final DateTime dateCreation;
  final List<LigneListe> lignes;
  String? parcoursId;
  String? membreId;
  DateTime? interrompueLe;
  String? modifieePar;
  DateTime? modifieeLe;
  String? repriseRayonId;

  /// Secteur de reprise ; « nonPlace » pour l'étape « Non placé » des courses.
  String? repriseSecteurId;

  int get nbCoches => lignes.where((g) => g.coche).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'magasinId': magasinId,
        'statut': statut.name,
        if (nom != null && nom!.isNotEmpty) 'nom': nom,
        'dateCreation': _iso(dateCreation),
        'lignes': [for (final g in lignes) g.toJson()],
        'parcoursId': parcoursId,
        if (membreId != null) 'membreId': membreId,
        if (interrompueLe != null) 'interrompueLe': _iso(interrompueLe),
        if (modifieePar != null) 'modifieePar': modifieePar,
        if (modifieeLe != null) 'modifieeLe': _iso(modifieeLe),
        if (repriseRayonId != null || repriseSecteurId != null)
          'reprise': {
            if (repriseRayonId != null) 'rayonId': repriseRayonId,
            if (repriseSecteurId != null) 'secteurId': repriseSecteurId
          },
      };

  static Liste depuis(Map<String, dynamic> l) {
    final r = l['reprise'] as Map?;
    return Liste(
      id: l['id'] as String,
      magasinId: l['magasinId'] as String,
      statut: StatutListe.values.firstWhere((s) => s.name == l['statut'], orElse: () => StatutListe.enConstruction),
      dateCreation: _date(l['dateCreation']) ?? DateTime.now(),
      lignes: [for (final g in (l['lignes'] as List? ?? [])) LigneListe.depuis(Map<String, dynamic>.from(g as Map))],
      parcoursId: _texte(l['parcoursId']),
      membreId: _texte(l['membreId']),
      interrompueLe: _date(l['interrompueLe']),
      modifieePar: _texte(l['modifieePar']),
      modifieeLe: _date(l['modifieeLe']),
      repriseRayonId: r?['rayonId'] as String?,
      repriseSecteurId: r?['secteurId'] as String?,
      nom: _texte(l['nom']),
    );
  }
}

class Course {
  Course(this.id, this.magasinId, this.dateCourses, this.membreId, this.nbArticles, {this.nom});
  final String id;

  /// Nom donné à la liste (null = nom par défaut, voir Etat.nomCourse).
  final String? nom;
  final String magasinId;
  final DateTime dateCourses;
  String membreId;
  final int nbArticles;
}

class Ticket {
  Ticket(this.id, this.listeId, this.magasinId, this.date, this.montant, this.source);
  final String id;
  String? listeId; // course de l'historique, null = non rattaché
  final String magasinId;
  DateTime date;
  double montant;
  final String source;
}

/// Élément de la corbeille : ce qui a été supprimé ensemble, pour pouvoir le remettre.
class ElementCorbeille {
  ElementCorbeille(this.id, this.type, this.libelle, this.le, this.contenu);
  final String id;
  final String type; // magasin, rayon, secteur, produit, liste, parcours
  final String libelle;
  final DateTime le;
  final Map<String, dynamic> contenu; // collection du JSON → objets retirés

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'libelle': libelle, 'le': _iso(le), 'contenu': contenu};
}

/// Liste rectificative (28/10/2026) : une liste simple préparée pour compléter une liste « À faire » ou en
/// cours de courses (une seule par liste). Liste « À faire » : ses articles y sont ajoutés aussitôt. Courses en
/// cours : celui qui les fait l'accepte ou la refuse en entier ; acceptée, ses articles rejoignent la course,
/// fondus dans leur secteur ([fusion]) ou gardés à part en tête. Refusée, ou sans réponse à la fin des courses,
/// elle passe en « À faire », marquée « rectificative » jusqu'au départ de ses propres courses.
class Rectificative {
  Rectificative(this.listeId, this.cibleId, this.auteurId, this.le, {this.mode, List<String>? produits}) : produits = produits ?? [];
  /// Liste qui porte les articles (retirée une fois acceptée).
  final String listeId;
  /// Course en cours visée.
  final String cibleId;
  final String auteurId;
  final DateTime le;

  /// 'redaction' : en préparation ; null : en attente de décision ; 'fusion' ou 'apart' : acceptée ;
  /// 'signalee' : devenue une liste « À faire » marquée rectificative.
  String? mode;

  /// Articles ajoutés à la course à l'acceptation.
  final List<String> produits;

  bool get enAttente => mode == null;
  bool get enRedaction => mode == 'redaction';
  bool get signalee => mode == 'signalee';
  bool get acceptee => mode == 'fusion' || mode == 'apart';
  bool get fusion => mode == 'fusion';

  Map<String, dynamic> toJson() => {
        'listeId': listeId,
        'cibleId': cibleId,
        'auteurId': auteurId,
        'le': _iso(le),
        if (mode != null) 'mode': mode,
        if (produits.isNotEmpty) 'produits': produits,
      };

  static Rectificative depuis(Map r) => Rectificative(r['listeId'] as String, r['cibleId'] as String, r['auteurId'] as String,
      _date(r['le']) ?? DateTime.now(),
      mode: r['mode'] as String?, produits: [for (final x in (r['produits'] as List? ?? const [])) x as String]);
}

/// Étape des courses : un secteur (ou « Non placé » si [secteur] est nul) et ses lignes.
class Etape {
  Etape(this.secteur, this.lignes);
  final Secteur? secteur;
  final List<LigneListe> lignes;
  bool get nonPlace => secteur == null;
  String get id => secteur?.id ?? 'nonPlace';
  String get nom => secteur?.nom ?? 'Non placé';
}

// ---------------------------------------------------------------------------
// État de la maquette
// ---------------------------------------------------------------------------

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

  /// Courses terminées classées dans l'historique sans ticket de caisse.
  Set<String> sansTicket = {};

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

  /// Produits ajoutés (« a ») ou modifiés (« m ») par le foyer, par rapport au catalogue de départ.
  Map<String, String> produitsPerso = {};

  /// Catalogue des marques livré (assets/marques_catalogue.json) : « Rayon/Secteur » → marques.
  Map<String, List<String>> marquesType = {};

  /// Marques distributeur livrées (assets/marques_distributeur.json), par enseigne.
  Map<String, List<MarqueDistributeur>> marquesDistributeur = {};

  /// Changements du foyer au catalogue des marques : « Rayon/Secteur » → {'+': ajoutées, '-': retirées}.
  Map<String, Map<String, List<String>>> marquesSecteurs = {};

  /// Membres radiés ('r') ou supprimés ('s') par l'administrateur.
  Map<String, String> statutsMembres = {};

  /// Rayons (« Animalerie ») et secteurs (« Animalerie/Chats ») ajoutés par le foyer.
  Set<String> structurePerso = {};

  /// Version du catalogue commun déjà ajoutée au foyer (0 : catalogue livré avec l'application),
  /// et ses nouveautés, montrées une fois sur chaque appareil.
  int versionCatalogueCommun = 0;
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
  List<Rayon> rayons = [];
  List<Secteur> secteurs = [];
  List<Marque> marques = [];
  List<Packaging> packagings = [];
  List<Produit> produits = [];
  List<Emplacement> emplacements = [];
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
  Stockage? get _actif => _foyer;

  /// Base des vraies données du foyer (la seule qui se synchronise).
  Stockage? get stockageFoyer => _foyer;

  /// Appelé après chaque enregistrement de la base du foyer (synchronisation).
  VoidCallback? surEnregistrement;

  String _chemin(String nom) => cheminBase(_dossier!, nom);

  Future<Map<String, dynamic>> _donneesDemo() async =>
      jsonDecode(await rootBundle.loadString(fichierDonnees)) as Map<String, dynamic>;

  /// Base du foyer (vraies données) et, en mode démonstration, base de démonstration.
  /// [dossier] : dossier des bases (essais) ; par défaut, celui de l'application.
  Future<void> charger({Directory? dossier}) async {
    if (enregistrementActif) {
      try {
        _dossier = await preparerDossierBases(dossier?.path);
        _foyer = Stockage.ouvrir(_chemin(baseFoyer));
        await _reprendreDemonstration();
        await _ouvrirActif();
        return;
      } catch (e) {
        debugPrint('Base locale indisponible : $e');
        _foyer = null;
      }
    }
    lire(await _donneesDemo());
  }

  static String _horodatage() => DateTime.now().toIso8601String().substring(0, 16).replaceAll(RegExp('[-:T]'), '');

  /// Il n'y a plus de mode démonstration (24/10/2026). Un appareil qui l'affichait garde ce qu'il
  /// montrait : la base de démonstration devient celle du foyer, l'autre est gardée dans un fichier à part.
  Future<void> _reprendreDemonstration() async {
    final f = _foyer!;
    if (f.reglage('mode_demo') != '1') return;
    final demo = _chemin(baseDemo);
    f.definirReglage('mode_demo', '0');
    if (!baseExiste(demo)) return;
    f.fermer();
    await renommerBase(_chemin(baseFoyer), '${_chemin(baseFoyer)}.avant-fusion-${_horodatage()}');
    await renommerBase(demo, _chemin(baseFoyer));
    _foyer = Stockage.ouvrir(_chemin(baseFoyer));
  }

  Future<void> _ouvrirActif() async {
    final s = _actif!;
    if (s.vide) {
      lire(_depart(await _donneesDemo()));
      final catalogue = await CatalogueType.lireJson();
      for (final m in magasins) {
        await appliquerModele(m, tailleComplete, catalogue: catalogue);
      }
      creerExemples(enregistrer: false);
      s.ecrire(versJson());
    } else {
      lire(s.lire());
    }
    // Types de mesure vides (types reçus avant leurs libellés, ou foyer rejoint) : on les reprend du catalogue.
    await reparerTypesMesure();
    await appliquerFormats();
    completerLots();
    harmoniserCatalogue();
    // Historique de plus de trois mois (réglable) vers les archives, et archives trop anciennes supprimées.
    if (archiverAnciennes() | purgerArchives()) enregistrer();
    // Appareil partagé (tablette, PC de la famille) : on dit qui l'utilise à chaque lancement.
    choixPersonne = appareilPartage && membresVisibles.length > 1;
  }

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
  }

  /// Trois listes exemples, dans le premier magasin : une en préparation, une prête, une course
  /// interrompue. Les exemples précédents sont remplacés.
  void creerExemples({bool enregistrer = true}) {
    if (magasins.isEmpty) return;
    listes.removeWhere((l) => (l.nom ?? '').startsWith(prefixeExemple) && l.statut != StatutListe.terminee);
    final m = _trouve(magasins, (m) => m.nom == 'Intermarché') ?? magasins.first;
    final parNom = {for (final p in produits) p.nom.toLowerCase(): p};
    List<LigneListe> lignes(List<String> noms) => [
          for (final n in noms)
            if (parNom[n.toLowerCase()] case final p?) LigneListe(produitId: p.id)
        ];
    final maintenant = DateTime.now();
    Liste nouvelle(String nom, StatutListe statut, List<String> noms) {
      final l = Liste(
        id: nouvelId('l'),
        magasinId: m.id,
        statut: statut,
        dateCreation: maintenant,
        lignes: lignes(noms),
        modifieePar: moi.id,
        modifieeLe: maintenant,
        nom: '$prefixeExemple$nom',
      );
      listes.add(l);
      return l;
    }

    nouvelle('liste en préparation', StatutListe.enConstruction, ['Lait demi-écrémé', 'Pain de mie', 'Beurre doux', 'Pommes', 'Yaourts nature', 'Café moulu']);
    nouvelle('liste prête pour les courses', StatutListe.prete, ['Pâtes spaghetti', 'Riz basmati', 'Tomates', 'Œufs', 'Emmental râpé', 'Papier toilette']);
    final enCours = nouvelle('courses en cours', StatutListe.enCours,
        ['Bananes', 'Carottes', 'Jambon blanc', 'Camembert', 'Eau minérale', 'Liquide vaisselle', 'Baguette']);
    enCours
      ..membreId = moi.id
      ..interrompueLe = maintenant;
    for (final g in enCours.lignes.take(2)) {
      g.cocheLe = maintenant;
      g.cochePar = moi.id;
    }
    if (enregistrer) modifie();
  }

  /// Premier lancement : un foyer vide, avec son créateur et un premier magasin (rempli d'après le catalogue complet).
  Map<String, dynamic> _depart(Map<String, dynamic> demo) {
    final auj = DateTime.now();
    const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hasard = Random.secure();
    final code = List.generate(6, (_) => lettres[hasard.nextInt(lettres.length)]).join();
    return {
      '_description': demo['_description'],
      '_ecartsModele': demo['_ecartsModele'],
      'foyer': {'id': nouvelId('f'), 'nom': 'Mon foyer', 'dateCreation': _iso(auj)!.substring(0, 10)},
      'membres': [
        {'id': nouvelId('m'), 'nomAffiche': 'Moi', 'role': 'administrateur', 'moi': true}
      ],
      'invitation': {'code': code, 'expiration': _iso(auj.add(const Duration(days: 7)))!.substring(0, 10)},
      'parametres': demo['parametres'],
      'typesPromotion': demo['typesPromotion'],
      'magasins': [
        for (final e in enseignesDeDepart) {'id': nouvelId('mg'), 'nom': e, 'enseigne': e, 'ville': ''}
      ],
      for (final cle in ['rayons', 'secteurs', 'marques', 'packagings', 'produits', 'emplacements', 'parcours', 'listes', 'historique', 'tickets'])
        cle: <dynamic>[],
      'frequencesPreliste': {'_regle': (demo['frequencesPreliste'] as Map?)?['_regle'] ?? ''},
    };
  }

  Future<void> enregistrer() async {
    if (!enregistrementActif) return;
    final s = _actif;
    if (s == null) return;
    try {
      s.ecrire(versJson());
      for (final e in s.erreurs) {
        debugPrint('Refusé par la base : $e');
      }
      // Le compteur d'utilisation est tenu par la base (règle R4).
      final c = s.compteurs();
      for (final p in produits) {
        p.nbUtilisations = c[p.id] ?? p.nbUtilisations;
      }
      if (identical(s, _foyer)) surEnregistrement?.call();
    } catch (e) {
      debugPrint('Enregistrement impossible : $e');
    }
  }

  /// Intègre les modifications reçues des autres appareils du foyer, puis relit la base.
  int integrerDistant(List<Map<String, dynamic>> objets) {
    final s = _foyer;
    if (s == null) return 0;
    enregistrer(); // ce qui vient d'être fait ici passe d'abord
    final n = s.appliquer(objets);
    if (n > 0) {
      lire(s.lire());
      _retrouverMoi(s);
    }
    return n;
  }

  /// Rejoindre un foyer : les données de cet appareil sont mises de côté (fichier gardé)
  /// et remplacées par un foyer vide, avec [nom] comme membre, qui se remplit de ce que les autres envoient.
  Future<void> rejoindreFoyer(String nom, {String email = ''}) async {
    final demo = await _donneesDemo();
    if (_dossier == null) {
      lire(_depart(demo));
      return;
    }
    _foyer?.fermer();
    _foyer = null;
    final f = _chemin(baseFoyer);
    if (baseExiste(f)) await renommerBase(f, '$f.avant-partage-${_horodatage()}');
    final s = _foyer = Stockage.ouvrir(_chemin(baseFoyer));
    final depart = _depart(demo);
    final moiJson = (depart['membres'] as List).first as Map;
    moiJson['nomAffiche'] = nom.trim().isEmpty ? 'Nouvel appareil' : nom.trim();
    moiJson['role'] = 'membre';
    moiJson['email'] = email.trim();
    depart['magasins'] = <dynamic>[];
    depart['parametres'] = {
      ...(demo['parametres'] as Map? ?? {}),
      'options': {'formats': 1, 'typesPackaging': <String>[]},
    };
    s.ecrire(depart); // avant la synchronisation : rien de ceci ne part vers les autres
    s.definirReglage('synchro_membre_provisoire', moiJson['id'] as String);
    lire(s.lire());
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

  /// Membre provisoire de cet appareil, en attendant que la personne choisisse son nom.
  bool get moiProvisoire => _foyer?.reglage('synchro_membre_provisoire') == moi.id;

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
    commentaires = {for (final e in (options?['commentaires'] as Map? ?? {}).entries) e.key as String: e.value as String};
    manquants = {for (final e in (options?['manquants'] as Map? ?? {}).entries) e.key as String: _ids(e.value).toSet()};
    simples = _ids(options?['simples']).toSet();
    datesPrevues = {for (final e in (options?['datesPrevues'] as Map? ?? {}).entries) e.key as String: e.value as String};
    libellesTickets = {for (final e in (options?['libellesTickets'] as Map? ?? {}).entries) e.key as String: e.value as String};
    ticketsImage = _ids(options?['ticketsImage']).toSet();
    nonRangees = _ids(options?['nonRangees']).toSet();
    listesTypes = [for (final t in (options?['listesTypes'] as List? ?? const []).cast<Map>()) ListeType.depuis(t)];
    parcoursAppris = _ids(options?['parcoursAppris']).toSet();
    produitsPerso = {for (final e in (options?['produitsPerso'] as Map? ?? {}).entries) e.key as String: e.value as String};
    marquesSecteurs = {
      for (final e in (options?['marquesSecteurs'] as Map? ?? {}).entries)
        e.key as String: {for (final x in (e.value as Map).entries) x.key as String: _ids(x.value)}
    };
    statutsMembres = {for (final e in (options?['statutsMembres'] as Map? ?? {}).entries) e.key as String: e.value as String};
    structurePerso = {for (final x in (options?['structurePerso'] as List? ?? const [])) x as String};
    typesPackaging = _ids(options?['typesPackaging']);
    delaiArchives = (options?['delaiArchives'] as num? ?? 0).toInt();
    apparence = options?['apparence'] as String?;
    formatsAppliques = options?['formats'] == 1;
    lotsCompletes = options?['lots'] == 1;
    versionCatalogueCommun = (options?['catalogueCommun'] as num? ?? 0).toInt();
    nouveautesCatalogue = (options?['nouveautesCatalogue'] as Map?)?.cast<String, dynamic>();
    imagesChoisies
      ..clear()
      ..addAll(Map<String, String>.from(options?['images'] as Map? ?? {}));
    typesPromotion = [
      for (final t in (j['typesPromotion'] as List).cast<Map>())
        TypePromotion(t['id'] as String, t['code'] as String, t['nom'] as String, t['exemple'] as String? ?? '',
            _ids(t['parametres']))
    ];
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
    notifyListeners();
  }

  Map<String, dynamic> versJson() => {
        '_description': _brut['_description'],
        '_ecartsModele': _brut['_ecartsModele'],
        'foyer': {'id': foyerId, 'nom': foyerNom, 'dateCreation': _iso(foyerCreation)!.substring(0, 10)},
        'membres': [
          for (final m in membres)
            {'id': m.id, 'nomAffiche': m.nomAffiche, 'role': m.role, 'moi': m.moi, if (m.email.isNotEmpty) 'email': m.email}
        ],
        'invitation': {'code': invitationCode, 'expiration': _iso(invitationExpiration)!.substring(0, 10)},
        'parametres': {
          'preliste': {'presencesMin': prelistePresencesMin, 'sur': prelisteSur},
          'options': {
            'parSecteurs': parSecteurs,
            'envoiFoyer': envoiFoyer,
            'ajoutParRecherche': ajoutParRecherche,
            'modePreparation': modePreparation,
            'delaiHistorique': delaiHistorique,
            if (archivees.isNotEmpty) 'archivees': archivees.toList(),
            if (gardeesEnHistorique.isNotEmpty) 'gardeesEnHistorique': gardeesEnHistorique.toList(),
            if (imagesChoisies.isNotEmpty) 'images': imagesChoisies,
            if (couleurs.isNotEmpty) 'couleurs': couleurs,
            if (apprentissage.isNotEmpty) 'apprentissage': apprentissage.toList(),
            if (sansTicket.isNotEmpty) 'sansTicket': sansTicket.toList(),
            if (commentaires.isNotEmpty) 'commentaires': commentaires,
            if (manquants.isNotEmpty) 'manquants': {for (final e in manquants.entries) e.key: e.value.toList()},
            if (simples.isNotEmpty) 'simples': simples.toList(),
            if (datesPrevues.isNotEmpty) 'datesPrevues': datesPrevues,
            if (libellesTickets.isNotEmpty) 'libellesTickets': libellesTickets,
            if (ticketsImage.isNotEmpty) 'ticketsImage': ticketsImage.toList(),
            if (nonRangees.isNotEmpty) 'nonRangees': nonRangees.toList(),
            if (listesTypes.isNotEmpty) 'listesTypes': [for (final t in listesTypes) t.toJson()],
            if (parcoursAppris.isNotEmpty) 'parcoursAppris': parcoursAppris.toList(),
            if (produitsPerso.isNotEmpty) 'produitsPerso': produitsPerso,
            if (marquesSecteurs.isNotEmpty) 'marquesSecteurs': marquesSecteurs,
            if (statutsMembres.isNotEmpty) 'statutsMembres': statutsMembres,
            if (structurePerso.isNotEmpty) 'structurePerso': structurePerso.toList()..sort(),
            'typesPackaging': typesPackaging,
            if (magasinsArchives.isNotEmpty) 'magasinsArchives': [for (final m in magasinsArchives) m.id],
            if (delaiArchives > 0) 'delaiArchives': delaiArchives,
            if (apparence != null) 'apparence': apparence,
            if (formatsAppliques) 'formats': 1,
            if (lotsCompletes) 'lots': 1,
            if (versionCatalogueCommun > 0) 'catalogueCommun': versionCatalogueCommun,
            if (nouveautesCatalogue != null) 'nouveautesCatalogue': nouveautesCatalogue,
          },
        },
        'typesPromotion': [for (final t in typesPromotion) t.toJson()],
        'magasins': [
          for (final m in magasins) {'id': m.id, 'nom': m.nom, 'enseigne': m.enseigne, 'ville': m.ville},
          for (final m in magasinsArchives) {'id': m.id, 'nom': m.nom, 'enseigne': m.enseigne, 'ville': m.ville, 'archive': true},
        ],
        'rayons': [for (final r in rayons) {'id': r.id, 'magasinId': r.magasinId, 'nom': r.nom}],
        'secteurs': [for (final s in secteurs) {'id': s.id, 'rayonId': s.rayonId, 'nom': s.nom}],
        'marques': [for (final m in marques) {'id': m.id, 'nom': m.nom}],
        'packagings': [for (final k in packagings) {'id': k.id, 'libelle': k.libelle}],
        'produits': [
          for (final p in produits)
            {'id': p.id, 'nom': p.nom, 'marqueIds': p.marqueIds, 'packagingIds': p.packagingIds, 'nbUtilisations': p.nbUtilisations}
        ],
        'emplacements': [
          for (final e in emplacements) {'magasinId': e.magasinId, 'produitId': e.produitId, 'secteurId': e.secteurId}
        ],
        'parcours': [
          for (final p in parcours)
            {'id': p.id, 'magasinId': p.magasinId, 'membreId': p.membreId, 'nom': p.nom, 'parDefaut': p.parDefaut, 'etapes': p.etapes}
        ],
        'listes': [for (final l in listes) l.toJson()],
        'historique': [
          for (final h in historique)
            {'id': h.id, 'magasinId': h.magasinId, 'dateCourses': _iso(h.dateCourses)!.substring(0, 10), 'membreId': h.membreId, 'nbArticles': h.nbArticles, if (h.nom != null) 'nom': h.nom}
        ],
        'tickets': [
          for (final t in tickets)
            {'id': t.id, 'listeId': t.listeId, 'magasinId': t.magasinId, 'date': _iso(t.date)!.substring(0, 10), 'montant': t.montant, 'source': t.source}
        ],
        'frequencesPreliste': {'_regle': regleFrequence, ...frequences},
        'corbeille': [for (final c in corbeille) c.toJson()],
        'rectificatives': [for (final r in rectificatives.values) r.toJson()],
      };

  // ------------------------------------------------------------ Recherche

  static T? _trouve<T>(Iterable<T> l, bool Function(T) test) {
    for (final e in l) {
      if (test(e)) return e;
    }
    return null;
  }

  Membre get moi => _trouve(membres, (m) => m.moi) ?? membres.first;
  Membre? membre(String? id) => _trouve(membres, (m) => m.id == id);
  Magasin? magasin(String? id) => _trouve(magasins, (m) => m.id == id) ?? _trouve(magasinsArchives, (m) => m.id == id);
  bool estArchive(String? magasinId) => magasinsArchives.any((m) => m.id == magasinId);
  Rayon? rayon(String? id) => _trouve(rayons, (r) => r.id == id);
  Secteur? secteur(String? id) => _trouve(secteurs, (s) => s.id == id);
  Marque? marque(String? id) => _trouve(marques, (m) => m.id == id);
  Packaging? packaging(String? id) => _trouve(packagings, (k) => k.id == id);
  Produit? produit(String? id) => _trouve(produits, (p) => p.id == id);
  Liste? liste(String? id) => _trouve(listes, (l) => l.id == id);
  Parcours? unParcours(String? id) => _trouve(parcours, (p) => p.id == id);
  TypePromotion? typePromotion(String? id) => _trouve(typesPromotion, (t) => t.id == id);
  Course? course(String? id) => _trouve(historique, (c) => c.id == id);
  Ticket? ticketDe(String courseId) => _trouve(tickets, (t) => t.listeId == courseId);

  List<Rayon> rayonsDu(String magasinId) => rayons.where((r) => r.magasinId == magasinId).toList();
  List<Secteur> secteursDu(String rayonId) => secteurs.where((s) => s.rayonId == rayonId).toList();
  List<Secteur> secteursDuMagasin(String magasinId) {
    final ids = rayonsDu(magasinId).map((r) => r.id).toSet();
    return secteurs.where((s) => ids.contains(s.rayonId)).toList();
  }

  Secteur? secteurDe(String magasinId, String produitId) {
    final e = _trouve(emplacements, (e) => e.magasinId == magasinId && e.produitId == produitId);
    return e == null ? null : secteur(e.secteurId);
  }

  Rayon? rayonDe(String magasinId, String produitId) => rayon(secteurDe(magasinId, produitId)?.rayonId);

  List<Produit> produitsDu(String magasinId, String secteurId) => [
        for (final e in emplacements)
          if (e.magasinId == magasinId && e.secteurId == secteurId) produit(e.produitId)
      ].whereType<Produit>().toList();

  int nbProduitsRayon(String magasinId, String rayonId) =>
      secteursDu(rayonId).fold(0, (n, s) => n + produitsDu(magasinId, s.id).length);

  /// Complément affiché en gris : marque et packaging.
  String complement(LigneListe? g, Produit p, {bool marque = true, bool avecPackaging = true}) {
    final m = <String>[];
    final mq = this.marque(g?.marqueId);
    if (marque && mq != null) m.add(mq.nom);
    final k = packagingDe(g, p);
    if (avecPackaging && k != null) m.add(k.libelle.toLowerCase());
    return m.join(' · ');
  }

  /// Packaging de la ligne, ou le premier du produit.
  Packaging? packagingDe(LigneListe? g, Produit p) =>
      packaging(g?.packagingId) ?? (p.packagingIds.isNotEmpty ? packaging(p.packagingIds.first) : null);

  // ------------------------------------------------------------ Listes

  List<Liste> listesStatut(StatutListe s) => listes.where((l) => l.statut == s).toList();
  Liste? get coursesEnCours => _trouve(listes, (l) => l.statut == StatutListe.enCours);
  Liste? get preparationInterrompue =>
      _trouve(listes, (l) => l.statut == StatutListe.enConstruction && l.interrompueLe != null);

  /// L'écran de reprise s'affiche au lancement si des courses sont en cours ou une préparation interrompue.
  bool get repriseAuLancement => coursesEnCours != null || preparationInterrompue != null;

  LigneListe? ligne(Liste l, String produitId) => _trouve(l.lignes, (g) => g.produitId == produitId);

  void _toucheConstruction(Liste l) {
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    if (l.statut == StatutListe.enConstruction) l.interrompueLe = DateTime.now();
  }

  void basculer(Liste l, String produitId) {
    final g = ligne(l, produitId);
    if (g == null) {
      final p = produit(produitId);
      p?.nbUtilisations++; // entrée dans une liste (règle R4)
      l.lignes.add(LigneListe(
        produitId: produitId,
        packagingId: (p != null && p.packagingIds.isNotEmpty) ? p.packagingIds.first : null,
      ));
    } else {
      l.lignes.remove(g);
    }
    _toucheConstruction(l);
    modifie();
  }

  void ajouterLigne(Liste l, String produitId) {
    if (ligne(l, produitId) == null) basculer(l, produitId);
  }

  void quantite(Liste l, String produitId, int q) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (q <= 0) {
      l.lignes.remove(g);
    } else {
      g.quantite = q;
    }
    _toucheConstruction(l);
    modifie();
  }

  /// Remet une ligne retirée (« Annuler » du message), à sa place.
  void remettreLigne(Liste l, LigneListe g, int i) {
    if (ligne(l, g.produitId) != null) return;
    l.lignes.insert(i.clamp(0, l.lignes.length), g);
    _toucheConstruction(l);
    modifie();
  }

  void definirPromotion(Liste l, String produitId, PromotionLigne? promo) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.promotion = promo;
    // La quantité suit la promotion qui exige un nombre (« 3 dont 1 gratuit » → 3).
    final requise = promo?.quantiteRequise;
    if (requise != null && g.quantite < requise) g.quantite = requise;
    _toucheConstruction(l);
    modifie();
  }

  void definirPackaging(Liste l, String produitId, String? packagingId) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.packagingId = packagingId;
    _toucheConstruction(l);
    modifie();
  }

  // ------------------------------------------------------------ Listes types

  /// Enregistre les articles de la liste sous un nom (sans coche) ; un nom déjà pris remplace l'ancienne liste type.
  ListeType enregistrerListeType(Liste l, String nom) {
    listesTypes.removeWhere((t) => t.nom.trim().toLowerCase() == nom.trim().toLowerCase());
    final t = ListeType(nouvelId('lt'), nom.trim(), l.magasinId, lignesReprises(l));
    listesTypes.add(t);
    modifie();
    return t;
  }

  void supprimerListeType(ListeType t) {
    listesTypes.remove(t);
    modifie();
  }

  /// Annule [supprimerListeType] : la liste type revient à sa place.
  void remettreListeType(ListeType t, int place) {
    if (listesTypes.contains(t)) return;
    listesTypes.insert(place.clamp(0, listesTypes.length), t);
    modifie();
  }

  /// Articles d'une liste type, à copier dans une nouvelle liste.
  List<LigneListe> lignesDeListeType(ListeType t) => [
        for (final g in t.lignes)
          if (produit(g.produitId) != null)
            LigneListe(
                produitId: g.produitId, marqueId: g.marqueId, packagingId: g.packagingId, quantite: g.quantite, consigne: g.consigne)
      ];

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

  /// Packaging correspondant à une mesure et un lot (créé au besoin) ; null si ni l'un ni l'autre.
  Packaging? packagingCompose(String? mesure, String? lot) {
    if (mesure == null && lot == null) return null;
    return _packagingNomme(mesure != null && lot != null ? '$lot × $mesure' : (lot ?? mesure)!);
  }

  /// Mesures proposées pour un produit : ses formats, sinon tous les types de packaging qui ne sont pas des lots.
  List<String> mesuresProposees(Produit p) {
    final siens = <String>{
      for (final id in p.packagingIds)
        if (mesureEtLot(packaging(id)?.libelle).$1 case final m?) m
    };
    if (siens.isNotEmpty) return siens.toList();
    return [
      for (final id in typesPackaging)
        if (packaging(id) case final k? when !estLot(k.libelle)) k.libelle
    ];
  }

  /// Lots proposés : ceux du produit et tous les types de packaging « lot ».
  List<String> lotsProposes(Produit p) => <String>{
        for (final id in [...p.packagingIds, ...typesPackaging])
          if (mesureEtLot(packaging(id)?.libelle).$2 case final l?) l
      }.toList();

  /// Ajouter une marque ou choisir un packaging crée un article à part (« Camembert » reste ;
  /// « Camembert Président · 250 g » est créé), rangé aux mêmes endroits ; la ligne passe sur ce nouvel article.
  Produit produitVariante(Liste l, Produit p, {String? marqueNom, String? packagingId}) {
    final mq = (marqueNom ?? '').trim();
    final k = packaging(packagingId);
    final racine = p.nom.split(' · ').first;
    final nom = '$racine${mq.isEmpty ? '' : ' $mq'}${k == null ? '' : ' · ${k.libelle}'}';
    var q = _trouve(produits, (x) => x.nom.toLowerCase() == nom.toLowerCase());
    if (q == null) {
      q = Produit(nouvelId('p'), nom, [...p.marqueIds], [if (k != null) k.id, ...p.packagingIds.where((id) => id != k?.id)], 0);
      produits.add(q);
      _marquerAjoute(q);
      for (final e in emplacements.where((e) => e.produitId == p.id).toList()) {
        emplacements.add(Emplacement(e.magasinId, q.id, e.secteurId));
      }
    }
    if (mq.isNotEmpty) ajouterMarque(q, mq);
    final m = mq.isEmpty ? null : _trouve(marques, (x) => x.nom.toLowerCase() == mq.toLowerCase());
    final i = l.lignes.indexWhere((g) => g.produitId == p.id);
    if (i >= 0 && q.id != p.id && ligne(l, q.id) == null) {
      final g = l.lignes[i];
      q.nbUtilisations++;
      l.lignes[i] = LigneListe(
          produitId: q.id,
          marqueId: m?.id ?? g.marqueId,
          packagingId: k?.id ?? g.packagingId,
          quantite: g.quantite,
          promotion: g.promotion,
          consigne: g.consigne);
    }
    _toucheConstruction(l);
    modifie();
    return q;
  }

  /// Nom de l'article sans la marque de sa ligne (« Camembert Président » → « Camembert »).
  String nomSansMarque(LigneListe? g, Produit p) {
    final mq = marque(g?.marqueId)?.nom;
    if (mq != null && p.nom.toLowerCase().endsWith(' ${mq.toLowerCase()}')) {
      return p.nom.substring(0, p.nom.length - mq.length - 1);
    }
    return p.nom;
  }

  /// Libellé de l'article dans la liste : son nom, avec la marque de la ligne si le nom ne la porte pas déjà.
  String libelleArticle(LigneListe? g, Produit p) {
    final mq = marque(g?.marqueId)?.nom;
    if (mq == null || p.nom.toLowerCase().contains(mq.toLowerCase())) return p.nom;
    return '${p.nom} $mq';
  }

  /// Marques proposées pour un article : celles de son secteur dans le catalogue des marques, celles du
  /// produit et de ses variantes (« Camembert Président »…).
  List<String> marquesProposees(LigneListe? g, Produit p, {String? magasinId}) {
    final racine = nomSansMarque(g, p).toLowerCase();
    final s = secteurCatalogue(p.id);
    final duSecteur = [
      if (s != null) ...marquesDuSecteur(s),
      if (magasinId != null) ...marquesDistributeurPour(magasin(magasinId), s),
    ];
    final ids = <String>{
      ...p.marqueIds,
      for (final q in produits)
        if (q.nom.toLowerCase() == racine || q.nom.toLowerCase().startsWith('$racine ')) ...q.marqueIds,
    };
    final noms = <String>{for (final n in duSecteur) n};
    for (final id in ids) {
      final n = marque(id)?.nom;
      if (n != null && !noms.any((x) => x.toLowerCase() == n.toLowerCase())) noms.add(n);
    }
    return noms.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Change la marque d'un article de la liste : « Camembert » devient l'article « Camembert Président »
  /// (créé au besoin, rangé aux mêmes endroits) ; sans marque, il redevient « Camembert ».
  /// La ligne garde sa quantité, son packaging, sa promotion et sa consigne. Rend l'article de la ligne.
  Produit changerMarque(Liste l, Produit p, String? marqueNom) {
    final g = ligne(l, p.id);
    if (g == null) return p;
    final mq = (marqueNom ?? '').trim();
    final racine = nomSansMarque(g, p);
    final nom = mq.isEmpty ? racine : '$racine $mq';
    var q = nom.toLowerCase() == p.nom.toLowerCase() ? p : _trouve(produits, (x) => x.nom.toLowerCase() == nom.toLowerCase());
    if (q == null) {
      q = Produit(nouvelId('p'), nom, [...p.marqueIds], [...p.packagingIds], 0);
      produits.add(q);
      _marquerAjoute(q);
      for (final e in emplacements.where((e) => e.produitId == p.id).toList()) {
        emplacements.add(Emplacement(e.magasinId, q.id, e.secteurId));
      }
    }
    if (mq.isNotEmpty) ajouterMarque(q, mq);
    final m = mq.isEmpty ? null : _trouve(marques, (x) => x.nom.toLowerCase() == mq.toLowerCase());
    if (q.id != p.id) {
      final i = l.lignes.indexOf(g);
      if (ligne(l, q.id) != null) {
        l.lignes.removeAt(i);
      } else {
        q.nbUtilisations++;
        l.lignes[i] = LigneListe(
            produitId: q.id,
            marqueId: m?.id,
            packagingId: g.packagingId,
            quantite: g.quantite,
            promotion: g.promotion,
            consigne: g.consigne);
      }
    } else {
      g.marqueId = m?.id;
    }
    _toucheConstruction(l);
    modifie();
    return q;
  }

  void definirConsigne(Liste l, String produitId, String? consigne) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.consigne = (consigne == null || consigne.trim().isEmpty) ? null : consigne.trim();
    _toucheConstruction(l);
    modifie();
  }

  /// Nom affiché d'une liste : celui donné par l'utilisateur, sinon « magasin du jj/mm/aaaa ».
  /// Nom complet de la liste d'une course de l'historique.
  String nomCourse(Course c) {
    final l = liste(c.id);
    if (l != null) return nomListe(l);
    return (c.nom != null && c.nom!.isNotEmpty) ? c.nom! : nomParDefaut(c.magasinId, c.dateCourses);
  }

  String nomListe(Liste l) => (l.nom != null && l.nom!.isNotEmpty) ? l.nom! : nomParDefaut(l.magasinId, l.dateCreation);
  /// Magasin, date et heure : deux listes créées n'ont pas le même nom.
  /// (Sans heure connue, comme dans les données de démonstration, la date seule.)
  String nomParDefaut(String magasinId, DateTime d) => '${magasin(magasinId)?.nom ?? 'Liste'} du ${jjmmaaaa(d)}'
      '${d.hour == 0 && d.minute == 0 ? '' : ' à ${heure(d)}'}';

  /// Nom libre à partir d'un nom proposé : « … (2) », « … (3) » si déjà pris.
  String nomLibre(String nom) {
    var n = nom;
    for (var i = 2; nomPris(n); i++) {
      n = '$nom ($i)';
    }
    return n;
  }

  /// Une liste non terminée porte déjà ce nom (deux listes ne peuvent pas avoir le même nom).
  bool nomPris(String nom, {Liste? sauf}) => listes.any((l) =>
      l != sauf && l.statut != StatutListe.terminee && nomListe(l).trim().toLowerCase() == nom.trim().toLowerCase());

  void renommerListe(Liste l, String nom) {
    l.nom = nom.trim().isEmpty ? null : nom.trim();
    modifie();
  }

  /// Une liste prête revient en préparation.
  /// Courses interrompues remises en préparation : les coches sont perdues.
  void coursesEnPreparation(Liste l) {
    for (final g in l.lignes) {
      g.cocheLe = null;
      g.cochePar = null;
    }
    apprentissage.remove(l.id);
    l.interrompueLe = null;
    remettreEnPreparation(l);
  }

  void remettreEnPreparation(Liste l) {
    // Une rectificative remise en préparation devient une liste ordinaire.
    if (rectificatives[l.id]?.signalee ?? false) rectificatives.remove(l.id);
    l.statut = StatutListe.enConstruction;
    l.membreId = null;
    l.parcoursId = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    modifie();
  }

  /// Dernières courses terminées dans un magasin (avec leurs articles), les plus récentes d'abord.
  List<Liste> dernieresCourses(String magasinId, {int nombre = 6}) {
    DateTime date(Liste l) => course(l.id)?.dateCourses ?? l.modifieeLe ?? l.dateCreation;
    final res = listes.where((l) => l.magasinId == magasinId && l.statut == StatutListe.terminee && l.lignes.isNotEmpty).toList()
      ..sort((a, b) => date(b).compareTo(date(a)));
    return res.take(nombre).toList();
  }

  DateTime dateCourses(Liste l) => course(l.id)?.dateCourses ?? l.modifieeLe ?? l.dateCreation;

  /// Articles d'une liste reprise pour une nouvelle préparation (sans coche ni promotion).
  List<LigneListe> lignesReprises(Liste ancienne) => [
        for (final g in ancienne.lignes)
          if (produit(g.produitId) != null)
            LigneListe(produitId: g.produitId, marqueId: g.marqueId, packagingId: g.packagingId, quantite: g.quantite, consigne: g.consigne)
      ];

  /// Quantité requise par la promotion si la ligne n'y suffit pas (règle 11), sinon null.
  int? quantiteInsuffisante(LigneListe g) {
    final r = g.promotion?.quantiteRequise;
    return (r != null && g.quantite < r) ? r : null;
  }

  int nbDansRayon(Liste l, String rayonId) => l.lignes.where((g) => rayonDe(l.magasinId, g.produitId)?.id == rayonId).length;
  int nbDansSecteur(Liste l, String secteurId) =>
      l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == secteurId).length;

  /// Position courante de la construction, gardée pour la reprise.
  void positionConstruction(Liste l, String? rayonId, String? secteurId) {
    if (l.repriseRayonId == rayonId && l.repriseSecteurId == secteurId && l.interrompueLe != null) return;
    l.repriseRayonId = rayonId;
    l.repriseSecteurId = secteurId;
    l.interrompueLe = DateTime.now();
    modifie();
  }

  Liste creerListe(String magasinId, List<LigneListe> lignes, {String? nom}) {
    for (final g in lignes) {
      produit(g.produitId)?.nbUtilisations++; // entrée dans une liste (règle R4)
    }
    final l = Liste(
      id: nouvelId('l'),
      magasinId: magasinId,
      statut: StatutListe.enConstruction,
      dateCreation: DateTime.now(),
      lignes: lignes,
      modifieePar: moi.id,
      modifieeLe: DateTime.now(),
      nom: (nom == null || nom.trim().isEmpty) ? null : nom.trim(),
    );
    listes.add(l);
    modifie();
    return l;
  }

  void listePrete(Liste l) {
    l.statut = StatutListe.prete;
    l.interrompueLe = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    modifie();
  }

  // ------------------------------------------------------------ Liste rectificative

  Rectificative? rectificativeDe(Liste l) => rectificatives[l.id];

  /// Listes « À faire » ou en cours de courses qu'une rectificative peut compléter.
  List<Liste> ciblesRectificative() =>
      [for (final l in listes) if (l.statut == StatutListe.prete || l.statut == StatutListe.enCours) l];

  /// Rectificative pas encore réglée pour [cible] (en préparation ou en attente de décision) : une seule à la fois.
  Rectificative? rectificativeOuvertePour(Liste cible) => _trouve(
      rectificatives.values, (r) => r.cibleId == cible.id && (r.enRedaction || r.enAttente) && liste(r.listeId) != null);

  /// Rectificative qui attend la décision de celui qui fait la course [cible].
  Rectificative? rectificativeEnAttente(Liste cible) => _trouve(
      rectificatives.values, (r) => r.cibleId == cible.id && r.enAttente && liste(r.listeId) != null);

  /// Rectificatives acceptées pour la course [cible].
  List<Rectificative> rectificativesAcceptees(Liste cible) =>
      [for (final r in rectificatives.values) if (r.cibleId == cible.id && r.acceptee) r];

  /// Mention après le nombre d'articles d'une liste : « rectificative », « rectificative envoyée ».
  String mentionRectificative(Liste l) {
    final r = rectificatives[l.id];
    if (r == null || r.acceptee) return '';
    return r.enAttente ? ' · rectificative envoyée' : ' · rectificative';
  }

  /// Nouvelle liste rectificative de [cible] : une liste simple du même magasin.
  Liste creerRectificative(Liste cible) {
    final l = creerListe(cible.magasinId, [], nom: nomLibre('Rectificative ${nomListe(cible)}'));
    marquerSimple(l, true);
    rectificatives[l.id] = Rectificative(l.id, cible.id, moi.id, DateTime.now(), mode: 'redaction');
    modifie();
    return l;
  }

  /// « Liste prête » d'une rectificative : fusionnée dans une liste pas encore commencée ('fusionnee'),
  /// envoyée à celui qui fait les courses ('envoyee'), ou, les courses finies, mise en « À faire » ('afaire').
  String validerRectificative(Liste l) {
    final r = rectificatives[l.id];
    if (r == null) return '';
    final cible = liste(r.cibleId);
    if (cible?.statut == StatutListe.enCours) {
      r.mode = null;
      l.modifieePar = moi.id;
      l.modifieeLe = DateTime.now();
      modifie();
      return 'envoyee';
    }
    if (cible != null && cible.statut != StatutListe.terminee) {
      accepterRectificative(r, fusion: true);
      return 'fusionnee';
    }
    _signaler(r);
    return 'afaire';
  }

  void _signaler(Rectificative r) {
    final l = liste(r.listeId);
    if (l == null) {
      rectificatives.remove(r.listeId);
      modifie();
      return;
    }
    r.mode = 'signalee';
    listePrete(l);
  }

  /// Refusée : elle passe en « À faire », marquée rectificative.
  void refuserRectificative(Rectificative r) => _signaler(r);

  /// Ajoute les articles de la rectificative à la course ; un article déjà dans la course n'est pas doublé.
  void accepterRectificative(Rectificative r, {required bool fusion}) {
    final rl = liste(r.listeId);
    final cible = liste(r.cibleId);
    if (rl == null || cible == null) return;
    for (final g in rl.lignes) {
      if (ligne(cible, g.produitId) != null) continue;
      cible.lignes.add(LigneListe(
          produitId: g.produitId,
          marqueId: g.marqueId,
          packagingId: g.packagingId,
          quantite: g.quantite,
          promotion: g.promotion,
          consigne: g.consigne));
      r.produits.add(g.produitId);
    }
    r.mode = fusion ? 'fusion' : 'apart';
    final c = commentaires.remove(rl.id);
    if (c != null) commentaires[cible.id] = [commentaires[cible.id], c].whereType<String>().join('\n');
    listes.remove(rl);
    modifie();
  }

  // ------------------------------------------------------------ Préliste

  Map<String, int> frequencesDu(String magasinId) => frequences[magasinId] ?? const {};

  List<LigneListe> preliste(String magasinId) => [
        for (final e in frequencesDu(magasinId).entries)
          if (e.value >= prelistePresencesMin && produit(e.key) != null)
            LigneListe(
              produitId: e.key,
              packagingId: produit(e.key)!.packagingIds.isNotEmpty ? produit(e.key)!.packagingIds.first : null,
            )
      ];

  // ------------------------------------------------------------ Parcours

  List<Parcours> parcoursDe(String magasinId, String membreId) =>
      parcours.where((p) => p.magasinId == magasinId && p.membreId == membreId).toList();

  Parcours? parcoursParDefaut(String magasinId, String membreId) {
    final l = parcoursDe(magasinId, membreId);
    if (l.isEmpty) return null;
    return l.firstWhere((p) => p.parDefaut, orElse: () => l.first);
  }

  void definirParDefaut(Parcours p, bool oui) {
    for (final autre in parcoursDe(p.magasinId, p.membreId)) {
      autre.parDefaut = oui ? identical(autre, p) : (identical(autre, p) ? false : autre.parDefaut);
    }
    modifie();
  }

  Parcours creerParcours(String magasinId, String membreId, String nom) {
    final p = Parcours(nouvelId('pc'), magasinId, membreId, nom, parcoursDe(magasinId, membreId).isEmpty,
        secteursDuMagasin(magasinId).map((s) => s.id).toList());
    parcours.add(p);
    modifie();
    return p;
  }

  void renommerParcours(Parcours p, String nom) {
    if (nom.trim().isEmpty) return;
    p.nom = nom.trim();
    modifie();
  }

  /// Rayons du parcours dans l'ordre de leur premier passage.
  List<Rayon> rayonsDuParcours(Parcours p) {
    final ids = <String>[];
    for (final sid in p.etapes) {
      final r = secteur(sid)?.rayonId;
      if (r != null && !ids.contains(r)) ids.add(r);
    }
    return [for (final id in ids) if (rayon(id) != null) rayon(id)!];
  }

  /// Déplace un rayon entier (tous ses secteurs) dans le parcours ; les secteurs sont regroupés par rayon.
  void deplacerRayonParcours(Parcours p, int ancien, int nouveau) {
    final rs = rayonsDuParcours(p);
    if (ancien < 0 || ancien >= rs.length) return;
    final r = rs.removeAt(ancien);
    rs.insert(nouveau.clamp(0, rs.length), r);
    p.etapes = [
      for (final x in rs) ...p.etapes.where((sid) => secteur(sid)?.rayonId == x.id),
      ...p.etapes.where((sid) => secteur(sid) == null),
    ];
    modifie();
  }

  /// Parcours d'un membre, tous magasins confondus.
  List<Parcours> parcoursDuMembre(String membreId) => parcours.where((p) => p.membreId == membreId).toList();

  /// « (retour) » : le rayon de l'étape a déjà été visité plus tôt, mais pas à l'étape précédente (règle 7).
  bool estRetour(List<String> etapes, int i) {
    final r = secteur(etapes[i])?.rayonId;
    if (i == 0 || r == null) return false;
    if (secteur(etapes[i - 1])?.rayonId == r) return false;
    return etapes.take(i - 1).any((id) => secteur(id)?.rayonId == r);
  }

  /// Étapes des courses : secteurs ayant au moins un article, dans l'ordre du parcours
  /// (sans parcours : ordre des rayons), puis « Non placé » (règle 9).
  List<Etape> etapes(Liste l, String? parcoursId) {
    final ordre = <String>[...(unParcours(parcoursId)?.etapes ?? const <String>[])];
    for (final s in secteursDuMagasin(l.magasinId)) {
      if (!ordre.contains(s.id)) ordre.add(s.id);
    }
    final res = <Etape>[];
    for (final sid in ordre) {
      final lignes = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == sid).toList();
      final s = secteur(sid);
      if (lignes.isNotEmpty && s != null) res.add(Etape(s, lignes));
    }
    final np = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId) == null).toList();
    if (np.isNotEmpty) res.add(Etape(null, np));
    return res;
  }

  // ------------------------------------------------------------ Courses

  void demarrerCourses(Liste l, String membreId, String? parcoursId) {
    // Ses courses commencent : elle n'est plus marquée rectificative.
    if (rectificatives[l.id]?.signalee ?? false) rectificatives.remove(l.id);
    // Sans parcours dans ce magasin, on propose d'emblée de l'enregistrer.
    if (parcoursDe(l.magasinId, membreId).isEmpty) apprentissage.add(l.id);
    l.statut = StatutListe.enCours;
    l.membreId = membreId;
    l.parcoursId = parcoursId;
    l.interrompueLe = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    modifie();
  }

  void cocher(Liste l, String produitId) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (g.coche) {
      g.cocheLe = null;
      g.cochePar = null;
    } else {
      g.cocheLe = DateTime.now();
      g.cochePar = l.membreId ?? moi.id;
    }
    modifie();
  }

  /// Changement de parcours pendant les courses : on garde l'étape en cours si elle existe encore.
  void changerParcours(Liste l, String? parcoursId) {
    l.parcoursId = parcoursId;
    modifie();
  }

  bool apprend(Liste l) => apprentissage.contains(l.id);

  void apprendreParcours(Liste l, bool oui) {
    oui ? apprentissage.add(l.id) : apprentissage.remove(l.id);
    modifie();
  }

  /// Secteurs dans l'ordre où leurs premiers articles ont été cochés.
  List<String> secteursDansLOrdre(Liste l) {
    final cochees = l.lignes.where((g) => g.cocheLe != null).toList()..sort((a, b) => a.cocheLe!.compareTo(b.cocheLe!));
    final res = <String>[];
    for (final g in cochees) {
      final s = secteurDe(l.magasinId, g.produitId)?.id;
      if (s != null && !res.contains(s)) res.add(s);
    }
    return res;
  }

  /// Fin de courses enregistrées : crée le parcours appris, ou y insère en silence les secteurs nouveaux,
  /// chacun juste après le secteur visité avant lui (ou juste avant le suivant), sans changer l'ordre existant.
  Parcours? retenirParcours(Liste l) {
    if (!apprentissage.remove(l.id)) return null;
    final suite = secteursDansLOrdre(l);
    if (suite.isEmpty) return null;
    final membreId = l.membreId ?? moi.id;
    final existant = _trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id) && p.id == l.parcoursId) ??
        _trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id) && p.parDefaut) ??
        _trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id));
    if (existant == null) {
      for (final autre in parcoursDe(l.magasinId, membreId)) {
        autre.parDefaut = false;
      }
      final p = Parcours(nouvelId('pc'), l.magasinId, membreId, 'Parcours appris', true, suite);
      parcours.add(p);
      parcoursAppris.add(p.id);
      return p;
    }
    existant.etapes = insererSecteurs(existant.etapes, suite);
    return existant;
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

  /// Départ annulé (rien de coché) : la liste redevient prête.
  void annulerDepart(Liste l) {
    apprentissage.remove(l.id);
    // Les courses n'ont pas commencé : la rectificative en attente s'y ajoute.
    for (final r in [...rectificatives.values.where((r) => r.cibleId == l.id && r.enAttente)]) {
      accepterRectificative(r, fusion: true);
    }
    l.statut = StatutListe.prete;
    l.membreId = null;
    l.parcoursId = null;
    l.repriseSecteurId = null;
    l.interrompueLe = null;
    modifie();
  }

    void etapeCourante(Liste l, String etapeId) {
    l.repriseSecteurId = etapeId;
    modifie();
  }

  void interrompreCourses(Liste l) {
    l.interrompueLe = DateTime.now();
    modifie();
  }

  Course terminerCourses(Liste l) {
    // Dans la base, une course de l'historique est la liste elle-même, au statut « terminee ».
    final c = Course(l.id, l.magasinId, DateTime.now(), l.membreId ?? moi.id, l.nbCoches, nom: l.nom);
    historique.insert(0, c);
    retenirParcours(l);
    l.statut = StatutListe.terminee;
    l.interrompueLe = null;
    // Une rectificative restée sans réponse passe en « À faire » ; une rectificative en préparation le sera à sa fin.
    for (final r in [...rectificatives.values.where((r) => r.cibleId == l.id)]) {
      if (r.enAttente) {
        _signaler(r);
      } else if (r.acceptee) {
        rectificatives.remove(r.listeId);
      }
    }
    modifie();
    return c;
  }

  // ------------------------------------------------------------ Magasin et catalogue

  Magasin? magasinNomme(String nom) => _trouve(magasins, (m) => m.nom.trim().toLowerCase() == nom.trim().toLowerCase());

  /// Listes non terminées rattachées à un magasin.
  List<Liste> listesDuMagasin(String magasinId) =>
      listes.where((l) => l.magasinId == magasinId && l.statut != StatutListe.terminee).toList();

  Magasin creerMagasin(String nom) {
    final m = Magasin(nouvelId('mg'), nom, '', '');
    magasins.add(m);
    modifie();
    return m;
  }

  /// Un nouveau magasin reçoit le catalogue du foyer (le même pour tous les magasins) ;
  /// le premier magasin du foyer, le catalogue de départ.
  Future<void> remplirMagasin(Magasin m) async {
    if (magasins.any((x) => x.id != m.id && rayonsDu(x.id).isNotEmpty)) {
      harmoniserCatalogue();
    } else {
      await appliquerModele(m, tailleComplete);
    }
  }

  static const String fichierCatalogueType = 'assets/catalogue_type.json';

  /// Un nouveau magasin reçoit toujours le catalogue complet, quelle que soit sa taille (décision du 19/10/2026).
  static const int tailleComplete = 3;

  /// Remplit un magasin avec les rayons, secteurs et produits du catalogue type jusqu'à la
  /// [taille] donnée (1 proximité, 2 supermarché, 3 hypermarché). Un produit déjà connu du
  /// foyer (même nom) est réutilisé. Rend le nombre de produits placés.
  Future<int> appliquerModele(Magasin m, int taille, {Map<String, dynamic>? catalogue}) async {
    if (taille <= 0) return 0;
    catalogue ??= await CatalogueType.lireJson();
    final parNom = {for (final p in produits) p.nom.toLowerCase(): p};
    var n = 0;
    for (final r in (catalogue['rayons'] as List).cast<Map>()) {
      final secteursR = (r['secteurs'] as List).cast<Map>().where((s) => (s['taille'] as num) <= taille).toList();
      if (secteursR.isEmpty) continue;
      final rayon = _trouve(rayons, (x) => x.magasinId == m.id && x.nom == r['nom']) ??
          (Rayon(nouvelId('r'), m.id, r['nom'] as String)..let(rayons.add));
      for (final s in secteursR) {
        final secteur = _trouve(secteurs, (x) => x.rayonId == rayon.id && x.nom == s['nom']) ??
            (Secteur(nouvelId('s'), rayon.id, s['nom'] as String)..let(secteurs.add));
        for (final p in (s['produits'] as List).cast<Map>()) {
          if ((p['taille'] as num) > taille) continue;
          final nom = p['nom'] as String;
          final produit = parNom[nom.toLowerCase()] ??= (Produit(nouvelId('p'), nom, [], [], 0)..let(produits.add));
          if (produit.packagingIds.isEmpty) {
            for (final f in (p['formats'] as List? ?? const []).cast<String>()) {
              produit.packagingIds.add(_packagingNomme(f).id);
            }
          }
          if (_trouve(emplacements, (e) => e.magasinId == m.id && e.produitId == produit.id) == null) {
            emplacements.add(Emplacement(m.id, produit.id, secteur.id));
            n++;
          }
        }
      }
    }
    modifie();
    return n;
  }

  Rayon ajouterRayon(String magasinId, String nom) {
    final existant = _trouve(rayons, (r) => r.magasinId == magasinId && r.nom == nom);
    if (existant != null) return existant; // un nom par magasin (contrainte de la base)
    final r = Rayon(nouvelId('r'), magasinId, nom);
    rayons.add(r);
    modifie();
    return r;
  }

  Secteur ajouterSecteur(String rayonId, String nom) {
    final existant = _trouve(secteurs, (s) => s.rayonId == rayonId && s.nom == nom);
    if (existant != null) return existant; // un nom par rayon (contrainte de la base)
    final s = Secteur(nouvelId('s'), rayonId, nom);
    secteurs.add(s);
    modifie();
    return s;
  }

  // ------------------------------------------------------------ Catalogue unique (25/10/2026)
  //
  // Un seul catalogue pour le foyer : les mêmes rayons, secteurs et produits dans tous les magasins,
  // chaque produit dans le même secteur partout. La base garde un exemplaire des rayons et secteurs
  // par magasin ; l'application les tient identiques (mêmes noms).

  /// Magasin dont les rayons et secteurs servent à présenter le catalogue (ils sont les mêmes partout).
  Magasin? get magasinReference => magasins.isEmpty ? null : magasins.first;

  /// Rayons du catalogue.
  List<Rayon> get rayonsCatalogue => magasinReference == null ? [] : rayonsDu(magasinReference!.id);

  /// Secteur du catalogue où est rangé le produit, ou null.
  Secteur? secteurCatalogue(String produitId) => magasinReference == null ? null : secteurDe(magasinReference!.id, produitId);

  /// Produits d'un secteur du catalogue (secteur du magasin de référence).
  List<Produit> produitsDuSecteur(Secteur s) => produitsDu(rayon(s.rayonId)?.magasinId ?? '', s.id);

  /// Le même secteur (mêmes noms de rayon et de secteur) dans le magasin [magasinId].
  Secteur? secteurHomologue(String magasinId, Secteur s) {
    final r = rayon(s.rayonId);
    if (r == null) return null;
    if (r.magasinId == magasinId) return s;
    final r2 = _trouve(rayons, (x) => x.magasinId == magasinId && x.nom == r.nom);
    return r2 == null ? null : _trouve(secteurs, (x) => x.rayonId == r2.id && x.nom == s.nom);
  }

  /// Produit ajouté par le foyer : lui seul peut être modifié ; le catalogue d'origine ne change pas.
  bool estAjoute(Produit p) => produitsPerso[p.id] == 'a';

  /// Produits ajoutés par le foyer, par ordre alphabétique.
  List<Produit> get produitsAjoutes =>
      [for (final p in produits) if (estAjoute(p)) p]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  void _marquerAjoute(Produit p) => produitsPerso[p.id] = 'a';

  /// Marque de ce nom (créée au besoin).
  Marque marqueNommee(String nom) {
    var m = _trouve(marques, (m) => m.nom.toLowerCase() == nom.trim().toLowerCase());
    if (m == null) {
      m = Marque(nouvelId('b'), nom.trim());
      marques.add(m);
      modifie();
    }
    return m;
  }

  /// Libellé d'un produit ajouté, sans sa marque (« Camembert Président » → « Camembert »).
  String libelleSansMarque(Produit p) {
    final m = p.marqueIds.isEmpty ? null : marque(p.marqueIds.first);
    if (m != null && p.nom.toLowerCase().endsWith(' ${m.nom.toLowerCase()}')) {
      return p.nom.substring(0, p.nom.length - m.nom.length - 1);
    }
    return p.nom;
  }

  /// Crée (ou corrige, avec [produit]) un produit ajouté : son nom est le libellé suivi de la marque,
  /// sa mesure et son packaging forment son format de vente.
  Produit enregistrerProduitAjoute({
    Produit? produit,
    required String libelle,
    String? marqueNom,
    String? mesure,
    String? lot,
    Secteur? secteur,
  }) {
    final mq = (marqueNom ?? '').trim();
    final nom = mq.isEmpty ? libelle.trim() : '${libelle.trim()} $mq';
    final p = produit ?? creerProduit(nom, secteur: secteur);
    p.nom = nom;
    p.marqueIds
      ..clear()
      ..addAll([if (mq.isNotEmpty) marqueNommee(mq).id]);
    final k = packagingCompose(mesure, lot);
    p.packagingIds
      ..clear()
      ..addAll([if (k != null) k.id]);
    if (produit != null && secteur != null) placer('', p.id, secteur.id);
    modifie();
    return p;
  }

  /// Range le produit dans le secteur [secteurId] (ou son homologue) de tous les magasins.
  /// [magasinId] n'est gardé que pour les appels existants : le rangement est le même partout.
  void placer(String magasinId, String produitId, String secteurId) {
    final s = secteur(secteurId);
    final p = produit(produitId);
    if (s == null || p == null) return;
    for (final m in magasins) {
      final h = secteurHomologue(m.id, s);
      if (h == null) continue;
      final e = _trouve(emplacements, (e) => e.magasinId == m.id && e.produitId == produitId);
      if (e == null) {
        emplacements.add(Emplacement(m.id, produitId, h.id));
      } else {
        e.secteurId = h.id;
      }
    }
    modifie();
  }

  /// Nouveau produit du catalogue (marqué « ajouté »), rangé dans [secteur] s'il est donné.
  Produit creerProduit(String nom, {Secteur? secteur}) {
    final p = Produit(nouvelId('p'), nom.trim(), [], [], 0);
    produits.add(p);
    _marquerAjoute(p);
    if (secteur != null) {
      placer(rayon(secteur.rayonId)?.magasinId ?? '', p.id, secteur.id);
    } else {
      modifie();
    }
    return p;
  }

  void renommerProduit(Produit p, String nom) {
    if (nom.trim().isEmpty || nom.trim() == p.nom) return;
    p.nom = nom.trim();
    modifie();
  }

  /// Remet les magasins au même catalogue : chaque magasin reçoit les rayons et secteurs qui lui manquent
  /// (identifiants tirés des noms, les mêmes sur tous les appareils), et chaque produit est rangé partout
  /// dans le secteur où il l'est dans le plus de magasins. Rend vrai si quelque chose a changé.
  bool harmoniserCatalogue() {
    final mags = [...magasins]..sort((a, b) => a.id.compareTo(b.id));
    if (mags.length < 2) return false;
    var change = false;
    String cle(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüœ]+'), '-');
    // Structure : l'union des rayons et secteurs de tous les magasins, dans l'ordre du premier.
    final structure = <String, List<String>>{};
    for (final m in mags) {
      for (final r in rayonsDu(m.id)) {
        final l = structure.putIfAbsent(r.nom, () => []);
        for (final s in secteursDu(r.id)) {
          if (!l.contains(s.nom)) l.add(s.nom);
        }
      }
    }
    final parNom = <String, Secteur>{}; // « magasin|rayon|secteur » → secteur
    for (final m in mags) {
      for (final e in structure.entries) {
        var r = _trouve(rayons, (x) => x.magasinId == m.id && x.nom == e.key);
        if (r == null) {
          r = Rayon('r-${m.id}-${cle(e.key)}', m.id, e.key);
          rayons.add(r);
          change = true;
        }
        for (final sn in e.value) {
          var s = _trouve(secteurs, (x) => x.rayonId == r!.id && x.nom == sn);
          if (s == null) {
            s = Secteur('s-${r.id}-${cle(sn)}', r.id, sn);
            secteurs.add(s);
            change = true;
          }
          parNom['${m.id}|${e.key}|$sn'] = s;
        }
      }
    }
    // Rangement : le plus fréquent ; à égalité, le premier par ordre alphabétique.
    final rayonDe = {for (final r in rayons) r.id: r};
    final secteurDeId = {for (final s in secteurs) s.id: s};
    final parProduit = <String, Map<String, Emplacement>>{};
    for (final e in emplacements) {
      (parProduit[e.produitId] ??= {})[e.magasinId] = e;
    }
    final ids = {for (final m in mags) m.id};
    for (final pe in parProduit.entries) {
      final votes = <String, int>{};
      for (final e in pe.value.values) {
        if (!ids.contains(e.magasinId)) continue;
        final s = secteurDeId[e.secteurId];
        final r = s == null ? null : rayonDe[s.rayonId];
        if (s == null || r == null) continue;
        final k = '${r.nom}|${s.nom}';
        votes[k] = (votes[k] ?? 0) + 1;
      }
      if (votes.isEmpty) continue;
      final choix = (votes.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key))).first.key;
      for (final m in mags) {
        final cible = parNom['${m.id}|$choix'];
        if (cible == null) continue;
        final e = pe.value[m.id];
        if (e == null) {
          emplacements.add(Emplacement(m.id, pe.key, cible.id));
          change = true;
        } else if (e.secteurId != cible.id) {
          e.secteurId = cible.id;
          change = true;
        }
      }
    }
    if (change) modifie();
    return change;
  }

  /// Produit présent dans une liste (en préparation, prête, en cours ou dans l'historique).
  bool produitUtilise(Produit p) => listes.any((l) => l.lignes.any((g) => g.produitId == p.id));

  void ajouterMarque(Produit p, String nom) {
    var m = _trouve(marques, (m) => m.nom.toLowerCase() == nom.toLowerCase());
    if (m == null) {
      m = Marque(nouvelId('b'), nom);
      marques.add(m);
    }
    if (!p.marqueIds.contains(m.id)) {
      p.marqueIds.add(m.id);
    }
    modifie();
  }

  void ajouterPackaging(Produit p, String libelle) {
    var k = _trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(nouvelId('k'), libelle);
      packagings.add(k);
    }
    if (!p.packagingIds.contains(k.id)) {
      p.packagingIds.add(k.id);
    }
    modifie();
  }

  // ------------------------------------------------------------ Suppression et corbeille

  /// Raison pour laquelle [objet] ne peut pas être supprimé, ou null.
  String? suppressionImpossible(Object objet) {
    if (objet is Magasin) {
      if (magasins.contains(objet) && magasins.length <= 1) return 'C\'est le seul magasin : créez-en un autre avant de le supprimer.';

    }
    if (objet is Produit && produitUtilise(objet)) return 'Ce produit est dans une liste : retirez-le d\'abord de la liste pour pouvoir le supprimer.';
    return null;
  }

  /// Ce qu'emporte la suppression de [objet], en clair (pour la confirmation).
  String consequences(Object objet) {
    String n(int x, String mot) => '$x $mot${x > 1 ? 's' : ''}';
    if (objet is Magasin) {
      if (estArchive(objet.id)) {
        return 'Ses ${n(listesArchivees(objet.id).length, 'course')} archivée${listesArchivees(objet.id).length > 1 ? 's' : ''} seront supprimées.';
      }
      final l = listes.where((x) => x.magasinId == objet.id && x.statut != StatutListe.terminee).length;
      return 'Avec ${n(parcours.where((p) => p.magasinId == objet.id).length, 'parcours')} '
          'et ${l == 0 ? 'aucune liste en cours' : '${n(l, 'liste')} en cours, effacée${l > 1 ? 's' : ''} aussi'}.'
          '${aUnHistorique(objet) ? ' Son historique de courses part dans Courses › Archives.' : ''}';
    }
    if (objet is Rayon) {
      return 'Avec ${n(secteursDu(objet.id).length, 'secteur')} ; ses produits deviennent « non placés » dans ce magasin.';
    }
    if (objet is Secteur) return 'Ses ${n(produitsDu(rayon(objet.rayonId)?.magasinId ?? '', objet.id).length, 'produit')} deviennent « non placés » dans ce magasin.';
    return '';
  }

  /// Supprime [objet] et ce qui en dépend ; le tout va dans la corbeille.
  void supprimer(Object objet) {
    final j = versJson();
    final retires = <String, List<dynamic>>{};
    void retirer(String collection, bool Function(Map o) test) {
      final l = (j[collection] as List).cast<Map>();
      final partis = l.where(test).toList();
      if (partis.isEmpty) return;
      (retires[collection] ??= []).addAll(partis);
      l.removeWhere(test);
    }

    void retirerSecteurs(Set<String> ids) {
      retirer('secteurs', (o) => ids.contains(o['id']));
      retirer('emplacements', (o) => ids.contains(o['secteurId']));
      // Les parcours gardent leurs autres étapes.
      for (final p in (j['parcours'] as List).cast<Map>()) {
        (p['etapes'] as List).removeWhere(ids.contains);
      }
    }

    late String type, libelle;
    if (objet is Magasin) {
      type = 'magasin';
      libelle = objet.nom;
      final rayonsM = rayonsDu(objet.id).map((r) => r.id).toSet();
      retirer('magasins', (o) => o['id'] == objet.id);
      retirer('rayons', (o) => rayonsM.contains(o['id']));
      retirerSecteurs(secteursDuMagasin(objet.id).map((s) => s.id).toSet());
      retirer('emplacements', (o) => o['magasinId'] == objet.id);
      retirer('parcours', (o) => o['magasinId'] == objet.id);
      final archive = estArchive(objet.id);
      retirer('listes', (o) => o['magasinId'] == objet.id && (archive || o['statut'] != StatutListe.terminee.name));
      if (archive) {
        retirer('historique', (o) => o['magasinId'] == objet.id);
      } else if (aUnHistorique(objet)) {
        // L'historique reste : le magasin passe dans les archives.
        (j['magasins'] as List).add({'id': objet.id, 'nom': objet.nom, 'enseigne': objet.enseigne, 'ville': objet.ville, 'archive': true});
        libelle = '${objet.nom} (historique gardé dans les archives)';
      }
    } else if (objet is Rayon) {
      type = 'rayon';
      libelle = '${objet.nom} · ${magasin(objet.magasinId)?.nom ?? ''}';
      retirer('rayons', (o) => o['id'] == objet.id);
      retirerSecteurs(secteursDu(objet.id).map((s) => s.id).toSet());
    } else if (objet is Secteur) {
      type = 'secteur';
      libelle = '${objet.nom} · ${rayon(objet.rayonId)?.nom ?? ''}';
      retirerSecteurs({objet.id});
    } else if (objet is Produit) {
      type = 'produit';
      libelle = objet.nom;
      retirer('produits', (o) => o['id'] == objet.id);
      retirer('emplacements', (o) => o['produitId'] == objet.id);
    } else if (objet is Liste) {
      type = 'liste';
      libelle = 'Liste ${nomListe(objet)} · ${objet.lignes.length} articles';
      retirer('listes', (o) => o['id'] == objet.id);
      retirer('historique', (o) => o['id'] == objet.id);
    } else if (objet is Parcours) {
      type = 'parcours';
      libelle = 'Parcours ${objet.nom} · ${magasin(objet.magasinId)?.nom ?? ''}';
      retirer('parcours', (o) => o['id'] == objet.id);
    } else {
      return;
    }
    (j['corbeille'] as List).insert(0, ElementCorbeille(nouvelId('cb'), type, libelle, DateTime.now(), retires).toJson());
    lire(j);
    enregistrer();
  }

  /// Ce qui manque pour restaurer [c] (son magasin, son rayon…), ou null.
  String? restaurationImpossible(ElementCorbeille c) {
    final contenu = c.contenu;
    final ids = <String>{for (final l in contenu.values) for (final o in (l as List).cast<Map>()) if (o['id'] != null) o['id'] as String};
    bool existe(String? id) => id == null || ids.contains(id) || magasin(id) != null || rayon(id) != null;
    for (final o in (contenu['rayons'] as List? ?? []).cast<Map>()) {
      if (!existe(o['magasinId'] as String?)) return 'Restaurez d\'abord le magasin de ce rayon.';
    }
    for (final o in (contenu['secteurs'] as List? ?? []).cast<Map>()) {
      if (!existe(o['rayonId'] as String?)) return 'Restaurez d\'abord le rayon de ce secteur.';
    }
    for (final o in [...(contenu['listes'] as List? ?? []), ...(contenu['parcours'] as List? ?? [])].cast<Map>()) {
      if (!existe(o['magasinId'] as String?)) return 'Restaurez d\'abord le magasin.';
    }
    return null;
  }

  /// Remet en place un élément de la corbeille.
  void restaurer(ElementCorbeille c) {
    if (restaurationImpossible(c) != null) return;
    final j = versJson();
    c.contenu.forEach((collection, objets) {
      final l = <dynamic>[...j[collection] as List];
      for (final o in objets as List) {
        final id = (o as Map)['id'];
        if (id == null || !l.any((x) => (x as Map)['id'] == id)) l.add(o);
      }
      j[collection] = l;
    });
    (j['corbeille'] as List).removeWhere((x) => (x as Map)['id'] == c.id);
    lire(j);
    enregistrer();
  }

  /// Vide la corbeille : ce qu'elle contient ne pourra plus être remis.
  void viderCorbeille() {
    corbeille.clear();
    modifie();
  }

  // ------------------------------------------------------------ Paramètres et historique

  void renommerFoyer(String nom) {
    foyerNom = nom;
    modifie();
  }

  void reglerPreliste(int presences, int sur) {
    prelistePresencesMin = presences;
    prelisteSur = sur;
    modifie();
  }

  void ajouterTypePromotion(String code, String nom, String exemple) {
    // Le code est unique (contrainte de la base) : « BON », « BON2 »…
    var unique = code;
    for (var i = 2; typesPromotion.any((t) => t.code == unique); i++) {
      unique = '$code$i';
    }
    typesPromotion.add(TypePromotion(nouvelId('tp'), unique, nom, exemple, ['libelle']));
    modifie();
  }

  /// Corrige le nom et le code court d'un type de promotion (le code reste unique).
  void modifierTypePromotion(TypePromotion t, {required String nom, required String code}) {
    if (nom.trim().isEmpty || code.trim().isEmpty) return;
    var unique = code.trim().toUpperCase();
    for (var i = 2; typesPromotion.any((x) => x.id != t.id && x.code == unique); i++) {
      unique = '${code.trim().toUpperCase()}$i';
    }
    t
      ..nom = nom.trim()
      ..code = unique;
    modifie();
  }

  /// Retire un type de promotion ; les listes déjà faites gardent leurs promotions.
  void supprimerTypePromotion(TypePromotion t) {
    typesPromotion.remove(t);
    modifie();
  }

  /// Courses terminées en instance : ni ticket joint, ni classées sans ticket. Elles restent dans l'onglet Courses.
  List<Course> get coursesEnInstance =>
      historique.where((c) => !estArchive(c.magasinId) && ticketDe(c.id) == null && !sansTicket.contains(c.id)).toList();
  bool enInstance(Course c) => ticketDe(c.id) == null && !sansTicket.contains(c.id);

  String? commentaire(Liste l) => commentaires[l.id];

  bool manquant(Liste l, String produitId) => manquants[l.id]?.contains(produitId) ?? false;

  /// Article absent des rayons (double appui sur sa case) : il est décoché et marqué manquant.
  void marquerManquant(Liste l, String produitId, bool oui) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (oui) {
      g.cocheLe = null;
      g.cochePar = null;
      (manquants[l.id] ??= {}).add(produitId);
    } else {
      manquants[l.id]?.remove(produitId);
      if (manquants[l.id]?.isEmpty ?? false) manquants.remove(l.id);
    }
    modifie();
  }

  bool estSimple(Liste l) => simples.contains(l.id);

  DateTime? datePrevue(Liste l) => DateTime.tryParse(datesPrevues[l.id] ?? '');

  void fixerDatePrevue(Liste l, DateTime d) {
    datesPrevues[l.id] = _iso(DateTime(d.year, d.month, d.day))!.substring(0, 10);
    modifie();
  }

  /// Nom proposé à la création : le magasin et le jour prévu des courses (« Intermarché · samedi 25/10 »).
  String nomPrevu(String magasinId, DateTime prevue) =>
      '${magasin(magasinId)?.nom ?? 'Liste'} · ${joursSemaine[prevue.weekday - 1]} ${jjmm(prevue)}';

  /// Deuxième ligne de l'en-tête d'une liste : date de création.
  String creeeLe(Liste l) => 'Créée le ${jjmm(l.dateCreation)} à ${heure(l.dateCreation)}';

  void marquerSimple(Liste l, bool oui) {
    if (oui ? simples.add(l.id) : simples.remove(l.id)) modifie();
  }

  /// Liste simple suivie par rayons et secteurs pendant les courses.
  bool estRangee(Liste l) => !nonRangees.contains(l.id);

  void ranger(Liste l, bool oui) {
    if (oui ? nonRangees.remove(l.id) : nonRangees.add(l.id)) modifie();
  }

  /// Liste montrée sans rayons ni secteurs pendant les courses : simple et non rangée.
  bool aPlat(Liste l) => estSimple(l) && !estRangee(l);

  void commenter(Liste l, String texte) {
    if (texte.trim().isEmpty) {
      commentaires.remove(l.id);
    } else {
      commentaires[l.id] = texte.trim();
    }
    modifie();
  }

  void classerSansTicket(Course c) {
    sansTicket.add(c.id);
    modifie();
  }

  /// Historique › « Remettre en terminées sans ticket » : la course revient dans l'onglet Courses.
  void remettreSansTicket(Course c) {
    sansTicket.remove(c.id);
    archivees.remove(c.id);
    modifie();
  }

  /// Course rangée dans les archives (magasin supprimé, ou passée de l'historique aux archives).
  bool estArchivee(Course c) => estArchive(c.magasinId) || archivees.contains(c.id);

  void archiver(Course c) {
    archivees.add(c.id);
    gardeesEnHistorique.remove(c.id);
    modifie();
  }

  void remettreEnHistorique(Course c) {
    archivees.remove(c.id);
    gardeesEnHistorique.add(c.id);
    modifie();
  }

  /// Courses archivées des magasins actifs, les plus récentes d'abord.
  List<Course> get coursesArchivees => historique.where((c) => !estArchive(c.magasinId) && archivees.contains(c.id)).toList()
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));

  void reglerDelaiHistorique(int mois) {
    delaiHistorique = mois;
    archiverAnciennes();
    modifie();
  }

  /// Les courses classées de plus de [delaiHistorique] mois passent dans les archives (sauf celles remises
  /// à la main dans l'historique). Rend vrai si quelque chose a changé.
  bool archiverAnciennes() {
    if (delaiHistorique <= 0) return false;
    final limite = DateTime.now().subtract(Duration(days: 30 * delaiHistorique));
    var change = false;
    for (final c in historique) {
      if (c.dateCourses.isBefore(limite) && !enInstance(c) && !gardeesEnHistorique.contains(c.id) && archivees.add(c.id)) change = true;
    }
    return change;
  }

  Membre ajouterMembre(String nom, String email) {
    final m = Membre(nouvelId('m'), nom.trim(), 'membre', false, email: email.trim());
    membres.add(m);
    modifie();
    return m;
  }

  void rattacherTicket(Ticket t, Course c) {
    t.listeId = c.id;
    modifie();
  }

  /// Ticket joint à une course (PDF fourni par l'application du magasin).
  Ticket ajouterTicket(Course c) {
    final t = Ticket(nouvelId('t'), c.id, c.magasinId, c.dateCourses, 0, 'photo');
    tickets.add(t);
    modifie();
    return t;
  }

  /// Ticket reçu sans course choisie : il attend dans Courses › Historique (« Tickets non rattachés »).
  /// (Source « photo » : la seule, avec « compte_magasin », que la base accepte.)
  Ticket ajouterTicketLibre(String magasinId) {
    final t = Ticket(nouvelId('t'), null, magasinId, DateTime.now(), 0, 'photo');
    tickets.add(t);
    modifie();
    return t;
  }

  String libelleTicket(Ticket t) => libellesTickets[t.id] ?? '';

  bool ticketImage(Ticket t) => ticketsImage.contains(t.id);

  void marquerTicketImage(Ticket t, bool image) {
    if (image ? !ticketsImage.add(t.id) : !ticketsImage.remove(t.id)) return;
    modifie();
  }

  void nommerTicket(Ticket t, String libelle) {
    libelle = libelle.trim();
    if (libelle.isEmpty ? libellesTickets.remove(t.id) == null : libellesTickets[t.id] == libelle) return;
    if (libelle.isNotEmpty) libellesTickets[t.id] = libelle;
    modifie();
  }

  void dateTicket(Ticket t, DateTime date) {
    if (t.date == date) return;
    t.date = date;
    modifie();
  }

  void montantTicket(Ticket t, double montant) {
    t.montant = montant;
    modifie();
  }

  void modifierEmail(Membre m, String email) {
    m.email = email.trim();
    modifie();
  }

  // ------------------------------------------------------------ Membres du foyer (26/10/2026)

  /// Membres visibles : tous sauf ceux qui ont été retirés du foyer (ou radiés, avant le 27/10/2026).
  /// Leurs noms restent sur leurs listes et leurs courses.
  List<Membre> get membresVisibles => [for (final m in membres) if (!statutsMembres.containsKey(m.id)) m];

  /// Cet appareil a été retiré du foyer par un autre membre.
  bool get moiExclu => statutsMembres.containsKey(moi.id);

  void renommerMembre(Membre m, String nom) {
    if (nom.trim().isEmpty) return;
    m.nomAffiche = nom.trim();
    modifie();
  }

  /// Retirer du foyer : le membre disparaît de la liste ; ses listes et ses courses restent.
  /// Son appareil cesse de partager ; il revient en saisissant le code de partage.
  void supprimerMembre(Membre m) {
    statutsMembres[m.id] = 's';
    modifie();
  }

  void reactiverMembre(Membre m) {
    if (statutsMembres.remove(m.id) != null) modifie();
  }

  /// Listes préparées par un membre, et ses courses.
  List<Liste> listesDuMembre(Membre m) => [for (final l in listes) if (l.membreId == m.id) l]
    ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
  List<Course> coursesDuMembre(Membre m) => [for (final c in historique) if (c.membreId == m.id) c]
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));

  /// Avant de rejoindre un foyer : les produits ajoutés et les listes non terminées de cet appareil,
  /// décrits par leurs noms (les identifiants changent d'un foyer à l'autre).
  Map<String, Object?> aReprendre() {
    String? rangementDe(Produit p) {
      final s = secteurCatalogue(p.id);
      return s == null ? null : '${rayon(s.rayonId)?.nom}/${s.nom}';
    }

    return {
      'produits': [
        for (final p in produitsAjoutes)
          {
            'nom': p.nom,
            'rangement': rangementDe(p),
            'marques': [for (final id in p.marqueIds) marque(id)?.nom],
            'formats': [for (final id in p.packagingIds) packaging(id)?.libelle],
          }
      ],
      'listes': [
        for (final l in listes)
          if (l.statut == StatutListe.enConstruction || l.statut == StatutListe.prete)
            {
              'nom': nomListe(l),
              'magasin': magasin(l.magasinId)?.nom,
              'prete': l.statut == StatutListe.prete,
              'lignes': [
                for (final g in l.lignes)
                  if (produit(g.produitId) case final p?)
                    {'produit': p.nom, 'quantite': g.quantite, 'consigne': g.consigne}
              ],
            }
      ],
    };
  }

  /// Une fois les données du foyer reçues : les produits et les listes gardés sont ajoutés au foyer.
  /// Rend vrai si c'est fait (le foyer a des magasins), faux s'il faut attendre encore.
  bool reprendre(Map<String, dynamic> a) {
    if (magasins.isEmpty) return false;
    for (final x in (a['produits'] as List? ?? const []).cast<Map>()) {
      final nom = x['nom'] as String;
      if (_trouve(produits, (p) => p.nom.toLowerCase() == nom.toLowerCase()) != null) continue;
      Secteur? s;
      final r = (x['rangement'] as String?)?.split('/');
      if (r != null && r.length == 2) {
        final ry = _trouve(rayonsCatalogue, (y) => y.nom == r[0]);
        if (ry != null) s = _trouve(secteursDu(ry.id), (y) => y.nom == r[1]);
      }
      final p = creerProduit(nom, secteur: s);
      for (final m in (x['marques'] as List? ?? const []).whereType<String>()) {
        p.marqueIds.add(marqueNommee(m).id);
      }
      for (final f in (x['formats'] as List? ?? const []).whereType<String>()) {
        p.packagingIds.add(_packagingNomme(f).id);
      }
    }
    for (final x in (a['listes'] as List? ?? const []).cast<Map>()) {
      final m = magasinNomme(x['magasin'] as String? ?? '') ?? magasins.first;
      final l = creerListe(m.id, []);
      l.nom = x['nom'] as String?;
      for (final g in (x['lignes'] as List? ?? const []).cast<Map>()) {
        final p = _trouve(produits, (p) => p.nom.toLowerCase() == (g['produit'] as String).toLowerCase());
        if (p == null) continue;
        ajouterLigne(l, p.id);
        final ligne = l.lignes.last;
        ligne.quantite = (g['quantite'] as num?)?.toInt() ?? 1;
        ligne.consigne = g['consigne'] as String?;
      }
      if (x['prete'] == true) l.statut = StatutListe.prete;
    }
    modifie();
    return true;
  }

  // ------------------------------------------------------------ Catalogue commun (26/10/2026)
  //
  // Tenu par l'éditeur (une seule personne), publié sur le serveur, ajouté à chaque foyer à la connexion.
  // Mêmes règles partout : identifiants calculés depuis les noms (deux appareils du foyer qui
  // l'ajoutent en même temps créent les mêmes objets) ; rien de ce que le foyer utilise n'est retiré.

  static String _cleNom(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüœ]+'), '-');

  /// Ajoute au foyer une version plus récente du catalogue commun. Rend les nouveautés (vide si rien).
  List<String> appliquerCatalogueCommun(Map<String, dynamic> j) {
    final version = (j['version'] as num? ?? 0).toInt();
    if (version <= versionCatalogueCommun || magasins.isEmpty) return const [];
    final lignes = <String>[];
    String bas(String t) => t.trim().toLowerCase();
    Produit? produitNomme(String nom) => _trouve(produits, (p) => bas(p.nom) == bas(nom));
    // Un même nom peut être dans plusieurs secteurs : le produit est alors repéré par son secteur.
    String? secteurDuProduit(Produit p) => secteurCatalogue(p.id)?.nom;
    Produit? produitDuSecteur(String nom, Object? secteur) =>
        secteur == null ? produitNomme(nom) : _trouve(produits, (p) => bas(p.nom) == bas(nom) && secteurDuProduit(p) == secteur);
    final places = <String, Set<String>>{};
    for (final rj in (j['rayons'] as List).cast<Map>()) {
      for (final sj in (rj['secteurs'] as List).cast<Map>()) {
        for (final pj in (sj['produits'] as List).cast<Map>()) {
          places.putIfAbsent(bas(pj['nom'] as String), () => {}).add('${rj['nom']}/${sj['nom']}');
        }
      }
    }
    final pris = <String>{};

    // 1. Noms changés par l'éditeur.
    var renommes = 0;
    for (final o in (j['renommes'] as List? ?? const []).cast<Map>()) {
      final ancien = o['ancien'] as String, nouveau = o['nouveau'] as String;
      switch (o['type']) {
        case 'rayon':
          if (_trouve(rayons, (r) => r.nom == nouveau) != null) continue;
          for (final r in rayons.where((r) => r.nom == ancien)) {
            r.nom = nouveau;
            renommes++;
          }
        case 'secteur':
          for (final x in secteurs.where((x) => x.nom == ancien && rayon(x.rayonId)?.nom == o['rayon'])) {
            if (_trouve(secteurs, (y) => y.rayonId == x.rayonId && y.nom == nouveau) != null) continue;
            x.nom = nouveau;
            renommes++;
          }
        case 'produit':
          final p = produitDuSecteur(ancien, o['secteur']);
          if (p != null && !estAjoute(p) && produitDuSecteur(nouveau, o['secteur']) == null) {
            p.nom = nouveau;
            renommes++;
          }
      }
    }

    // 2. Rayons, secteurs et produits.
    for (final rj in (j['rayons'] as List).cast<Map>()) {
      final rn = rj['nom'] as String;
      final rayonNeuf = _trouve(rayonsCatalogue, (r) => r.nom == rn) == null;
      if (rayonNeuf) lignes.add('Nouveau rayon : $rn');
      structurePerso.remove(rn);
      for (final m in magasins) {
        if (_trouve(rayons, (r) => r.magasinId == m.id && r.nom == rn) == null) rayons.add(Rayon('r-${m.id}-${_cleNom(rn)}', m.id, rn));
      }
      for (final sj in (rj['secteurs'] as List).cast<Map>()) {
        final sn = sj['nom'] as String;
        final ref = _trouve(rayonsCatalogue, (r) => r.nom == rn)!;
        if (!rayonNeuf && _trouve(secteursDu(ref.id), (x) => x.nom == sn) == null) lignes.add('Nouveau secteur : $rn › $sn');
        structurePerso.remove('$rn/$sn');
        for (final m in magasins) {
          final r = _trouve(rayons, (r) => r.magasinId == m.id && r.nom == rn)!;
          if (_trouve(secteurs, (x) => x.rayonId == r.id && x.nom == sn) == null) secteurs.add(Secteur('s-${r.id}-${_cleNom(sn)}', r.id, sn));
        }
        final secteurRef = _trouve(secteursDu(ref.id), (x) => x.nom == sn)!;
        for (final pj in (sj['produits'] as List).cast<Map>()) {
          final nom = pj['nom'] as String;
          final plusieurs = (places[bas(nom)]?.length ?? 0) > 1;
          String? place(Produit x) {
            final c = secteurCatalogue(x.id);
            return c == null ? null : '${rayon(c.rayonId)?.nom}/${c.nom}';
          }

          // Même nom dans plusieurs secteurs : celui de ce secteur, sinon un homonyme rangé ailleurs, sinon un nouveau.
          var p = !plusieurs
              ? produitNomme(nom)
              : _trouve(produits, (x) => bas(x.nom) == bas(nom) && secteurCatalogue(x.id)?.id == secteurRef.id) ??
                  _trouve(produits, (x) => bas(x.nom) == bas(nom) && !pris.contains(x.id) && !places[bas(nom)]!.contains(place(x)));
          if (p != null) {
            // Ajouté par le foyer, maintenant au catalogue commun : il en fait partie.
            produitsPerso.remove(p.id);
          } else {
            final id = 'pc-${_cleNom(nom)}';
            p = Produit(plusieurs && _trouve(produits, (x) => x.id == id) != null ? 'pc-${_cleNom(sn)}-${_cleNom(nom)}' : id, nom, [], [], 0);
            produits.add(p);
            for (final f in (pj['formats'] as List? ?? const []).cast<String>()) {
              p.packagingIds.add(_packagingNomme(f).id);
            }
            for (final mq in (pj['marques'] as List? ?? const []).cast<String>()) {
              p.marqueIds.add(marqueNommee(mq).id);
            }
            lignes.add('$sn : $nom');
          }
          pris.add(p.id);
          // Rangé là où le catalogue commun le met (un produit d'origine ne se déplace que par l'éditeur).
          final ici = secteurCatalogue(p.id);
          if (ici == null || (!estAjoute(p) && ici.id != secteurRef.id)) placer(ref.magasinId, p.id, secteurRef.id);
        }
      }
    }
    for (final e in (j['images'] as Map? ?? const {}).entries) {
      imagesChoisies.putIfAbsent(e.key as String, () => e.value as String);
    }

    // 3. Retirés par l'éditeur, s'ils ne servent pas au foyer.
    var retires = 0;
    for (final o in (j['retires'] as List? ?? const []).cast<Map>()) {
      final nom = o['nom'] as String;
      switch (o['type']) {
        case 'produit':
          final p = produitDuSecteur(nom, o['secteur']);
          if (p == null || estAjoute(p) || produitUtilise(p)) continue;
          produits.remove(p);
          emplacements.removeWhere((e) => e.produitId == p.id);
          retires++;
        case 'secteur':
          final ids = {
            for (final x in secteurs)
              if (x.nom == nom && rayon(x.rayonId)?.nom == o['rayon']) x.id
          };
          if (ids.isEmpty || emplacements.any((e) => ids.contains(e.secteurId))) continue;
          secteurs.removeWhere((x) => ids.contains(x.id));
          for (final pc in parcours) {
            pc.etapes.removeWhere(ids.contains);
          }
          retires++;
        case 'rayon':
          final ids = {for (final r in rayons) if (r.nom == nom) r.id};
          if (ids.isEmpty || secteurs.any((x) => ids.contains(x.rayonId))) continue;
          rayons.removeWhere((r) => ids.contains(r.id));
          retires++;
      }
    }
    if (renommes > 0) lignes.add('$renommes nom${renommes > 1 ? 's' : ''} corrigé${renommes > 1 ? 's' : ''}');
    if (retires > 0) lignes.add('$retires élément${retires > 1 ? 's' : ''} retiré${retires > 1 ? 's' : ''} du catalogue');
    versionCatalogueCommun = version;
    if (lignes.isNotEmpty) {
      nouveautesCatalogue = {'version': version, 'date': j['date'], 'lignes': lignes.take(200).toList(), 'total': lignes.length};
    }
    modifie();
    return lignes;
  }

  // ------------------------------------------------------------ Rayons et secteurs ajoutés (26/10/2026)

  bool rayonAjoute(Rayon r) => structurePerso.contains(r.nom);
  bool secteurAjoute(Secteur s) => structurePerso.contains('${rayon(s.rayonId)?.nom}/${s.nom}');

  /// Nouveau rayon, dans tous les magasins, avec un premier secteur du même nom.
  Rayon? ajouterRayonCatalogue(String nom) {
    final n = nom.trim();
    if (n.isEmpty || magasins.isEmpty) return null;
    if (_trouve(rayonsCatalogue, (r) => r.nom.toLowerCase() == n.toLowerCase()) != null) return null;
    for (final m in magasins) {
      final r = ajouterRayon(m.id, n);
      ajouterSecteur(r.id, n);
    }
    structurePerso
      ..add(n)
      ..add('$n/$n');
    modifie();
    return _trouve(rayonsCatalogue, (r) => r.nom == n);
  }

  /// Nouveau secteur dans le rayon [r], dans tous les magasins.
  Secteur? ajouterSecteurCatalogue(Rayon r, String nom) {
    final n = nom.trim();
    if (n.isEmpty) return null;
    if (_trouve(secteursDu(r.id), (s) => s.nom.toLowerCase() == n.toLowerCase()) != null) return null;
    for (final m in magasins) {
      final ry = _trouve(rayons, (x) => x.magasinId == m.id && x.nom == r.nom);
      if (ry != null) ajouterSecteur(ry.id, n);
    }
    structurePerso.add('${r.nom}/$n');
    modifie();
    return _trouve(secteursDu(r.id), (s) => s.nom == n);
  }

  /// Nouvel ordre des secteurs du rayon [r] (par leurs noms), dans tous les magasins.
  void ordonnerSecteursCatalogue(Rayon r, List<String> noms) {
    final rang = {for (var i = 0; i < noms.length; i++) noms[i]: i};
    for (final rid in {for (final x in rayons) if (x.nom == r.nom) x.id}) {
      // Les secteurs de ce rayon reprennent leurs places dans la liste, dans le nouvel ordre.
      final places = [for (var i = 0; i < secteurs.length; i++) if (secteurs[i].rayonId == rid) i];
      final cle = {for (var k = 0; k < places.length; k++) secteurs[places[k]]: rang[secteurs[places[k]].nom] ?? noms.length + k};
      final tries = [for (final i in places) secteurs[i]]..sort((a, b) => cle[a]!.compareTo(cle[b]!));
      for (var k = 0; k < places.length; k++) {
        secteurs[places[k]] = tries[k];
      }
    }
    modifie();
  }

  /// Renomme un rayon ajouté, dans tous les magasins.
  void renommerRayonCatalogue(Rayon r, String nom) {
    final n = nom.trim(), ancien = r.nom;
    if (n.isEmpty || n == ancien || !rayonAjoute(r)) return;
    for (final x in rayons.where((x) => x.nom == ancien)) {
      x.nom = n;
    }
    structurePerso = {for (final c in structurePerso) c == ancien ? n : (c.startsWith('$ancien/') ? '$n/${c.substring(ancien.length + 1)}' : c)};
    modifie();
  }

  /// Renomme un secteur ajouté, dans tous les magasins.
  void renommerSecteurCatalogue(Secteur s, String nom) {
    final n = nom.trim(), ancien = s.nom, rn = rayon(s.rayonId)?.nom ?? '';
    if (n.isEmpty || n == ancien || !secteurAjoute(s)) return;
    for (final x in secteurs.where((x) => x.nom == ancien && rayon(x.rayonId)?.nom == rn)) {
      x.nom = n;
    }
    structurePerso
      ..remove('$rn/$ancien')
      ..add('$rn/$n');
    modifie();
  }

  /// Un secteur ajouté et vide se supprime (dans tous les magasins) ; rend faux s'il a des produits.
  bool supprimerSecteurCatalogue(Secteur s) {
    if (!secteurAjoute(s) || produitsDuSecteur(s).isNotEmpty) return false;
    final rn = rayon(s.rayonId)?.nom ?? '';
    final ids = {for (final x in secteurs) if (x.nom == s.nom && rayon(x.rayonId)?.nom == rn) x.id};
    secteurs.removeWhere((x) => ids.contains(x.id));
    for (final p in parcours) {
      p.etapes.removeWhere(ids.contains);
    }
    structurePerso.remove('$rn/${s.nom}');
    modifie();
    return true;
  }

  /// Un rayon ajouté se supprime quand ses secteurs sont vides.
  bool supprimerRayonCatalogue(Rayon r) {
    if (!rayonAjoute(r) || secteursDu(r.id).any((s) => produitsDuSecteur(s).isNotEmpty)) return false;
    final ids = {for (final x in rayons) if (x.nom == r.nom) x.id};
    final sids = {for (final x in secteurs) if (ids.contains(x.rayonId)) x.id};
    secteurs.removeWhere((x) => sids.contains(x.id));
    rayons.removeWhere((x) => ids.contains(x.id));
    for (final p in parcours) {
      p.etapes.removeWhere(sids.contains);
    }
    structurePerso.removeWhere((c) => c == r.nom || c.startsWith('${r.nom}/'));
    modifie();
    return true;
  }

  void options({bool? parSecteurs, bool? envoiFoyer, bool? ajoutParRecherche, String? modePreparation}) {
    if (parSecteurs != null) this.parSecteurs = parSecteurs;
    if (envoiFoyer != null) this.envoiFoyer = envoiFoyer;
    if (ajoutParRecherche != null) this.ajoutParRecherche = ajoutParRecherche;
    if (modePreparation != null) this.modePreparation = modePreparation;
    modifie();
  }

  Packaging _packagingNomme(String libelle) {
    var k = _trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(nouvelId('k'), libelle);
      packagings.add(k);
    }
    return k;
  }

  /// Mise à jour : donne aux produits sans packaging les formats de vente du catalogue,
  /// et fait de tous ces formats les types de packaging (Paramètres), rangés par nature.
  Future<void> appliquerFormats({Map<String, dynamic>? catalogue, bool typesSeulement = false}) async {
    if (formatsAppliques) return;
    try {
      catalogue ??= await CatalogueType.lireJson();
    } catch (_) {
      return; // catalogue illisible : on réessaiera au prochain lancement
    }
    final parNom = <String, List<String>>{};
    final tous = <String>{};
    for (final r in (catalogue['rayons'] as List).cast<Map>()) {
      for (final s in (r['secteurs'] as List).cast<Map>()) {
        for (final p in (s['produits'] as List).cast<Map>()) {
          final f = (p['formats'] as List? ?? const []).cast<String>();
          parNom[(p['nom'] as String).toLowerCase()] = f;
          tous.addAll(f);
        }
      }
    }
    if (tous.isEmpty) return;
    for (final p in typesSeulement ? const <Produit>[] : produits) {
      if (p.packagingIds.isNotEmpty) continue;
      for (final f in parNom[p.nom.toLowerCase()] ?? const <String>[]) {
        p.packagingIds.add(_packagingNomme(f).id);
      }
    }
    for (final f in tous) {
      final k = _packagingNomme(f);
      if (!typesPackaging.contains(k.id)) typesPackaging.add(k.id);
    }
    // Types de départ (pack de 6 à 2) qu'aucun article n'utilise : retirés
    typesPackaging.removeWhere((id) =>
        RegExp(r'^pack de [2-6]$', caseSensitive: false).hasMatch(packaging(id)?.libelle ?? '') && nbProduitsAvecPackaging(id) == 0);
    trierTypesPackaging();
    formatsAppliques = true;
    modifie();
  }

  /// Types de mesure vides alors que les formats ont été appliqués : on les reprend du catalogue, sans toucher aux articles.
  Future<void> reparerTypesMesure({Map<String, dynamic>? catalogue}) async {
    if (typesMesure.isNotEmpty || !formatsAppliques) return;
    formatsAppliques = false;
    await appliquerFormats(catalogue: catalogue, typesSeulement: true);
    formatsAppliques = true;
  }

  /// Range les types : vente à l'unité, poids, volumes, lots, packs ; puis par quantité.
  void trierTypesPackaging() {
    (int, double) rang(String id) {
      final l = (packaging(id)?.libelle ?? '').toLowerCase();
      final n = double.tryParse(RegExp(r'\d+(?:,\d+)?').firstMatch(l)?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
      if (n == 0) return (0, 0);
      if (RegExp(r'\d\s*k?g\b').hasMatch(l)) return (1, l.contains('kg') ? n * 1000 : n);
      if (RegExp(r'\d\s*(c|m)?l\b').hasMatch(l)) return (2, l.contains('cl') ? n * 10 : (l.contains('ml') ? n : n * 1000));
      if (l.startsWith('pack')) return (4, n);
      return (3, n);
    }

    typesPackaging.sort((a, b) {
      final (ga, na) = rang(a);
      final (gb, nb) = rang(b);
      return ga != gb ? ga.compareTo(gb) : na.compareTo(nb);
    });
  }

  /// Nombre de produits qui proposent ce packaging.
  int nbProduitsAvecPackaging(String id) => produits.where((p) => p.packagingIds.contains(id)).length;

  List<Produit> produitsAvecPackaging(String id) => produits.where((p) => p.packagingIds.contains(id)).toList()
    ..sort((a, b) => a.nom.compareTo(b.nom));

  /// Corrige le libellé d'un format : tous les produits qui l'utilisent sont corrigés d'un coup.
  /// Si le nouveau libellé existe déjà, les deux formats sont fusionnés.
  void renommerMagasin(Magasin m, String nom) {
    if (nom.trim().isEmpty) return;
    m.nom = nom.trim();
    modifie();
  }

  // ------------------------------------------------------------ Catalogue des marques (28/10/2026)

  static const fichierMarques = 'assets/marques_catalogue.json';

  static const fichierMarquesDistributeur = 'assets/marques_distributeur.json';

  Future<void> chargerMarquesType() async {
    try {
      lireMarquesType(jsonDecode(await rootBundle.loadString(fichierMarques)) as Map<String, dynamic>);
      lireMarquesDistributeur(jsonDecode(await rootBundle.loadString(fichierMarquesDistributeur)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Catalogue des marques illisible : $e');
    }
  }

  void lireMarquesDistributeur(Map<String, dynamic> j) {
    marquesDistributeur = {
      for (final e in (j['enseignes'] as Map).entries)
        e.key as String: [
          for (final m in (e.value as List).cast<Map>())
            MarqueDistributeur(m['marque'] as String, m['categorie'] as String? ?? '', _ids(m['cibles']))
        ]
    };
  }

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

  /// Enseignes qui ont des marques distributeur.
  List<String> get enseignesMdd => marquesDistributeur.keys.toList();

  /// Enseigne d'un magasin pour ses marques distributeur : celle choisie, sinon reconnue dans son nom.
  String? enseigneDe(Magasin? m) {
    if (m == null || m.enseigne == '-') return null; // « Aucune » choisie
    if (marquesDistributeur.containsKey(m.enseigne)) return m.enseigne;
    final t = ' ${m.enseigne} ${m.nom} '.toLowerCase();
    for (final e in _motsEnseignes.entries) {
      if (e.value.any(t.contains)) return e.key;
    }
    return null;
  }

  void definirEnseigne(Magasin m, String enseigne) {
    m.enseigne = enseigne;
    modifie();
  }

  /// Marques distributeur de l'enseigne du magasin pour un article du secteur [s].
  List<String> marquesDistributeurPour(Magasin? m, Secteur? s) {
    final liste = marquesDistributeur[enseigneDe(m)] ?? const <MarqueDistributeur>[];
    final rayonNom = s == null ? null : rayon(s.rayonId)?.nom;
    final cle = s == null ? null : cleSecteur(s);
    return [
      for (final x in liste)
        if (x.cibles.any((c) => c == '*' || c == rayonNom || c == cle)) x.marque
    ];
  }

  void lireMarquesType(Map<String, dynamic> j) {
    marquesType = {for (final e in (j['secteurs'] as Map).entries) e.key as String: _ids(e.value)};
  }

  String cleSecteur(Secteur s) => '${rayon(s.rayonId)?.nom ?? ''}/${s.nom}';

  /// Marques d'un secteur : celles du catalogue des marques, celles ajoutées par le foyer et celles des
  /// produits du secteur, sans celles que le foyer a retirées ; par ordre alphabétique.
  List<String> marquesDuSecteur(Secteur s) {
    final cle = cleSecteur(s);
    final perso = marquesSecteurs[cle] ?? const {};
    final retirees = {for (final n in perso['-'] ?? const <String>[]) n.toLowerCase()};
    final vues = <String>{};
    final res = <String>[];
    void ajoute(String n) {
      if (retirees.contains(n.toLowerCase()) || !vues.add(n.toLowerCase())) return;
      res.add(n);
    }
    for (final n in marquesType[cle] ?? const <String>[]) {
      ajoute(n);
    }
    for (final n in perso['+'] ?? const <String>[]) {
      ajoute(n);
    }
    for (final p in produitsDuSecteur(s)) {
      for (final id in p.marqueIds) {
        if (marque(id)?.nom case final n?) ajoute(n);
      }
    }
    return res..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void ajouterMarqueSecteur(Secteur s, String nom) {
    final n = nom.trim();
    if (n.isEmpty) return;
    final perso = marquesSecteurs.putIfAbsent(cleSecteur(s), () => {});
    perso['-']?.removeWhere((x) => x.toLowerCase() == n.toLowerCase());
    if (!marquesDuSecteur(s).any((x) => x.toLowerCase() == n.toLowerCase())) (perso['+'] ??= []).add(n);
    modifie();
  }

  void retirerMarqueSecteur(Secteur s, String nom) {
    final perso = marquesSecteurs.putIfAbsent(cleSecteur(s), () => {});
    perso['+']?.removeWhere((x) => x.toLowerCase() == nom.toLowerCase());
    if (!(perso['-'] ?? []).any((x) => x.toLowerCase() == nom.toLowerCase())) (perso['-'] ??= []).add(nom);
    modifie();
  }

  /// Renomme une marque partout : dans les secteurs où elle figure, et ses produits (« Camembert Président »).
  void renommerMarqueCatalogue(String ancien, String nouveau) {
    final n = nouveau.trim();
    if (n.isEmpty || n == ancien) return;
    for (final s in [for (final r in rayonsCatalogue) ...secteursDu(r.id)]) {
      if (!marquesDuSecteur(s).any((x) => x.toLowerCase() == ancien.toLowerCase())) continue;
      retirerMarqueSecteur(s, ancien);
      ajouterMarqueSecteur(s, n);
    }
    if (_trouve(marques, (m) => m.nom.toLowerCase() == ancien.toLowerCase()) case final m?) renommerMarque(m, n);
    modifie();
  }

  /// Marques, par ordre alphabétique.
  List<Marque> get marquesTriees => [...marques]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  List<Produit> produitsDeMarque(String marqueId) => [for (final p in produits) if (p.marqueIds.contains(marqueId)) p];

  /// Renomme une marque ; si le nouveau nom est déjà celui d'une autre marque, les deux n'en font plus qu'une.
  void renommerMarque(Marque m, String nom) {
    final n = nom.trim();
    if (n.isEmpty || n == m.nom) return;
    // Les produits de la marque portent son nom (« Camembert Président ») : ils sont renommés aussi.
    final ancien = RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(m.nom)}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);
    for (final p in produitsDeMarque(m.id)) {
      p.nom = p.nom.replaceAll(ancien, n);
    }
    final autre = _trouve(marques, (x) => x.id != m.id && x.nom.toLowerCase() == n.toLowerCase());
    if (autre != null) {
      for (final p in produits) {
        if (p.marqueIds.remove(m.id) && !p.marqueIds.contains(autre.id)) p.marqueIds.add(autre.id);
      }
      for (final l in listes) {
        for (final g in l.lignes) {
          if (g.marqueId == m.id) g.marqueId = autre.id;
        }
      }
      marques.remove(m);
    } else {
      m.nom = n;
    }
    modifie();
  }

  /// Supprime une marque qu'aucun produit ne porte.
  bool supprimerMarque(Marque m) {
    if (produitsDeMarque(m.id).isNotEmpty || listes.any((l) => l.lignes.any((g) => g.marqueId == m.id))) return false;
    marques.remove(m);
    modifie();
    return true;
  }

  void renommerPackaging(String id, String libelle) {
    final k = packaging(id);
    if (k == null || libelle.trim().isEmpty) return;
    final autre = _trouve(packagings, (x) => x.id != id && x.libelle.toLowerCase() == libelle.trim().toLowerCase());
    if (autre != null) {
      fusionnerPackaging(id, autre.id);
      return;
    }
    k.libelle = libelle.trim();
    modifie();
  }

  /// Remplace partout le format [source] par [cible] (produits, lignes de liste, types) puis l'oublie.
  void fusionnerPackaging(String source, String cible) {
    if (source == cible || packaging(cible) == null) return;
    for (final p in produits) {
      final i = p.packagingIds.indexOf(source);
      if (i < 0) continue;
      if (p.packagingIds.contains(cible)) {
        p.packagingIds.removeAt(i);
      } else {
        p.packagingIds[i] = cible;
      }
    }
    for (final l in listes) {
      for (final g in l.lignes) {
        if (g.packagingId == source) g.packagingId = cible;
      }
    }
    final t = typesPackaging.indexOf(source);
    if (t >= 0) {
      if (typesPackaging.contains(cible)) {
        typesPackaging.removeAt(t);
      } else {
        typesPackaging[t] = cible;
      }
    }
    couleurs.remove('pack:$source');
    if (!listes.any((l) => l.lignes.any((g) => g.packagingId == source))) packagings.removeWhere((k) => k.id == source);
    modifie();
  }

  /// Retire un format de la liste des types et de tous les produits (les listes déjà faites le gardent).
  void supprimerPackaging(String id) {
    for (final p in produits) {
      p.packagingIds.remove(id);
    }
    typesPackaging.remove(id);
    couleurs.remove('pack:$id');
    modifie();
  }

  /// Formats les plus courants des autres produits du même secteur (produit sans format connu).
  List<String> formatsDuSecteur(String magasinId, String produitId, {int max = 8}) {
    final s = secteurDe(magasinId, produitId);
    if (s == null) return [];
    final n = <String, int>{};
    for (final e in emplacements.where((e) => e.magasinId == magasinId && e.secteurId == s.id)) {
      for (final k in produit(e.produitId)?.packagingIds ?? const <String>[]) {
        n[k] = (n[k] ?? 0) + 1;
      }
    }
    final ids = n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
    return ids.take(max).toList();
  }

  void ajouterTypePackaging(String libelle) {
    final k = _packagingNomme(libelle);
    if (!typesPackaging.contains(k.id)) typesPackaging.add(k.id);
    modifie();
  }

  void retirerTypePackaging(String id) {
    typesPackaging.remove(id);
    modifie();
  }

  /// Couleurs des pastilles (Gérer › Paramètres › Apparence) : une pour les promotions, une pour les mesures,
  /// une pour les packagings (lots). Par défaut : promotion en rouge, mesure et packaging en vert.
  static const couleurPromoDefaut = 0xFFE53935;
  static const couleurMesureDefaut = 0xFF43A047;
  static const couleurLotDefaut = 0xFF2E7D32;
  int get couleurPromotions => couleurs['promo'] ?? couleurPromoDefaut;
  int get couleurMesures => couleurs['mesure'] ?? couleurMesureDefaut;
  int get couleurLots => couleurs['lot'] ?? couleurLotDefaut;
  int? couleurPromo(String? typeId) => typeId == null ? null : couleurPromotions;
  int? couleurPack(String? packagingId) {
    final k = packaging(packagingId);
    if (k == null) return null;
    return mesureEtLot(k.libelle).$2 != null ? couleurLots : couleurMesures;
  }

  /// Types de mesure (poids, volume, à la pièce…) et types de packaging (lots), parmi les formats proposés.
  List<String> get typesMesure => [for (final id in typesPackaging) if (!estLot(packaging(id)?.libelle ?? '')) id];
  List<String> get typesLot => [for (final id in typesPackaging) if (estLot(packaging(id)?.libelle ?? '')) id];

  /// Les packagings sont surtout des lots de 2 à 10 : ceux qui manquent sont ajoutés une fois.
  void completerLots() {
    if (lotsCompletes) return;
    for (var n = 2; n <= 10; n++) {
      final existe = typesLot.any((id) => RegExp('\\b$n\\b').hasMatch(packaging(id)?.libelle ?? ''));
      if (!existe) ajouterTypePackaging('Lot de $n');
    }
    lotsCompletes = true;
    trierTypesPackaging();
    modifie();
  }

  void choisirCouleur(String cle, int? couleur) {
    if (couleur == null) {
      couleurs.remove(cle);
    } else {
      couleurs[cle] = couleur;
    }
    modifie();
  }

  void choisirApparence(String nom) {
    apparence = nom;
    modifie();
  }

  void reglerDelaiArchives(int mois) {
    delaiArchives = mois;
    purgerArchives();
    modifie();
  }

  /// Courses des magasins archivés.
  List<Liste> listesArchivees(String magasinId) => listes.where((l) => l.magasinId == magasinId).toList()
    ..sort((a, b) => dateCourses(b).compareTo(dateCourses(a)));

  /// Supprime les archives plus anciennes que le délai réglé (rien si « jamais ») ; rend vrai si quelque chose est parti.
  bool purgerArchives() {
    if (delaiArchives <= 0) return false;
    final limite = DateTime.now().subtract(Duration(days: 30 * delaiArchives));
    final ids = {
      for (final m in magasinsArchives)
        for (final c in historique.where((c) => c.magasinId == m.id && c.dateCourses.isBefore(limite))) c.id,
      for (final c in historique.where((c) => archivees.contains(c.id) && c.dateCourses.isBefore(limite))) c.id,
    };
    if (ids.isEmpty) return false;
    archivees.removeAll(ids);
    listes.removeWhere((l) => ids.contains(l.id));
    historique.removeWhere((c) => ids.contains(c.id));
    for (final m in [...magasinsArchives]) {
      if (!historique.any((c) => c.magasinId == m.id) && !listes.any((l) => l.magasinId == m.id)) magasinsArchives.remove(m);
    }
    return true;
  }

  /// Un magasin supprimé qui a un historique part dans les archives ; ses listes non terminées sont effacées.
  bool aUnHistorique(Magasin m) =>
      historique.any((c) => c.magasinId == m.id) || listes.any((l) => l.magasinId == m.id && l.statut == StatutListe.terminee);

  void restaurerMagasin(Magasin m) {
    magasinsArchives.remove(m);
    if (!magasins.contains(m)) magasins.add(m);
    modifie();
  }

  /// Image choisie pour un rayon ou un secteur (clé : voir images_choisies.dart) ; null = image automatique.
  void choisirImage(String cle, String? picto) {
    if (picto == null) {
      imagesChoisies.remove(cle);
    } else {
      imagesChoisies[cle] = picto;
    }
    modifie();
  }
}

extension _Let<T> on T {
  void let(void Function(T) f) => f(this);
}
