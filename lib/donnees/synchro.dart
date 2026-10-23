// Partage du foyer entre appareils : chaque appareil garde sa base locale (stockage.dart) et
// les modifications circulent par un serveur MQTT (QoS 1, session persistante).
//
// Canaux, sous « ldc/<code de partage>/ » :
//   presence/<appareil>  en ligne / hors ligne (retenu, testament MQTT)
//   modifs/<appareil>    lots d'objets modifiés (une ligne de table = un objet)
//   bonjour              à la connexion : « voici ce que je connais déjà » ; les autres renvoient le reste
//
// Chaque objet porte une horloge hybride (heure + compteur + appareil) : en cas de modifications
// simultanées du même objet, la plus récente l'emporte, sur tous les appareils.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'modele.dart';
import 'stockage.dart';

/// Horloge hybride : « heure en ms (15 chiffres) - compteur (5 chiffres) - appareil ».
/// Les chaînes se comparent dans l'ordre des événements, même si les montres des appareils diffèrent.
class Horloge {
  Horloge(this.noeud, {String dernier = ''}) {
    if (dernier.length > 21) recevoir(dernier);
  }
  final String noeud;
  int _ms = 0, _n = 0;

  String suivante() {
    final m = DateTime.now().millisecondsSinceEpoch;
    if (m > _ms) {
      _ms = m;
      _n = 0;
    } else {
      _n++;
    }
    return '${_ms.toString().padLeft(15, '0')}-${_n.toString().padLeft(5, '0')}-$noeud';
  }

  /// Une modification reçue d'ailleurs : les suivantes d'ici seront plus récentes.
  void recevoir(String hlc) {
    final m = int.tryParse(hlc.substring(0, 15)) ?? 0, n = int.tryParse(hlc.substring(16, 21)) ?? 0;
    if (m > _ms || (m == _ms && n > _n)) {
      _ms = m;
      _n = n;
    }
  }
}

/// Serveur MQTT ; par défaut le serveur public de HiveMQ.
class ServeurMqtt {
  const ServeurMqtt({this.hote = hoteHiveMq, this.port = 8883, this.tls = true, this.utilisateur = '', this.motDePasse = ''});
  static const hoteHiveMq = 'broker.hivemq.com';
  final String hote;
  final int port;
  final bool tls;
  final String utilisateur, motDePasse;
}

/// Le réseau, isolé pour pouvoir essayer la synchronisation sans serveur.
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
  Evenement(this.texte, {this.erreur = false}) : t = DateTime.now();
  final DateTime t;
  final String texte;
  final bool erreur;
}

class Appareil {
  Appareil(this.id);
  final String id;
  String nom = '?';
  bool enLigne = false;
}

class Synchro extends ChangeNotifier {
  Synchro._();
  static final Synchro instance = Synchro._();

  /// Remplaçable dans les essais.
  Transport Function(ServeurMqtt) fabrique = TransportMqtt.new;

  static const tailleLot = 300;

  Etat get _etat => Etat.instance;
  Stockage? get _base => _etat.stockageFoyer;

  Transport? _transport;
  final _abonnements = <StreamSubscription>[];
  Timer? _envoiDiffere, _receptionDifferee;
  final _recus = <Map<String, dynamic>>[];
  bool _envoiEnCours = false, _envoiARefaire = false;

  /// 'arrete', 'connexion', 'connecte', 'deconnecte'.
  String etatReseau = 'arrete';
  String? derniereErreur;
  final journal = <Evenement>[];
  final appareils = <String, Appareil>{};
  int envoyes = 0, recus = 0;

  // ------------------------------------------------------------ Réglages (base du foyer)

  String? _reglage(String cle) => _base?.reglage('synchro_$cle');
  void _definir(String cle, String valeur) => _base?.definirReglage('synchro_$cle', valeur);

  String? get code => _reglage('code');
  bool get actif => code != null;
  String get noeud => _reglage('noeud') ?? '';

  ServeurMqtt get serveur => ServeurMqtt(
        hote: _reglage('hote') ?? ServeurMqtt.hoteHiveMq,
        port: int.tryParse(_reglage('port') ?? '') ?? 8883,
        tls: _reglage('tls') != '0',
        utilisateur: _reglage('utilisateur') ?? '',
        motDePasse: _reglage('mdp') ?? '',
      );

  String get _sujet => 'ldc/$code';
  String get nomAppareil {
    final systeme = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iPhone'
            : Platform.isWindows
                ? 'Windows'
                : Platform.operatingSystem;
    return '${_etat.moi.nomAffiche} · $systeme';
  }

