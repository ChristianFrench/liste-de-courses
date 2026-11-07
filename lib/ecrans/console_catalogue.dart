import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/pictogramme.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../navigation.dart';
import '../theme.dart';
import 'editeur_catalogue.dart';

// Catalogue commun en grand écran, dans la console Windows (07/11/2026, Aristide) : à gauche l'arbre des rayons et
// des secteurs, au centre les produits du secteur choisi en tableau (sélection multiple, glisser-déposer vers un
// secteur de l'arbre, Entrée / F2 / Suppr), ou l'iconographie des rayons et secteurs à compléter avant de généraliser.
// Le téléphone garde son écran ; les gestes passent par l'état de l'éditeur ([EtatEditeurCatalogue]) et son journal.

enum ModeCatalogue { produits, iconographie }

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Rayons et secteurs sans icône (ni choisie, ni livrée, ni approchée).
int sansIcone(Brouillon b) {
  var n = 0;
  for (final r in b.catalogue.rayons) {
    if (etatIconeRayon(r.nom, b.images) == EtatIcone.aucune) n++;
    for (final s in r.secteurs) {
      if (etatIconeSecteur(r.nom, s.nom, b.images) == EtatIcone.aucune) n++;
    }
  }
  return n;
}

/// La bibliothèque entière, avec un champ de recherche ; rend l'image choisie, [imageAutomatique], ou null.
Future<String?> choisirDansBibliotheque(BuildContext context, {required String titre}) {
  var filtre = '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) {
        final f = filtre.trim().toLowerCase();
        final images = [
          for (final c in toutesLesImages)
            if (f.isEmpty || c.replaceAll('-', ' ').contains(f)) c
        ];
        return Dialog(
          child: SizedBox(
            width: 760,
            height: 620,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(titre, style: Charte.texte(18, gras: true)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('bibliotheque-recherche'),
                      autofocus: true,
                      style: Charte.texte(15),
                      decoration: const InputDecoration(labelText: 'Rechercher une image', hintText: 'pomme, chat, outil…'),
                      onChanged: (v) => maj(() => filtre = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Bouton(texte: 'Image automatique', onTap: () => Navigator.of(ctx).pop(imageAutomatique)),
                ]),
                const SizedBox(height: 10),
                Text(_pluriel(images.length, 'image'), style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 96, mainAxisExtent: 92),
                    itemCount: images.length,
                    itemBuilder: (_, i) => Tooltip(
                      message: images[i].split('--').last.replaceAll('-', ' '),
                      child: InkWell(
                        key: ValueKey('biblio-${images[i]}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(images[i]),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(children: [
                            Pictogramme(images[i], taille: 52),
                            const SizedBox(height: 2),
                            Text(images[i].split('--').last.replaceAll('-', ' '),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(11, couleur: Charte.texteSecondaire)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(alignment: Alignment.centerRight, child: _Bouton(texte: 'Fermer', onTap: () => Navigator.of(ctx).pop())),
              ]),
            ),
          ),
        );
      },
    ),
  );
}

class CatalogueLarge extends StatefulWidget {
  const CatalogueLarge({super.key, required this.editeur, required this.mode});
  final EtatEditeurCatalogue editeur;
  final ModeCatalogue mode;

  @override
  State<CatalogueLarge> createState() => _CatalogueLargeState();
}

class _CatalogueLargeState extends State<CatalogueLarge> {
  String recherche = '';
  CatSecteur? secteur;
  final selection = <CatProduit>{};
  final ouverts = <CatRayon>{};
  final _focus = FocusNode(debugLabel: 'produits');
  bool toutesLesIcones = false;
  CatSecteur? _survole;

  EtatEditeurCatalogue get e => widget.editeur;
  Brouillon get b => e.b!;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _modifie() {
    e.modifie();
    setState(() {});
  }

  (CatRayon, CatSecteur)? _ou(CatProduit p) {
    for (final r in b.catalogue.rayons) {
      for (final s in r.secteurs) {
        if (s.produits.any((x) => identical(x, p))) return (r, s);
      }
    }
    return null;
  }

  CatRayon? _rayonDe(CatSecteur s) {
    for (final r in b.catalogue.rayons) {
      if (r.secteurs.any((x) => identical(x, s))) return r;
    }
    return null;
  }

