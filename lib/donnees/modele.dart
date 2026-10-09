import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Date du jour figée pour la maquette : les promotions factices restent ainsi
/// visibles quel que soit le jour de l'essai.
final DateTime dateMaquette = DateTime(2026, 10, 9);

DateTime _date(dynamic v) => DateTime.parse(v as String);
List<String> _ids(dynamic v) => v == null ? <String>[] : List<String>.from(v as List);
String? _texte(dynamic v) => v as String?;

String jjmmaaaa(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String jjmm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
String euros(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

// ---------------------------------------------------------------------------
// Entités (mêmes noms que le document « Modèle de données »)
// ---------------------------------------------------------------------------

class Foyer {
  Foyer({required this.id, required this.nom, required this.dateCreation});
  final String id;
  String nom;
  final DateTime dateCreation;
}

class Membre {
  Membre({required this.id, required this.nomAffiche, required this.role, required this.moi});
  final String id;
  final String nomAffiche;
  final String role;
  final bool moi;

  String get roleAffiche => role == 'administrateur' ? 'Administrateur' : 'Membre';
  String get initiales {
    final mots = nomAffiche.split(' ');
    if (mots.length >= 2) return '${mots.first[0]}${mots.last[0]}'.toUpperCase();
    return nomAffiche.substring(0, nomAffiche.length < 2 ? nomAffiche.length : 2).toUpperCase();
  }
}

class Invitation {
  Invitation({required this.code, required this.expiration});
  final String code;
  final DateTime expiration;
}

class Magasin {
  Magasin({required this.id, required this.nom, required this.enseigne, required this.ville});
  final String id;
  final String nom;
  final String enseigne;
  final String ville;
}

class Rayon {
  Rayon({required this.id, required this.magasinId, required this.nom});
  final String id;
  final String magasinId;
  String nom;
}

class Secteur {
  Secteur({required this.id, required this.rayonId, required this.nom});
  final String id;
  final String rayonId;
  String nom;
}

class Marque {
  Marque({required this.id, required this.nom});
  final String id;
  final String nom;
}

class Packaging {
  Packaging({required this.id, required this.libelle});
  final String id;
  final String libelle;
}

class Produit {
  Produit({
    required this.id,
    required this.nom,
    required this.marqueIds,
    required this.packagingIds,
    required this.nbUtilisations,
  });
  final String id;
  String nom;
  final List<String> marqueIds;
  final List<String> packagingIds;
  int nbUtilisations;
}

class Emplacement {
  Emplacement({required this.magasinId, required this.produitId, required this.secteurId});
  final String magasinId;
  final String produitId;
  String secteurId;
}

/// Les six types de promotion du modèle de données.
enum TypePromo { lot, prixGlobal, remise, packagingSpecial, fidelite, autre }

extension TypePromoTexte on TypePromo {
  String get code {
    switch (this) {
      case TypePromo.lot:
        return 'LOT';
      case TypePromo.prixGlobal:
        return '2=€';
      case TypePromo.remise:
        return '−%';
      case TypePromo.packagingSpecial:
        return 'PK';
      case TypePromo.fidelite:
        return 'FID';
      case TypePromo.autre:
        return '?';
    }
  }

  String get nom {
    switch (this) {
      case TypePromo.lot:
        return 'Lot';
      case TypePromo.prixGlobal:
        return 'Prix global';
      case TypePromo.remise:
        return 'Remise';
      case TypePromo.packagingSpecial:
        return 'Packaging';
      case TypePromo.fidelite:
        return 'Fidélité';
      case TypePromo.autre:
        return 'Autre';
    }
  }

  static TypePromo depuis(String v) =>
      TypePromo.values.firstWhere((t) => t.name == v, orElse: () => TypePromo.autre);
}

class Promotion {
  Promotion({
    required this.id,
    required this.magasinId,
    required this.produitId,
    required this.type,
    required this.parametres,
    required this.libelle,
    required this.debut,
    required this.fin,
    this.packagingId,
    this.marqueId,
  });
  final String id;
  final String magasinId;
  final String produitId;
  final String? packagingId;
  final String? marqueId;
  final TypePromo type;
  final Map<String, dynamic> parametres;
  final String libelle;
  final DateTime debut;
  final DateTime fin;

  bool get active => !dateMaquette.isBefore(debut) && !dateMaquette.isAfter(fin);

  /// Quantité nécessaire pour bénéficier de la promotion (règle 11), ou null.
  int? get quantiteRequise {
    switch (type) {
      case TypePromo.lot:
        return (parametres['quantiteAchetee'] as num?)?.toInt();
      case TypePromo.prixGlobal:
        return (parametres['quantiteMinimale'] as num?)?.toInt();
      default:
        return null;
    }
  }
}

class Parcours {
  Parcours({
    required this.id,
    required this.magasinId,
    required this.membreId,
    required this.nom,
    required this.parDefaut,
    required this.etapes,
  });
  final String id;
  final String magasinId;
  final String membreId;
  String nom;
  bool parDefaut;

  /// Identifiants de secteurs, dans l'ordre de passage (règles 6 et 7).
  List<String> etapes;
}

class LigneListe {
  LigneListe({
    required this.produitId,
    this.marqueId,
    this.packagingId,
    this.quantite = 1,
    this.promotionId,
  });
  final String produitId;
  String? marqueId;
  String? packagingId;
  int quantite;
  String? promotionId;
}

enum StatutListe { enConstruction, prete }

class Liste {
  Liste({
    required this.id,
    required this.magasinId,
    required this.statut,
    required this.dateCreation,
    required this.lignes,
    required this.auteurId,
    this.parcoursId,
  });
  final String id;
  final String magasinId;
  StatutListe statut;
  String? parcoursId;
  final DateTime dateCreation;
  final List<LigneListe> lignes;
  String auteurId;
  DateTime? derniereModification;
}

class Course {
  Course({
    required this.id,
    required this.magasinId,
    required this.dateCourses,
    required this.membreId,
    required this.nbArticles,
    this.ticketSource,
    this.montant,
  });
  final String id;
  final String magasinId;
  final DateTime dateCourses;
  final String membreId;
  final int nbArticles;
  final String? ticketSource;
  final double? montant;
}

/// Courses en train d'être faites (état local de la maquette).
class CoursesEnCours {
  CoursesEnCours({required this.listeId, required this.membreId, required this.parcoursId});
  final String listeId;
  String membreId;
  String? parcoursId;
  final Set<String> coches = <String>{};
  int etape = 0;
}

/// Une étape des courses : un secteur (ou « Non placé » si [secteur] est nul)
/// et les lignes de la liste qui s'y trouvent.
class Etape {
  Etape(this.secteur, this.lignes);
  final Secteur? secteur;
  final List<LigneListe> lignes;
  bool get nonPlace => secteur == null;
}

// ---------------------------------------------------------------------------
// État de la maquette : données chargées depuis le fichier JSON, en mémoire
// ---------------------------------------------------------------------------

class Etat extends ChangeNotifier {
  Etat._();
  static final Etat instance = Etat._();

  static const String fichierDonnees = 'assets/donnees_maquette.json';

  bool charge = false;
  late Foyer foyer;
  List<Membre> membres = [];
  late Invitation invitation;
  List<Magasin> magasins = [];
  List<Rayon> rayons = [];
  List<Secteur> secteurs = [];
  List<Marque> marques = [];
  List<Packaging> packagings = [];
  List<Produit> produits = [];
  List<Emplacement> emplacements = [];
  List<Promotion> promotions = [];
  List<Parcours> parcours = [];
  List<Liste> listes = [];
  List<Course> historique = [];
  Map<String, Map<String, int>> frequences = {};
  String regleFrequence = '';

  CoursesEnCours? courses;
  bool horsReseau = false;

  int _compteur = 0;
  String nouvelId(String prefixe) {
    _compteur++;
    return '$prefixe-n$_compteur';
  }

  Future<void> charger() async {
    final texte = await rootBundle.loadString(fichierDonnees);
    lire(jsonDecode(texte) as Map<String, dynamic>);
  }

  void lire(Map<String, dynamic> j) {
    final f = j['foyer'] as Map<String, dynamic>;
    foyer = Foyer(id: f['id'] as String, nom: f['nom'] as String, dateCreation: _date(f['dateCreation']));
    membres = [
      for (final m in (j['membres'] as List).cast<Map<String, dynamic>>())
        Membre(
          id: m['id'] as String,
          nomAffiche: m['nomAffiche'] as String,
          role: m['role'] as String,
          moi: m['moi'] as bool? ?? false,
        )
    ];
    final inv = j['invitation'] as Map<String, dynamic>;
    invitation = Invitation(code: inv['code'] as String, expiration: _date(inv['expiration']));
    magasins = [
      for (final m in (j['magasins'] as List).cast<Map<String, dynamic>>())
        Magasin(
          id: m['id'] as String,
          nom: m['nom'] as String,
          enseigne: m['enseigne'] as String? ?? '',
          ville: m['ville'] as String? ?? '',
        )
    ];
    rayons = [
      for (final r in (j['rayons'] as List).cast<Map<String, dynamic>>())
        Rayon(id: r['id'] as String, magasinId: r['magasinId'] as String, nom: r['nom'] as String)
    ];
    secteurs = [
      for (final s in (j['secteurs'] as List).cast<Map<String, dynamic>>())
        Secteur(id: s['id'] as String, rayonId: s['rayonId'] as String, nom: s['nom'] as String)
    ];
    marques = [
      for (final m in (j['marques'] as List).cast<Map<String, dynamic>>())
        Marque(id: m['id'] as String, nom: m['nom'] as String)
    ];
    packagings = [
      for (final k in (j['packagings'] as List).cast<Map<String, dynamic>>())
        Packaging(id: k['id'] as String, libelle: k['libelle'] as String)
    ];
    produits = [
      for (final p in (j['produits'] as List).cast<Map<String, dynamic>>())
        Produit(
          id: p['id'] as String,
          nom: p['nom'] as String,
          marqueIds: _ids(p['marqueIds']),
          packagingIds: _ids(p['packagingIds']),
          nbUtilisations: (p['nbUtilisations'] as num? ?? 0).toInt(),
        )
    ];
    emplacements = [
      for (final e in (j['emplacements'] as List).cast<Map<String, dynamic>>())
        Emplacement(
          magasinId: e['magasinId'] as String,
          produitId: e['produitId'] as String,
          secteurId: e['secteurId'] as String,
        )
    ];
    promotions = [
      for (final p in (j['promotions'] as List).cast<Map<String, dynamic>>())
        Promotion(
          id: p['id'] as String,
          magasinId: p['magasinId'] as String,
          produitId: p['produitId'] as String,
          packagingId: _texte(p['packagingId']),
          marqueId: _texte(p['marqueId']),
          type: TypePromoTexte.depuis(p['type'] as String),
          parametres: Map<String, dynamic>.from(p['parametres'] as Map? ?? {}),
          libelle: p['libelle'] as String? ?? '',
          debut: _date(p['debut']),
          fin: _date(p['fin']),
        )
    ];
    parcours = [
      for (final p in (j['parcours'] as List).cast<Map<String, dynamic>>())
        Parcours(
          id: p['id'] as String,
          magasinId: p['magasinId'] as String,
          membreId: p['membreId'] as String,
          nom: p['nom'] as String,
          parDefaut: p['parDefaut'] as bool? ?? false,
          etapes: _ids(p['etapes']),
        )
    ];
    final auteurParDefaut = membres.isEmpty ? '' : membres.first.id;
    listes = [
      for (final l in (j['listes'] as List).cast<Map<String, dynamic>>())
        Liste(
          id: l['id'] as String,
          magasinId: l['magasinId'] as String,
          statut: l['statut'] == 'prete' ? StatutListe.prete : StatutListe.enConstruction,
          parcoursId: _texte(l['parcoursId']),
          dateCreation: _date(l['dateCreation']),
          auteurId: l['auteurId'] as String? ?? auteurParDefaut,
          lignes: [
            for (final g in (l['lignes'] as List).cast<Map<String, dynamic>>())
              LigneListe(
                produitId: g['produitId'] as String,
                marqueId: _texte(g['marqueId']),
                packagingId: _texte(g['packagingId']),
                quantite: (g['quantite'] as num? ?? 1).toInt(),
                promotionId: _texte(g['promotionId']),
              )
          ],
        )
    ];
    historique = [
      for (final h in (j['historique'] as List).cast<Map<String, dynamic>>())
        Course(
          id: h['id'] as String,
          magasinId: h['magasinId'] as String,
          dateCourses: _date(h['dateCourses']),
          membreId: h['membreId'] as String,
          nbArticles: (h['nbArticles'] as num? ?? 0).toInt(),
          ticketSource: (h['ticket'] as Map?)?['source'] as String?,
          montant: ((h['ticket'] as Map?)?['montant'] as num?)?.toDouble(),
        )
    ];
    historique.sort((a, b) => b.dateCourses.compareTo(a.dateCourses));
    frequences = {};
    final fr = j['frequencesPreliste'] as Map<String, dynamic>? ?? {};
    fr.forEach((cle, valeur) {
      if (cle == '_regle') {
        regleFrequence = valeur as String;
      } else {
        frequences[cle] = (valeur as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    });
    courses = null;
    horsReseau = false;
    charge = true;
    notifyListeners();
  }

  void signaler() => notifyListeners();

  // ---------------------------------------------------------------- Recherche

  Membre get moi => membres.firstWhere((m) => m.moi, orElse: () => membres.first);
  Membre? membre(String? id) => _trouve(membres, (m) => m.id == id);
  Magasin? magasin(String? id) => _trouve(magasins, (m) => m.id == id);
  Rayon? rayon(String? id) => _trouve(rayons, (r) => r.id == id);
  Secteur? secteur(String? id) => _trouve(secteurs, (s) => s.id == id);
  Marque? marque(String? id) => _trouve(marques, (m) => m.id == id);
  Packaging? packaging(String? id) => _trouve(packagings, (k) => k.id == id);
  Produit? produit(String? id) => _trouve(produits, (p) => p.id == id);
  Liste? liste(String? id) => _trouve(listes, (l) => l.id == id);
  Parcours? unParcours(String? id) => _trouve(parcours, (p) => p.id == id);
  Promotion? promotion(String? id) => _trouve(promotions, (p) => p.id == id);

  static T? _trouve<T>(List<T> liste, bool Function(T) test) {
    for (final e in liste) {
      if (test(e)) return e;
    }
    return null;
  }

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

  void placer(String magasinId, String produitId, String secteurId) {
    final e = _trouve(emplacements, (e) => e.magasinId == magasinId && e.produitId == produitId);
    if (e == null) {
      emplacements.add(Emplacement(magasinId: magasinId, produitId: produitId, secteurId: secteurId));
    } else {
      e.secteurId = secteurId;
    }
    notifyListeners();
  }

  /// Produits placés dans un secteur pour un magasin.
  List<Produit> produitsDu(String magasinId, String secteurId) => [
        for (final e in emplacements)
          if (e.magasinId == magasinId && e.secteurId == secteurId) produit(e.produitId)
      ].whereType<Produit>().toList();

  List<Promotion> promotionsDe(String produitId, {String? magasinId}) => promotions
      .where((p) => p.produitId == produitId && p.active && (magasinId == null || p.magasinId == magasinId))
      .toList();

  Promotion? promotionActive(String magasinId, String produitId) {
    final l = promotionsDe(produitId, magasinId: magasinId);
    return l.isEmpty ? null : l.first;
  }

  /// Complément affiché en gris : marque et packaging.
  String complement(LigneListe? ligne, Produit p) {
    final morceaux = <String>[];
    final m = marque(ligne?.marqueId);
    if (m != null) morceaux.add(m.nom);
    final k = packaging(ligne?.packagingId) ??
        (p.packagingIds.isNotEmpty ? packaging(p.packagingIds.first) : null);
    if (k != null) morceaux.add(k.libelle.toLowerCase());
    return morceaux.join(' · ');
  }

  // ---------------------------------------------------------------- Listes

  List<Liste> get listesEnConstruction =>
      listes.where((l) => l.statut == StatutListe.enConstruction).toList();

  LigneListe? ligne(Liste l, String produitId) => _trouve(l.lignes, (g) => g.produitId == produitId);

  int nbArticles(Liste l) => l.lignes.length;

  void _modifiee(Liste l) {
    l.derniereModification = DateTime.now();
    l.auteurId = moi.id;
  }

  void basculer(Liste l, String produitId) {
    final g = ligne(l, produitId);
    if (g == null) {
      ajouterLigne(l, produitId);
    } else {
      l.lignes.remove(g);
      _modifiee(l);
      notifyListeners();
    }
  }

  void ajouterLigne(Liste l, String produitId, {int quantite = 1}) {
    if (ligne(l, produitId) != null) return;
    final p = produit(produitId);
    final promo = promotionActive(l.magasinId, produitId);
    l.lignes.add(LigneListe(
      produitId: produitId,
      packagingId: promo?.packagingId ?? (p != null && p.packagingIds.isNotEmpty ? p.packagingIds.first : null),
      marqueId: promo?.marqueId,
      quantite: quantite,
      promotionId: promo?.id,
    ));
    _modifiee(l);
    notifyListeners();
  }

  void quantite(Liste l, String produitId, int q) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (q <= 0) {
      l.lignes.remove(g);
    } else {
      g.quantite = q;
    }
    _modifiee(l);
    notifyListeners();
  }

  /// Quantité manquante pour la promotion (règle 11) : renvoie la quantité requise
  /// si la ligne n'y suffit pas, sinon null.
  int? quantiteInsuffisante(Liste l, LigneListe g) {
    final promo = promotion(g.promotionId) ?? promotionActive(l.magasinId, g.produitId);
    final requise = promo?.quantiteRequise;
    if (requise == null) return null;
    return g.quantite < requise ? requise : null;
  }

  int nbDansRayon(Liste l, String rayonId) =>
      l.lignes.where((g) => rayonDe(l.magasinId, g.produitId)?.id == rayonId).length;
  int nbDansSecteur(Liste l, String secteurId) =>
      l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == secteurId).length;

  Liste creerListe(String magasinId, List<LigneListe> lignes) {
    final l = Liste(
      id: nouvelId('l'),
      magasinId: magasinId,
      statut: StatutListe.enConstruction,
      dateCreation: dateMaquette,
      lignes: lignes,
      auteurId: moi.id,
    );
    l.derniereModification = DateTime.now();
    listes.add(l);
    notifyListeners();
    return l;
  }

  void listePrete(Liste l) {
    l.statut = StatutListe.prete;
    _modifiee(l);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Préliste

  /// Nombre de présences du produit dans les 6 dernières courses du magasin.
  Map<String, int> frequencesDu(String magasinId) => frequences[magasinId] ?? const {};

  static const int seuilPreliste = 3;

  List<LigneListe> preliste(String magasinId) {
    final f = frequencesDu(magasinId);
    return [
      for (final e in f.entries)
        if (e.value >= seuilPreliste)
          LigneListe(
            produitId: e.key,
            packagingId: (produit(e.key)?.packagingIds.isNotEmpty ?? false) ? produit(e.key)!.packagingIds.first : null,
            promotionId: promotionActive(magasinId, e.key)?.id,
          )
    ];
  }

  // ---------------------------------------------------------------- Parcours

  List<Parcours> parcoursDe(String magasinId, String membreId) =>
      parcours.where((p) => p.magasinId == magasinId && p.membreId == membreId).toList();

  Parcours? parcoursParDefaut(String magasinId, String membreId) {
    final l = parcoursDe(magasinId, membreId);
    if (l.isEmpty) return null;
    return l.firstWhere((p) => p.parDefaut, orElse: () => l.first);
  }

  void definirParDefaut(Parcours p) {
    for (final autre in parcoursDe(p.magasinId, p.membreId)) {
      autre.parDefaut = identical(autre, p);
    }
    notifyListeners();
  }

  /// Étapes des courses : secteurs contenant au moins un article, dans l'ordre du
  /// parcours (sans parcours : ordre des rayons du magasin), puis « Non placé ».
  List<Etape> etapes(Liste l, String? parcoursId) {
    final p = unParcours(parcoursId);
    final ordre = <String>[...(p?.etapes ?? const <String>[])];
    for (final s in secteursDuMagasin(l.magasinId)) {
      if (!ordre.contains(s.id)) ordre.add(s.id);
    }
    final resultat = <Etape>[];
    for (final sid in ordre) {
      final lignes = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == sid).toList();
      final s = secteur(sid);
      if (lignes.isNotEmpty && s != null) resultat.add(Etape(s, lignes));
    }
    final nonPlaces = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId) == null).toList();
    if (nonPlaces.isNotEmpty) resultat.add(Etape(null, nonPlaces));
    return resultat;
  }

  // ---------------------------------------------------------------- Courses

  void demarrerCourses(Liste l, String membreId, String? parcoursId) {
    l.parcoursId = parcoursId;
    courses = CoursesEnCours(listeId: l.id, membreId: membreId, parcoursId: parcoursId);
    notifyListeners();
  }

  Liste? get listeEnCours => liste(courses?.listeId);

  void cocher(String produitId) {
    final c = courses;
    if (c == null) return;
    if (!c.coches.remove(produitId)) c.coches.add(produitId);
    notifyListeners();
  }

  void allerEtape(int i) {
    courses?.etape = i;
    notifyListeners();
  }

  void changerParcours(String? parcoursId) {
    final c = courses;
    if (c == null) return;
    c.parcoursId = parcoursId;
    c.etape = 0;
    listeEnCours?.parcoursId = parcoursId;
    notifyListeners();
  }

  void terminerCourses() {
    final c = courses;
    final l = listeEnCours;
    if (c == null || l == null) return;
    historique.insert(
      0,
      Course(
        id: nouvelId('h'),
        magasinId: l.magasinId,
        dateCourses: dateMaquette,
        membreId: c.membreId,
        nbArticles: c.coches.length,
      ),
    );
    for (final g in l.lignes) {
      if (c.coches.contains(g.produitId)) produit(g.produitId)?.nbUtilisations++;
    }
    listes.remove(l);
    courses = null;
    notifyListeners();
  }

  void basculerReseau() {
    horsReseau = !horsReseau;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Catalogue

  Produit creerProduit(String nom) {
    final p = Produit(id: nouvelId('p'), nom: nom, marqueIds: [], packagingIds: [], nbUtilisations: 0);
    produits.add(p);
    notifyListeners();
    return p;
  }

  bool produitUtilise(Produit p) =>
      p.nbUtilisations > 0 || listes.any((l) => l.lignes.any((g) => g.produitId == p.id));

  void ajouterMarque(Produit p, String nom) {
    var m = _trouve(marques, (m) => m.nom.toLowerCase() == nom.toLowerCase());
    if (m == null) {
      m = Marque(id: nouvelId('b'), nom: nom);
      marques.add(m);
    }
    if (!p.marqueIds.contains(m.id)) p.marqueIds.add(m.id);
    notifyListeners();
  }

  void ajouterPackaging(Produit p, String libelle) {
    var k = _trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(id: nouvelId('k'), libelle: libelle);
      packagings.add(k);
    }
    if (!p.packagingIds.contains(k.id)) p.packagingIds.add(k.id);
    notifyListeners();
  }

  void ajouterPromotion(Promotion p) {
    promotions.add(p);
    notifyListeners();
  }

  Parcours creerParcours(String magasinId, String membreId, String nom) {
    final p = Parcours(
      id: nouvelId('pc'),
      magasinId: magasinId,
      membreId: membreId,
      nom: nom,
      parDefaut: parcoursDe(magasinId, membreId).isEmpty,
      etapes: secteursDuMagasin(magasinId).map((s) => s.id).toList(),
    );
    parcours.add(p);
    notifyListeners();
    return p;
  }

  Rayon ajouterRayon(String magasinId, String nom) {
    final r = Rayon(id: nouvelId('r'), magasinId: magasinId, nom: nom);
    rayons.add(r);
    notifyListeners();
    return r;
  }

  Secteur ajouterSecteur(String rayonId, String nom) {
    final s = Secteur(id: nouvelId('s'), rayonId: rayonId, nom: nom);
    secteurs.add(s);
    notifyListeners();
    return s;
  }
}
