import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'entete.dart' show glisserOnglet;
import 'pictogramme.dart';

export 'entete.dart';
export 'recherche.dart';

// Composants réutilisables (spécification IHM, chapitre 5).

BorderSide get _bordCadre => BorderSide(color: Charte.cadre, width: Charte.traitCadre);
BorderSide get _bordLigne => BorderSide(color: Charte.separateurLigne, width: Charte.traitSeparateur);
BorderSide get _bordZone => BorderSide(color: Charte.separateurZone, width: Charte.traitSeparateur);

/// Squelette commun à tous les écrans : en-tête, contenu, puis éléments du bas.
class PageBase extends StatefulWidget {
  const PageBase({super.key, required this.entete, required this.corps, this.haut = const [], this.bas = const []});
  final Widget entete;
  final List<Widget> haut;
  final Widget corps;
  final List<Widget> bas;

  @override
  State<PageBase> createState() => _PageBaseState();
}

class _PageBaseState extends State<PageBase> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Charte.fond,
      body: SafeArea(
        child: Builder(
          // Glisser le doigt sur une zone libre de la fenêtre passe à l'onglet voisin, comme sur le bandeau
          // (les lignes qui se glissent gardent leur geste : elles l'emportent).
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() > 200) glisserOnglet(context, v < 0 ? 1 : -1);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [widget.entete, ...widget.haut, Expanded(child: widget.corps), ...widget.bas],
            ),
          ),
        ),
      ),
    );
  }
}

class BoutonIcone extends StatelessWidget {
  const BoutonIcone({super.key, required this.icone, required this.onTap, required this.libelle, this.taille = 26, this.couleur});
  final IconData icone;
  final Color? couleur;
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
        child: SizedBox(width: 44, height: 44, child: Icon(icone, size: taille, color: couleur ?? Charte.couleurIcone(icone))),
      ),
    );
  }
}

/// Icône blanche sur un carré arrondi de couleur (menus, onglets).
/// L'icône de tête d'un élément de liste, la même partout : un rond pâle, l'icône au trait dans la couleur de la palette.
/// À la place de l'icône : des initiales ([texte]) ou l'image d'un rayon ou d'un secteur ([image]).
class IconeRonde extends StatelessWidget {
  const IconeRonde(this.icone, {super.key, this.texte, this.image, this.taille = 44});
  final IconData? icone;
  final String? texte;
  final String? image;
  final double taille;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: image != null ? Charte.blanc : Charte.fondSelection, shape: BoxShape.circle,
            border: image != null ? Border.all(color: Charte.separateurZone) : null),
        child: image != null
            ? Pictogramme(image, taille: taille * 0.8)
            : texte != null
                ? Text(texte!, style: Charte.texte(taille * 0.32, gras: true, couleur: Charte.cadre))
                : Icon(icone, size: taille * 0.55, color: Charte.cadre),
      );
}

// ----------------------------------------------------------------- Puces

class Puce {
  const Puce(this.libelle, {this.compteur, this.termine = false, this.icone, this.image});
  final String libelle;
  final int? compteur;
  final bool termine;
  final IconData? icone;

  /// Image du rayon ou du secteur (voir pictogramme.dart).
  final String? image;
}

