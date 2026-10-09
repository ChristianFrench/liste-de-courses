import 'package:flutter/material.dart';

import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

// Composants réutilisables (spécification IHM, chapitre 5).

const _bordCadre = BorderSide(color: Charte.encre, width: Charte.traitCadre);
const _bordLigne = BorderSide(color: Charte.separateurLigne, width: Charte.traitSeparateur);
const _bordZone = BorderSide(color: Charte.separateurZone, width: Charte.traitSeparateur);

/// Squelette commun à tous les écrans : en-tête, contenu, puis éléments du bas.
class PageBase extends StatelessWidget {
  const PageBase({super.key, required this.entete, required this.corps, this.haut = const [], this.bas = const []});
  final Widget entete;
  final List<Widget> haut;
  final Widget corps;
  final List<Widget> bas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Charte.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [entete, ...haut, Expanded(child: corps), ...bas],
        ),
      ),
    );
  }
}

class BoutonIcone extends StatelessWidget {
  const BoutonIcone({super.key, required this.icone, required this.onTap, required this.libelle, this.taille = 26});
  final IconData icone;
  final VoidCallback? onTap;
  final String libelle;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: libelle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(width: 44, height: 44, child: Icon(icone, size: taille, color: Charte.encre)),
      ),
    );
  }
}

/// En-tête des écrans de travail (48 points).
class EnTeteTravail extends StatelessWidget {
  const EnTeteTravail({super.key, required this.titre, this.gauche, this.action});
  final String titre;
  final Widget? gauche;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.enTeteTravail,
      decoration: const BoxDecoration(border: Border(bottom: _bordCadre)),
      child: Row(
        children: [
          const SizedBox(width: 2),
          gauche ??
              BoutonIcone(
                icone: Icons.chevron_left,
                taille: 32,
                libelle: 'Retour',
                onTap: () => Navigator.of(context).maybePop(),
              ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(titre, style: Charte.titreEcran, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (action != null) action!,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// En-tête des écrans de gestion (60 points).
class EnTeteGestion extends StatelessWidget {
  const EnTeteGestion({super.key, required this.titre, this.retour = true, this.gauche, this.action, this.onTitre});
  final String titre;
  final bool retour;
  final Widget? gauche;
  final Widget? action;
  final VoidCallback? onTitre;

  @override
  Widget build(BuildContext context) {
    final texte = Text(titre, style: Charte.texte(19, gras: true), maxLines: 1, overflow: TextOverflow.ellipsis);
    return Container(
      height: Charte.enTeteGestion,
      decoration: const BoxDecoration(border: Border(bottom: _bordCadre)),
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          if (gauche != null) ...[const SizedBox(width: 12), gauche!, const SizedBox(width: 10)],
          if (gauche == null && retour)
            BoutonIcone(
              icone: Icons.chevron_left,
              taille: 32,
              libelle: 'Retour',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          if (gauche == null && !retour) const SizedBox(width: 16),
          Expanded(
            child: onTitre == null
                ? texte
                : InkWell(
                    onTap: onTitre,
                    child: SizedBox(height: 44, child: Align(alignment: Alignment.centerLeft, child: texte)),
                  ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Puces

class Puce {
  const Puce(this.libelle, {this.compteur, this.termine = false, this.icone});
  final String libelle;
  final int? compteur;
  final bool termine;
  final IconData? icone;
}

/// Liste horizontale défilante de puces ; la puce sélectionnée reste visible.
class BandeauPuces extends StatefulWidget {
  const BandeauPuces({
    super.key,
    required this.puces,
    required this.selection,
    required this.onChoix,
    this.fond = Charte.fond,
    this.pastille = true,
  });
  final List<Puce> puces;
  final int selection;
  final ValueChanged<int> onChoix;
  final Color fond;

  /// Puces en pastille (rayons) ou rectangulaires arrondies (secteurs, étapes).
  final bool pastille;

  @override
  State<BandeauPuces> createState() => _BandeauPucesState();
}

class _BandeauPucesState extends State<BandeauPuces> {
  final List<GlobalKey> _cles = [];

  void _preparerCles() {
    while (_cles.length < widget.puces.length) {
      _cles.add(GlobalKey());
    }
  }

  void _montrerSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.selection < 0 || widget.selection >= _cles.length) return;
      final ctx = _cles[widget.selection].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 200));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _preparerCles();
    _montrerSelection();
  }

  @override
  void didUpdateWidget(covariant BandeauPuces ancien) {
    super.didUpdateWidget(ancien);
    _preparerCles();
    if (ancien.selection != widget.selection) _montrerSelection();
  }

  @override
  Widget build(BuildContext context) {
    final rayon = widget.pastille ? 18.0 : 8.0;
    return Container(
      height: Charte.bandeauPuces,
      decoration: BoxDecoration(color: widget.fond, border: const Border(bottom: _bordZone)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (var i = 0; i < widget.puces.length; i++)
              _puce(widget.puces[i], i == widget.selection, rayon, () => widget.onChoix(i), _cles[i]),
          ],
        ),
      ),
    );
  }

  Widget _puce(Puce p, bool choisie, double rayon, VoidCallback onTap, Key cle) {
    final couleurTexte = choisie ? Charte.fond : (p.termine ? Charte.texteBarre : Charte.encre);
    final bord = p.termine && !choisie ? const Color(0xFF999999) : Charte.encre;
    return GestureDetector(
      key: cle,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: choisie,
        label: p.libelle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: choisie ? Charte.encre : Charte.fond,
              borderRadius: BorderRadius.circular(rayon),
              border: Border.all(color: bord, width: Charte.traitCadre),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.icone != null) ...[
                  Icon(p.icone, size: 16, color: couleurTexte),
                  const SizedBox(width: 4),
                ],
                Text(p.libelle, style: Charte.texte(15, gras: choisie, couleur: couleurTexte)),
                if (p.termine && !choisie) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check, size: 15, color: couleurTexte),
                ],
                if (p.compteur != null && p.compteur! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: couleurTexte, width: 1.5),
                    ),
                    child: Text('${p.compteur}', style: Charte.texte(11, gras: true, couleur: couleurTexte)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Lignes

class CaseACocher extends StatelessWidget {
  const CaseACocher({super.key, required this.coche, this.taille = 22});
  final bool coche;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: coche ? Charte.encre : Charte.fond,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Charte.encre, width: Charte.traitCadre),
      ),
      child: coche ? Icon(Icons.check, size: taille - 4, color: Charte.fond) : null,
    );
  }
}

class IconePromo extends StatelessWidget {
  const IconePromo({super.key, required this.type, this.inverse = false});
  final TypePromo type;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final couleur = inverse ? Charte.fond : Charte.encre;
    return Semantics(
      label: 'Promotion ${type.nom}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: couleur, width: 1.5),
        ),
        child: Text(type.code, style: Charte.texte(10, gras: true, couleur: couleur)),
      ),
    );
  }
}

