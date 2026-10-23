import 'package:flutter/material.dart';

import '../donnees/import_texte.dart' show normaliser;
import '../donnees/modele.dart';
import '../theme.dart';

/// Nombre de lettres à taper avant que la liste des articles s'affiche.
const lettresRecherche = 3;

/// Articles dont un mot commence par le texte tapé (sans tenir compte des accents ni des majuscules) ;
/// chaque mot tapé doit commencer un mot du nom. Ceux dont le nom commence par le texte viennent d'abord,
/// puis les plus achetés.
List<Produit> chercherProduits(Iterable<Produit> produits, String texte, {int max = 40}) {
  final q = normaliser(texte).split(' ').where((m) => m.isNotEmpty).toList();
  if (q.isEmpty || normaliser(texte).length < lettresRecherche) return [];
  final res = <(Produit, bool)>[];
  for (final p in produits) {
    final n = normaliser(p.nom);
    final mots = n.split(' ');
    if (q.every((m) => mots.any((x) => x.startsWith(m)))) res.add((p, n.startsWith(q.first)));
  }
  res.sort((a, b) {
    if (a.$2 != b.$2) return a.$2 ? -1 : 1;
    final u = b.$1.nbUtilisations.compareTo(a.$1.nbUtilisations);
    return u != 0 ? u : normaliser(a.$1.nom).compareTo(normaliser(b.$1.nom));
  });
  return [for (final r in res.take(max)) r.$1];
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
    this.detail,
    this.coche,
    this.aide = 'Rechercher un article',
  });
  final Iterable<Produit> Function() produits;
  final void Function(Produit p) onChoix;
  final void Function(String nom)? onNouveau;

  /// Ligne d'explication sous le nom (ex. : rayon › secteur).
  final String Function(Produit p)? detail;

  /// Article déjà dans la liste : une coche s'affiche à droite.
  final bool Function(Produit p)? coche;
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

  void _fini() {
    _texte.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: LayoutBuilder(
        builder: (context, contraintes) => RawAutocomplete<Object>(
          textEditingController: _texte,
          focusNode: _focus,
          displayStringForOption: (_) => '',
          optionsBuilder: (v) {
            final t = v.text.trim();
            if (normaliser(t).length < lettresRecherche) return const [];
            final res = <Object>[...chercherProduits(widget.produits(), t)];
            final existe = res.any((p) => normaliser((p as Produit).nom) == normaliser(t));
            if (widget.onNouveau != null && !existe) res.add(t);
            return res;
          },
          onSelected: (o) {
            _fini();
            if (o is Produit) {
              widget.onChoix(o);
            } else if (o is String) {
              widget.onNouveau?.call(o);
            }
          },
          fieldViewBuilder: (context, controleur, focus, valider) => TextField(
            key: const ValueKey('champ-recherche'),
            controller: controleur,
            focusNode: focus,
            style: Charte.texte(16),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.aide,
              prefixIcon: Icon(Icons.search, color: Charte.cadre),
              suffixIcon: ListenableBuilder(
                listenable: controleur,
                builder: (context, _) => controleur.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(tooltip: 'Effacer', icon: const Icon(Icons.close), onPressed: _fini),
              ),
              filled: true,
              fillColor: Charte.blanc,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Charte.separateurZone)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Charte.separateurZone)),
            ),
          ),
          optionsViewBuilder: (context, choisir, options) => Align(
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
                constraints: BoxConstraints(maxHeight: 320, maxWidth: contraintes.maxWidth),
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
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                          child: o is Produit
                              ? Row(children: [
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
                                  if (widget.coche?.call(o) ?? false) Icon(Icons.check, color: Charte.cadre),
                                ])
                              : Row(children: [
                                  Icon(Icons.add_circle_outline, color: Charte.cadre),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Créer « $o »', style: Charte.texte(16, gras: true, couleur: Charte.cadre))),
                                ]),
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
