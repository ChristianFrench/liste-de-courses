import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../composants/composants.dart';
import '../composants/pictogramme.dart' show cleRayon;
import '../donnees/catalogue_commun.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import 'editeur_catalogue.dart';
import '../theme.dart';
import '../donnees/synchro.dart';

// Écrans de Gérer : Mon foyer (Foyer et ses membres), Courses (Types de promotion, de mesure, de packaging),
// Paramètres (Apparence, Données).

/// Page simple de Gérer : en-tête avec retour, contenu en colonne.
/// [actions] : les actions de l'écran, proposées en touchant son titre.
Widget _page(String sousTitre, String titre, IconData icone, List<Widget> contenu, {List<ActionLigne> actions = const []}) => PageBase(
      entete: EnTeteFenetre(retour: true, icone: icone, sousTitre: sousTitre, titre: titre, actions: actions),
      corps: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: contenu),
    );

/// Écran de Gérer redessiné à chaque changement (couleur choisie, membre ajouté…).
abstract class _EcranVivant extends StatelessWidget {
  const _EcranVivant({super.key});
  Widget construire(BuildContext context);

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Etat.instance, builder: (context, _) => construire(context));
}

/// Pour l'écran Foyer (foyer.dart).
typedef OptionFoyer = _Option;
Future<void> repartirANeuf(BuildContext context) => _neuf(context);
Future<void> ajouterMembreParNom(BuildContext context) => _ajouterMembre(context, Etat.instance);

/// Ajout d'un membre directement par son nom, sans passer par l'invitation.
Future<void> _ajouterMembre(BuildContext context, Etat etat) async {
  final nom = await demanderTexte(libelle: 'Prénom', context, titre: 'Nouveau membre', aide: 'Prénom ou nom', valider: 'Ajouter');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  if (etat.membres.any((m) => m.nomAffiche.toLowerCase() == nom.trim().toLowerCase())) {
    Nav.message(context, '« ${nom.trim()} » fait déjà partie du foyer');
    return;
  }
  final email = await demanderTexte(libelle: 'Adresse mail', context, titre: 'Adresse mail · ${nom.trim()}', aide: 'prenom.nom@exemple.fr (facultatif)');
  etat.ajouterMembre(nom, email ?? '');
  if (context.mounted) Nav.message(context, '${nom.trim()} fait maintenant partie du foyer');
}

Future<void> _exemples(BuildContext context) async {
  final ok = await confirmer(
    context,
    titre: 'Listes exemples',
    contenu: Text(
      'Remettre les trois listes exemples (en préparation, prête, courses en cours) ? '
      'Les exemples encore présents sont remplacés ; vos listes ne changent pas.',
      style: Charte.texte(16),
    ),
    plein: 'Annuler',
    contour: 'Remettre les exemples',
  );
  if (ok != true) return;
  Etat.instance.creerExemples();
  if (context.mounted) Nav.message(context, 'Listes exemples remises');
}

Future<void> _neuf(BuildContext context) async {
  final partage = Synchro.instance.actif;
  final ok = await confirmer(
    context,
    titre: 'Repartir d\'un foyer neuf',
    icone: Icons.restart_alt,
    contenu: Text(
      'Le foyer repart du contenu de départ : le catalogue, les enseignes et les trois listes exemples. '
      'Vos listes, parcours, tickets et modifications du catalogue disparaissent de l\'application '
      '(une copie reste dans un fichier sur cet appareil).'
      '${partage ? '\n\nLe partage entre appareils est arrêté sur cet appareil, et le nom du foyer est libéré : vous pourrez le reprendre en créant un foyer.' : ''}',
      style: Charte.texte(16),
    ),
    plein: 'Annuler',
    contour: 'Repartir à neuf',
  );
  if (ok != true) return;
  if (partage) await Synchro.instance.libererNomEtArreter();
  await Etat.instance.repartirANeuf();
  Synchro.instance.rafraichir();
  Nav.i.reinitialiser();
  Nav.i.retourOnglet(Nav.gerer);
  if (context.mounted) Nav.message(context, 'Foyer neuf');
}

/// Gérer › Paramètres › Apparence : palettes de couleurs.
class EcranApparence extends _EcranVivant {
  const EcranApparence({super.key});

