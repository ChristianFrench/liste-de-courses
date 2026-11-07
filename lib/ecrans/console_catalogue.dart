import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/pictogramme.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../donnees/journal_catalogue.dart';
import '../navigation.dart';
import '../theme.dart';
import 'console_images.dart';
import 'editeur_catalogue.dart';

// Catalogue commun en grand écran, dans la console Windows (07/11/2026, Aristide, 2e version) :
// - en haut, un titre commun : le catalogue, ses chiffres, ce qui est en cours, le bouton Généraliser et le menu ☰
//   des actions qui ne modifient pas le catalogue (historique, iconographie, valider, clé de signature…) ;
// - dessous, un seul cadre sur toute la largeur : rayons, secteurs et produits ; clic droit = actions de l'élément,
//   double-clic ou F2 = renommer sur place, tout changement d'emplacement se fait à la souris (glisser-déposer).
// Le téléphone garde son écran ; les gestes passent par l'état de l'éditeur ([EtatEditeurCatalogue]) et son journal.

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
Future<String?> choisirDansBibliotheque(BuildContext context, {required String titre, Future<String?> Function()? ajouter}) {
  var filtre = '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) {
        final f = filtre.trim().toLowerCase();
        final images = [
          for (final c in toutesLesImages)
            if (f.isEmpty || c.replaceAll('-', ' ').contains(f) || nomImage(c).toLowerCase().contains(f)) c
        ];
        return Dialog(
          backgroundColor: Charte.blanc,
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
                  if (ajouter != null) ...[
                    const SizedBox(width: 8),
                    _Bouton(
                      key: const ValueKey('bibliotheque-ajouter'),
                      texte: 'Ajouter une image…',
                      icone: Icons.add_photo_alternate_outlined,
                      onTap: () async {
                        final c = await ajouter();
                        if (c != null && ctx.mounted) Navigator.of(ctx).pop(c);
                      },
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                Text(_pluriel(images.length, 'image'), style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 96, mainAxisExtent: 92),
                    itemCount: images.length,
                    itemBuilder: (_, i) => Tooltip(
                      message: '${nomImage(images[i])} · ${origineImage(images[i])}',
                      child: InkWell(
                        key: ValueKey('biblio-${images[i]}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(images[i]),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(children: [
                            Pictogramme(images[i], taille: 52),
                            const SizedBox(height: 2),
                            Text(nomImage(images[i]),
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

/// Ce que l'on fait glisser : un rayon, un secteur (avec son rayon) ou des produits.
class _Glisse {
  _Glisse.rayon(this.rayon)
      : secteur = null,
        produits = const [];
  _Glisse.secteur(this.rayon, this.secteur) : produits = const [];
  _Glisse.produits(this.produits)
      : rayon = null,
        secteur = null;
  final CatRayon? rayon;
  final CatSecteur? secteur;
  final List<CatProduit> produits;
  bool get estRayon => secteur == null && produits.isEmpty;
  bool get estSecteur => secteur != null;
  bool get estProduits => produits.isNotEmpty;
  String get libelle => estProduits
      ? (produits.length == 1 ? produits.single.nom : _pluriel(produits.length, 'produit'))
      : estSecteur
          ? secteur!.nom
          : rayon!.nom;
}

/// Une ligne du cadre : un rayon, un secteur ou un produit.
class _Ligne {
  _Ligne(this.r, [this.s, this.p]);
  final CatRayon r;
  final CatSecteur? s;
  final CatProduit? p;
  Object get objet => p ?? s ?? r;
}

class CatalogueLarge extends StatefulWidget {
  const CatalogueLarge({super.key, required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<CatalogueLarge> createState() => _CatalogueLargeState();
}

class _CatalogueLargeState extends State<CatalogueLarge> {
  String recherche = '';
  final rayonsOuverts = <CatRayon>{};
  final secteursOuverts = <CatSecteur>{};

  /// Rayon ou secteur choisi (clic) ; produits choisis (clic, Ctrl+clic).
  Object? choisi;
  final produitsChoisis = <CatProduit>{};

  /// Élément renommé sur place, et son champ.
  Object? _edite;
  final _champ = TextEditingController();
  final _focus = FocusNode(debugLabel: 'catalogue');
  Object? _survole;

  EtatEditeurCatalogue get e => widget.editeur;
  Brouillon get b => e.b!;

  @override
  void initState() {
    super.initState();
    e.ouvrirIconographie = () => montrerIconographie(context, e);
  }

  @override
  void dispose() {
    _arreterDefilement();
    _defilement.dispose();
    _champ.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- défilement pendant un glisser-déposer
  // 07/11/2026 (Aristide) : en approchant le haut ou le bas du cadre, la liste défile, plus vite près du bord.

  final _defilement = ScrollController();
  final _cleCadre = GlobalKey();
  Timer? _minuterie;
  double _vitesse = 0;

  void _suivreGlisse(Offset global) {
    final boite = _cleCadre.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null || !boite.hasSize) return;
    final y = boite.globalToLocal(global).dy;
    const zone = 60.0, max = 22.0;
    final h = boite.size.height;
    _vitesse = y < zone
        ? -max * ((zone - y.clamp(-zone, zone)) / zone).clamp(0.15, 1.0)
        : y > h - zone
            ? max * ((y.clamp(h - zone, h + zone) - (h - zone)) / zone).clamp(0.15, 1.0)
            : 0;
    if (_vitesse == 0) {
      _arreterDefilement();
    } else {
      _minuterie ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!_defilement.hasClients || _vitesse == 0) return;
        final p = _defilement.position;
        final cible = (p.pixels + _vitesse).clamp(p.minScrollExtent, p.maxScrollExtent);
        if (cible != p.pixels) _defilement.jumpTo(cible);
      });
    }
  }

  void _arreterDefilement() {
    _minuterie?.cancel();
    _minuterie = null;
    _vitesse = 0;
  }

  void _modifie() {
    e.modifie();
    if (mounted) setState(() {});
  }

  void _message(String t) {
    if (mounted) Nav.message(context, t);
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

  // ---------------------------------------------------------------- gestes

  Future<void> _choisirImage(String cle, String nom) async {
    final c = await choisirDansBibliotheque(context, titre: 'Icône de $nom', ajouter: () => ajouterImageBibliotheque(context, e));
    if (c == null || !mounted) return;
    b.choisirImage(cle, c == imageAutomatique ? null : c);
    _modifie();
  }

  Future<void> _nouveauSecteur(CatRayon r) async {
    final nom = await demanderTexte(context, titre: 'Nouveau secteur · ${r.nom}', valider: 'Ajouter');
    if (nom == null || nom.trim().isEmpty || !mounted) return;
    final s = b.ajouterSecteur(r, nom);
    rayonsOuverts.add(r);
    choisi = s;
    _modifie();
  }

  Future<void> _nouveauProduit(CatSecteur s) async {
    final nom = await demanderTexte(context, titre: 'Nouveau produit · ${s.nom}', valider: 'Ajouter');
    if (nom == null || nom.trim().isEmpty || !mounted) return;
    if (!b.ajouterProduit(s, nom)) {
      _message('« ${nom.trim()} » est déjà dans ce secteur');
      return;
    }
    secteursOuverts.add(s);
    _modifie();
  }

  void _commencerRenommage(Object o) {
    _champ.text = switch (o) { CatRayon r => r.nom, CatSecteur s => s.nom, CatProduit p => p.nom, _ => '' };
    _champ.selection = TextSelection(baseOffset: 0, extentOffset: _champ.text.length);
    setState(() => _edite = o);
  }

  void _finirRenommage({bool garder = true}) {
    final o = _edite;
    if (o == null) return;
    final nom = _champ.text.trim();
    setState(() => _edite = null);
    if (!garder || nom.isEmpty) return;
    switch (o) {
      case CatRayon r when nom != r.nom:
        if (b.rayon(nom) != null) return _message('Le rayon « $nom » existe déjà');
        b.renommerRayon(r, nom);
      case CatSecteur s when nom != s.nom:
        final r = _rayonDe(s);
        if (r == null) return;
        if (b.secteur(r, nom) != null) return _message('Le secteur « $nom » existe déjà dans ${r.nom}');
        b.renommerSecteur(r, s, nom);
      case CatProduit p when nom != p.nom:
        final o = _ou(p);
        if (o != null && b.produitDans(o.$2, nom) != null) return _message('« $nom » est déjà dans ${o.$2.nom}');
        b.renommerProduit(p, nom);
      default:
        return;
    }
    _modifie();
    _focus.requestFocus();
  }

  Future<void> _supprimer(Object o) async {
    switch (o) {
      case CatRayon r:
        final n = r.secteurs.fold(0, (n, s) => n + s.produits.length);
        if (!await _confirmer('Supprimer le rayon ${r.nom} ?', 'Avec ${_pluriel(r.secteurs.length, 'secteur')} et ${_pluriel(n, 'produit')}.')) {
          return;
        }
        b.retirerRayon(r);
      case CatSecteur s:
        final r = _rayonDe(s);
        if (r == null || !await _confirmer('Supprimer le secteur ${s.nom} ?', 'Avec ${_pluriel(s.produits.length, 'produit')}.')) return;
        b.retirerSecteur(r, s);
      case CatProduit _:
        final l = produitsChoisis.isNotEmpty ? [...produitsChoisis] : [o];
        if (l.length > 1 && !await _confirmer('Retirer ${_pluriel(l.length, 'produit')} ?', '')) return;
        for (final p in l) {
          final x = _ou(p);
          if (x != null) b.retirerProduit(x.$2, p);
        }
        produitsChoisis.clear();
    }
    choisi = null;
    _modifie();
  }

  Future<bool> _confirmer(String titre, String detail) async {
    final ok = await confirmer(
      context,
      titre: titre,
      icone: Icons.delete_outline,
      contenu: Text('$detail Les foyers ne retirent que ce qu\'ils n\'utilisent pas.'.trim(), style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Supprimer',
    );
    return ok == true && mounted;
  }

  /// Dépose [g] sur la ligne [cible] ; rend vrai si quelque chose a changé.
  void _deposer(_Glisse g, _Ligne cible) {
    var fait = '';
    if (g.estProduits) {
      final vers = cible.s;
      if (vers == null) return;
      var n = 0;
      for (final p in g.produits) {
        final o = _ou(p);
        if (o != null && b.deplacerProduit(o.$2, p, vers)) n++;
      }
      produitsChoisis.clear();
      if (n == 0) return _message('Déjà dans ${vers.nom}');
      secteursOuverts.add(vers);
      fait = '${_pluriel(n, 'produit')} déplacé${n > 1 ? 's' : ''} vers ${cible.r.nom} › ${vers.nom}';
    } else if (g.estSecteur) {
      final s = g.secteur!, de = _rayonDe(s);
      if (de == null || identical(cible.s, s)) return;
      final vers = cible.r;
      if (!identical(de, vers)) {
        b.deplacerSecteur(de, s, vers);
        fait = '${s.nom} déplacé dans ${vers.nom}';
      }
      // Déposé sur un secteur : il se place avant lui.
      final avant = cible.s;
      if (avant != null && cible.p == null) {
        final noms = [for (final x in vers.secteurs) if (!identical(x, s)) x.nom];
        noms.insert(noms.indexOf(avant.nom), s.nom);
        b.ordonnerSecteurs(vers, noms);
        if (fait.isEmpty) fait = '${s.nom} placé avant ${avant.nom}';
      }
      rayonsOuverts.add(vers);
      if (fait.isEmpty) return;
    } else if (g.estRayon) {
      final r = g.rayon!;
      if (identical(r, cible.r) || cible.s != null) return;
      final noms = [for (final x in b.catalogue.rayons) if (!identical(x, r)) x.nom];
      noms.insert(noms.indexOf(cible.r.nom), r.nom);
      b.ordonnerRayons(noms);
      fait = '${r.nom} placé avant ${cible.r.nom}';
    }
    _modifie();
    _message(fait);
  }

  bool _accepte(_Glisse g, _Ligne cible) {
    if (g.estProduits) return cible.s != null && g.produits.any((p) => !cible.s!.produits.contains(p));
    if (g.estSecteur) return cible.p == null && !identical(cible.s, g.secteur);
    return cible.s == null && !identical(cible.r, g.rayon);
  }

  // ---------------------------------------------------------------- menus

  /// Un menu est ouvert : le clic droit sur une ligne arrive aussi au cadre, qui ne doit pas ouvrir le sien.
  bool _menuOuvert = false;

  Future<void> _menu(Offset ou, _Ligne? l) async {
    if (_menuOuvert) return;
    _menuOuvert = true;
    try {
      await _menuDe(ou, l);
    } finally {
      _menuOuvert = false;
    }
  }

  Future<void> _menuDe(Offset ou, _Ligne? l) async {
    final o = l?.objet;
    if (o is CatProduit && !produitsChoisis.contains(o)) {
      produitsChoisis
        ..clear()
        ..add(o);
    }
    if (o != null && o is! CatProduit) {
      produitsChoisis.clear();
      choisi = o;
    }
    setState(() {});
    PopupMenuItem<String> item(String v, IconData i, String t, {bool actif = true}) => PopupMenuItem(
          value: v,
          enabled: actif,
          height: 40,
          child: Row(children: [Icone(i, size: 20, color: Charte.cadre), const SizedBox(width: 10), Text(t, style: Charte.texte(15))]),
        );
    final n = produitsChoisis.length;
    final List<PopupMenuEntry<String>> items = switch (o) {
      CatRayon r => [
          item('secteur', Icons.add, 'Nouveau secteur…'),
          item('texte', Icons.notes, 'Ajouter depuis un texte…'),
          item('renommer', Icons.edit_outlined, 'Renommer (F2)'),
          item('icone', Icons.image_outlined, 'Changer l\'icône…'),
          if (r.secteurs.length > 1) item('ordre', Icons.drag_handle, 'Ordre des secteurs…'),
          if (b.catalogue.rayons.length > 1) item('enSecteur', Icons.low_priority, 'Transformer en secteur d\'un autre rayon…'),
          const PopupMenuDivider(),
          item('supprimer', Icons.delete_outline, 'Supprimer le rayon (Suppr)'),
        ],
      CatSecteur _ => [
          item('produit', Icons.add, 'Nouveau produit… (Entrée)'),
          item('texte', Icons.notes, 'Ajouter depuis un texte…'),
          item('renommer', Icons.edit_outlined, 'Renommer (F2)'),
          item('icone', Icons.image_outlined, 'Changer l\'icône…'),
          item('enRayon', Icons.vertical_align_top, 'Transformer en rayon'),
          const PopupMenuDivider(),
          item('supprimer', Icons.delete_outline, 'Supprimer le secteur (Suppr)'),
        ],
      CatProduit _ => [
          item('renommer', Icons.edit_outlined, 'Renommer (F2)', actif: n == 1),
          const PopupMenuDivider(),
          item('supprimer', Icons.delete_outline, n > 1 ? 'Retirer $n produits (Suppr)' : 'Retirer le produit (Suppr)'),
        ],
      _ => [
          item('rayon', Icons.add, 'Nouveau rayon…'),
          item('texte', Icons.notes, 'Ajouter depuis un texte…'),
        ],
    };
    final v = await showMenu<String>(context: context, position: RelativeRect.fromLTRB(ou.dx, ou.dy, ou.dx, ou.dy), items: items);
    if (v == null || !mounted) return;
    switch ((v, o)) {
      case ('secteur', CatRayon r):
        await _nouveauSecteur(r);
      case ('produit', CatSecteur s):
        await _nouveauProduit(s);
      case ('texte', CatRayon r):
        if (await ajouterDepuisTexte(context, b, rayon: r)) _modifie();
      case ('texte', CatSecteur s):
        if (await ajouterDepuisTexte(context, b, rayon: _rayonDe(s), secteur: s)) _modifie();
      case ('texte', _):
        if (await ajouterDepuisTexte(context, b)) _modifie();
      case ('rayon', _):
        await e.nouveauRayon();
        if (mounted) setState(() {});
      case ('renommer', final Object x):
        _commencerRenommage(x);
      case ('icone', CatRayon r):
        await _choisirImage(cleChoixRayon(r.nom), r.nom);
      case ('icone', CatSecteur s):
        await _choisirImage(cleChoixSecteur(_rayonDe(s)?.nom ?? '', s.nom), s.nom);
      case ('ordre', CatRayon r):
        final noms = await ordonner(context, titre: 'Ordre des secteurs · ${r.nom}', noms: [for (final s in r.secteurs) s.nom]);
        if (noms == null) return;
        b.ordonnerSecteurs(r, noms);
        _modifie();
      case ('enRayon', CatSecteur s):
        _secteurEnRayon(s);
      case ('enSecteur', CatRayon r):
        await _rayonEnSecteur(r);
      case ('supprimer', final Object x):
        await _supprimer(x);
    }
  }

  /// Un secteur devient un rayon du même nom (avec un secteur du même nom qui garde ses produits).
  void _secteurEnRayon(CatSecteur s) {
    final r = _rayonDe(s);
    if (r == null) return;
    final image = b.images[cleChoixSecteur(r.nom, s.nom)];
    final nr = b.secteurEnRayon(r, s);
    if (image != null) {
      b.images.putIfAbsent(cleChoixRayon(nr.nom), () => image);
      b.images.putIfAbsent(cleChoixSecteur(nr.nom, s.nom), () => image);
    }
    rayonsOuverts.add(nr);
    choisi = nr;
    _modifie();
    _message('« ${s.nom} » est maintenant un rayon');
  }

  /// Un rayon devient un secteur d'un autre rayon, choisi dans la liste ; ses secteurs y sont réunis.
  Future<void> _rayonEnSecteur(CatRayon r) async {
    final autres = [for (final x in b.catalogue.rayons) if (!identical(x, r)) x];
    final noms = [for (final s in r.secteurs) s.nom];
    final vers = await showDialog<CatRayon>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Charte.blanc,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('« ${r.nom} » devient un secteur de…', style: Charte.texte(18, gras: true)),
          if (noms.length > 1 || (noms.length == 1 && noms.single != r.nom)) ...[
            const SizedBox(height: 6),
            Text('Ses produits (${noms.join(', ')}) seront réunis dans le secteur « ${r.nom} ».',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ],
        ]),
        children: [
          SizedBox(
            width: 480,
            height: 420,
            child: ListView(children: [
              for (final x in autres)
                ListTile(
                  key: ValueKey('vers-rayon-${x.nom}'),
                  leading: Pictogramme(b.images[cleChoixRayon(x.nom)] ?? cleRayon(x.nom), taille: 28),
                  title: Text(x.nom, style: Charte.texte(15)),
                  onTap: () => Navigator.of(ctx).pop(x),
                ),
            ]),
          ),
        ],
      ),
    );
    if (vers == null || !mounted) return;
    final image = b.images[cleChoixRayon(r.nom)];
    final s = b.rayonEnSecteur(r, vers);
    if (image != null) b.images.putIfAbsent(cleChoixSecteur(vers.nom, s.nom), () => image);
    rayonsOuverts.add(vers);
    secteursOuverts.add(s);
    choisi = s;
    _modifie();
    _message('« ${r.nom} » est maintenant un secteur de ${vers.nom}');
  }

  Future<void> _menuGeneral(String v) async {
    switch (v) {
      case 'historique':
        await montrerHistorique(context, e);
      case 'iconographie':
        await montrerIconographie(context, e);
      case 'images':
        await montrerImagesAjoutees(context, e);
      case 'valider':
        await e.valider();
      case 'generaliser':
        await e.generaliser();
      case 'repartir':
        await e.repartir();
      case 'cle':
        await e.cleSignature();
      case 'renvoyer':
        await e.renvoyer();
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- titre

  Widget _titre() {
    final p = e.publie;
    final numero = e.numeroPublie;
    final date = p?['date'] as String?;
    final secteurs = b.catalogue.rayons.fold(0, (n, r) => n + r.secteurs.length);
    final manquantes = sansIcone(b);
    Widget pastille(String cle, String libelle, String valeur, {bool fort = false}) => Container(
          key: ValueKey('pastille-$cle'),
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
            color: fort ? Charte.clair(Charte.accent, 0.6) : Charte.blanc,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Charte.separateurZone),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(valeur, style: Charte.texte(17, gras: true, couleur: Charte.encreNiveau)),
            Text(libelle, style: Charte.texte(12, couleur: Charte.texteSecondaire)),
          ]),
        );
    PopupMenuItem<String> item(String v, IconData i, String t, {bool actif = true}) => PopupMenuItem(
          value: v,
          enabled: actif,
          height: 42,
          child: Row(children: [Icone(i, size: 22, color: Charte.cadre), const SizedBox(width: 12), Text(t, style: Charte.texte(15))]),
        );
    return Container(
      color: Charte.fondBandeau,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icone(Icons.public, size: 34, color: Charte.cadre),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Catalogue commun', style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau)),
              Text(
                [
                  numero == 0 ? 'Aucune version publiée' : 'Version publiée v$numero${date == null ? '' : ' du ${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}'}',
                  _pluriel(b.catalogue.rayons.length, 'rayon'),
                  _pluriel(secteurs, 'secteur'),
                  _pluriel(b.nbProduits, 'produit'),
                  if (manquantes > 0) '$manquantes sans icône',
                ].join(' · '),
                style: Charte.texte(14, couleur: Charte.texteSecondaire),
              ),
            ]),
          ),
          pastille('en-cours', 'en cours', '${e.enCours}', fort: e.enCours > 0),
          pastille('etapes', 'étapes', '${e.journal.etapes.length}'),
          pastille('a-generaliser', 'à généraliser', b.modifications == 0 ? 'rien' : '${b.modifications}'),
          const SizedBox(width: 12),
          _Bouton(
            key: const ValueKey('generaliser'),
            texte: e.enPublication ? 'Envoi…' : 'Généraliser (v${numero + 1})',
            icone: Icons.public,
            plein: true,
            onTap: e.enPublication || b.modifications == 0 || e.enCours > 0 ? null : () => _menuGeneral('generaliser'),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            key: const ValueKey('console-menu'),
            tooltip: 'Menu',
            icon: Icone(Icons.menu, size: 28, color: Charte.cadre),
            onSelected: _menuGeneral,
            itemBuilder: (_) => [
              item('historique', Icons.history, 'Historique…'),
              item('iconographie', Icons.image_outlined, 'Iconographie…${manquantes > 0 ? ' ($manquantes sans icône)' : ''}'),
              item('images', Icons.add_photo_alternate_outlined, 'Images ajoutées…${b.imagesPerso.isEmpty ? '' : ' (${b.imagesPerso.length})'}'),
              item('valider', Icons.check, 'Valider les modifications (${e.enCours})…', actif: e.enCours > 0),
              item('generaliser', Icons.public, 'Généraliser (v${numero + 1})…', actif: b.modifications > 0 && e.enCours == 0),
              const PopupMenuDivider(),
              item('repartir', Icons.restore, 'Repartir d\'un catalogue…'),
              item('cle', Icons.key_outlined, 'Clé de signature…'),
              if (e.absenteDuServeur) item('renvoyer', Icons.cloud_upload_outlined, 'Renvoyer v$numero au serveur'),
            ],
          ),
        ]),
        if (e.enCours > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 46),
            child: Text('${_pluriel(e.enCours, 'modification')} en cours : validez-les (menu ☰) avant de généraliser.',
                style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
          ),
        if (e.absenteDuServeur)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 46),
            child: Text('La version v$numero n\'est pas sur le serveur : renvoyez-la (menu ☰).',
                style: Charte.texte(13.5, gras: true, couleur: Charte.rouge)),
          ),
      ]),
    );
  }

  // ---------------------------------------------------------------- cadre du catalogue

  List<_Ligne> _lignes() {
    final f = recherche.trim().toLowerCase();
    final cherche = f.length >= 2;
    final l = <_Ligne>[];
    for (final r in b.catalogue.rayons) {
      final rTrouve = cherche && r.nom.toLowerCase().contains(f);
      final sous = <_Ligne>[];
      for (final s in r.secteurs) {
        final sTrouve = cherche && s.nom.toLowerCase().contains(f);
        final produits = [for (final p in s.produits) if (cherche && p.nom.toLowerCase().contains(f)) p];
        if (cherche && !rTrouve && !sTrouve && produits.isEmpty) continue;
        sous.add(_Ligne(r, s));
        if (cherche ? produits.isNotEmpty : secteursOuverts.contains(s)) {
          final montres = cherche && !sTrouve ? produits : ([...s.produits]..sort((a, c) => a.nom.toLowerCase().compareTo(c.nom.toLowerCase())));
          if (cherche && sTrouve && !secteursOuverts.contains(s) && produits.isEmpty) continue;
          for (final p in montres) {
            sous.add(_Ligne(r, s, p));
          }
        }
      }
      if (cherche && !rTrouve && sous.isEmpty) continue;
      l.add(_Ligne(r));
      if (cherche || rayonsOuverts.contains(r)) l.addAll(sous);
    }
    return l;
  }

  Widget _libelle(Object o, String nom, TextStyle style) {
    if (!identical(_edite, o)) return Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _finirRenommage(garder: false)},
      child: SizedBox(
        height: 30,
        child: TextField(
          key: const ValueKey('renommage'),
          controller: _champ,
          autofocus: true,
          style: style,
          // 07/11/2026 (Aristide) : renommage en place sans cadre, le texte reste où il était.
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 6),
          ),
          onSubmitted: (_) => _finirRenommage(),
          onTapOutside: (_) => _finirRenommage(),
        ),
      ),
    );
  }

  Widget _rangee(_Ligne l) {
    final o = l.objet;
    final niveau = l.p != null ? 3 : (l.s != null ? 2 : 1);
    final selection = o is CatProduit ? produitsChoisis.contains(o) : identical(choisi, o);
    final survol = identical(_survole, o);
    final hauteur = niveau == 1 ? 42.0 : (niveau == 2 ? 38.0 : 32.0);
    final fond = survol
        ? Charte.accent
        : selection
            ? Charte.fondSelection
            : (niveau == 1 ? Charte.niveau(2) : niveau == 2 ? Charte.niveau(3) : Charte.blanc);
    final ouvert = niveau == 1 ? (recherche.trim().length >= 2 || rayonsOuverts.contains(l.r)) : secteursOuverts.contains(l.s);
    Widget contenu;
    switch (niveau) {
      case 1:
        final r = l.r;
        contenu = Row(children: [
          Icone(ouvert ? Icons.expand_more : Icons.chevron_right, size: 22, color: Charte.encreNiveau),
          _icone(b.images[cleChoixRayon(r.nom)] ?? cleRayon(r.nom), 30, () => _choisirImage(cleChoixRayon(r.nom), r.nom), r.nom),
          const SizedBox(width: 8),
          Expanded(child: _libelle(r, r.nom, Charte.texte(15, gras: true, couleur: Charte.encreNiveau))),
          Text(_pluriel(r.secteurs.length, 'secteur'), style: Charte.texte(13, couleur: Charte.encreNiveau)),
          const SizedBox(width: 8),
        ]);
      case 2:
        final s = l.s!;
        contenu = Row(children: [
          const SizedBox(width: 30),
          Icone(ouvert ? Icons.expand_more : Icons.chevron_right, size: 20, color: Charte.encreNiveau),
          _icone(b.images[cleChoixSecteur(l.r.nom, s.nom)] ?? cleSecteur(l.r.nom, s.nom), 26,
              () => _choisirImage(cleChoixSecteur(l.r.nom, s.nom), s.nom), s.nom),
          const SizedBox(width: 8),
          Expanded(child: _libelle(s, s.nom, Charte.texte(14.5, gras: true))),
          Text(_pluriel(s.produits.length, 'produit'), style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          const SizedBox(width: 8),
        ]);
      default:
        final p = l.p!;
        contenu = Row(children: [
          const SizedBox(width: 92),
          Expanded(flex: 4, child: _libelle(p, p.nom, Charte.texte(14.5, gras: selection))),
          Expanded(
            flex: 3,
            child: Text(p.formats.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
          ),
          Expanded(
            flex: 3,
            child: Text(p.marques.take(4).join(', '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
          ),
        ]);
    }
    final rangee = Container(
      height: hauteur,
      padding: const EdgeInsets.only(left: 8, right: 8),
      decoration: BoxDecoration(color: fond, border: Border(bottom: BorderSide(color: niveau == 3 ? Charte.separateurLigne : Charte.blanc))),
      child: contenu,
    );
    final glisse = switch (niveau) {
      1 => _Glisse.rayon(l.r),
      2 => _Glisse.secteur(l.r, l.s),
      _ => _Glisse.produits(produitsChoisis.contains(l.p) ? [...produitsChoisis] : [l.p!]),
    };
    final cible = DragTarget<_Glisse>(
      onWillAcceptWithDetails: (d) {
        final ok = _accepte(d.data, l);
        if (ok) setState(() => _survole = o);
        return ok;
      },
      onLeave: (_) => setState(() => _survole = null),
      onAcceptWithDetails: (d) {
        setState(() => _survole = null);
        _deposer(d.data, l);
      },
      builder: (_, __, ___) => GestureDetector(
        key: ValueKey(switch (niveau) { 1 => 'console-rayon-${l.r.nom}', 2 => 'console-secteur-${l.r.nom}/${l.s!.nom}', _ => 'console-produit-${l.s!.nom}/${l.p!.nom}' }),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _focus.requestFocus();
          setState(() {
            if (o is CatProduit) {
              if (!HardwareKeyboard.instance.isControlPressed) produitsChoisis.clear();
              produitsChoisis.contains(o) && HardwareKeyboard.instance.isControlPressed ? produitsChoisis.remove(o) : produitsChoisis.add(o);
              choisi = null;
            } else {
              produitsChoisis.clear();
              choisi = o;
              if (o is CatRayon) rayonsOuverts.contains(o) ? rayonsOuverts.remove(o) : rayonsOuverts.add(o);
              if (o is CatSecteur) secteursOuverts.contains(o) ? secteursOuverts.remove(o) : secteursOuverts.add(o);
            }
          });
        },
        onDoubleTap: () => _commencerRenommage(o),
        onSecondaryTapDown: (d) => _menu(d.globalPosition, l),
        child: rangee,
      ),
    );
    return Draggable<_Glisse>(
      data: glisse,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragUpdate: (d) => _suivreGlisse(d.globalPosition),
      onDragEnd: (_) => _arreterDefilement(),
      onDraggableCanceled: (_, __) => _arreterDefilement(),
      onDragCompleted: _arreterDefilement,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Charte.cadre,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(glisse.libelle, style: Charte.texte(14, gras: true, couleur: Charte.blanc)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: rangee),
      child: cible,
    );
  }

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

  Future<void> _touche(String t) async {
    final o = produitsChoisis.isNotEmpty ? produitsChoisis.first : choisi;
    if (o == null || _edite != null) return;
    switch (t) {
      case 'F2':
        if (produitsChoisis.length <= 1) _commencerRenommage(o);
      case 'Suppr':
        await _supprimer(o);
      case 'Entrée':
        if (o is CatSecteur) await _nouveauProduit(o);
        if (o is CatRayon) await _nouveauSecteur(o);
    }
  }

  Widget _cadre() {
    final lignes = _lignes();
    final toutOuvert = rayonsOuverts.length == b.catalogue.rayons.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
        child: Row(children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: TextField(
                key: const ValueKey('console-recherche'),
                style: Charte.texte(15),
                decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Un rayon, un secteur, un produit'),
                onChanged: (v) => setState(() => recherche = v),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: toutOuvert ? 'Tout replier' : 'Tout déplier',
            child: IconButton(
              key: const ValueKey('console-tout'),
              onPressed: () => setState(() {
                if (toutOuvert) {
                  rayonsOuverts.clear();
                  secteursOuverts.clear();
                } else {
                  rayonsOuverts.addAll(b.catalogue.rayons);
                }
              }),
              icon: Icone(toutOuvert ? Icons.unfold_less : Icons.unfold_more, size: 26, color: Charte.cadre),
            ),
          ),
          const Spacer(),
          // 07/11/2026 (Aristide) : ajouter à partir d'un texte toujours à portée, pas seulement au clic droit.
          const SizedBox(width: 12),
          _Bouton(
            key: const ValueKey('console-texte'),
            texte: 'Ajouter à partir d\'un texte',
            icone: Icons.notes,
            onTap: () async {
              final o = choisi;
              final ok = switch (o) {
                CatSecteur s => await ajouterDepuisTexte(context, b, rayon: _rayonDe(s), secteur: s),
                CatRayon r => await ajouterDepuisTexte(context, b, rayon: r),
                _ => await ajouterDepuisTexte(context, b),
              };
              if (ok) _modifie();
            },
          ),
          const SizedBox(width: 8),
          _Bouton(
            key: const ValueKey('console-nouveau-rayon'),
            texte: 'Nouveau rayon',
            icone: Icons.add,
            onTap: () async {
              await e.nouveauRayon();
              if (mounted) setState(() {});
            },
          ),
        ]),
      ),
      // Aide sur sa propre ligne : à côté des boutons, elle était écrasée quand la fenêtre est étroite.
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
        child: Text(
          'Clic droit : actions de l\'élément · Double-clic ou F2 : renommer · Suppr : retirer · Entrée : ajouter dedans · '
          'Glisser-déposer : déplacer un produit, un secteur ou un rayon · Ctrl+clic : plusieurs produits',
          style: Charte.texte(12.5, couleur: Charte.texteSecondaire),
        ),
      ),
      Expanded(
        child: Container(
          key: _cleCadre,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(border: Border.all(color: Charte.separateurZone), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.f2): () => _touche('F2'),
              const SingleActivator(LogicalKeyboardKey.delete): () => _touche('Suppr'),
              const SingleActivator(LogicalKeyboardKey.enter): () => _touche('Entrée'),
              const SingleActivator(LogicalKeyboardKey.numpadEnter): () => _touche('Entrée'),
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapDown: (d) => _menu(d.globalPosition, null),
                child: ListView.builder(
                  key: const ValueKey('console-cadre'),
                  controller: _defilement,
                  itemCount: lignes.length,
                  itemBuilder: (_, i) => _rangee(lignes[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (e.b == null) return const Center(child: CircularProgressIndicator());
    // Scaffold : pour les messages en bas de l'écran.
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _titre(),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(child: _cadre()),
      ]),
    );
  }
}

// ---------------------------------------------------------------- historique (fenêtre)

/// L'historique en fenêtre : les étapes à gauche (et ce qui est en cours), le détail de la ligne choisie à droite,
/// « Repartir de cette étape » avec confirmation.
Future<void> montrerHistorique(BuildContext context, EtatEditeurCatalogue e) {
  int? choix = e.enCours > 0 ? -1 : (e.journal.etapes.isEmpty ? null : e.journal.etapes.length - 1);
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, maj) {
      final j = e.journal;
      String date(DateTime d) => JournalCatalogue.nomParDefaut(d);
      Widget ligne(int i) {
        final enCours = i < 0;
        final et = enCours ? null : j.etapes[i];
        final gestes = enCours ? j.enCours : et!.gestes;
        final etat = enCours ? 'en cours' : (et!.numero != null ? 'généralisée v${et.numero}' : 'validée');
        final actif = choix == i;
        return Material(
          color: actif ? Charte.fondSelection : Colors.transparent,
          child: InkWell(
            key: ValueKey('historique-ligne-$i'),
            onTap: () => maj(() => choix = i),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(enCours ? 'Modifications en cours' : et!.nom, style: Charte.texte(15, gras: true)),
                Text('${enCours ? '' : '${date(et!.date)} · '}$etat · ${_pluriel(gestes.length, 'modification')}',
                    style: Charte.texte(12.5, couleur: enCours ? Charte.cadre : Charte.texteSecondaire)),
              ]),
            ),
          ),
        );
      }

      final c = choix;
      final gestes = c == null ? const <GesteCatalogue>[] : (c < 0 ? j.enCours : j.etapes[c].gestes);
      return Dialog(
        backgroundColor: Charte.blanc,
        child: SizedBox(
          width: 1000,
          height: 640,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Text('Historique des modifications', style: Charte.texte(19, gras: true)),
            ),
            Container(height: 1, color: Charte.separateurZone),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 360,
                  child: ListView(children: [
                    if (j.enCours.isNotEmpty) ligne(-1),
                    for (var i = j.etapes.length - 1; i >= 0; i--) ligne(i),
                  ]),
                ),
                VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
                Expanded(
                  child: c == null
                      ? const SizedBox()
                      : ListView(padding: const EdgeInsets.all(16), children: [
                          if (gestes.isEmpty) Text('Aucune modification.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                          for (final g in gestes.reversed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                for (final l in g.lignes) Text(l, style: Charte.texte(15)),
                                Text(date(g.date), style: Charte.texte(12, couleur: Charte.texteSecondaire)),
                              ]),
                            ),
                        ]),
                ),
              ]),
            ),
            Container(height: 1, color: Charte.separateurZone),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (c != null && c < 0)
                  _Bouton(
                    key: const ValueKey('historique-valider'),
                    texte: 'Valider ces modifications',
                    icone: Icons.check,
                    onTap: () async {
                      await e.valider();
                      maj(() => choix = j.etapes.length - 1);
                    },
                  ),
                if (c != null && c >= 0)
                  _Bouton(
                    key: const ValueKey('historique-repartir'),
                    texte: 'Repartir de cette étape',
                    icone: Icons.history,
                    onTap: () async {
                      if (await e.revenirA(c)) maj(() => choix = j.etapes.length - 1);
                    },
                  ),
                const SizedBox(width: 10),
                _Bouton(key: const ValueKey('historique-fermer'), texte: 'Fermer', onTap: () => Navigator.of(ctx).pop()),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
}

