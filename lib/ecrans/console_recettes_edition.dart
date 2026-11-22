import 'package:flutter/material.dart';

import '../composants/composants.dart' show Bouton;
import '../donnees/recettes.dart';
import '../theme.dart';

// Console › Catalogue des recettes › Modifier / Nouvelle recette (20/11/2026, Aristide : versions du catalogue
// des recettes comme pour les produits). Une fenêtre à trois onglets (Caractéristiques, Ingrédients, Recette, 22/11/2026) ; les ingrédients s'écrivent un par
// ligne sous la forme uniforme « Nom · quantité · précision », les étapes et les conseils un par ligne.

const valeursRegimes = ['Végétarien', 'Végétalien', 'Sans gluten', 'Sans lactose'];
const valeursSaisons = ['Printemps', 'Été', 'Automne', 'Hiver'];
const valeursCout = ['€', '€€', '€€€'];
const valeursCuissons = ['Sans cuisson', 'Four', 'Plaque', 'Cocotte-minute'];
const valeursOccasions = ['Quotidien', "À l'avance", 'À recevoir', 'À emporter'];

/// « Nom · quantité · précision » ↔ ingrédient.
String ligneIngredient(IngredientRecette i) => [i.nom, i.quantite, i.precision].where((x) => x.isNotEmpty).length == 1
    ? i.nom
    : [i.nom, i.quantite, if (i.precision.isNotEmpty) i.precision].join(' · ');

IngredientRecette? lireLigneIngredient(String l) {
  final p = l.split('·').map((x) => x.trim()).toList();
  if (p.isEmpty || p.first.isEmpty) return null;
  return IngredientRecette(p[0], quantite: p.length > 1 ? p[1] : '', precision: p.length > 2 ? p.sublist(2).join(' · ') : '');
}

List<String> _lignes(String t) => [for (final l in t.split('\n')) if (l.trim().isNotEmpty) l.trim().replaceFirst(RegExp(r'^\d+[.)]\s*'), '')];

/// Ouvre la fenêtre de modification ; rend la recette modifiée (une copie), ou null (abandon).
Future<Recette?> editerRecette(BuildContext context, {Recette? recette, required BaseRecettes base}) {
  return showDialog<Recette>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FenetreRecette(recette: recette, base: base),
  );
}

class _FenetreRecette extends StatefulWidget {
  const _FenetreRecette({required this.recette, required this.base});
  final Recette? recette;
  final BaseRecettes base;

  @override
  State<_FenetreRecette> createState() => _FenetreRecetteState();
}

class _FenetreRecetteState extends State<_FenetreRecette> {
  late final Recette? r = widget.recette;
  late final titre = TextEditingController(text: r?.titre ?? '');
  late final pour = TextEditingController(text: r?.pour ?? '4 personnes');
  late final prep = TextEditingController(text: r?.tempsPreparation?.toString() ?? '');
  late final cuisson = TextEditingController(text: r?.tempsCuisson?.toString() ?? '');
  late final ingredients = TextEditingController(text: [for (final i in r?.detail ?? const <IngredientRecette>[]) ligneIngredient(i)].join('\n'));
  late final etapes = TextEditingController(text: (r?.etapes ?? const <String>[]).join('\n'));
  late final conseils = TextEditingController(text: (r?.conseils ?? const <String>[]).join('\n'));
  late final types = {...?r?.types};
  late String? difficulte = r?.difficulte ?? 'Facile';
  late final regimes = {...?r?.regimes};
  late final saisons = {...(r == null ? valeursSaisons : r!.saisons)};
  late String? cout = r?.cout ?? '€€';
  late final sousTypes = <String, String?>{...?r?.sousTypes};
  late String? origine = r?.origine ?? 'France';
  late final cuissons = {...?r?.cuissons};
  late final occasions = {...?r?.occasions};
  String? erreur;