class AlerteQuantite extends StatelessWidget {
  const AlerteQuantite({super.key, required this.requise});
  final int requise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Charte.fond,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Charte.encre, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: Charte.encre),
          const SizedBox(width: 3),
          Text('Il en faut $requise', style: Charte.texte(11, gras: true)),
        ],
      ),
    );
  }
}

class SelecteurQuantite extends StatelessWidget {
  const SelecteurQuantite({super.key, required this.quantite, required this.onChange});
  final int quantite;
  final ValueChanged<int> onChange;

  Widget _bouton(String signe, int valeur, String libelle) => Semantics(
        button: true,
        label: libelle,
        child: InkWell(
          onTap: () => onChange(valeur),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(child: Text(signe, style: Charte.texte(18, gras: true))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Charte.fond,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Charte.encre, width: Charte.traitCadre),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bouton('−', quantite - 1, 'Diminuer'),
          SizedBox(
            width: 24,
            child: Text('$quantite', textAlign: TextAlign.center, style: Charte.texte(16, gras: true)),
          ),
          _bouton('+', quantite + 1, 'Augmenter'),
        ],
      ),
    );
  }
}

/// Ligne produit pendant la construction (44 points).
class LigneChoix extends StatelessWidget {
  const LigneChoix({
    super.key,
    required this.nom,
    required this.complement,
    required this.coche,
    required this.quantite,
    required this.onTap,
    required this.onQuantite,
    this.promo,
    this.habituel = false,
    this.alerte,
  });
  final String nom;
  final String complement;
  final bool coche;
  final int quantite;
  final TypePromo? promo;
  final bool habituel;
  final int? alerte;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: coche ? Charte.fondSelection : Charte.fond,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Charte.ligneConstruction),
          decoration: const BoxDecoration(border: Border(bottom: _bordLigne)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              CaseACocher(coche: coche),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: nom, style: Charte.texte(15, gras: coche)),
                          if (complement.isNotEmpty) TextSpan(text: ' · $complement', style: Charte.secondaire),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (alerte != null) AlerteQuantite(requise: alerte!),
                    ],
                  ),
                ),
              ),
              if (promo != null) ...[const SizedBox(width: 4), IconePromo(type: promo!)],
              const SizedBox(width: 6),
              if (coche)
                SelecteurQuantite(quantite: quantite, onChange: onQuantite)
              else if (habituel)
                const Tooltip(
                  message: 'Acheté habituellement',
                  child: Icon(Icons.history, size: 19, color: Charte.texteSecondaire),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne produit pendant les courses (56 points) : cochée = barrée et grisée.
class LigneCourse extends StatelessWidget {
  const LigneCourse({
    super.key,
    required this.nom,
    required this.complement,
    required this.coche,
    required this.quantite,
    required this.onTap,
    this.promo,
    this.alerte,
  });
  final String nom;
  final String complement;
  final bool coche;
  final int quantite;
  final TypePromo? promo;
  final int? alerte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = coche ? Charte.texteBarre : Charte.encre;
    return Material(
      color: Charte.fond,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Charte.ligneCourses),
          decoration: const BoxDecoration(border: Border(bottom: _bordLigne)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              CaseACocher(coche: coche, taille: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Charte.texte(17, gras: !coche, couleur: couleur, barre: coche)),
                      if (complement.isNotEmpty)
                        Text(complement,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Charte.texte(12,
                                couleur: coche ? Charte.texteBarre : Charte.texteSecondaire, barre: coche)),
                      if (alerte != null && !coche) AlerteQuantite(requise: alerte!),
                    ],
                  ),
                ),
              ),
              if (promo != null) ...[IconePromo(type: promo!), const SizedBox(width: 8)],
              Text('×$quantite', style: Charte.texte(17, gras: true, couleur: couleur)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne en lecture seule de la liste complète (32 points).
class LigneCompacte extends StatelessWidget {
  const LigneCompacte({super.key, required this.nom, required this.complement, required this.quantite, this.promo, this.coche = false});
  final String nom;
  final String complement;
  final int quantite;
  final TypePromo? promo;
  final bool coche;

  @override
  Widget build(BuildContext context) {
    final couleur = coche ? Charte.texteBarre : Charte.encre;
    return Container(
      height: Charte.ligneCompacte,
      decoration: const BoxDecoration(border: Border(bottom: _bordLigne)),
      padding: const EdgeInsets.only(left: 40, right: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: nom, style: Charte.texte(15, couleur: couleur, barre: coche)),
                      if (complement.isNotEmpty)
                        TextSpan(
                            text: '  $complement',
                            style: Charte.texte(12, couleur: Charte.texteSecondaire, barre: coche)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (promo != null) ...[const SizedBox(width: 6), IconePromo(type: promo!)],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('$quantite', textAlign: TextAlign.right, style: Charte.texte(15, gras: true, couleur: couleur)),
          ),
        ],
      ),
    );
  }
}