/// Liste horizontale défilante de puces ; la puce sélectionnée reste visible.
class BandeauPuces extends StatefulWidget {
  const BandeauPuces({
    super.key,
    required this.puces,
    required this.selection,
    required this.onChoix,
    this.fond,
    this.pastille = true,
  });
  final List<Puce> puces;
  final int selection;
  final ValueChanged<int> onChoix;
  final Color? fond;

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
    final avecImages = widget.puces.any((p) => p.image != null);
    final rayon = avecImages ? 14.0 : (widget.pastille ? 18.0 : 8.0);
    return Container(
      height: avecImages ? 72 : Charte.bandeauPuces,
      decoration: BoxDecoration(color: widget.fond ?? Charte.fond, border: Border(bottom: _bordZone)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (var i = 0; i < widget.puces.length; i++)
              _puce(widget.puces[i], i == widget.selection, rayon, () => widget.onChoix(i), _cles[i], avecImages),
          ],
        ),
      ),
    );
  }

  Widget _puce(Puce p, bool choisie, double rayon, VoidCallback onTap, Key cle, bool grande) {
    final couleurTexte = choisie ? Charte.blanc : (p.termine ? Charte.texteBarre : Charte.encre);
    final bord = p.termine && !choisie ? Charte.separateurZone : Charte.cadre;
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
            height: grande ? 62 : 36,
            padding: EdgeInsets.only(left: p.image != null ? 5 : 12, right: 12),
            decoration: BoxDecoration(
              color: choisie ? Charte.accent : Charte.blanc,
              borderRadius: BorderRadius.circular(rayon),
              border: Border.all(color: bord, width: Charte.traitCadre),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.image != null) ...[
                  // Image en couleur sur un rond blanc, lisible même sur la puce choisie (fond noir).
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Pictogramme(p.image, taille: 44),
                  ),
                  const SizedBox(width: 8),
                ],
                if (p.icone != null) ...[
                  Icon(p.icone, size: 16, color: couleurTexte),
                  const SizedBox(width: 4),
                ],
                Text(p.libelle, style: Charte.texte(grande ? 17 : 15, gras: choisie, couleur: couleurTexte)),
                if (p.termine && !choisie) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check, size: 15, color: couleurTexte),
                ],
                if (p.compteur != null && p.compteur! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: grande ? 26 : 20,
                    height: grande ? 26 : 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: couleurTexte, width: 1.5),
                    ),
                    child: Text('${p.compteur}', style: Charte.texte(grande ? 13 : 11, gras: true, couleur: couleurTexte)),
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
        color: coche ? Charte.accent : Charte.blanc,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: coche ? Charte.accent : Charte.cadre, width: Charte.traitCadre),
      ),
      child: coche ? Icon(Icons.check, size: taille - 4, color: Charte.blanc) : null,
    );
  }
}

class IconePromo extends StatelessWidget {
  const IconePromo({super.key, required this.code, this.inverse = false});
  final String code;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final couleur = inverse ? Charte.blanc : Charte.cadre;
    return Semantics(
      label: 'Promotion $code',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: couleur, width: 1.5),
        ),
        child: Text(code, style: Charte.texte(Charte.tCodePromo + 1, gras: true, couleur: couleur)),
      ),
    );
  }
}

/// Bouton promotion d'une ligne cochée (34 × 30) : code du type si une promotion est visée,
/// sinon « % » en pointillé. Zone tactile portée à 44.
class BoutonPromo extends StatelessWidget {
  const BoutonPromo({super.key, required this.code, required this.onTap, this.couleur, this.iconeVide, this.sujet = 'promotion'});
  final String? code;
  final Color? couleur; // couleur du type de promotion (ou du packaging)
  final IconData? iconeVide; // dessinée quand rien n'est choisi (sinon « % »)
  final String sujet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contenu = SizedBox(
      width: 34,
      height: 30,
      child: Center(
        child: code == null && iconeVide != null
            ? Icon(iconeVide, size: 20, color: Charte.couleurIcone(iconeVide!))
            : Text(code ?? '%',
                style: Charte.texte(code == null ? 15 : Charte.tCodePromo + 2, gras: true, couleur: code == null ? Charte.rouge : Charte.encre)),
      ),
    );
    return Semantics(
      button: true,
      label: code == null ? 'Indiquer : $sujet' : '$sujet $code',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: code == null
                ? CadrePointille(rayon: 6, epaisseur: 1.5, child: contenu)
                : Container(
                    decoration: BoxDecoration(
                      color: couleur == null ? null : Color.alphaBlend(couleur!.withValues(alpha: 0.22), Charte.fond),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: couleur ?? Charte.encre, width: 1.5),
                    ),
                    child: contenu,
                  ),
          ),
        ),
      ),
    );
  }
}

class AlerteQuantite extends StatelessWidget {
  const AlerteQuantite({super.key, required this.requise});
  final int requise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: Charte.couleurIcone(Icons.warning_amber_rounded)),
          const SizedBox(width: 3),
          Flexible(child: Text('Il en faut $requise pour la promotion', style: Charte.texte(12, gras: true))),
        ],
      ),
    );
  }
}