  void _enregistrer() {
    final t = titre.text.trim();
    if (t.isEmpty) {
      setState(() => erreur = 'Le titre est obligatoire.');
      return;
    }
    if (types.isEmpty) {
      setState(() => erreur = 'Choisissez au moins un type.');
      return;
    }
    final detail = [for (final l in _lignes(ingredients.text)) if (lireLigneIngredient(l) case final i?) i];
    final et = _lignes(etapes.text);
    final x = r?.copie() ??
        Recette(id: widget.base.nouvelIdentifiant(t), titre: t, types: const [], ingredients: const [], preparation: '', photos: const [],
            source: 'Emplettes');
    x
      ..titre = t
      ..types = [for (final y in typesRecettes.keys) if (types.contains(y)) y]
      ..sousTypes = {for (final y in typesRecettes.keys) if (types.contains(y) && sousTypes[y] != null) y: sousTypes[y]!}
      ..origine = origine
      ..pour = pour.text.trim().isEmpty ? null : pour.text.trim()
      ..tempsPreparation = int.tryParse(prep.text.trim())
      ..tempsCuisson = int.tryParse(cuisson.text.trim())
      ..difficulte = difficulte
      ..detail = detail
      ..ingredients = [for (final i in detail) i.texte]
      ..titreIngredients = 'Ingrédients'
      ..etapes = et
      ..preparation = [for (var i = 0; i < et.length; i++) '${i + 1}. ${et[i]}'].join('\n')
      ..conseils = _lignes(conseils.text)
      ..regimes = [for (final y in valeursRegimes) if (regimes.contains(y)) y]
      ..saisons = [for (final y in valeursSaisons) if (saisons.contains(y)) y]
      ..cout = cout
      ..cuissons = [for (final y in valeursCuissons) if (cuissons.contains(y)) y]
      ..occasions = [for (final y in valeursOccasions) if (occasions.contains(y)) y];
    Navigator.of(context).pop(x);
  }

  Widget _champ(TextEditingController c, String libelle, {String? aide, int lignes = 1, Key? cle, double? largeur, bool nombre = false}) {
    final champ = TextField(
      key: cle,
      controller: c,
      minLines: lignes,
      maxLines: lignes == 1 ? 1 : null,
      keyboardType: nombre ? TextInputType.number : (lignes > 1 ? TextInputType.multiline : TextInputType.text),
      style: Charte.texte(15),
      decoration: InputDecoration(labelText: libelle, hintText: aide, alignLabelWithHint: lignes > 1),
    );
    return largeur == null ? champ : SizedBox(width: largeur, child: champ);
  }

