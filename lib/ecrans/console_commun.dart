import 'package:flutter/material.dart';

import '../composants/composants.dart' show Bouton;
import '../composants/icone.dart';
import '../theme.dart';

// Présentation commune aux trois catalogues de la console (21/11/2026, Aristide : « harmoniser la présentation
// des trois catalogues, prendre comme modèle l'écran du catalogue des produits : en-têtes, boutons, menus ; les
// mêmes données au même endroit ; les listes au format du catalogue des produits avec dépliement, repliement »).
// - [EnTeteConsole] : icône, titre, ligne des chiffres, pastilles (en cours, étapes, à généraliser…), bouton
//   « Généraliser… » et menu ☰ ;
// - [BarreConsole] : recherche au sens strict (n / total, précédent, suivant), tout déplier, boutons à droite,
//   puis la ligne d'aide ;
// - [CadreConsole] : le cadre de la liste, sur toute la largeur ;
// - [RangeeConsole] : toutes les lignes de l'arbre, titres (même présentation à tous les niveaux) et feuilles.

String plurielConsole(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Bouton de la console : celui du catalogue des produits (taille 15, largeur du texte).
class BoutonConsole extends StatelessWidget {
  const BoutonConsole({super.key, required this.texte, this.icone, this.onTap, this.plein = false});
  final String texte;
  final IconData? icone;
  final VoidCallback? onTap;
  final bool plein;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(child: Bouton(texte: texte, icone: icone, onTap: onTap, plein: plein, taille: 15));
}

/// Une pastille de l'en-tête : la valeur en gras, son libellé dessous.
class PastilleConsole {
  const PastilleConsole(this.cle, this.libelle, this.valeur, {this.fort = false});
  final String cle, libelle, valeur;
  final bool fort;
}

/// Une entrée du menu ☰ ; null dans la liste = un séparateur.
class EntreeMenuConsole {
  const EntreeMenuConsole(this.valeur, this.icone, this.texte, {this.actif = true});
  final String valeur, texte;
  final IconData icone;
  final bool actif;
}

/// En-tête d'un catalogue de la console, sur le modèle du catalogue des produits.
class EnTeteConsole extends StatelessWidget {
  const EnTeteConsole({
    super.key,
    required this.signe,
    required this.titre,
    required this.chiffres,
    this.pastilles = const [],
    this.bouton,
    this.menu = const [],
    this.onMenu,
    this.alertes = const [],
  });

  /// Icône ou image à gauche du titre (34 px).
  final Widget signe;
  final String titre;

  /// La ligne sous le titre : version publiée, nombres… (jointe par « · »).
  final List<String> chiffres;
  final List<PastilleConsole> pastilles;

  /// Le bouton principal (Généraliser…).
  final Widget? bouton;
  final List<EntreeMenuConsole?> menu;
  final void Function(String)? onMenu;

  /// Lignes d'avertissement sous le titre : (texte, en rouge).
  final List<(String, bool)> alertes;

  @override
  Widget build(BuildContext context) {
    Widget pastille(PastilleConsole p) => Container(
          key: ValueKey('pastille-${p.cle}'),
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
            color: p.fort ? Charte.clair(Charte.accent, 0.6) : Charte.blanc,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Charte.separateurZone),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(p.valeur, style: Charte.texte(17, gras: true, couleur: Charte.encreNiveau)),
            Text(p.libelle, style: Charte.texte(12, couleur: Charte.texteSecondaire)),
          ]),
        );
    PopupMenuEntry<String> item(EntreeMenuConsole? e) => e == null
        ? const PopupMenuDivider()
        : PopupMenuItem(
            value: e.valeur,
            enabled: e.actif,
            height: 42,
            child: Row(children: [Icone(e.icone, size: 22, color: Charte.cadre), const SizedBox(width: 12), Text(e.texte, style: Charte.texte(15))]),
          );
    return Container(
      color: Charte.fondBandeau,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 34, height: 34, child: Center(child: signe)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre, style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau)),
              Text(chiffres.join(' · '), style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ]),
          ),
          for (final p in pastilles) pastille(p),
          if (bouton != null) ...[const SizedBox(width: 12), bouton!],
          if (menu.isNotEmpty) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              key: const ValueKey('console-menu'),
              tooltip: 'Menu',
              icon: Icone(Icons.menu, size: 28, color: Charte.cadre),
              onSelected: onMenu,
              itemBuilder: (_) => [for (final e in menu) item(e)],
            ),
          ],
        ]),
        for (final (t, rouge) in alertes)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 46),
            child: Text(t, style: Charte.texte(13.5, gras: rouge, couleur: rouge ? Charte.rouge : Charte.texteSecondaire)),
          ),
      ]),
    );
  }
}