  @override
  Widget construire(BuildContext context) {
    final etat = Etat.instance;
    final cadres = (etat.couleurPromotions, etat.couleurMesures, etat.couleurLots);
    final cadresActuels = palettesCadres.where((p) => (p.$2, p.$3, p.$4) == cadres).firstOrNull?.$1 ?? '';
    return _page('Gérer › Paramètres', 'Apparence', Icons.palette_outlined, [
      // 02/11/2026 (Aristide) : deux sujets titrés, chacun avec une liste déroulante (libellé à gauche, palette à
      // droite) et un petit exemple du résultat en dessous.
      const TitreSection('Palette de l\'application', cote: 0),
      ChoixDeroulant<String>(
        libelle: 'Palette',
        valeur: Charte.palette.nom,
        choix: {for (final p in toutesLesPalettes) p.nom: p.nom},
        apercus: {for (final p in toutesLesPalettes) p.nom: _Echantillon(p)},
        apercuADroite: true,
        onChange: (v) {
          etat.choisirApparence(v);
          Charte.choisirPalette(v);
        },
      ),
      const SizedBox(height: 10),
      TitreGroupe(nom: 'Fruits et légumes', grand: true, image: cleRayon('Fruits et légumes'), nombre: 2),
      for (final (n, d) in [('Pommes Golden', '1 kg'), ('Bananes', 'Lot de 6')]) LigneMenu(titre: n, sousTitre: d),
      const TitreSection('Palette des cadres', cote: 0),
      ChoixDeroulant<String>(
        key: const ValueKey('palette-cadres'),
        libelle: 'Promotions, mesures, packagings',
        valeur: cadresActuels,
        choix: {if (cadresActuels.isEmpty) '': 'Personnalisée', for (final p in palettesCadres) p.$1: p.$1},
        apercus: {
          if (cadresActuels.isEmpty) '': _EchantillonCadres(cadres),
          for (final p in palettesCadres) p.$1: _EchantillonCadres((p.$2, p.$3, p.$4)),
        },
        apercuADroite: true,
        onChange: (v) {
          final p = palettesCadres.firstWhere((p) => p.$1 == v);
          etat.choisirCouleur('promo', p.$2);
          etat.choisirCouleur('mesure', p.$3);
          etat.choisirCouleur('lot', p.$4);
        },
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 8, children: [
        Pastille('Promo -30 %', couleur: Color(etat.couleurPromotions)),
        Pastille('500 g', couleur: Color(etat.couleurMesures)),
        Pastille('Lot de 4', couleur: Color(etat.couleurLots)),
      ]),
    ]);
  }
}

/// Les trois couleurs d'une palette des cadres, côte à côte.
class _EchantillonCadres extends StatelessWidget {
  const _EchantillonCadres(this.couleurs);
  final (int, int, int) couleurs;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final c in [couleurs.$1, couleurs.$2, couleurs.$3]) Container(width: 26, height: 22, color: Color(c)),
        ]),
      );
}

/// Gérer › Paramètres › Données : listes exemples, puis suppression automatique des archives.
class EcranDonnees extends _EcranVivant {
  const EcranDonnees({super.key});

