// Moteur de l'essai : base locale sqlite_crdt + échanges MQTT (QoS 1).
//
// Canaux, sous « ldc-essai/<code du foyer>/ » :
//   presence/<appareil>  état en ligne / hors ligne (retenu, testament MQTT)
//   modifs/<appareil>    lots de lignes modifiées par cet appareil
//   accuse               accusé de réception d'un lot (sert aux mesures)
//   bonjour              à la connexion : « voici ce que je connais déjà »
//   ping / pong          mesure du temps aller-retour
//   message              message libre (notification)
//   empreinte            comparaison du contenu des bases
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

const tablesSynchronisees = ['listes', 'lignes'];
const tailleLot = 400;

Future<SqliteCrdt> ouvrirBase(String? chemin) {
  Future<void> creer(CrdtTableExecutor db, int version) async {
    await db.execute('''
      CREATE TABLE listes (
        id TEXT NOT NULL,
        nom TEXT,
        par TEXT,
        PRIMARY KEY (id)
      )''');
    await db.execute('''
      CREATE TABLE lignes (
        id TEXT NOT NULL,
        liste_id TEXT,
        article TEXT,
        quantite INTEGER,
        coche INTEGER,
        par TEXT,
        PRIMARY KEY (id)
      )''');
  }

  return chemin == null
      ? SqliteCrdt.openInMemory(version: 1, onCreate: creer)
      : SqliteCrdt.open(chemin, version: 1, onCreate: creer);
}

/// Le réseau, isolé pour pouvoir tester le moteur sans broker.
abstract class Transport {
  Stream<(String sujet, String contenu)> get messages;
  Stream<String> get etats; // 'connecte', 'deconnecte', 'connexion', ou un message d'erreur
  bool get connecte;
  Future<void> connecter({
    required String identifiant,
    required String sujetTestament,
    required String testament,
    required String abonnement,
  });
  void publier(String sujet, String contenu, {bool retenu = false});
  Future<void> fermer();
}

class Evenement {
  Evenement(this.type, this.texte) : t = DateTime.now();
  final DateTime t;
  final String type; // info, envoi, reception, erreur, message, mesure
  final String texte;
}

class Pair {
  Pair(this.id);
  final String id;
  String nom = '?';
  String plateforme = '';
  bool enLigne = false;
  DateTime vu = DateTime.now();
  int changementsRecus = 0;
}

class Moteur extends ChangeNotifier {
  Moteur({
    required this.crdt,
    required this.transport,
    required this.foyer,
    required this.nom,
    required this.plateforme,
    this.dernierEnvoi = '',
    this.surDernierEnvoi,
  });

  final SqliteCrdt crdt;
  final Transport transport;
  final String foyer;
  final String nom;
  final String plateforme;

  /// Horodatage de la dernière modification locale publiée.
  String dernierEnvoi;
  final void Function(String)? surDernierEnvoi;

  String get id => crdt.nodeId;
  String get base => 'ldc-essai/$foyer';

  final journal = <Evenement>[];
  final pairs = <String, Pair>{};
  final _notifications = StreamController<String>.broadcast();
  Stream<String> get notifications => _notifications.stream;

  String etatReseau = 'deconnecte';
  int lotsEnvoyes = 0, changementsEnvoyes = 0, lotsRecus = 0, changementsRecus = 0;
  int _seq = 0;
  final _envois = <int, (int t, int n)>{}; // seq -> (heure d'envoi, nombre)
  final _accuses = <String, Map<int, (int n, int rtt)>>{}; // pair -> seq -> (nombre accusé, aller-retour en ms)
  final _subs = <StreamSubscription>[];
  Future<void> _file = Future.value();
  bool _envoiEnCours = false, _envoiARefaire = false;

  // ---------------------------------------------------------------- démarrage

  Future<void> demarrer() async {
    _subs.add(transport.messages.listen((m) => _file = _file.then((_) => _recevoir(m.$1, m.$2)).catchError((e) {
          noter('erreur', 'Message illisible sur ${m.$1} : $e');
        })));
    _subs.add(transport.etats.listen((e) {
      etatReseau = e;
      if (e == 'connecte') {
        noter('info', 'Connecté au serveur MQTT');
        _annoncer();
      } else if (e == 'deconnecte') {
        noter('info', 'Déconnecté : les modifications restent en attente dans la base locale');
      } else if (e != 'connexion') {
        noter('erreur', e);
      }
      notifyListeners();
    }));
    await transport.connecter(
      identifiant: 'ldc-essai-$id',
      sujetTestament: '$base/presence/$id',
      testament: jsonEncode(_presence(false)),
      abonnement: '$base/#',
    );
  }

