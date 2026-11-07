import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/modele.dart';
import '../theme.dart';
import 'administration_serveur.dart';
import 'console_catalogue.dart';
import 'editeur_catalogue.dart';

// Console d'administration d'Emplettes (06/11/2026, Aristide) : application Windows seule, en fenêtre large,
// ouverte par le code d'éditeur (secret GitHub CODE_EDITEUR). Mêmes composants graphiques que l'application.
// À gauche, le menu des fonctions d'administration ; à droite, la fonction choisie :
// - Serveur OVH : initialisation (étapes et état), suivi technique, console shell (administration_serveur.dart) ;
// - Utilisateurs : foyers, appareils et suivi des activités (à venir) ;
// - Contenu : catalogue des produits (à gauche la vue du téléphone, à droite les actions de maintenance),
//   catalogue des marques (à venir) ;
// - Apparence : palette de la console.

enum Rubrique { initialisation, suivi, shell, utilisateurs, produits, iconographie, marques, apparence }

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
    _Entree(Rubrique.iconographie, 'Iconographie', Icons.image_outlined),
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
            onChoix: (r) => setState(() {
                  _commande = null;
                  rubrique = r;
                })),
        VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
        Expanded(
          child: switch (rubrique) {
            Rubrique.produits || Rubrique.iconographie => PageCatalogueProduits(
                mode: rubrique == Rubrique.iconographie ? ModeCatalogue.iconographie : ModeCatalogue.produits,
                onMode: (m) => setState(() => rubrique = m == ModeCatalogue.iconographie ? Rubrique.iconographie : Rubrique.produits),
              ),
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
            Rubrique.marques => const _PageAVenir(
                titre: 'Catalogue des marques',
                chemin: 'Contenu',
                texte: 'Même disposition que le catalogue des produits : la vue du téléphone à gauche, les actions de '
                    'maintenance des marques à droite.',
                elements: [
                  ('Marques par secteur', 'Ajouter, renommer, fusionner les doublons', Icons.sell_outlined),
                  ('Marques des distributeurs', 'Enseignes et leurs marques propres', Icons.storefront_outlined),
                ],
              ),
            Rubrique.apparence => const _PageApparence(),
          },
        ),
      ]),
    );
  }
}

