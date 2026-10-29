import 'dart:convert';

import 'package:sqlite3/common.dart';

import 'base_locale.dart';

import 'schema_v2.dart';
import 'synchro.dart' show Horloge;

// Base locale SQLite de l'appareil, au schéma v2 (documents/schema-v2.sql) : une table par
// entité du modèle de données, avec les règles de gestion imposées par la base (déclencheurs).
//
// L'application garde son état en mémoire sous la forme du JSON de la maquette ; ce fichier
// le traduit en lignes de tables. Seules les lignes modifiées sont réécrites. Rien n'est effacé
// dans le catalogue (archive = 1) ; une ligne de liste ou un parcours retiré est marqué
// « supprime », pour la future synchronisation entre membres du foyer (MQTT).

/// Manière de traiter une ligne qui a disparu de l'état.
enum _Retrait { archive, supprime, abandon, effacer, aucun }

class _Table {
  const _Table(this.nom, this.cle, this.retrait, {this.horodate = true, this.insertionSeule = const {}});
  final String nom;
  final List<String> cle;
  final _Retrait retrait;
  final bool horodate; // colonnes modifie_le et synchro
  final Set<String> insertionSeule; // jamais réécrites (ex. compteur tenu par la base)
}

/// Liens réécrits en bloc pour un parent (marques d'un produit, étapes d'un parcours).
class _Ensemble {
  const _Ensemble(this.table, this.parent, this.enfant, {this.ordre});
  final String table;
  final String parent;
  final String enfant;
  final String? ordre;
}

// Ordre d'écriture : un secteur doit exister avant l'emplacement ou l'étape qui le désigne
// (déclencheurs R5, R6). Les lignes de liste passent avant les produits : le compteur d'un
// produit déjà présent monte (R4), celui d'un produit importé garde sa valeur.
const _tables = [
  _Table('foyer', ['id'], _Retrait.aucun),
  _Table('membre', ['id'], _Retrait.effacer),
  _Table('invitation', ['code'], _Retrait.effacer, horodate: false),
  _Table('type_promotion', ['id'], _Retrait.archive),
  _Table('magasin', ['id'], _Retrait.archive),
  _Table('rayon', ['id'], _Retrait.archive),
  _Table('secteur', ['id'], _Retrait.archive),
  _Table('marque', ['id'], _Retrait.archive),
  _Table('packaging', ['id'], _Retrait.archive),
  _Table('liste', ['id'], _Retrait.abandon),
  _Table('ligne_liste', ['id'], _Retrait.supprime, insertionSeule: {'nom_copie'}),
  _Table('produit', ['id'], _Retrait.archive, insertionSeule: {'nb_utilisations'}),
  _Table('emplacement', ['produit_id', 'magasin_id'], _Retrait.effacer),
  _Table('parcours', ['id'], _Retrait.supprime),
  _Table('ticket', ['id'], _Retrait.effacer),
  _Table('parametre', ['cle'], _Retrait.aucun, horodate: false),
];

const _ensembles = {
  'produit_marque': _Ensemble('produit_marque', 'produit_id', 'marque_id'),
  'produit_packaging': _Ensemble('produit_packaging', 'produit_id', 'packaging_id'),
  'parcours_etape': _Ensemble('parcours_etape', 'parcours_id', 'secteur_id', ordre: 'ordre'),
};

/// Tables dont la colonne foyer_id désigne le foyer local : elle ne circule pas entre appareils,
/// chacun garde son propre identifiant de foyer (le foyer partagé, c'est le code de partage).
const _avecFoyer = {'membre', 'liste', 'parcours', 'ticket'};

/// Réglages qui concernent tout le foyer (les autres restent propres à l'appareil).
const _parametresPartages = {'options', 'frequences_preliste', 'corbeille', 'rectificatives'};

/// Options propres à l'appareil, jamais envoyées.
const _optionsLocales = {'apparence'};

const _sqlSynchro = '''
CREATE TABLE IF NOT EXISTS synchro_objet (
    tab     TEXT NOT NULL,
    cle     TEXT NOT NULL,   -- valeurs de la clé, en JSON
    hlc     TEXT NOT NULL,   -- horloge hybride de la dernière modification
    noeud   TEXT NOT NULL,   -- appareil auteur de cette modification
    valeurs TEXT,            -- contenu partagé (JSON) ; NULL = retiré
    PRIMARY KEY (tab, cle)
);
CREATE INDEX IF NOT EXISTS synchro_objet_noeud ON synchro_objet (noeud, hlc);
CREATE TABLE IF NOT EXISTS synchro_attente (
    tab     TEXT NOT NULL,
    cle     TEXT NOT NULL,
    objet   TEXT NOT NULL,   -- objet reçu refusé par la base, réessayé à la réception suivante
    PRIMARY KEY (tab, cle)
);
''';

const _statuts = {'enConstruction': 'construction', 'prete': 'prete', 'enCours': 'en_cours', 'terminee': 'terminee'};

class Stockage {
  Stockage._(this._db);

  final CommonDatabase _db;

  /// Dernière valeur écrite, par « table | clé » : évite de réécrire ce qui n'a pas changé.
  final Map<String, String> _ecrit = {};

  /// Lignes refusées par la base lors du dernier enregistrement (contrainte, règle de gestion).
  final List<String> erreurs = [];

  static Stockage ouvrir(String chemin) {
    final db = ouvrirBase(chemin);
    db.execute('PRAGMA foreign_keys = ON');
    final s = Stockage._(db);
    if (!s._existe('foyer')) s._creer();
    db.execute(_sqlSynchro);
    return s;
  }

