import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

// Base locale SQLite de l'appareil. Chaque objet du modèle (magasin, rayon, produit, liste…)
// est une ligne de la table « objets », sous forme JSON. Seuls les objets modifiés sont
// réécrits ; un objet supprimé est marqué « supprime » plutôt qu'effacé, pour la future
// synchronisation entre membres du foyer (MQTT).

/// Collections du modèle : clé dans le JSON de l'état → type d'objet.
const _collections = {
  'membres': 'membre',
  'typesPromotion': 'typePromotion',
  'magasins': 'magasin',
  'rayons': 'rayon',
  'secteurs': 'secteur',
  'marques': 'marque',
  'packagings': 'packaging',
  'produits': 'produit',
  'emplacements': 'emplacement',
  'parcours': 'parcours',
  'listes': 'liste',
  'historique': 'course',
  'tickets': 'ticket',
};

/// Réglages propres à l'appareil, jamais partagés.
const _typeLocal = 'local';

/// Objets uniques du foyer (foyer, invitation, paramètres, fréquences…).
const _typeConfig = 'config';

class Stockage {
  Stockage._(this._db);

  final Database _db;

  /// Dernier contenu écrit, par « type/id » : évite de réécrire ce qui n'a pas changé.
  final Map<String, String> _ecrit = {};

  static Stockage ouvrir(String chemin) {
    final db = sqlite3.open(chemin);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS objets (
        type     TEXT    NOT NULL,
        id       TEXT    NOT NULL,
        rang     INTEGER NOT NULL DEFAULT 0,
        contenu  TEXT    NOT NULL,
        modifie  TEXT    NOT NULL,
        supprime INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (type, id)
      )''');
    db.execute('PRAGMA user_version = 1');
    return Stockage._(db);
  }

  void fermer() => _db.dispose();

  bool get vide => _db.select("SELECT 1 FROM objets WHERE type <> '$_typeLocal' AND supprime = 0 LIMIT 1").isEmpty;

  // ------------------------------------------------------------ Réglages de l'appareil

  String? reglage(String cle) {
    final r = _db.select('SELECT contenu FROM objets WHERE type = ? AND id = ?', [_typeLocal, cle]);
    return r.isEmpty ? null : jsonDecode(r.first['contenu'] as String) as String?;
  }

  void definirReglage(String cle, String valeur) {
    _db.execute(
      'INSERT OR REPLACE INTO objets (type, id, rang, contenu, modifie, supprime) VALUES (?, ?, 0, ?, ?, 0)',
      [_typeLocal, cle, jsonEncode(valeur), DateTime.now().toUtc().toIso8601String()],
    );
  }

  // ------------------------------------------------------------ État du foyer

  /// Reconstitue le JSON de l'état (même forme que « Données maquette.json »).
  Map<String, dynamic> lire() {
    _ecrit.clear();
    final etat = <String, dynamic>{for (final cle in _collections.keys) cle: <dynamic>[]};
    final parType = {for (final e in _collections.entries) e.value: e.key};
    final lignes = _db.select(
        "SELECT type, id, contenu FROM objets WHERE supprime = 0 AND type <> '$_typeLocal' ORDER BY type, rang");
    for (final l in lignes) {
      final type = l['type'] as String;
      final id = l['id'] as String;
      final contenu = l['contenu'] as String;
      _ecrit['$type/$id'] = contenu;
      final valeur = jsonDecode(contenu);
      if (type == _typeConfig) {
        etat[id] = valeur;
      } else if (parType[type] != null) {
        (etat[parType[type]] as List).add(valeur);
      }
    }
    return etat;
  }

  /// Enregistre l'état complet : écrit les objets nouveaux ou modifiés, marque les disparus.
  void ecrire(Map<String, dynamic> etat) {
    final maintenant = DateTime.now().toUtc().toIso8601String();
    final presents = <String>{};
    final inserer = _db.prepare(
        'INSERT OR REPLACE INTO objets (type, id, rang, contenu, modifie, supprime) VALUES (?, ?, ?, ?, ?, 0)');
    final marquer = _db.prepare('UPDATE objets SET supprime = 1, modifie = ? WHERE type = ? AND id = ?');
    _db.execute('BEGIN');
    try {
      void ecrireObjet(String type, String id, int rang, Object? valeur) {
        final cle = '$type/$id';
        presents.add(cle);
        final contenu = jsonEncode(valeur);
        if (_ecrit[cle] == contenu) return;
        inserer.execute([type, id, rang, contenu, maintenant]);
        _ecrit[cle] = contenu;
      }

      etat.forEach((cle, valeur) {
        final type = _collections[cle];
        if (type == null) {
          ecrireObjet(_typeConfig, cle, 0, valeur);
          return;
        }
        final liste = (valeur as List).cast<Map>();
        for (var i = 0; i < liste.length; i++) {
          ecrireObjet(type, _identifiant(type, liste[i]), i, liste[i]);
        }
      });
      for (final cle in _ecrit.keys.where((c) => !presents.contains(c)).toList()) {
        final i = cle.indexOf('/');
        marquer.execute([maintenant, cle.substring(0, i), cle.substring(i + 1)]);
        _ecrit.remove(cle);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      inserer.dispose();
      marquer.dispose();
    }
  }

  /// Les emplacements n'ont pas d'identifiant propre : un produit a un secteur par magasin.
  static String _identifiant(String type, Map objet) =>
      type == 'emplacement' ? '${objet['magasinId']}|${objet['produitId']}' : objet['id'] as String;
}