  int get enAttente => _base?.nbEnAttente ?? 0;

  // ------------------------------------------------------------ Démarrage et arrêt

  /// Au lancement de l'application : reprend le partage s'il est en place.
  Future<void> demarrer() async {
    _etat.surEnregistrement = signaler;
    if (actif) await _connecter();
  }

  /// Premier appareil : crée le code de partage et prépare l'envoi de tout le foyer.
  Future<void> creerPartage() async {
    final base = _base;
    if (base == null) return;
    _definir('code', _tirer(10));
    _definir('noeud', _tirer(12));
    base.horloge = Horloge(noeud);
    base.toutJournaliser(_etat.versJson());
    _noter('Partage créé : code ${code!}');
    await _connecter();
  }

  /// Autre appareil : remplace les données de cet appareil par celles du foyer qui partage [codePartage].
  Future<void> rejoindre(String codePartage, String nom) async {
    final ancien = serveur;
    await _deconnecter();
    await _etat.rejoindreFoyer(nom);
    final base = _base!;
    _definir('code', codePartage.trim().toUpperCase());
    _definir('noeud', _tirer(12));
    _definirServeur(ancien);
    base.horloge = Horloge(noeud);
    base.toutJournaliser(_etat.versJson(), tables: {'membre'});
    _noter('Foyer rejoint avec le code $code : réception des données…');
    await _connecter();
  }

  /// Cet appareil ne partage plus : ses données restent, elles ne circulent plus.
  Future<void> arreterPartage() async {
    await _deconnecter();
    _base?.effacerReglage('synchro_code');
    _base?.horloge = null;
    etatReseau = 'arrete';
    appareils.clear();
    _noter('Partage arrêté sur cet appareil');
  }

  Future<void> changerServeur(ServeurMqtt s) async {
    _definirServeur(s);
    if (actif) {
      await _deconnecter();
      await _connecter();
    }
    notifyListeners();
  }

  void _definirServeur(ServeurMqtt s) {
    _definir('hote', s.hote.trim());
    _definir('port', '${s.port}');
    _definir('tls', s.tls ? '1' : '0');
    _definir('utilisateur', s.utilisateur);
    _definir('mdp', s.motDePasse);
  }

  /// Renvoie tout ce que cet appareil connaît (après un changement de serveur, par exemple).
  void toutRenvoyer() {
    final base = _base;
    if (base == null || !(_transport?.connecte ?? false)) return;
    final objets = [for (final n in base.connus().keys) ...base.objetsDe(n, '')];
    _publier(objets);
    _noter('Tout renvoyé : ${objets.length} objets');
  }

  Future<void> _connecter() async {
    final base = _base;
    if (base == null || !actif) return;
    base.horloge ??= Horloge(noeud, dernier: base.connus()[noeud] ?? '');
    final t = _transport = fabrique(serveur);
    _abonnements
      ..add(t.messages.listen((m) => _recevoir(m.$1, m.$2)))
      ..add(t.etats.listen((e) {
        if (e == 'connecte') {
          derniereErreur = null;
          _noter('Connecté à ${serveur.hote}');
          _annoncer();
        } else if (e == 'deconnecte') {
          if (etatReseau == 'connecte') _noter('Hors ligne : les modifications attendent le retour du réseau');
        } else if (e != 'connexion') {
          derniereErreur = e;
          _noter(e, erreur: true);
        }
        if (e == 'connecte' || e == 'deconnecte' || e == 'connexion') etatReseau = e;
        notifyListeners();
      }));
    await t.connecter(
      identifiant: 'ldc-$noeud',
      sujetTestament: '$_sujet/presence/$noeud',
      testament: jsonEncode(_presence(false)),
      abonnement: '$_sujet/#',
    );
  }

  Future<void> _deconnecter() async {
    final t = _transport;
    _transport = null;
    if (t != null && t.connecte) t.publier('$_sujet/presence/$noeud', jsonEncode(_presence(false)), retenu: true);
    for (final a in _abonnements) {
      await a.cancel();
    }
    _abonnements.clear();
    await t?.fermer();
  }

  Map<String, Object?> _presence(bool enLigne) => {'de': noeud, 'nom': nomAppareil, 'enLigne': enLigne};

  void _annoncer() {
    final t = _transport, base = _base;
    if (t == null || base == null) return;
    t.publier('$_sujet/presence/$noeud', jsonEncode(_presence(true)), retenu: true);
    _bonjour();
    envoyerModifs();
  }

