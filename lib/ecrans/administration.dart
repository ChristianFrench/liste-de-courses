import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/modele.dart';
import '../theme.dart';
import 'administration_serveur.dart';
import 'console_catalogue.dart';
import 'console_marques.dart';
import 'editeur_catalogue.dart';

// Console d'administration d'Emplettes (06/11/2026, Aristide) : application Windows seule, en fenêtre large,
// ouverte par le code d'éditeur (secret GitHub CODE_EDITEUR). Mêmes composants graphiques que l'application.
// À gauche, le menu des fonctions d'administration ; à droite, la fonction choisie :
// - Serveur OVH : initialisation (étapes et état), suivi technique, console shell (administration_serveur.dart) ;
// - Utilisateurs : foyers, appareils et suivi des activités (à venir) ;
// - Contenu : catalogue des produits (à gauche la vue du téléphone, à droite les actions de maintenance),
//   catalogue des marques (console_marques.dart, 08/11/2026) ;
// - Apparence : palette de la console.

enum Rubrique { initialisation, suivi, shell, utilisateurs, produits, marques, apparence }

class _Entree {
  const _Entree(this.rubrique, this.titre, this.icone);
  final Rubrique rubrique;
  final String titre;
  final IconData icone;
}

const _groupes = <(String, List<_Entree>)>[
  ('Serveur OVH', [
    _Entree(Rubrique.initialisation, 'Initialisation', Icons.checklist),
    _Entree(Rubrique.suivi, 'Suivi technique', Icons.monitor_heart_outlined),
    _Entree(Rubrique.shell, 'Console shell', Icons.terminal),
  ]),
  ('Utilisateurs', [_Entree(Rubrique.utilisateurs, 'Foyers et activités', Icons.groups_outlined)]),
  ('Contenu', [
    _Entree(Rubrique.produits, 'Catalogue des produits', Icons.inventory_2_outlined),
    _Entree(Rubrique.marques, 'Catalogue des marques', Icons.sell_outlined),
  ]),
  ('Réglages', [_Entree(Rubrique.apparence, 'Apparence', Icons.palette_outlined)]),
];

class ConsoleAdministration extends StatefulWidget {
  const ConsoleAdministration({super.key, this.depart = Rubrique.produits});
  final Rubrique depart;

  @override
  State<ConsoleAdministration> createState() => _ConsoleAdministrationState();
}

class _ConsoleAdministrationState extends State<ConsoleAdministration> {
  late Rubrique rubrique = widget.depart;

  /// Barre latérale repliée : les icônes seules (07/11/2026, Aristide).
  bool _menuReplie = false;

  /// Commande à taper en ouvrant la console shell (depuis l'initialisation ou le suivi).
  String? _commande;

  void _shell(String commande) => setState(() {
        _commande = commande;
        rubrique = Rubrique.shell;
      });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Charte.fond,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Menu(
            choisie: rubrique,
            replie: _menuReplie,
            onReplier: () => setState(() => _menuReplie = !_menuReplie),
            onChoix: (r) => setState(() {
                  _commande = null;
                  rubrique = r;
                })),
        VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
        Expanded(
          child: switch (rubrique) {
            Rubrique.produits => const PageCatalogueProduits(),
            Rubrique.initialisation => PageInitialisation(ouvrirShell: _shell),
            Rubrique.suivi => PageSuivi(ouvrirShell: _shell),
            Rubrique.shell => PageShell(key: ValueKey(_commande), commande: _commande),
            Rubrique.utilisateurs => const _PageAVenir(
                titre: 'Foyers et activités',
                chemin: 'Utilisateurs',
                texte: 'Le nombre de foyers et d\'appareils, et le suivi de leur activité, sans rien lire de leurs listes : '
                    'les données des foyers sont chiffrées avec leur code.',
                elements: [
                  ('Foyers', 'Nombre de foyers, appareils par foyer', Icons.groups_outlined),
                  ('Activité', 'Connexions du jour, de la semaine, du mois', Icons.show_chart),
                  ('Propositions de catalogue', 'Foyers qui ont déposé des changements', Icons.inventory_2_outlined),
                ],
              ),
            Rubrique.marques => const PageCatalogueMarques(),
            Rubrique.apparence => const _PageApparence(),
          },
        ),
      ]),
    );
  }
}

/// Le menu de gauche : l'image d'Emplettes, puis les fonctions groupées, puis « Verrouiller ».
class _Menu extends StatelessWidget {
  const _Menu({required this.choisie, required this.onChoix, required this.replie, required this.onReplier});
  final Rubrique choisie;
  final ValueChanged<Rubrique> onChoix;

  /// Repliée : 64 points, les icônes seules avec leur nom en bulle (07/11/2026, Aristide).
  final bool replie;
  final VoidCallback onReplier;