  @override
  Widget construire(BuildContext context) {
    final etat = Etat.instance;
    return _page('Gérer › Paramètres', 'Données', Icons.storage_outlined, [
      LigneMenu(
        icone: Icons.playlist_add_check,
        titre: 'Préliste',
        sousTitre: 'Produits présents ${etat.prelistePresencesMin} fois sur les ${etat.prelisteSur} dernières courses',
        onTap: () => _reglerPreliste(context, etat),
      ),
      LigneMenu(
        icone: Icons.inventory_2_outlined,
        titre: 'Passage de l\'historique aux archives',
        sousTitre: etat.delaiHistorique == 0 ? 'Jamais : les courses restent dans l\'historique' : 'Après ${etat.delaiHistorique} mois',
        onTap: () async {
          final v = await choisirDansListe<int>(context,
              titre: 'Archiver les courses après', choix: const {1: '1 mois', 2: '2 mois', 3: '3 mois', 6: '6 mois', 12: '1 an', 0: 'Jamais'});
          if (v != null) etat.reglerDelaiHistorique(v);
        },
      ),
      LigneMenu(
        icone: Icons.timer_outlined,
        titre: 'Suppression automatique des archives',
        sousTitre: etat.delaiArchives == 0 ? 'Jamais : les archives sont gardées' : 'Après ${etat.delaiArchives} mois',
        onTap: () async {
          final v = await choisirDansListe<int>(context,
              titre: 'Supprimer les archives après', choix: const {0: 'Jamais', 6: '6 mois', 12: '1 an', 24: '2 ans', 60: '5 ans'});
          if (v != null) etat.reglerDelaiArchives(v);
        },
      ),
      if (CatalogueCommun.editeurPossible)
        LigneMenu(
          icone: Icons.public,
          titre: 'Éditeur du catalogue commun',
          sousTitre: CatalogueCommun.instance.editeur
              ? 'Ouvert sur cet appareil (aussi dans Gérer › Courses)'
              : 'Fermé : touchez pour saisir le code d\'éditeur',
          onTap: () => CatalogueCommun.instance.editeur
              ? Nav.aller<void>(context, const EcranEditeurCatalogue())
              : _deverrouillerEditeur(context),
        ),
      LigneMenu(
        icone: Icons.receipt_long_outlined,
        titre: 'Journal de l\'appareil',
        sousTitre: 'Ouvertures et fermetures, avec l\'état de la base',
        onTap: () => _journal(context),
      ),
    ], actions: [
      ActionLigne(Icons.restore, 'Remettre les listes exemples', () => _exemples(context)),
    ]);
  }
}

/// Le code d'éditeur (secret GitHub CODE_EDITEUR) ouvre Gérer › Courses › Catalogue commun sur cet appareil.
Future<void> _deverrouillerEditeur(BuildContext context) async {
  final code = await demanderTexte(libelle: 'Code', context, titre: 'Éditeur du catalogue commun', aide: 'Code d\'éditeur', valider: 'Ouvrir');
  if (code == null || !context.mounted) return;
  if (CatalogueCommun.instance.deverrouiller(code)) {
    Etat.instance.modifie();
    await Nav.aller<void>(context, const EcranEditeurCatalogue());
  } else {
    Nav.message(context, 'Code incorrect');
  }
}

Future<void> _reglerPreliste(BuildContext context, Etat etat) async {
  var presences = etat.prelistePresencesMin;
  var sur = etat.prelisteSur;
  final ok = await volet<bool>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => corpsVolet(
        titre: 'Règle de la préliste',
        contenu: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Un produit entre dans la préliste s\'il figure au moins', style: Charte.texte(15)),
            _Compteur(valeur: presences, min: 1, max: sur, onChange: (v) => maj(() => presences = v)),
            Text('fois sur les dernières courses du magasin, au nombre de', style: Charte.texte(15)),
            _Compteur(valeur: sur, min: presences, max: 20, onChange: (v) => maj(() => sur = v)),
          ],
        ),
        boutons: [
          Bouton(texte: 'Annuler', onTap: () => Navigator.of(ctx).pop(false)),
          Bouton(texte: 'Valider', plein: true, onTap: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ),
  );
  if (ok == true) etat.reglerPreliste(presences, sur);
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.min, required this.max, required this.onChange});
  final int valeur;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SelecteurQuantite(quantite: valeur, onChange: (v) => onChange(v.clamp(min, max))),
      );
}

/// Gérer › Courses › Types de promotion : chacun dans un petit cadre, tous de la couleur des promotions
/// (Gérer › Paramètres › Apparence). Touchez un type pour le modifier ou le supprimer.
class EcranTypesPromotion extends StatelessWidget {
  const EcranTypesPromotion({super.key});