class SelecteurQuantite extends StatelessWidget {
  const SelecteurQuantite({super.key, required this.quantite, required this.onChange});
  final int quantite;
  final ValueChanged<int> onChange;

  /// Zone tactile de 44 × 44 ; le signe est dessiné dans le cadre de 34 de haut.
  Widget _bouton(String signe, int valeur, String libelle) => Semantics(
        button: true,
        label: libelle,
        child: InkWell(
          onTap: () => onChange(valeur),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: Text(signe, style: Charte.texte(18, gras: true, couleur: Charte.cadre))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: 5,
            bottom: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Charte.blanc,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bouton('−', quantite - 1, 'Diminuer'),
              SizedBox(
                width: 18,
                child: Text('$quantite', textAlign: TextAlign.center, style: Charte.texte(16, gras: true)),
              ),
              _bouton('+', quantite + 1, 'Augmenter'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Packaging ou promotion en clair (« Pack de 6 », « 3 dont 1 gratuit »), sur la couleur choisie dans Paramètres.
/// Avec [onTap], c'est un bouton (préparation) ; [vide] : rien n'est encore choisi (« + Packaging », fond pâle).
class Pastille extends StatelessWidget {
  const Pastille(this.texte, {super.key, this.couleur, this.petite = false, this.onTap, this.vide = false});
  final String texte;
  final Color? couleur;
  final bool petite;
  final VoidCallback? onTap;
  final bool vide;

  @override
  Widget build(BuildContext context) {
    final c = couleur;
    final cadre = Container(
      padding: EdgeInsets.symmetric(horizontal: petite ? 5 : 7, vertical: petite ? 0 : 1),
      decoration: BoxDecoration(
        color: c == null
            ? Charte.fondBandeau
            : Color.alphaBlend(c.withValues(alpha: vide ? 0.08 : 0.22), Charte.fond),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c == null ? Charte.separateurZone : (vide ? c.withValues(alpha: 0.45) : c), width: 1.2),
      ),
      child: Text(texte,
          style: Charte.texte(petite ? 11 : 13, gras: true, couleur: vide && c != null ? c : Charte.encre)),
    );
    if (onTap == null) return cadre;
    // Zone tactile agrandie autour du cadre (même aspect que pendant les courses).
    return Semantics(
      button: true,
      label: texte,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(widthFactor: 1, child: cadre),
        ),
      ),
    );
  }
}

/// Titre de groupe : numéro d'ordre rond, nom du secteur ou du rayon, fond gris.
class TitreGroupe extends StatelessWidget {
  const TitreGroupe(
      {super.key,
      required this.nom,
      this.numero,
      this.nonPlace = false,
      this.image,
      this.fort = false,
      this.droite,
      this.avancement,
      this.nombre,
      this.icone,
      this.ouvert,
      this.focus = false,
      this.ajoute = false,
      this.grand = false,
      this.onTap});
  final String nom;

  /// Bandeau des listes autres que les articles : plus haut, police plus grosse, avec icône ou image.
  final bool grand;

  /// Rayon ou secteur ajouté par le foyer : petit signe après le nom.
  final bool ajoute;
  final VoidCallback? onTap;
  final String? droite;
  /// Nombre d'articles ou d'éléments du groupe, à droite.
  final int? nombre;

  /// [image] et [icone] ne s'affichent que sur un bandeau [grand] ; ne sont plus affichés : [numero],
  /// [avancement], [ouvert], [focus], [fort].
  final String? numero;
  final String? image;
  final IconData? icone;
  final (int, int)? avancement;
  final bool? ouvert;
  final bool focus;
  final bool fort;
  final bool nonPlace;

  @override
  Widget build(BuildContext context) {
    final blanc = Charte.texte(grand ? 16 : 14, gras: true, couleur: Charte.blanc);
    final signe = !grand
        ? null
        : image != null
            ? Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Charte.blanc, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Pictogramme(image!, taille: 26),
              )
            : icone != null
                ? Icon(icone, size: 24, color: Charte.blanc)
                : null;
    return Material(
      color: nonPlace ? Charte.texteSecondaire : Charte.accent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: grand ? Charte.ligneListe : 0),
          padding: EdgeInsets.fromLTRB(grand ? 12 : 16, 4, 14, 4),
          child: Row(children: [
            if (signe != null) ...[signe, const SizedBox(width: 10)],
            Expanded(child: Text(nom.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: blanc)),
            if (ajoute) Text(' +', style: blanc),
            if (droite != null) Text(droite!, style: blanc),
            if (nombre != null && nombre! > 0) Padding(padding: const EdgeInsets.only(left: 8), child: Text('$nombre', style: blanc)),
          ]),
        ),
      ),
    );
  }
}

