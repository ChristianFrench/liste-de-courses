import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import 'synchro.dart';

// Chiffrement par foyer (01/11/2026, demandé par Aristide : « on chiffre »).
// Le mot de passe du serveur est le même pour toutes les applications : sans chiffrement, quiconque le connaît
// pourrait lire les listes d'un foyer. Désormais tout ce qu'un foyer dépose sur le serveur est chiffré (AES-GCM 256)
// avec une clé tirée du code de partage, que seuls les appareils du foyer connaissent. Le code lui-même n'apparaît
// plus dans les sujets : « ldc/<code>/… » devient « ldc/f-<empreinte du code>/… ».
// Le catalogue commun, les apports au catalogue partagé et l'annuaire des noms restent en clair : ils sont faits
// pour être lus par tous.

/// Sujet réel, sur le serveur, d'un foyer : une empreinte du code, qui ne permet pas de le retrouver.
String sujetFoyer(String code) =>
    'ldc/f-${crypto.sha256.convert(utf8.encode('liste-de-courses/sujet/$code')).toString().substring(0, 24)}';

class ChiffreFoyer {
  ChiffreFoyer._(this._cle);
  final SecretKey _cle;
  static final _aes = AesGcm.with256bits();
  static final Map<String, Future<ChiffreFoyer>> _deja = {};

  /// Clé du foyer, tirée du code (longue à calculer, pour décourager les essais ; gardée ensuite en mémoire).
  static Future<ChiffreFoyer> pour(String code) => _deja.putIfAbsent(code, () async {
        final k = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 60000, bits: 256)
            .deriveKeyFromPassword(password: code, nonce: utf8.encode('liste-de-courses/chiffrement-du-foyer'));
        return ChiffreFoyer._(SecretKey(await k.extractBytes()));
      });

  static const prefixe = 'chf:';

  /// « chf: » + base 64 (nonce, texte chiffré, code d'authentification). Un contenu vide reste vide
  /// (il efface un message retenu).
  Future<String> chiffrer(String texte) async {
    if (texte.isEmpty) return '';
    final b = await _aes.encrypt(utf8.encode(texte), secretKey: _cle);
    return '$prefixe${base64Encode(b.concatenation())}';
  }

  /// Le texte en clair, ou null s'il n'est pas chiffré par ce foyer (ancienne version, autre clé, altéré).
  Future<String?> dechiffrer(String publie) async {
    if (publie.isEmpty) return '';
    if (!publie.startsWith(prefixe)) return null;
    try {
      final b = SecretBox.fromConcatenation(base64Decode(publie.substring(prefixe.length)),
          nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
      return utf8.decode(await _aes.decrypt(b, secretKey: _cle));
    } catch (_) {
      return null;
    }
  }
}

/// Transport qui chiffre ce que le foyer publie sous « ldc/<code>/ » et le dépose sous le sujet réel du foyer ;
/// à la réception, il déchiffre et rend les sujets d'origine. Les autres sujets passent tels quels.
class TransportChiffre implements Transport {
  TransportChiffre(this.dessous, this.code) : _chiffre = ChiffreFoyer.pour(code);
  final Transport dessous;
  final String code;
  final Future<ChiffreFoyer> _chiffre;
  Future<void> _file = Future.value();
  Stream<(String, String)>? _messages;

  /// Messages ignorés : non chiffrés ou chiffrés avec une autre clé.
  int ignores = 0;

  String get _logique => 'ldc/$code';
  String get _reel => sujetFoyer(code);

  String _versReel(String sujet) =>
      sujet == _logique || sujet.startsWith('$_logique/') ? '$_reel${sujet.substring(_logique.length)}' : sujet;

  @override
  Stream<(String, String)> get messages => _messages ??= dessous.messages
      .asyncMap<(String, String)?>((m) async {
        if (m.$1 != _reel && !m.$1.startsWith('$_reel/')) return m;
        final clair = await (await _chiffre).dechiffrer(m.$2);
        if (clair == null) {
          ignores++;
          return null;
        }
        return ('$_logique${m.$1.substring(_reel.length)}', clair);
      })
      .where((m) => m != null)
      .map((m) => m!)
      .asBroadcastStream();

  @override
  Stream<String> get etats => dessous.etats;

  @override
  bool get connecte => dessous.connecte;

  @override
  Future<void> connecter({
    required String identifiant,
    required String sujetTestament,
    required String testament,
    required String abonnement,
  }) async {
    final c = await _chiffre;
    final reel = _versReel(sujetTestament);
    await dessous.connecter(
      identifiant: identifiant,
      sujetTestament: reel,
      testament: reel == sujetTestament ? testament : await c.chiffrer(testament),
      abonnement: _versReel(abonnement),
    );
  }

  @override
  void publier(String sujet, String contenu, {bool retenu = false}) {
    // Une file : le chiffrement prend un instant, l'ordre des messages doit rester le même.
    _file = _file.then((_) async {
      final reel = _versReel(sujet);
      dessous.publier(reel, reel == sujet ? contenu : await (await _chiffre).chiffrer(contenu), retenu: retenu);
    }).catchError((Object _) {});
  }

  /// Efface les messages retenus en clair de l'ancienne version (avant le chiffrement), sous « ldc/<code>/ ».
  void effacerAnciens(Iterable<String> suffixes) {
    _file = _file.then((_) {
      for (final s in suffixes) {
        dessous.publier('$_logique/$s', '', retenu: true);
      }
    });
  }

  @override
  Future<void> fermer() async {
    await _file;
    await dessous.fermer();
  }
}
