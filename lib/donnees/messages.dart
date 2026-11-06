import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'modele.dart';
import 'synchro.dart';

// Messages entre les membres du foyer (maquette du 27/10/2026), par le service gratuit ntfy.sh.
// Depuis le 28/10/2026 : chaque membre s'abonne à SON canal dans l'appli ntfy (Android) ou sur ntfy.sh
// (navigateur), et y reçoit messages et notifications même quand Emplettes est fermée. Tout ce qui
// est envoyé passe aussi par le canal du foyer, que personne n'écoute : c'est le journal de l'écran Messages.

/// Un message reçu du canal du foyer : notification ou trace d'un mail (02/11/2026 : expéditeur et
/// destinataires dans les étiquettes « de-… » et « a-… », pour l'historique de chaque membre).
class MessageFoyer {
  MessageFoyer(this.id, this.heure, this.titre, this.texte, {this.de, this.a = const [], this.mail = false});
  final String id;
  final DateTime heure;
  final String titre;
  final String texte;

  /// Membre qui l'a envoyé (null : inconnu).
  final String? de;

  /// Membres destinataires (vide : tout le foyer, anciens messages).
  final List<String> a;
  final bool mail;

  /// Lu depuis une ligne JSON de ntfy (ou du journal gardé sur l'appareil).
  static MessageFoyer? lire(Map m) {
    if (m case {'id': final String id, 'time': final int t}) {
      final tags = [for (final x in (m['tags'] as List? ?? const [])) '$x'];
      final titre = m['title'] as String? ?? '';
      String? de = [for (final x in tags) if (x.startsWith('de-')) x.substring(3)].firstOrNull;
      if (de == null) {
        final nom = titre.split(' · ').first;
        de = Etat.instance.membresVisibles.where((x) => x.nomAffiche == nom).firstOrNull?.id;
      }
      return MessageFoyer(id, DateTime.fromMillisecondsSinceEpoch(t * 1000), titre, m['message'] as String? ?? '',
          de: de, a: [for (final x in tags) if (x.startsWith('a-')) x.substring(2)], mail: tags.contains('mail'));
    }
    return null;
  }

  Map<String, Object?> versJson() => {
        'id': id,
        'time': heure.millisecondsSinceEpoch ~/ 1000,
        'title': titre,
        'message': texte,
        'tags': [if (de != null) 'de-$de', for (final x in a) 'a-$x', if (mail) 'mail'],
      };

  /// Envoyé par [membreId] ?
  bool envoyePar(String membreId) => de == membreId;

  /// Reçu par [membreId] : destinataire nommé, ou message à tout le foyer d'un autre membre.
  bool recuPar(String membreId) => a.isEmpty ? (de != null && de != membreId) : a.contains(membreId);
}

class MessagesFoyer extends ChangeNotifier {
  MessagesFoyer._();
  static final MessagesFoyer instance = MessagesFoyer._();

  /// Domaine du serveur OVH d'Emplettes (secret GitHub VPS_HOTE) : ntfy y tourne depuis le 06/11/2026 ;
  /// sans lui, le service public ntfy.sh comme avant.
  static const domaine = String.fromEnvironment('DOMAINE');
  static const serveur = domaine == '' ? 'https://ntfy.sh' : 'https://ntfy.$domaine';

  /// Remplaçable dans les essais.
  http.Client client = http.Client();

  final List<MessageFoyer> messages = [];
  String? erreur;
  bool enCours = false;

  /// Canal personnel de [membreId] : seuls les membres du foyer (qui ont le code) peuvent le calculer.
  String canalDe(String membreId) {
    final code = Synchro.instance.code ?? canal;
    return 'ldc-${sha256.convert(utf8.encode('liste-de-courses/ntfy/$code/$membreId')).toString().substring(0, 20)}';
  }

  /// Le canal auquel s'abonner sur cet appareil.
  String get monCanal => canalDe(Etat.instance.moi.id);

  /// Canal du foyer (journal) : tiré du code de partage (le code lui-même ne circule pas) ; seul, un canal propre à l'appareil.
  String get canal {
    final code = Synchro.instance.code;
    if (code != null && Synchro.instance.mode == 'foyer') {
      return 'ldc-${sha256.convert(utf8.encode('liste-de-courses/ntfy/$code')).toString().substring(0, 20)}';
    }
    final base = Etat.instance.stockageFoyer;
    var c = base?.reglage('ntfy_canal') ?? _canalLocal;
    if (c == null) {
      final r = Random.secure();
      c = 'ldc-${List.generate(20, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[r.nextInt(36)]).join()}';
      base?.definirReglage('ntfy_canal', c);
      _canalLocal = c;
    }
    return c;
  }

  String? _canalLocal;