  /// Une ligne « libellé : valeur », la même pour tous les critères (22/11/2026).
  Widget _rangee(String libelle, Widget valeur) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 170, child: Text(libelle, style: Charte.texte(14, gras: true, couleur: Charte.encreNiveau))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: valeur)),
        ]),
      );

  Widget _choix(String titre, List<String> valeurs, bool Function(String) actif, void Function(String) basculer) => _rangee(
        titre,
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in valeurs)
            FilterChip(
              key: ValueKey('critere-$titre-$v'),
              label: Text(v, style: Charte.texte(13.5)),
              selected: actif(v),
              onSelected: (_) => setState(() => basculer(v)),
            ),
        ]),
      );

  Widget _liste<T>(Key cle, T valeur, List<(T, String)> valeurs, void Function(T?) choisir) => SizedBox(
        width: 320,
        child: DropdownButton<T>(
          key: cle,
          isExpanded: true,
          value: valeur,
          items: [for (final (v, l) in valeurs) DropdownMenuItem<T>(value: v, child: Text(l, style: Charte.texte(15)))],
          onChanged: (v) => setState(() => choisir(v)),
        ),
      );

  void _bascule(Set<String> s, String v) => s.contains(v) ? s.remove(v) : s.add(v);

  /// Onglet Caractéristiques : titre, types et sous-types, origine, temps, difficulté et critères,
  /// tous sur le même modèle de ligne.
  Widget _caracteristiques() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 14), children: [
        _champ(titre, 'Titre', cle: const ValueKey('edition-titre')),
        const SizedBox(height: 14),
        _choix('Types', typesRecettes.keys.toList(), types.contains, (v) => _bascule(types, v)),
        for (final t in typesRecettes.keys)
          if (types.contains(t))
            _rangee(
              'Sous-type $t',
              _liste<String?>(ValueKey('edition-sous-type-$t'), typesRecettes[t]!.contains(sousTypes[t]) ? sousTypes[t] : null,
                  [(null, 'Aucun'), for (final s in typesRecettes[t]!) (s, s)], (v) => sousTypes[t] = v),
            ),
        _rangee('Origine',
            _liste<String?>(const ValueKey('edition-origine'), origine, [(null, 'Non précisée'), for (final o in originesRecettes) (o, o)], (v) => origine = v)),
        _rangee(
          'Temps (minutes)',
          Row(children: [
            _champ(prep, 'Préparation', largeur: 150, nombre: true, cle: const ValueKey('edition-preparation')),
            const SizedBox(width: 12),
            _champ(cuisson, 'Cuisson', largeur: 150, nombre: true, cle: const ValueKey('edition-cuisson')),
          ]),
        ),
        _rangee('Difficulté',
            _liste<String?>(const ValueKey('edition-difficulte'), difficulte, [for (final d in niveauxDifficulte) (d, d)], (v) => difficulte = v)),
        _choix('Régime', valeursRegimes, regimes.contains, (v) => _bascule(regimes, v)),
        _choix('Saison', valeursSaisons, saisons.contains, (v) => _bascule(saisons, v)),
        _choix('Coût', valeursCout, (v) => cout == v, (v) => cout = cout == v ? null : v),
        _choix('Mode de cuisson', valeursCuissons, cuissons.contains, (v) => _bascule(cuissons, v)),
        _choix('Occasion', valeursOccasions, occasions.contains, (v) => _bascule(occasions, v)),
      ]);

  /// Onglet Ingrédients : le nombre de personnes, puis un ingrédient par ligne.
  Widget _ingredients() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 14), children: [
        _champ(pour, 'Pour', aide: '4 personnes', largeur: 240, cle: const ValueKey('edition-pour')),
        const SizedBox(height: 14),
        _champ(ingredients, 'Ingrédients, un par ligne : Nom · quantité · précision', aide: 'Pommes de terre · 1 kg · type Charlotte',
            lignes: 18, cle: const ValueKey('edition-ingredients')),
      ]);

  /// Onglet Recette : les étapes, puis les conseils.
  Widget _recette() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 14), children: [
        _champ(etapes, "Étapes, une par ligne (verbes à l'infinitif)", lignes: 16, cle: const ValueKey('edition-etapes')),
        const SizedBox(height: 14),
        _champ(conseils, 'Conseils, un par ligne', lignes: 4, cle: const ValueKey('edition-conseils')),
      ]);

  @override
  Widget build(BuildContext context) {
    // 22/11/2026 (Aristide) : la fenêtre de modification a les mêmes trois onglets que la fiche.
    return Dialog(
      backgroundColor: Charte.blanc,
      child: SizedBox(
        width: 1040,
        height: 780,
        child: DefaultTabController(
          length: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: Charte.fondBandeau,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Text(r == null ? 'Nouvelle recette' : 'Modifier « ${r!.titre} »', style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau)),
            ),
            TabBar(
              labelStyle: Charte.texte(15, gras: true),
              unselectedLabelStyle: Charte.texte(15),
              labelColor: Charte.encreNiveau,
              indicatorColor: Charte.cadre,
              tabs: const [Tab(text: 'Caractéristiques'), Tab(text: 'Ingrédients'), Tab(text: 'Recette')],
            ),
            Container(height: 1, color: Charte.separateurZone),
            Expanded(child: TabBarView(children: [_caracteristiques(), _ingredients(), _recette()])),
            Container(height: 1, color: Charte.separateurZone),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                if (erreur != null) Expanded(child: Text(erreur!, style: Charte.texte(14, gras: true, couleur: Charte.rouge))) else const Spacer(),
                Bouton(key: const ValueKey('edition-annuler'), texte: 'Annuler', onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 10),
                Bouton(key: const ValueKey('edition-enregistrer'), texte: 'Enregistrer', plein: true, icone: Icons.check, onTap: _enregistrer),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
