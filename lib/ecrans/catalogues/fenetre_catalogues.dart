import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../composants/icone.dart' show ImageEmplettes;
import '../../donnees/version.dart';
import '../../theme.dart';
import '../administration.dart' show PageCatalogueProduits;
import '../console_commun.dart' show CommandesConsole;
import '../console_marques.dart' show PageCatalogueMarques;
import '../console_recettes.dart' show PageRecettes;

// « Emplettes · catalogues » (22/11/2026, Aristide) : logiciel Windows de gestion du contenu (produits, marques,
// recettes), séparé de la console technique. Étape 1 = la charpente aux normes Windows : barre de titre (celle de
// Windows), barre de menus, barre d'outils, zone de travail, barre d'état ; écran d'accueil, aide, à propos.
// Les commandes qui ne sont pas encore branchées sont grisées (étapes suivantes : fiche à droite, stockage sur le
// serveur, « Proposer cette version »). Proposition validée : https://claude.ai/artifact/GWNKPRiwChPXr37KuMWKtK

enum CatalogueAffiche { produits, marques, recettes }

extension on CatalogueAffiche {
  String get titre => switch (this) {
        CatalogueAffiche.produits => 'Catalogue des produits',
        CatalogueAffiche.marques => 'Catalogue des marques',
        CatalogueAffiche.recettes => 'Catalogue des recettes',
      };
  String get court => switch (this) {
        CatalogueAffiche.produits => 'Produits',
        CatalogueAffiche.marques => 'Marques',
        CatalogueAffiche.recettes => 'Recettes',
      };
  IconData get icone => switch (this) {
        CatalogueAffiche.produits => Icons.inventory_2_outlined,
        CatalogueAffiche.marques => Icons.sell_outlined,
        CatalogueAffiche.recettes => Icons.menu_book_outlined,
      };
}

const nomLogiciel = 'Emplettes · catalogues';

/// Écran d'accueil (splash) : le nom, la version, pendant un court instant au lancement.
class AccueilCatalogues extends StatelessWidget {
  const AccueilCatalogues({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Charte.niveau(4),
        child: Center(
          child: Container(
            key: const ValueKey('catalogues-accueil'),
            width: 520,
            padding: const EdgeInsets.fromLTRB(36, 36, 36, 30),
            decoration: BoxDecoration(color: Charte.blanc, borderRadius: BorderRadius.circular(14), border: Border.all(color: Charte.separateurZone)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ImageEmplettes('complet', taille: 96),
              const SizedBox(height: 18),
              Text('Emplettes', style: Charte.texte(30, gras: true, couleur: Charte.encreNiveau)),
              Text('Gestion des catalogues', style: Charte.texte(18, couleur: Charte.texteSecondaire)),
              const SizedBox(height: 24),
              const SizedBox(width: 220, child: LinearProgressIndicator()),
              const SizedBox(height: 18),
              Text('Version $versionApplication', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ]),
          ),
        ),
      );
}

/// La fenêtre principale.
class FenetreCatalogues extends StatefulWidget {
  const FenetreCatalogues({super.key});

  @override
  State<FenetreCatalogues> createState() => _FenetreCataloguesState();
}

class _FenetreCataloguesState extends State<FenetreCatalogues> {
  CatalogueAffiche catalogue = CatalogueAffiche.produits;
  bool barreOutils = true, barreEtat = true;
  String message = 'Prêt';

  static const _fenetre = MethodChannel('emplettes/fenetre');

  @override
  void initState() {
    super.initState();
    // Largeur minimum de la fenêtre Windows (même canal que la console, voir outils/fenetre_editeur.py).
    _fenetre.invokeMethod<void>('largeurMinimum', 960).catchError((_) {});
  }

  void _afficher(CatalogueAffiche c) => setState(() {
        catalogue = c;
        message = '${c.titre} affiché';
      });

  void _deplier() {
    CommandesConsole.deplier?.call();
    setState(() => message = 'Tout déplié');
  }

