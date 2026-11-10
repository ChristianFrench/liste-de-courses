import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../composants/icone.dart';
import '../donnees/recettes.dart';
import '../navigation.dart';
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
  bool _import = false;

  @override
  void initState() {
    super.initState();
    if (widget.base != null) {
      base = widget.base;
    } else {
      BaseRecettes.ouvrir().then((b) {
        if (mounted) setState(() => base = b);
      }, onError: (Object e) {
        // Sans dossier de données (tests) : une base vide, en mémoire.
        if (mounted) setState(() => base = BaseRecettes(Directory.systemTemp.createTempSync('recettes')));
      });
    }
  }

  Future<void> _importer() async {
    final b = base;
    if (b == null) return;
    final chemin = await getDirectoryPath(confirmButtonText: 'Importer ce dossier');
    if (chemin == null || !mounted) return;
    setState(() => _import = true);
    try {
      final bilan = await b.importerKeep(Directory(chemin));
      if (!mounted) return;
      Nav.message(context, 'Import : $bilan');
    } catch (e) {
      if (mounted) Nav.message(context, 'Import impossible : $e');
    } finally {
      if (mounted) setState(() => _import = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = base;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TitrePageAdmin(
        'Contenu',
        'Catalogue des recettes',
        droite: SizedBox(
          width: 260,
          child: FilledButton.icon(
            key: const ValueKey('recettes-importer'),
            onPressed: b == null || _import ? null : _importer,
            icon: const Icon(Icons.download),
            label: Text(_import ? 'Import en cours…' : 'Importer un dossier Keep…'),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
        child: Text(
          'Base séparée, sans lien avec le catalogue publié. On importe le dossier dézippé de Google Takeout (Keep) : '
          'les notes libellées « Recettes … » sont lues, une recette déjà importée est mise à jour.',
          style: Charte.texte(14, couleur: Charte.texteSecondaire),
        ),
      ),
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
        child: Text(b.recettes.isEmpty ? 'Aucune recette : importez un dossier Keep.' : 'Choisissez une recette à gauche.',
            style: Charte.texte(16, couleur: Charte.texteSecondaire)),
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
            const SizedBox(width: 6),
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

Widget _vignette(BaseRecettes b, Recette r, double taille) {
  final f = r.photos.isEmpty ? null : b.photo(r.photos.first);
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: taille,
      height: taille,
      child: f == null || !f.existsSync()
          ? Container(color: Charte.placeholder, child: Icone(Icons.restaurant_menu, color: Charte.texteSecondaire))
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
                      child: Text(t, style: Charte.texte(13, couleur: Charte.cadre)),
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
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: SelectableText(r.preparation.isEmpty ? '—' : r.preparation, style: Charte.texte(16).copyWith(height: 1.45)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _photos() {
    final fichiers = [for (final p in recette.photos) base.photo(p)].where((f) => f.existsSync()).toList();
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

  Widget _ingredients() {
    final r = recette;
    if (r.ingredients.isEmpty) {
      return Center(child: Text('Pas de liste d\'ingrédients : tout est dans l\'onglet Recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
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
