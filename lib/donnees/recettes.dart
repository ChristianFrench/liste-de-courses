import 'dart:convert';
import 'dart:io';

import 'dossier_application.dart';

// Catalogue des recettes de la console (10/11/2026, Aristide) : les notes Google Keep libellées « Recettes … »
// importées dans une base SÉPARÉE (recettes/recettes.json et ses photos, dans le dossier de la console), sans
// lien avec le catalogue publié. Une recette déjà importée est mise à jour, jamais dupliquée.
// Découpage ingrédients / préparation : règles de /mnt/project-files/recettes/decoupage.md (decoupe.py).

class Recette {
  Recette({
    required this.id,
    required this.titre,
    required this.types,
    this.titreIngredients,
    required this.ingredients,
    required this.preparation,
    required this.photos,
    this.modifieeLe,
  });

  /// Identifiant stable : la date de création de la note Keep (sinon son titre).
  final String id;
  String titre;

  /// Types affichés : les libellés sans « Recettes » (« Plats », « Sauces »…). Une recette peut en avoir plusieurs.
  List<String> types;
  String? titreIngredients;
  List<String> ingredients;
  String preparation;

  /// Noms des fichiers photo, rangés dans le dossier de la base.
  List<String> photos;
  DateTime? modifieeLe;

  Map<String, dynamic> versJson() => {
        'id': id,
        'titre': titre,
        'types': types,
        if (titreIngredients != null) 'titreIngredients': titreIngredients,
        'ingredients': ingredients,
        'preparation': preparation,
        'photos': photos,
        if (modifieeLe != null) 'modifieeLe': modifieeLe!.toIso8601String(),
      };

  factory Recette.lire(Map j) => Recette(
        id: j['id'] as String,
        titre: j['titre'] as String? ?? '',
        types: [...((j['types'] as List?) ?? const []).cast<String>()],
        titreIngredients: j['titreIngredients'] as String?,
        ingredients: [...((j['ingredients'] as List?) ?? const []).cast<String>()],
        preparation: j['preparation'] as String? ?? '',
        photos: [...((j['photos'] as List?) ?? const []).cast<String>()],
        modifieeLe: DateTime.tryParse(j['modifieeLe'] as String? ?? ''),
      );
}

/// Sans accents ni majuscules.
String _norm(String t) {
  const de = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const vers = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final c in t.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : vers[i]);
  }
  return b.toString();
}

/// Découpe le texte d'une note : (titre des ingrédients, ingrédients, préparation).
/// 1. La première ligne qui commence par « ingrédi… » (sans accents ni majuscules) est le titre des ingrédients.
/// 2. Les lignes suivantes sont des ingrédients tant qu'elles commencent par -, •, * ou – (retiré), ou qu'elles
///    sont courtes (< 60) sans point final. Une ligne vide ne coupe pas si la suivante est encore un tiret ;
///    « -- … » ou « 1. » / « 1) » (étapes) arrêtent la liste.
/// 3. Préparation : ce qui précédait le titre, puis tout ce qui suit les ingrédients.
/// 4. Sans titre « Ingrédients » : aucun ingrédient, tout est préparation.
(String?, List<String>, String) decouperRecette(String texte) {
  final lignes = const LineSplitter().convert(texte);
  final i = lignes.indexWhere((l) => RegExp(r'^\s*ingr[eé]di[ae]?n').hasMatch(_norm(l)));
  if (i < 0) return (null, const [], texte.trim());
  final titre = lignes[i].trim();
  final puce = RegExp(r'^[-•*–]');
  final ing = <String>[];
  var k = i + 1;
  while (k < lignes.length) {
    final l = lignes[k].trim();
    if (l.isEmpty) {
      final suivante = lignes.skip(k + 1).map((x) => x.trim()).firstWhere((x) => x.isNotEmpty, orElse: () => '');
      if (RegExp(r'^[-•*–]\s?[^-]').hasMatch(suivante)) {
        k++;
        continue;
      }
      break;
    }
    if (RegExp(r'^(--|\d+[.)])').hasMatch(l)) break;
    if (puce.hasMatch(l) || (l.length < 60 && !l.endsWith('.'))) {
      ing.add(l.replaceFirst(RegExp(r'^[-•*–]\s*'), ''));
      k++;
      continue;
    }
    break;
  }
  final avant = lignes.take(i).join('\n').trim();
  final prep = lignes.skip(k).join('\n').trim();
  return (titre, ing, avant.isEmpty ? prep : '$avant\n\n$prep'.trim());
}

/// Type affiché d'un libellé Keep : « Recettes Plats Accompagnement » → « Plats accompagnement ».
String typeDuLibelle(String libelle) {
  var t = libelle.trim().replaceFirst(RegExp(r'^recettes?\s*', caseSensitive: false), '').trim();
  if (t.isEmpty) return 'Autres';
  t = t[0].toUpperCase() + t.substring(1).toLowerCase();
  return t.replaceFirst('Entree', 'Entrée');
}

/// Bilan d'un import.
class BilanImport {
  int ajoutees = 0, misesAJour = 0, ignorees = 0, photos = 0;
  final erreurs = <String>[];
  @override
  String toString() => '$ajoutees ajoutée(s), $misesAJour mise(s) à jour, $photos photo(s)'
      '${ignorees > 0 ? ', $ignorees note(s) sans libellé « Recette » ignorée(s)' : ''}'
      '${erreurs.isNotEmpty ? ', ${erreurs.length} erreur(s)' : ''}';
}