/// Groupes rétractables ouverts ou fermés, gardés tant que l'application tourne.
class Retractables extends ChangeNotifier {
  Retractables._();
  static final i = Retractables._();
  final Map<String, bool> _etat = {};

  bool ouvert(String cle, {bool parDefaut = true}) => _etat[cle] ?? parDefaut;
  void basculer(String cle, {bool parDefaut = true}) {
    _etat[cle] = !ouvert(cle, parDefaut: parDefaut);
    notifyListeners();
  }

  /// Ouvre ou ferme d'un coup tous les groupes donnés (bouton « Tout réduire » / « Tout développer »).
  void tous(Iterable<String> cles, bool ouvrir) {
    for (final c in cles) {
      _etat[c] = ouvrir;
    }
    notifyListeners();
  }

  /// Fixe l'état d'ouverture sans prévenir (à la création d'un écran).
  void fixer(Iterable<String> cles, bool ouvrir) {
    for (final c in cles) {
      _etat[c] = ouvrir;
    }
  }

  bool tousFermes(Iterable<String> cles, {bool parDefaut = true}) => cles.isNotEmpty && cles.every((c) => !ouvert(c, parDefaut: parDefaut));
}

/// Le modèle de toutes les listes de l'application : un mince bandeau (titre du groupe, nombre), puis les
/// éléments du groupe, toujours visibles (plus rien ne se replie). [cle], [image], [icone] et [parDefaut]
/// ne servent plus.
class GroupeRetractable extends StatelessWidget {
  const GroupeRetractable({
    super.key,
    required this.cle,
    required this.titre,
    required this.enfants,
    this.image,
    this.icone,
    this.nombre,
    this.vide,
    this.parDefaut = true,
    this.marge = 16,
    this.ajoute = false,
    this.actions = const [],
  });
  final String cle;
  final bool ajoute;

  /// Actions du groupe : toucher son bandeau les propose dans un volet.
  final List<ActionLigne> actions;
  final String titre;
  final List<Widget> enfants;
  final String? image;
  final IconData? icone;
  final int? nombre;
  /// Texte affiché quand le groupe n'a aucun élément.
  final String? vide;
  final bool parDefaut;
  final double marge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitreGroupe(
          nom: titre,
          nombre: nombre,
          ajoute: ajoute,
          grand: true,
          image: image,
          icone: icone,
          onTap: actions.isEmpty ? null : () => menuActions(context, titre: titre, actions: actions),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: marge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enfants.isEmpty && vide != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(vide!, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ),
              ...enfants,
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

/// Action « Tout replier » / « Tout déplier » des groupes [cles] (menu de l'en-tête).

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
    final fond = plein ? (actif ? Charte.accent : Charte.desactive) : Charte.blanc;
    final texteCouleur = plein ? Charte.blanc : (actif ? Charte.cadre : Charte.desactive);
    final contenu = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pas d'icône à côté d'un libellé : seulement sur un bouton sans texte.
          if (icone != null && texte.isEmpty) Icon(icone, size: 28, color: texteCouleur),
          if (texte.isNotEmpty)
            Flexible(
              child: Text(texte,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Charte.texte(taille, gras: true, couleur: texteCouleur)),
            ),
          if (iconeApres != null && texte.isEmpty) Icon(iconeApres, size: 28, color: texteCouleur),
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

/// Bouton d'ÉTAT (un filtre qu'on allume ou éteint) : forme de gélule et interrupteur à gauche.
/// Il se distingue des boutons d'ACTION ([Bouton], rectangles) : son libellé ne change pas,
/// seul l'interrupteur montre s'il est allumé.
class BoutonEtat extends StatelessWidget {
  const BoutonEtat({super.key, required this.texte, required this.actif, required this.onTap, this.taille = 14, this.hauteur = 48, this.surPhoto = false});
  final String texte;
  final bool actif;
  final VoidCallback onTap;
  final double taille;
  final double hauteur;

  /// Posé sur la photo de la barre de titre : libellé blanc ombré.
  final bool surPhoto;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: actif,
        child: Material(
          // Ni cadre ni fond : l'interrupteur seul dit l'état.
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: hauteur,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 2),
                  // Interrupteur à la hauteur des icônes de l'application (24) ; tout le bouton reste sensible.
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: SizedBox(
                    width: 40,
                    height: 24,
                    child: FittedBox(
                      child: Switch(
                        value: actif,
                        onChanged: (_) => onTap(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeThumbColor: Charte.blanc,
                        activeTrackColor: Charte.accent,
                        inactiveThumbColor: Charte.texteBarre,
                        inactiveTrackColor: Charte.blanc,
                        trackOutlineColor: WidgetStatePropertyAll(actif ? Charte.accent : Charte.texteBarre),
                      ),
                    ),
                  ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    // Une seule ligne : le libellé rapetisse plutôt que de passer à la ligne.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(texte,
                          maxLines: 1,
                          style: surPhoto
                              ? Charte.texte(taille, gras: actif, couleur: Charte.blanc)
                                  .copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)])
                              : Charte.texte(taille, gras: actif, couleur: Charte.encre)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      );
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
      decoration: BoxDecoration(color: Charte.fondBandeau, border: Border(top: _bordZone)),
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

/// Écran en liste avec, en bas, la zone réservée aux décisions (juste au-dessus des onglets).
class AvecDecision extends StatelessWidget {
  const AvecDecision({super.key, required this.contenu, required this.boutons});
  final Widget contenu;
  final List<Widget> boutons;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: contenu), BarreAction(boutons: boutons)],
      );
}

