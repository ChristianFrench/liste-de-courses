import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'catalogue_commun.dart';
import 'recettes.dart';
import 'signature.dart';

/// Catalogue commun des recettes (20/11/2026, Aristide : « un fonctionnement identique à celui des produits et
/// des marques. Généraliser, etc. »). Un seul catalogue, alimenté par l'éditeur depuis la console.
///
/// Sur le serveur :
/// - « ldc/recettes-communes » : la dernière version, message retenu, signé avec la clé de l'éditeur, emballé
///   (« gz: »). Contenu : numero, libelle, date, recettes (sans les champs propres à la console) et, pour chaque
///   recette illustrée, l'empreinte de son image ;
/// - « ldc/recettes-images/<empreinte> » : une image, message retenu (« img:<ext>:» + base 64). L'empreinte
///   signée de l'index garantit l'image ; une application ne télécharge que les empreintes qu'elle n'a pas.
/// Les images partent avant l'index, sur la même liaison (ordre garanti) : quand le serveur renvoie l'index,
/// les images sont arrivées.
class RecettesCommunes {
  static const sujet = 'ldc/recettes-communes';
  static const sujetImages = 'ldc/recettes-images';
  static String sujetImage(String empreinte) => '$sujetImages/$empreinte';

  /// Champs propres à la console, qui ne partent pas.
  static const champsPrives = {
    'photos', 'texteOrigine', 'remarques', 'illustration', 'illustrationFournie', 'retouchee', 'modifieeLe',
    'preparation', 'titreIngredients', 'memo',
  };

  /// Empreinte d'un fichier ou d'un texte : 16 caractères du SHA-256.
  static String empreinte(List<int> octets) => sha256.convert(octets).toString().substring(0, 16);

  static String empreinteRecette(Recette r) => empreinte(utf8.encode(jsonEncode(r.versJson()..removeWhere((k, _) => k == 'modifieeLe'))));

  /// Les recettes publiables (les mémos restent dans la console).
  static List<Recette> publiables(BaseRecettes b) => [for (final r in b.recettes) if (!r.memo) r];

  /// Ce qui a changé depuis la dernière publication : (ajoutées, modifiées, retirées).
  static (List<String>, List<String>, List<String>) changements(BaseRecettes b) {
    final avant = Map<String, dynamic>.from(b.publiee['empreintes'] as Map? ?? const {});
    final titres = Map<String, dynamic>.from(b.publiee['titres'] as Map? ?? const {});
    final ajoutees = <String>[], modifiees = <String>[];
    final vus = <String>{};
    for (final r in publiables(b)) {
      vus.add(r.id);
      final e = avant[r.id];
      if (e == null) {
        ajoutees.add(r.titre);
      } else if (e != empreinteRecette(r)) {
        modifiees.add(r.titre);
      }
    }
    final retirees = [for (final id in avant.keys) if (!vus.contains(id)) '${titres[id] ?? id}'];
    return (ajoutees, modifiees, retirees);
  }

  static bool aPublier(BaseRecettes b) {
    final (a, m, r) = changements(b);
    return b.publiee.isEmpty || a.isNotEmpty || m.isNotEmpty || r.isNotEmpty;
  }

  /// Nom de la version publiée (« 1.0 »), « 0 » avant la première.
  static String libellePublie(BaseRecettes b) => b.publiee.isEmpty ? '0' : '${b.publiee['libelle'] ?? b.publiee['numero']}';

  static String libelleSuivant(BaseRecettes b, {bool majeure = false}) =>
      CatalogueCommun.libelleSuivant(libellePublie(b), majeure: majeure);

  /// Le contenu publié : recettes sans les champs de la console, et empreintes des images.
  static Future<(Map<String, dynamic>, Map<String, File>)> contenu(BaseRecettes b) async {
    final images = <String, File>{};
    final liste = <Map<String, dynamic>>[];
    for (final r in publiables(b)) {
      final j = r.versJson()..removeWhere((k, _) => champsPrives.contains(k));
      final nom = r.illustration;
      if (nom != null) {
        final f = b.photo(nom);
        if (f.existsSync()) {
          final e = empreinte(await f.readAsBytes());
          j['image'] = e;
          images[e] = f;
        }
      }
      liste.add(j);
    }
    return (<String, dynamic>{'recettes': liste}, images);
  }