class BaseRecettes {
  BaseRecettes(this.dossier, [List<Recette>? recettes]) : recettes = recettes ?? [];

  /// Dossier de la base : recettes.json et les photos.
  final Directory dossier;
  final List<Recette> recettes;

  static Future<BaseRecettes> ouvrir({Directory? dossier}) async {
    final d = dossier ?? Directory('${(await dossierApplication()).path}${Platform.pathSeparator}recettes');
    final f = File('${d.path}${Platform.pathSeparator}recettes.json');
    if (!f.existsSync()) return BaseRecettes(d);
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return BaseRecettes(d, [for (final r in (j['recettes'] as List? ?? const []).cast<Map>()) Recette.lire(r)]);
    } catch (_) {
      return BaseRecettes(d);
    }
  }

  Future<void> enregistrer() async {
    await dossier.create(recursive: true);
    final f = File('${dossier.path}${Platform.pathSeparator}recettes.json');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert({
      'version': 1,
      'recettes': [for (final r in recettes) r.versJson()],
    }));
  }

  File photo(String nom) => File('${dossier.path}${Platform.pathSeparator}$nom');

  /// Types présents, par ordre alphabétique, avec leurs recettes (par titre).
  Map<String, List<Recette>> parType() {
    final m = <String, List<Recette>>{};
    for (final r in recettes) {
      for (final t in r.types.isEmpty ? const ['Autres'] : r.types) {
        m.putIfAbsent(t, () => []).add(r);
      }
    }
    final cles = m.keys.toList()..sort((a, b) => _norm(a).compareTo(_norm(b)));
    return {for (final k in cles) k: m[k]!..sort((a, b) => _norm(a.titre).compareTo(_norm(b.titre)))};
  }

  /// Importe les notes Keep (.json) du dossier [source] dont un libellé contient « recette » ; leurs photos sont
  /// copiées dans la base. Une recette déjà importée (même note) est mise à jour. [toutes] : aussi les notes
  /// sans libellé « Recette ».
  Future<BilanImport> importerKeep(Directory source, {bool toutes = false}) async {
    final bilan = BilanImport();
    await dossier.create(recursive: true);
    final fichiers = source.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in fichiers) {
      Map<String, dynamic> j;
      try {
        j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        bilan.erreurs.add('${f.uri.pathSegments.last} : illisible');
        continue;
      }
      if (j['isTrashed'] == true || (j['title'] == null && j['textContent'] == null)) continue;
      final libelles = [for (final l in (j['labels'] as List? ?? const []).cast<Map>()) '${l['name'] ?? ''}'];
      final deRecette = libelles.where((l) => _norm(l).contains('recette')).toList();
      if (deRecette.isEmpty && !toutes) {
        bilan.ignorees++;
        continue;
      }
      final titre = '${j['title'] ?? ''}'.trim().isEmpty ? '(sans titre)' : '${j['title']}'.trim();
      final id = j['createdTimestampUsec'] != null ? 'keep-${j['createdTimestampUsec']}' : 'keep-${_norm(titre)}';
      var texte = '${j['textContent'] ?? ''}';
      // Une liste à cocher : ses cases sont les ingrédients.
      final cases = [for (final c in (j['listContent'] as List? ?? const []).cast<Map>()) '${c['text'] ?? ''}'.trim()]
        ..removeWhere((t) => t.isEmpty);
      final (ti, ing, prep) = cases.isNotEmpty ? ('Ingrédients', cases, texte.trim()) : decouperRecette(texte);
      // Photos : le nom est celui du JSON (attachments[].filePath), les accents des noms de note n'y sont pas.
      final photos = <String>[];
      for (final a in (j['attachments'] as List? ?? const []).cast<Map>()) {
        final nom = '${a['filePath'] ?? ''}'.split(RegExp(r'[\\/]')).last;
        final type = '${a['mimetype'] ?? ''}';
        if (nom.isEmpty || !(type.startsWith('image') || RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(nom))) continue;
        var src = File('${source.path}${Platform.pathSeparator}$nom');
        // Keep écrit parfois .jpeg dans la note et .jpg dans l'archive.
        if (!src.existsSync() && nom.toLowerCase().endsWith('.jpeg')) {
          src = File('${source.path}${Platform.pathSeparator}${nom.substring(0, nom.length - 5)}.jpg');
        }
        if (!src.existsSync()) {
          bilan.erreurs.add('$titre : photo $nom absente');
          continue;
        }
        final dest = photo(src.uri.pathSegments.last);
        if (!dest.existsSync() || dest.lengthSync() != src.lengthSync()) await src.copy(dest.path);
        photos.add(src.uri.pathSegments.last);
        bilan.photos++;
      }
      final types = <String>[for (final l in deRecette) typeDuLibelle(l)];
      final edite = (j['userEditedTimestampUsec'] as num?)?.toInt();
      final r = Recette(
        id: id,
        titre: titre,
        types: types.toSet().toList(),
        titreIngredients: ti,
        ingredients: ing,
        preparation: prep,
        photos: photos,
        modifieeLe: edite == null ? null : DateTime.fromMicrosecondsSinceEpoch(edite),
      );
      final i = recettes.indexWhere((x) => x.id == id);
      if (i >= 0) {
        recettes[i] = r;
        bilan.misesAJour++;
      } else {
        recettes.add(r);
        bilan.ajoutees++;
      }
    }
    await enregistrer();
    return bilan;
  }
}
