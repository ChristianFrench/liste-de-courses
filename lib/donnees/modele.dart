import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

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
  final String nomAffiche;
  final String role;
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
  final String code;
  final String nom;
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
  final String enseigne;
  final String ville;
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
  final String nom;
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
  Course(this.id, this.magasinId, this.dateCourses, this.membreId, this.nbArticles);
  final String id;
  final String magasinId;
  final DateTime dateCourses;
  final String membreId;
  final int nbArticles;
}

class Ticket {
  Ticket(this.id, this.listeId, this.magasinId, this.date, this.montant, this.source);
  final String id;
  String? listeId; // course de l'historique, null = non rattaché
  final String magasinId;
  final DateTime date;
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
  static const String fichierAncien = 'etat_maquette.json'; // maquette 0.6 et avant
  static const String baseFoyer = 'liste_de_courses.db';
  static const String baseDemo = 'demonstration.db';

  /// Désactive l'enregistrement sur disque (tests).
  bool enregistrementActif = true;

  /// Mode démonstration : données fictives, gardées dans une base à part.
  bool modeDemo = false;

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
  List<TypePromotion> typesPromotion = [];
  List<Magasin> magasins = []; // magasins actifs

  /// Magasins supprimés qui avaient un historique : gardés dans Gérer › Archives avec leurs courses.
  List<Magasin> magasinsArchives = [];

  /// Couleurs choisies (Paramètres) : « promo:<type> » et « pack:<packaging> » → 0xAARRGGBB.
  Map<String, int> couleurs = {};
  /// Courses pendant lesquelles on enregistre le parcours (identifiants de listes).
  Set<String> apprentissage = {};
  /// Parcours issus de l'apprentissage : de nouvelles courses enregistrées les complètent.
  Set<String> parcoursAppris = {};

  /// Types de packaging proposés partout (Paramètres) : pack de 6, de 5…
  List<String> typesPackaging = [];

  /// Délai de suppression automatique des archives, en mois (0 : jamais).
  int delaiArchives = 0;

  /// Formats de vente du catalogue déjà appliqués aux produits (une seule fois, à la mise à jour).
  bool formatsAppliques = false;

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
  String regleFrequence = '';

  int _compteur = 0;
  String nouvelId(String prefixe) => '$prefixe-${DateTime.now().millisecondsSinceEpoch}-${++_compteur}';

  // ------------------------------------------------------------ Chargement et enregistrement

  Directory? _dossier;
  Stockage? _foyer;
  Stockage? _demo;
  Stockage? get _actif => modeDemo ? _demo : _foyer;

  String _chemin(String nom) => '${_dossier!.path}${Platform.pathSeparator}$nom';

  Future<Map<String, dynamic>> _donneesDemo() async =>
      jsonDecode(await rootBundle.loadString(fichierDonnees)) as Map<String, dynamic>;

  /// Base du foyer (vraies données) et, en mode démonstration, base de démonstration.
  Future<void> charger() async {
    if (enregistrementActif) {
      try {
        final d = await getApplicationSupportDirectory();
        if (!d.existsSync()) d.createSync(recursive: true);
        _dossier = d;
        _foyer = Stockage.ouvrir(_chemin(baseFoyer));
        modeDemo = _foyer!.reglage('mode_demo') == '1';
        _reprendreAncienFichier();
        await _ouvrirActif();
        return;
      } catch (e) {
        debugPrint('Base locale indisponible : $e');
        _foyer = _demo = null;
      }
    }
    lire(await _donneesDemo());
  }

