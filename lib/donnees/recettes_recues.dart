import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'catalogue_commun.dart';
import 'demonstration.dart';
import 'modele.dart';
import 'recette_ingredients.dart';
import 'signature.dart';
import 'synchro.dart' show Transport;

/// Catalogue commun des recettes, côté application (20/11/2026, Aristide : versionné, commun à tous les foyers,
/// alimenté par l'éditeur seul depuis la console, comme le catalogue des produits).
///
/// Au lancement, l'application lit l'index signé « ldc/recettes-communes » (console : RecettesCommunes). Une
/// version plus récente que celle appliquée remplace les recettes embarquées ; elle est gardée sur l'appareil,
/// pour fonctionner hors ligne. Les images arrivent ensuite, en tâche de fond, une par empreinte
/// (« ldc/recettes-images/<empreinte> ») ; celles déjà embarquées (même empreinte) ne sont pas téléchargées.
/// La démonstration garde ses recettes embarquées.
class RecettesRecues extends ChangeNotifier {
  RecettesRecues._();
  static final RecettesRecues instance = RecettesRecues._();

  static const sujet = 'ldc/recettes-communes';
  static String sujetImage(String empreinte) => 'ldc/recettes-images/$empreinte';

  static const _cleIndex = 'recettes_communes';
  static const _cleNouveautes = 'recettes_nouveautes';
  static const _cleVues = 'recettes_nouveautes_vues';
  static String _cleImage(String e) => 'recette_image:$e';

  String? _reglage(String c) => Etat.instance.stockageFoyer?.reglage(c);
  void _definir(String c, String v) => Etat.instance.stockageFoyer?.definirReglage(c, v);

  Map<String, dynamic>? _index;
  bool _indexLu = false;

  /// La version reçue et gardée sur l'appareil, ou null (recettes embarquées).
  Map<String, dynamic>? get index {
    if (!_indexLu) {
      _indexLu = true;
      try {
        final t = _reglage(_cleIndex);
        if (t != null) _index = jsonDecode(t) as Map<String, dynamic>;
      } catch (_) {
        _index = null;
      }
    }
    return _index;
  }

  int get numero => ((index?['numero'] as num?) ?? 0).toInt();

  final _images = <String, Uint8List?>{};

  /// L'image reçue d'empreinte [e], ou null.
  Uint8List? image(String e) => _images.putIfAbsent(e, () {
        final t = _reglage(_cleImage(e));
        if (t == null) return null;
        try {
          return base64Decode(t);
        } catch (_) {
          return null;
        }
      });

  /// Lit le serveur (au lancement) : nouvelle version des recettes, puis ses images manquantes.
  Future<void> verifier() async {
    if (demonstration || Etat.instance.stockageFoyer == null) return;
    try {
      await CatalogueCommun.instance.avecServeur<bool>((t, messages) async {
        String? publie;
        try {
          publie = (await messages.firstWhere((m) => m.$1 == sujet && m.$2.isNotEmpty).timeout(const Duration(seconds: 8))).$2;
        } on TimeoutException {
          return false;
        }
        final j = await lire(publie);
        if (j == null) return false;
        if (((j['numero'] as num?) ?? 0).toInt() > numero) await appliquer(j);
        await _telechargerImages(t, messages);
        return true;
      }, abonnement: sujet);
    } catch (e) {
      debugPrint('Recettes communes : $e');
    }
  }

  /// Une version publiée : son contenu si la signature de l'éditeur est bonne, sinon null.
  static Future<Map<String, dynamic>?> lire(String publie) async {
    if (!await SignatureEditeur.verifie(publie)) return null;
    return CatalogueCommun.deballer(SignatureEditeur.contenu(publie));
  }

  /// Remplace les recettes par la version [j] (déjà vérifiée) et prépare la fenêtre « Nouveautés ».
  Future<void> appliquer(Map<String, dynamic> j) async {
    final avant = await recettesFournies();
    _definir(_cleIndex, jsonEncode(j));
    _index = j;
    _indexLu = true;
    oublierRecettes();
    final apres = await recettesFournies();
    _definir(_cleNouveautes, jsonEncode(nouveautes(avant, apres, '${j['libelle'] ?? j['numero']}')));
    notifyListeners();
  }

  /// Ce qui a changé de [avant] à [apres] : version, lignes à montrer.
  static Map<String, dynamic> nouveautes(List<RecetteLue> avant, List<RecetteLue> apres, String libelle) {
    final a = {for (final r in avant) r.id ?? r.titre: r};
    final ajoutees = <String>[], modifiees = <String>[];
    for (final r in apres) {
      final x = a.remove(r.id ?? r.titre);
      if (x == null) {
        ajoutees.add(r.titre);
      } else if (x.signature != r.signature) {
        modifiees.add(r.titre);
      }
    }
    final retirees = [for (final r in a.values) r.titre];
    String n(int k, String mot) => '$k $mot${k > 1 ? 's' : ''}';
    return {
      'version': libelle,
      'resume': [
        if (ajoutees.isNotEmpty) n(ajoutees.length, 'ajoutée'),
        if (modifiees.isNotEmpty) n(modifiees.length, 'modifiée'),
        if (retirees.isNotEmpty) n(retirees.length, 'retirée'),
      ].join(', '),
      'lignes': [
        for (final t in ajoutees.take(20)) 'Nouvelle : $t',
        for (final t in modifiees.take(20)) 'Modifiée : $t',
        for (final t in retirees.take(10)) 'Retirée : $t',
      ],
    };
  }

  /// Nouveautés à montrer sur cet appareil (une fois) : (version, résumé, lignes), ou null.
  (String, String, List<String>)? get aMontrer {
    final t = _reglage(_cleNouveautes);
    if (t == null) return null;
    final n = jsonDecode(t) as Map<String, dynamic>;
    if ('${n['version']}' == _reglage(_cleVues) || '${n['resume']}'.isEmpty) return null;
    return ('${n['version']}', '${n['resume']}', [...(n['lignes'] as List).cast<String>()]);
  }

  void nouveautesVues() {
    final n = aMontrer;
    if (n != null) _definir(_cleVues, n.$1);
    notifyListeners();
  }

  /// Les images de l'index que l'appareil n'a ni embarquées ni reçues, demandées sur la liaison ouverte.
  Future<void> _telechargerImages(Transport t, Stream<(String, String)> messages) async {
    final j = index;
    if (j == null) return;
    final embarquees = await empreintesEmbarquees();
    final manquantes = <String>{
      for (final r in (j['recettes'] as List).cast<Map>())
        if (r['image'] case final String e)
          if (!embarquees.contains(e) && _reglage(_cleImage(e)) == null) e,
    };
    if (manquantes.isEmpty) return;
    final attendues = {for (final e in manquantes) sujetImage(e): e};
    final recues = Completer<void>();
    var n = 0;
    final sub = messages.listen((m) {
      final e = attendues.remove(m.$1);
      if (e == null) return;
      final x = RegExp(r'^img:([a-z0-9]+):').firstMatch(m.$2);
      if (x != null) {
        _definir(_cleImage(e), m.$2.substring(x.end));
        _images.remove(e);
        n++;
      }
      if (attendues.isEmpty && !recues.isCompleted) recues.complete();
    });
    for (final s in attendues.keys.toList()) {
      t.abonner(s);
    }
    try {
      await recues.future.timeout(Duration(seconds: 20 + manquantes.length));
    } on TimeoutException {
      // les autres viendront au prochain lancement
    } finally {
      await sub.cancel();
    }
    if (n > 0) {
      oublierRecettes();
      notifyListeners();
    }
  }
}