/// Deux boutons accolés, un sélectionné.
class Bascule extends StatelessWidget {
  const Bascule({super.key, required this.options, required this.index, required this.onChange, this.hauteur = 48, this.douce = false});
  final bool douce;
  final List<String> options;
  final int index;
  final ValueChanged<int> onChange;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      // Un choix d'état : forme de gélule, comme [BoutonEtat] (les actions sont rectangulaires).
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(hauteur / 2),
        border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
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
                  color: i == index ? (douce ? Charte.fondSelection : Charte.accent) : Charte.blanc,
                  child: InkWell(
                    onTap: () => onChange(i),
                    child: Center(
                      child: Text(options[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Charte.texte(16, gras: i == index, couleur: i == index && !douce ? Charte.blanc : Charte.encre)),
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
              Icon(Icons.cloud_off_outlined, size: 18, color: Charte.couleurIcone(Icons.cloud_off_outlined)),
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
        border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: choix.containsKey(valeur) ? valeur : null,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: Charte.couleurIcone(Icons.expand_more)),
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
          : BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Charte.cadre, width: 1.5)),
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

/// Petit bouton d'action secondaire (« Copier », « Restaurer »…), à bord fin.
class Lien extends StatelessWidget {
  const Lien(this.texte, {super.key, required this.onTap, this.taille = 16, this.italique = false});
  final String texte;
  final VoidCallback onTap;
  final double taille;
  final bool italique;

  // Une action est toujours un bouton (jamais un texte souligné) : petit bouton à bord fin.
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Material(
        color: Charte.fond,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              texte,
              style: Charte.texte(taille, couleur: Charte.cadre).copyWith(fontStyle: italique ? FontStyle.italic : FontStyle.normal),
            ),
          ),
        ),
      ),
    );
  }
}

/// Volet du bas : toutes les fenêtres de l'application s'ouvrent ainsi, avec la poignée en haut.
/// Il remonte avec le clavier, ne dépasse pas la largeur d'un téléphone sur grand écran ;
/// [fermable] faux : seuls ses boutons le ferment (saisies longues qu'un geste maladroit ferait perdre).
Future<T?> volet<T>(BuildContext context, {required WidgetBuilder builder, bool fermable = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: fermable,
    enableDrag: fermable,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Charte.blanc,
    barrierColor: Charte.voile,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(top: false, child: builder(ctx)),
    ),
  );
}