  String get _filtre => recherche.trim().toLowerCase();

  // ---------------------------------------------------------------- gestes

  Future<void> _choisirImage(String cle, String nom) async {
    final c = await choisirDansBibliotheque(context, titre: 'Icône de $nom');
    if (c == null || !mounted) return;
    b.choisirImage(cle, c == imageAutomatique ? null : c);
    _modifie();
  }

  void _fixer(String cle, String picto) {
    b.choisirImage(cle, picto);
    _modifie();
  }

  Future<void> _nouveauProduit() async {
    final s = secteur;
    if (s == null) return;
    final nom = await demanderTexte(context, titre: 'Nouveau produit · ${s.nom}', valider: 'Ajouter');
    if (nom == null || nom.trim().isEmpty || !mounted) return;
    if (!b.ajouterProduit(s, nom)) {
      Nav.message(context, '« ${nom.trim()} » est déjà dans ce secteur');
      return;
    }
    _modifie();
  }

  Future<void> _renommer() async {
    if (selection.length != 1) return;
    final p = selection.single;
    final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
    if (nom == null || !mounted) return;
    b.renommerProduit(p, nom);
    _modifie();
  }

  Future<void> _retirer() async {
    if (selection.isEmpty) return;
    if (selection.length > 1) {
      final ok = await confirmer(
        context,
        titre: 'Retirer ${_pluriel(selection.length, 'produit')} ?',
        icone: Icons.delete_outline,
        contenu: Text('Les foyers ne retirent que ce qu\'ils n\'utilisent pas.', style: Charte.texte(16)),
        plein: 'Annuler',
        contour: 'Retirer',
      );
      if (ok != true || !mounted) return;
    }
    for (final p in [...selection]) {
      final o = _ou(p);
      if (o != null) b.retirerProduit(o.$2, p);
    }
    selection.clear();
    _modifie();
  }

  /// Déplace les produits dans [vers] ; rend le nombre déplacé.
  int _deplacer(Iterable<CatProduit> produits, CatSecteur vers) {
    var n = 0;
    for (final p in [...produits]) {
      final o = _ou(p);
      if (o != null && b.deplacerProduit(o.$2, p, vers)) n++;
    }
    selection.clear();
    if (n > 0) _modifie();
    final r = _rayonDe(vers);
    if (mounted) {
      Nav.message(context, n == 0 ? 'Rien à déplacer (déjà dans ${vers.nom})' : '${_pluriel(n, 'produit')} déplacé${n > 1 ? 's' : ''} vers ${r?.nom ?? ''} › ${vers.nom}');
    }
    return n;
  }

  Future<void> _deplacerVers() async {
    if (selection.isEmpty) return;
    final choix = <CatSecteur, String>{
      for (final r in b.catalogue.rayons)
        for (final s in r.secteurs) s: '${r.nom} › ${s.nom}',
    };
    final vers = await choisirDansListe<CatSecteur>(context, titre: 'Déplacer ${_pluriel(selection.length, 'produit')} vers', choix: choix);
    if (vers == null || !mounted) return;
    _deplacer(selection, vers);
  }

  // ---------------------------------------------------------------- arbre

