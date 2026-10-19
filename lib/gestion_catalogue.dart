import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'composants/pictogramme.dart';
import 'donnees/catalogue_type.dart';
import 'gestion_catalogue/tableur.dart';
import 'theme.dart';

// « Gestion du catalogue » : petite application Windows pour tenir à jour le catalogue type
// (rayons, secteurs, produits) que l'application propose à la création d'un magasin.
// Trois colonnes : rayons, secteurs du rayon choisi, produits du secteur choisi.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Gestion du catalogue', size: Size(1280, 800), minimumSize: Size(900, 560), center: true),
      () async {
        await windowManager.setResizable(true);
        await windowManager.setMaximizable(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(MaterialApp(
    title: 'Gestion du catalogue',
    debugShowCheckedModeBanner: false,
    theme: Charte.theme(),
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const EcranCatalogue(),
  ));
}

const _lettre = {1: 'P', 2: 'S', 3: 'H'};
const _orange = Color(0xFFB26A00);

class EcranCatalogue extends StatefulWidget {
  const EcranCatalogue({super.key, this.catalogue});
  final CatalogueType? catalogue; // pour les essais
  @override
  State<EcranCatalogue> createState() => _EcranCatalogueState();
}

class _EcranCatalogueState extends State<EcranCatalogue> with WindowListener {
  CatalogueType? c;
  CatRayon? rayon;
  CatSecteur? secteur;
  final Set<CatProduit> choix = {};
  bool mesProduits = false;
  int modifs = 0;
  String recherche = '';
  final rechercheCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isWindows && widget.catalogue == null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
    _charger();
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isWindows && widget.catalogue == null) windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _charger({bool livre = false}) async {
    final cat = widget.catalogue ?? (livre ? CatalogueType.lire(await CatalogueType.livre()) : await CatalogueType.charger());
    setState(() {
      c = cat;
      rayon = cat.rayons.isEmpty ? null : cat.rayons.first;
      secteur = rayon == null || rayon!.secteurs.isEmpty ? null : rayon!.secteurs.first;
      choix.clear();
      modifs = livre ? 1 : 0;
    });
  }

  void _modifier(VoidCallback f) => setState(() {
        f();
        modifs++;
      });

  void _message(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));

  @override
  void onWindowClose() async {
    if (modifs == 0 || await _confirmer('Quitter sans enregistrer ?', 'Les modifications non enregistrées seront perdues.', 'Quitter')) {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  // ---------------------------------------------------------------- dialogues

  Future<bool> _confirmer(String titre, String texte, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titre),
          content: Text(texte),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<String?> _nom(String titre, [String initial = '']) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: SizedBox(
          width: 420,
          child: TextField(controller: ctl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Valider')),
        ],
      ),
    ).then((v) => v == null || v.isEmpty ? null : v);
  }

  Future<CatSecteur?> _choisirSecteur(String titre) {
    CatRayon r = rayon ?? c!.rayons.first;
    CatSecteur? s;
    return showDialog<CatSecteur>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => AlertDialog(
          title: Text(titre),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<CatRayon>(
                initialValue: r,
                decoration: const InputDecoration(labelText: 'Rayon'),
                items: [for (final x in c!.rayons) DropdownMenuItem(value: x, child: Text(x.nom))],
                onChanged: (x) => maj(() {
                  r = x!;
                  s = null;
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CatSecteur>(
                key: ValueKey(r),
                initialValue: s,
                decoration: const InputDecoration(labelText: 'Secteur'),
                items: [for (final x in r.secteurs) DropdownMenuItem(value: x, child: Text(x.nom))],
                onChanged: (x) => maj(() => s = x),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: s == null ? null : () => Navigator.pop(ctx, s), child: const Text('Déplacer')),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  bool _nomPris(Iterable<String> noms, String nom, [String? sauf]) =>
      noms.any((n) => n.toLowerCase() == nom.toLowerCase() && n != sauf);

  Future<void> _ajouterRayon() async {
    final n = await _nom('Nouveau rayon');
    if (n == null) return;
    if (_nomPris(c!.rayons.map((r) => r.nom), n)) return _message('Le rayon « $n » existe déjà.');
    _modifier(() {
      rayon = CatRayon(n);
      c!.rayons.add(rayon!);
      secteur = null;
    });
  }

  Future<void> _ajouterSecteur() async {
    final r = rayon;
    if (r == null) return;
    final n = await _nom('Nouveau secteur dans « ${r.nom} »');
    if (n == null) return;
    if (_nomPris(r.secteurs.map((s) => s.nom), n)) return _message('Le secteur « $n » existe déjà dans ce rayon.');
    _modifier(() {
      secteur = CatSecteur(n, 1);
      r.secteurs.add(secteur!);
    });
  }

  Future<void> _ajouterProduits() async {
    final s = secteur;
    if (s == null) return;
    final ctl = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter des produits dans « ${s.nom} »'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: ctl,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(hintText: 'Un produit par ligne'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (texte == null) return;
    final existants = {for (final (_, _, p) in c!.tousLesProduits) p.nom.toLowerCase()};
    final dejaLa = <String>[];
    var n = 0;
    _modifier(() {
      for (final l in texte.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
        if (!existants.add(l.toLowerCase())) {
          dejaLa.add(l);
          continue;
        }
        s.produits.add(CatProduit(l, s.taille));
        n++;
      }
    });
    _message('$n produit${n > 1 ? 's' : ''} ajouté${n > 1 ? 's' : ''}'
        '${dejaLa.isEmpty ? '' : ' ; déjà au catalogue : ${dejaLa.join(', ')}'}');
  }

  Future<void> _renommerRayon(CatRayon r) async {
    final n = await _nom('Renommer le rayon', r.nom);
    if (n == null || n == r.nom) return;
    if (_nomPris(c!.rayons.map((x) => x.nom), n, r.nom)) return _message('Le rayon « $n » existe déjà.');
    _modifier(() => r.nom = n);
  }

  Future<void> _renommerSecteur(CatRayon r, CatSecteur s) async {
    final n = await _nom('Renommer le secteur', s.nom);
    if (n == null || n == s.nom) return;
    if (_nomPris(r.secteurs.map((x) => x.nom), n, s.nom)) return _message('Le secteur « $n » existe déjà dans ce rayon.');
    _modifier(() => s.nom = n);
  }

  Future<void> _renommerProduit(CatProduit p) async {
    final n = await _nom('Renommer le produit', p.nom);
    if (n == null || n == p.nom) return;
    if (_nomPris([for (final (_, _, x) in c!.tousLesProduits) x.nom], n, p.nom)) {
      return _message('Le produit « $n » existe déjà.');
    }
    _modifier(() => p.nom = n);
  }

  Future<void> _supprimerRayon(CatRayon r) async {
    final np = r.secteurs.fold<int>(0, (a, s) => a + s.produits.length);
    if (!await _confirmer('Supprimer le rayon « ${r.nom} » ?',
        '${r.secteurs.length} secteur(s) et $np produit(s) seront supprimés du catalogue.', 'Supprimer')) {
      return;
    }
    _modifier(() {
      c!.rayons.remove(r);
      if (rayon == r) {
        rayon = c!.rayons.isEmpty ? null : c!.rayons.first;
        secteur = rayon?.secteurs.firstOrNull;
      }
    });
  }

  Future<void> _supprimerSecteur(CatRayon r, CatSecteur s) async {
    if (!await _confirmer(
        'Supprimer le secteur « ${s.nom} » ?', '${s.produits.length} produit(s) seront supprimés du catalogue.', 'Supprimer')) {
      return;
    }
    _modifier(() {
      r.secteurs.remove(s);
      if (secteur == s) secteur = r.secteurs.firstOrNull;
    });
  }

  Map<CatProduit, CatSecteur> get _secteurDe => {for (final (_, s, p) in c!.tousLesProduits) p: s};

  Future<void> _supprimerProduits(Set<CatProduit> ps) async {
    if (ps.isEmpty) return;
    final titre = ps.length == 1 ? 'Supprimer « ${ps.first.nom} » ?' : 'Supprimer ${ps.length} produits ?';
    final mes = ps.where((p) => p.listes > 0).length;
    if (!await _confirmer(titre, mes > 0 ? '$mes figure(nt) dans vos listes.' : 'Ils seront retirés du catalogue.', 'Supprimer')) {
      return;
    }
    final de = _secteurDe;
    _modifier(() {
      for (final p in ps) {
        de[p]?.produits.remove(p);
      }
      choix.removeAll(ps);
    });
  }

  Future<void> _deplacerProduits(Set<CatProduit> ps) async {
    if (ps.isEmpty) return;
    final cible = await _choisirSecteur(ps.length == 1 ? 'Déplacer « ${ps.first.nom} »' : 'Déplacer ${ps.length} produits');
    if (cible == null) return;
    final de = _secteurDe;
    _modifier(() {
      for (final p in ps) {
        de[p]?.produits.remove(p);
        cible.produits.add(p);
      }
      choix.clear();
    });
    _message('Déplacé vers « ${cible.nom} »');
  }

  Future<void> _enregistrer() async {
    try {
      final f = await c!.enregistrer();
      setState(() => modifs = 0);
      _message('Catalogue enregistré ($f). L\'application l\'utilisera pour les nouveaux magasins.');
    } catch (e) {
      _message('Enregistrement impossible : $e');
    }
  }

  Future<void> _exporter() async {
    final lieu = await getSaveLocation(
      suggestedName: 'Catalogue.xlsx',
      acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: ['xlsx'])],
    );
    if (lieu == null) return;
    final chemin = lieu.path.toLowerCase().endsWith('.xlsx') ? lieu.path : '${lieu.path}.xlsx';
    await XFile.fromData(Uint8List.fromList(exporterExcel(c!)), name: 'Catalogue.xlsx').saveTo(chemin);
    _message('Tableau enregistré : $chemin');
  }

  Future<void> _importer() async {
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: ['xlsx'])]);
    if (f == null) return;
    BilanImport? bilan;
    try {
      final octets = await f.readAsBytes();
      _modifier(() => bilan = importerExcel(c!, octets));
    } catch (e) {
      return _message('Lecture du tableau impossible : $e');
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tableau appliqué'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text([
              bilan!.total == 0 ? 'Aucun changement.' : bilan.toString(),
              ...bilan!.remarques.take(30),
              if (bilan!.total > 0) '\nPensez à « Enregistrer » pour garder ces changements.',
            ].join('\n')),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _revenirAuLivre() async {
    if (await _confirmer('Revenir au catalogue livré ?',
        'Toutes vos modifications du catalogue seront remplacées par le catalogue livré avec l\'application '
            '(vous pourrez encore annuler en quittant sans enregistrer).',
        'Revenir')) {
      await _charger(livre: true);
    }
  }

  // ---------------------------------------------------------------- affichage

  @override
  Widget build(BuildContext context) {
    final cat = c;
    if (cat == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final nbP = cat.tousLesProduits.length;
    final nbMes = cat.tousLesProduits.where((x) => x.$3.listes > 0).length;
    return Scaffold(
      body: Column(children: [
        Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Catalogue type', style: Charte.texte(20, gras: true)),
                Text('${cat.rayons.length} rayons · ${cat.rayons.fold<int>(0, (a, r) => a + r.secteurs.length)} secteurs · '
                    '$nbP produits · ★ $nbMes dans vos listes',
                    style: Charte.secondaire, overflow: TextOverflow.ellipsis),
              ]),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: rechercheCtl,
                decoration: InputDecoration(
                  hintText: 'Chercher un produit',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: recherche.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                                rechercheCtl.clear();
                                recherche = '';
                              })),
                ),
                onChanged: (v) => setState(() => recherche = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('★ Mes produits'),
              selected: mesProduits,
              onSelected: (v) => setState(() => mesProduits = v),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Plus',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) => switch (v) {
                'importer' => _importer(),
                'exporter' => _exporter(),
                'annuler' => _charger(),
                'livre' => _revenirAuLivre(),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'exporter', child: Text('Exporter vers Excel…')),
                const PopupMenuItem(value: 'importer', child: Text('Appliquer un tableau Excel…')),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'annuler', enabled: modifs > 0, child: const Text('Annuler les modifications')),
                const PopupMenuItem(value: 'livre', child: Text('Revenir au catalogue livré')),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: modifs > 0 ? _enregistrer : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(modifs > 0 ? 'Enregistrer' : 'Enregistré'),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: recherche.isNotEmpty
              ? _resultats(cat)
              : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 280, child: _colonneRayons(cat)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 320, child: _colonneSecteurs()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _colonneProduits()),
                ]),
        ),
      ]),
    );
  }

  Widget _titreColonne(String titre, {VoidCallback? ajouter, String? aide}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(children: [
          Expanded(child: Text(titre, style: Charte.titreGroupe)),
          if (ajouter != null) TextButton.icon(onPressed: ajouter, icon: const Icon(Icons.add, size: 18), label: Text(aide ?? 'Ajouter')),
        ]),
      );

  Widget _taille(int t, ValueChanged<int> changer) => PopupMenuButton<int>(
        tooltip: 'Taille de magasin',
        initialValue: t,
        onSelected: changer,
        itemBuilder: (_) => [
          for (final e in CatalogueType.tailles.entries)
            PopupMenuItem(value: e.key, child: Text('${_lettre[e.key]} · ${e.value}${e.key < 3 ? ' et plus' : ''}')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(border: Border.all(color: Charte.texteSecondaire), borderRadius: BorderRadius.circular(4)),
          child: Text(_lettre[t]!, style: Charte.texte(12, gras: true, couleur: Charte.texteSecondaire)),
        ),
      );

  Widget _menuLigne(List<(String, VoidCallback)> actions) => PopupMenuButton<int>(
        tooltip: 'Actions',
        icon: const Icon(Icons.more_horiz, size: 20),
        onSelected: (i) => actions[i].$2(),
        itemBuilder: (_) => [for (var i = 0; i < actions.length; i++) PopupMenuItem(value: i, child: Text(actions[i].$1))],
      );

  bool _visible(CatProduit p) => !mesProduits || p.listes > 0;

  Widget _colonneRayons(CatalogueType cat) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _titreColonne('RAYONS', ajouter: _ajouterRayon),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: cat.rayons.length,
            onReorderItem: (a, b) => _modifier(() {
              cat.rayons.insert(b, cat.rayons.removeAt(a));
            }),
            itemBuilder: (_, i) {
              final r = cat.rayons[i];
              final np = r.secteurs.fold<int>(0, (a, s) => a + s.produits.where(_visible).length);
              return ListTile(
                key: ObjectKey(r),
                dense: true,
                selected: r == rayon,
                selectedTileColor: Charte.fondSelection,
                leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, size: 18)),
                title: Row(children: [
                  Pictogramme(cleRayon(r.nom), taille: 28),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.nom, style: Charte.texte(15, gras: r == rayon))),
                ]),
                subtitle: Text('${r.secteurs.length} secteurs · $np produits', style: Charte.secondaire),
                trailing: _menuLigne([('Renommer', () => _renommerRayon(r)), ('Supprimer', () => _supprimerRayon(r))]),
                onTap: () => setState(() {
                  rayon = r;
                  secteur = r.secteurs.firstOrNull;
                  choix.clear();
                }),
              );
            },
          ),
        ),
      ]);

  Widget _colonneSecteurs() {
    final r = rayon;
    if (r == null) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titreColonne('SECTEURS DE « ${r.nom.toUpperCase()} »', ajouter: _ajouterSecteur),
      Expanded(
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: r.secteurs.length,
          onReorderItem: (a, b) => _modifier(() {
            r.secteurs.insert(b, r.secteurs.removeAt(a));
          }),
          itemBuilder: (_, i) {
            final s = r.secteurs[i];
            return ListTile(
              key: ObjectKey(s),
              dense: true,
              selected: s == secteur,
              selectedTileColor: Charte.fondSelection,
              leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, size: 18)),
              title: Row(children: [
                Pictogramme(cleSecteur(r.nom, s.nom), taille: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(s.nom, style: Charte.texte(15, gras: s == secteur))),
              ]),
              subtitle: Text('${s.produits.where(_visible).length} produits', style: Charte.secondaire),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _taille(s.taille, (t) => _modifier(() => s.taille = t)),
                _menuLigne([
                  ('Renommer', () => _renommerSecteur(r, s)),
                  ('Supprimer', () => _supprimerSecteur(r, s)),
                ]),
              ]),
              onTap: () => setState(() {
                secteur = s;
                choix.clear();
              }),
            );
          },
        ),
      ),
    ]);
  }

  Widget _ligneProduit(CatProduit p, {String? chemin, VoidCallback? aller}) => ListTile(
        key: ObjectKey(p),
        dense: true,
        leading: Checkbox(
          value: choix.contains(p),
          onChanged: (v) => setState(() => v == true ? choix.add(p) : choix.remove(p)),
        ),
        title: Row(children: [
          Flexible(child: Text(p.nom, style: Charte.texte(15))),
          if (p.listes > 0) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Présent ${p.listes} fois dans vos listes',
              child: Text('★${p.listes}', style: Charte.texte(12, gras: true, couleur: _orange)),
            ),
          ],
        ]),
        subtitle: chemin != null || p.marques.isNotEmpty
            ? Text([if (chemin != null) chemin, if (p.marques.isNotEmpty) p.marques.join(', ')].join(' · '), style: Charte.secondaire)
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _taille(p.taille, (t) => _modifier(() => p.taille = t)),
          _menuLigne([
            ('Renommer', () => _renommerProduit(p)),
            ('Déplacer vers…', () => _deplacerProduits({p})),
            if (aller != null) ('Voir son secteur', aller),
            ('Supprimer', () => _supprimerProduits({p})),
          ]),
        ]),
        onTap: () => setState(() => choix.contains(p) ? choix.remove(p) : choix.add(p)),
      );

  Widget _barreChoix() => choix.isEmpty
      ? const SizedBox()
      : Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('${choix.length} sélectionné${choix.length > 1 ? 's' : ''}', style: Charte.texte(14, gras: true)),
            const Spacer(),
            TextButton(onPressed: () => setState(choix.clear), child: const Text('Désélectionner')),
            OutlinedButton(onPressed: () => _deplacerProduits({...choix}), child: const Text('Déplacer vers…')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _supprimerProduits({...choix}), child: const Text('Supprimer')),
          ]),
        );

  Widget _colonneProduits() {
    final s = secteur;
    if (s == null) {
      return Center(child: Text('Choisissez ou créez un secteur.', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    }
    final ps = s.produits.where(_visible).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titreColonne('PRODUITS DE « ${s.nom.toUpperCase()} »', ajouter: _ajouterProduits),
      _barreChoix(),
      Expanded(
        child: ps.isEmpty
            ? Center(child: Text(mesProduits ? 'Aucun de vos produits dans ce secteur.' : 'Aucun produit.', style: Charte.secondaire))
            : ListView(children: [for (final p in ps) _ligneProduit(p)]),
      ),
    ]);
  }

  Widget _resultats(CatalogueType cat) {
    final trouves = [
      for (final (r, s, p) in cat.tousLesProduits)
        if (p.nom.toLowerCase().contains(recherche) && _visible(p)) (r, s, p)
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titreColonne('${trouves.length} PRODUIT${trouves.length > 1 ? 'S' : ''} TROUVÉ${trouves.length > 1 ? 'S' : ''}'),
      _barreChoix(),
      Expanded(
        child: ListView(children: [
          for (final (r, s, p) in trouves)
            _ligneProduit(p,
                chemin: '${r.nom} › ${s.nom}',
                aller: () => setState(() {
                      rayon = r;
                      secteur = s;
                      rechercheCtl.clear();
                      recherche = '';
                      choix.clear();
                    })),
        ]),
      ),
    ]);
  }
}