  String get lienWeb => '$serveur/$monCanal';

  /// Lien qui abonne l'appli ntfy d'Android au canal.
  String get lienAppli => 'ntfy://${Uri.parse(serveur).host}/$monCanal';

  /// Envoie [texte] au journal du foyer et sur le canal des membres [a] (tous si null), sauf soi-même ;
  /// renvoie une erreur lisible, ou null.
  Future<String?> envoyer(String texte, {Iterable<String>? a, bool notification = false}) async {
    final t = texte.trim();
    if (t.isEmpty) return 'Message vide';
    final etat = Etat.instance;
    final moi = etat.moi.id;
    final pour = [for (final id in a ?? [for (final m in etat.membresVisibles) m.id]) if (id != moi) id];
    // Seul (ou personne à prévenir), une notification ne part pas.
    if (notification && pour.isEmpty) return null;
    try {
      for (final c in [canal, for (final id in pour.toSet()) canalDe(id)]) {
        final r = await client
            .post(Uri.parse(serveur),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'topic': c,
                  'title': '${etat.moi.nomAffiche} · ${etat.foyerNom}',
                  'message': t,
                  // Le journal du foyer garde l'expéditeur et les destinataires (personne n'écoute ce canal).
                  'tags': [notification ? 'bell' : 'shopping_cart', if (c == canal) ...['de-$moi', for (final id in pour.toSet()) 'a-$id']],
                }))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode >= 300) return 'Le service ntfy a refusé le message (${r.statusCode})';
      }
      await lire();
      return null;
    } catch (e) {
      debugPrint('ntfy : $e');
      return 'Pas de réseau ou service ntfy injoignable';
    }
  }

  /// Trace d'un mail parti, dans le journal du foyer (sans prévenir personne) : pour l'historique des membres.
  Future<void> journaliserMail(List<String> adresses, String sujet) async {
    final etat = Etat.instance;
    final moi = etat.moi.id;
    final ad = {for (final x in adresses) x.trim().toLowerCase()};
    final pour = [for (final m in etat.membresVisibles) if (m.email.isNotEmpty && ad.contains(m.email.trim().toLowerCase())) m.id];
    try {
      await client
          .post(Uri.parse(serveur),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'topic': canal,
                'title': '${etat.moi.nomAffiche} · ${etat.foyerNom}',
                'message': sujet,
                'tags': ['mail', 'de-$moi', for (final id in pour) 'a-$id'],
              }))
          .timeout(const Duration(seconds: 15));
      await lire();
    } catch (e) {
      debugPrint('ntfy (trace du mail) : $e');
    }
  }

  /// Notification automatique (Etat.avertir) : envoyée sans attendre, une erreur réseau est ignorée.
  void avertir(String texte, Iterable<String>? a) {
    if (Synchro.instance.mode != 'foyer') return;
    envoyer(texte, a: a, notification: true);
  }

  /// Journal gardé sur l'appareil (ntfy.sh n'en garde que quelques heures), du plus ancien au plus récent.
  void _garder(List<MessageFoyer> lus) {
    final base = Etat.instance.stockageFoyer;
    final tous = <String, MessageFoyer>{for (final x in messages) x.id: x};
    if (messages.isEmpty) {
      try {
        for (final m in (jsonDecode(base?.reglage('journal_ntfy') ?? '[]') as List).whereType<Map>()) {
          if (MessageFoyer.lire(m) case final x?) tous[x.id] = x;
        }
      } catch (_) {}
    }
    for (final x in lus) {
      tous[x.id] = x;
    }
    final liste = tous.values.toList()..sort((a, b) => a.heure.compareTo(b.heure));
    final garde = liste.length > 400 ? liste.sublist(liste.length - 400) : liste;
    messages
      ..clear()
      ..addAll(garde);
    base?.definirReglage('journal_ntfy', jsonEncode([for (final x in garde) x.versJson()]));
  }

  /// Relit le canal du foyer (dernières 48 heures) et l'ajoute au journal de l'appareil.
  Future<void> lire() async {
    if (enCours) return;
    enCours = true;
    try {
      final r = await client.get(Uri.parse('$serveur/$canal/json?poll=1&since=48h')).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) throw 'statut ${r.statusCode}';
      final lus = [
        for (final ligne in const LineSplitter().convert(utf8.decode(r.bodyBytes)))
          if (ligne.trim().isNotEmpty)
            if (jsonDecode(ligne) case {'event': 'message'} && final Map m)
              if (MessageFoyer.lire(m) case final x?) x,
      ];
      _garder(lus);
      erreur = null;
    } catch (_) {
      erreur = 'Messages injoignables (pas de réseau ?)';
    } finally {
      enCours = false;
      notifyListeners();
    }
  }
}
