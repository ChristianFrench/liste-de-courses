import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'schema_v2.dart';

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

const _statuts = {'enConstruction': 'construction', 'prete': 'prete', 'enCours': 'en_cours', 'terminee': 'terminee'};

class Stockage {
  Stockage._(this._db);

  final Database _db;

  /// Dernière valeur écrite, par « table | clé » : évite de réécrire ce qui n'a pas changé.
  final Map<String, String> _ecrit = {};

  /// Lignes refusées par la base lors du dernier enregistrement (contrainte, règle de gestion).
  final List<String> erreurs = [];

  static Stockage ouvrir(String chemin) {
    final db = sqlite3.open(chemin);
    db.execute('PRAGMA foreign_keys = ON');
    final s = Stockage._(db);
    if (!s._existe('foyer')) s._creer();
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

  bool get vide => _db.select('SELECT 1 FROM foyer LIMIT 1').isEmpty;

  // ------------------------------------------------------------ Réglages de l'appareil

  String? reglage(String cle) {
    final r = _db.select('SELECT valeur FROM parametre WHERE cle = ?', [cle]);
    return r.isEmpty ? null : r.first['valeur'] as String?;
  }

  void definirReglage(String cle, String valeur) =>
      _db.execute('INSERT OR REPLACE INTO parametre (cle, valeur) VALUES (?, ?)', [cle, valeur]);

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
        {'id': m['id'], 'nomAffiche': m['nom_affiche'], 'role': m['role'], 'moi': m['id'] == moi}
    ];
    final inv = _db.select('SELECT * FROM invitation WHERE foyer_id = ? ORDER BY rowid DESC LIMIT 1', [foyerId]);
    etat['invitation'] = inv.isEmpty
        ? {'code': '', 'expiration': etat['foyer']['dateCreation']}
        : {'code': inv.first['code'], 'expiration': inv.first['expire_le']};
    etat['parametres'] = {
      'preliste': {'presencesMin': foyer['preliste_presences_min'], 'sur': foyer['preliste_sur']}
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
        });
      }
      if (statut == 'terminee' && lignes.isEmpty) continue;
      final nonPlace = l['ecran_reprise'] == 'non_place';
      listes.add({
        'id': id,
        'magasinId': l['magasin_id'],
        'statut': statuts[statut] ?? 'enConstruction',
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
    final requetes = <String, PreparedStatement>{};
    PreparedStatement requete(String sql) => requetes[sql] ??= _db.prepare(sql);

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
          final colonnes = valeurs.keys.toList();
          final maj = [
            for (final c in colonnes)
              if (!t.cle.contains(c) && !t.insertionSeule.contains(c)) '$c = excluded.$c'
          ];
          try {
            requete('INSERT INTO ${t.nom} (${colonnes.join(', ')}) VALUES (${List.filled(colonnes.length, '?').join(', ')}) '
                    'ON CONFLICT (${t.cle.join(', ')}) DO ${maj.isEmpty ? 'NOTHING' : 'UPDATE SET ${maj.join(', ')}'}')
                .execute([for (final c in colonnes) valeurs[c]]);
          } on SqliteException catch (e) {
            // Une règle de la base refuse cette ligne : le reste de l'état est quand même enregistré.
            erreurs.add('${t.nom} ${ligne[t.cle.first]} : ${e.message}');
            continue;
          }
          _ecrit[cle] = empreinte;
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
      _Ensemble e, List<Map<String, Object?>> liens, PreparedStatement Function(String) requete) {
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
    });
    return presents;
  }

  void _retirer(String cle, String maintenant, PreparedStatement Function(String) requete) {
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
        requete('UPDATE $nom SET archive = 1$horo WHERE $ou').execute([...h, ...valeurs]);
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
      res['membre']!.add({'id': m['id'], 'foyer_id': foyerId, 'nom_affiche': m['nomAffiche'], 'role': m['role']});
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
    ]);
    return res;
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
