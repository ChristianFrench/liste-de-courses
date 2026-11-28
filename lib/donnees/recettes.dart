import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'dossier_application.dart';
import 'journal_catalogue.dart';
import 'modele.dart' show Etat, EtatChargement;
import 'classement_recettes.dart';

export 'classement_recettes.dart';

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
    this.detail = const [],
    this.etapes = const [],
    this.conseils = const [],
    this.remarques = const [],
    this.texteOrigine,
    this.memo = false,
    this.illustration,
    this.pour,
    this.source,
    this.tempsPreparation,
    this.tempsCuisson,
    this.difficulte,
    this.regimes = const [],
    this.saisons = const [],
    this.cout,
    this.cuissons = const [],
    this.occasions = const [],
    this.retouchee = false,
    Map<String, String>? sousTypes,
    this.origine,
  }) : sousTypes = sousTypes ?? {};

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

  // Recette normalisée (11/11/2026, recettes-normalisees.json du Fil de génération) : ingrédients en
  // quantité / nom / précision, étapes numérotées, conseils, remarques à confirmer, texte d'origine.
  List<IngredientRecette> detail;
  List<String> etapes, conseils, remarques;
  String? texteOrigine;

  /// Mémo (temps de cuisson…) plutôt que recette : pas d'ingrédients.
  bool memo;

  /// Illustration d'Aristide (12/11/2026), fichier rangé avec les photos ; montrée avant les photos Keep.
  String? illustration;

  /// Illustration fournie avec la console déjà posée (« nom:taille ») : on ne la recopie pas à chaque ouverture.
  String? illustrationFournie;
  /// Nombre de personnes (ou de pièces) prévu par les quantités : « 4 personnes », « 30 crêpes ».
  String? pour;

  /// Origine : null pour les recettes maison (Google Keep), « Emplettes » pour celles rédigées pour l'application.
  String? source;

  /// 20/11/2026 (Aristide) : temps de préparation et de cuisson en minutes, difficulté sur quatre niveaux
  /// ([niveauxDifficulte]). Null quand on ne les connaît pas.
  int? tempsPreparation;
  int? tempsCuisson;
  String? difficulte;

  /// Critères de choix (20/11/2026) : Végétarien, Végétalien, Sans gluten, Sans lactose ; Printemps… Hiver ;
  /// €, €€, €€€ ; Sans cuisson, Four, Plaque, Cocotte-minute ; Quotidien, À l'avance, À recevoir, À emporter.
  List<String> regimes;
  List<String> saisons;
  String? cout;
  List<String> cuissons;
  List<String> occasions;

  /// Modifiée dans la console (20/11/2026) : une livraison de recettes ne l'écrase plus.
  bool retouchee;

  /// Classement (21/11/2026, Aristide) : un sous-type par type ([typesRecettes]), et l'origine ([originesRecettes]).
  Map<String, String> sousTypes;
  String? origine;

  /// « Plats · Volaille » pour chaque type.
  List<String> get classement => [for (final t in types) sousTypes[t] == null ? t : '$t · ${sousTypes[t]}'];

  /// Copie indépendante.
  Recette copie() => Recette.lire(versJson());

  /// « Toute l'année » quand les quatre saisons y sont.
  String get repereSaisons => saisons.length == 4 ? "Toute l'année" : saisons.join(', ');

  /// « Préparation 15 min · Cuisson 1 h 10 · Facile » (vide si rien n'est connu).
  String get repereTemps => [
        if (tempsPreparation != null) 'Préparation ${dureeRecette(tempsPreparation!)}',
        if (tempsCuisson != null) tempsCuisson == 0 ? 'Sans cuisson' : 'Cuisson ${dureeRecette(tempsCuisson!)}',
        if (difficulte != null) difficulte!,
      ].join(' · ');

  bool get normalisee => detail.isNotEmpty || etapes.isNotEmpty;

  Map<String, dynamic> versJson() => {
        'id': id,
        'titre': titre,
        'types': types,
        if (titreIngredients != null) 'titreIngredients': titreIngredients,
        'ingredients': ingredients,
        'preparation': preparation,
        'photos': photos,
        if (modifieeLe != null) 'modifieeLe': modifieeLe!.toIso8601String(),
        if (detail.isNotEmpty) 'detail': [for (final i in detail) i.versJson()],
        if (etapes.isNotEmpty) 'etapes': etapes,
        if (conseils.isNotEmpty) 'conseils': conseils,
        if (remarques.isNotEmpty) 'remarques': remarques,
        if (texteOrigine != null) 'texteOrigine': texteOrigine,
        if (memo) 'memo': true,
        if (illustration != null) 'illustration': illustration,
        if (pour != null) 'pour': pour,
        if (source != null) 'source': source,
        if (tempsPreparation != null) 'tempsPreparation': tempsPreparation,
        if (tempsCuisson != null) 'tempsCuisson': tempsCuisson,
        if (difficulte != null) 'difficulte': difficulte,
        if (regimes.isNotEmpty) 'regimes': regimes,
        if (saisons.isNotEmpty) 'saisons': saisons,
        if (cout != null) 'cout': cout,
        if (cuissons.isNotEmpty) 'cuissons': cuissons,
        if (occasions.isNotEmpty) 'occasions': occasions,
        if (retouchee) 'retouchee': true,
        if (sousTypes.isNotEmpty) 'sousTypes': sousTypes,
        if (origine != null) 'origine': origine,
        if (illustrationFournie != null) 'illustrationFournie': illustrationFournie,
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
        detail: [for (final i in (j['detail'] as List? ?? const []).cast<Map>()) IngredientRecette.lire(i)],
        etapes: _textes(j['etapes']),
        conseils: _textes(j['conseils']),
        remarques: _textes(j['remarques']),
        texteOrigine: j['texteOrigine'] as String?,
        memo: j['memo'] == true,
        illustration: j['illustration'] as String?,
        pour: j['pour'] as String?,
        source: j['source'] as String?,
        tempsPreparation: (j['tempsPreparation'] as num?)?.toInt(),
        tempsCuisson: (j['tempsCuisson'] as num?)?.toInt(),
        difficulte: j['difficulte'] as String?,
        regimes: [for (final x in (j['regimes'] as List? ?? const [])) x as String],
        saisons: [for (final x in (j['saisons'] as List? ?? const [])) x as String],
        cout: j['cout'] as String?,
        cuissons: [for (final x in (j['cuissons'] as List? ?? const [])) x as String],
        occasions: [for (final x in (j['occasions'] as List? ?? const [])) x as String],
        retouchee: j['retouchee'] == true,
        sousTypes: {for (final e in (j['sousTypes'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
        origine: j['origine'] as String?,
      )..illustrationFournie = j['illustrationFournie'] as String?;
}

List<String> _textes(Object? l) => [for (final x in (l as List? ?? const [])) if ('$x'.trim().isNotEmpty) '$x'.trim()];

/// Ingrédient d'une recette normalisée : « 3 gousses » · « Ail » · « écrasé ».
/// Les quatre niveaux de difficulté, du plus simple au plus exigeant.
const niveauxDifficulte = ['Facile', 'Moyen', 'Difficile', 'Avancé'];

/// 15 → « 15 min », 70 → « 1 h 10 », 120 → « 2 h ».
String dureeRecette(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

class IngredientRecette {
  IngredientRecette(this.nom, {this.quantite = '', this.precision = ''});
  final String nom, quantite, precision;

  factory IngredientRecette.lire(Map j) =>
      IngredientRecette('${j['nom'] ?? ''}'.trim(), quantite: '${j['quantite'] ?? ''}'.trim(), precision: '${j['precision'] ?? ''}'.trim());
  Map<String, dynamic> versJson() => {'nom': nom, if (quantite.isNotEmpty) 'quantite': quantite, if (precision.isNotEmpty) 'precision': precision};

  /// Une ligne : « 3 gousses Ail (écrasé) ».
  String get texte => [if (quantite.isNotEmpty) quantite, nom, if (precision.isNotEmpty) '($precision)'].join(' ');
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

/// Nom de fichier d'une illustration : « Écrasé de pommes de terre à l'huile d'olive » → ecrase-de-pommes-de-terre-a-l-huile-d-olive.
String slugRecette(String titre) => _norm(titre.replaceAll('œ', 'oe').replaceAll('Œ', 'oe').replaceAll('æ', 'ae').replaceAll('Æ', 'ae'))
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Ordre des types : celui de [typesRecettes], puis les autres par ordre alphabétique, puis « Autres ».
int _rangType(String t) {
  final i = typesRecettes.keys.toList().indexOf(t);
  return i >= 0 ? i : (t == 'Autres' ? 1000 : 999);
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

/// Fichier des recettes normalisées, posé à côté des notes Keep (ou dans le dossier parent).
const fichierNormalise = 'recettes-normalisees.json';

/// Bilan d'un import.
class BilanImport {
  int ajoutees = 0, misesAJour = 0, ignorees = 0, photos = 0, normalisees = 0, illustrations = 0;
  final erreurs = <String>[];
  @override
  String toString() => '$ajoutees ajoutée(s), $misesAJour mise(s) à jour, $photos photo(s)'
      '${normalisees > 0 ? ', $normalisees normalisée(s)' : ''}'
      '${illustrations > 0 ? ', $illustrations illustration(s)' : ''}'
      '${ignorees > 0 ? ', $ignorees note(s) sans libellé « Recette » ignorée(s)' : ''}'
      '${erreurs.isNotEmpty ? ', ${erreurs.length} erreur(s)' : ''}';
}

class BaseRecettes {
  BaseRecettes(this.dossier, [List<Recette>? recettes]) : recettes = recettes ?? [];

  /// Dossier de la base : recettes.json et les photos.
  final Directory dossier;
  final List<Recette> recettes;

  /// Version des recettes livrées avec la console déjà appliquée (0 : aucune).
  int versionFournie = 0;

  /// 20/11/2026 (Aristide) : versions du catalogue des recettes, comme pour les produits et les marques.
  /// Chaque geste est noté « en cours » ; « Valider » fige une étape (instantané de toutes les recettes) ;
  /// « Généraliser » publie une version (voir recettes_communes.dart).
  JournalCatalogue journal = JournalCatalogue([], []);

  /// Dernière version publiée : numero, libelle, date, empreintes {id: empreinte du texte}, images publiées.
  Map<String, dynamic> publiee = {};

  int get enCours => journal.enCours.length;

  /// Toutes les recettes, emballées (« gz: » + gzip en base 64), pour une étape du journal.
  String instantane() => 'gz:${base64Encode(GZipEncoder().encode(utf8.encode(jsonEncode([for (final r in recettes) r.versJson()])))!)}';

  static List<Recette> deballer(String texte) {
    final s = texte.startsWith('gz:') ? utf8.decode(GZipDecoder().decodeBytes(base64Decode(texte.substring(3)))) : texte;
    return [for (final m in (jsonDecode(s) as List).cast<Map>()) Recette.lire(m)];
  }

  /// Note un geste en cours (enregistré aussitôt) ; la première fois, l'état actuel devient le point de départ.
  Future<void> noter(List<String> lignes) async {
    if (lignes.isEmpty) return;
    journal.noter(lignes);
    await enregistrer();
  }

  /// Le point de départ du journal, la première fois.
  Future<void> demarrerJournal() async {
    if (journal.etapes.isNotEmpty) return;
    journal.valider('Point de départ', instantane());
    await enregistrer();
  }

  Future<EtapeCatalogue> valider(String nom) async {
    final e = journal.valider(nom, instantane());
    await enregistrer();
    return e;
  }

  /// Revient à l'étape [i] : ses recettes remplacent les actuelles ; ce qui suit est abandonné.
  Future<void> revenirA(int i) async {
    final l = deballer(journal.revenirA(i));
    recettes
      ..clear()
      ..addAll(l);
    await enregistrer();
  }

  /// Ce qu'apporte une modification de [avant] en [apres] (une ligne par recette, champs touchés).
  static List<String> gestesEntre(Recette? avant, Recette? apres) {
    if (avant == null && apres == null) return const [];
    if (avant == null) return ['Recette ajoutée : ${apres!.titre}'];
    if (apres == null) return ['Recette supprimée : ${avant.titre}'];
    final a = avant.versJson(), b = apres.versJson();
    const noms = {
      'titre': 'titre', 'types': 'types', 'detail': 'ingrédients', 'etapes': 'étapes', 'conseils': 'conseils',
      'pour': 'portions', 'tempsPreparation': 'préparation', 'tempsCuisson': 'cuisson', 'difficulte': 'difficulté',
      'regimes': 'régime', 'saisons': 'saison', 'cout': 'coût', 'cuissons': 'mode de cuisson', 'occasions': 'occasion',
      'illustration': 'illustration', 'remarques': 'remarques', 'sousTypes': 'sous-types', 'origine': 'origine',
    };
    final touches = [for (final e in noms.entries) if (jsonEncode(a[e.key]) != jsonEncode(b[e.key])) e.value];
    if (touches.isEmpty) return const [];
    final titre = avant.titre == apres.titre ? apres.titre : '${avant.titre} → ${apres.titre}';
    return ['Recette modifiée : $titre (${touches.join(', ')})'];
  }

  /// Remplace (ou ajoute) une recette modifiée dans la console et note le geste.
  Future<void> modifier(Recette? avant, Recette apres) async {
    apres
      ..retouchee = true
      ..modifieeLe = DateTime.now();
    final i = avant == null ? -1 : recettes.indexWhere((x) => x.id == avant.id);
    if (i >= 0) {
      recettes[i] = apres;
    } else {
      recettes.add(apres);
    }
    await noter(gestesEntre(avant, apres));
  }

  Future<void> supprimer(Recette r) async {
    recettes.removeWhere((x) => x.id == r.id);
    await noter(gestesEntre(r, null));
  }

  /// Identifiant d'une recette créée dans la console : « emplettes-<titre> », rendu unique.
  String nouvelIdentifiant(String titre) {
    final base = 'emplettes-${slugRecette(titre)}';
    var id = base;
    for (var n = 2; recettes.any((r) => r.id == id); n++) {
      id = '$base-$n';
    }
    return id;
  }

  /// Pose [image] comme illustration de [r] sans effacer l'ancienne (une étape du journal peut y revenir).
  Future<String> copierIllustration(Recette r, File image) async {
    await dossier.create(recursive: true);
    final ext = image.path.split('.').last.toLowerCase();
    final nom = 'illustration-${slugRecette(r.titre)}-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await image.copy(photo(nom).path);
    return nom;
  }

  static Future<BaseRecettes> ouvrir({Directory? dossier}) async {
    final d = dossier ?? Directory('${(await dossierApplication()).path}${Platform.pathSeparator}recettes');
    final f = File('${d.path}${Platform.pathSeparator}recettes.json');
    if (!f.existsSync()) return BaseRecettes(d);
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return BaseRecettes(d, [for (final r in (j['recettes'] as List? ?? const []).cast<Map>()) Recette.lire(r)])
        ..versionFournie = (j['fournies'] as num?)?.toInt() ?? 0
        ..journal = JournalCatalogue.lire(_lireSiPresent(File('${d.path}${Platform.pathSeparator}journal.json')))
        ..publiee = Map<String, dynamic>.from(j['publiee'] as Map? ?? const {});
    } catch (e) {
      // 16/11/2026 : une base de recettes illisible était remplacée par une base vide au premier
      // enregistrement : elle est d'abord mise de côté, intacte.
      final cote = '${f.path}.illisible-${DateTime.now().millisecondsSinceEpoch}';
      var ou = 'mise de côté ($cote)';
      try {
        await f.rename(cote);
      } catch (e2) {
        ou = 'NON mise de côté ($e2)';
      }
      Etat.instance.noter('Base de recettes illisible, $ou : $e');
      return BaseRecettes(d);
    }
  }

  static String? _lireSiPresent(File f) {
    try {
      return f.existsSync() ? f.readAsStringSync() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> enregistrer() async {
    await dossier.create(recursive: true);
    // Le journal (instantanés compris) dans son propre fichier : recettes.json reste léger.
    if (journal.etapes.isNotEmpty || journal.enCours.isNotEmpty) {
      await File('${dossier.path}${Platform.pathSeparator}journal.json').writeAsString(journal.ecrire());
    }
    final f = File('${dossier.path}${Platform.pathSeparator}recettes.json');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert({
      'version': 1,
      if (versionFournie > 0) 'fournies': versionFournie,
      if (publiee.isNotEmpty) 'publiee': publiee,
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
    final cles = m.keys.toList()
      ..sort((a, b) {
        final r = _rangType(a).compareTo(_rangType(b));
        return r != 0 ? r : _norm(a).compareTo(_norm(b));
      });
    return {for (final k in cles) k: m[k]!..sort((a, b) => _norm(a.titre).compareTo(_norm(b.titre)))};
  }

  /// Images d'un dossier (et de ses sous-dossiers), par slug du nom de fichier.
  static Map<String, File> _imagesDu(Directory d) {
    final m = <String, File>{};
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final x = RegExp(r'^(.*)\.(jpe?g|png|webp)$', caseSensitive: false).firstMatch(f.uri.pathSegments.last);
      if (x != null) m[slugRecette(x.group(1)!)] = f;
    }
    return m;
  }

  /// Copie [image] dans la base comme illustration de [r] (nom horodaté : l'ancienne image en cache n'est pas reprise).
  Future<void> _poserIllustration(Recette r, File image) async {
    final ext = image.path.split('.').last.toLowerCase();
    final nom = 'illustration-${slugRecette(r.titre)}-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await image.copy(photo(nom).path);
    final avant = r.illustration;
    r.illustration = nom;
    if (avant != null && avant != nom) {
      try {
        photo(avant).deleteSync();
      } catch (_) {}
    }
  }

  /// Remplace les illustrations (12/11/2026, Aristide « je veux simplement changer les illustrations ») : chaque
  /// image du dossier dont le nom est le titre de la recette (« mousse-au-chocolat.jpg », accents et majuscules
  /// indifférents) devient son illustration. Rend (illustrations posées, images sans recette).
  Future<(int, List<String>)> importerIllustrations(Directory dossier) async {
    final images = _imagesDu(dossier);
    final utilisees = <String>{};
    var n = 0;
    for (final r in recettes) {
      final cle = slugRecette(r.titre);
      final f = images[cle];
      if (f == null) continue;
      await _poserIllustration(r, f);
      utilisees.add(cle);
      n++;
    }
    await enregistrer();
    return (n, [for (final e in images.entries) if (!utilisees.contains(e.key)) e.value.uri.pathSegments.last]);
  }

  /// Dossier des illustrations livrées avec la console (installateur : <programme>\recettes-illustrations).
  static Directory get dossierFourni =>
      Directory('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}recettes-illustrations');

  /// Pose les illustrations livrées avec la console (12/11/2026, Aristide : « vous l'intégrez dans le catalogue
  /// des recettes ») : illustrations.json associe l'identifiant de la recette (note Keep) à son image. Une image
  /// déjà posée n'est pas recopiée ; une image fournie plus récente (autre taille) remplace l'ancienne.
  Future<int> appliquerIllustrationsFournies([Directory? dossier]) async {
    final d = dossier ?? dossierFourni;
    final index = File('${d.path}${Platform.pathSeparator}illustrations.json');
    if (!index.existsSync()) return 0;
    final Map carte;
    try {
      carte = jsonDecode(await index.readAsString()) as Map;
    } catch (_) {
      return 0;
    }
    var n = 0;
    for (final r in recettes) {
      final nom = carte[r.id];
      if (nom is! String || r.retouchee) continue;
      final f = File('${d.path}${Platform.pathSeparator}$nom');
      if (!f.existsSync()) continue;
      final marque = '$nom:${f.lengthSync()}';
      if (r.illustrationFournie == marque && r.illustration != null && photo(r.illustration!).existsSync()) continue;
      await _poserIllustration(r, f);
      r.illustrationFournie = marque;
      n++;
    }
    if (n > 0) await enregistrer();
    return n;
  }

  /// Recettes reformulées livrées avec la console (12/11/2026, Aristide : « tous les textes des recettes doivent
  /// être reformulés ») : recettes-fournies.json remplace le texte des recettes de même identifiant et ajoute les
  /// autres ; les anciennes photos Keep sont retirées (« supprimez les anciennes »), seule l'illustration reste.
  /// Appliqué une fois par version du fichier.
  Future<int> appliquerRecettesFournies([Directory? dossierSource]) async {
    final d = dossierSource ?? dossierFourni;
    final f = File('${d.path}${Platform.pathSeparator}recettes-fournies.json');
    if (!f.existsSync()) return 0;
    final Map j;
    try {
      j = jsonDecode(await f.readAsString()) as Map;
    } catch (_) {
      return 0;
    }
    final version = (j['version'] as num?)?.toInt() ?? 1;
    if (version <= versionFournie) return 0;
    var n = 0, ajoutees = 0, maj = 0;
    for (final m in (j['recettes'] as List? ?? const []).cast<Map>()) {
      final r = Recette.lire(m);
      final i = recettes.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        // 20/11/2026 : une recette modifiée dans la console garde la version d'Aristide ; seul le classement
        // (21/11/2026) lui est donné s'il n'en a pas encore.
        if (recettes[i].retouchee) {
          final x = recettes[i];
          if (x.sousTypes.isEmpty && r.sousTypes.isNotEmpty) {
            x
              ..types = r.types
              ..sousTypes = r.sousTypes
              ..origine ??= r.origine;
            maj++;
          }
          continue;
        }
        r
          ..illustration = recettes[i].illustration
          ..illustrationFournie = recettes[i].illustrationFournie;
        if (gestesEntre(recettes[i], r).isNotEmpty) maj++;
        recettes[i] = r;
      } else {
        recettes.add(r);
        ajoutees++;
      }
      n++;
    }
    if (versionFournie > 0 && (ajoutees > 0 || maj > 0)) {
      journal.noter(['Recettes livrées avec la console (n° $version) : $ajoutees ajoutée(s), $maj mise(s) à jour']);
    }
    // Plus de photos Keep : fichiers retirés de la base, sauf les illustrations en usage.
    final gardees = {for (final r in recettes) if (r.illustration != null) r.illustration!};
    for (final r in recettes) {
      r.photos = [];
    }
    if (dossier.existsSync()) {
      for (final x in dossier.listSync().whereType<File>()) {
        final nom = x.uri.pathSegments.last;
        if (nom == 'recettes.json' || nom == 'journal.json' || nom.startsWith('illustration-') || gardees.contains(nom)) continue;
        try {
          x.deleteSync();
        } catch (_) {}
      }
    }
    versionFournie = version;
    await enregistrer();
    return n;
  }

  /// Change l'illustration d'une seule recette.
  Future<void> changerIllustration(Recette r, File image) async {
    await _poserIllustration(r, image);
    await enregistrer();
  }

  /// Importe les notes Keep (.json) du dossier [source] dont un libellé contient « recette » ; leurs photos sont
  /// copiées dans la base. Une recette déjà importée (même note) est mise à jour. [toutes] : aussi les notes
  /// sans libellé « Recette ».
  Future<BilanImport> importerKeep(Directory source, {bool toutes = false}) async {
    final bilan = BilanImport();
    await dossier.create(recursive: true);
    // Recettes normalisées (11/11/2026) : recettes-normalisees.json dans le dossier importé ou son parent,
    // rattachées aux notes par le nom du fichier Keep.
    final normalisees = <String, Map>{};
    for (final d in [source, source.parent]) {
      final n = File('${d.path}${Platform.pathSeparator}$fichierNormalise');
      if (!n.existsSync()) continue;
      try {
        for (final r in (jsonDecode(await n.readAsString()) as List).cast<Map>()) {
          if (r['fichier'] is String) normalisees[r['fichier'] as String] = r;
        }
        bilan.normalisees = normalisees.length;
      } catch (_) {
        bilan.erreurs.add('$fichierNormalise illisible');
      }
      break;
    }
    // Illustrations (12/11/2026) : <slug du titre>.jpg/.png dans un dossier « Illustrations » du dossier importé
    // ou de son parent.
    var illustrations = <String, File>{};
    for (final d in [source, source.parent]) {
      final dir = d.listSync().whereType<Directory>().where((x) => _norm(x.uri.pathSegments.where((p) => p.isNotEmpty).last) == 'illustrations');
      if (dir.isEmpty) continue;
      illustrations = _imagesDu(dir.first);
      break;
    }
    final fichiers = source.listSync().whereType<File>().where((f) {
      final n = f.uri.pathSegments.last;
      return n.toLowerCase().endsWith('.json') && n != fichierNormalise;
    }).toList()
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
      final texte = '${j['textContent'] ?? ''}';
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
      final nz = normalisees[f.uri.pathSegments.last];
      if (nz != null) {
        r.titre = '${nz['titre'] ?? r.titre}'.trim().isEmpty ? r.titre : '${nz['titre']}'.trim();
        final t = [for (final x in _textes(nz['types'])) typeDuLibelle(x)];
        if (t.isNotEmpty) r.types = t.toSet().toList();
        r.detail = [for (final i in (nz['ingredients'] as List? ?? const []).cast<Map>()) IngredientRecette.lire(i)]..removeWhere((i) => i.nom.isEmpty);
        r.ingredients = [for (final i in r.detail) i.texte];
        r.titreIngredients = r.detail.isEmpty ? null : 'Ingrédients';
        r.etapes = _textes(nz['etapes']);
        r.conseils = _textes(nz['conseils']);
        r.remarques = _textes(nz['remarques']);
        r.texteOrigine = nz['texte_origine'] as String? ?? texte;
        r.memo = nz['memo'] == true;
        if (r.etapes.isNotEmpty) r.preparation = [for (var k = 0; k < r.etapes.length; k++) '${k + 1}. ${r.etapes[k]}'].join('\n');
      }
      final ill = illustrations[slugRecette(r.titre)] ?? illustrations[slugRecette(titre)];
      if (ill != null) {
        await _poserIllustration(r, ill);
        bilan.illustrations++;
      } else {
        // Réimport sans dossier d'illustrations : on garde celle déjà rangée.
        final avant = recettes.where((x) => x.id == id).firstOrNull;
        r.illustration = avant?.illustration;
        r.illustrationFournie = avant?.illustrationFournie;
      }
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
