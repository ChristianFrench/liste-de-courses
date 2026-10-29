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
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'client_mqtt.dart';
import 'modele.dart';
import 'stockage.dart';
import 'version.dart';

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

/// Serveur MQTT ; par défaut celui du projet, dont l'identifiant est fourni à la compilation
/// (secrets GitHub MQTT_UTILISATEUR et MQTT_MOT_DE_PASSE, jamais écrits dans le dépôt).
class ServeurMqtt {
  const ServeurMqtt(
      {this.hote = hoteDefaut,
      this.port = portDefaut,
      this.tls = true,
      this.utilisateur = utilisateurDefaut,
      this.motDePasse = motDePasseDefaut,
      this.empreinte = ''});
  static const hoteDefaut = String.fromEnvironment('MQTT_HOTE', defaultValue: 'w041270a.ala.us-east-1.emqxsl.com');
  static const portDefaut = int.fromEnvironment('MQTT_PORT', defaultValue: 8883);
  static const utilisateurDefaut = String.fromEnvironment('MQTT_UTILISATEUR');
  static const motDePasseDefaut = String.fromEnvironment('MQTT_MOT_DE_PASSE');

  /// Vrai si l'application a reçu l'identifiant du serveur à la compilation.
  static bool get identifiantIntegre => utilisateurDefaut.isNotEmpty;

  /// Réglages saisis à la main (dépannage) : sinon le serveur imposé.
  bool get parDefaut => hote == hoteDefaut && port == portDefaut && utilisateur == utilisateurDefaut;
  final String hote;
  final int port;
  final bool tls;
  final String utilisateur, motDePasse;

  /// Certificat non signé par une autorité (Mosquitto sur le PC) : empreinte SHA-256 acceptée à la
  /// première connexion. Un autre certificat est ensuite refusé tant que l'utilisateur ne l'a pas accepté.
  final String empreinte;

  /// Les 16 premiers chiffres de l'empreinte, comme Verifier-serveur-MQTT.exe les affiche.
  static String empreinteCourte(String hex) =>
      hex.length < 16 ? hex : [for (var i = 0; i < 16; i += 4) hex.substring(i, i + 4).toUpperCase()].join(' ');
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

  /// Membre du foyer qui utilise cet appareil, son système (Windows, Android, Web) et la version.
  String? membreId, plateforme, version;

  /// Dernière connexion connue.
  DateTime? vu;

  /// Avance de son horloge sur la nôtre, en secondes (annoncée avec sa présence).
  int? decalage;
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

  /// Vrai quand un message de contrôle envoyé au serveur est bien revenu (échange réel, pas seulement
  /// la connexion) ; vérifié à la connexion puis toutes les 30 s.
  bool liaisonOk = false;
  DateTime? derniereVerification;
  int? dureeVerification; // aller-retour en ms
  Timer? _controle, _delaiControle;
  int _envoiControle = 0;
  String? derniereErreur;

  /// Empreinte d'un certificat refusé parce qu'il diffère de celui accepté au départ.
  String? certificatRefuse;
  /// Des modifications partent ou arrivent en ce moment (le point vert clignote).
  bool enEchange = false;
  Timer? _finEchange;

  void _marquerEchange() {
    _finEchange?.cancel();
    if (!enEchange) {
      enEchange = true;
      notifyListeners();
    }
    _finEchange = Timer(const Duration(seconds: 2), () {
      enEchange = false;
      notifyListeners();
    });
  }

  /// Appareils vus d'un membre du foyer (sa présence l'indique ; avant le 26/10/2026, d'après son nom).
  List<Appareil> appareilsDe(Membre m) => [
        for (final a in appareils.values)
          if (a.membreId == m.id || (a.membreId == null && a.nom.split(' · ').first == m.nomAffiche)) a
      ];

  /// Nom affiché d'un appareil : le nom actuel de son membre (il a pu être renommé), puis son système.
  String nomDe(Appareil a) {
    final m = _etat.membre(a.membreId);
    if (m == null) return a.nom;
    return '${m.nomAffiche} · ${a.plateforme ?? a.nom.split(' · ').last}';
  }