  Future<void> _agir(BuildContext context, TypePromotion t) => menuActions(context, titre: t.nom, actions: [
        ActionLigne(Icons.edit_outlined, 'Modifier le nom et le code', () async {
          final etat = Etat.instance;
          final nom = await demanderTexte(context, titre: 'Nom du type de promotion', initial: t.nom);
          if (nom == null || nom.isEmpty || !context.mounted) return;
          final code = await demanderTexte(libelle: 'Code', context, titre: 'Code court (3 caractères)', initial: t.code);
          if (code == null || code.isEmpty) return;
          etat.modifierTypePromotion(t, nom: nom, code: code.length > 4 ? code.substring(0, 4) : code);
        }),
        ActionLigne(Icons.delete_outline, 'Supprimer ce type', () async {
          final ok = await confirmer(context,
              titre: 'Supprimer « ${t.nom} » ?',
              contenu: Text('Il ne sera plus proposé. Les listes déjà faites gardent leurs promotions.', style: Charte.texte(16)),
              plein: 'Garder',
              contour: 'Supprimer');
          if (ok == true) Etat.instance.supprimerTypePromotion(t);
        }, danger: true),
      ]);

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: EnTeteFenetre(
          retour: true,
          icone: Icons.local_offer_outlined,
          sousTitre: 'Gérer › Courses',
          titre: 'Types de promotion',
          aide: Aides.typesPromotion,
          actions: [
            ActionLigne(Icons.add, '+ Nouveau type', () async {
              final nom = await demanderTexte(context, titre: 'Nouveau type de promotion', aide: 'Nom (ex. : Bon de réduction)');
              if (nom == null || nom.isEmpty || !context.mounted) return;
              final code = await demanderTexte(context,
                  titre: 'Code court (3 caractères)', initial: nom.substring(0, nom.length < 3 ? nom.length : 3).toUpperCase());
              if (code == null || code.isEmpty) return;
              etat.ajouterTypePromotion(code.length > 4 ? code.substring(0, 4) : code, nom, '');
            }),
          ],
        ),
        corps: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final t in etat.typesPromotion)
              LigneMenu(
                titre: t.nom,
                sousTitre: 'code ${t.code}',
                onTap: () => _agir(context, t),
              ),
          ],
        ),
      ),
    );
  }
}

/// Petits cadres identiques, texte au centre, tous de la même couleur ; trois par ligne.
class GrilleCadres extends StatelessWidget {
  const GrilleCadres({super.key, required this.cadres, required this.couleur});
  final List<(String, VoidCallback)> cadres;
  final Color couleur;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final largeur = (c.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (texte, onTap) in cadres)
                SizedBox(
                  width: largeur,
                  height: 48,
                  child: Material(
                    color: Color.alphaBlend(couleur.withValues(alpha: 0.18), Charte.fond),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: couleur, width: 1.5)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(texte,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Charte.texte(14, gras: true)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

/// Petit carré de la couleur d'une famille de types (promotions, mesures, packagings).
class PastilleType extends StatelessWidget {
  const PastilleType(this.couleur, {super.key});
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Color.alphaBlend(couleur.withValues(alpha: 0.25), Charte.fond),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: couleur, width: 1.5),
        ),
      );
}

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Case à cocher d'une option, sur toute la largeur.
class _Option extends StatelessWidget {
  const _Option({required this.texte, required this.coche, required this.onChange});
  final String texte;

  // 02/11/2026 (Aristide) : les explications des options passent dans l'aide.
  final bool coche;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChange(!coche),
        child: Container(
          constraints: BoxConstraints(minHeight: Charte.ligneListe),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              CaseACocher(coche: coche, taille: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(texte, style: Charte.texte(16)),
              ),
            ],
          ),
        ),
      );
}


/// Gérer › Courses › Types de mesure (poids, volume, à la pièce…) ou Types de packaging (lots de 2 à 10…),
/// dans de petits cadres de la couleur choisie dans Gérer › Paramètres › Apparence.
class EcranTypesPackaging extends StatelessWidget {
  const EcranTypesPackaging({super.key, this.lots = true});

  /// Vrai : les packagings (lots) ; faux : les mesures.
  final bool lots;