// ---------------------------------------------------------------- iconographie (fenêtre)

Future<void> montrerIconographie(BuildContext context, EtatEditeurCatalogue e) => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Charte.blanc,
        child: SizedBox(width: 1100, height: 760, child: PanneauIconographie(editeur: e)),
      ),
    );

/// Rayons et secteurs avec l'état de leur icône, des propositions à cliquer et la bibliothèque.
class PanneauIconographie extends StatefulWidget {
  const PanneauIconographie({super.key, required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<PanneauIconographie> createState() => _PanneauIconographieState();
}

class _PanneauIconographieState extends State<PanneauIconographie> {
  bool tout = false;
  Brouillon get b => widget.editeur.b!;

  void _fixer(String cle, String? picto) {
    b.choisirImage(cle, picto);
    widget.editeur.modifie();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lignes = <(String cle, String nom, String? rayon, EtatIcone etat, String? actuelle, List<String> produits)>[];
    for (final r in b.catalogue.rayons) {
      lignes.add((cleChoixRayon(r.nom), r.nom, null, etatIconeRayon(r.nom, b.images), b.images[cleChoixRayon(r.nom)] ?? cleRayon(r.nom),
          [for (final s in r.secteurs) s.nom]));
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
    final vues = [for (final l in lignes) if (tout || aCompleter(l.$4)) l];
    const libelles = {EtatIcone.choisie: 'choisie', EtatIcone.exacte: 'livrée', EtatIcone.approchee: 'approchée', EtatIcone.aucune: 'aucune'};

    Widget ligne((String, String, String?, EtatIcone, String?, List<String>) l) {
      final (cle, nom, rayon, etat, actuelle, produits) = l;
      final propositions = [for (final c in propositionsIcone(nom, produits, max: 8)) if (c != actuelle) c].take(7).toList();
      return Container(
        key: ValueKey('icono-$cle'),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        decoration: BoxDecoration(
          color: rayon == null ? Charte.niveau(3) : Charte.blanc,
          border: Border(bottom: BorderSide(color: Charte.separateurLigne)),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: actuelle != null ? Pictogramme(actuelle, taille: 46) : Icone(Icons.hide_image_outlined, size: 30, color: Charte.texteSecondaire),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 260,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(rayon == null ? nom.toUpperCase() : nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(15, gras: true)),
              Text('${rayon == null ? 'Rayon' : 'Secteur de $rayon'} · ${libelles[etat]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Charte.texte(12.5, gras: etat == EtatIcone.aucune, couleur: etat == EtatIcone.aucune ? Charte.rouge : Charte.texteSecondaire)),
            ]),
          ),
          Expanded(
            child: Row(children: [
              for (final c in propositions)
                Tooltip(
                  message: '${nomImage(c)} · ${origineImage(c)}',
                  child: InkWell(
                    key: ValueKey('proposition-$cle-$c'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _fixer(cle, c),
                    child: Padding(padding: const EdgeInsets.all(4), child: Pictogramme(c, taille: 42)),
                  ),
                ),
              if (propositions.isEmpty) Text('Aucune proposition', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ]),
          ),
          if (etat == EtatIcone.choisie)
            Tooltip(
              message: 'Revenir à l\'icône automatique',
              child: IconButton(onPressed: () => _fixer(cle, null), icon: Icone(Icons.undo, size: 24, color: Charte.cadre)),
            ),
          Tooltip(
            message: 'Bibliothèque',
            child: IconButton(
              key: ValueKey('bibliotheque-$cle'),
              onPressed: () async {
                final c = await choisirDansBibliotheque(context,
                    titre: 'Icône de $nom', ajouter: () => ajouterImageBibliotheque(context, widget.editeur));
                if (c != null && mounted) _fixer(cle, c == imageAutomatique ? null : c);
              },
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
            selected: !tout,
            onSelected: (_) => setState(() => tout = false),
          ),
          ChoiceChip(
            key: const ValueKey('icono-tout'),
            label: Text('Tous (${lignes.length})'),
            selected: tout,
            onSelected: (_) => setState(() => tout = true),
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
      Container(height: 1, color: Charte.separateurZone),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerRight,
          child: _Bouton(key: const ValueKey('icono-fermer'), texte: 'Fermer', onTap: () => Navigator.of(context).pop()),
        ),
      ),
    ]);
  }
}

/// [Bouton] à la largeur de son libellé (dans une rangée, où la largeur n'est pas bornée).
class _Bouton extends StatelessWidget {
  const _Bouton({super.key, required this.texte, required this.onTap, this.icone, this.plein = false});
  final String texte;
  final VoidCallback? onTap;
  final IconData? icone;
  final bool plein;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(child: Bouton(texte: texte, icone: icone, onTap: onTap, plein: plein, taille: 15));
}