  Map<String, Object?> _presence(bool enLigne) =>
      {'de': id, 'nom': nom, 'plateforme': plateforme, 'enLigne': enLigne};

  Future<void> _annoncer() async {
    transport.publier('$base/presence/$id', jsonEncode(_presence(true)), retenu: true);
    // « Voici, pour chaque autre appareil, la modification la plus récente que je connais. »
    final connus = <String, String>{};
    for (final t in tablesSynchronisees) {
      for (final r in await crdt.query(
          'SELECT node_id, max(hlc) AS h FROM $t WHERE node_id != ?1 GROUP BY node_id', [id])) {
        final n = r['node_id'] as String, h = r['h'] as String;
        if ((connus[n] ?? '').compareTo(h) < 0) connus[n] = h;
      }
    }
    transport.publier('$base/bonjour', jsonEncode({'de': id, 'nom': nom, 'connus': connus}));
    await envoyerModifs();
  }

  Future<void> arreter() async {
    if (transport.connecte) {
      transport.publier('$base/presence/$id', jsonEncode(_presence(false)), retenu: true);
    }
    for (final s in _subs) {
      await s.cancel();
    }
    await transport.fermer();
  }

  @override
  void dispose() {
    _notifications.close();
    super.dispose();
  }

  void noter(String type, String texte) {
    journal.insert(0, Evenement(type, texte));
    if (journal.length > 2000) journal.removeLast();
    notifyListeners();
  }

  String nomDe(String pair) => pair == id ? nom : (pairs[pair]?.nom ?? pair.substring(0, min(6, pair.length)));

  // ---------------------------------------------------------------- envoi

  /// Publie toutes les modifications locales pas encore envoyées.
  Future<void> envoyerModifs() async {
    if (_envoiEnCours) {
      _envoiARefaire = true;
      return;
    }
    if (!transport.connecte) return;
    _envoiEnCours = true;
    try {
      do {
        _envoiARefaire = false;
        final lignes = <(String table, Map<String, Object?> r)>[];
        for (final t in tablesSynchronisees) {
          for (final r in await crdt.query(
              'SELECT * FROM $t WHERE node_id = ?1 AND modified > ?2', [id, dernierEnvoi])) {
            lignes.add((t, r));
          }
        }
        if (lignes.isEmpty) break;
        lignes.sort((a, b) => (a.$2['modified'] as String).compareTo(b.$2['modified'] as String));
        final plusRecent = lignes.last.$2['modified'] as String;
        for (var i = 0; i < lignes.length; i += tailleLot) {
          _publierLot(lignes.sublist(i, min(i + tailleLot, lignes.length)));
        }
        dernierEnvoi = plusRecent;
        surDernierEnvoi?.call(plusRecent);
      } while (_envoiARefaire && transport.connecte);
    } finally {
      _envoiEnCours = false;
    }
  }

  void _publierLot(List<(String, Map<String, Object?>)> lot, {String? pour}) {
    final donnees = <String, List<Map<String, Object?>>>{};
    for (final (t, r) in lot) {
      final copie = Map<String, Object?>.of(r)
        ..remove('modified')
        ..remove('node_id');
      (donnees[t] ??= []).add(copie);
    }
    final seq = ++_seq;
    final maintenant = DateTime.now().millisecondsSinceEpoch;
    _envois[seq] = (maintenant, lot.length);
    transport.publier('$base/modifs/$id',
        jsonEncode({'de': id, 'seq': seq, 'envoye': maintenant, 'n': lot.length, 'pour': pour, 'donnees': donnees}));
    lotsEnvoyes++;
    changementsEnvoyes += lot.length;
    noter('envoi', '${pour == null ? 'Envoyé' : 'Renvoyé à ${nomDe(pour)}'} : ${_resume(donnees)}');
  }

