import 'dart:io';

import 'package:flutter/material.dart';

import '../composants/icone.dart';
import '../donnees/recettes.dart';
import '../theme.dart';
import 'administration_serveur.dart' show TitrePageAdmin;

// Console › Catalogue des recettes (10/11/2026, Aristide) : base séparée, importée des notes Google Keep.
// À gauche, la liste façon catalogue : un bandeau dépliable par type (Plats, Sauces, Desserts…), puis ses
// recettes avec leur vignette. À droite, la fiche de la recette choisie : bandeau du titre et de ses types,
// puis les onglets Photos / Ingrédients / Recette.

class PageRecettes extends StatefulWidget {
  const PageRecettes({super.key, this.base});

  /// Base imposée (tests) ; sinon celle du dossier de la console.
  final BaseRecettes? base;

  @override
  State<PageRecettes> createState() => _PageRecettesState();
}

class _PageRecettesState extends State<PageRecettes> {
  BaseRecettes? base;
  Recette? choisie;
  final ouverts = <String>{};
  String recherche = '';

  @override
  void initState() {
    super.initState();
    if (widget.base != null) {
      base = widget.base;
    } else {
      BaseRecettes.ouvrir().then((b) async {
        // Recettes reformulées et illustrations livrées avec la console : posées sans rien demander.
        try {
          await b.appliquerRecettesFournies();
        } catch (_) {}
        try {
          await b.appliquerIllustrationsFournies();
        } catch (_) {}
        if (mounted) setState(() => base = b);
      }, onError: (Object e) {
        // Sans dossier de données (tests) : une base vide, en mémoire.
        if (mounted) setState(() => base = BaseRecettes(Directory.systemTemp.createTempSync('recettes')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = base;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 12/11/2026 (Aristide) : plus de bouton d'import Keep ; les recettes reformulées et leurs illustrations
      // sont livrées avec la console et posées à l'ouverture.
      const TitrePageAdmin('Contenu', 'Catalogue des recettes'),
      Expanded(
        child: b == null
            ? Center(child: Text('Chargement…', style: Charte.texte(16, couleur: Charte.texteSecondaire)))
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 440, child: _cadre(_liste(b))),
                  const SizedBox(width: 16),
                  Expanded(child: _cadre(choisie == null ? _aucune(b) : FicheRecette(key: ValueKey(choisie!.id), recette: choisie!, base: b))),
                ]),
              ),
      ),
    ]);
  }

  Widget _cadre(Widget enfant) => Container(
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Charte.separateurZone),
        ),
        clipBehavior: Clip.antiAlias,
        child: enfant,
      );

  Widget _aucune(BaseRecettes b) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/recettes/recettes-de-cuisine.png', width: 128, height: 128),
          const SizedBox(height: 12),
          Text(b.recettes.isEmpty ? 'Aucune recette.' : 'Choisissez une recette à gauche.',
              style: Charte.texte(16, couleur: Charte.texteSecondaire)),
        ]),
      );

  Widget _liste(BaseRecettes b) {
    final q = recherche.trim().toLowerCase();
    final groupes = b.parType();
    final lignes = <Widget>[];
    for (final MapEntry(key: type, value: l) in groupes.entries) {
      final visibles = [for (final r in l) if (q.isEmpty || r.titre.toLowerCase().contains(q) || r.ingredients.any((i) => i.toLowerCase().contains(q))) r];
      if (visibles.isEmpty) continue;
      final ouvert = q.isNotEmpty || ouverts.contains(type);
      lignes.add(InkWell(
        key: ValueKey('type-recette-$type'),
        onTap: () => setState(() => ouvert && q.isEmpty ? ouverts.remove(type) : ouverts.add(type)),
        child: Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            Icone(ouvert ? Icons.expand_more : Icons.chevron_right, color: Charte.cadre),
            const SizedBox(width: 4),
            Image.asset(iconeTypeRecette(type), width: 36, height: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(type, style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau))),
            Text('${visibles.length}', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ]),
        ),
      ));
      if (!ouvert) continue;
      for (final r in visibles) {
        final actif = identical(r, choisie);
        lignes.add(InkWell(
          key: ValueKey('recette-${r.id}-$type'),
          onTap: () => setState(() => choisie = r),
          child: Container(
            color: actif ? Charte.fondSelection : null,
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(children: [
              _vignette(b, r, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: Charte.texte(15, gras: actif)),
                  Text(r.ingredients.isEmpty ? 'Texte seul' : '${r.ingredients.length} ingrédients',
                      style: Charte.texte(12.5, couleur: Charte.texteSecondaire)),
                ]),
              ),
            ]),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('recettes-recherche'),
              style: Charte.texte(15),
              decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Une recette ou un ingrédient'),
              onChanged: (v) => setState(() => recherche = v),
            ),
          ),
          Tooltip(
            message: ouverts.length == groupes.length ? 'Tout replier' : 'Tout déplier',
            child: IconButton(
              onPressed: () => setState(() => ouverts.length == groupes.length ? ouverts.clear() : ouverts.addAll(groupes.keys)),
              icon: Icone(ouverts.length == groupes.length ? Icons.unfold_less : Icons.unfold_more, color: Charte.cadre),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('${b.recettes.length} recette${b.recettes.length > 1 ? 's' : ''} · ${groupes.length} type${groupes.length > 1 ? 's' : ''}',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ),
      Container(height: 1, color: Charte.separateurZone),
      Expanded(child: ListView(children: lignes)),
    ]);
  }
}

