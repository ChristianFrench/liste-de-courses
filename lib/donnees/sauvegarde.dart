import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'chiffrement.dart';
import 'modele.dart';
import 'sauvegarde_depot_io.dart' if (dart.library.js_interop) 'sauvegarde_depot_web.dart' as depot;
import 'synchro.dart';

export 'sauvegarde_depot_io.dart' if (dart.library.js_interop) 'sauvegarde_depot_web.dart' show dossierSauvegardesEssai;

// Sauvegarde (décidée avec Aristide, faite le 03/11/2026).
// - Une copie n'est faite qu'à un jalon, et seulement si les données ont changé depuis la copie précédente :
//   liste prête ou liste type enregistrée, courses terminées, sortie du catalogue, changement dans le foyer
//   (membre, magasin, code), catalogue commun reçu, et juste avant un geste lourd (restaurer, rejoindre un foyer).
// - Quatre copies gardées : celles des 3 derniers jalons, et une « ancre » d'au moins un mois quand il y en a une.
// - Chiffrées avec le code du foyer (un foyer seul n'en a pas : sa copie est seulement compressée).
// - Jamais la clé de signature ni le brouillon de l'éditeur du catalogue commun : ils sont dans les réglages
//   de l'appareil, pas dans les données copiées.

/// Une copie de sauvegarde, d'après son en-tête (lisible sans le code).
class CopieSauvegarde {
  CopieSauvegarde(this.nom, this.entete, this.contenu);
  final String nom;
  final Map<String, dynamic> entete;
  final String contenu;