  Widget _arbre() {
    final f = _filtre;
    bool produitTrouve(CatSecteur s) => f.length >= 2 && s.produits.any((p) => p.nom.toLowerCase().contains(f));
    final lignes = <Widget>[];
    for (final r in b.catalogue.rayons) {
      final secteurs = [
        for (final s in r.secteurs)
          if (f.isEmpty || r.nom.toLowerCase().contains(f) || s.nom.toLowerCase().contains(f) || produitTrouve(s)) s
      ];
      if (f.isNotEmpty && secteurs.isEmpty && !r.nom.toLowerCase().contains(f)) continue;
      final ouvert = f.isNotEmpty || ouverts.contains(r);
      lignes.add(_ligneRayon(r, ouvert));
      if (ouvert) {
        for (final s in secteurs) {
          lignes.add(_ligneSecteur(r, s));
        }
      }
    }
    final toutOuvert = ouverts.length == b.catalogue.rayons.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: TextField(
          key: const ValueKey('console-recherche'),
          style: Charte.texte(15),
          decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Un rayon, un secteur, un produit'),
          onChanged: (v) => setState(() => recherche = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        child: Row(children: [
          TextButton.icon(
            key: const ValueKey('console-nouveau-rayon'),
            onPressed: e.nouveauRayon,
            icon: Icone(Icons.add, size: 20, color: Charte.cadre),
            label: Text('Nouveau rayon', style: Charte.texte(14, couleur: Charte.cadre)),
          ),
          const Spacer(),
          Tooltip(
            message: toutOuvert ? 'Tout replier' : 'Tout déplier',
            child: IconButton(
              key: const ValueKey('console-tout'),
              onPressed: () => setState(() => toutOuvert ? ouverts.clear() : ouverts.addAll(b.catalogue.rayons)),
              icon: Icone(toutOuvert ? Icons.unfold_less : Icons.unfold_more, size: 24, color: Charte.cadre),
            ),
          ),
        ]),
      ),
      Container(height: 1, color: Charte.separateurZone),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 16), children: lignes)),
    ]);
  }

  Widget _crayon(String cle, String nom, VoidCallback onTap) => Tooltip(
        message: 'Modifier $nom',
        child: InkResponse(
          key: ValueKey('crayon-$cle'),
          onTap: onTap,
          radius: 18,
          child: Padding(padding: const EdgeInsets.all(5), child: Icone(Icons.edit_outlined, size: 20, color: Charte.encreNiveau)),
        ),
      );

  Widget _icone(String? picto, double taille, VoidCallback onTap, String nom) => Tooltip(
        message: 'Icône de $nom',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: taille + 4,
            height: taille + 4,
            child: Center(
              child: picto != null
                  ? Pictogramme(picto, taille: taille)
                  : Icone(Icons.add_photo_alternate_outlined, size: taille * 0.7, color: Charte.texteSecondaire),
            ),
          ),
        ),
      );

  Widget _ligneRayon(CatRayon r, bool ouvert) => Material(
        color: Charte.niveau(2),
        child: InkWell(
          key: ValueKey('console-rayon-${r.nom}'),
          onTap: () => setState(() => ouverts.contains(r) ? ouverts.remove(r) : ouverts.add(r)),
          child: Container(
            height: 42,
            padding: const EdgeInsets.only(left: 6, right: 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.blanc))),
            child: Row(children: [
              Icone(ouvert ? Icons.expand_more : Icons.chevron_right, size: 22, color: Charte.encreNiveau),
              _icone(b.images[cleChoixRayon(r.nom)] ?? cleRayon(r.nom), 30, () => _choisirImage(cleChoixRayon(r.nom), r.nom), r.nom),
              const SizedBox(width: 6),
              Expanded(
                child: Text(r.nom.toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14.5, gras: true, couleur: Charte.encreNiveau)),
              ),
              Text('${r.secteurs.length}', style: Charte.texte(13, couleur: Charte.encreNiveau)),
              _crayon('r-${r.nom}', r.nom, () => menuActions(context, titre: 'Rayon ${r.nom}', actions: e.actionsRayon(context, r))),
            ]),
          ),
        ),
      );

  Widget _ligneSecteur(CatRayon r, CatSecteur s) {
    final choisi = identical(secteur, s);
    return DragTarget<List<CatProduit>>(
      onWillAcceptWithDetails: (d) {
        final ok = d.data.any((p) => !s.produits.contains(p));
        if (ok) setState(() => _survole = s);
        return ok;
      },
      onLeave: (_) => setState(() => _survole = null),
      onAcceptWithDetails: (d) {
        setState(() => _survole = null);
        _deplacer(d.data, s);
      },
      builder: (context, _, __) => Material(
        color: identical(_survole, s) ? Charte.accent : (choisi ? Charte.fondSelection : Charte.niveau(3)),
        child: InkWell(
          key: ValueKey('console-secteur-${r.nom}/${s.nom}'),
          onTap: () => setState(() {
            secteur = s;
            selection.clear();
            _focus.requestFocus();
          }),
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 30, right: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Charte.blanc),
                left: BorderSide(color: choisi ? Charte.cadre : Colors.transparent, width: 4),
              ),
            ),
            child: Row(children: [
              _icone(b.images[cleChoixSecteur(r.nom, s.nom)] ?? cleSecteur(r.nom, s.nom), 26,
                  () => _choisirImage(cleChoixSecteur(r.nom, s.nom), s.nom), s.nom),
              const SizedBox(width: 6),
              Expanded(child: Text(s.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14.5, gras: choisi))),
              Text('${s.produits.length}', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
              _crayon('s-${r.nom}/${s.nom}', s.nom, () async {
                await menuActions(context, titre: 'Secteur ${s.nom}', actions: actionsSecteurEditeur(context, b, r, s, _modifie, quitter: () {
                  if (identical(secteur, s)) setState(() => secteur = null);
                }));
              }),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- produits

  Set<String> _publies() {
    final j = e.publie;
    if (j == null) return const {};
    return {
      for (final r in (j['rayons'] as List? ?? const []).cast<Map>())
        for (final s in (r['secteurs'] as List? ?? const []).cast<Map>())
          for (final p in (s['produits'] as List? ?? const []).cast<Map>()) '${s['nom']}/${p['nom']}'.toLowerCase()
    };
  }

  Widget _produits() {
    final f = _filtre;
    final global = f.length >= 2;
    final s = secteur;
    final List<(CatRayon, CatSecteur, CatProduit)> lignes = global
        ? [
            for (final r in b.catalogue.rayons)
              for (final x in r.secteurs)
                for (final p in x.produits)
                  if (p.nom.toLowerCase().contains(f)) (r, x, p)
          ]
        : s == null
            ? []
            : [for (final p in s.produits) (_rayonDe(s)!, s, p)];
    lignes.sort((a, c) => a.$3.nom.toLowerCase().compareTo(c.$3.nom.toLowerCase()));
    final publies = _publies();
    final titre = global ? 'Recherche « ${recherche.trim()} »' : s == null ? 'Choisissez un secteur à gauche' : '${_rayonDe(s)?.nom ?? ''} › ${s.nom}';
    final tous = lignes.isNotEmpty && lignes.every((l) => selection.contains(l.$3));

    Widget cellule(String t, {int flex = 1, bool gras = false, Color? couleur}) => Expanded(
          flex: flex,
          child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14.5, gras: gras, couleur: couleur ?? Charte.encre)),
        );

    Widget ligne((CatRayon, CatSecteur, CatProduit) l) {
      final (r, x, p) = l;
      final choisi = selection.contains(p);
      final nouveau = e.publie != null && !publies.contains('${x.nom}/${p.nom}'.toLowerCase());
      final rangee = Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: choisi ? Charte.fondSelection : Charte.blanc,
          border: Border(bottom: BorderSide(color: Charte.separateurLigne)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: choisi,
              onChanged: (v) => setState(() => v == true ? selection.add(p) : selection.remove(p)),
            ),
          ),
          cellule(p.nom, flex: 3, gras: choisi),
          if (global) cellule('${r.nom} › ${x.nom}', flex: 4, couleur: Charte.texteSecondaire),
          cellule(p.formats.join(', '), flex: 3, couleur: Charte.texteSecondaire),
          cellule(p.marques.take(4).join(', '), flex: 3, couleur: Charte.texteSecondaire),
          SizedBox(width: 70, child: Text(nouveau ? 'nouveau' : '', style: Charte.texte(12.5, gras: true, couleur: Charte.cadre))),
        ]),
      );
      final donnees = choisi ? selection.toList() : [p];
      return Draggable<List<CatProduit>>(
        key: ValueKey('console-produit-${x.nom}/${p.nom}'),
        data: donnees,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Charte.cadre,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(donnees.length == 1 ? donnees.single.nom : _pluriel(donnees.length, 'produit'),
                style: Charte.texte(14, gras: true, couleur: Charte.blanc)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: rangee),
        child: GestureDetector(
          onTap: () => setState(() {
            final ctrl = HardwareKeyboard.instance.isControlPressed;
            if (!ctrl) selection.clear();
            choisi && ctrl ? selection.remove(p) : selection.add(p);
            _focus.requestFocus();
          }),
          onDoubleTap: () {
            setState(() => selection
              ..clear()
              ..add(p));
            _renommer();
          },
          child: rangee,
        ),
      );
    }

    final n = selection.length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _nouveauProduit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _nouveauProduit,
        const SingleActivator(LogicalKeyboardKey.f2): _renommer,
        const SingleActivator(LogicalKeyboardKey.delete): _retirer,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(children: [
              if (!global && s != null) ...[
                Pictogramme(b.images[cleChoixSecteur(_rayonDe(s)?.nom ?? '', s.nom)] ?? cleSecteur(_rayonDe(s)?.nom ?? '', s.nom), taille: 36),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(titre, style: Charte.texte(19, gras: true, couleur: Charte.encreNiveau))),
              Text(_pluriel(lignes.length, 'produit'), style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _Bouton(
                key: const ValueKey('console-nouveau-produit'),
                texte: 'Nouveau produit (Entrée)',
                icone: Icons.add,
                onTap: s == null || global ? null : _nouveauProduit,
              ),
              _Bouton(
                texte: 'Depuis un texte',
                icone: Icons.notes,
                onTap: () async {
                  final r = s == null ? null : _rayonDe(s);
                  if (await ajouterDepuisTexte(context, b, rayon: global ? null : r, secteur: global ? null : s)) _modifie();
                },
              ),
              _Bouton(key: const ValueKey('console-renommer'), texte: 'Renommer (F2)', icone: Icons.edit_outlined, onTap: n == 1 ? _renommer : null),
              _Bouton(
                key: const ValueKey('console-deplacer'),
                texte: n > 0 ? 'Déplacer ($n)' : 'Déplacer',
                icone: Icons.drive_file_move_outline,
                onTap: n > 0 ? _deplacerVers : null,
              ),
              _Bouton(
                key: const ValueKey('console-retirer'),
                texte: n > 0 ? 'Retirer ($n) (Suppr)' : 'Retirer (Suppr)',
                icone: Icons.delete_outline,
                onTap: n > 0 ? _retirer : null,
              ),
            ]),
          ),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Charte.niveau(2),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Checkbox(
                  key: const ValueKey('console-tout-cocher'),
                  value: tous,
                  onChanged: lignes.isEmpty
                      ? null
                      : (v) => setState(() => v == true ? selection.addAll([for (final l in lignes) l.$3]) : selection.clear()),
                ),
              ),
              cellule('Produit', flex: 3, gras: true),
              if (global) cellule('Rayon › secteur', flex: 4, gras: true),
              cellule('Mesure et packaging', flex: 3, gras: true),
              cellule('Marques', flex: 3, gras: true),
              const SizedBox(width: 70),
            ]),
          ),
          Expanded(
            child: lignes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      global ? 'Aucun produit ne correspond.' : s == null ? '' : 'Aucun produit dans ce secteur.',
                      style: Charte.texte(15, couleur: Charte.texteSecondaire),
                    ),
                  )
                : ListView.builder(itemCount: lignes.length, itemBuilder: (_, i) => ligne(lignes[i])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Text(
              'Clic : choisir · Ctrl+clic : ajouter à la sélection · Double-clic : renommer · '
              'Glisser un produit (ou la sélection) sur un secteur à gauche pour l\'y déplacer.',
              style: Charte.texte(12.5, couleur: Charte.texteSecondaire),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- iconographie

  Widget _iconographie() {
    final lignes = <(String cle, String nom, String? rayon, EtatIcone etat, String? actuelle, List<String> produits)>[];
    for (final r in b.catalogue.rayons) {
      lignes.add((
        cleChoixRayon(r.nom),
        r.nom,
        null,
        etatIconeRayon(r.nom, b.images),
        b.images[cleChoixRayon(r.nom)] ?? cleRayon(r.nom),
        [for (final s in r.secteurs) s.nom],
      ));
      for (final s in r.secteurs) {
        lignes.add((
          cleChoixSecteur(r.nom, s.nom),
          s.nom,
          r.nom,
          etatIconeSecteur(r.nom, s.nom, b.images),
          b.images[cleChoixSecteur(r.nom, s.nom)] ?? cleSecteur(r.nom, s.nom),
          [for (final p in s.produits) p.nom],
        ));
      }
    }
    bool aCompleter(EtatIcone x) => x == EtatIcone.aucune || x == EtatIcone.approchee;
    final nAucune = lignes.where((l) => l.$4 == EtatIcone.aucune).length;
    final nApprochee = lignes.where((l) => l.$4 == EtatIcone.approchee).length;
    final vues = [for (final l in lignes) if (toutesLesIcones || aCompleter(l.$4)) l];
    const libelles = {
      EtatIcone.choisie: 'choisie',
      EtatIcone.exacte: 'livrée',
      EtatIcone.approchee: 'approchée',
      EtatIcone.aucune: 'aucune',
    };

    Widget ligne((String, String, String?, EtatIcone, String?, List<String>) l) {
      final (cle, nom, rayon, etat, actuelle, produits) = l;
      final propositions = [for (final c in propositionsIcone(nom, produits)) if (c != actuelle) c].take(5).toList();
      return Container(
        key: ValueKey('icono-$cle'),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: rayon == null ? Charte.niveau(3) : Charte.blanc,
          border: Border(bottom: BorderSide(color: Charte.separateurLigne)),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: actuelle != null
                  ? Pictogramme(actuelle, taille: 46)
                  : Icone(Icons.hide_image_outlined, size: 30, color: Charte.texteSecondaire),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(rayon == null ? nom.toUpperCase() : nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(15, gras: true)),
              Text('${rayon == null ? 'Rayon' : 'Secteur de $rayon'} · ${libelles[etat]}',
                  style: Charte.texte(12.5, gras: etat == EtatIcone.aucune, couleur: etat == EtatIcone.aucune ? Charte.rouge : Charte.texteSecondaire)),
            ]),
          ),
          Expanded(
            child: Row(children: [
              for (final c in propositions)
                Tooltip(
                  message: c.split('--').last.replaceAll('-', ' '),
                  child: InkWell(
                    key: ValueKey('proposition-$cle-$c'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _fixer(cle, c),
                    child: Padding(padding: const EdgeInsets.all(3), child: Pictogramme(c, taille: 38)),
                  ),
                ),
              if (propositions.isEmpty)
                Text('Aucune proposition', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ]),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Bibliothèque',
            child: IconButton(
              key: ValueKey('bibliotheque-$cle'),
              onPressed: () => _choisirImage(cle, nom),
              icon: Icone(Icons.photo_library_outlined, size: 26, color: Charte.cadre),
            ),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Text('Iconographie des rayons et secteurs', style: Charte.texte(19, gras: true, couleur: Charte.encreNiveau)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Text(
          '$nAucune sans icône, $nApprochee à icône approchée (prise par ressemblance). Cliquez une proposition pour la '
          'fixer, ou ouvrez la bibliothèque. Chaque choix est une modification à valider, puis à généraliser.',
          style: Charte.texte(14, couleur: Charte.texteSecondaire),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(
            key: const ValueKey('icono-a-completer'),
            label: Text('À compléter (${nAucune + nApprochee})'),
            selected: !toutesLesIcones,
            onSelected: (_) => setState(() => toutesLesIcones = false),
          ),
          ChoiceChip(
            key: const ValueKey('icono-tout'),
            label: Text('Tous (${lignes.length})'),
            selected: toutesLesIcones,
            onSelected: (_) => setState(() => toutesLesIcones = true),
          ),
        ]),
      ),
      Container(height: 1, color: Charte.separateurZone),
      Expanded(
        child: vues.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Tous les rayons et secteurs ont leur icône.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              )
            : ListView.builder(itemCount: vues.length, itemBuilder: (_, i) => ligne(vues[i])),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (e.b == null) return const Center(child: CircularProgressIndicator());
    if (secteur != null && _rayonDe(secteur!) == null) secteur = null;
    return Material(
      color: Charte.fond,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 300, child: _arbre()),
        VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
        Expanded(child: widget.mode == ModeCatalogue.produits ? _produits() : _iconographie()),
      ]),
    );
  }
}

/// [Bouton] à la largeur de son libellé (dans une rangée ou un Wrap, où la largeur n'est pas bornée).
class _Bouton extends StatelessWidget {
  const _Bouton({super.key, required this.texte, required this.onTap, this.icone});
  final String texte;
  final VoidCallback? onTap;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(child: Bouton(texte: texte, icone: icone, onTap: onTap, taille: 15));
}