  String _resume(Map<String, dynamic> donnees) {
    final morceaux = <String>[];
    var total = 0;
    donnees.forEach((t, lignes) {
      total += (lignes as List).length;
      for (final l in lignes.take(3)) {
        final m = l as Map;
        final quoi = t == 'lignes' ? '${m['article']}' : 'liste « ${m['nom']} »';
        final etat = m['is_deleted'] == 1
            ? 'supprimé'
            : t == 'lignes'
                ? '${m['quantite']}${m['coche'] == 1 ? ', coché' : ''}'
                : '';
        morceaux.add(etat.isEmpty ? quoi : '$quoi ($etat)');
      }
    });
    final reste = total - morceaux.length;
    return '$total changement${total > 1 ? 's' : ''} : ${morceaux.join(', ')}${reste > 0 ? ' et $reste autres' : ''}';
  }

  // ---------------------------------------------------------------- réception

  Future<void> _recevoir(String sujet, String contenu) async {
    if (!sujet.startsWith('$base/')) return;
    final type = sujet.substring(base.length + 1).split('/').first;
    if (contenu.isEmpty) return;
    final m = jsonDecode(contenu) as Map<String, dynamic>;
    final de = m['de'] as String?;
    if (de == null || de == id) return;
    final pair = pairs[de] ??= Pair(de);
    pair.vu = DateTime.now();
    switch (type) {
      case 'presence':
        final avant = pair.enLigne;
        pair
          ..nom = m['nom'] as String? ?? pair.nom
          ..plateforme = m['plateforme'] as String? ?? ''
          ..enLigne = m['enLigne'] == true;
        if (avant != pair.enLigne) {
          noter('info', '${pair.nom} (${pair.plateforme}) ${pair.enLigne ? 'est en ligne' : 'est hors ligne'}');
        }
        notifyListeners();
      case 'modifs':
        await _recevoirModifs(m, pair);
      case 'accuse':
        if (m['a'] == id) _recevoirAccuse(m, pair);
      case 'bonjour':
        pair.nom = m['nom'] as String? ?? pair.nom;
        await _repondreBonjour(m, pair);
      case 'ping':
        transport.publier('$base/pong', jsonEncode({'de': id, 'a': de, 'seq': m['seq'], 't': m['t']}));
      case 'pong':
        if (m['a'] == id) _recevoirPong(m, pair);
      case 'message':
        final texte = '${pair.nom} : ${m['texte']}';
        noter('message', texte);
        _notifications.add(texte);
      case 'empreinte':
        if (m['demande'] == true) {
          final (e, n) = await empreinte();
          transport.publier('$base/empreinte', jsonEncode({'de': id, 'a': de, 'empreinte': e, 'n': n}));
        } else if (m['a'] == id) {
          final (e, n) = await empreinte();
          final pareil = e == m['empreinte'];
          noter('mesure',
              'Comparaison avec ${pair.nom} : ${pareil ? 'bases identiques' : 'BASES DIFFÉRENTES'} ($n lignes ici, ${m['n']} chez ${pair.nom})');
        }
    }
  }