  DateTime get le => DateTime.tryParse(entete['le'] as String? ?? '') ?? DateTime(2000);
  String get jalon => entete['jalon'] as String? ?? '';
  String get foyer => entete['foyer'] as String? ?? '';
  bool get chiffree => entete['chiffre'] == true;
  bool get ancre => nom.contains('-ancre-');
  String get empreinte => entete['empreinte'] as String? ?? '';
  Map<String, dynamic> get compte => (entete['compte'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// « 12 listes · 1 690 articles · 34 courses »
  String get resume {
    final c = compte;
    String n(String k, String mot) {
      final v = (c[k] as num?)?.toInt() ?? 0;
      return '$v $mot${v > 1 ? 's' : ''}';
    }

    return [n('listes', 'liste'), n('produits', 'article'), n('courses', 'course')].join(' · ');
  }

  static CopieSauvegarde? lire(String nom, String contenu) {
    try {
      final j = jsonDecode(contenu) as Map<String, dynamic>;
      if (j['emplettes'] != 1) return null;
      return CopieSauvegarde(nom, j, contenu);
    } catch (_) {
      return null;
    }
  }
}

class Sauvegarde {
  Sauvegarde._();
  static final instance = Sauvegarde._();

  /// Faux pendant les essais (et la démonstration) : aucun jalon ne fait de copie.
  static bool actif = false;

  /// Nombre de copies des derniers jalons, en plus de l'ancre.
  static const derniers = 3;

  /// Âge minimal de l'ancre.
  static const ageAncre = Duration(days: 30);

  Timer? _attente;
  Future<void>? _enCours;

  /// Un jalon est passé : la copie part un peu après (plusieurs jalons rapprochés n'en font qu'une).
  void jalon(String raison) {
    if (!actif) return;
    _attente?.cancel();
    _attente = Timer(const Duration(seconds: 2), () => copier(raison));
  }

  /// Fait la copie maintenant si les données ont changé ; rend vrai si une copie a été écrite.
  Future<bool> copier(String raison, {bool forcer = false}) async {
    while (_enCours != null) {
      await _enCours;
    }
    final c = Completer<void>();
    _enCours = c.future;
    try {
      final copies = await liste();
      final texte = jsonEncode(Etat.instance.versJson());
      final empreinte = crypto.sha256.convert(utf8.encode(texte)).toString();
      final derniere = copies.where((x) => !x.ancre).firstOrNull ?? copies.firstOrNull;
      if (!forcer && derniere?.empreinte == empreinte) return false;
      final contenu = await fabriquer(texte, raison, empreinte);
      final le = DateTime.now();
      final nom = 'Emplettes-${_horodatage(le)}-${le.millisecond.toString().padLeft(3, '0')}.emplettes';
      await depot.ecrireCopie(nom, contenu);
      await _ranger([CopieSauvegarde.lire(nom, contenu)!, ...copies]);
      return true;
    } catch (e) {
      debugPrint('Sauvegarde impossible : $e');
      Etat.instance.noter('Sauvegarde impossible : $e');
      return false;
    } finally {
      _enCours = null;
      c.complete();
    }
  }

  /// Le fichier d'une copie : un en-tête lisible (date, jalon, foyer, nombres) et les données compressées,
  /// chiffrées avec le code du foyer s'il y en a un.
  Future<String> fabriquer(String texte, String raison, String empreinte) async {
    final etat = Etat.instance;
    final code = Synchro.instance.code;
    var donnees = 'gz:${base64Encode(GZipEncoder().encode(utf8.encode(texte))!)}';
    if (code != null) donnees = await (await ChiffreFoyer.pour(code)).chiffrer(donnees);
    return jsonEncode({
      'emplettes': 1,
      'le': DateTime.now().toIso8601String().substring(0, 23),
      'jalon': raison,
      'foyer': etat.foyerNom,
      'chiffre': code != null,
      'empreinte': empreinte,
      'compte': {
        'listes': etat.listes.length,
        'produits': etat.produits.length,
        'courses': etat.historique.length,
        'magasins': etat.magasins.length,
      },
      'donnees': donnees,
    });
  }

  /// Les copies de l'appareil, la plus récente d'abord (l'ancre en dernier).
  Future<List<CopieSauvegarde>> liste() async {
    final res = <CopieSauvegarde>[
      for (final e in (await depot.lireCopies()).entries)
        if (CopieSauvegarde.lire(e.key, e.value) case final c?) c,
    ];
    res.sort((a, b) => b.le.compareTo(a.le));
    return res;
  }

  /// Garde les [derniers] copies et l'ancre. La copie qui sort des dernières devient l'ancre s'il n'y en a pas,
  /// ou si elle a au moins un mois et qu'elle est plus récente que l'ancre actuelle ; sinon elle est effacée.
  Future<void> _ranger(List<CopieSauvegarde> copies) async {
    final ordinaires = copies.where((c) => !c.ancre).toList()..sort((a, b) => b.le.compareTo(a.le));
    var ancre = copies.where((c) => c.ancre).firstOrNull;
    final maintenant = DateTime.now();
    for (final c in ordinaires.skip(derniers)) {
      final assezVieille = maintenant.difference(c.le) >= ageAncre;
      final remplace = ancre == null || (assezVieille && c.le.isAfter(ancre.le)) ||
          (maintenant.difference(ancre.le) < ageAncre && c.le.isBefore(ancre.le));
      if (remplace) {
        final nom = c.nom.replaceFirst('Emplettes-', 'Emplettes-ancre-');
        await depot.ecrireCopie(nom, c.contenu);
        if (ancre != null) await depot.effacerCopie(ancre.nom);
        ancre = CopieSauvegarde(nom, c.entete, c.contenu);
      }
      await depot.effacerCopie(c.nom);
    }
  }

  /// Les données d'une copie, ou null si le code ne l'ouvre pas.
  Future<Map<String, dynamic>?> ouvrir(CopieSauvegarde c, {String? code}) async {
    var d = c.entete['donnees'] as String? ?? '';
    if (c.chiffree) {
      final k = code ?? Synchro.instance.code;
      if (k == null) return null;
      final clair = await (await ChiffreFoyer.pour(k)).dechiffrer(d);
      if (clair == null) return null;
      d = clair;
    }
    if (!d.startsWith('gz:')) return null;
    try {
      return jsonDecode(utf8.decode(GZipDecoder().decodeBytes(base64Decode(d.substring(3))))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Remplace les données de l'appareil par celles de la copie ; une copie de l'état actuel est faite avant.
  /// Dans un foyer, les données restaurées partent vers les autres appareils, comme toute modification.
  Future<void> restaurer(Map<String, dynamic> donnees) async {
    await copier('Avant restauration', forcer: true);
    final etat = Etat.instance;
    etat.lire(donnees);
    etat.unifierStructure(); // copie d'avant le 12/11/2026 : un exemplaire de la structure par magasin
    await etat.enregistrer();
    etat.modifie();
  }

  /// « Sauvegarder maintenant » : un fichier à garder ailleurs (Drive, mail, clé USB…).
  Future<bool> exporter() async {
    final texte = jsonEncode(Etat.instance.versJson());
    final contenu = await fabriquer(texte, 'Sauvegarde manuelle', crypto.sha256.convert(utf8.encode(texte)).toString());
    return depot.exporterFichier('Emplettes-${_horodatage(DateTime.now())}.emplettes', contenu);
  }

  /// « Depuis un fichier… »
  Future<CopieSauvegarde?> importer() async {
    final t = await depot.importerFichier();
    if (t == null) return null;
    return CopieSauvegarde.lire('fichier', t);
  }

  Future<String> emplacement() => depot.emplacementCopies();

  static String _horodatage(DateTime d) {
    String z(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${z(d.month)}${z(d.day)}-${z(d.hour)}${z(d.minute)}${z(d.second)}';
  }
}