/// Icône d'un type de recette (images d'Aristide, 11/11/2026) ; « recettes-de-cuisine » pour les autres.
String iconeTypeRecette(String type) {
  final t = type.toLowerCase();
  if (t.startsWith('dessert')) return 'assets/recettes/desserts.png';
  if (t.startsWith('entr')) return 'assets/recettes/entrees.png';
  if (t.contains('accompagnement')) return 'assets/recettes/plats-accompagnement.png';
  if (t.startsWith('plat')) return 'assets/recettes/plats-complets.png';
  if (t.startsWith('sauce')) return 'assets/recettes/sauces.png';
  return 'assets/recettes/recettes-de-cuisine.png';
}

Widget _vignette(BaseRecettes b, Recette r, double taille) {
  final nom = r.illustration ?? (r.photos.isEmpty ? null : r.photos.first);
  final f = nom == null ? null : b.photo(nom);
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: taille,
      height: taille,
      child: f == null || !f.existsSync()
          ? Image.asset(iconeTypeRecette(r.types.isEmpty ? '' : r.types.first), fit: BoxFit.contain)
          : Image.file(f, fit: BoxFit.cover, cacheWidth: (taille * 2).round()),
    ),
  );
}

/// Fiche d'une recette : bandeau (photo, titre, types, nombre d'ingrédients), puis les onglets.
class FicheRecette extends StatelessWidget {
  const FicheRecette({super.key, required this.recette, required this.base});
  final Recette recette;
  final BaseRecettes base;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    return DefaultTabController(
      length: 3,
      initialIndex: r.ingredients.isEmpty ? 2 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(children: [
            _vignette(base, r, 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.titre, style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final t in r.types)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Charte.blanc, borderRadius: BorderRadius.circular(12), border: Border.all(color: Charte.cadre)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset(iconeTypeRecette(t), width: 18, height: 18),
                        const SizedBox(width: 5),
                        Text(t, style: Charte.texte(13, couleur: Charte.cadre)),
                      ]),
                    ),
                  Text(
                      '${r.ingredients.length} ingrédient${r.ingredients.length > 1 ? 's' : ''} · ${r.photos.length} photo${r.photos.length > 1 ? 's' : ''}'
                      '${r.modifieeLe == null ? '' : ' · modifiée le ${r.modifieeLe!.day.toString().padLeft(2, '0')}/${r.modifieeLe!.month.toString().padLeft(2, '0')}/${r.modifieeLe!.year}'}',
                      style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ]),
              ]),
            ),
          ]),
        ),
        TabBar(
          labelStyle: Charte.texte(15, gras: true),
          unselectedLabelStyle: Charte.texte(15),
          labelColor: Charte.encreNiveau,
          indicatorColor: Charte.cadre,
          tabs: const [Tab(text: 'Photos'), Tab(text: 'Ingrédients'), Tab(text: 'Recette')],
        ),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(
          child: TabBarView(children: [
            _photos(),
            _ingredients(),
            _recette(),
          ]),
        ),
      ]),
    );
  }

  Widget _photos() {
    final fichiers = [
      for (final p in [if (recette.illustration != null) recette.illustration!, ...recette.photos]) base.photo(p)
    ].where((f) => f.existsSync()).toList();
    if (fichiers.isEmpty) return Center(child: Text('Pas de photo', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final f in fichiers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(f, fit: BoxFit.contain)),
            ),
          ),
        ),
    ]);
  }

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
      );

  /// Onglet Recette : étapes numérotées, conseils, remarques à confirmer, texte Keep d'origine (replié).
  Widget _recette() {
    final r = recette;
    if (r.etapes.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: SelectableText(r.preparation.isEmpty ? '—' : r.preparation, style: Charte.texte(16).copyWith(height: 1.45)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 22), children: [
      for (var k = 0; k < r.etapes.length; k++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle),
              child: Text('${k + 1}', style: Charte.texte(14, gras: true, couleur: Charte.blanc)),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: SelectableText(r.etapes[k], style: Charte.texte(16).copyWith(height: 1.4)))),
          ]),
        ),
      if (r.conseils.isNotEmpty) ...[
        _titre('Conseils'),
        for (final c in r.conseils) _puce(c),
      ],
      if (r.remarques.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Charte.clair(Charte.orange, 0.88),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Charte.orange),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('À confirmer', style: Charte.texte(15, gras: true, couleur: Charte.orange)),
            const SizedBox(height: 6),
            for (final m in r.remarques) _puce(m),
          ]),
        ),
      if (r.texteOrigine != null && r.texteOrigine!.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Texte d\'origine (Google Keep)', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(r.texteOrigine!.trim(), style: Charte.texte(14, couleur: Charte.texteSecondaire).copyWith(height: 1.4)),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _puce(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle))),
          Expanded(child: SelectableText(t, style: Charte.texte(16))),
        ]),
      );

  Widget _ingredients() {
    final r = recette;
    if (r.detail.isNotEmpty) {
      // Recette normalisée : quantité · nom · précision, en colonnes.
      return ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 22), children: [
        for (final i in r.detail)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: SelectableText(i.quantite.isEmpty ? '—' : i.quantite, style: Charte.texte(16, couleur: Charte.texteSecondaire))),
              Expanded(
                child: SelectableText.rich(TextSpan(children: [
                  TextSpan(text: i.nom, style: Charte.texte(16, gras: true)),
                  if (i.precision.isNotEmpty) TextSpan(text: '  ${i.precision}', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ])),
              ),
            ]),
          ),
      ]);
    }
    if (r.ingredients.isEmpty) {
      return Center(child: Text(r.memo ? 'Mémo sans ingrédients : voir l\'onglet Recette.' : 'Pas de liste d\'ingrédients : tout est dans l\'onglet Recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 22), children: [
      if (r.titreIngredients != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(r.titreIngredients!.replaceFirst(RegExp(r'\s*:\s*$'), ''), style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
        ),
      for (final i in r.ingredients)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle))),
            Expanded(child: SelectableText(i, style: Charte.texte(16))),
          ]),
        ),
    ]);
  }
}