  @override
  Widget build(BuildContext context) {
    final bascule = Tooltip(
      message: replie ? 'Déplier le menu' : 'Replier le menu',
      child: IconButton(
        key: const ValueKey('menu-replier'),
        onPressed: onReplier,
        icon: Icone(replie ? Icons.chevron_right : Icons.chevron_left, size: 26, color: Charte.cadre),
      ),
    );
    return Container(
      width: replie ? 64 : 270,
      color: Charte.fondBandeau,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(replie ? 6 : 16, 18, replie ? 6 : 4, 14),
          child: replie
              ? Column(children: [const ImageEmplettes('complet', taille: 40), bascule])
              : Row(children: [
                  const ImageEmplettes('complet', taille: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Emplettes', style: Charte.texte(20, gras: true, couleur: Charte.encreNiveau)),
                      Text('Administration', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                    ]),
                  ),
                  bascule,
                ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final (titre, entrees) in _groupes) ...[
              replie
                  ? Divider(height: 18, indent: 12, endIndent: 12, color: Charte.separateurZone)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(titre.toUpperCase(), style: Charte.texte(12.5, gras: true, couleur: Charte.texteSecondaire)),
                    ),
              for (final e in entrees)
                Tooltip(
                  message: replie ? e.titre : '',
                  child: Material(
                    color: e.rubrique == choisie ? Charte.niveau(1) : Colors.transparent,
                    child: InkWell(
                      key: ValueKey('rubrique-${e.rubrique.name}'),
                      onTap: () => onChoix(e.rubrique),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(replie ? 0 : 20, 9, replie ? 0 : 12, 9),
                        child: replie
                            ? Center(child: Icone(e.icone, size: 24, color: Charte.cadre))
                            : Row(children: [
                                Icone(e.icone, size: 22, color: Charte.cadre),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(e.titre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Charte.texte(15.5, gras: e.rubrique == choisie, couleur: Charte.encre)),
                                ),
                              ]),
                      ),
                    ),
                  ),
                ),
            ],
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(replie ? 8 : 14),
          child: replie
              ? Tooltip(
                  message: 'Verrouiller',
                  child: IconButton(
                    key: const ValueKey('verrouiller'),
                    onPressed: CatalogueCommun.instance.verrouiller,
                    icon: Icone(Icons.lock_outline, size: 24, color: Charte.cadre),
                  ),
                )
              : Bouton(
                  key: const ValueKey('verrouiller'),
                  texte: 'Verrouiller',
                  icone: Icons.lock_outline,
                  onTap: CatalogueCommun.instance.verrouiller,
                ),
        ),
      ]),
    );
  }
}

/// Contenu › Catalogue des produits : l'éditeur du catalogue commun en grand écran ([CatalogueLarge]).
class PageCatalogueProduits extends StatelessWidget {
  const PageCatalogueProduits({super.key});

  @override
  Widget build(BuildContext context) => const EcranEditeurCatalogue(actionsAPart: true, large: true);
}

/// Fonction prévue, pas encore construite : ce qu'elle montrera.
class _PageAVenir extends StatelessWidget {
  const _PageAVenir({required this.titre, required this.chemin, required this.texte, required this.elements});
  final String titre, chemin, texte;
  final List<(String, String, IconData)> elements;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        TitrePageAdmin(chemin, titre),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(texte, style: Charte.texte(16, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (t, d, i) in elements)
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Charte.blanc,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Charte.separateurZone),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icone(i, size: 26, color: Charte.cadre),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t, style: Charte.texte(16, gras: true)),
                        const SizedBox(height: 2),
                        Text(d, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                        const SizedBox(height: 8),
                        Text('À venir', style: Charte.texte(13, gras: true, couleur: Charte.cadre)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ]),
        ),
      ]);
}

/// Réglages › Apparence : la palette de la console (celle de l'application, en partie).
class _PageApparence extends StatelessWidget {
  const _PageApparence();

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        const TitrePageAdmin('Réglages', 'Apparence'),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 420,
              child: ChoixDeroulant<String>(
                key: const ValueKey('palette-console'),
                libelle: 'Palette de la console',
                valeur: Charte.palette.nom,
                choix: {for (final p in toutesLesPalettes) p.nom: p.nom},
                apercus: {for (final p in toutesLesPalettes) p.nom: EchantillonPalette(p)},
                apercuADroite: true,
                onChange: (v) {
                  Etat.instance.choisirApparence(v);
                  Charte.choisirPalette(v);
                },
              ),
            ),
          ),
        ),
      ]);
}

/// Échantillon d'une palette : ses quatre niveaux, du plus foncé au plus clair.
class EchantillonPalette extends StatelessWidget {
  const EchantillonPalette(this.palette, {super.key});
  final Palette palette;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: palette.accent)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final t in Charte.eclaircis) Container(width: 22, height: 22, color: Color.lerp(palette.accentFonce, Charte.blanc, t)),
          ]),
        ),
      );
}
