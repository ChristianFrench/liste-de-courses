import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'modele.dart';
import 'synchro.dart';

// Messages entre les membres du foyer (maquette du 27/10/2026), par le service gratuit ntfy.sh :
// chaque membre s'abonne au canal du foyer dans l'appli ntfy (Android) ou sur ntfy.sh (navigateur),
// et reçoit les messages même quand Liste de courses est fermée.

/// Un message reçu du canal.
class MessageFoyer {
  MessageFoyer(this.id, this.heure, this.titre, this.texte);
  final String id;
  final DateTime heure;
  final String titre;
  final String texte;
}

class MessagesFoyer extends ChangeNotifier {
  MessagesFoyer._();
  static final MessagesFoyer instance = MessagesFoyer._();

  static const serveur = 'https://ntfy.sh';

  /// Remplaçable dans les essais.
  http.Client client = http.Client();

  final List<MessageFoyer> messages = [];
  String? erreur;
  bool enCours = false;

  /// Canal du foyer : tiré du code de partage (le code lui-même ne circule pas) ; seul, un canal propre à l'appareil.
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

  String get lienWeb => '$serveur/$canal';

  /// Lien qui abonne l'appli ntfy d'Android au canal.
  String get lienAppli => 'ntfy://ntfy.sh/$canal';

  /// Envoie [texte] à tout le foyer ; renvoie une erreur lisible, ou null.
  Future<String?> envoyer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty) return 'Message vide';
    final etat = Etat.instance;
    try {
      final r = await client
          .post(Uri.parse(serveur),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'topic': canal,
                'title': '${etat.moi.nomAffiche} · ${etat.foyerNom}',
                'message': t,
                'tags': ['shopping_cart'],
              }))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return 'Le service ntfy a refusé le message (${r.statusCode})';
      await lire();
      return null;
    } catch (e) {
      debugPrint('ntfy : $e');
      return 'Pas de réseau ou service ntfy injoignable';
    }
  }

  /// Messages des dernières 48 heures, du plus ancien au plus récent.
  Future<void> lire() async {
    if (enCours) return;
    enCours = true;
    try {
      final r = await client.get(Uri.parse('$serveur/$canal/json?poll=1&since=48h')).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) throw 'statut ${r.statusCode}';
      messages
        ..clear()
        ..addAll([
          for (final ligne in const LineSplitter().convert(utf8.decode(r.bodyBytes)))
            if (ligne.trim().isNotEmpty)
              if (jsonDecode(ligne) case {'event': 'message', 'id': final String id, 'time': final int t} && final Map m)
                MessageFoyer(id, DateTime.fromMillisecondsSinceEpoch(t * 1000), m['title'] as String? ?? '', m['message'] as String? ?? ''),
        ]);
      erreur = null;
    } catch (_) {
      erreur = 'Messages injoignables (pas de réseau ?)';
    } finally {
      enCours = false;
      notifyListeners();
    }
  }
}