  Future<void> _recevoirModifs(Map<String, dynamic> m, Pair pair) async {
    final pour = m['pour'] as String?;
    if (pour != null && pour != id) return;
    final changeset = <String, List<Map<String, Object?>>>{};
    (m['donnees'] as Map<String, dynamic>).forEach((t, lignes) {
      if (!tablesSynchronisees.contains(t)) return;
      changeset[t] = [
        for (final l in lignes as List) {...(l as Map<String, dynamic>), 'hlc': (l['hlc'] as String).toHlc},
      ];
    });
    final n = m['n'] as int? ?? changeset.recordCount;
    final debut = DateTime.now();
    try {
      await crdt.merge(changeset);
    } catch (e) {
      noter('erreur', 'Lot de ${pair.nom} refusé : $e'
          '${'$e'.contains('drift') ? ' (horloges des deux appareils décalées de plus d\'une minute)' : ''}');
      return;
    }
    final duree = DateTime.now().difference(debut).inMilliseconds;
    lotsRecus++;
    changementsRecus += n;
    pair.changementsRecus += n;
    transport.publier('$base/accuse', jsonEncode({'de': id, 'a': pair.id, 'seq': m['seq'], 'n': n, 'envoye': m['envoye']}));
    noter('reception', 'Reçu de ${pair.nom} : ${_resume(m['donnees'] as Map<String, dynamic>)} · intégré en $duree ms');
  }

  void _recevoirAccuse(Map<String, dynamic> m, Pair pair) {
    final seq = m['seq'] as int, n = m['n'] as int;
    final envoi = _envois[seq];
    if (envoi == null) return;
    final rtt = DateTime.now().millisecondsSinceEpoch - envoi.$1;
    (_accuses[pair.id] ??= {})[seq] = (n, rtt);
    _verifierVolume();
    notifyListeners();
  }

  Future<void> _repondreBonjour(Map<String, dynamic> m, Pair pair) async {
    final connu = (m['connus'] as Map<String, dynamic>? ?? {})[id] as String? ?? '';
    final lignes = <(String, Map<String, Object?>)>[];
    for (final t in tablesSynchronisees) {
      for (final r in await crdt.query('SELECT * FROM $t WHERE node_id = ?1 AND hlc > ?2', [id, connu])) {
        lignes.add((t, r));
      }
    }
    if (lignes.isEmpty) return;
    noter('info', '${pair.nom} vient de se connecter : il lui manque ${lignes.length} de mes changements, je les renvoie');
    for (var i = 0; i < lignes.length; i += tailleLot) {
      _publierLot(lignes.sublist(i, min(i + tailleLot, lignes.length)), pour: pair.id);
    }
  }

  // ---------------------------------------------------------------- données

  final _alea = Random();
  String nouvelId() =>
      '${id.substring(0, min(4, id.length))}${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_alea.nextInt(1 << 20).toRadixString(36)}';

  Stream<List<Map<String, Object?>>> listes() =>
      crdt.watch('SELECT id, nom, par FROM listes WHERE is_deleted = 0 ORDER BY nom');

  Stream<List<Map<String, Object?>>> lignesDe(String listeId) => crdt.watch(
      'SELECT id, article, quantite, coche, par FROM lignes WHERE is_deleted = 0 AND liste_id = ?1 ORDER BY coche, article',
      () => [listeId]);

  Future<String> ajouterListe(String nomListe, {List<(String, int)> articles = const []}) async {
    final lid = nouvelId();
    await crdt.transaction((txn) async {
      await txn.execute('INSERT INTO listes (id, nom, par) VALUES (?1, ?2, ?3)', [lid, nomListe, nom]);
      for (final (a, q) in articles) {
        await txn.execute('INSERT INTO lignes (id, liste_id, article, quantite, coche, par) VALUES (?1, ?2, ?3, ?4, 0, ?5)',
            [nouvelId(), lid, a, q, nom]);
      }
    });
    await envoyerModifs();
    return lid;
  }

  Future<void> ajouterLigne(String listeId, String article, [int quantite = 1]) async {
    await crdt.execute('INSERT INTO lignes (id, liste_id, article, quantite, coche, par) VALUES (?1, ?2, ?3, ?4, 0, ?5)',
        [nouvelId(), listeId, article, quantite, nom]);
    await envoyerModifs();
  }

  Future<void> cocher(String ligneId, bool coche) async {
    await crdt.execute('UPDATE lignes SET coche = ?1, par = ?2 WHERE id = ?3', [coche ? 1 : 0, nom, ligneId]);
    await envoyerModifs();
  }

  Future<void> changerQuantite(String ligneId, int quantite) async {
    await crdt.execute('UPDATE lignes SET quantite = ?1, par = ?2 WHERE id = ?3', [max(1, quantite), nom, ligneId]);
    await envoyerModifs();
  }

  Future<void> supprimerLigne(String ligneId) async {
    await crdt.execute('DELETE FROM lignes WHERE id = ?1', [ligneId]);
    await envoyerModifs();
  }

  Future<void> supprimerListe(String listeId) async {
    await crdt.transaction((txn) async {
      await txn.execute('DELETE FROM lignes WHERE liste_id = ?1', [listeId]);
      await txn.execute('DELETE FROM listes WHERE id = ?1', [listeId]);
    });
    await envoyerModifs();
  }

  Future<(int listes, int lignes)> compter() async {
    final l = await crdt.query('SELECT count(*) AS n FROM listes WHERE is_deleted = 0');
    final a = await crdt.query('SELECT count(*) AS n FROM lignes WHERE is_deleted = 0');
    return (l.first['n'] as int, a.first['n'] as int);
  }

  /// Empreinte du contenu visible (indépendante de l'appareil) et nombre de lignes.
  Future<(String, int)> empreinte() async {
    var h = 0x811c9dc5;
    var n = 0;
    void ajouter(String s) {
      for (final c in utf8.encode(s)) {
        h = ((h ^ c) * 0x01000193) & 0xffffffff;
      }
    }

    for (final r in await crdt.query('SELECT id, nom FROM listes WHERE is_deleted = 0 ORDER BY id')) {
      ajouter('L${r['id']}|${r['nom']}\n');
    }
    for (final r in await crdt
        .query('SELECT id, liste_id, article, quantite, coche FROM lignes WHERE is_deleted = 0 ORDER BY id')) {
      ajouter('A${r['id']}|${r['liste_id']}|${r['article']}|${r['quantite']}|${r['coche']}\n');
      n++;
    }
    return (h.toRadixString(16).padLeft(8, '0'), n);
  }

  // ---------------------------------------------------------------- essais

  void message(String texte) {
    transport.publier('$base/message', jsonEncode({'de': id, 'texte': texte}));
    noter('message', 'Moi : $texte');
  }

  void comparerEmpreintes() async {
    final (e, n) = await empreinte();
    noter('mesure', 'Mon empreinte : $e ($n lignes). Demande aux autres appareils…');
    transport.publier('$base/empreinte', jsonEncode({'de': id, 'demande': true}));
  }

  // Ping : temps aller-retour des petits messages.
  final _pings = <String, List<int>>{};
  int _seqPing = 0;
  int _pingDebut = 0;

  Future<void> ping({int nombre = 10, Duration intervalle = const Duration(milliseconds: 300)}) async {
    _pings.clear();
    _pingDebut = _seqPing + 1;
    noter('mesure', 'Ping : envoi de $nombre messages…');
    for (var i = 0; i < nombre; i++) {
      transport.publier('$base/ping', jsonEncode({'de': id, 'seq': ++_seqPing, 't': DateTime.now().millisecondsSinceEpoch}));
      await Future<void>.delayed(intervalle);
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    if (_pings.isEmpty) {
      noter('mesure', 'Ping : aucune réponse (aucun autre appareil en ligne ?)');
    }
    _pings.forEach((p, ms) {
      noter('mesure', 'Ping ${nomDe(p)} : ${ms.length}/$nombre réponses · ${_stats(ms)}');
    });
  }

  void _recevoirPong(Map<String, dynamic> m, Pair pair) {
    if ((m['seq'] as int) < _pingDebut) return;
    (_pings[pair.id] ??= []).add(DateTime.now().millisecondsSinceEpoch - (m['t'] as int));
  }

  String _stats(List<int> ms) {
    if (ms.isEmpty) return 'aucune mesure';
    final s = [...ms]..sort();
    final moy = s.reduce((a, b) => a + b) / s.length;
    return 'aller-retour min ${s.first} ms, moyen ${moy.round()} ms, max ${s.last} ms';
  }

  // Volume : N lignes créées d'un coup, temps jusqu'à l'accusé de chaque appareil.
  ({int seqDebut, int total, int t0, Set<String> finis, Completer<void> fin})? _volume;

  Future<void> essaiVolume(int nombre) async {
    final enLigne = pairs.values.where((p) => p.enLigne).toList();
    noter('mesure', 'Volume : création de $nombre lignes…');
    final t0 = DateTime.now();
    final articles = [for (var i = 1; i <= nombre; i++) ('Article $i', 1 + i % 5)];
    final seqDebut = _seq + 1;
    final fin = Completer<void>();
    _volume = (seqDebut: seqDebut, total: nombre + 1, t0: t0.millisecondsSinceEpoch, finis: <String>{}, fin: fin);
    await ajouterListe('Volume $nombre (${_heure(t0)})', articles: articles);
    final ecrit = DateTime.now().difference(t0).inMilliseconds;
    noter('mesure', 'Volume : écrit en base et publié en $ecrit ms (${_seq - seqDebut + 1} lots)');
    if (enLigne.isEmpty) {
      noter('mesure', 'Volume : aucun autre appareil en ligne, pas de mesure de réception');
      _volume = null;
      return;
    }
    await fin.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    final v = _volume!;
    for (final p in enLigne) {
      if (!v.finis.contains(p.id)) {
        final recu = (_accuses[p.id] ?? {}).entries.where((e) => e.key >= v.seqDebut).fold<int>(0, (s, e) => s + e.value.$1);
        noter('mesure', 'Volume : ${p.nom} n\'a confirmé que $recu/${v.total} changements au bout de 3 minutes');
      }
    }
    _volume = null;
  }

  void _verifierVolume() {
    final v = _volume;
    if (v == null) return;
    _accuses.forEach((p, parSeq) {
      if (v.finis.contains(p)) return;
      final recu = parSeq.entries.where((e) => e.key >= v.seqDebut).fold<int>(0, (s, e) => s + e.value.$1);
      if (recu >= v.total) {
        v.finis.add(p);
        final ms = DateTime.now().millisecondsSinceEpoch - v.t0;
        noter('mesure',
            'Volume : ${nomDe(p)} a reçu et enregistré les ${v.total} changements en ${ms} ms (${(v.total * 1000 / max(ms, 1)).round()} changements/s)');
      }
    });
    final attendus = pairs.values.where((p) => p.enLigne).map((p) => p.id).toSet();
    if (attendus.difference(v.finis).isEmpty && !v.fin.isCompleted) v.fin.complete();
  }

  // Endurance : une modification à intervalle régulier pendant une durée donnée.
  bool enduranceEnCours = false;
  bool _arreterEndurance = false;

  Future<void> essaiEndurance(Duration duree, Duration intervalle) async {
    enduranceEnCours = true;
    _arreterEndurance = false;
    notifyListeners();
    final lid = await ajouterListe('Endurance (${_heure(DateTime.now())})',
        articles: [for (var i = 1; i <= 20; i++) ('Produit $i', 1)]);
    final ids = [for (final r in await crdt.query('SELECT id FROM lignes WHERE liste_id = ?1', [lid])) r['id'] as String];
    final seqDebut = _seq + 1;
    final fin = DateTime.now().add(duree);
    var nb = 0;
    noter('mesure', 'Endurance : une modification toutes les ${intervalle.inSeconds} s pendant ${duree.inMinutes} min');
    while (DateTime.now().isBefore(fin) && !_arreterEndurance) {
      final l = ids[_alea.nextInt(ids.length)];
      await crdt.execute('UPDATE lignes SET quantite = quantite + 1, par = ?1 WHERE id = ?2', [nom, l]);
      await envoyerModifs();
      nb++;
      await Future<void>.delayed(intervalle);
    }
    await Future<void>.delayed(const Duration(seconds: 5));
    final envoyes = _envois.keys.where((s) => s >= seqDebut).length;
    noter('mesure', 'Endurance terminée : $nb modifications, $envoyes lots envoyés');
    for (final p in pairs.values) {
      final recus = (_accuses[p.id] ?? {}).entries.where((e) => e.key >= seqDebut);
      final acc = recus.length;
      final rtt = [for (final e in recus) e.value.$2];
      if (acc == 0 && !p.enLigne) continue;
      noter('mesure', 'Endurance ${p.nom} : $acc/$envoyes lots confirmés, ${envoyes - acc} manquants · ${_stats(rtt)}');
    }
    enduranceEnCours = false;
    notifyListeners();
  }

  void arreterEndurance() => _arreterEndurance = true;

  // Simulation : courses jouées ligne par ligne à partir d'une liste existante.
  bool simulationEnCours = false;

  Future<void> simulerCourses(String listeId, Duration intervalle) async {
    simulationEnCours = true;
    notifyListeners();
    final lignes = await crdt.query(
        'SELECT id, article FROM lignes WHERE liste_id = ?1 AND is_deleted = 0 AND coche = 0 ORDER BY article', [listeId]);
    noter('mesure', 'Simulation : ${lignes.length} articles à cocher, un toutes les ${intervalle.inMilliseconds} ms');
    for (final l in lignes) {
      if (!simulationEnCours) break;
      await cocher(l['id'] as String, true);
      await Future<void>.delayed(intervalle);
    }
    noter('mesure', 'Simulation terminée');
    simulationEnCours = false;
    notifyListeners();
  }

  void arreterSimulation() {
    simulationEnCours = false;
    notifyListeners();
  }

  /// Une ligne par article ; un nombre en début ou en fin de ligne donne la quantité.
  static List<(String, int)> lireArticles(String texte) {
    final res = <(String, int)>[];
    for (var l in const LineSplitter().convert(texte)) {
      l = l.trim().replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (l.isEmpty) continue;
      var q = 1;
      final debut = RegExp(r'^(\d+)\s*(x\s+)?(.+)$').firstMatch(l);
      final fin = RegExp(r'^(.+?)\s+x?(\d+)$').firstMatch(l);
      if (debut != null) {
        q = int.parse(debut.group(1)!);
        l = debut.group(3)!;
      } else if (fin != null) {
        q = int.parse(fin.group(2)!);
        l = fin.group(1)!;
      }
      res.add((l, q.clamp(1, 999)));
    }
    return res;
  }

  String _heure(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