  bool _existe(String table) =>
      _db.select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [table]).isNotEmpty;

  /// Crée le schéma v2 ; une base de la version 1 (table « objets ») est reprise puis gardée à part.
  void _creer() {
    Map<String, dynamic>? ancien;
    String? demo;
    if (_existe('objets')) {
      ancien = _lireV1();
      final r = _db.select("SELECT contenu FROM objets WHERE type = 'local' AND id = 'modeDemo'");
      if (r.isNotEmpty) demo = jsonDecode(r.first['contenu'] as String) == 'oui' ? '1' : '0';
    }
    _db.execute(schemaV2);
    if (ancien != null) ecrire(ancien);
    if (demo != null) definirReglage('mode_demo', demo);
    if (_existe('objets')) _db.execute('ALTER TABLE objets RENAME TO objets_v1');
  }

  void fermer() => _db.dispose();

  /// Vérification rapide de la base : null si elle est saine, sinon ce que SQLite y trouve.
  String? verifier() {
    try {
      final r = [for (final l in _db.select('PRAGMA quick_check(5)')) '${l.values.first}'];
      return r.length == 1 && r.first == 'ok' ? null : r.join(' ; ');
    } catch (e) {
      return '$e';
    }
  }

  /// Base abîmée (29/10/2026, web : index des listes faux, des listes revenaient en arrière) : chaque ligne
  /// lisible est recopiée dans la base neuve [chemin], lue sans les index abîmés. Deux lignes de même clé :
  /// la dernière écrite l'emporte. Renvoie le nombre de lignes recopiées et les tables illisibles.
  (int, List<String>) recopierDans(String chemin) {
    Stockage.ouvrir(chemin).fermer(); // schéma à jour
    var n = 0;
    final echecs = <String>[];
    _db.execute('PRAGMA foreign_keys = OFF');
    _db.execute('ATTACH DATABASE ? AS neuve', [chemin]);
    // Les déclencheurs (compteurs d'utilisation…) ne doivent pas rejouer : les valeurs sont recopiées telles quelles.
    final declencheurs = [
      for (final r in _db.select("SELECT name, sql FROM neuve.sqlite_master WHERE type = 'trigger'"))
        (r['name'] as String, r['sql'] as String)
    ];
    for (final (nom, _) in declencheurs) {
      _db.execute('DROP TRIGGER neuve."$nom"');
    }
    try {
      final tables = [
        for (final r in _db.select("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"))
          r['name'] as String
      ];
      for (final t in tables) {
        final colonnes = {for (final r in _db.select('PRAGMA main.table_info("$t")')) r['name'] as String};
        final dansNeuve = [for (final r in _db.select('PRAGMA neuve.table_info("$t")')) r['name'] as String];
        if (dansNeuve.isEmpty) _db.execute('CREATE TABLE neuve."$t" AS SELECT * FROM main."$t" WHERE 0');
        final communes = (dansNeuve.isEmpty ? colonnes.toList() : dansNeuve.where(colonnes.contains).toList())
            .map((c) => '"$c"')
            .join(', ');
        try {
          _db.execute('INSERT OR REPLACE INTO neuve."$t" ($communes) SELECT $communes FROM main."$t" NOT INDEXED ORDER BY rowid');
          n += _db.updatedRows;
        } catch (e) {
          echecs.add('$t ($e)');
        }
      }
    } finally {
      _db.execute('DETACH DATABASE neuve');
      final neuve = ouvrirBase(chemin);
      try {
        for (final (_, sql) in declencheurs) {
          neuve.execute(sql);
        }
      } finally {
        neuve.dispose();
      }
      _db.execute('PRAGMA foreign_keys = ON');
    }
    return (n, echecs);
  }

  bool get vide => _db.select('SELECT 1 FROM foyer LIMIT 1').isEmpty;

  // ------------------------------------------------------------ Réglages de l'appareil

  String? reglage(String cle) {
    final r = _db.select('SELECT valeur FROM parametre WHERE cle = ?', [cle]);
    return r.isEmpty ? null : r.first['valeur'] as String?;
  }

  void definirReglage(String cle, String valeur) =>
      _db.execute('INSERT OR REPLACE INTO parametre (cle, valeur) VALUES (?, ?)', [cle, valeur]);

  void effacerReglage(String cle) => _db.execute('DELETE FROM parametre WHERE cle = ?', [cle]);

  /// Compteurs d'utilisation tenus par la base (déclencheur R4).
  Map<String, int> compteurs() => {
        for (final r in _db.select('SELECT id, nb_utilisations FROM produit'))
          r['id'] as String: r['nb_utilisations'] as int
      };

  // ------------------------------------------------------------ Lecture

  /// Reconstitue le JSON de l'état (même forme que « Données maquette.json »).
  Map<String, dynamic> lire() {
    final etat = <String, dynamic>{};
    final f = _db.select('SELECT * FROM foyer ORDER BY rowid LIMIT 1');
    if (f.isEmpty) return etat;
    final foyer = f.first;
    final foyerId = foyer['id'] as String;
    final moi = reglage('membre_courant');
    List<String> liens(String table, String colonne, String parent, String id, {String ordre = 'rowid'}) => [
          for (final r in _db.select('SELECT $colonne FROM $table WHERE $parent = ? ORDER BY $ordre', [id]))
            r[colonne] as String
        ];

    etat['foyer'] = {'id': foyerId, 'nom': foyer['nom'], 'dateCreation': (foyer['cree_le'] as String).substring(0, 10)};
    etat['membres'] = [
      for (final m in _db.select('SELECT * FROM membre WHERE foyer_id = ? ORDER BY rowid', [foyerId]))
        {'id': m['id'], 'nomAffiche': m['nom_affiche'], 'role': m['role'], 'moi': m['id'] == moi, 'email': m['email'] ?? ''}
    ];
    final inv = _db.select('SELECT * FROM invitation WHERE foyer_id = ? ORDER BY rowid DESC LIMIT 1', [foyerId]);
    etat['invitation'] = inv.isEmpty
        ? {'code': '', 'expiration': etat['foyer']['dateCreation']}
        : {'code': inv.first['code'], 'expiration': inv.first['expire_le']};
    etat['parametres'] = {
      'preliste': {'presencesMin': foyer['preliste_presences_min'], 'sur': foyer['preliste_sur']},
      if (reglage('options') != null) 'options': jsonDecode(reglage('options')!),
    };
    etat['typesPromotion'] = [
      for (final t in _db.select('SELECT * FROM type_promotion WHERE archive = 0 ORDER BY ordre_affichage, rowid'))
        {'id': t['id'], 'code': t['code'], 'nom': t['libelle'], 'exemple': t['exemple'] ?? '', 'parametres': jsonDecode(t['parametres'] as String)}
    ];
    etat['magasins'] = [
      for (final m in _db.select('SELECT * FROM magasin WHERE archive = 0 ORDER BY rowid'))
        {'id': m['id'], 'nom': m['nom'], 'enseigne': m['enseigne'] ?? '', 'ville': m['ville'] ?? ''}
    ];
    etat['rayons'] = [
      for (final r in _db.select('SELECT * FROM rayon WHERE archive = 0 ORDER BY ordre_affichage, rowid'))
        {'id': r['id'], 'magasinId': r['magasin_id'], 'nom': r['nom']}
    ];
    etat['secteurs'] = [
      for (final s in _db.select('SELECT * FROM secteur WHERE archive = 0 ORDER BY ordre_affichage, rowid'))
        {'id': s['id'], 'rayonId': s['rayon_id'], 'nom': s['nom']}
    ];
    etat['marques'] = [
      for (final m in _db.select('SELECT * FROM marque WHERE archive = 0 ORDER BY rowid')) {'id': m['id'], 'nom': m['nom']}
    ];
    etat['packagings'] = [
      for (final k in _db.select('SELECT * FROM packaging WHERE archive = 0 ORDER BY rowid'))
        {'id': k['id'], 'libelle': k['libelle']}
    ];
    etat['produits'] = [
      for (final p in _db.select('SELECT * FROM produit WHERE archive = 0 ORDER BY rowid'))
        {
          'id': p['id'],
          'nom': p['nom'],
          'marqueIds': liens('produit_marque', 'marque_id', 'produit_id', p['id'] as String),
          'packagingIds': liens('produit_packaging', 'packaging_id', 'produit_id', p['id'] as String),
          'nbUtilisations': p['nb_utilisations'],
        }
    ];
    etat['emplacements'] = [
      for (final e in _db.select('SELECT * FROM emplacement ORDER BY rowid'))
        {'magasinId': e['magasin_id'], 'produitId': e['produit_id'], 'secteurId': e['secteur_id']}
    ];
    etat['parcours'] = [
      for (final p in _db.select('SELECT * FROM parcours WHERE supprime = 0 AND foyer_id = ? ORDER BY rowid', [foyerId]))
        {
          'id': p['id'],
          'magasinId': p['magasin_id'],
          'membreId': p['membre_id'],
          'nom': p['nom'],
          'parDefaut': p['par_defaut'] == 1,
          'etapes': liens('parcours_etape', 'secteur_id', 'parcours_id', p['id'] as String, ordre: 'ordre'),
        }
    ];

    // Listes : une liste terminée sans ligne n'est qu'une course de l'historique.
    final statuts = {for (final e in _statuts.entries) e.value: e.key};
    final listes = <dynamic>[];
    final historique = <dynamic>[];
    for (final l in _db.select(
        "SELECT * FROM liste WHERE foyer_id = ? AND statut <> 'abandonnee' ORDER BY rowid", [foyerId])) {
      final id = l['id'] as String;
      final lignes = _db.select(
          'SELECT * FROM ligne_liste WHERE liste_id = ? AND supprime = 0 ORDER BY ordre, rowid', [id]);
      final statut = l['statut'] as String;
      if (statut == 'terminee' && l['date_courses'] != null) {
        historique.add({
          'id': id,
          'magasinId': l['magasin_id'],
          'dateCourses': (l['date_courses'] as String).substring(0, 10),
          'membreId': l['fait_par_id'],
          'nbArticles': l['nb_articles'] ?? lignes.where((g) => g['cochee'] == 1).length,
          if (l['libelle'] != null) 'nom': l['libelle'],
        });
      }
      if (statut == 'terminee' && lignes.isEmpty) continue;
      final nonPlace = l['ecran_reprise'] == 'non_place';
      listes.add({
        'id': id,
        'magasinId': l['magasin_id'],
        'statut': statuts[statut] ?? 'enConstruction',
        if (l['libelle'] != null) 'nom': l['libelle'],
        'dateCreation': l['cree_le'],
        'lignes': [
          for (final g in lignes)
            {
              'produitId': g['produit_id'],
              'marqueId': g['marque_id'],
              'packagingId': g['packaging_id'],
              'quantite': (g['quantite'] as num).toInt(),
              if (g['type_promotion_id'] != null)
                'promotion': {
                  'type': g['type_promotion_id'],
                  'parametres': jsonDecode(g['promo_parametres'] as String? ?? '{}'),
                  'libelle': g['promo_libelle'] ?? '',
                },
              if (g['cochee'] == 1) 'coche': {'par': g['cochee_par'], 'le': g['cochee_le']},
              if (g['note'] != null) 'consigne': g['note'],
            }
        ],
        'parcoursId': l['parcours_id'],
        'membreId': l['fait_par_id'],
        'interrompueLe': l['interrompue_le'],
        'modifieePar': l['modifie_par'],
        if (l['modifie_par'] != null && l['modifie_le'] != l['cree_le']) 'modifieeLe': l['modifie_le'],
        if (l['rayon_reprise_id'] != null || l['secteur_reprise_id'] != null || nonPlace)
          'reprise': {
            if (l['rayon_reprise_id'] != null) 'rayonId': l['rayon_reprise_id'],
            if (nonPlace) 'secteurId': 'nonPlace' else if (l['secteur_reprise_id'] != null) 'secteurId': l['secteur_reprise_id'],
          },
      });
    }
    etat['listes'] = listes;
    etat['historique'] = historique;
    etat['tickets'] = [
      for (final t in _db.select('SELECT * FROM ticket WHERE foyer_id = ? ORDER BY rowid', [foyerId]))
        {
          'id': t['id'],
          'listeId': t['liste_id'],
          'magasinId': t['magasin_id'],
          'date': t['date_ticket'],
          'montant': (t['montant'] as num?)?.toDouble() ?? 0.0,
          'source': t['source'],
        }
    ];
    final freq = reglage('frequences_preliste');
    etat['frequencesPreliste'] = freq == null ? <String, dynamic>{} : jsonDecode(freq);
    final corbeille = reglage('corbeille');
    etat['corbeille'] = corbeille == null ? <dynamic>[] : jsonDecode(corbeille);
    final rectificatives = reglage('rectificatives');
    etat['rectificatives'] = rectificatives == null ? <dynamic>[] : jsonDecode(rectificatives);

    _ecrit
      ..clear()
      ..addAll(_empreintes(etat));
    return etat;
  }

  // ------------------------------------------------------------ Écriture

  /// Enregistre l'état complet : écrit les lignes nouvelles ou modifiées, retire les disparues.
  void ecrire(Map<String, dynamic> etat) {
    final maintenant = DateTime.now().toUtc().toIso8601String().substring(0, 19);
    final lignes = _lignes(etat);
    erreurs.clear();
    final requetes = <String, CommonPreparedStatement>{};
    CommonPreparedStatement requete(String sql) => requetes[sql] ??= _db.prepare(sql);

    _db.execute('BEGIN');
    try {
      _db.execute('PRAGMA defer_foreign_keys = ON');
      final presents = <String>{};
      for (final t in _tables) {
        var aEcrire = lignes[t.nom]!;
        if (t.nom == 'parcours') {
          // Un seul parcours par défaut par membre et magasin : l'ancien perd ce rôle avant que le
          // nouveau le prenne. Les parcours nouveaux gardent leur ordre.
          final connus = aEcrire.where((l) => _ecrit.containsKey(_cle(t.nom, [l['id']]))).toList()
            ..sort((a, b) => (a['par_defaut'] as int) - (b['par_defaut'] as int));
          aEcrire = [...connus, ...aEcrire.where((l) => !connus.contains(l))];
        }
        for (final ligne in aEcrire) {
          final cle = _cle(t.nom, [for (final c in t.cle) ligne[c]]);
          presents.add(cle);
          final empreinte = _empreinte(t, ligne);
          if (_ecrit[cle] == empreinte) continue;
          if (t.nom == 'ligne_liste' && !_ecrit.containsKey(cle)) {
            // Un produit remis dans la liste compte comme une nouvelle entrée (R4).
            requete('UPDATE produit SET nb_utilisations = nb_utilisations + 1 WHERE id = ? '
                    'AND EXISTS (SELECT 1 FROM ligne_liste WHERE id = ? AND supprime = 1)')
                .execute([ligne['produit_id'], ligne['id']]);
          }
          final valeurs = {...ligne, if (t.horodate && !ligne.containsKey('modifie_le')) 'modifie_le': maintenant};
          if (t.horodate) valeurs['synchro'] = 0;
          try {
            _inserer(t, valeurs, requete);
          } on SqliteException catch (e) {
            // Une règle de la base refuse cette ligne : le reste de l'état est quand même enregistré.
            erreurs.add('${t.nom} ${ligne[t.cle.first]} : ${e.message}');
            continue;
          }
          _ecrit[cle] = empreinte;
          _journaliser(t.nom, [for (final c in t.cle) ligne[c]], ligne, requete);
        }
        if (t.nom == 'produit' || t.nom == 'parcours') {
          for (final e in _ensembles.values.where((e) => e.parent == '${t.nom}_id')) {
            presents.addAll(_ecrireEnsemble(e, lignes[e.table]!, requete));
          }
        }
      }
      for (final cle in _ecrit.keys.where((c) => !presents.contains(c)).toList()) {
        _retirer(cle, maintenant, requete);
        _ecrit.remove(cle);
        final morceaux = cle.split(_sep);
        _journaliser(morceaux.first, morceaux.sublist(1), null, requete);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      _ecrit.clear();
      rethrow;
    } finally {
      for (final r in requetes.values) {
        r.dispose();
      }
    }
  }

  /// Réécrit les liens d'un parent quand ils ont changé ; rend les clés présentes.
  Set<String> _ecrireEnsemble(
      _Ensemble e, List<Map<String, Object?>> liens, CommonPreparedStatement Function(String) requete) {
    final parParent = <String, List<Object?>>{};
    for (final l in liens) {
      (parParent[l[e.parent] as String] ??= []).add(l[e.enfant]);
    }
    final presents = <String>{};
    parParent.forEach((parent, enfants) {
      final cle = _cle(e.table, [parent]);
      presents.add(cle);
      final empreinte = jsonEncode(enfants);
      if (_ecrit[cle] == empreinte) return;
      requete('DELETE FROM ${e.table} WHERE ${e.parent} = ?').execute([parent]);
      final colonnes = [e.parent, e.enfant, if (e.ordre != null) e.ordre!];
      final inserer = requete('INSERT INTO ${e.table} (${colonnes.join(', ')}) VALUES (${List.filled(colonnes.length, '?').join(', ')})');
      for (var i = 0; i < enfants.length; i++) {
        inserer.execute([parent, enfants[i], if (e.ordre != null) i + 1]);
      }
      _ecrit[cle] = empreinte;
      _journaliser(e.table, [parent], {'enfants': enfants}, requete);
    });
    return presents;
  }

  /// Insère la ligne, ou met à jour celle qui a la même clé.
  void _inserer(_Table t, Map<String, Object?> valeurs, CommonPreparedStatement Function(String) requete) {
    final colonnes = valeurs.keys.toList();
    final maj = [
      for (final c in colonnes)
        if (!t.cle.contains(c) && !t.insertionSeule.contains(c)) '$c = excluded.$c'
    ];
    requete('INSERT INTO ${t.nom} (${colonnes.join(', ')}) VALUES (${List.filled(colonnes.length, '?').join(', ')}) '
            'ON CONFLICT (${t.cle.join(', ')}) DO ${maj.isEmpty ? 'NOTHING' : 'UPDATE SET ${maj.join(', ')}'}')
        .execute([for (final c in colonnes) valeurs[c]]);
  }

  void _retirer(String cle, String maintenant, CommonPreparedStatement Function(String) requete) {
    final morceaux = cle.split(_sep);
    final nom = morceaux.first;
    final valeurs = morceaux.sublist(1);
    final ens = _ensembles[nom];
    if (ens != null) {
      requete('DELETE FROM $nom WHERE ${ens.parent} = ?').execute(valeurs);
      return;
    }
    final t = _tables.firstWhere((t) => t.nom == nom);
    final ou = t.cle.map((c) => '$c = ?').join(' AND ');
    final horo = t.horodate ? ', modifie_le = ?, synchro = 0' : '';
    final h = t.horodate ? [maintenant] : <Object?>[];
    switch (t.retrait) {
      case _Retrait.archive:
        // Le nom d'un rayon ou d'un secteur archivé est libéré (nom unique par magasin ou par rayon) ;
        // une restauration réécrit le nom d'origine.
        final libere = nom == 'rayon' || nom == 'secteur' ? ", nom = nom || ' [' || id || ']'" : '';
        requete('UPDATE $nom SET archive = 1$libere$horo WHERE $ou').execute([...h, ...valeurs]);
      case _Retrait.supprime:
        requete('UPDATE $nom SET supprime = 1$horo WHERE $ou').execute([...h, ...valeurs]);
      case _Retrait.abandon:
        requete("UPDATE $nom SET statut = 'abandonnee'$horo WHERE $ou").execute([...h, ...valeurs]);
      case _Retrait.effacer:
        requete('DELETE FROM $nom WHERE $ou').execute(valeurs);
      case _Retrait.aucun:
        break;
    }
  }

  static const _sep = '\u0001';
  static String _cle(String table, List<Object?> valeurs) => [table, ...valeurs].join(_sep);

  static String _empreinte(_Table t, Map<String, Object?> ligne) =>
      jsonEncode({for (final e in ligne.entries) if (!t.insertionSeule.contains(e.key)) e.key: e.value});

  /// Empreintes de toutes les lignes d'un état, sans rien écrire (après une lecture).
  Map<String, String> _empreintes(Map<String, dynamic> etat) {
    final lignes = _lignes(etat);
    final res = <String, String>{};
    for (final t in _tables) {
      for (final l in lignes[t.nom]!) {
        res[_cle(t.nom, [for (final c in t.cle) l[c]])] = _empreinte(t, l);
      }
    }
    for (final e in _ensembles.values) {
      final parParent = <String, List<Object?>>{};
      for (final l in lignes[e.table]!) {
        (parParent[l[e.parent] as String] ??= []).add(l[e.enfant]);
      }
      parParent.forEach((p, enfants) => res[_cle(e.table, [p])] = jsonEncode(enfants));
    }
    return res;
  }

  /// Traduit le JSON de l'état en lignes de tables.
  static Map<String, List<Map<String, Object?>>> _lignes(Map<String, dynamic> etat) {
    final res = <String, List<Map<String, Object?>>>{
      for (final t in _tables) t.nom: [],
      for (final e in _ensembles.keys) e: [],
    };
    List<Map> liste(String cle) => (etat[cle] as List? ?? const []).cast<Map>();
    final foyer = etat['foyer'] as Map;
    final foyerId = foyer['id'] as String;
    final preliste = (etat['parametres'] as Map?)?['preliste'] as Map?;

    res['foyer']!.add({
      'id': foyerId,
      'nom': foyer['nom'],
      'preliste_presences_min': preliste?['presencesMin'] ?? 3,
      'preliste_sur': preliste?['sur'] ?? 6,
      'cree_le': foyer['dateCreation'],
    });
    for (final m in liste('membres')) {
      res['membre']!.add({
        'id': m['id'],
        'foyer_id': foyerId,
        'nom_affiche': m['nomAffiche'],
        'email': (m['email'] as String? ?? '').isEmpty ? null : m['email'],
        'role': m['role'],
      });
    }
    final inv = etat['invitation'] as Map?;
    if (inv != null && (inv['code'] as String? ?? '').isNotEmpty) {
      res['invitation']!.add({'code': inv['code'], 'foyer_id': foyerId, 'expire_le': inv['expiration']});
    }
    final types = liste('typesPromotion');
    for (var i = 0; i < types.length; i++) {
      final t = types[i];
      res['type_promotion']!.add({
        'id': t['id'],
        'code': t['code'],
        'libelle': t['nom'],
        'exemple': t['exemple'],
        'parametres': jsonEncode(t['parametres'] ?? []),
        'ordre_affichage': i + 1,
        'archive': 0,
      });
    }
    for (final m in liste('magasins')) {
      res['magasin']!.add({'id': m['id'], 'nom': m['nom'], 'enseigne': m['enseigne'], 'ville': m['ville'], 'archive': 0});
    }
    final rayons = liste('rayons');
    for (var i = 0; i < rayons.length; i++) {
      final r = rayons[i];
      res['rayon']!.add({'id': r['id'], 'magasin_id': r['magasinId'], 'nom': r['nom'], 'ordre_affichage': i, 'archive': 0});
    }
    final secteurs = liste('secteurs');
    for (var i = 0; i < secteurs.length; i++) {
      final s = secteurs[i];
      res['secteur']!.add({'id': s['id'], 'rayon_id': s['rayonId'], 'nom': s['nom'], 'ordre_affichage': i, 'archive': 0});
    }
    final marques = {for (final m in liste('marques')) m['id']: m['nom']};
    marques.forEach((id, nom) => res['marque']!.add({'id': id, 'nom': nom, 'archive': 0}));
    final packagings = {for (final k in liste('packagings')) k['id']: k['libelle']};
    packagings.forEach((id, libelle) => res['packaging']!.add({'id': id, 'libelle': libelle, 'archive': 0}));
    final noms = <Object?, Object?>{};
    for (final p in liste('produits')) {
      noms[p['id']] = p['nom'];
      res['produit']!.add({'id': p['id'], 'nom': p['nom'], 'nb_utilisations': p['nbUtilisations'] ?? 0, 'archive': 0});
      for (final m in (p['marqueIds'] as List? ?? const [])) {
        res['produit_marque']!.add({'produit_id': p['id'], 'marque_id': m});
      }
      for (final k in (p['packagingIds'] as List? ?? const [])) {
        res['produit_packaging']!.add({'produit_id': p['id'], 'packaging_id': k});
      }
    }
    for (final e in liste('emplacements')) {
      res['emplacement']!.add({'produit_id': e['produitId'], 'magasin_id': e['magasinId'], 'secteur_id': e['secteurId']});
    }
    for (final p in liste('parcours')) {
      res['parcours']!.add({
        'id': p['id'],
        'foyer_id': foyerId,
        'membre_id': p['membreId'],
        'magasin_id': p['magasinId'],
        'nom': p['nom'],
        'par_defaut': p['parDefaut'] == true ? 1 : 0,
        'supprime': 0,
      });
    }
    for (final p in liste('parcours')) {
      for (final s in (p['etapes'] as List? ?? const [])) {
        res['parcours_etape']!.add({'parcours_id': p['id'], 'secteur_id': s});
      }
    }

    final listes = <String, Map<String, Object?>>{};
    for (final l in liste('listes')) {
      final id = l['id'] as String;
      final reprise = l['reprise'] as Map?;
      final nonPlace = reprise?['secteurId'] == 'nonPlace';
      listes[id] = {
        'id': id,
        'foyer_id': foyerId,
        'magasin_id': l['magasinId'],
        'statut': _statuts[l['statut']] ?? 'construction',
        'parcours_id': l['parcoursId'],
        'fait_par_id': l['membreId'],
        'libelle': l['nom'],
        'date_courses': null,
        'nb_articles': null,
        'ecran_reprise': nonPlace ? 'non_place' : null,
        'rayon_reprise_id': reprise?['rayonId'],
        'secteur_reprise_id': nonPlace ? null : reprise?['secteurId'],
        'interrompue_le': l['interrompueLe'],
        'modifie_par': l['modifieePar'],
        'cree_le': l['dateCreation'],
        'modifie_le': l['modifieeLe'] ?? l['dateCreation'],
      };
      final lignes = (l['lignes'] as List? ?? const []).cast<Map>();
      for (var i = 0; i < lignes.length; i++) {
        final g = lignes[i];
        final promo = g['promotion'] as Map?;
        final coche = g['coche'] as Map?;
        res['ligne_liste']!.add({
          'id': '$id|${g['produitId']}',
          'liste_id': id,
          'produit_id': g['produitId'],
          'marque_id': g['marqueId'],
          'packaging_id': g['packagingId'],
          'quantite': g['quantite'] ?? 1,
          'type_promotion_id': promo?['type'],
          'promo_parametres': promo == null ? null : jsonEncode(promo['parametres'] ?? {}),
          'promo_libelle': promo?['libelle'],
          'ordre': i,
          'note': g['consigne'],
          'cochee': coche == null ? 0 : 1,
          'cochee_par': coche?['par'],
          'cochee_le': coche?['le'],
          'nom_copie': noms[g['produitId']] ?? '?',
          'marque_copie': marques[g['marqueId']],
          'packaging_copie': packagings[g['packagingId']],
          'supprime': 0,
        });
      }
    }
    // Historique : une course terminée est une liste au statut « terminee ».
    for (final h in liste('historique')) {
      final id = h['id'] as String;
      final l = listes[id] ??= {
        'id': id,
        'foyer_id': foyerId,
        'magasin_id': h['magasinId'],
        'statut': 'terminee',
        'parcours_id': null,
        'fait_par_id': null,
        'libelle': null,
        'date_courses': null,
        'nb_articles': null,
        'ecran_reprise': null,
        'rayon_reprise_id': null,
        'secteur_reprise_id': null,
        'interrompue_le': null,
        'modifie_par': null,
        'cree_le': h['dateCourses'],
        'modifie_le': h['dateCourses'],
      };
      l['statut'] = 'terminee';
      l['date_courses'] = h['dateCourses'];
      l['fait_par_id'] = h['membreId'];
      l['nb_articles'] = h['nbArticles'];
      l['libelle'] ??= h['nom'];
    }
    res['liste']!.addAll(listes.values);

    for (final t in liste('tickets')) {
      res['ticket']!.add({
        'id': t['id'],
        'foyer_id': foyerId,
        'liste_id': t['listeId'],
        'magasin_id': t['magasinId'],
        'date_ticket': t['date'],
        'montant': t['montant'],
        'source': t['source'] ?? 'photo',
      });
    }

    final moi = liste('membres').where((m) => m['moi'] == true).map((m) => m['id']).firstOrNull;
    res['parametre']!.addAll([
      {'cle': 'foyer_courant', 'valeur': foyerId},
      if (moi != null) {'cle': 'membre_courant', 'valeur': moi},
      {'cle': 'frequences_preliste', 'valeur': jsonEncode(etat['frequencesPreliste'] ?? {})},
      {'cle': 'corbeille', 'valeur': jsonEncode(etat['corbeille'] ?? [])},
      {'cle': 'rectificatives', 'valeur': jsonEncode(etat['rectificatives'] ?? [])},
      if ((etat['parametres'] as Map?)?['options'] != null)
        {'cle': 'options', 'valeur': jsonEncode((etat['parametres'] as Map)['options'])},
    ]);
    return res;
  }

  // ------------------------------------------------------------ Synchronisation (synchro.dart)

  /// Horloge de la synchronisation. Quand elle est réglée, chaque changement enregistré est noté
  /// dans synchro_objet, d'où il part vers les autres appareils du foyer.
  Horloge? horloge;

  /// Note un changement à envoyer, sauf s'il ne change rien à ce que les autres appareils ont déjà.
  void _journaliser(String table, List<Object?> cle, Map<String, Object?>? valeurs, CommonPreparedStatement Function(String) requete) {
    final h = horloge;
    if (h == null || table == 'invitation') return;
    if (table == 'parametre' && !_parametresPartages.contains(cle.first)) return;
    final k = jsonEncode(table == 'foyer' ? ['foyer'] : cle);
    final v = valeurs == null ? null : _canonique(_partage(table, valeurs));
    final r = requete('SELECT valeurs FROM synchro_objet WHERE tab = ? AND cle = ?').select([table, k]);
    if (r.isNotEmpty && r.first['valeurs'] == v) return;
    requete('INSERT OR REPLACE INTO synchro_objet (tab, cle, hlc, noeud, valeurs) VALUES (?, ?, ?, ?, ?)')
        .execute([table, k, h.suivante(), h.noeud, v]);
  }

  /// Ce qui circule d'une ligne : sans le foyer local ni l'état d'envoi, sans les options de l'appareil.
  static Map<String, Object?> _partage(String table, Map<String, Object?> valeurs) {
    final v = Map<String, Object?>.of(valeurs)
      ..remove('foyer_id')
      ..remove('synchro');
    if (table == 'foyer') v.remove('id');
    if (table == 'parametre' && v['cle'] == 'options' && v['valeur'] is String) {
      final o = Map<String, dynamic>.from(jsonDecode(v['valeur'] as String) as Map);
      o.removeWhere((c, _) => _optionsLocales.contains(c));
      v['valeur'] = _canonique(o);
    }
    return v;
  }

  /// JSON aux clés triées : deux contenus égaux s'écrivent pareil.
  static String _canonique(Object? x) {
    Object? trier(Object? x) => x is Map
        ? {for (final c in (x.keys.map((k) => '$k').toList()..sort())) c: trier(x[c])}
        : x is List
            ? [for (final e in x) trier(e)]
            : x;
    return jsonEncode(trier(x));
  }

  /// Note tout le contenu de l'état comme à envoyer (premier appareil du partage), ou seulement [tables].
  void toutJournaliser(Map<String, dynamic> etat, {Set<String>? tables}) {
    final lignes = _lignes(etat);
    final requetes = <String, CommonPreparedStatement>{};
    CommonPreparedStatement requete(String sql) => requetes[sql] ??= _db.prepare(sql);
    _db.execute('BEGIN');
    try {
      for (final t in _tables) {
        if (tables != null && !tables.contains(t.nom)) continue;
        for (final l in lignes[t.nom]!) {
          _journaliser(t.nom, [for (final c in t.cle) l[c]], l, requete);
        }
      }
      for (final e in _ensembles.values) {
        if (tables != null && !tables.contains(e.table)) continue;
        final parParent = <String, List<Object?>>{};
        for (final l in lignes[e.table]!) {
          (parParent[l[e.parent] as String] ??= []).add(l[e.enfant]);
        }
        parParent.forEach((p, enfants) => _journaliser(e.table, [p], {'enfants': enfants}, requete));
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      for (final r in requetes.values) {
        r.dispose();
      }
    }
  }

  /// Journal abîmé (29/10/2026, web : « database disk image is malformed » en lisant synchro_objet).
  /// D'abord ses index reconstruits ; sinon le journal est refait avec ce qui reste lisible. Ensuite toute
  /// ligne de la base qui diffère du journal y est notée à nouveau, donc renvoyée aux autres appareils.
  String reparerJournal() {
    String resultat;
    try {
      _db.execute('REINDEX synchro_objet');
      _db.select('SELECT count(*) FROM synchro_objet NOT INDEXED');
      connus();
      objetsDe('', '');
      resultat = 'index reconstruits';
    } catch (_) {
      var lignes = <List<Object?>>[];
      try {
        lignes = [
          for (final r in _db.select('SELECT tab, cle, hlc, noeud, valeurs FROM synchro_objet NOT INDEXED'))
            [r['tab'], r['cle'], r['hlc'], r['noeud'], r['valeurs']]
        ];
      } catch (_) {}
      _db.execute('DROP TABLE IF EXISTS synchro_objet');
      _db.execute(_sqlSynchro);
      _db.execute('BEGIN');
      final inserer = _db.prepare('INSERT OR REPLACE INTO synchro_objet (tab, cle, hlc, noeud, valeurs) VALUES (?, ?, ?, ?, ?)');
      try {
        for (final l in lignes) {
          inserer.execute(l);
        }
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      } finally {
        inserer.dispose();
      }
      resultat = 'journal refait, ${lignes.length} objets gardés';
    }
    if (horloge != null) toutJournaliser(lire());
    try {
      final controle = _db.select('PRAGMA quick_check(3)').map((r) => r.values.first).join(' ; ');
      resultat += ', vérification de la base : $controle';
    } catch (e) {
      resultat += ', vérification de la base impossible : $e';
    }
    return resultat;
  }

  /// Objets modifiés par [noeud] après [apres] (ordre de l'horloge).
  List<Map<String, Object?>> objetsDe(String noeud, String apres) => [
        for (final r in _db.select(
            'SELECT tab, cle, hlc, noeud, valeurs FROM synchro_objet WHERE noeud = ? AND hlc > ? ORDER BY hlc', [noeud, apres]))
          {'t': r['tab'], 'k': r['cle'], 'h': r['hlc'], 'n': r['noeud'], 'v': r['valeurs']}
      ];

  /// Pour chaque appareil, sa modification la plus récente connue ici.
  Map<String, String> connus() => {
        for (final r in _db.select('SELECT noeud, max(hlc) AS h FROM synchro_objet GROUP BY noeud'))
          r['noeud'] as String: r['h'] as String
      };

  /// Nouveau partage : ce qui a été noté pour un partage précédent ne compte plus.
  void viderJournal() {
    _db.execute('DELETE FROM synchro_objet');
    _db.execute('DELETE FROM synchro_attente');
  }

  /// Appareil qui a envoyé la fiche du foyer : celui qui a créé le partage.
  String? auteurFoyer() {
    final r = _db.select("SELECT noeud FROM synchro_objet WHERE tab = 'foyer' ORDER BY hlc LIMIT 1");
    return r.isEmpty ? null : r.first['noeud'] as String;
  }

  /// Objets reçus mais laissés de côté à la dernière intégration : la version d'ici est plus récente.
  int ignores = 0;

  int get nbEnAttente => _db.select('SELECT count(*) AS n FROM synchro_attente').first['n'] as int;

  /// Intègre les objets reçus des autres appareils (le plus récent l'emporte). Un objet refusé
  /// par la base (son secteur n'est pas encore arrivé…) est gardé et réessayé à la réception suivante.
  /// Rend le nombre d'objets intégrés.
  int appliquer(List<Map<String, dynamic>> objets) {
    final maintenant = DateTime.now().toUtc().toIso8601String().substring(0, 19);
    final foyer = _db.select('SELECT id FROM foyer ORDER BY rowid LIMIT 1');
    if (foyer.isEmpty) return 0;
    final foyerId = foyer.first['id'] as String;
    final rang = {for (var i = 0; i < _tables.length; i++) _tables[i].nom: i};
    for (final e in _ensembles.keys) {
      rang[e] = rang[e.startsWith('parcours') ? 'parcours' : 'produit']! ;
    }
    final tous = [
      for (final r in _db.select('SELECT objet FROM synchro_attente')) Map<String, dynamic>.from(jsonDecode(r['objet'] as String) as Map),
      ...objets,
    ]..sort((a, b) {
        final c = (rang[a['t']] ?? 99) - (rang[b['t']] ?? 99);
        return c != 0 ? c : (a['h'] as String).compareTo(b['h'] as String);
      });
    erreurs.clear();
    ignores = 0;
    var n = 0;
    final requetes = <String, CommonPreparedStatement>{};
    CommonPreparedStatement requete(String sql) => requetes[sql] ??= _db.prepare(sql);
    // Les objets arrivent dans le désordre (un emplacement avant son produit) : pas de contrôle des
    // références pendant l'intégration.
    _db.execute('PRAGMA foreign_keys = OFF');
    _db.execute('BEGIN');
    try {
      for (final o in tous) {
        final t = o['t'] as String, k = o['k'] as String, h = o['h'] as String;
        if (!rang.containsKey(t) || t == 'invitation') continue;
        final local = requete('SELECT hlc FROM synchro_objet WHERE tab = ? AND cle = ?').select([t, k]);
        if (local.isNotEmpty && (local.first['hlc'] as String).compareTo(h) >= 0) {
          requete('DELETE FROM synchro_attente WHERE tab = ? AND cle = ?').execute([t, k]);
          ignores++;
          continue;
        }
        final v = o['v'] as String?;
        try {
          _integrer(t, (jsonDecode(k) as List).cast<Object?>(), v == null ? null : Map<String, Object?>.from(jsonDecode(v) as Map),
              foyerId, maintenant, requete);
        } on SqliteException catch (e) {
          erreurs.add('$t $k : ${e.message}');
          requete('INSERT OR REPLACE INTO synchro_attente (tab, cle, objet) VALUES (?, ?, ?)').execute([t, k, jsonEncode(o)]);
          continue;
        }
        requete('INSERT OR REPLACE INTO synchro_objet (tab, cle, hlc, noeud, valeurs) VALUES (?, ?, ?, ?, ?)')
            .execute([t, k, h, o['n'], v]);
        requete('DELETE FROM synchro_attente WHERE tab = ? AND cle = ?').execute([t, k]);
        horloge?.recevoir(h);
        n++;
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      _db.execute('PRAGMA foreign_keys = ON');
      for (final r in requetes.values) {
        r.dispose();
      }
    }
    return n;
  }

  void _integrer(String table, List<Object?> cle, Map<String, Object?>? valeurs, String foyerId, String maintenant,
      CommonPreparedStatement Function(String) requete) {
    final ens = _ensembles[table];
    if (ens != null) {
      requete('DELETE FROM $table WHERE ${ens.parent} = ?').execute(cle);
      final enfants = (valeurs?['enfants'] as List?) ?? const [];
      final colonnes = [ens.parent, ens.enfant, if (ens.ordre != null) ens.ordre!];
      for (var i = 0; i < enfants.length; i++) {
        requete('INSERT INTO $table (${colonnes.join(', ')}) VALUES (${List.filled(colonnes.length, '?').join(', ')})')
            .execute([cle.first, enfants[i], if (ens.ordre != null) i + 1]);
      }
      return;
    }
    final t = _tables.firstWhere((t) => t.nom == table);
    if (table == 'foyer') {
      if (valeurs == null) return;
      requete('UPDATE foyer SET nom = ?, preliste_presences_min = ?, preliste_sur = ?, modifie_le = ? WHERE id = ?').execute(
          [valeurs['nom'], valeurs['preliste_presences_min'], valeurs['preliste_sur'], maintenant, foyerId]);
      return;
    }
    if (table == 'parametre') {
      final c = cle.first as String;
      if (valeurs == null || !_parametresPartages.contains(c)) return;
      var valeur = valeurs['valeur'] as String?;
      if (c == 'options' && valeur != null) {
        final o = Map<String, dynamic>.from(jsonDecode(valeur) as Map);
        final ici = reglage('options');
        if (ici != null) {
          final locales = jsonDecode(ici) as Map;
          for (final l in _optionsLocales) {
            if (locales.containsKey(l)) o[l] = locales[l];
          }
        }
        valeur = jsonEncode(o);
      }
      requete('INSERT OR REPLACE INTO parametre (cle, valeur) VALUES (?, ?)').execute([c, valeur]);
      return;
    }
    if (valeurs == null) {
      _retirer(_cle(table, cle), maintenant, requete);
      return;
    }
    final v = {
      ...valeurs,
      if (_avecFoyer.contains(table)) 'foyer_id': foyerId,
      if (t.horodate && !valeurs.containsKey('modifie_le')) 'modifie_le': maintenant,
      if (t.horodate) 'synchro': 1,
    };
    _inserer(t, v, requete);
  }

  // ------------------------------------------------------------ Reprise de la version 1

  /// Lit l'ancienne table « objets » (un objet JSON par ligne) sous forme d'état.
  Map<String, dynamic>? _lireV1() {
    const collections = {
      'membre': 'membres', 'typePromotion': 'typesPromotion', 'magasin': 'magasins', 'rayon': 'rayons',
      'secteur': 'secteurs', 'marque': 'marques', 'packaging': 'packagings', 'produit': 'produits',
      'emplacement': 'emplacements', 'parcours': 'parcours', 'liste': 'listes', 'course': 'historique', 'ticket': 'tickets',
    };
    final etat = <String, dynamic>{for (final c in collections.values) c: <dynamic>[]};
    final lignes = _db.select("SELECT type, id, contenu FROM objets WHERE supprime = 0 AND type <> 'local' ORDER BY type, rang");
    for (final l in lignes) {
      final valeur = jsonDecode(l['contenu'] as String);
      final type = l['type'] as String;
      if (type == 'config') {
        etat[l['id'] as String] = valeur;
      } else if (collections[type] != null) {
        (etat[collections[type]] as List).add(valeur);
      }
    }
    return etat['foyer'] == null ? null : etat;
  }
}