  /// « Voici, pour chaque appareil, la modification la plus récente que je connais. »
  void _bonjour() {
    final connus = _base!.connus()..remove(noeud);
    _transport?.publier('$_sujet/bonjour', jsonEncode({'de': noeud, 'nom': nomAppareil, 'connus': connus}));
  }

  // ------------------------------------------------------------ Envoi

  /// Appelé après chaque enregistrement : les modifications partent peu après (regroupées).
  void signaler() {
    if (!actif) return;
    _envoiDiffere?.cancel();
    _envoiDiffere = Timer(const Duration(milliseconds: 300), envoyerModifs);
  }

  void envoyerModifs() {
    final t = _transport, base = _base;
    if (t == null || base == null || !t.connecte) return;
    if (_envoiEnCours) {
      _envoiARefaire = true;
      return;
    }
    _envoiEnCours = true;
    try {
      do {
        _envoiARefaire = false;
        final objets = base.objetsDe(noeud, _reglage('envoi') ?? '');
        if (objets.isEmpty) break;
        _publier(objets);
        _definir('envoi', objets.last['h'] as String);
      } while (_envoiARefaire && t.connecte);
    } finally {
      _envoiEnCours = false;
    }
  }

  void _publier(List<Map<String, Object?>> objets, {String? pour}) {
    final t = _transport;
    if (t == null) return;
    for (var i = 0; i < objets.length; i += tailleLot) {
      final lot = objets.sublist(i, min(i + tailleLot, objets.length));
      t.publier('$_sujet/modifs/$noeud', jsonEncode({'de': noeud, 'pour': pour, 'objets': lot}));
      envoyes += lot.length;
    }
    if (pour == null) _noter('Envoyé : ${_resume(objets)}');
    notifyListeners();
  }

  // ------------------------------------------------------------ Réception

  void _recevoir(String sujet, String contenu) {
    if (!sujet.startsWith('$_sujet/') || contenu.isEmpty) return;
    final type = sujet.substring(_sujet.length + 1).split('/').first;
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(contenu) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final de = m['de'] as String?;
    if (de == null || de == noeud) return;
    final a = appareils[de] ??= Appareil(de);
    a.nom = m['nom'] as String? ?? a.nom;
    switch (type) {
      case 'presence':
        final avant = a.enLigne;
        a.enLigne = m['enLigne'] == true;
        if (!avant && a.enLigne) {
          _noter('${a.nom} est en ligne');
          _bonjour(); // il peut avoir des modifications pour moi
        } else if (avant && !a.enLigne) {
          _noter('${a.nom} est hors ligne');
        }
        notifyListeners();
      case 'bonjour':
        a.enLigne = true;
        _repondre(m, a);
      case 'modifs':
        final pour = m['pour'] as String?;
        if (pour != null && pour != noeud) return;
        a.enLigne = true;
        _recus.addAll([for (final o in m['objets'] as List) Map<String, dynamic>.from(o as Map)]);
        _receptionDifferee ??= Timer(const Duration(milliseconds: 400), _integrer);
    }
  }

  /// Un appareil arrive : il reçoit tout ce qu'il ne connaît pas encore, de tous les appareils.
  void _repondre(Map<String, dynamic> m, Appareil a) {
    final base = _base;
    if (base == null) return;
    final connus = Map<String, dynamic>.from(m['connus'] as Map? ?? {});
    final objets = [
      for (final n in base.connus().keys)
        if (n != a.id) ...base.objetsDe(n, connus[n] as String? ?? ''),
    ];
    if (objets.isEmpty) return;
    _noter('${a.nom} se connecte : ${objets.length} objets à lui envoyer');
    _publier(objets, pour: a.id);
  }

