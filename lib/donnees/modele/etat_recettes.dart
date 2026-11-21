part of '../modele.dart';

// « Note préparée » (21/11/2026, Aristide) : en tête du cycle des courses, on choisit des recettes et on note
// leurs ingrédients, sans liste ouverte ; à la préparation d'une liste, chaque recette de la note est traitée
// (ingrédients ajoutés) ou ignorée. Comme tout le reste, la note est commune au foyer.

/// Une recette de la note : ses ingrédients notés (lignes de la recette), son état et la liste qui l'a traitée.
class NoteRecette {
  NoteRecette({
    required this.id,
    this.recette,
    required this.titre,
    this.personnes,
    this.ingredients = const [],
    this.etat = aTraiter,
    this.liste,
    List<Map<String, dynamic>>? aRegler,
    DateTime? le,
  })  : aRegler = aRegler ?? [],
        le = le ?? DateTime.now();

  static const aTraiter = 'a', traitee = 't', ignoree = 'i';

  final String id;

  /// Identifiant dans le catalogue des recettes.
  final String? recette;
  final String titre;
  final int? personnes;

  /// Lignes d'ingrédients cochées (telles qu'écrites dans la recette, avant ajustement des quantités).
  final List<String> ingredients;
  String etat;

  /// Liste qui l'a traitée ou ignorée.
  String? liste;
  final DateTime le;

  /// Ingrédients cochés mais pas ajoutés (21/11/2026, Aristide) : inconnus du catalogue (à placer) ou présents
  /// dans plusieurs secteurs (à choisir). Chacun : {t: ligne de la recette, n: nom, c: [produits possibles]}.
  final List<Map<String, dynamic>> aRegler;

  factory NoteRecette.depuis(Map j) => NoteRecette(
        id: j['id'] as String,
        recette: j['recette'] as String?,
        titre: j['titre'] as String? ?? '',
        personnes: (j['personnes'] as num?)?.toInt(),
        ingredients: [for (final x in (j['ingredients'] as List? ?? const [])) '$x'],
        etat: j['etat'] as String? ?? aTraiter,
        liste: j['liste'] as String?,
        aRegler: [for (final x in (j['aRegler'] as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)],
        le: DateTime.tryParse(j['le'] as String? ?? ''),
      );

  Map<String, dynamic> versJson() => {
        'id': id,
        if (recette != null) 'recette': recette,
        'titre': titre,
        if (personnes != null) 'personnes': personnes,
        if (ingredients.isNotEmpty) 'ingredients': ingredients,
        'etat': etat,
        if (liste != null) 'liste': liste,
        if (aRegler.isNotEmpty) 'aRegler': aRegler,
        'le': le.toIso8601String().substring(0, 16),
      };
}

extension EtatRecettes on Etat {
  /// La recette notée et encore à traiter, s'il y en a une.
  NoteRecette? noteATraiter(String? recette, String titre) =>
      noteRecettes.where((n) => n.etat == NoteRecette.aTraiter && (n.recette ?? n.titre) == (recette ?? titre)).firstOrNull;

  /// Note (ou renote) les ingrédients d'une recette : une seule entrée à traiter par recette.
  void noterRecette({String? recette, required String titre, int? personnes, required List<String> ingredients}) {
    noteRecettes.removeWhere((n) => n.etat == NoteRecette.aTraiter && (n.recette ?? n.titre) == (recette ?? titre));
    noteRecettes.add(NoteRecette(id: nouvelId('n'), recette: recette, titre: titre, personnes: personnes, ingredients: ingredients));
    modifie();
  }

  void retirerDeLaNote(NoteRecette n) {
    noteRecettes.remove(n);
    modifie();
  }

  /// Les recettes à montrer en tête d'une liste en préparation : celles à traiter, puis celles traitées ou
  /// ignorées pour cette liste.
  List<NoteRecette> recettesDeListe(Liste l) => [
        for (final n in noteRecettes) if (n.etat == NoteRecette.aTraiter) n,
        for (final n in noteRecettes) if (n.etat != NoteRecette.aTraiter && n.liste == l.id) n,
      ];

  /// Recettes traitées pour une liste (mémo en tête de liste).
  List<NoteRecette> recettesTraitees(Liste l) =>
      [for (final n in noteRecettes) if (n.etat == NoteRecette.traitee && n.liste == l.id) n];

  void marquerRecette(NoteRecette n, String etat, Liste? l) {
    n.etat = etat;
    n.liste = etat == NoteRecette.aTraiter ? null : l?.id;
    // Les recettes des listes qui n'existent plus ne servent plus.
    noteRecettes.removeWhere((x) => x.liste != null && liste(x.liste) == null);
    modifie();
  }

  /// Recette choisie directement depuis la préparation (bouton « Recette ») : notée comme traitée pour [l].
  void recetteTraitee(Liste l,
      {String? recette, required String titre, int? personnes, required List<String> ingredients, List<Map<String, dynamic>>? aRegler}) {
    noteRecettes.removeWhere((n) => n.etat == NoteRecette.aTraiter && (n.recette ?? n.titre) == (recette ?? titre));
    noteRecettes.add(NoteRecette(
        id: nouvelId('n'), recette: recette, titre: titre, personnes: personnes, ingredients: ingredients,
        etat: NoteRecette.traitee, liste: l.id, aRegler: aRegler));
    modifie();
  }

  /// Fixe les ingrédients à régler d'une recette traitée.
  void definirARegler(NoteRecette n, List<Map<String, dynamic>> aRegler) {
    n.aRegler
      ..clear()
      ..addAll(aRegler);
    modifie();
  }

  /// Un ingrédient à régler est réglé (produit choisi ou placé, ou abandonné).
  void reglerIngredient(NoteRecette n, Map<String, dynamic> x) {
    n.aRegler.remove(x);
    modifie();
  }
}