/// Titre de groupe : numéro d'ordre rond, nom du secteur ou du rayon, fond gris.
class TitreGroupe extends StatelessWidget {
  const TitreGroupe({super.key, required this.nom, this.numero, this.nonPlace = false});
  final String nom;
  final String? numero;
  final bool nonPlace;

  @override
  Widget build(BuildContext context) {
    final rond = Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Charte.encre, width: 1.2)),
      child: Text(numero ?? '?', style: Charte.texte(11, gras: true)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nonPlace) const TraitPointille(),
        Container(
          height: 30,
          color: Charte.fondSelection,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (numero != null || nonPlace) ...[rond, const SizedBox(width: 10)],
              Expanded(
                child: Text(nom.toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(12, gras: true, espacement: 0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key, this.haut = 16, this.cote = 16});
  final String texte;
  final double haut;
  final double cote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(cote, haut, cote, 8),
      child: Text(texte.toUpperCase(), style: Charte.texte(12, couleur: Charte.texteSecondaire, espacement: 1.2)),
    );
  }
}

// ----------------------------------------------------------------- Boutons

class Bouton extends StatelessWidget {
  const Bouton({
    super.key,
    required this.texte,
    required this.onTap,
    this.plein = false,
    this.pointille = false,
    this.hauteur = 48,
    this.icone,
    this.iconeApres,
    this.taille = 17,
  });
  final String texte;
  final VoidCallback? onTap;
  final bool plein;
  final bool pointille;
  final double hauteur;
  final IconData? icone;
  final IconData? iconeApres;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final actif = onTap != null;
    final fond = plein ? (actif ? Charte.encre : const Color(0xFF8A8A8A)) : Charte.fond;
    final texteCouleur = plein ? Charte.fond : (actif ? Charte.encre : const Color(0xFF8A8A8A));
    final contenu = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icone != null) ...[
            Icon(icone, size: icone == Icons.arrow_left || texte.isEmpty ? 28 : 20, color: texteCouleur),
            if (texte.isNotEmpty) const SizedBox(width: 6),
          ],
          if (texte.isNotEmpty)
            Flexible(
              child: Text(texte,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Charte.texte(taille, gras: true, couleur: texteCouleur)),
            ),
          if (iconeApres != null) ...[const SizedBox(width: 4), Icon(iconeApres, size: 28, color: texteCouleur)],
        ],
      ),
    );
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: plein || pointille ? BorderSide.none : _bordCadre,
    );
    Widget bouton = Material(
      color: fond,
      shape: forme,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: SizedBox(height: hauteur, child: contenu)),
    );
    if (pointille) bouton = CadrePointille(child: bouton);
    return Semantics(button: true, enabled: actif, child: bouton);
  }
}