  /// Le fichier de la maquette 0.6 contient des essais sur les données fictives :
  /// il devient le contenu de la base de démonstration.
  void _reprendreAncienFichier() {
    final f = File(_chemin(fichierAncien));
    if (!f.existsSync()) return;
    try {
      final demo = _demo ??= Stockage.ouvrir(_chemin(baseDemo));
      if (demo.vide) demo.ecrire(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      f.renameSync('${f.path}.ancien');
    } catch (e) {
      debugPrint('Reprise du fichier $fichierAncien impossible : $e');
    }
  }

  Future<void> _ouvrirActif() async {
    if (modeDemo) _demo ??= Stockage.ouvrir(_chemin(baseDemo));
    final s = _actif!;
    if (s.vide) {
      lire(modeDemo ? await _donneesDemo() : _depart(await _donneesDemo()));
      if (!modeDemo) await appliquerModele(magasins.first, tailleComplete);
      s.ecrire(versJson());
    } else {
      lire(s.lire());
    }
    await appliquerFormats();
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
        {'id': nouvelId('mg'), 'nom': 'Mon magasin', 'enseigne': '', 'ville': ''}
      ],
      for (final cle in ['rayons', 'secteurs', 'marques', 'packagings', 'produits', 'emplacements', 'parcours', 'listes', 'historique', 'tickets'])
        cle: <dynamic>[],
      'frequencesPreliste': {'_regle': (demo['frequencesPreliste'] as Map?)?['_regle'] ?? ''},
    };
  }

  /// Passe des vraies données à la démonstration, ou l'inverse. Rien n'est effacé.
  Future<void> basculerDemo(bool oui) async {
    if (oui == modeDemo) return;
    modeDemo = oui;
    if (_foyer == null) {
      lire(oui ? await _donneesDemo() : _depart(await _donneesDemo()));
      return;
    }
    _foyer!.definirReglage('mode_demo', oui ? '1' : '0');
    await _ouvrirActif();
  }

  /// Mode démonstration : revient aux données de démonstration d'origine.
  Future<void> reinitialiser() async {
    if (!modeDemo) return;
    lire(await _donneesDemo());
    await enregistrer();
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
    } catch (e) {
      debugPrint('Enregistrement impossible : $e');
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
    couleurs = {for (final e in (options?['couleurs'] as Map? ?? {}).entries) e.key as String: (e.value as num).toInt()};
    apprentissage = _ids(options?['apprentissage']).toSet();
    parcoursAppris = _ids(options?['parcoursAppris']).toSet();
    typesPackaging = _ids(options?['typesPackaging']);
    delaiArchives = (options?['delaiArchives'] as num? ?? 0).toInt();
    apparence = options?['apparence'] as String?;
    formatsAppliques = options?['formats'] == 1;
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
            h['membreId'] as String, (h['nbArticles'] as num? ?? 0).toInt())
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
            if (imagesChoisies.isNotEmpty) 'images': imagesChoisies,
            if (couleurs.isNotEmpty) 'couleurs': couleurs,
            if (apprentissage.isNotEmpty) 'apprentissage': apprentissage.toList(),
            if (parcoursAppris.isNotEmpty) 'parcoursAppris': parcoursAppris.toList(),
            'typesPackaging': typesPackaging,
            if (magasinsArchives.isNotEmpty) 'magasinsArchives': [for (final m in magasinsArchives) m.id],
            if (delaiArchives > 0) 'delaiArchives': delaiArchives,
            if (apparence != null) 'apparence': apparence,
            if (formatsAppliques) 'formats': 1,
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
            {'id': h.id, 'magasinId': h.magasinId, 'dateCourses': _iso(h.dateCourses)!.substring(0, 10), 'membreId': h.membreId, 'nbArticles': h.nbArticles}
        ],
        'tickets': [
          for (final t in tickets)
            {'id': t.id, 'listeId': t.listeId, 'magasinId': t.magasinId, 'date': _iso(t.date)!.substring(0, 10), 'montant': t.montant, 'source': t.source}
        ],
        'frequencesPreliste': {'_regle': regleFrequence, ...frequences},
        'corbeille': [for (final c in corbeille) c.toJson()],
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

  void definirConsigne(Liste l, String produitId, String? consigne) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.consigne = (consigne == null || consigne.trim().isEmpty) ? null : consigne.trim();
    _toucheConstruction(l);
    modifie();
  }

  /// Nom affiché d'une liste : celui donné par l'utilisateur, sinon « magasin du jj/mm/aaaa ».
  String nomListe(Liste l) => (l.nom != null && l.nom!.isNotEmpty) ? l.nom! : nomParDefaut(l.magasinId, l.dateCreation);
  String nomParDefaut(String magasinId, DateTime d) => '${magasin(magasinId)?.nom ?? 'Liste'} du ${jjmmaaaa(d)}';

  void renommerListe(Liste l, String nom) {
    l.nom = nom.trim().isEmpty ? null : nom.trim();
    modifie();
  }

  /// Une liste prête revient en préparation.
  void remettreEnPreparation(Liste l) {
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
    final c = Course(l.id, l.magasinId, DateTime.now(), l.membreId ?? moi.id, l.nbCoches);
    historique.insert(0, c);
    retenirParcours(l);
    l.statut = StatutListe.terminee;
    l.interrompueLe = null;
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

  void placer(String magasinId, String produitId, String secteurId) {
    final e = _trouve(emplacements, (e) => e.magasinId == magasinId && e.produitId == produitId);
    if (e == null) {
      emplacements.add(Emplacement(magasinId, produitId, secteurId));
    } else {
      e.secteurId = secteurId;
    }
    modifie();
  }

  Produit creerProduit(String nom) {
    final p = Produit(nouvelId('p'), nom, [], [], 0);
    produits.add(p);
    modifie();
    return p;
  }

  bool produitUtilise(Produit p) => p.nbUtilisations > 0 || listes.any((l) => l.lignes.any((g) => g.produitId == p.id));

  void ajouterMarque(Produit p, String nom) {
    var m = _trouve(marques, (m) => m.nom.toLowerCase() == nom.toLowerCase());
    if (m == null) {
      m = Marque(nouvelId('b'), nom);
      marques.add(m);
    }
    if (!p.marqueIds.contains(m.id)) p.marqueIds.add(m.id);
    modifie();
  }

  void ajouterPackaging(Produit p, String libelle) {
    var k = _trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(nouvelId('k'), libelle);
      packagings.add(k);
    }
    if (!p.packagingIds.contains(k.id)) p.packagingIds.add(k.id);
    modifie();
  }

  // ------------------------------------------------------------ Suppression et corbeille

  /// Raison pour laquelle [objet] ne peut pas être supprimé, ou null.
  String? suppressionImpossible(Object objet) {
    if (objet is Magasin) {
      if (magasins.contains(objet) && magasins.length <= 1) return 'C\'est le seul magasin : créez-en un autre avant de le supprimer.';

    }
    if (objet is Produit && produitUtilise(objet)) return 'Ce produit a déjà servi dans une liste : il ne peut pas être supprimé.';
    return null;
  }

  /// Ce qu'emporte la suppression de [objet], en clair (pour la confirmation).
  String consequences(Object objet) {
    String n(int x, String mot) => '$x $mot${x > 1 ? 's' : ''}';
    if (objet is Magasin) {
      final r = rayonsDu(objet.id);
      if (estArchive(objet.id)) {
        return 'Ses ${n(listesArchivees(objet.id).length, 'course')} archivée${listesArchivees(objet.id).length > 1 ? 's' : ''} seront supprimées.';
      }
      final l = listes.where((x) => x.magasinId == objet.id && x.statut != StatutListe.terminee).length;
      return 'Avec ${n(r.length, 'rayon')}, ${n(secteursDuMagasin(objet.id).length, 'secteur')}, '
          'l\'emplacement des produits, ${n(parcours.where((p) => p.magasinId == objet.id).length, 'parcours')} '
          'et ${l == 0 ? 'aucune liste en cours' : '${n(l, 'liste')} en cours, effacée${l > 1 ? 's' : ''} aussi'}.'
          '${aUnHistorique(objet) ? ' Son historique de courses part dans Gérer › Archives.' : ''}';
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

  void montantTicket(Ticket t, double montant) {
    t.montant = montant;
    modifie();
  }

  void modifierEmail(Membre m, String email) {
    m.email = email.trim();
    modifie();
  }

  void options({bool? parSecteurs, bool? envoiFoyer}) {
    if (parSecteurs != null) this.parSecteurs = parSecteurs;
    if (envoiFoyer != null) this.envoiFoyer = envoiFoyer;
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
  Future<void> appliquerFormats({Map<String, dynamic>? catalogue}) async {
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
    for (final p in produits) {
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

  /// Couleur d'un type de promotion ou de packaging, ou null.
  // Sans couleur choisie : couleurs chaudes pour les promotions selon le rang du type ; une seule couleur pour tous les packagings.
  static const _chaudes = [0xFFE53935, 0xFFFB8C00, 0xFFEC407A, 0xFFFDD835, 0xFF8E24AA, 0xFF8D6E63];
  static const _froides = [0xFF1E88E5, 0xFF00ACC1, 0xFF43A047, 0xFF3949AB, 0xFF00897B, 0xFF7CB342];
  int _rang(String id, List<String> ids) => (ids.indexOf(id) < 0 ? id.hashCode : ids.indexOf(id)).abs();
  int? couleurPromo(String? typeId) => typeId == null
      ? null
      : couleurs['promo:$typeId'] ?? _chaudes[_rang(typeId, [for (final t in typesPromotion) t.id]) % _chaudes.length];
  int? couleurPack(String? packagingId) => packagingId == null
      ? null
      : couleurs['pack:$packagingId'] ?? _froides.first;

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

  /// Supprime les archives plus anciennes que le délai réglé (rien si « jamais »).
  void purgerArchives() {
    if (delaiArchives <= 0) return;
    final limite = DateTime.now().subtract(Duration(days: 30 * delaiArchives));
    final ids = {
      for (final m in magasinsArchives)
        for (final c in historique.where((c) => c.magasinId == m.id && c.dateCourses.isBefore(limite))) c.id
    };
    if (ids.isEmpty) return;
    listes.removeWhere((l) => ids.contains(l.id));
    historique.removeWhere((c) => ids.contains(c.id));
    for (final m in [...magasinsArchives]) {
      if (!historique.any((c) => c.magasinId == m.id) && !listes.any((l) => l.magasinId == m.id)) magasinsArchives.remove(m);
    }
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