  /// « exe », « apk » ou « web » selon le système, suivi de la version.
  static String libelleVersion(String? plateforme, String? version) {
    final p = switch (plateforme) { 'Windows' => 'exe', 'Android' => 'apk', 'Web' => 'web', null => '?', _ => plateforme };
    return version == null ? p : '$p $version';
  }

  /// Cet appareil : « apk 0.6.0 ».
  String get maVersion => libelleVersion(nomSysteme, versionApplication);

    /// Autres appareils du foyer connectés en ce moment.
  int get autresEnLigne => appareils.values.where((a) => a.enLigne).length;

  /// Couleur du point de l'icône : blanc (pas de partage), rouge (pas de serveur ou de réseau),
  /// orange (aucun autre appareil connecté), vert (synchronisé avec au moins un autre appareil).
  String get pastille => !actif
      ? 'blanc'
      : !liaisonOk
          ? 'rouge'
          : autresEnLigne == 0
              ? 'orange'
              : 'vert';

  final journal = <Evenement>[];
  final appareils = <String, Appareil>{};
  int envoyes = 0, recus = 0;

  // ------------------------------------------------------------ Réglages (base du foyer)

  String? _reglage(String cle) => _base?.reglage('synchro_$cle');
  void _definir(String cle, String valeur) => _base?.definirReglage('synchro_$cle', valeur);

  String? get code => _reglage('code');

  /// 'maitre' : appareil qui a créé le partage ; 'esclave' : appareil qui l'a rejoint.
  /// « maitre » sur l'appareil qui a créé le partage, « esclave » sur ceux qui l'ont rejoint.
  /// Un partage créé avant que le rôle soit noté : l'appareil qui a envoyé la fiche du foyer est le maître.
  String? get role {
    final r = _reglage('role');
    if (r != null || !actif) return r;
    final auteur = _base?.auteurFoyer();
    if (auteur == null || noeud.isEmpty) return null;
    final deduit = auteur == noeud ? 'maitre' : 'esclave';
    _definir('role', deduit);
    return deduit;
  }
  bool get actif => code != null;

  /// 'seul' : pas de synchronisation ; 'foyer' : données partagées ; '' : pas encore choisi
  /// (écran d'accueil du premier lancement). Sans base (essais), 'foyer'.
  String get mode {
    if (_base == null) return 'foyer';
    return _reglage('mode') ?? (actif ? 'foyer' : '');
  }

  /// Le partage s'est arrêté sans que cet appareil le demande : 'code' (code régénéré par
  /// l'administrateur) ou 'radie' (membre radié). Il faut saisir le code de partage pour revenir.
  String? get suspendu => _reglage('suspendu');

  String get noeud => _reglage('noeud') ?? '';

  ServeurMqtt get serveur {
    final hote = _reglage('hote') ?? '';
    // Serveur imposé, sauf réglage de dépannage (« Avancé ») ou ancien serveur saisi à la main.
    if (hote.isEmpty) return ServeurMqtt(empreinte: _reglage('empreinte') ?? '');
    final u = _reglage('utilisateur') ?? '';
    final memeServeur = hote == ServeurMqtt.hoteDefaut;
    return ServeurMqtt(
      hote: hote,
      port: int.tryParse(_reglage('port') ?? '') ?? 8883,
      tls: _reglage('tls') != '0',
      utilisateur: u.isEmpty && memeServeur ? ServeurMqtt.utilisateurDefaut : u,
      motDePasse: u.isEmpty && memeServeur ? ServeurMqtt.motDePasseDefaut : (_reglage('mdp') ?? ''),
      empreinte: _reglage('empreinte') ?? '',
    );
  }

  /// Revient au serveur imposé (efface les réglages de dépannage).
  Future<void> serveurParDefaut() async {
    for (final c in ['hote', 'port', 'tls', 'utilisateur', 'mdp', 'empreinte']) {
      _base?.effacerReglage('synchro_$c');
    }
    certificatRefuse = null;
    if (actif) {
      await _deconnecter();
      await _connecter();
    }
    notifyListeners();
  }