/// Barre au-dessus du cadre : recherche au sens strict, tout déplier / tout replier (deux icônes, pour toute la
/// hiérarchie), boutons ; puis l'aide.
class BarreConsole extends StatelessWidget {
  const BarreConsole({
    super.key,
    required this.aideRecherche,
    required this.onChercher,
    required this.onSuivant,
    required this.onPrecedent,
    required this.recherche,
    required this.trouves,
    required this.indice,
    required this.onDeplier,
    required this.onReplier,
    this.boutons = const [],
    required this.aide,
  });
  final String aideRecherche, recherche, aide;
  final void Function(String) onChercher;
  final VoidCallback onSuivant, onPrecedent, onDeplier, onReplier;
  final int trouves, indice;
  final List<Widget> boutons;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
          child: Row(children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: TextField(
                  key: const ValueKey('console-recherche'),
                  style: Charte.texte(15),
                  decoration: InputDecoration(labelText: 'Rechercher', hintText: aideRecherche),
                  onChanged: onChercher,
                  onSubmitted: (_) => onSuivant(),
                ),
              ),
            ),
            if (recherche.trim().length >= 2) ...[
              const SizedBox(width: 10),
              Text(trouves == 0 ? 'Aucun résultat' : '${indice + 1} / $trouves',
                  key: const ValueKey('console-recherche-compte'), style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              Tooltip(
                message: 'Précédent',
                child: IconButton(
                  key: const ValueKey('console-recherche-precedent'),
                  onPressed: trouves < 2 ? null : onPrecedent,
                  icon: Icone(Icons.keyboard_arrow_up, size: 26, color: Charte.cadre),
                ),
              ),
              Tooltip(
                message: 'Suivant',
                child: IconButton(
                  key: const ValueKey('console-recherche-suivant'),
                  onPressed: trouves < 2 ? null : onSuivant,
                  icon: Icone(Icons.keyboard_arrow_down, size: 26, color: Charte.cadre),
                ),
              ),
            ],
            const SizedBox(width: 10),
            // 22/11/2026 (Aristide) : toute la hiérarchie, en icônes : flèche vers le bas = tout déplier,
            // flèche vers le haut = tout replier.
            Tooltip(
              message: 'Tout déplier',
              child: IconButton(
                key: const ValueKey('console-tout-deplier'),
                onPressed: onDeplier,
                icon: Icone(Icons.keyboard_double_arrow_down, size: 28, color: Charte.cadre),
              ),
            ),
            Tooltip(
              message: 'Tout replier',
              child: IconButton(
                key: const ValueKey('console-tout-replier'),
                onPressed: onReplier,
                icon: Icone(Icons.keyboard_double_arrow_up, size: 28, color: Charte.cadre),
              ),
            ),
            const Spacer(),
            for (final b in boutons) ...[const SizedBox(width: 8), b],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Text(aide, style: Charte.texte(12.5, couleur: Charte.texteSecondaire)),
        ),
      ]);
}

/// Le cadre de la liste, sur toute la largeur.
class CadreConsole extends StatelessWidget {
  const CadreConsole({super.key, required this.child, this.cleCadre});
  final Widget child;
  final Key? cleCadre;