/// Le menu de gauche : l'image d'Emplettes, puis les fonctions groupées, puis « Verrouiller ».
class _Menu extends StatelessWidget {
  const _Menu({required this.choisie, required this.onChoix});
  final Rubrique choisie;
  final ValueChanged<Rubrique> onChoix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: Charte.fondBandeau,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Row(children: [
            const ImageEmplettes('complet', taille: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Emplettes', style: Charte.texte(20, gras: true, couleur: Charte.encreNiveau)),
                Text('Administration', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final (titre, entrees) in _groupes) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(titre.toUpperCase(), style: Charte.texte(12.5, gras: true, couleur: Charte.texteSecondaire)),
              ),
              for (final e in entrees)
                Material(
                  color: e.rubrique == choisie ? Charte.niveau(1) : Colors.transparent,
                  child: InkWell(
                    key: ValueKey('rubrique-${e.rubrique.name}'),
                    onTap: () => onChoix(e.rubrique),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 9, 12, 9),
                      child: Row(children: [
                        Icone(e.icone, size: 22, color: Charte.cadre),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.titre,
                              style: Charte.texte(15.5, gras: e.rubrique == choisie, couleur: Charte.encre)),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Bouton(
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

/// Contenu › Catalogue des produits : à gauche la vue du téléphone (l'écran de l'éditeur, tel qu'il se
/// présente sur un téléphone), à droite les actions de maintenance et ce qui changera à la généralisation.
class PageCatalogueProduits extends StatefulWidget {
  const PageCatalogueProduits({super.key, this.mode = ModeCatalogue.produits, this.onMode});
  final ModeCatalogue mode;
  final ValueChanged<ModeCatalogue>? onMode;

  @override
  State<PageCatalogueProduits> createState() => _PageCatalogueProduitsState();
}

class _PageCatalogueProduitsState extends State<PageCatalogueProduits> {
  final _editeur = GlobalKey<EtatEditeurCatalogue>();

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 07/11/2026 (Aristide) : la console n'imite plus le téléphone ; le catalogue prend la largeur du PC.
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: EcranEditeurCatalogue(
          key: _editeur,
          auChangement: _rafraichir,
          actionsAPart: true,
          large: true,
          mode: widget.mode,
          versIconographie: () => widget.onMode?.call(ModeCatalogue.iconographie),
        ),
      ),
      VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
      SizedBox(width: 300, child: _Maintenance(editeur: _editeur, mode: widget.mode, onMode: widget.onMode)),
    ]);
  }
}

/// Panneau de droite du catalogue des produits : état du brouillon, actions, changements à généraliser.
class _Maintenance extends StatelessWidget {
  const _Maintenance({required this.editeur, required this.mode, this.onMode});
  final GlobalKey<EtatEditeurCatalogue> editeur;
  final ModeCatalogue mode;
  final ValueChanged<ModeCatalogue>? onMode;

  @override
  Widget build(BuildContext context) {
    final e = editeur.currentState;
    final b = e?.b;
    final recap = e?.recapitulatif;
    final numero = e?.numeroPublie ?? 0;
    Widget action(String cle, IconData icone, String texte, String detail, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Carte(
            key: ValueKey('maintenance-$cle'),
            onTap: onTap,
            child: Row(children: [
              Icone(icone, size: 26, color: Charte.cadre),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(texte, style: Charte.texte(16, gras: true)),
                  Text(detail, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ]),
              ),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      TitrePageAdmin('Contenu', mode == ModeCatalogue.iconographie ? 'Iconographie' : 'Catalogue des produits'),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (b != null)
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Chiffre('Version publiée', numero == 0 ? 'aucune' : 'v$numero'),
              _Chiffre('Rayons', '${b.catalogue.rayons.length}'),
              _Chiffre('Secteurs', '${b.catalogue.rayons.fold(0, (n, r) => n + r.secteurs.length)}'),
              _Chiffre('Produits', '${b.nbProduits}'),
              _Chiffre('À généraliser', b.modifications == 0 ? 'rien' : '${b.modifications}'),
            ]),
          const SizedBox(height: 22),
          Text('Maintenance', style: Charte.texte(18, gras: true, couleur: Charte.encreNiveau)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final colonnes = c.maxWidth > 700 ? 2 : 1;
            final cartes = [
              action('repartir', Icons.restore, 'Repartir d\'un catalogue', 'Une version gardée ou la proposition d\'un foyer',
                  e == null ? null : e.repartir),
              action('rayon', Icons.add, 'Nouveau rayon', 'Les secteurs s\'ajoutent depuis le rayon, à gauche',
                  e == null ? null : e.nouveauRayon),
              action('texte', Icons.notes, 'Ajouter depuis un texte', 'Rayons, secteurs et produits collés d\'un texte',
                  e == null ? null : e.depuisTexte),
              action('cle', Icons.key_outlined, 'Clé de signature', 'La clé publique qui authentifie vos versions',
                  e == null ? null : e.cleSignature),
              // 07/11/2026 (Aristide) : valider (point de sauvegarde) est distinct de généraliser.
              action('valider', Icons.check, 'Valider les modifications',
                  e == null || e.enCours == 0 ? 'Rien en cours' : '${e.enCours} en cours : elles deviennent une étape de l\'historique',
                  e == null || e.enCours == 0 ? null : e.valider),
              if (b != null)
                mode == ModeCatalogue.produits
                    ? action('iconographie', Icons.image_outlined, 'Iconographie',
                        '${sansIcone(b)} sans icône : propositions et bibliothèque Noto 3D', () => onMode?.call(ModeCatalogue.iconographie))
                    : action('produits', Icons.inventory_2_outlined, 'Produits', 'Revenir aux produits des secteurs',
                        () => onMode?.call(ModeCatalogue.produits)),
              action('historique', Icons.history, 'Historique', 'Les étapes validées ; revenir à l\'une d\'elles',
                  e == null ? null : e.historique),
            ];
            final largeur = (c.maxWidth - (colonnes - 1) * 10) / colonnes;
            return Wrap(spacing: 10, children: [for (final w in cartes) SizedBox(width: largeur, child: w)]);
          }),
          const SizedBox(height: 14),
          Text('À généraliser', style: Charte.texte(18, gras: true, couleur: Charte.encreNiveau)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Charte.blanc,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Charte.separateurZone),
            ),
            child: recap == null || recap.vide
                ? Text(
                    (b?.modifications ?? 0) == 0
                        ? 'Rien n\'a changé depuis la version publiée.'
                        // 06/11/2026 : des modifications sans ajout, retrait ni déplacement (ordre, images, noms…)
                        // laissaient croire qu'il n'y avait rien à généraliser.
                        : '${b!.modifications} modification${b.modifications > 1 ? 's' : ''} : ordre, images ou noms corrigés, '
                            'sans rayon, secteur ni produit ajouté, retiré ou déplacé.',
                    style: Charte.texte(15, couleur: Charte.texteSecondaire))
                : RecapitulatifVue(recap),
          ),
          if (e?.absenteDuServeur == true) ...[
            const SizedBox(height: 14),
            Text(
                'La version v$numero n\'est pas sur le serveur (publiée avant le passage au serveur OVH) : '
                'les foyers ne la reçoivent pas. Renvoyez-la.',
                style: Charte.texte(15, gras: true, couleur: Charte.rouge)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 320,
                child: Bouton(
                  key: const ValueKey('renvoyer'),
                  texte: e!.enPublication ? 'Envoi…' : 'Renvoyer v$numero au serveur',
                  icone: Icons.cloud_upload_outlined,
                  plein: true,
                  hauteur: 46,
                  onTap: e.enPublication ? null : e.renvoyer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 320,
              child: Bouton(
                key: const ValueKey('generaliser'),
                texte: e?.enPublication == true ? 'Envoi…' : 'Généraliser (v${numero + 1})',
                icone: Icons.public,
                plein: true,
                hauteur: 46,
                onTap: e == null || e.enPublication || (b?.modifications ?? 0) == 0 || e.enCours > 0 ? null : e.generaliser,
              ),
            ),
          ),
          if ((e?.enCours ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text('${e!.enCours} modification${e.enCours > 1 ? 's' : ''} en cours : validez-les avant de généraliser.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ],
        ]),
      ),
    ]);
  }
}

/// Un chiffre clé dans une petite case : le nombre en gros, son libellé en dessous.
class _Chiffre extends StatelessWidget {
  const _Chiffre(this.libelle, this.valeur);
  final String libelle, valeur;

  @override
  Widget build(BuildContext context) => Container(
        width: 124,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: Charte.niveau(3), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valeur, style: Charte.texte(24, gras: true, couleur: Charte.encreNiveau)),
          Text(libelle, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
        ]),
      );
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
