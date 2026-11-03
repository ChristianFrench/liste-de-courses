import 'package:flutter/material.dart';

import '../donnees/import_texte.dart' show normaliser;
import '../donnees/modele.dart';
import '../theme.dart';
import 'icone.dart';

/// Nombre de lettres à taper avant que la liste des articles s'affiche.
const lettresRecherche = 3;

/// Résultats montrés d'abord ; « Voir plus » montre les autres (31/10/2026 : affichage moins encombré).
const premiersResultats = 8;

/// Articles dont un mot commence par le texte tapé (sans tenir compte des accents ni des majuscules) ;
/// chaque mot tapé doit commencer un mot du nom. Ceux dont le nom commence par le texte viennent d'abord,
/// puis les plus achetés par le foyer, puis les plus courants en magasin (popularité Open Food Facts).
List<Produit> chercherProduits(Iterable<Produit> produits, String texte, {int max = 40}) {
  final q = normaliser(texte).split(' ').where((m) => m.isNotEmpty).toList();
  if (q.isEmpty || normaliser(texte).length < lettresRecherche) return [];
  final etat = Etat.instance;
  final res = <(Produit, bool)>[];
  for (final p in produits) {
    final n = normaliser(p.nom);
    final mots = n.split(' ');
    if (q.every((m) => mots.any((x) => x.startsWith(m)))) res.add((p, n.startsWith(q.first)));
  }
  res.sort((a, b) {
    if (a.$2 != b.$2) return a.$2 ? -1 : 1;
    final u = b.$1.nbUtilisations.compareTo(a.$1.nbUtilisations);
    if (u != 0) return u;
    final c = etat.popularite(b.$1).compareTo(etat.popularite(a.$1));
    return c != 0 ? c : normaliser(a.$1.nom).compareTo(normaliser(b.$1.nom));
  });
  return [for (final r in res.take(max)) r.$1];
}

/// Recherche par marque (31/10/2026, élargie le 03/11/2026 à la demande d'Aristide) : un article et une marque
/// qu'on peut lui donner. Les marques d'un article : celles de sa nature (Open Food Facts) et celles de son
/// secteur dans le catalogue des marques. Chaque mot tapé commence un mot du nom ou de la marque, et au moins
/// un mot est celui de la marque : « nut » → Pâte à tartiner chocolat · Nutella ; « camembert prés » →
/// Camembert · Président. Ceux qui reprennent des mots du nom d'abord, puis la nature, l'usage, la popularité.
List<(Produit, String)> chercherMarques(Iterable<Produit> produits, String texte, {int max = 6}) {
  final etat = Etat.instance;
  final q = normaliser(texte).split(' ').where((m) => m.isNotEmpty).toList();
  if (q.isEmpty || normaliser(texte).length < lettresRecherche) return [];
  final parSecteur = <String, List<String>>{};
  final res = <(Produit, String, int, bool)>[];
  for (final p in produits) {
    final nom = normaliser(p.nom);
    final motsNom = nom.split(' ');
    final nature = etat.naturesOff[p.nom.toLowerCase()]?.marques ?? const <String>[];
    final s = etat.secteurCatalogue(p.id);
    final marques = <String>{
      ...nature,
      if (s != null) ...parSecteur.putIfAbsent(s.id, () => etat.marquesDuSecteur(s)),
    };
    (String, int, bool)? meilleur;
    for (final m in marques) {
      final nm = normaliser(m);
      if (nm.isEmpty || nom.contains(nm)) continue;
      final motsMarque = nm.split(' ');
      var dansMarque = false, dansNom = 0, ok = true;
      for (final x in q) {
        final n = motsNom.any((w) => w.startsWith(x));
        final mq = motsMarque.any((w) => w.startsWith(x));
        if (!n && !mq) {
          ok = false;
          break;
        }
        if (mq) dansMarque = true;
        if (n) dansNom++;
      }
      // La marque seule (« président ») : seulement pour les natures qui la portent (sinon tout le secteur viendrait).
      if (!ok || !dansMarque) continue;
      final deNature = nature.contains(m);
      if (dansNom == 0 && !deNature) continue;
      if (meilleur == null || dansNom > meilleur.$2 || (deNature && !meilleur.$3)) meilleur = (m, dansNom, deNature);
    }
    if (meilleur != null) res.add((p, meilleur.$1, meilleur.$2, meilleur.$3));
  }
  res.sort((a, b) {
    if (a.$3 != b.$3) return b.$3.compareTo(a.$3);
    if (a.$4 != b.$4) return a.$4 ? -1 : 1;
    final u = b.$1.nbUtilisations.compareTo(a.$1.nbUtilisations);
    if (u != 0) return u;
    return etat.popularite(b.$1).compareTo(etat.popularite(a.$1));
  });
  return [for (final r in res.take(max)) (r.$1, r.$2)];
}

/// Option « Voir plus » de la liste déroulante.
/// « Créer « x » dans un autre secteur » : le nom existe déjà au catalogue.
class _AutreSecteur {
  const _AutreSecteur(this.nom);
  final String nom;
}

class _VoirPlus {
  const _VoirPlus(this.reste);
  final int reste;
}

/// Champ de recherche sous le titre : à partir de trois lettres, une liste déroulante montre les articles
/// qui contiennent un mot commençant par le texte ; en toucher un le choisit ([onChoix]).
/// [onNouveau] ajoute, en fin de liste déroulante, « Créer « texte » » pour un article absent du catalogue.
class ChampRecherche extends StatefulWidget {
  const ChampRecherche({
    super.key,
    required this.produits,
    required this.onChoix,
    this.onNouveau,
    this.onMarque,
    this.detail,
    this.droite,
    this.largeur,
    this.aide = 'Rechercher un article',
  });
  final Iterable<Produit> Function() produits;
  final void Function(Produit p) onChoix;
  final void Function(String nom)? onNouveau;