  /// Message d'une image : « img:jpg:<base 64> ».
  static String emballerImage(File f, List<int> octets) => 'img:${f.path.split('.').last.toLowerCase()}:${base64Encode(octets)}';

  /// Lit un message d'image : (extension, octets), ou null.
  static (String, List<int>)? deballerImage(String m) {
    final x = RegExp(r'^img:([a-z0-9]+):').firstMatch(m);
    if (x == null) return null;
    return (x.group(1)!, base64Decode(m.substring(x.end)));
  }

  /// Dernière erreur de publication, à montrer.
  static String? erreur;

  /// Généralise : publie les images pas encore envoyées, puis l'index signé. Rend le libellé publié, ou null.
  /// [progres] reçoit (images envoyées, images à envoyer).
  static Future<String?> generaliser(BaseRecettes b, {bool majeure = false, void Function(int, int)? progres}) async {
    erreur = null;
    final graine = CatalogueCommun.instance.graineSignature;
    if (graine == null) {
      erreur = 'phrase de signature non saisie (Catalogue des produits › Clé de signature)';
      return null;
    }
    try {
      final (j, images) = await contenu(b);
      final dejaEnvoyees = {for (final x in (b.publiee['images'] as List? ?? const [])) '$x'};
      final aEnvoyer = [for (final e in images.keys) if (!dejaEnvoyees.contains(e)) e];
      final numero = ((b.publiee['numero'] as num?) ?? 0).toInt() + 1;
      final libelle = libelleSuivant(b, majeure: majeure);
      final date = DateTime.now().toIso8601String().substring(0, 16);
      j
        ..['numero'] = numero
        ..['libelle'] = libelle
        ..['date'] = date;
      final texte = await SignatureEditeur.signer(CatalogueCommun.emballer(j), graine);
      final ok = await CatalogueCommun.instance.avecServeur<bool>((t, messages) async {
        final retour = Completer<bool>();
        final sub = messages.listen((m) {
          if (m.$1 == sujet && m.$2 == texte && !retour.isCompleted) retour.complete(true);
        }, onDone: () {
          erreur ??= 'le serveur a coupé la liaison';
          if (!retour.isCompleted) retour.complete(false);
        });
        try {
          var n = 0;
          for (final e in aEnvoyer) {
            final f = images[e]!;
            t.publier(sujetImage(e), emballerImage(f, await f.readAsBytes()), retenu: true);
            n++;
            progres?.call(n, aEnvoyer.length);
            // Laisser partir les messages : la liaison n'accumule pas des dizaines de mégaoctets.
            if (n % 10 == 0) await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          t.publier(sujet, texte, retenu: true);
          return await retour.future.timeout(Duration(seconds: 30 + aEnvoyer.length));
        } on TimeoutException {
          erreur ??= 'le serveur n\'a pas renvoyé les recettes';
          return false;
        } finally {
          await sub.cancel();
        }
      }, abonnement: sujet);
      if (ok != true) {
        erreur ??= 'pas de liaison avec le serveur';
        return null;
      }
      final recettes = publiables(b);
      b.publiee = {
        'numero': numero,
        'libelle': libelle,
        'date': date,
        'empreintes': {for (final r in recettes) r.id: empreinteRecette(r)},
        'titres': {for (final r in recettes) r.id: r.titre},
        'images': {...dejaEnvoyees, ...images.keys}.toList()..sort(),
      };
      b.journal.generalisee(numero, libelle);
      await b.enregistrer();
      return libelle;
    } catch (e) {
      erreur = '$e';
      return null;
    }
  }

  /// Lit une version publiée (applications) : le contenu si la signature est bonne, sinon null.
  static Future<Map<String, dynamic>?> lire(String publie) async {
    if (publie.isEmpty || !await SignatureEditeur.verifie(publie)) return null;
    return CatalogueCommun.deballer(SignatureEditeur.contenu(publie));
  }
}