  @override
  Widget build(BuildContext context) => Container(
        key: cleCadre,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(color: Charte.blanc, border: Border.all(color: Charte.separateurZone), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// Une ligne de l'arbre, la MÊME dans les trois catalogues (22/11/2026, Aristide : « les titres, sous-titres ont
/// TOUS la même présentation, police, couleur de fond » ; « sur chaque niveau un dépliement / repliement avec la
/// MÊME présentation »).
/// - Titre (domaine, rayon, secteur ; domaine, marque ; type, sous-type) : chevron à gauche (› replié, ⌄ déplié),
///   place de l'icône, libellé en gras, compte à droite ; même fond à tous les niveaux, retrait selon la profondeur.
/// - Ligne (produit, produit d'une marque, recette) : fond blanc, alignée sous le libellé de son titre, colonnes.
class RangeeConsole extends StatelessWidget {
  const RangeeConsole({
    super.key,
    required this.profondeur,
    this.titre = true,
    this.ouvert = false,
    this.signe,
    required this.libelle,
    this.compte,
    this.colonnes = const [],
    this.choisie = false,
    this.trouvee = false,
    this.survolee = false,
    this.onTap,
    this.onDoubleTap,
    this.onClicDroit,
  });
  final int profondeur;
  final bool titre, ouvert, choisie, trouvee, survolee;
  final Widget? signe;
  final String libelle;
  final String? compte;
  final List<(String, int)> colonnes;
  final VoidCallback? onTap, onDoubleTap;
  final void Function(Offset)? onClicDroit;

  static const hauteurTitre = 40.0, hauteurLigne = 32.0, retrait = 24.0, placeSigne = 34.0;
  static double hauteurDe({required bool titre}) => titre ? hauteurTitre : hauteurLigne;

  /// Le dessin seul (sans les gestes) : le catalogue des produits l'enveloppe de son glisser-déposer.
  static Widget corps({
    required int profondeur,
    bool titre = true,
    bool ouvert = false,
    Widget? signe,
    required String libelle,
    String? compte,
    List<(String, int)> colonnes = const [],
    bool choisie = false,
    bool trouvee = false,
    bool survolee = false,
    Key? cle,
  }) {
    final fond = survolee
        ? Charte.accent
        : trouvee
            ? Charte.clair(Charte.orange, 0.65)
            : choisie
                ? Charte.fondSelection
                : (titre ? Charte.niveau(2) : Charte.blanc);
    final gauche = 6 + retrait * profondeur;
    final contenu = titre
        ? Row(children: [
            SizedBox(width: gauche),
            Icone(ouvert ? Icons.expand_more : Icons.chevron_right, size: 22, color: Charte.encreNiveau),
            const SizedBox(width: 4),
            SizedBox(width: placeSigne, height: placeSigne, child: Center(child: signe)),
            const SizedBox(width: 8),
            Expanded(child: Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(15, gras: true, couleur: Charte.encreNiveau))),
            if (compte != null) Text(compte, style: Charte.texte(13, couleur: Charte.encreNiveau)),
            const SizedBox(width: 8),
          ])
        : Row(children: [
            SizedBox(width: gauche + 26),
            Expanded(flex: 4, child: Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14.5, gras: choisie))),
            for (final (t, poids) in colonnes)
              Expanded(
                flex: poids,
                child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
              ),
          ]);
    return Container(
      key: cle,
      height: hauteurDe(titre: titre),
      padding: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: fond, border: Border(bottom: BorderSide(color: titre ? Charte.blanc : Charte.separateurLigne))),
      child: contenu,
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: onClicDroit == null ? null : (d) => onClicDroit!(d.globalPosition),
        child: corps(
          profondeur: profondeur,
          titre: titre,
          ouvert: ouvert,
          signe: signe,
          libelle: libelle,
          compte: compte,
          colonnes: colonnes,
          choisie: choisie,
          trouvee: trouvee,
          survolee: survolee,
        ),
      );
}

/// Menu d'un clic droit : (valeur, icône, texte, actif).
Future<String?> menuConsole(BuildContext context, Offset ou, List<EntreeMenuConsole?> entrees) => showMenu<String>(
      context: context,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 440),
      position: RelativeRect.fromLTRB(ou.dx, ou.dy, ou.dx, ou.dy),
      items: [
        for (final e in entrees)
          if (e == null)
            const PopupMenuDivider()
          else
            PopupMenuItem(
              value: e.valeur,
              enabled: e.actif,
              height: 40,
              child: Row(children: [Icone(e.icone, size: 20, color: Charte.cadre), const SizedBox(width: 10), Text(e.texte, style: Charte.texte(15))]),
            ),
      ],
    );