  /// Actions sur un format : correction du libellé (pour tous ses articles), fusion, articles, suppression.
  Future<void> _agir(BuildContext context, Etat etat, String id) async {
    final k = etat.packaging(id);
    if (k == null) return;
    final n = etat.nbProduitsAvecPackaging(id);
    String? action;
    await menuActions(context, titre: k.libelle, actions: [
      ActionLigne(Icons.edit_outlined, 'Modifier le libellé (pour ses $n articles)', () => action = 'renommer'),
      ActionLigne(Icons.merge, 'Fusionner avec un autre', () => action = 'fusionner'),
      ActionLigne(Icons.list, 'Voir les $n articles', () => action = 'articles'),
      ActionLigne(Icons.delete_outline, 'Supprimer', () => action = 'supprimer', danger: true),
    ]);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'renommer':
        final nom = await demanderTexte(libelle: 'Libellé', context, titre: 'Libellé', initial: k.libelle, aide: lots ? 'Ex. : Lot de 4' : 'Ex. : 500 g, 75 cl');
        if (nom != null && nom.isNotEmpty) etat.renommerPackaging(id, nom);
      case 'fusionner':
        final autres = lots ? etat.typesLot : etat.typesMesure;
        final cible = await choisirDansListe<String>(context,
            titre: 'Remplacer « ${k.libelle} » par', choix: {for (final x in autres) if (x != id) x: etat.packaging(x)?.libelle ?? ''});
        if (cible != null) etat.fusionnerPackaging(id, cible);
      case 'articles':
        await modale(
          context,
          titre: '${k.libelle} · $n articles',
          icone: lots ? Icons.inventory_2_outlined : Icons.scale_outlined,
          oui: null,
          non: null,
          contenu: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in etat.produitsAvecPackaging(id))
                Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(p.nom, style: Charte.texte(15))),
            ],
          ),
        );
      case 'supprimer':
        final ok = await confirmer(context,
            titre: 'Supprimer « ${k.libelle} » ?',
            contenu: Text('Il ne sera plus proposé pour ses $n articles. Les listes déjà faites le gardent.', style: Charte.texte(16)),
            plein: 'Garder',
            contour: 'Supprimer');
        if (ok == true) etat.supprimerPackaging(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final ids = lots ? etat.typesLot : etat.typesMesure;
        return PageBase(
          entete: EnTeteFenetre(
              retour: true,
              icone: lots ? Icons.inventory_2_outlined : Icons.scale_outlined,
              sousTitre: 'Gérer › Courses',
              titre: lots ? 'Types de packaging' : 'Types de mesure',
              aide: lots ? Aides.typesPackaging : Aides.typesMesure,
              actions: [
                ActionLigne(Icons.add, lots ? '+ Nouveau packaging' : '+ Nouvelle mesure', () async {
                  final nom = await demanderTexte(libelle: 'Libellé', context,
                      titre: lots ? 'Nouveau packaging' : 'Nouvelle mesure', aide: lots ? 'Ex. : Lot de 12' : 'Ex. : 500 g, 75 cl');
                  if (nom == null || nom.isEmpty) return;
                  // Un packaging est un lot : « 12 » devient « Lot de 12 ».
                  final libelle = lots && !Etat.estLot(nom) ? 'Lot de ${nom.replaceFirst(RegExp(r'^de\s+', caseSensitive: false), '')}' : nom;
                  etat.ajouterTypePackaging(libelle);
                  etat.trierTypesPackaging();
                }),
              ]),
          corps: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final id in ids)
                if (etat.packaging(id) case final k?)
                  LigneMenu(
                    titre: k.libelle,
                    sousTitre: _pluriel(etat.nbProduitsAvecPackaging(id), 'article'),
                    onTap: () => _agir(context, etat, id),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Pastille d'une palette : ses teintes, du plus foncé au plus pâle, et son nom.
/// Échantillon d'une palette : ses quatre niveaux, du plus foncé au plus clair (ceux de [Charte.niveau]).
class _Echantillon extends StatelessWidget {
  const _Echantillon(this.palette);
  final Palette palette;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: palette.accent)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // 02/11/2026 (Aristide) : sans la teinte sombre, les quatre niveaux clairs des bandeaux.
            for (final t in const [0.82, 0.88, 0.93, 0.97]) Container(width: 22, height: 22, color: Color.lerp(palette.accentFonce, Charte.blanc, t)),
          ]),
        ),
      );
}

/// Journal de l'appareil : à copier pour Claude quand des données semblent perdues.
Future<void> _journal(BuildContext context) async {
  final lignes = Etat.instance.journalAppareil;
  final copier = await confirmer(
    context,
    titre: 'Journal de l\'appareil',
    icone: Icons.receipt_long_outlined,
    contenu: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: SelectableText(lignes.isEmpty ? 'Rien encore.' : lignes.take(60).join('\n\n'),
            style: Charte.texte(12, couleur: Charte.texteSecondaire)),
      ),
    ),
    plein: 'Fermer',
    contour: 'Copier',
  );
  if (copier == true) await Clipboard.setData(ClipboardData(text: lignes.join('\n')));
}