  String get _sujet => 'ldc/$code';
  String get nomAppareil {
    return '${_etat.moi.nomAffiche} · $nomSysteme';
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
    base.viderJournal();
    base.effacerReglage('synchro_envoi');
    _definir('code', _tirer(10));
    _definir('role', 'maitre');
    _definir('noeud', _tirer(12));
    base.horloge = Horloge(noeud);
    base.toutJournaliser(base.lire());
    _noter('Partage créé : code ${code!}');
    await _connecter();
  }

  /// Autre appareil : remplace les données de cet appareil par celles du foyer qui partage [codePartage].
  /// Les produits ajoutés et les listes non terminées de cet appareil sont gardés et ajoutés au foyer.
  Future<void> rejoindre(String codePartage, String nom, {String email = ''}) async {
    final ancien = _base?.reglage('synchro_hote') == null ? null : serveur;
    final garder = _etat.magasins.isEmpty ? null : _etat.aReprendre();
    await _deconnecter();
    await _etat.rejoindreFoyer(nom, email: email);
    final base = _base!;
    _definir('code', codePartage.trim().toUpperCase());
    _definir('role', 'esclave');
    _definir('mode', 'foyer');
    _definir('noeud', _tirer(12));
    if (garder != null) _definir('a_reprendre', jsonEncode(garder));
    if (ancien != null) _definirServeur(ancien);
    base.horloge = Horloge(noeud);
    base.toutJournaliser(_etat.versJson(), tables: {'membre'});
    _noter('Foyer rejoint avec le code $code : réception des données…');
    await _connecter();
  }

  // ------------------------------------------------------------ Seul ou en foyer (26/10/2026)

  /// Premier lancement ou changement : cet appareil fonctionne seul, sans synchronisation.
  Future<void> choisirSeul() async {
    if (actif) await arreterPartage();
    _definir('mode', 'seul');
    _base?.effacerReglage('synchro_suspendu');
    notifyListeners();
  }

  static String _cleNom(String nom) => nom
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[^a-z0-9]+'), '-');

  /// Vérifie sur le serveur qu'aucun foyer ne porte déjà ce nom (annuaire des noms, sans données).
  /// Rend null si le nom est libre, sinon la raison du refus.
  Future<String?> verifierNomFoyer(String nom) async {
    final cle = _cleNom(nom);
    if (cle.replaceAll('-', '').isEmpty) return 'Saisissez le nom du foyer.';
    final t = fabrique(serveur);
    final pris = Completer<bool>();
    final abonnements = [
      t.messages.listen((m) {
        if (m.$1 == 'ldc/annuaire/$cle' && m.$2.isNotEmpty && !pris.isCompleted) pris.complete(true);
      }),
      t.etats.listen((e) {
        // Connecté : un nom déjà pris arrive aussitôt (message retenu) ; sinon, libre après 3 s.
        if (e == 'connecte') Timer(const Duration(seconds: 3), () => pris.isCompleted ? null : pris.complete(false));
      }),
    ];
    try {
      await t.connecter(
        identifiant: 'ldc-verif-${_tirer(8)}',
        sujetTestament: 'ldc/verif',
        testament: '',
        abonnement: 'ldc/annuaire/$cle',
      );
      final r = await pris.future.timeout(const Duration(seconds: 15));
      return r ? 'Un foyer porte déjà ce nom. Choisissez-en un autre.' : null;
    } on TimeoutException {
      return 'Le serveur ne répond pas. Vérifiez la connexion à internet et réessayez.';
    } finally {
      for (final a in abonnements) {
        await a.cancel();
      }
      await t.fermer();
    }
  }

