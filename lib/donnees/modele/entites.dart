part of '../modele.dart';

// Objets du foyer : magasins, rayons, secteurs, produits, listes, courses… (sortis de modele.dart le 16/11/2026).

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

/// Les rayons, secteurs et emplacements sont communs à tous les magasins (12/11/2026) : ils portent ce
/// magasin fictif, jamais montré (une ligne « magasin » cachée dans la base, pour ses liens).
const String magasinCommun = 'commun';

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

  /// 03/11/2026 (Aristide) : la valeur courte montrée et saisie sur la ligne, après le code (« PX 2,50 € »,
  /// « LOT 3+1 », « −% 30 % »).
  String get valeur {
    final v = parametres['valeur'];
    if (v is String) return v;
    String f(num n) => n == n.roundToDouble() ? '${n.toInt()}' : n.toString().replaceAll('.', ',');
    switch (type) {
      case 'prix':
        final n = parametres['prix'] as num?;
        return n == null ? '' : euros(n.toDouble());
      case 'lot':
        final a = parametres['quantiteAchetee'] as num?, b = parametres['quantiteOfferte'] as num?;
        return a == null ? '' : '${f(a)}+${f(b ?? 0)}';
      case 'remise':
      case 'fidelite':
        final pc = parametres['pourcentage'] as num?, m = parametres['montant'] as num?;
        return pc != null ? '${f(pc)} %' : (m != null ? euros(m.toDouble()) : '');
      case 'prixGlobal':
        final q = parametres['quantiteMinimale'] as num?;
        return q == null ? '' : 'par ${f(q)}';
      default:
        return '';
    }
  }

  /// Promotion tirée de la valeur tapée sur la ligne : « 2,50 » (prix), « 3+1 » (lot), « 30 » ou « 30 % »
  /// ou « 1 € » (remise), « 2 » (lot pour promo), sinon le texte tel quel.
  static PromotionLigne depuisValeur(String type, String saisie, {String nomType = 'Promotion'}) {
    final t = saisie.trim();
    num? n(String x) => num.tryParse(x.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '.'));
    String f(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toString().replaceAll('.', ',');
    final p = <String, dynamic>{};
    var libelle = t.isEmpty ? nomType : '$nomType $t';
    var valeur = t;
    switch (type) {
      case 'prix':
        final v = n(t);
        if (v != null) {
          p['prix'] = v;
          valeur = euros(v.toDouble());
          libelle = 'Prix promo $valeur';
        }
      case 'lot':
        final m = RegExp(r'(\d+)\D+(\d+)').firstMatch(t);
        if (m != null) {
          final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
          p['quantiteAchetee'] = a;
          p['quantiteOfferte'] = b;
          valeur = '$a+$b';
          libelle = '$a dont $b gratuit${b > 1 ? 's' : ''}';
        }
      case 'remise':
      case 'fidelite':
        final v = n(t);
        if (v != null) {
          final montant = t.contains('€');
          p[montant ? 'montant' : 'pourcentage'] = v;
          valeur = montant ? euros(v.toDouble()) : '${f(v)} %';
          libelle = '${type == 'remise' ? 'Remise' : 'Fidélité'} de $valeur';
        }
      case 'prixGlobal':
        final v = n(t);
        if (v != null) {
          p['quantiteMinimale'] = v;
          valeur = 'par ${f(v)}';
          libelle = 'Par ${f(v)}';
        }
    }
    p['valeur'] = valeur;
    return PromotionLigne(type, p, libelle);
  }

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
  String magasinId;
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
