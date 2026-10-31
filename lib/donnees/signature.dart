import 'dart:convert';

import 'package:cryptography/cryptography.dart';

// Signature du catalogue commun par l'éditeur (31/10/2026).
// Le mot de passe du serveur est le même pour toutes les applications : n'importe qui pourrait déposer un faux
// catalogue commun. L'éditeur le signe donc (Ed25519) avec une clé tirée d'une phrase que lui seul connaît ;
// chaque application vérifie la signature avec la clé publique ci-dessous, et refuse un catalogue mal signé.
// Tant que la clé publique est vide, les catalogues non signés restent acceptés (passage en douceur).

/// Clé publique de l'éditeur (base 64), donnée par l'écran « Catalogue commun › Clé de signature ».
const clePubliqueEditeur = '';

class SignatureEditeur {
  static final _ed = Ed25519();

  /// Graine de la clé (32 octets, base 64), tirée de la phrase : longue à calculer, pour décourager les essais.
  static Future<String> graine(String phrase) async {
    final k = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256)
        .deriveKeyFromPassword(password: phrase.trim(), nonce: utf8.encode('liste-de-courses/editeur-du-catalogue'));
    return base64Encode(await k.extractBytes());
  }

  static Future<SimpleKeyPair> _paire(String graine) => _ed.newKeyPairFromSeed(base64Decode(graine));

  static Future<String> clePublique(String graine) async =>
      base64Encode((await (await _paire(graine)).extractPublicKey()).bytes);

  /// Le texte publié, précédé de sa signature : « sig:<signature>: » + texte.
  static Future<String> signer(String texte, String graine) async {
    final s = await _ed.sign(utf8.encode(texte), keyPair: await _paire(graine));
    return 'sig:${base64Encode(s.bytes)}:$texte';
  }

  /// Le texte signé sans sa signature (inchangé s'il n'est pas signé).
  static String contenu(String publie) {
    if (!publie.startsWith('sig:')) return publie;
    final i = publie.indexOf(':', 4);
    return i < 0 ? '' : publie.substring(i + 1);
  }

  /// Vrai si [publie] est signé par la clé [cle] (base 64) ; sans clé, tout est accepté.
  static Future<bool> verifie(String publie, {String cle = clePubliqueEditeur}) async {
    if (cle.isEmpty) return true;
    if (!publie.startsWith('sig:')) return false;
    final i = publie.indexOf(':', 4);
    if (i < 0) return false;
    try {
      return await _ed.verify(
        utf8.encode(publie.substring(i + 1)),
        signature: Signature(base64Decode(publie.substring(4, i)),
            publicKey: SimplePublicKey(base64Decode(cle), type: KeyPairType.ed25519)),
      );
    } catch (_) {
      return false;
    }
  }
}