/// Un ou deux boutons pleine largeur en bas de l'écran (64 points).
class BarreAction extends StatelessWidget {
  const BarreAction({super.key, required this.boutons});
  final List<Widget> boutons;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.barreAction,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(color: Charte.fond, border: Border(top: _bordZone)),
      child: Row(
        children: [
          for (var i = 0; i < boutons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: boutons[i]),
          ],
        ],
      ),
    );
  }
}

/// Barre de navigation des écrans de gestion.
class BarreNavigation extends StatelessWidget {
  const BarreNavigation({super.key, required this.index});
  final int index;

  static const _onglets = <(IconData, String)>[
    (Icons.home_outlined, 'Accueil'),
    (Icons.checklist, 'Liste'),
    (Icons.inventory_2_outlined, 'Produits'),
    (Icons.storefront_outlined, 'Magasins'),
    (Icons.history, 'Historique'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Charte.barreNavigation,
      decoration: const BoxDecoration(border: Border(top: _bordZone)),
      child: Row(
        children: [
          for (var i = 0; i < _onglets.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: Material(
                  color: i == index ? Charte.fondSelection : Charte.fond,
                  child: InkWell(
                    onTap: i == index && i != 0 ? null : () => Nav.onglet(context, i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_onglets[i].$1, size: 24, color: Charte.encre),
                        const SizedBox(height: 2),
                        Text(_onglets[i].$2, style: Charte.texte(12, gras: i == index)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Deux boutons accolés, un sélectionné.
class Bascule extends StatelessWidget {
  const Bascule({super.key, required this.options, required this.index, required this.onChange, this.hauteur = 44});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChange;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: Material(
                  color: i == index ? Charte.encre : Charte.fond,
                  child: InkWell(
                    onTap: () => onChange(i),
                    child: Center(
                      child: Text(options[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Charte.texte(16, gras: i == index, couleur: i == index ? Charte.fond : Charte.encre)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BandeauHorsReseau extends StatelessWidget {
  const BandeauHorsReseau({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: CadrePointille(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 18, color: Charte.encre),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Hors réseau : vos coches sont gardées et seront envoyées au retour du réseau.',
                    style: Charte.texte(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Divers

class CadrePointille extends StatelessWidget {
  const CadrePointille({super.key, required this.child, this.rayon = 8, this.epaisseur = 2, this.couleur = Charte.encre});
  final Widget child;
  final double rayon;
  final double epaisseur;
  final Color couleur;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _PeintrePointille(rayon, couleur, epaisseur), child: child);
}

class _PeintrePointille extends CustomPainter {
  _PeintrePointille(this.rayon, this.couleur, this.epaisseur);
  final double rayon;
  final Color couleur;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final demi = epaisseur / 2;
    final rect = Rect.fromLTWH(demi, demi, size.width - epaisseur, size.height - epaisseur);
    final chemin = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rayon)));
    final pinceau = Paint()
      ..color = couleur
      ..strokeWidth = epaisseur
      ..style = PaintingStyle.stroke;
    for (final m in chemin.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), pinceau);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PeintrePointille ancien) =>
      ancien.rayon != rayon || ancien.couleur != couleur || ancien.epaisseur != epaisseur;
}

class TraitPointille extends StatelessWidget {
  const TraitPointille({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 2, width: double.infinity, child: CustomPaint(painter: _PeintreTrait()));
}

class _PeintreTrait extends CustomPainter {
  const _PeintreTrait();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Charte.encre
      ..strokeWidth = 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + 6, 1), p);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}

class ImageAbsente extends StatelessWidget {
  const ImageAbsente({super.key, required this.texte, this.hauteur = 110});
  final String texte;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return CadrePointille(
      couleur: const Color(0xFF999999),
      epaisseur: 1.5,
      child: Container(
        height: hauteur,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Charte.placeholder, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(8),
        child: Text(texte, textAlign: TextAlign.center, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ),
    );
  }
}

/// Liste déroulante encadrée.
class ChoixDeroulant<T> extends StatelessWidget {
  const ChoixDeroulant({super.key, required this.valeur, required this.choix, required this.onChange, this.hauteur = 48});
  final T valeur;
  final Map<T, String> choix;
  final ValueChanged<T> onChange;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Charte.fond,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Charte.encre, width: Charte.traitCadre),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: choix.containsKey(valeur) ? valeur : null,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Charte.encre),
          style: Charte.texte(16),
          dropdownColor: Charte.fond,
          items: [
            for (final e in choix.entries)
              DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChange(v);
          },
        ),
      ),
    );
  }
}

/// Étiquette encadrée (rôle d'un membre, présence d'un ticket…).
class Etiquette extends StatelessWidget {
  const Etiquette(this.texte, {super.key, this.pointille = false, this.icone});
  final String texte;
  final bool pointille;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pointille
          ? null
          : BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Charte.encre, width: 1.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texte, style: Charte.texte(12, gras: !pointille)),
          if (icone != null) ...[const SizedBox(width: 3), Icon(icone, size: 13, color: Charte.encre)],
        ],
      ),
    );
    return pointille ? CadrePointille(rayon: 4, epaisseur: 1.2, child: contenu) : contenu;
  }
}

/// Lien souligné (« + Signaler une promotion », « Renommer »…), zone tactile 44 points.
class Lien extends StatelessWidget {
  const Lien(this.texte, {super.key, required this.onTap, this.taille = 16, this.italique = false});
  final String texte;
  final VoidCallback onTap;
  final double taille;
  final bool italique;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            texte,
            style: Charte.texte(taille).copyWith(
              decoration: TextDecoration.underline,
              fontStyle: italique ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Boîte de saisie d'un texte court ; renvoie null si annulée.
Future<String?> demanderTexte(BuildContext context,
    {required String titre, String initial = '', String? aide, String valider = 'Valider'}) {
  final controleur = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Charte.fond,
      title: Text(titre, style: Charte.texte(18, gras: true)),
      content: TextField(
        controller: controleur,
        autofocus: true,
        style: Charte.texte(16),
        decoration: InputDecoration(hintText: aide),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: Charte.texte(16)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controleur.text.trim()),
          child: Text(valider, style: Charte.texte(16, gras: true)),
        ),
      ],
    ),
  );
}

/// Choix dans une liste simple ; renvoie la clé choisie ou null.
Future<T?> choisirDansListe<T>(BuildContext context, {required String titre, required Map<T, String> choix}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Charte.fond,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(titre, style: Charte.texte(18, gras: true)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in choix.entries)
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(e.key),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(border: Border(bottom: _bordLigne)),
                        child: Text(e.value, style: Charte.texte(16)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