  void _integrer() {
    _receptionDifferee = null;
    final lot = List.of(_recus);
    _recus.clear();
    if (lot.isEmpty) return;
    try {
      final n = _etat.integrerDistant(lot);
      recus += n;
      if (n > 0) _noter('Reçu : ${_resume(lot)}');
      for (final e in _base?.erreurs ?? const <String>[]) {
        debugPrint('Synchronisation, en attente : $e');
      }
    } catch (e) {
      _noter('Réception impossible : $e', erreur: true);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ Divers

  static const _noms = {
    'membre': 'membre', 'magasin': 'magasin', 'rayon': 'rayon', 'secteur': 'secteur', 'marque': 'marque',
    'packaging': 'format', 'produit': 'produit', 'emplacement': 'emplacement', 'parcours': 'parcours',
    'liste': 'liste', 'ligne_liste': 'article de liste', 'ticket': 'ticket', 'parametre': 'réglage', 'foyer': 'foyer',
  };

  String _resume(List<Map<String, dynamic>> objets) {
    final parType = <String, int>{};
    for (final o in objets) {
      final t = _noms[o['t']] ?? 'détail';
      parType[t] = (parType[t] ?? 0) + 1;
    }
    return parType.entries.map((e) => '${e.value} ${e.key}${e.value > 1 && !e.key.endsWith('s') ? 's' : ''}').join(', ');
  }

  void _noter(String texte, {bool erreur = false}) {
    journal.insert(0, Evenement(texte, erreur: erreur));
    if (journal.length > 200) journal.removeLast();
    notifyListeners();
  }

  static String _tirer(int n) {
    const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hasard = Random.secure();
    return List.generate(n, (_) => lettres[hasard.nextInt(lettres.length)]).join();
  }
}

/// Transport réel : client MQTT, QoS 1, session persistante, reconnexion automatique.
class TransportMqtt implements Transport {
  TransportMqtt(this.serveur);
  final ServeurMqtt serveur;

  MqttServerClient? _client;
  final _messages = StreamController<(String, String)>.broadcast();
  final _etats = StreamController<String>.broadcast();
  StreamSubscription? _sub;
  Timer? _relance;
  bool _ferme = false;
  late String _abonnement;

  @override
  Stream<(String, String)> get messages => _messages.stream;
  @override
  Stream<String> get etats => _etats.stream;
  @override
  bool get connecte => _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<void> connecter({
    required String identifiant,
    required String sujetTestament,
    required String testament,
    required String abonnement,
  }) async {
    _abonnement = abonnement;
    final c = MqttServerClient.withPort(serveur.hote, identifiant, serveur.port)
      ..secure = serveur.tls
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..connectTimeoutPeriod = 8000
      ..logging(on: false)
      ..setProtocolV311(); // MQTT 3.1.1, accepté par tous les serveurs
    c.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(identifiant)
        .withWillTopic(sujetTestament)
        .withWillMessage(_ascii(testament)) // le client refuse les accents dans le testament
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain(); // pas de startClean : le serveur garde la session et les messages manqués
    c.onConnected = _connecte;
    c.onAutoReconnect = () => _etats.add('connexion');
    c.onAutoReconnected = _connecte;
    c.onDisconnected = () {
      if (!_ferme) _etats.add('deconnecte');
    };
    _client = c;
    await _premiereConnexion();
  }

  Future<void> _premiereConnexion() async {
    final c = _client!;
    if (_ferme) return;
    _etats.add('connexion');
    try {
      await c.connect(serveur.utilisateur.isEmpty ? null : serveur.utilisateur,
          serveur.motDePasse.isEmpty ? null : serveur.motDePasse);
    } catch (e) {
      final s = '$e';
      _etats.add('Connexion impossible à ${serveur.hote}:${serveur.port} (${s.length > 120 ? '${s.substring(0, 120)}…' : s}),'
          ' nouvel essai dans 15 s');
      _etats.add('deconnecte');
      c.disconnect();
      if (!_ferme) _relance = Timer(const Duration(seconds: 15), _premiereConnexion);
      return;
    }
    await _sub?.cancel();
    _sub = c.updates!.listen((liste) {
      for (final r in liste) {
        final p = r.payload;
        if (p is MqttPublishMessage) {
          _messages.add((r.topic, utf8.decode(p.payload.message, allowMalformed: true)));
        }
      }
    });
  }

  void _connecte() {
    _client!.subscribe(_abonnement, MqttQos.atLeastOnce);
    _etats.add('connecte');
  }

  /// Accents écrits en \\uXXXX : le JSON reste identique une fois relu.
  String _ascii(String s) => s.replaceAllMapped(
      RegExp(r'[^\x00-\x7F]'), (m) => m[0]!.codeUnits.map((c) => '\\u${c.toRadixString(16).padLeft(4, '0')}').join());

  @override
  void publier(String sujet, String contenu, {bool retenu = false}) {
    if (!connecte) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(contenu);
    _client!.publishMessage(sujet, MqttQos.atLeastOnce, b.payload!, retain: retenu);
  }

  @override
  Future<void> fermer() async {
    _ferme = true;
    _relance?.cancel();
    await _sub?.cancel();
    _client?.disconnect();
  }
}