  /// Créer un foyer : toutes ses données deviennent celles du foyer.
  /// Rend null si c'est fait, sinon la raison du refus.
  /// [reprendreNom] : le nom a déjà servi (ancien foyer de la famille) et on le reprend ; les données ne se
  /// mélangent pas, chaque foyer ayant son propre code.
  Future<String?> creerFoyer(String nom, String email, {bool reprendreNom = false}) async {
    if (!reprendreNom) {
      final refus = await verifierNomFoyer(nom);
      if (refus != null) return refus;
    }
    _etat.renommerFoyer(nom.trim());
    _etat.modifierEmail(_etat.moi, email);
    _etat.moi.role = 'administrateur';
    _etat.statutsMembres.clear();
    _etat.modifie();
    _definir('mode', 'foyer');
    _base?.effacerReglage('synchro_suspendu');
    _annuaire = _cleNom(nom);
    await creerPartage();
    return null;
  }

  /// Nom du foyer à inscrire dans l'annuaire dès la connexion.
  String? _annuaire;

  /// Administrateur : un nouveau code remplace l'ancien. Les autres appareils s'arrêtent et
  /// demandent le nouveau code ; leurs données restent.
  Future<void> regenererCode() async {
    if (!actif) return;
    _transport?.publier('$_sujet/ferme', jsonEncode({'de': noeud, 'heure': DateTime.now().millisecondsSinceEpoch}),
        retenu: true);
    _transport?.publier('$_sujet/presence/$noeud', '', retenu: true);
    await _deconnecter(presence: false);
    appareils.clear();
    _definir('code', _tirer(10));
    _noter('Nouveau code de partage : ${code!}');
    await _connecter();
  }

  /// Revenir dans le foyer avec le code de partage (après un code régénéré ou un retrait du foyer) :
  /// les données de cet appareil sont gardées.
  Future<void> reprendreAvecCode(String codePartage) async {
    final raison = suspendu;
    _definir('code', codePartage.trim().toUpperCase());
    _definir('mode', 'foyer');
    _base?.effacerReglage('synchro_suspendu');
    if (raison == 'radie') _definir('rejoint', '1');
    _noter('Retour dans le foyer avec le code $code');
    await _connecter();
    notifyListeners();
  }

  /// Le partage s'arrête sans que cet appareil l'ait demandé ; ses données restent.
  Future<void> _suspendre(String raison) async {
    if (!actif) return;
    _transport?.publier('$_sujet/presence/$noeud', '', retenu: true);
    await _deconnecter(presence: false);
    _base?.effacerReglage('synchro_code');
    _definir('suspendu', raison);
    etatReseau = 'arrete';
    appareils.clear();
    _noter(raison == 'code'
        ? 'Le code de partage a changé : saisissez le nouveau code'
        : 'Cette personne a été retirée du foyer par un autre membre');
  }

  /// Après une réception : retour d'un membre radié, reprise des données gardées, radiation.
  Timer? _apresReception;
  void _verifierApresReception() {
    _apresReception?.cancel();
    _apresReception = Timer(const Duration(seconds: 4), () {
      if (!actif) return;
      if (_reglage('rejoint') != null && _etat.moiExclu) {
        _etat.reactiverMembre(_etat.moi);
      }
      _base?.effacerReglage('synchro_rejoint');
      final a = _reglage('a_reprendre');
      if (a != null) {
        try {
          if (_etat.reprendre(jsonDecode(a) as Map<String, dynamic>)) _base?.effacerReglage('synchro_a_reprendre');
        } catch (e) {
          _base?.effacerReglage('synchro_a_reprendre');
          _noter('Reprise des données de cet appareil impossible : $e', erreur: true);
        }
      }
      if (_etat.moiExclu) _suspendre('radie');
    });
  }

  /// Cet appareil ne partage plus : ses données restent, elles ne circulent plus.
  /// Après un changement de base (foyer neuf) : l'écran d'accueil (seul, créer, rejoindre) se réaffiche.
  void rafraichir() => notifyListeners();

  /// Repartir d'un foyer neuf : le nom du foyer est libéré dans l'annuaire (il pourra être repris), puis le partage s'arrête.
  Future<void> libererNomEtArreter() async {
    final cle = _cleNom(_etat.foyerNom);
    if (cle.replaceAll('-', '').isNotEmpty) _transport?.publier('ldc/annuaire/$cle', '', retenu: true);
    await arreterPartage();
  }

