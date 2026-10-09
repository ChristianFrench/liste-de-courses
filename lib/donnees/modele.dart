import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// Données de la maquette v0.2 (« Données maquette.json »), gardées dans un fichier JSON local
// pour que l'interruption survive à la fermeture. Chaque action est enregistrée immédiatement.

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
  Membre(this.id, this.nomAffiche, this.role, this.moi);
  final String id;
  final String nomAffiche;
  final String role;
  final bool moi;
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
  final String libelle;
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
  LigneListe({required this.produitId, this.marqueId, this.packagingId, this.quantite = 1, this.promotion, this.cochePar, this.cocheLe});
  final String produitId;
  String? marqueId;
  String? packagingId;
  int quantite;
  PromotionLigne? promotion;
  String? cochePar;
  DateTime? cocheLe;
  bool get coche => cocheLe != null;

  Map<String, dynamic> toJson() => {
        'produitId': produitId,
        if (marqueId != null) 'marqueId': marqueId,
        if (packagingId != null) 'packagingId': packagingId,
        'quantite': quantite,
        if (promotion != null) 'promotion': promotion!.toJson(),
        if (cocheLe != null) 'coche': {'par': cochePar, 'le': _iso(cocheLe)},
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
  });
  final String id;
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
  final double montant;
  final String source;
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
  static const String fichierLocal = 'etat_maquette.json';

  /// Désactive l'enregistrement sur disque (tests).
  bool enregistrementActif = true;

  late Map<String, dynamic> _brut; // champs conservés tels quels (description, écarts…)
  String foyerId = 'f1';
  String foyerNom = '';
  DateTime foyerCreation = DateTime(2026, 10, 1);
  List<Membre> membres = [];
  String invitationCode = '';
  DateTime invitationExpiration = DateTime(2026, 10, 16);
  int prelistePresencesMin = 3;
  int prelisteSur = 6;
  List<TypePromotion> typesPromotion = [];
  List<Magasin> magasins = [];
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
  String regleFrequence = '';

  int _compteur = 0;
  String nouvelId(String prefixe) => '$prefixe-${DateTime.now().millisecondsSinceEpoch}-${++_compteur}';

  // ------------------------------------------------------------ Chargement et enregistrement

  Future<File?> _fichier() async {
    if (!enregistrementActif) return null;
    try {
      final d = await getApplicationSupportDirectory();
      if (!d.existsSync()) d.createSync(recursive: true);
      return File('${d.path}${Platform.pathSeparator}$fichierLocal');
    } catch (_) {
      return null;
    }
  }

  /// Fichier local s'il existe, sinon données de démonstration.
  Future<void> charger() async {
    final f = await _fichier();
    if (f != null && f.existsSync()) {
      try {
        lire(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        return;
      } catch (_) {}
    }
    lire(jsonDecode(await rootBundle.loadString(fichierDonnees)) as Map<String, dynamic>);
    await enregistrer();
  }

  /// Revient aux données de démonstration.
  Future<void> reinitialiser() async {
    lire(jsonDecode(await rootBundle.loadString(fichierDonnees)) as Map<String, dynamic>);
    await enregistrer();
  }

  Future<void> enregistrer() async {
    final f = await _fichier();
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode(versJson()));
    } catch (_) {}
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
        Membre(m['id'] as String, m['nomAffiche'] as String, m['role'] as String, m['moi'] as bool? ?? false)
    ];
    final inv = j['invitation'] as Map;
    invitationCode = inv['code'] as String;
    invitationExpiration = _date(inv['expiration']) ?? invitationExpiration;
    final pl = (j['parametres'] as Map?)?['preliste'] as Map?;
    prelistePresencesMin = (pl?['presencesMin'] as num? ?? 3).toInt();
    prelisteSur = (pl?['sur'] as num? ?? 6).toInt();
    typesPromotion = [
      for (final t in (j['typesPromotion'] as List).cast<Map>())
        TypePromotion(t['id'] as String, t['code'] as String, t['nom'] as String, t['exemple'] as String? ?? '',
            _ids(t['parametres']))
    ];
    magasins = [
      for (final m in (j['magasins'] as List).cast<Map>())
        Magasin(m['id'] as String, m['nom'] as String, m['enseigne'] as String? ?? '', m['ville'] as String? ?? '')
    ];
    rayons = [
      for (final r in (j['rayons'] as List).cast<Map>()) Rayon(r['id'] as String, r['magasinId'] as String, r['nom'] as String)
    ];
    secteurs = [
      for (final s in (j['secteurs'] as List).cast<Map>()) Secteur(s['id'] as String, s['rayonId'] as String, s['nom'] as String)
    ];
    marques = [for (final m in (j['marques'] as List).cast<Map>()) Marque(m['id'] as String, m['nom'] as String)];
    packagings = [for (final k in (j['packagings'] as List).cast<Map>()) Packaging(k['id'] as String, k['libelle'] as String)];
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
        'membres': [for (final m in membres) {'id': m.id, 'nomAffiche': m.nomAffiche, 'role': m.role, 'moi': m.moi}],
        'invitation': {'code': invitationCode, 'expiration': _iso(invitationExpiration)!.substring(0, 10)},
        'parametres': {
          'preliste': {'presencesMin': prelistePresencesMin, 'sur': prelisteSur}
        },
        'typesPromotion': [for (final t in typesPromotion) t.toJson()],
        'magasins': [for (final m in magasins) {'id': m.id, 'nom': m.nom, 'enseigne': m.enseigne, 'ville': m.ville}],
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
  Magasin? magasin(String? id) => _trouve(magasins, (m) => m.id == id);
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
  String complement(LigneListe? g, Produit p, {bool marque = true}) {
    final m = <String>[];
    final mq = this.marque(g?.marqueId);
    if (marque && mq != null) m.add(mq.nom);
    final k = packaging(g?.packagingId) ?? (p.packagingIds.isNotEmpty ? packaging(p.packagingIds.first) : null);
    if (k != null) m.add(k.libelle.toLowerCase());
    return m.join(' · ');
  }

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
    _toucheConstruction(l);
    modifie();
  }

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

  Liste creerListe(String magasinId, List<LigneListe> lignes) {
    final l = Liste(
      id: nouvelId('l'),
      magasinId: magasinId,
      statut: StatutListe.enConstruction,
      dateCreation: DateTime.now(),
      lignes: lignes,
      modifieePar: moi.id,
      modifieeLe: DateTime.now(),
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

  void etapeCourante(Liste l, String etapeId) {
    l.repriseSecteurId = etapeId;
    modifie();
  }

  void interrompreCourses(Liste l) {
    l.interrompueLe = DateTime.now();
    modifie();
  }

  Course terminerCourses(Liste l) {
    final c = Course(nouvelId('h'), l.magasinId, DateTime.now(), l.membreId ?? moi.id, l.nbCoches);
    historique.insert(0, c);
    for (final g in l.lignes) {
      if (g.coche) produit(g.produitId)?.nbUtilisations++;
    }
    l.statut = StatutListe.terminee;
    l.interrompueLe = null;
    modifie();
    return c;
  }

  // ------------------------------------------------------------ Magasin et catalogue

  Magasin creerMagasin(String nom) {
    final m = Magasin(nouvelId('mg'), nom, '', '');
    magasins.add(m);
    modifie();
    return m;
  }

  Rayon ajouterRayon(String magasinId, String nom) {
    final r = Rayon(nouvelId('r'), magasinId, nom);
    rayons.add(r);
    modifie();
    return r;
  }

  Secteur ajouterSecteur(String rayonId, String nom) {
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
    typesPromotion.add(TypePromotion(nouvelId('tp'), code, nom, exemple, ['libelle']));
    modifie();
  }

  void rattacherTicket(Ticket t, Course c) {
    t.listeId = c.id;
    modifie();
  }
}