  void _replier() {
    CommandesConsole.replier?.call();
    setState(() => message = 'Tout replié');
  }

  void _rechercher() => CommandesConsole.recherche.requestFocus();

  Map<ShortcutActivator, VoidCallback> get _raccourcis => {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _afficher(CatalogueAffiche.produits),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _afficher(CatalogueAffiche.marques),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _afficher(CatalogueAffiche.recettes),
        const SingleActivator(LogicalKeyboardKey.numpad1, control: true): () => _afficher(CatalogueAffiche.produits),
        const SingleActivator(LogicalKeyboardKey.numpad2, control: true): () => _afficher(CatalogueAffiche.marques),
        const SingleActivator(LogicalKeyboardKey.numpad3, control: true): () => _afficher(CatalogueAffiche.recettes),
        const SingleActivator(LogicalKeyboardKey.add, control: true): _deplier,
        const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): _deplier,
        const SingleActivator(LogicalKeyboardKey.minus, control: true): _replier,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): _replier,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _rechercher,
        const SingleActivator(LogicalKeyboardKey.f1): () => montrerAide(context),
      };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _raccourcis,
      child: Focus(
        autofocus: true,
        child: Material(
          color: Charte.fond,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _barreMenus(),
            if (barreOutils) _barreOutils(),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(catalogue),
                child: switch (catalogue) {
                  CatalogueAffiche.produits => const PageCatalogueProduits(),
                  CatalogueAffiche.marques => const PageCatalogueMarques(),
                  CatalogueAffiche.recettes => const PageRecettes(),
                },
              ),
            ),
            if (barreEtat) _barreEtat(),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- barre de menus

  Widget _barreMenus() {
    final style = Charte.texte(14);
    MenuItemButton item(String texte, {VoidCallback? onTap, MenuSerializableShortcut? raccourci, Key? cle, IconData? icone, bool coche = false}) =>
        MenuItemButton(
          key: cle,
          onPressed: onTap,
          shortcut: raccourci,
          leadingIcon: SizedBox(width: 20, child: coche ? const Icon(Icons.check, size: 18) : (icone == null ? null : Icon(icone, size: 18))),
          child: Padding(padding: const EdgeInsets.only(right: 24), child: Text(texte, style: style)),
        );
    Widget menu(String accelerateur, List<Widget> enfants, {Key? cle}) => SubmenuButton(
          key: cle,
          menuChildren: enfants,
          child: MenuAcceleratorLabel(accelerateur, builder: (context, label, index) {
            return Text.rich(TextSpan(style: style, children: [
              if (index > 0) TextSpan(text: label.substring(0, index)),
              if (index >= 0) TextSpan(text: label[index], style: const TextStyle(decoration: TextDecoration.underline)),
              TextSpan(text: index >= 0 ? label.substring(index + 1) : label),
            ]));
          }),
        );
    const trait = Divider(height: 9);
    return Container(
      decoration: BoxDecoration(color: Charte.blanc, border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
      child: Row(children: [
        Expanded(
          child: MenuBar(
            style: const MenuStyle(
              elevation: WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
            ),
            children: [
              menu('&Fichier', cle: const ValueKey('menu-fichier'), [
                item('Enregistrer sur le serveur', raccourci: const SingleActivator(LogicalKeyboardKey.keyS, control: true), icone: Icons.save_outlined),
                item('Recharger depuis le serveur', icone: Icons.cloud_download_outlined),
                trait,
                item('Importer…', raccourci: const SingleActivator(LogicalKeyboardKey.keyI, control: true)),
                item('Exporter…', raccourci: const SingleActivator(LogicalKeyboardKey.keyE, control: true)),
                trait,
                item('Quitter', cle: const ValueKey('menu-quitter'), raccourci: const SingleActivator(LogicalKeyboardKey.f4, alt: true), onTap: () => exit(0)),
              ]),
              menu('&Édition', cle: const ValueKey('menu-edition'), [
                item('Annuler', raccourci: const SingleActivator(LogicalKeyboardKey.keyZ, control: true), icone: Icons.undo),
                item('Rétablir', raccourci: const SingleActivator(LogicalKeyboardKey.keyY, control: true), icone: Icons.redo),
                trait,
                item('Couper', raccourci: const SingleActivator(LogicalKeyboardKey.keyX, control: true)),
                item('Copier', raccourci: const SingleActivator(LogicalKeyboardKey.keyC, control: true)),
                item('Coller', raccourci: const SingleActivator(LogicalKeyboardKey.keyV, control: true)),
                trait,
                item('Renommer', raccourci: const SingleActivator(LogicalKeyboardKey.f2)),
                item('Supprimer', raccourci: const SingleActivator(LogicalKeyboardKey.delete)),
                trait,
                item('Rechercher', cle: const ValueKey('menu-rechercher'), raccourci: const SingleActivator(LogicalKeyboardKey.keyF, control: true), icone: Icons.search, onTap: _rechercher),
              ]),
              menu('&Affichage', cle: const ValueKey('menu-affichage'), [
                for (final c in CatalogueAffiche.values)
                  item(c.titre,
                      cle: ValueKey('menu-${c.name}'),
                      coche: catalogue == c,
                      raccourci: SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + c.index), control: true),
                      onTap: () => _afficher(c)),
                trait,
                item('Tout déplier', cle: const ValueKey('menu-deplier'), raccourci: const SingleActivator(LogicalKeyboardKey.add, control: true), icone: Icons.keyboard_double_arrow_down, onTap: _deplier),
                item('Tout replier', cle: const ValueKey('menu-replier'), raccourci: const SingleActivator(LogicalKeyboardKey.minus, control: true), icone: Icons.keyboard_double_arrow_up, onTap: _replier),
                trait,
                item("Barre d'outils", cle: const ValueKey('menu-barre-outils'), coche: barreOutils, onTap: () => setState(() => barreOutils = !barreOutils)),
                item("Barre d'état", cle: const ValueKey('menu-barre-etat'), coche: barreEtat, onTap: () => setState(() => barreEtat = !barreEtat)),
                trait,
                item('Actualiser', raccourci: const SingleActivator(LogicalKeyboardKey.f5)),
              ]),
              menu('&Insertion', cle: const ValueKey('menu-insertion'), [
                item('Nouveau', raccourci: const SingleActivator(LogicalKeyboardKey.keyN, control: true), icone: Icons.add),
                item('Illustration ou icône…', icone: Icons.image_outlined),
              ]),
              menu('&Version', cle: const ValueKey('menu-version'), [
                item('Contrôler le catalogue', raccourci: const SingleActivator(LogicalKeyboardKey.f7), icone: Icons.fact_check_outlined),
                item('Valider les modifications', raccourci: const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true), icone: Icons.task_alt),
                item('Historique des étapes', icone: Icons.history),
                trait,
                item('Proposer cette version', icone: Icons.outbox_outlined),
                item('État des versions'),
              ]),
              menu('&Outils', cle: const ValueKey('menu-outils'), [
                item('Iconographie'),
                item('Propositions des foyers'),
                trait,
                item('Options…', icone: Icons.settings_outlined),
              ]),
              menu('&?', cle: const ValueKey('menu-aide'), [
                item('Aide', cle: const ValueKey('menu-aide-f1'), raccourci: const SingleActivator(LogicalKeyboardKey.f1), icone: Icons.help_outline, onTap: () => montrerAide(context)),
                item('Raccourcis clavier', cle: const ValueKey('menu-raccourcis'), icone: Icons.keyboard_outlined, onTap: () => montrerRaccourcis(context)),
                trait,
                item('À propos', cle: const ValueKey('menu-a-propos'), onTap: () => montrerAPropos(context)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- barre d'outils

  Widget _barreOutils() {
    Widget outil(IconData icone, String bulle, {VoidCallback? onTap, Key? cle}) => Tooltip(
          message: bulle,
          child: IconButton(
            key: cle,
            onPressed: onTap,
            icon: Icon(icone, size: 22),
            color: Charte.encreNiveau,
            visualDensity: VisualDensity.compact,
          ),
        );
    Widget trait() => Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: Charte.separateurZone);
    Widget bascule(CatalogueAffiche c) {
      final actif = catalogue == c;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: '${c.titre} (Ctrl+${c.index + 1})',
          child: OutlinedButton.icon(
            key: ValueKey('outil-${c.name}'),
            onPressed: () => _afficher(c),
            icon: Icon(c.icone, size: 18),
            label: Text(c.court, style: Charte.texte(14, gras: actif)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Charte.encreNiveau,
              backgroundColor: actif ? Charte.clair(Charte.accent, 0.55) : Charte.blanc,
              side: BorderSide(color: actif ? Charte.cadre : Charte.separateurZone, width: actif ? 1.5 : 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('barre-outils'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(color: Charte.blanc, border: Border(bottom: BorderSide(color: Charte.separateurZone))),
      child: Row(children: [
        outil(Icons.save_outlined, 'Enregistrer sur le serveur (Ctrl+S) : à venir'),
        outil(Icons.cloud_download_outlined, 'Recharger depuis le serveur : à venir'),
        trait(),
        outil(Icons.undo, 'Annuler (Ctrl+Z) : à venir'),
        outil(Icons.redo, 'Rétablir (Ctrl+Y) : à venir'),
        trait(),
        for (final c in CatalogueAffiche.values) bascule(c),
        trait(),
        outil(Icons.keyboard_double_arrow_down, 'Tout déplier (Ctrl+Plus)', onTap: _deplier, cle: const ValueKey('outil-deplier')),
        outil(Icons.keyboard_double_arrow_up, 'Tout replier (Ctrl+Moins)', onTap: _replier, cle: const ValueKey('outil-replier')),
        trait(),
        outil(Icons.search, 'Rechercher (Ctrl+F)', onTap: _rechercher, cle: const ValueKey('outil-rechercher')),
        trait(),
        outil(Icons.fact_check_outlined, 'Contrôler le catalogue (F7) : à venir'),
        outil(Icons.outbox_outlined, 'Proposer cette version : à venir'),
        const Spacer(),
        outil(Icons.help_outline, 'Aide (F1)', onTap: () => montrerAide(context), cle: const ValueKey('outil-aide')),
      ]),
    );
  }

  // ---------------------------------------------------------------- barre d'état

  Widget _barreEtat() {
    final style = Charte.texte(12.5, couleur: Charte.encreNiveau);
    Widget caseEtat(Widget enfant, {bool extensible = false}) {
      final c = Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: enfant);
      return extensible ? Expanded(child: c) : c;
    }

    Widget trait() => Container(width: 1, height: 16, color: Charte.separateurZone);
    return Container(
      key: const ValueKey('barre-etat'),
      height: 26,
      decoration: BoxDecoration(color: Charte.niveau(2), border: Border(top: BorderSide(color: Charte.separateurZone))),
      child: Row(children: [
        caseEtat(Text(message, key: const ValueKey('etat-message'), style: style, overflow: TextOverflow.ellipsis), extensible: true),
        trait(),
        caseEtat(Text(catalogue.titre, key: const ValueKey('etat-catalogue'), style: style)),
        trait(),
        caseEtat(Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 10, color: Charte.texteSecondaire),
          const SizedBox(width: 6),
          Text('Données sur ce PC (serveur : à venir)', style: style),
        ])),
        trait(),
        caseEtat(Text('Version $versionApplication', key: const ValueKey('etat-version'), style: style)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- aide, raccourcis, à propos

Future<void> _fenetreTexte(BuildContext context, String titre, List<Widget> contenu, {Key? cle}) => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        key: cle,
        backgroundColor: Charte.blanc,
        child: SizedBox(
          width: 720,
          height: 620,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: Charte.fondBandeau,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Text(titre, style: Charte.texte(20, gras: true, couleur: Charte.encreNiveau)),
            ),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 14), children: contenu)),
            Container(height: 1, color: Charte.separateurZone),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const ValueKey('aide-fermer'), onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
              ),
            ),
          ]),
        ),
      ),
    );

Widget _section(String titre) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(titre, style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
    );

Widget _para(String texte) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(texte, style: Charte.texte(14.5)));

/// Aide (F1).
Future<void> montrerAide(BuildContext context) => _fenetreTexte(context, 'Aide', cle: const ValueKey('fenetre-aide'), [
      _para('$nomLogiciel sert à tenir à jour le contenu commun à tous les foyers : les produits (domaines, rayons, '
          'secteurs, produits), les marques et les recettes.'),
      _section('La fenêtre'),
      _para('En haut, la barre de menus et la barre d\'outils ; au milieu, le catalogue affiché ; en bas, la barre d\'état '
          '(dernière action, catalogue affiché, emplacement des données, version du logiciel).'),
      _para('Les commandes grisées seront branchées dans les prochaines versions (fiche à droite, enregistrement sur le '
          'serveur, proposition d\'une version).'),
      _section('Changer de catalogue'),
      _para('Menu Affichage, boutons Produits, Marques, Recettes de la barre d\'outils, ou Ctrl+1, Ctrl+2, Ctrl+3.'),
      _section('Parcourir'),
      _para('Chaque titre de la hiérarchie se déplie ou se replie d\'un clic sur sa ligne. Tout déplier (Ctrl+Plus) et '
          'Tout replier (Ctrl+Moins) agissent sur toute la hiérarchie.'),
      _para('Rechercher (Ctrl+F) : la recherche est stricte ; Entrée ou les flèches passent au résultat suivant ou précédent.'),
      _section('Modifier'),
      _para('Clic : choisir ou voir. Double-clic : modifier. Clic droit : le menu des gestes de l\'élément. Glisser-déposer : '
          'déplacer un produit, un secteur ou un rayon.'),
      _para('Chaque geste est noté dans le journal. « Valider les modifications » en fait une étape nommée, à laquelle on '
          'peut revenir depuis l\'historique.'),
      _section('Versions'),
      _para('Ce logiciel prépare une version du catalogue. La généralisation à tous les foyers appartient à la console technique.'),
    ]);

/// Raccourcis clavier.
Future<void> montrerRaccourcis(BuildContext context) {
  const lignes = [
    ('Ctrl+1, Ctrl+2, Ctrl+3', 'Produits, Marques, Recettes'),
    ('Ctrl+Plus, Ctrl+Moins', 'Tout déplier, Tout replier'),
    ('Ctrl+F', 'Rechercher'),
    ('Entrée', 'Résultat suivant (dans la recherche)'),
    ('F1', 'Aide'),
    ('Alt', 'Barre de menus ; Alt + lettre soulignée ouvre un menu'),
    ('Échap', 'Fermer une fenêtre, annuler la saisie'),
    ('Alt+F4', 'Quitter'),
    ('Ctrl+S, Ctrl+Z, Ctrl+Y, F2, Suppr, Ctrl+N, F7', 'À venir'),
  ];
  return _fenetreTexte(context, 'Raccourcis clavier', cle: const ValueKey('fenetre-raccourcis'), [
    for (final (touche, effet) in lignes)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
        child: Row(children: [
          SizedBox(width: 300, child: Text(touche, style: Charte.texte(14.5, gras: true, couleur: Charte.encreNiveau))),
          Expanded(child: Text(effet, style: Charte.texte(14.5))),
        ]),
      ),
  ]);
}

/// À propos.
Future<void> montrerAPropos(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('fenetre-a-propos'),
        backgroundColor: Charte.blanc,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const ImageEmplettes('complet', taille: 72),
          const SizedBox(height: 12),
          Text(nomLogiciel, style: Charte.texte(20, gras: true, couleur: Charte.encreNiveau)),
          const SizedBox(height: 4),
          Text('Gestion des catalogues d\'Emplettes', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 12),
          Text('Version $versionApplication', style: Charte.texte(14)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))],
      ),
    );