  Future<void> arreterPartage() async {
    // La présence gardée par le serveur est effacée : les autres ne voient plus cet appareil.
    _transport?.publier('$_sujet/presence/$noeud', '', retenu: true);
    await _deconnecter(presence: false);
    _base?.effacerReglage('synchro_code');
    _base?.effacerReglage('synchro_role');
    _base?.horloge = null;
    etatReseau = 'arrete';
    appareils.clear();
    _noter('Partage arrêté sur cet appareil');
  }

  /// Retire de la liste un appareil hors ligne (il a quitté le partage ou rejoint sous un autre nom).
  void oublier(String id) {
    _transport?.publier('$_sujet/presence/$id', '', retenu: true);
    appareils.remove(id);
    notifyListeners();
  }

  Future<void> changerServeur(ServeurMqtt s) async {
    final avant = serveur;
    // Autre serveur : son certificat sera accepté à la première connexion
    if (s.hote.trim() != avant.hote || s.port != avant.port) _base?.effacerReglage('synchro_empreinte');
    certificatRefuse = null;
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

  /// Le serveur présente un autre certificat que celui accepté au départ : l'utilisateur le confirme.
  Future<void> accepterCertificat() async {
    final e = certificatRefuse;
    if (e == null) return;
    _definir('empreinte', e);
    certificatRefuse = null;
    _noter('Nouveau certificat du serveur accepté : ${ServeurMqtt.empreinteCourte(e)}');
    if (actif) {
      await _deconnecter();
      await _connecter();
    }
    notifyListeners();
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
      ..add(t.messages.listen((m) => _sansPanne('la réception (${m.$1.split('/').skip(2).join('/')})', () => _recevoir(m.$1, m.$2))))
      ..add(t.etats.listen((e) {
        if (e.startsWith('certificat:')) {
          final empreinte = e.substring(11);
          _definir('empreinte', empreinte);
          _noter('Certificat du serveur accepté : ${ServeurMqtt.empreinteCourte(empreinte)}');
          return;
        }
        if (e.startsWith('info:')) {
          _noter(e.substring(5));
          return;
        }
        if (e.startsWith('certificat-refuse:')) {
          certificatRefuse = e.substring(18);
          _noter('Le serveur présente un autre certificat (${ServeurMqtt.empreinteCourte(certificatRefuse!)}) : connexion refusée',
              erreur: true);
          return;
        }
        if (e == 'connecte') {
          certificatRefuse = null;
          derniereErreur = null;
          _noter('Connecté à ${serveur.hote}');
          if (_annuaire case final cle?) {
            t.publier('ldc/annuaire/$cle', jsonEncode({'cree': DateTime.now().millisecondsSinceEpoch}), retenu: true);
            _annuaire = null;
          }
          // Le contrôle d'abord : une erreur à l'annonce (29/10/2026, web) le laissait sans minuterie,
          // voyant rouge sans explication.
          _controler();
          _controle?.cancel();
          _controle = Timer.periodic(const Duration(seconds: 30), (_) => _controler());
          _sansPanne('l\'annonce aux autres appareils', _annoncer);
        } else if (e == 'deconnecte') {
          if (etatReseau == 'connecte') _noter('Hors ligne : les modifications attendent le retour du réseau');
          liaisonOk = false;
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

  /// Essais : simule l'arrêt de l'application.
  @visibleForTesting
  Future<void> deconnecterPourEssai() => _deconnecter();

  Future<void> _deconnecter({bool presence = true}) async {
    final t = _transport;
    _transport = null;
    _controle?.cancel();
    _delaiControle?.cancel();
    liaisonOk = false;
    if (presence && t != null && t.connecte) t.publier('$_sujet/presence/$noeud', jsonEncode(_presence(false)), retenu: true);
    for (final a in _abonnements) {
      await a.cancel();
    }
    _abonnements.clear();
    await t?.fermer();
  }

  int _pannes = 0;

  /// Une erreur imprévue est écrite dans le journal (les 20 premières) au lieu d'arrêter l'échange en silence.
  void _sansPanne(String quoi, void Function() faire) {
    try {
      faire();
    } catch (e) {
      // Base du navigateur abîmée dans le journal d'échange (29/10/2026) : réparée une fois, puis on réessaie.
      final base = _base;
      if (_journalRepare || base == null || !'$e'.contains('malformed')) {
        _signalerPanne(quoi, e, StackTrace.current);
        return;
      }
      _journalRepare = true;
      _noter('Base abîmée pendant $quoi : réparation du journal d\'échange…', erreur: true);
      try {
        _noter('Journal d\'échange réparé : ${base.reparerJournal()}');
        faire();
      } catch (e2, pile) {
        _signalerPanne('la réparation', e2, pile);
      }
    }
  }

  bool _journalRepare = false;

  void _signalerPanne(String quoi, Object e, StackTrace pile) {
    if (++_pannes <= 20) {
      final texte = '$e';
      _noter('Erreur pendant $quoi : ${texte.length > 200 ? '${texte.substring(0, 200)}…' : texte}', erreur: true);
    }
    debugPrint('$e\n$pile');
  }

  /// Message de contrôle : l'appareil s'écoute lui-même ; s'il revient, le serveur fonctionne.
  void _controler() {
    final t = _transport;
    if (t == null) return;
    if (!t.connecte) {
      _changerLiaison(false);
      return;
    }
    _envoiControle = DateTime.now().millisecondsSinceEpoch;
    t.publier('$_sujet/controle/$noeud', jsonEncode({'de': noeud, 't': _envoiControle}));
    _delaiControle?.cancel();
    _delaiControle = Timer(const Duration(seconds: 10), () {
      if (liaisonOk || !_controleNote) _noter('Contrôle sans retour après 10 s (messages reçus depuis le lancement : $_messagesRecus)', erreur: true);
      _controleNote = true;
      _changerLiaison(false);
      // Navigateur (29/10/2026) : connecté et abonné, mais plus aucun message ne revenait. Deux contrôles
      // perdus de suite : nouvelle connexion, avec une réception repartie de zéro.
      if (++_controlesPerdus >= 2 && identical(_transport, t) && t.connecte) {
        _controlesPerdus = 0;
        _noter('Nouvelle connexion au serveur');
        unawaited(_deconnecter(presence: false).then((_) => _connecter()));
      }
    });
  }

  void _changerLiaison(bool ok) {
    if (ok != liaisonOk) _noter(ok ? 'Échange avec le serveur vérifié' : 'Le serveur ne répond plus', erreur: !ok);
    liaisonOk = ok;
    notifyListeners();
  }

  String? _presenceAnnoncee;

  Map<String, Object?> _presence(bool enLigne) => {
        'de': noeud,
        'nom': nomAppareil,
        'membre': _etat.moi.id,
        'plateforme': nomSysteme,
        'version': versionApplication,
        'enLigne': enLigne,
        'heure': DateTime.now().millisecondsSinceEpoch,
      };

  void _annoncer() {
    final t = _transport, base = _base;
    if (t == null || base == null) return;
    _presenceAnnoncee = '${_etat.moi.id}|$nomAppareil';
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
    _envoiDiffere = Timer(const Duration(milliseconds: 300), () => _sansPanne('l\'envoi des modifications', envoyerModifs));
  }

  void envoyerModifs() {
    final t = _transport, base = _base;
    if (t == null || base == null || !t.connecte) return;
    // Changement de personne ou de nom sur cet appareil : les autres le voient tout de suite.
    final qui = '${_etat.moi.id}|$nomAppareil';
    if (qui != _presenceAnnoncee) {
      _presenceAnnoncee = qui;
      t.publier('$_sujet/presence/$noeud', jsonEncode(_presence(true)), retenu: true);
    }
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
    if (objets.isNotEmpty) _marquerEchange();
    if (pour == null) _noter('Envoyé : ${_resume(objets)}');
    notifyListeners();
  }

  // ------------------------------------------------------------ Réception

  int _messagesRecus = 0, _controlesPerdus = 0;
  bool _controleNote = false;

  void _recevoir(String sujet, String contenu) {
    _messagesRecus++;
    if (!sujet.startsWith('$_sujet/')) return;
    final type = sujet.substring(_sujet.length + 1).split('/').first;
    if (contenu.isEmpty) {
      // Présence effacée : l'appareil a quitté le partage.
      if (type == 'presence' && appareils.remove(sujet.split('/').last) != null) notifyListeners();
      return;
    }
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(contenu) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final de = m['de'] as String?;
    if (type == 'ferme') {
      // Un membre a régénéré le code : ce canal est fermé.
      if (de != noeud) _suspendre('code');
      return;
    }
    if (type == 'controle') {
      if (de == noeud && m['t'] == _envoiControle) {
        _delaiControle?.cancel();
        _controlesPerdus = 0;
        derniereVerification = DateTime.now();
        dureeVerification = derniereVerification!.millisecondsSinceEpoch - _envoiControle;
        _changerLiaison(true);
      }
      return;
    }
    if (de == null || de == noeud) return;
    final a = appareils[de] ??= Appareil(de);
    a.nom = m['nom'] as String? ?? a.nom;
    switch (type) {
      case 'presence':
        final avant = a.enLigne;
        a.enLigne = m['enLigne'] == true;
        final heure = m['heure'] as int?;
        a.membreId = m['membre'] as String? ?? a.membreId;
        a.plateforme = m['plateforme'] as String? ?? a.plateforme;
        a.version = m['version'] as String? ?? a.version;
        if (heure != null) a.vu = DateTime.fromMillisecondsSinceEpoch(heure);
        if (a.enLigne && heure != null) a.decalage = ((heure - DateTime.now().millisecondsSinceEpoch) / 1000).round();
        if (!avant && a.enLigne) {
          _noter('${a.nom} est en ligne');
          _bonjour(); // il peut avoir des modifications pour moi
        } else if (avant && !a.enLigne) {
          _noter('${a.nom} est hors ligne');
        }
        notifyListeners();
      case 'bonjour':
        a.enLigne = true;
        a.vu = DateTime.now();
        _repondre(m, a);
      case 'modifs':
        final pour = m['pour'] as String?;
        if (pour != null && pour != noeud) return;
        a.enLigne = true;
        _marquerEchange();
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
      final ignores = _base?.ignores ?? 0, attente = _base?.nbEnAttente ?? 0;
      final de = {for (final o in lot) appareils[o['n']]?.nom ?? '?'}.join(', ');
      _noter('Reçu de $de : ${_resume(lot)}'
          '${ignores > 0 ? ' ; $ignores déjà plus récents ici, laissés de côté' : ''}'
          '${attente > 0 ? ' ; $attente en attente' : ''}');
      for (final e in _base?.erreurs ?? const <String>[]) {
        debugPrint('Synchronisation, en attente : $e');
      }
      _verifierApresReception();
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

  MqttClient? _client;
  late String _empreinte = serveur.empreinte;
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
    final c = creerClientMqtt(serveur.hote, serveur.port, serveur.tls, identifiant, _certificat)
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
    // Navigateur : session neuve à chaque connexion. Une session gardée côté serveur a bloqué toute
    // réception (29/10/2026) ; les modifications manquées reviennent par « bonjour » (connus).
    if (kIsWeb) c.connectionMessage!.startClean();
    c.onConnected = _connecte;
    c.onSubscribed = (s) => _etats.add('info:Abonnement accepté par le serveur ($s)');
    c.onSubscribeFail = (s) => _etats.add('Abonnement refusé par le serveur ($s)');
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

  /// Certificat non signé par une autorité (Mosquitto sur le PC) : accepté la première fois,
  /// ensuite seulement s'il est le même.
  bool _certificat(List<int> der) {
    final e = sha256.convert(der).toString();
    if (_empreinte.isEmpty) {
      _empreinte = e;
      _etats.add('certificat:$e');
      return true;
    }
    if (e == _empreinte) return true;
    _etats.add('certificat-refuse:$e');
    return false;
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
