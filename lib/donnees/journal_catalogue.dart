import 'dart:convert';

/// Historique des modifications du catalogue commun dans l'outil de l'éditeur (07/11/2026, Aristide).
///
/// - En cours : chaque geste (ajout, renommage, déplacement, retrait) est noté avec sa date et son texte
///   (l'objet, l'avant et l'après) ; il est enregistré et visible, mais pas encore validé.
/// - Validée : « Valider les modifications » fige les gestes en cours en une étape nommée (par défaut le jour et
///   l'heure), point de sauvegarde qui garde tout le catalogue de ce moment.
/// - Généralisée : seule une étape validée se généralise, et rien ne doit être en cours.
/// Revenir à une étape abandonne toutes les modifications qui l'ont suivie.
class GesteCatalogue {
  GesteCatalogue(this.date, this.lignes);
  final DateTime date;

  /// Ce qu'a fait le geste, une ligne par changement (« Produit renommé : Kakis → Kaki »).
  final List<String> lignes;

  Map<String, dynamic> versJson() => {'d': date.toIso8601String(), 'l': lignes};
  factory GesteCatalogue.lire(Map j) => GesteCatalogue(DateTime.tryParse('${j['d']}') ?? DateTime(2026), [for (final x in (j['l'] as List? ?? const [])) '$x']);
}

class EtapeCatalogue {
  EtapeCatalogue(this.nom, this.date, this.gestes, this.instantane, {this.numero, this.libelle});
  final String nom;
  final DateTime date;
  final List<GesteCatalogue> gestes;

  /// Le brouillon complet à cette étape, emballé (« gz:… »).
  final String instantane;

  /// Numéro de la version généralisée qui la contient, ou null (validée seulement).
  int? numero;

  /// Nom de cette version (« 3.1 »), ou null (versions d'avant le 09/11/2026 : le numéro).
  String? libelle;

  /// « v3.1 » (ou « v3 » pour les anciennes).
  String get version => 'v${libelle ?? numero}';

  Map<String, dynamic> versJson() => {
        'nom': nom,
        'd': date.toIso8601String(),
        'g': [for (final g in gestes) g.versJson()],
        'i': instantane,
        if (numero != null) 'v': numero,
        if (libelle != null) 'l': libelle,
      };
  factory EtapeCatalogue.lire(Map j) => EtapeCatalogue(
        '${j['nom']}',
        DateTime.tryParse('${j['d']}') ?? DateTime(2026),
        [for (final g in (j['g'] as List? ?? const [])) GesteCatalogue.lire(g as Map)],
        '${j['i']}',
        numero: (j['v'] as num?)?.toInt(),
        libelle: j['l'] as String?,
      );
}

class JournalCatalogue {
  JournalCatalogue(this.etapes, this.enCours);
  final List<EtapeCatalogue> etapes;
  final List<GesteCatalogue> enCours;

  /// Au plus tant d'étapes gardées (les plus anciennes partent).
  static const maxEtapes = 100;

  factory JournalCatalogue.lire(String? texte) {
    if (texte == null || texte.isEmpty) return JournalCatalogue([], []);
    try {
      final j = jsonDecode(texte) as Map;
      return JournalCatalogue(
        [for (final e in (j['etapes'] as List? ?? const [])) EtapeCatalogue.lire(e as Map)],
        [for (final g in (j['enCours'] as List? ?? const [])) GesteCatalogue.lire(g as Map)],
      );
    } catch (_) {
      return JournalCatalogue([], []);
    }
  }

  String ecrire() => jsonEncode({
        'etapes': [for (final e in etapes) e.versJson()],
        'enCours': [for (final g in enCours) g.versJson()],
      });

  void noter(List<String> lignes, {DateTime? date}) {
    if (lignes.isEmpty) return;
    enCours.add(GesteCatalogue(date ?? DateTime.now(), lignes));
  }

  /// Fige les gestes en cours en une étape ; [instantane] est le brouillon emballé à ce moment.
  EtapeCatalogue valider(String nom, String instantane, {DateTime? date, int? numero, String? libelle}) {
    final e = EtapeCatalogue(nom, date ?? DateTime.now(), [...enCours], instantane, numero: numero, libelle: libelle);
    etapes.add(e);
    enCours.clear();
    if (etapes.length > maxEtapes) etapes.removeRange(0, etapes.length - maxEtapes);
    return e;
  }

  /// Revient à l'étape [i] : les étapes suivantes et les gestes en cours sont abandonnés ; rend son instantané.
  String revenirA(int i) {
    etapes.removeRange(i + 1, etapes.length);
    enCours.clear();
    return etapes[i].instantane;
  }

  /// Après une généralisation : les étapes validées pas encore publiées sont dans la version [numero].
  void generalisee(int numero, [String? libelle]) {
    for (final e in etapes) {
      if (e.numero != null) continue;
      e.numero = numero;
      e.libelle = libelle;
    }
  }

  /// Nom par défaut d'une étape : le jour et l'heure.
  static String nomParDefaut(DateTime d) {
    String z(int n) => n.toString().padLeft(2, '0');
    return '${z(d.day)}/${z(d.month)}/${d.year} à ${z(d.hour)}h${z(d.minute)}';
  }
}