/// Corps d'un volet : titre, contenu qui défile, puis les boutons (toujours visibles).
Widget corpsVolet({required String titre, required Widget contenu, List<Widget> boutons = const []}) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titre, style: Charte.texte(20, gras: true)),
          const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: contenu)),
          for (final b in boutons) ...[const SizedBox(height: 10), b],
        ],
      ),
    );

/// Change l'ordre d'une liste de noms (on fait glisser la poignée ≡) ; renvoie null si annulé.
Future<List<String>?> ordonner(BuildContext context, {required String titre, required List<String> noms}) {
  final ordre = [...noms];
  return volet<List<String>>(
    context,
    fermable: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: Charte.texte(20, gras: true)),
            const SizedBox(height: 4),
            Text('Faites glisser la poignée ≡ pour déplacer un secteur.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 8),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: ordre.length,
                onReorderItem: (de, vers) => maj(() => ordre.insert(vers, ordre.removeAt(de))),
                itemBuilder: (ctx, i) => Material(
                  key: ValueKey('ordre-${ordre[i]}'),
                  color: Charte.blanc,
                  child: Container(
                    height: Charte.ligneListe,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                    child: Row(children: [
                      Expanded(child: Text(ordre[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(17))),
                      ReorderableDragStartListener(
                        index: i,
                        child: Container(
                          width: 44,
                          height: Charte.ligneListe,
                          alignment: Alignment.center,
                          child: Icon(Icons.drag_handle, key: ValueKey('poignee-${ordre[i]}'), size: 26, color: Charte.cadre),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Bouton(texte: 'Valider', plein: true, onTap: () => Navigator.of(ctx).pop(ordre)),
            const SizedBox(height: 10),
            Bouton(texte: 'Annuler', onTap: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    ),
  );
}

/// Saisie d'un texte court ; renvoie null si annulée.
Future<String?> demanderTexte(BuildContext context,
    {required String titre, String initial = '', String? aide, String valider = 'Valider'}) {
  final controleur = TextEditingController(text: initial);
  return volet<String>(
    context,
    builder: (ctx) => corpsVolet(
      titre: titre,
      contenu: TextField(
        controller: controleur,
        autofocus: true,
        style: Charte.texte(16),
        decoration: InputDecoration(hintText: aide),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      boutons: [
        Row(children: [
          Expanded(child: Bouton(texte: 'Annuler', onTap: () => Navigator.of(ctx).pop())),
          const SizedBox(width: 10),
          Expanded(child: Bouton(texte: valider, plein: true, onTap: () => Navigator.of(ctx).pop(controleur.text.trim()))),
        ]),
      ],
    ),
  );
}

/// Choix dans une liste simple ; renvoie la clé choisie ou null.
Future<T?> choisirDansListe<T>(BuildContext context, {required String titre, required Map<T, String> choix}) {
  return volet<T>(
    context,
    builder: (ctx) => corpsVolet(
      titre: titre,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in choix.entries)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(e.key),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(border: Border(bottom: _bordLigne)),
                child: Text(e.value, style: Charte.texte(16)),
              ),
            ),
        ],
      ),
    ),
  );
}

// ----------------------------------------------------------------- Composants v0.2

class SousOnglet {
  const SousOnglet(this.libelle, this.icone);
  final String libelle;
  final IconData icone;
}

/// Boutons d'onglet accolés dans un cadre arrondi ; l'actif est plein.
class SousOnglets extends StatelessWidget {
  const SousOnglets({super.key, required this.onglets, required this.actif, required this.onChoix});
  final List<SousOnglet> onglets;
  final int actif;
  final ValueChanged<int> onChoix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Container(
        height: Charte.sousOnglets + 4, // 44 de zone tactile à l'intérieur du cadre de 2
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < onglets.length; i++) ...[
              if (i > 0) Container(width: 1.5, color: Charte.cadre),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == actif,
                  label: onglets[i].libelle,
                  child: Material(
                    color: i == actif ? Charte.accent : Charte.blanc,
                    child: InkWell(
                      onTap: () => onChoix(i),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(onglets[i].icone, size: 18, color: i == actif ? Charte.blanc : Charte.cadre),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(onglets[i].libelle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Charte.texte(15, gras: i == actif, couleur: i == actif ? Charte.blanc : Charte.encre)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte : cadre 2, rayon 10 ; cliquable = chevron à droite.
class Carte extends StatelessWidget {
  const Carte({super.key, required this.child, this.onTap, this.chevron, this.fond, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final bool? chevron;
  final Color? fond;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final avecChevron = chevron ?? onTap != null;
    return Material(
      color: fond ?? Charte.blanc,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(child: child),
              if (avecChevron) Icon(Icons.chevron_right, size: 28, color: Charte.couleurIcone(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de menu : titre, sous-titre gris, chevron ; zone tactile 44 au moins.
/// Action courte au bout d'un élément de liste (« Reprendre », « Partir ») : pilule pleine ou à contour.
class BoutonAction extends StatelessWidget {
  const BoutonAction(this.texte, {super.key, required this.onTap, this.plein = false});
  final String texte;
  final VoidCallback onTap;
  final bool plein;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: texte,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: plein ? Charte.accent : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: plein ? Charte.accent : Charte.cadre, width: 1.6),
            ),
            child: Text(texte, style: Charte.texte(15, gras: true, couleur: plein ? Charte.blanc : Charte.cadre)),
          ),
        ),
      );
}

/// L'élément de liste standard, le même partout : une ligne de 30 points, le titre, son complément en petit
/// à droite (coupé s'il est long : le détail s'ouvre au toucher), sans icône ni chevron.
/// [icone] et [gauche] ne sont plus affichés.
class LigneMenu extends StatelessWidget {
  const LigneMenu(
      {super.key, required this.titre, this.sousTitre, this.onTap, this.titreTaille = 16, this.gauche, this.droite, this.icone, this.apresTitre});
  final String titre;

  /// Petit signe après le titre (ex. : produit ajouté ou modifié par le foyer).
  final Widget? apresTitre;
  final IconData? icone;
  final String? sousTitre;
  final VoidCallback? onTap;
  final double titreTaille;
  final Widget? gauche;
  final Widget? droite;

  @override
  Widget build(BuildContext context) {
    final signe = gauche ?? (icone == null ? null : Icon(icone, size: 24, color: Charte.cadre));
    return Material(
      color: Charte.fond,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Charte.ligneListe),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              if (signe != null) ...[SizedBox(width: 32, height: 32, child: FittedBox(child: signe)), const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(child: Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(17))),
                      if (apresTitre != null) ...[const SizedBox(width: 6), apresTitre!],
                    ]),
                    if (sousTitre != null && sousTitre!.isNotEmpty)
                      Text(sousTitre!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
              if (droite != null) ...[const SizedBox(width: 8), droite!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton Pause : pastille contour, icône pause + « Pause ».
class BoutonPause extends StatelessWidget {
  const BoutonPause({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pause',
      child: Material(
        color: Charte.fond,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause, size: 18, color: Charte.couleurIcone(Icons.pause)),
                  const SizedBox(width: 4),
                  Text('Pause', style: Charte.texte(15, gras: true)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fenêtre des étapes décisives (valider la liste, partir faire les courses, terminer…), en volet du bas :
/// titre, ce qu'il faut savoir ou choisir, puis l'action (bouton plein) et l'annulation.
/// Rend true si l'action est choisie. [icone] et [croix] ne sont plus affichés (ni icônes, ni croix : la poignée ferme).
Future<bool> modale(
  BuildContext context, {
  required String titre,
  IconData? icone,
  required Widget Function(BuildContext context, StateSetter maj) contenu,
  required String? oui,
  String? non = 'Annuler',
  bool croix = false,
  bool fermable = true,
}) async {
  final r = await volet<bool>(
    context,
    fermable: fermable,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => corpsVolet(
        titre: titre,
        contenu: contenu(ctx, maj),
        boutons: [
          if (oui != null) Bouton(texte: oui, plein: true, onTap: () => Navigator.of(ctx).pop(true)),
          if (non != null) Bouton(texte: non, onTap: () => Navigator.of(ctx).pop(false)),
        ],
      ),
    ),
  );
  return r == true;
}

/// Case à cocher d'une fenêtre modale (ex. : « Enregistrer le parcours »).
class CaseModale extends StatelessWidget {
  const CaseModale({super.key, required this.texte, this.aide, required this.coche, required this.onChange});
  final String texte;
  final String? aide;
  final bool coche;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChange(!coche),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CaseACocher(coche: coche, taille: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(texte, style: Charte.texte(16, gras: true)),
                    if (aide != null) Text(aide!, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Confirmation en volet du bas : bouton plein (rend false) et bouton contour (rend true) ; null si fermé.
Future<bool?> confirmer(
  BuildContext context, {
  required String titre,
  required Widget contenu,
  required String plein,
  required String contour,
  IconData? icone,
}) {
  return volet<bool>(
    context,
    builder: (ctx) => corpsVolet(
      titre: titre,
      contenu: contenu,
      boutons: [
        Bouton(texte: plein, plein: true, onTap: () => Navigator.of(ctx).pop(false)),
        Bouton(texte: contour, onTap: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
}

// ------------------------------------------------------------ Gestes tactiles

/// Action d'une ligne, proposée par glissement ou dans le menu de l'appui long.
class ActionLigne {
  const ActionLigne(this.icone, this.texte, this.faire, {this.danger = false});
  final IconData icone;
  final String texte;
  final VoidCallback faire;

  /// Suppression : fond rouge quand on glisse.
  final bool danger;
}

/// Ligne qu'on fait glisser du doigt : vers la gauche [versGauche] (en général supprimer),
/// vers la droite [versDroite] (l'action principale) ; un appui long ouvre le menu de toutes les [actions].
class Glissable extends StatelessWidget {
  const Glissable(
      {required Key key, required this.child, this.versGauche, this.versDroite, this.titre, this.detail, this.auToucher = false, this.actions = const []})
      : super(key: key);
  final Widget child;

  /// Détail montré en tête du volet des actions.
  final String? detail;

  /// Toucher la ligne ouvre aussi le volet (détail et actions), comme l'appui long.
  final bool auToucher;
  final ActionLigne? versGauche;
  final ActionLigne? versDroite;
  final String? titre;
  final List<ActionLigne> actions;

  Widget _fond(ActionLigne a, bool aDroite) => Container(
        color: a.danger ? Charte.rouge : Charte.accent,
        alignment: aDroite ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(a.texte, style: Charte.texte(16, gras: true, couleur: Charte.blanc)),
      );

  @override
  Widget build(BuildContext context) {
    Widget w = child;
    if (actions.isNotEmpty) {
      w = GestureDetector(
        onTap: auToucher ? () => menuActions(context, titre: titre, detail: detail, actions: actions) : null,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          menuActions(context, titre: titre, detail: detail, actions: actions);
        },
        child: w,
      );
    }
    if (versGauche == null && versDroite == null) return w;
    final gauche = versGauche, droite = versDroite;
    return Dismissible(
      key: key!,
      direction: gauche != null && droite != null
          ? DismissDirection.horizontal
          : (gauche != null ? DismissDirection.endToStart : DismissDirection.startToEnd),
      dismissThresholds: const {DismissDirection.endToStart: 0.35, DismissDirection.startToEnd: 0.35},
      background: droite != null ? _fond(droite, false) : _fond(gauche!, true),
      secondaryBackground: gauche != null && droite != null ? _fond(gauche, true) : null,
      // La ligne revient toujours en place : c'est l'action (et la mise à jour des données) qui la fait disparaître.
      confirmDismiss: (sens) async {
        HapticFeedback.selectionClick();
        final a = sens == DismissDirection.endToStart ? gauche : droite;
        a?.faire();
        return false;
      },
      child: w,
    );
  }
}

/// Volet d'une ligne (toucher ou appui long) : son détail éventuel, puis ses actions, sans icônes.
Future<void> menuActions(BuildContext context, {String? titre, String? detail, required List<ActionLigne> actions}) async {
  final choix = await volet<ActionLigne>(
    context,
    builder: (ctx) => corpsVolet(
      titre: titre ?? '',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail != null && detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(detail, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
          for (final a in actions)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(a),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(border: Border(bottom: _bordLigne)),
                child: Text(a.texte, style: Charte.texte(17, couleur: a.danger ? Charte.rouge : Charte.encre)),
              ),
            ),
        ],
      ),
    ),
  );
  choix?.faire();
}