  /// Choix d'une nature avec sa marque (« Pâte à tartiner chocolat · Nutella ») ; sans lui, pas de recherche
  /// par marque.
  final void Function(Produit p, String marque)? onMarque;

  /// Ligne d'explication sous le nom (ex. : rayon › secteur).
  final String Function(Produit p)? detail;

  /// Bouton à droite du champ (ex. : « Parcourir »).
  final Widget? droite;

  /// Largeur du champ ; par défaut, toute la largeur (moins [droite]).
  final double? largeur;
  final String aide;

  @override
  State<ChampRecherche> createState() => _ChampRechercheState();
}

class _ChampRechercheState extends State<ChampRecherche> {
  final _texte = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Le champ est recréé après chaque choix : la liste des articles trouvés ne peut pas rester affichée
  /// sous un champ vide.
  int _generation = 0;

  /// « Voir plus » touché pour ce texte : tous les résultats.
  bool _tout = false;
  String _dernier = '';

  void _fini() {
    _texte.clear();
    _focus.unfocus();
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: Row(
        children: [
          if (widget.largeur case final l?) SizedBox(width: l, child: _champ()) else Expanded(child: _champ()),
          if (widget.droite != null) ...[const SizedBox(width: 6), widget.droite!],
        ],
      ),
    );
  }

  Widget _champ() {
    return LayoutBuilder(
      builder: (context, contraintes) => RawAutocomplete<Object>(
        key: ValueKey(_generation),
        textEditingController: _texte,
        focusNode: _focus,
        displayStringForOption: (_) => '',
        optionsBuilder: (v) {
          final t = v.text.trim();
          if (t != _dernier) _tout = false;
          _dernier = t;
          if (normaliser(t).length < lettresRecherche) return const [];
          final produits = widget.produits();
          final trouves = chercherProduits(produits, t);
          final existe = trouves.any((p) => normaliser(p.nom) == normaliser(t));
          final res = <Object>[...(_tout ? trouves : trouves.take(premiersResultats))];
          if (!_tout && trouves.length > premiersResultats) res.add(_VoirPlus(trouves.length - premiersResultats));
          // Les marques quand le texte tapé en contient une (et que les articles trouvés laissent la place).
          if (widget.onMarque != null && trouves.length < premiersResultats) {
            res.addAll(chercherMarques(produits, t, max: premiersResultats - trouves.length.clamp(0, 2)));
          }
          // 02/11/2026 (Aristide) : un nom déjà au catalogue peut se créer dans un autre secteur (frais / libre-service).
          if (widget.onNouveau != null) res.add(existe ? _AutreSecteur(t) : t);
          return res;
        },
        onSelected: (o) {
          if (o is _VoirPlus) {
            // Le champ vient d'être vidé par le choix : on remet le texte, avec tous les résultats.
            _tout = true;
            _texte.text = _dernier;
            _texte.selection = TextSelection.collapsed(offset: _dernier.length);
            return;
          }
          _fini();
          if (o is (Produit, String)) {
            widget.onMarque?.call(o.$1, o.$2);
          } else if (o is Produit) {
            widget.onChoix(o);
          } else if (o is _AutreSecteur) {
            widget.onNouveau?.call(o.nom);
          } else if (o is String) {
            widget.onNouveau?.call(o);
          }
        },
        fieldViewBuilder: (context, controleur, focus, valider) => TextField(
          key: const ValueKey('champ-recherche'),
          controller: controleur,
          focusNode: focus,
          style: Charte.texte(18),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            hintText: widget.aide,
            hintMaxLines: 2,
            hintStyle: Charte.texte(widget.largeur == null && widget.droite == null ? 14 : 17, couleur: Charte.texteSecondaire),
            prefixIcon: Icone(Icons.search, color: Charte.cadre),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 34),
            suffixIcon: ListenableBuilder(
              listenable: controleur,
              builder: (context, _) => controleur.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icone(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                      onPressed: _fini),
            ),
            filled: true,
            fillColor: Charte.blanc,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Charte.separateurZone),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Charte.separateurZone),
            ),
          ),
        ),
        // La liste des trouvés peut être plus large qu'un champ étroit : toute la largeur de l'écran.
        optionsViewBuilder: (context, choisir, options) => OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: MediaQuery.sizeOf(context).width - 20,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              decoration: BoxDecoration(
                color: Charte.blanc,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Charte.separateurZone),
                boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 320, maxWidth: MediaQuery.sizeOf(context).width - 20),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final (i, o) in options.indexed)
                        InkWell(
                          key: ValueKey('option-recherche-$i'),
                          onTap: () => choisir(o),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Charte.separateurLigne)),
                            ),
                            child: o is _VoirPlus
                                ? Text('Voir plus (${o.reste})', style: Charte.texte(16, gras: true, couleur: Charte.cadre))
                                : o is (Produit, String)
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${o.$1.nom} · ${o.$2}', style: Charte.texte(16)),
                                      if (widget.detail?.call(o.$1) case final d? when d.isNotEmpty)
                                        Text(d, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                                    ],
                                  )
                                : o is Produit
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(o.nom, style: Charte.texte(16)),
                                            if (widget.detail?.call(o) case final d? when d.isNotEmpty)
                                              Text(d, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Icone(Icons.add_circle_outline, color: Charte.cadre),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(o is _AutreSecteur ? 'Créer « ${o.nom} » dans un autre secteur' : 'Créer « $o »', style: Charte.texte(16, gras: true, couleur: Charte.cadre)),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
