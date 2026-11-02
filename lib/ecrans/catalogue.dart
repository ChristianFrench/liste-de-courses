import '../composants/icone.dart';
import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart' show Pictogramme, cleRayon, cleSecteur;
import '../composants/signe_perso.dart';
import '../donnees/modele.dart';
import '../donnees/univers.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';
import 'listes.dart';
import 'magasin.dart';

// Gérer › Courses : Magasins (et leurs parcours), Catalogue (unique pour le foyer), Marques.

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Rayon puis secteur du catalogue. Rend null si on abandonne, `(null,)` pour « ne pas ranger »
/// (seulement avec [sansSecteur]).
Future<(Secteur?,)?> choisirSecteur(BuildContext context, {required String titre, bool sansSecteur = false}) {
  final etat = Etat.instance;
  String? ouvert;
  return showModalBottomSheet<(Secteur?,)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Charte.blanc,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, defilement) => ListView(
          controller: defilement,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text('Où ranger « $titre » ? Choisissez le rayon, puis le secteur.', style: Charte.texte(17, gras: true)),
            ),
            for (final r in etat.rayonsVisibles) ...[
              TitreGroupe(
                nom: r.nom,
                image: cleRayon(r.nom),
                icone: Icons.view_week_outlined,
                fort: true,
                ouvert: ouvert == r.id,
                onTap: () => maj(() => ouvert = ouvert == r.id ? null : r.id),
              ),
              if (ouvert == r.id)
                for (final s in etat.secteursVisibles(r.id))
                  TitreGroupe(nom: s.nom, image: cleSecteur(r.nom, s.nom), onTap: () => Navigator.of(ctx).pop((s,))),
            ],
            if (sansSecteur)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Bouton(texte: 'Ne pas ranger', taille: 16, onTap: () => Navigator.of(ctx).pop((null,))),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// Nouveau produit depuis la recherche d'une liste : une seule fenêtre, rayon et secteur compris
/// (« Ne pas ranger » possible). Rend le produit créé, ou null.
Future<Produit?> nouveauProduit(BuildContext context, {Secteur? secteur, String? nom}) =>
    fenetreProduit(context, secteur: secteur, libelle: nom, ranger: secteur == null);

const _autreMarque = '\u0000autre';

/// Range un produit non placé (ou le déplace) : rayon et secteur, les mêmes dans tous les magasins.
Future<bool> placerProduit(BuildContext context, Produit p) async {
  final etat = Etat.instance;
  final actuel = etat.secteurCatalogue(p.id);
  final rayons = [for (final r in etat.rayonsVisibles) if (etat.secteursVisibles(r.id).isNotEmpty) r];
  if (rayons.isEmpty) return false;
  var rayonId = actuel?.rayonId ?? rayons.first.id;
  var secteurId = actuel?.id ?? etat.secteursVisibles(rayonId).first.id;
  final libelle = TextEditingController(text: p.nom);
  final ok = await modale(
    context,
    titre: 'Placer le produit',
    oui: 'Placer',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('placer-libelle'),
          controller: libelle,
          style: Charte.texte(17),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Libellé'),
        ),
        const SizedBox(height: 14),
        ChoixDeroulant<String>(
          key: const ValueKey('placer-rayon'),
          libelle: 'Rayon',
          valeur: rayonId,
          choix: {for (final r in rayons) r.id: r.nom},
          onChange: (v) => maj(() {
            rayonId = v;
            secteurId = etat.secteursVisibles(v).first.id;
          }),
        ),
        const SizedBox(height: 14),
        ChoixDeroulant<String>(
          key: const ValueKey('placer-secteur'),
          libelle: 'Secteur',
          valeur: secteurId,
          choix: {for (final x in etat.secteursVisibles(rayonId)) x.id: x.nom},
          onChange: (v) => maj(() => secteurId = v),
        ),
        const SizedBox(height: 8),
        Text('Le même rangement dans tous les magasins.', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ],
    ),
  );
  if (!ok) return false;
  final n = libelle.text.trim();
  if (n.isNotEmpty && n != p.nom) etat.renommerProduit(p, n);
  etat.placer(etat.rayon(rayonId)!.magasinId, p.id, secteurId);
  return true;
}

/// Renomme un article d'une liste ou le range ailleurs (30/10/2026) : un nouveau produit, partagé avec tous
/// les foyers, prend sa place dans la liste ; l'ancien reste au catalogue.
Future<void> modifierArticle(BuildContext context, Liste l, Produit p) async {
  final etat = Etat.instance;
  final actuel = etat.secteurCatalogue(p.id);
  final rayons = [for (final r in etat.rayonsVisibles) if (etat.secteursVisibles(r.id).isNotEmpty) r];
  if (rayons.isEmpty) return;
  var rayonId = rayons.any((r) => r.id == actuel?.rayonId) ? actuel!.rayonId : rayons.first.id;
  var secteurId = etat.secteursVisibles(rayonId).any((s) => s.id == actuel?.id) ? actuel!.id : etat.secteursVisibles(rayonId).first.id;
  final libelle = TextEditingController(text: p.nom);
  final ok = await modale(
    context,
    titre: 'Nom, rayon, secteur',
    oui: 'Valider',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('article-libelle'),
          controller: libelle,
          style: Charte.texte(17),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Libellé'),
        ),
        const SizedBox(height: 14),
        ChoixDeroulant<String>(
          key: const ValueKey('article-rayon'),
          libelle: 'Rayon',
          valeur: rayonId,
          choix: {for (final r in rayons) r.id: r.nom},
          onChange: (v) => maj(() {
            rayonId = v;
            secteurId = etat.secteursVisibles(v).first.id;
          }),
        ),
        const SizedBox(height: 14),
        ChoixDeroulant<String>(
          key: const ValueKey('article-secteur'),
          libelle: 'Secteur',
          valeur: secteurId,
          choix: {for (final x in etat.secteursVisibles(rayonId)) x.id: x.nom},
          onChange: (v) => maj(() => secteurId = v),
        ),
        const SizedBox(height: 8),
        Text('Un nouveau produit prend sa place dans la liste et rejoint le catalogue de tous les foyers ; '
            '« ${p.nom} » reste au catalogue.', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ],
    ),
  );
  if (!ok) return;
  final q = etat.remplacerArticle(l, p, libelle.text, etat.secteur(secteurId));
  if (q.id != p.id && context.mounted) Nav.message(context, '« ${q.nom} » remplace « ${p.nom} » dans la liste');
}

/// Renomme un produit (libellé seul, le rangement ne change pas).
Future<void> renommerProduit(BuildContext context, Produit p) async {
  final n = await demanderTexte(context, titre: 'Renommer le produit', libelle: 'Libellé', initial: p.nom);
  if (n != null && n.trim().isNotEmpty) Etat.instance.renommerProduit(p, n);
}

/// Actions sur un non placé ou un produit ajouté par le foyer : le placer (ou le déplacer), le renommer,
/// le supprimer. Depuis une liste ([liste]), « Supprimer » retire la ligne (ce n'était pas un produit) et
/// supprime le produit s'il n'est dans aucune autre liste.
List<ActionLigne> actionsNonPlace(BuildContext context, Produit p, {Liste? liste}) {
  final etat = Etat.instance;
  final place = etat.secteurCatalogue(p.id) != null;
  return [
    ActionLigne(Icons.place_outlined, place ? 'Déplacer dans un autre secteur' : 'Placer dans un rayon et un secteur',
        () => placerProduit(context, p)),
    ActionLigne(Icons.edit_outlined, 'Renommer', () => renommerProduit(context, p)),
    ActionLigne(Icons.delete_outline, liste == null ? 'Supprimer' : 'Supprimer (ce n\'est pas un produit)', () async {
      if (liste == null) {
        await demanderSuppression(context, p, 'le produit ${p.nom}');
        return;
      }
      etat.quantite(liste, p.id, 0);
      final aussi = !etat.produitUtilise(p) && etat.estAjoute(p);
      if (aussi) etat.supprimer(p);
      if (context.mounted) {
        Nav.message(context, aussi ? '« ${p.nom} » retiré de la liste et supprimé (dans la corbeille)' : '« ${p.nom} » retiré de la liste');
      }
    }, danger: true),
  ];
}

/// « Non placé » touché dans une liste : choisir l'article, puis le placer, le renommer ou le supprimer.
Future<void> placerNonPlaces(BuildContext context, List<Produit> produits, {Liste? liste}) async {
  if (produits.isEmpty) return;
  final p = produits.length == 1
      ? produits.single
      : await choisirDansListe<Produit>(context, titre: 'Quel article ?', choix: {for (final x in produits) x: x.nom});
  if (p != null && context.mounted) await menuActions(context, titre: p.nom, actions: actionsNonPlace(context, p, liste: liste));
}

/// Toutes les marques du catalogue des marques (tous secteurs), et celles déjà portées par des produits.
List<String> marquesDuCatalogue() {
  final etat = Etat.instance;
  final res = <String, String>{};
  for (final r in etat.rayonsVisibles) {
    for (final x in etat.secteursVisibles(r.id)) {
      for (final n in etat.marquesDuSecteur(x)) {
        res.putIfAbsent(n.toLowerCase(), () => n);
      }
    }
  }
  for (final m in etat.marques) {
    res.putIfAbsent(m.nom.toLowerCase(), () => m.nom);
  }
  return res.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// « Autre marque… » : une marque prise dans tout le catalogue des marques (proposée dès les premières
/// lettres), ou une nouvelle. Elle est ajoutée aux marques de [secteur]. Rend son nom, ou null.
Future<String?> autreMarque(BuildContext context, Secteur? secteur) async {
  final toutes = marquesDuCatalogue();
  var saisie = '';
  final n = await volet<String>(
    context,
    builder: (ctx) => corpsVolet(
      titre: 'Autre marque',
      contenu: Autocomplete<String>(
        optionsBuilder: (v) {
          final t = v.text.trim().toLowerCase();
          if (t.isEmpty) return const <String>[];
          return [
            for (final m in toutes) if (m.toLowerCase().startsWith(t)) m,
            for (final m in toutes) if (!m.toLowerCase().startsWith(t) && m.toLowerCase().contains(t)) m,
          ];
        },
        onSelected: (v) => Navigator.of(ctx).pop(v),
        fieldViewBuilder: (context, c, focus, valider) => TextField(
          key: const ValueKey('autre-marque'),
          controller: c,
          focusNode: focus,
          autofocus: true,
          style: Charte.texte(16),
          onChanged: (v) => saisie = v,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          decoration: InputDecoration(
            labelText: 'Marque',
            hintText: secteur == null ? 'Tapez les premières lettres' : 'Ajoutée aux marques du secteur ${secteur.nom}',
          ),
        ),
      ),
      boutons: [
        Row(children: [
          Expanded(child: Bouton(texte: 'Annuler', onTap: () => Navigator.of(ctx).pop())),
          const SizedBox(width: 10),
          Expanded(child: Bouton(texte: 'Valider', plein: true, onTap: () => Navigator.of(ctx).pop(saisie.trim()))),
        ]),
      ],
    ),
  );
  if (n == null || n.trim().isEmpty) return null;
  // Écrite autrement qu'une marque connue (« president ») : on garde l'orthographe du catalogue.
  final nom = toutes.firstWhere((m) => m.toLowerCase() == n.trim().toLowerCase(), orElse: () => n.trim());
  if (secteur != null) Etat.instance.ajouterMarqueSecteur(secteur, nom);
  return nom;
}

/// Fenêtre d'un produit ajouté (avec une croix) : libellé, marque éventuelle, mesure et packaging.
/// Sans [produit] : crée le produit dans [secteur] ; avec [produit] (ajouté par le foyer) : le corrige.
/// Le produit s'appelle toujours « libellé marque » (« Camembert Président »).
/// [ranger] : le rayon et le secteur se choisissent dans la fenêtre.
Future<Produit?> fenetreProduit(BuildContext context,
    {Produit? produit, Secteur? secteur, String? libelle, String? marque, bool ranger = false}) async {
  final etat = Etat.instance;
  String rayonId = secteur?.rayonId ?? '';
  String secteurId = secteur?.id ?? '';
  Secteur? choisi() => ranger ? (secteurId.isEmpty ? null : etat.secteur(secteurId)) : secteur;
  final nom = TextEditingController(text: produit == null ? (libelle ?? '') : etat.libelleSansMarque(produit));
  final mq = TextEditingController(
      text: produit == null ? (marque ?? '') : (produit.marqueIds.isEmpty ? '' : etat.marque(produit.marqueIds.first)?.nom ?? ''));
  final (m0, l0) = Etat.mesureEtLot(produit == null || produit.packagingIds.isEmpty ? null : etat.packaging(produit.packagingIds.first)?.libelle);
  String? mesure = m0;
  String? lot = l0;
  final mesures = <String>{for (final id in etat.typesMesure) etat.packaging(id)!.libelle, if (m0 != null) m0}.toList();
  final lots = <String>{for (final id in etat.typesLot) etat.packaging(id)!.libelle, if (l0 != null) l0}.toList();
  final ok = await modale(
    context,
    titre: produit == null ? 'Nouveau produit${secteur == null || ranger ? '' : ' · ${secteur.nom}'}' : 'Modifier le produit',
    icone: Icons.shopping_basket_outlined,
    oui: produit == null ? 'Ajouter' : 'Enregistrer',
    non: null,
    croix: true,
    contenu: (context, maj) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le nom retenu, en haut, sans saisie : il suit le nom et la marque tapés dessous.
          Container(
            key: const ValueKey('produit-nom-retenu'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Charte.fondBandeau, borderRadius: BorderRadius.circular(8)),
            child: Text(
              nom.text.trim().isEmpty ? 'Nom du produit' : [nom.text.trim(), mq.text.trim()].where((x) => x.isNotEmpty).join(' '),
              style: Charte.texte(18, gras: true, couleur: nom.text.trim().isEmpty ? Charte.texteSecondaire : Charte.encre),
            ),
          ),
          if (ranger) ...[
            const SizedBox(height: 16),
            ChoixDeroulant<String>(
              key: const ValueKey('produit-rayon'),
              libelle: 'Rayon',
              valeur: rayonId,
              choix: {'': 'Ne pas ranger', for (final r in etat.rayonsVisibles) r.id: r.nom},
              onChange: (v) => maj(() {
                rayonId = v;
                secteurId = v.isEmpty ? '' : etat.secteursVisibles(v).first.id;
              }),
            ),
            if (rayonId.isNotEmpty) ...[
              const SizedBox(height: 14),
              ChoixDeroulant<String>(
                key: const ValueKey('produit-secteur'),
                libelle: 'Secteur',
                valeur: secteurId,
                choix: {for (final x in etat.secteursVisibles(rayonId)) x.id: x.nom},
                onChange: (v) => maj(() => secteurId = v),
              ),
            ],
          ],
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('produit-nom'),
            controller: nom,
            autofocus: produit == null && (libelle ?? '').isEmpty,
            style: Charte.texte(17),
            onChanged: (_) => maj(() {}),
            decoration: const InputDecoration(labelText: 'Nom (ex. : Camembert)'),
          ),
          const SizedBox(height: 14),
          // La marque se choisit dans le catalogue des marques du secteur (toutes, sans secteur) ;
          // « Autre marque… » en ajoute une au secteur.
          ChoixDeroulant<String>(
            key: const ValueKey('produit-marque'),
            libelle: 'Marque (facultative)',
            valeur: mq.text,
            choix: {
              '': 'Aucune',
              for (final n in {
                ...(choisi() == null ? etat.marquesTriees.map((m) => m.nom) : etat.marquesDuSecteur(choisi()!)),
                if (mq.text.isNotEmpty) mq.text,
              })
                n: n,
              _autreMarque: 'Autre marque…',
            },
            onChange: (v) async {
              if (v != _autreMarque) return maj(() => mq.text = v);
              final n = await autreMarque(context, choisi());
              if (n != null) maj(() => mq.text = n);
            },
          ),
          // Les mesures sont nombreuses : une liste déroulante.
          const SizedBox(height: 14),
          ChoixDeroulant<String>(
            libelle: 'Mesure',
            valeur: mesure ?? '',
            choix: {'': 'Aucune', for (final m in mesures) m: m},
            onChange: (v) => maj(() => mesure = v.isEmpty ? null : v),
          ),
          const SizedBox(height: 14),
          ChoixDeroulant<String>(
            key: const ValueKey('produit-packaging'),
            libelle: 'Packaging',
            valeur: lot ?? '',
            choix: {'': 'Aucun', for (final x in lots) x: x},
            onChange: (v) => maj(() => lot = v.isEmpty ? null : v),
          ),
        ],
      );
    },
  );
  if (!ok || !context.mounted) return null;
  final n = nom.text.trim();
  if (n.isEmpty) {
    Nav.message(context, 'Le produit n\'a pas de nom : rien n\'est enregistré');
    return null;
  }
  if (ranger) secteur = secteurId.isEmpty ? null : etat.secteur(secteurId);
  final complet = [n, mq.text.trim()].where((x) => x.isNotEmpty).join(' ').toLowerCase();
  // Le même nom peut exister dans un autre secteur, pas deux fois dans le même.
  final ici = secteur ?? (produit == null ? null : etat.secteurCatalogue(produit.id));
  bool memePlace(Produit p) {
    if (ici == null) return true;
    final c = etat.secteurCatalogue(p.id);
    return c != null && c.nom == ici.nom && etat.rayon(c.rayonId)?.nom == etat.rayon(ici.rayonId)?.nom;
  }

  final existant = etat.produits.where((p) => p.id != produit?.id && p.nom.toLowerCase() == complet && memePlace(p)).firstOrNull;
  if (existant != null) {
    Nav.message(context, '« ${existant.nom} » est déjà dans ${ici == null ? 'le catalogue' : 'ce secteur'}');
    return produit == null ? existant : null;
  }
  return etat.enregistrerProduitAjoute(produit: produit, libelle: n, marqueNom: mq.text, mesure: mesure, lot: lot, secteur: secteur);
}

/// Où se trouve le produit dans le catalogue, en clair.
String rangement(Produit p) {
  final etat = Etat.instance;
  final s = etat.secteurCatalogue(p.id);
  return s == null ? 'Non rangé' : '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}';
}

/// Ligne d'un produit du catalogue : ses marques dessous, ses mesures et packagings dans leurs cadres à droite ;
/// la toucher ouvre ses actions dans un volet (02/11/2026, Aristide : plus de page pour les voir).
LigneMenu ligneProduit(BuildContext context, Produit p, {bool avecRangement = false, Color? fond}) {
  final etat = Etat.instance;
  final packs = p.packagingIds;
  final marques = [for (final id in p.marqueIds) etat.marque(id)?.nom ?? ''].where((x) => x.isNotEmpty).join(', ');
  return LigneMenu(
    fond: fond,
    titre: p.nom,
    // 01/11/2026 (Aristide) : pas d'icône sur les produits.
    apresTitre: SignePerso(p),
    sousTitre: avecRangement ? rangement(p) : (marques.isEmpty ? (packs.isEmpty ? 'à compléter' : null) : marques),
    droite: packs.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final id in packs.take(2))
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Pastille(etat.packaging(id)?.libelle ?? '', petite: true, couleur: Color(etat.couleurPack(id) ?? etat.couleurMesures)),
                ),
              if (packs.length > 2) Padding(padding: const EdgeInsets.only(left: 4), child: Text('+${packs.length - 2}', style: Charte.texte(13))),
            ]),
          ),
    onTap: () => menuActions(context, titre: p.nom, actions: actionsProduit(context, p)),
  );
}


// ------------------------------------------------------------ Magasins

/// Gérer › Courses › Magasins : les magasins du foyer ; chacun ouvre ses parcours.
class EcranMagasins extends StatelessWidget {
  const EcranMagasins({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: EnTeteFenetre(
          retour: true,
          icone: Icons.storefront_outlined,
          sousTitre: 'Gérer › Courses',
          titre: 'Magasins',
          aide: Aides.magasins,
          actions: [
            ActionLigne(Icons.add, '+ Nouveau magasin', () async {
              final m = await creerMagasinDemande(context);
              if (m != null && context.mounted) Nav.aller<void>(context, EcranMagasin(magasinId: m.id));
            }),
          ],
        ),
        corps: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final m in etat.magasins)
              Glissable(
                key: ValueKey('glisser-${m.id}'),
                titre: m.nom,
                versGauche: ActionLigne(Icons.delete_outline, 'Supprimer', () => demanderSuppression(context, m, 'le magasin ${m.nom}'), danger: true),
                actions: [
                  ActionLigne(Icons.delete_outline, 'Supprimer le magasin', () => demanderSuppression(context, m, 'le magasin ${m.nom}'), danger: true),
                ],
                child: LigneMenu(
                  titre: m.nom,
                  sousTitre: '${_pluriel(etat.parcours.where((p) => p.magasinId == m.id).length, 'parcours')} · '
                      '${_pluriel(etat.listesDuMagasin(m.id).length, 'liste')} en cours',
                  onTap: () => Nav.aller<void>(context, EcranMagasin(magasinId: m.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un magasin : ses parcours ; le renommer, le supprimer.
class EcranMagasin extends StatelessWidget {
  const EcranMagasin({super.key, required this.magasinId});
  final String magasinId;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final m = etat.magasin(magasinId);
        if (m == null) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, icone: Icons.storefront_outlined, titre: 'Magasin'),
            corps: Center(child: Text('Ce magasin n\'existe plus.', style: Charte.texte(16))),
          );
        }
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.storefront_outlined,
            sousTitre: 'Gérer › Courses › Magasins',
            titre: m.nom,
            aide: Aides.parcours,
            actions: [
              ActionLigne(Icons.edit_outlined, 'Renommer le magasin', () async {
                final nom = await demanderTexte(context, titre: 'Nom du magasin', initial: m.nom);
                if (nom == null || nom.isEmpty || !context.mounted) return;
                if (etat.magasinNomme(nom) case final autre? when autre.id != m.id) {
                  Nav.message(context, 'Un magasin s\'appelle déjà « $nom »');
                  return;
                }
                etat.renommerMagasin(m, nom);
              }),
              ActionLigne(Icons.local_mall_outlined, 'Enseigne : ${etat.enseigneDe(m) ?? 'aucune'}', () async {
                final e = await choisirDansListe<String>(context,
                    titre: 'Enseigne (marques distributeur)', choix: {'': 'Aucune', for (final x in etat.enseignesMdd) x: x});
                if (e != null) etat.definirEnseigne(m, e.isEmpty ? '-' : e);
              }),
              ActionLigne(Icons.delete_outline, 'Supprimer le magasin', () async {
                if (await demanderSuppression(context, m, 'le magasin ${m.nom}') && context.mounted) Navigator.of(context).pop();
              }, danger: true),
            ],
          ),
          corps: SousEcranParcours(magasinId: m.id),
        );
      },
    );
  }
}

// ------------------------------------------------------------ Catalogue

/// Gérer › Courses › Catalogue : le catalogue unique du foyer, par rayon et secteur, avec une recherche.
class EcranCatalogue extends StatefulWidget {
  const EcranCatalogue({super.key});

  @override
  State<EcranCatalogue> createState() => _EcranCatalogueState();
}

class _EcranCatalogueState extends State<EcranCatalogue> {
  String recherche = '';

  /// Secteur déplié (un seul à la fois) : ses produits s'affichent sous lui, à modifier sur place.
  String? _secteurOuvert;

  static String _cleU(String u) => 'catalogue-univers/$u';
  static String _cleR(Rayon r) => 'catalogue/${r.nom}';

  /// Arborescence comme dans les autres listes (02/11/2026, Aristide) : univers, rayons, secteurs et produits aux
  /// quatre niveaux de la palette, sans retrait à gauche ; grande icône en débord au premier plan (un toucher long
  /// sur celle d'un rayon ou d'un secteur choisit une image de la bibliothèque) ; un crayon à chaque niveau ouvre
  /// ses actions dans un volet.
  List<Widget> _arbre(BuildContext context, Map<String, List<Rayon>> parUnivers) {
    final etat = Etat.instance;
    final plis = Retractables.i;
    final res = <Widget>[];
    for (final MapEntry(key: u, value: rayonsU) in parUnivers.entries) {
      final uOuvert = plis.ouvert(_cleU(u));
      final rayons = <Widget>[];
      if (uOuvert) {
        for (final x in rayonsU) {
          final rOuvert = plis.ouvert(_cleR(x), parDefaut: false);
          final secteurs = <Widget>[];
          if (rOuvert) {
            for (final sec in etat.secteursVisibles(x.id)) {
              final ouvert = _secteurOuvert == sec.id;
              final produits = etat.produitsDuSecteur(sec);
              produits.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
              secteurs.add(NiveauArbre(
                cle: 'secteur-${sec.id}',
                niveau: 3,
                nom: sec.nom,
                signe: Pictogramme(cleSecteur(x.nom, sec.nom), taille: 40),
                surSigneLong: () => choisirImageSecteur(context, x.nom, sec.nom),
                ajoute: etat.secteurAjoute(sec),
                nombre: produits.length,
                ouvert: ouvert,
                onTap: () => setState(() => _secteurOuvert = ouvert ? null : sec.id),
                onCrayon: () => menuActions(context, titre: sec.nom, actions: actionsSecteur(context, sec)),
                // 02/11/2026 (Aristide) : tout à droite, les marques du secteur.
                droite: IconButton(
                  key: ValueKey('marques-secteur-${sec.id}'),
                  tooltip: 'Marques de ${sec.nom}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => menuActions(context, titre: 'Marques · ${sec.nom}', actions: [
                    for (final n in etat.marquesDuSecteur(sec))
                      ActionLigne(Icons.sell_outlined, n, () => fenetreMarque(context, secteur: sec, nom: n)),
                    ActionLigne(Icons.add, '+ Nouvelle marque', () => fenetreMarque(context, secteur: sec)),
                  ]),
                  icon: Icone(Icons.sell_outlined, size: 24),
                ),
                enfants: [for (final p in produits) FeuilleArbre(child: ligneProduit(context, p, fond: Charte.niveau(4)))],
              ));
            }
          }
          rayons.add(NiveauArbre(
            cle: 'rayon-${x.nom}',
            niveau: 2,
            nom: x.nom,
            signe: Pictogramme(cleRayon(x.nom), taille: 40),
            surSigneLong: () => choisirImageRayon(context, x.nom),
            ajoute: etat.rayonAjoute(x),
            nombre: etat.secteursVisibles(x.id).length,
            ouvert: rOuvert,
            onTap: () => plis.basculer(_cleR(x), parDefaut: false),
            onCrayon: () => menuActions(context, titre: x.nom, actions: _actionsRayon(context, x)),
            enfants: secteurs,
          ));
        }
      }
      res.add(NiveauArbre(
        cle: 'univers-$u',
        niveau: 1,
        nom: u,
        signe: Icone(apparenceUnivers[u]?.$1 ?? Icons.storefront_outlined, size: 40, color: Charte.encreNiveau),
        nombre: rayonsU.length,
        ouvert: uOuvert,
        onTap: () => plis.basculer(_cleU(u)),
        onCrayon: () => menuActions(context, titre: u, actions: [
          ActionLigne(Icons.add, '+ Nouveau rayon', () => _nouveauRayon(context)),
          ActionLigne(Icons.drag_handle, 'Déplacer les rayons', () => _deplacerRayons(context)),
        ]),
        enfants: rayons,
      ));
    }
    return res;
  }

  List<ActionLigne> _actionsRayon(BuildContext context, Rayon x) {
    final etat = Etat.instance;
    return [
      ActionLigne(Icons.add, '+ Nouveau secteur', () => _nouveauSecteur(context, x)),
      if (etat.secteursVisibles(x.id).length > 1)
        ActionLigne(Icons.drag_handle, 'Changer l\'ordre des secteurs', () async {
          final noms = await ordonner(context, titre: 'Ordre des secteurs · ${x.nom}', noms: [for (final s in etat.secteursVisibles(x.id)) s.nom]);
          if (noms != null) etat.ordonnerSecteursCatalogue(x, noms);
        }),
      if (etat.rayonAjoute(x)) ActionLigne(Icons.edit_outlined, 'Renommer le rayon', () => _renommerRayon(context, x)),
      ActionLigne(Icons.storefront_outlined, 'Changer d\'univers', () async {
          final u = await choisirDansListe<String>(context, titre: 'Univers du rayon « ${x.nom} »', choix: {for (final u in universDesRayons.keys) u: u});
          if (u != null) etat.changerUniversRayon(x, u);
        }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([etat, Retractables.i]),
      builder: (context, _) {
        final r = recherche.toLowerCase();
        bool garde(Produit p) =>
            p.nom.toLowerCase().contains(r) || p.marqueIds.any((id) => (etat.marque(id)?.nom.toLowerCase() ?? '').contains(r));
        final trouves = r.length < 2 ? <Produit>[] : ([for (final p in etat.produitsVisibles) if (garde(p)) p]..sort((a, b) => a.nom.compareTo(b.nom)));
        final nonRanges = [for (final p in etat.produitsVisibles) if (etat.secteurCatalogue(p.id) == null) p]..sort((a, b) => a.nom.compareTo(b.nom));
        final perso = etat.produitsAjoutes.length;
        final parUnivers = <String, List<Rayon>>{
          for (final u in [...universDesRayons.keys, autresRayons])
            if (_rayonsRanges(etat).where((x) => universDuRayon(x.nom, etat.universRayons) == u).toList() case final l when l.isNotEmpty) u: l,
        };
        final plis = Retractables.i;
        final cles = [for (final e in parUnivers.entries) ...[_cleU(e.key), for (final x in e.value) _cleR(x)]];
        final toutOuvert = cles.every((c) => plis.ouvert(c, parDefaut: c.startsWith('catalogue-univers/')));
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.menu_book_outlined,
            sousTitre: 'Gérer › Courses',
            titre: 'Catalogue',
            aide: Aides.catalogue,
            actions: [
              ActionLigne(Icons.add, '+ Nouveau rayon', () => _nouveauRayon(context)),
              ActionLigne(Icons.drag_handle, 'Déplacer les rayons', () => _deplacerRayons(context)),
              ActionLigne(Icons.edit_outlined, 'Produits ajoutés ($perso)', () => Nav.aller<void>(context, const EcranProduitsPerso())),
            ],
            droite: boutonEnTete(toutOuvert ? Icons.unfold_less : Icons.unfold_more, toutOuvert ? 'Tout replier' : 'Tout déplier', () {
              plis.tous(cles, !toutOuvert);
              if (toutOuvert) setState(() => _secteurOuvert = null);
            }),
          ),
          haut: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const ValueKey('catalogue-recherche'),
                style: Charte.texte(16),
                decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Un produit, une marque…'),
                onChanged: (v) => setState(() => recherche = v.trim()),
              ),
            ),
            Container(height: 1, color: Charte.separateurZone),
          ],
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: r.length >= 2
                ? [
                    if (trouves.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Aucun produit ne correspond.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                      ),
                    for (final p in trouves) ligneProduit(context, p, avecRangement: true),
                  ]
                : [
                    ColonneDebord(children: _arbre(context, parUnivers)),
                    if (nonRanges.isNotEmpty)
                      GroupeRetractable(
                        cle: 'catalogue/nonRanges',
                        titre: 'Non placés',
                        icone: Icons.help_outline,
                        nombre: nonRanges.length,
                        enfants: [
                          for (final p in nonRanges)
                            LigneMenu(
                              titre: p.nom,
                              icone: Icons.shopping_basket_outlined,
                              apresTitre: SignePerso(p),
                              sousTitre: 'Touchez pour le placer',
                              onTap: () => menuActions(context, titre: p.nom, actions: [
                                ...actionsNonPlace(context, p),
                                ActionLigne(Icons.info_outline, 'Voir la fiche', () => Nav.aller<void>(context, EcranFicheProduit(produitId: p.id))),
                              ]),
                            ),
                        ],
                      ),
                  ],
          ),
        );
      },
    );
  }
}

/// Un secteur du catalogue : ses produits.
class EcranSecteurCatalogue extends StatelessWidget {
  const EcranSecteurCatalogue({super.key, required this.secteurId});
  final String secteurId;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final s = etat.secteur(secteurId);
        if (s == null) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, icone: Icons.menu_book_outlined, titre: 'Secteur'),
            corps: Center(child: Text('Ce secteur n\'existe plus.', style: Charte.texte(16))),
          );
        }
        final produits = etat.produitsDuSecteur(s)..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.menu_book_outlined,
            sousTitre: 'Catalogue › ${etat.rayon(s.rayonId)?.nom ?? ''}',
            titre: s.nom,
            aide: Aides.catalogue,
            actions: actionsSecteur(context, s),
          ),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (produits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucun produit dans ce secteur.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              for (final p in produits) ligneProduit(context, p),
            ],
          ),
        );
      },
    );
  }
}

/// Actions d'un secteur du catalogue : nouveau produit ; le renommer s'il a été créé par le foyer. Supprimer est
/// réservé à l'éditeur du catalogue commun (30/10/2026) : le catalogue est celui de tous les foyers.
List<ActionLigne> actionsSecteur(BuildContext context, Secteur s) => [
      ActionLigne(Icons.add, '+ Nouveau produit', () async {
        final p = await fenetreProduit(context, secteur: s);
        if (p != null && context.mounted) Nav.message(context, '« ${p.nom} » ajouté au catalogue');
      }),
      if (Etat.instance.secteurAjoute(s)) ActionLigne(Icons.edit_outlined, 'Renommer le secteur', () => _renommerSecteur(context, s)),
    ];

/// Catalogue › Produits ajoutés : les produits que le foyer a ajoutés, à corriger (fenêtre du produit) ou supprimer.
class EcranProduitsPerso extends StatelessWidget {
  const EcranProduitsPerso({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final ajoutes = etat.produitsAjoutes;
        Future<void> modifier(Produit p) => fenetreProduit(context, produit: p, secteur: etat.secteurCatalogue(p.id));
        return PageBase(
          entete: const EnTeteFenetre(
              retour: true, icone: Icons.menu_book_outlined, sousTitre: 'Gérer › Courses › Catalogue', titre: 'Produits ajoutés', aide: Aides.catalogue),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (ajoutes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucun produit ajouté.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              for (final p in ajoutes)
                Glissable(
                  key: ValueKey('perso-${p.id}'),
                  titre: p.nom,
                  auToucher: true,
                  actions: [
                    ActionLigne(Icons.edit_outlined, 'Modifier', () => modifier(p)),
                  ],
                  child: LigneMenu(
                    titre: p.nom,
                    icone: Icons.shopping_basket_outlined,
                    sousTitre: [rangement(p), if (p.packagingIds.isNotEmpty) etat.packaging(p.packagingIds.first)?.libelle ?? '']
                        .join(' · '),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                    'Vos produits ajoutés rejoignent le catalogue de tous les foyers dès qu\'ils ont été achetés '
                    '(cochés dans des courses terminées). Touchez-en un pour le modifier. '
                    'Seul l\'éditeur du catalogue commun supprime un produit.',
                    style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ Marques

/// Gérer › Courses › Catalogue des marques (28/10/2026) : un seul écran, rangé comme le catalogue des produits.
/// Seuls les rayons et secteurs qui ont des marques paraissent, avec leur nombre ; sous chaque secteur, ses
/// marques (lignes de 40), puis « + Nouvelle marque ». Toucher une marque la modifie ; la poubelle ou un
/// glissement vers la gauche la retire du secteur.
class EcranMarques extends StatelessWidget {
  const EcranMarques({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final plis = Retractables.i;
    return ListenableBuilder(
      listenable: Listenable.merge([etat, plis]),
      builder: (context, _) {
        final enfants = <Widget>[];
        final cles = <String>[];
        for (final r in etat.rayonsVisibles) {
          final secteurs = [
            for (final s in etat.secteursVisibles(r.id))
              if (etat.marquesDuSecteur(s) case final noms when noms.isNotEmpty) (s, noms)
          ];
          if (secteurs.isEmpty) continue;
          // Rayons repliés au départ ; un rayon déployé montre ses secteurs, déployés au départ.
          final cleR = 'marques/r/${r.nom}';
          final rOuvert = plis.ouvert(cleR, parDefaut: false);
          cles.add(cleR);
          final lignes = <Widget>[];
          for (final (s, noms) in secteurs) {
            final cleS = 'marques/s/${r.nom}/${s.nom}';
            cles.add(cleS);
            if (!rOuvert) continue;
            final sOuvert = plis.ouvert(cleS);
            lignes.add(NiveauArbre(
              cle: 'secteur-marques-${s.nom}',
              niveau: 3,
              profondeur: 2,
              nom: s.nom,
              signe: Pictogramme(cleSecteur(r.nom, s.nom), taille: 40),
              nombre: noms.length,
              ouvert: sOuvert,
              onTap: () => plis.basculer(cleS),
              onCrayon: () => menuActions(context, titre: s.nom, actions: [
                ActionLigne(Icons.add, '+ Nouvelle marque', () => fenetreMarque(context, secteur: s)),
              ]),
              enfants: [
                for (final n in noms)
                  Glissable(
                    key: ValueKey('glisser-marque-${s.id}-$n'),
                    titre: n,
                    versGauche: ActionLigne(Icons.delete_outline, 'Retirer', () => _retirer(context, s, n), danger: true),
                    child: FeuilleArbre(
                      profondeur: 3,
                      child: _LigneMarque(
                        key: ValueKey('marque-$n'),
                        nom: n,
                        detail: _produitsDeMarque(n),
                        onTap: () => fenetreMarque(context, secteur: s, nom: n),
                        onSupprimer: () => _retirer(context, s, n),
                      ),
                    ),
                  ),
                FeuilleArbre(
                  profondeur: 3,
                  child: _LigneMarque(
                    key: ValueKey('nouvelle-marque-${s.nom}'),
                    nom: '+ Nouvelle marque',
                    ajout: true,
                    onTap: () => fenetreMarque(context, secteur: s),
                  ),
                ),
              ],
            ));
          }
          enfants.add(NiveauArbre(
            cle: 'rayon-marques-${r.nom}',
            niveau: 2,
            profondeur: 1,
            nom: r.nom,
            signe: Pictogramme(cleRayon(r.nom), taille: 40),
            ouvert: rOuvert,
            onTap: () => plis.basculer(cleR, parDefaut: false),
            nombre: {for (final (_, noms) in secteurs) ...noms.map((n) => n.toLowerCase())}.length,
            enfants: lignes,
          ));
        }
        // Marques distributeur : un rayon, un secteur par enseigne (proposées selon l'enseigne du magasin de la liste)
        if (etat.marquesDistributeur.isNotEmpty) {
          const cleR = 'marques/r/mdd';
          final rOuvert = plis.ouvert(cleR, parDefaut: false);
          cles.add(cleR);
          final lignes = <Widget>[];
          for (final e in etat.marquesDistributeur.entries) {
            final cleE = 'marques/s/mdd/${e.key}';
            cles.add(cleE);
            if (!rOuvert) continue;
            final eOuvert = plis.ouvert(cleE);
            lignes.add(NiveauArbre(
              cle: 'mdd-${e.key}',
              niveau: 3,
              profondeur: 2,
              nom: e.key,
              nombre: e.value.length,
              ouvert: eOuvert,
              onTap: () => plis.basculer(cleE),
              enfants: [
                for (final x in e.value) FeuilleArbre(profondeur: 3, child: _LigneMarque(nom: x.marque, detail: x.categorie, onTap: () {})),
              ],
            ));
          }
          enfants.add(NiveauArbre(
            cle: 'rayon-mdd',
            niveau: 2,
            profondeur: 1,
            nom: 'Marques distributeur',
            signe: Icone(Icons.local_mall_outlined, size: 40, color: Charte.encreNiveau),
            nombre: etat.marquesDistributeur.values.fold<int>(0, (n, l) => n + l.length),
            ouvert: rOuvert,
            onTap: () => plis.basculer(cleR, parDefaut: false),
            enfants: lignes,
          ));
        }
        // Rayons repliés par défaut, secteurs déployés : « tout déplier » les ouvre tous.
        final toutOuvert = cles.isNotEmpty &&
            cles.every((c) => plis.ouvert(c, parDefaut: !c.startsWith('marques/r/')));
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.sell_outlined,
            sousTitre: 'Gérer › Courses',
            titre: 'Catalogue des marques',
            aide: Aides.marques,
            actions: [ActionLigne(Icons.add, '+ Nouvelle marque', () => fenetreMarque(context))],
            droite: boutonEnTete(toutOuvert ? Icons.unfold_less : Icons.unfold_more, toutOuvert ? 'Tout replier' : 'Tout déplier',
                () => plis.tous(cles, !toutOuvert)),
          ),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: enfants.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Aucune marque : touchez le titre pour en ajouter une.',
                          style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                    ),
                  ]
                : [ColonneDebord(children: enfants)],
          ),
        );
      },
    );
  }

  static String? _produitsDeMarque(String nom) {
    final etat = Etat.instance;
    final m = etat.marques.where((m) => m.nom.toLowerCase() == nom.toLowerCase()).firstOrNull;
    final n = m == null ? 0 : etat.produitsDeMarque(m.id).length;
    return n == 0 ? null : _pluriel(n, 'produit');
  }

  static void _retirer(BuildContext context, Secteur s, String nom) {
    final etat = Etat.instance;
    etat.retirerMarqueSecteur(s, nom);
    Nav.message(context, '« $nom » retirée de ${s.nom}', annuler: () => etat.ajouterMarqueSecteur(s, nom));
  }
}

/// Ligne de 40 du catalogue des marques : le nom (et ses produits), la poubelle à droite.
class _LigneMarque extends StatelessWidget {
  const _LigneMarque({super.key, required this.nom, required this.onTap, this.onSupprimer, this.detail, this.ajout = false});
  final String nom;
  final String? detail;
  final bool ajout;
  final VoidCallback onTap;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) => Material(
        color: Charte.niveau(4),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: Charte.ligneListe,
            padding: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
            child: Row(children: [
              Expanded(
                child: Text(nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Charte.texte(16, couleur: ajout ? Charte.accent : Charte.encre, gras: ajout)),
              ),
              if (detail != null) Text(detail!, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
              if (onSupprimer != null)
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: onSupprimer,
                  icon: Icone(Icons.delete_outline, size: 22, color: Charte.couleurIcone(Icons.delete_outline)),
                ),
            ]),
          ),
        ),
      );
}

/// Volet de création ou de modification d'une marque : rayon, secteur du rayon, libellé.
/// En modification, un autre nom renomme la marque partout (ses produits aussi) ; un autre secteur l'y déplace.
Future<void> fenetreMarque(BuildContext context, {Secteur? secteur, String? nom}) async {
  final etat = Etat.instance;
  final rayons = [for (final r in etat.rayonsVisibles) if (etat.secteursVisibles(r.id).isNotEmpty) r];
  if (rayons.isEmpty) return;
  var rayonId = secteur?.rayonId ?? rayons.first.id;
  var secteurId = secteur?.id ?? etat.secteursVisibles(rayonId).first.id;
  final libelle = TextEditingController(text: nom ?? '');
  final ok = await modale(
    context,
    titre: nom == null ? 'Nouvelle marque' : 'Modifier la marque',
    oui: 'Valider',
    non: 'Annuler',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        ChoixDeroulant<String>(
          key: const ValueKey('marque-rayon'),
          libelle: 'Rayon',
          valeur: rayonId,
          choix: {for (final r in rayons) r.id: r.nom},
          onChange: (v) => maj(() {
            rayonId = v;
            secteurId = etat.secteursVisibles(v).first.id;
          }),
        ),
        const SizedBox(height: 14),
        ChoixDeroulant<String>(
          key: const ValueKey('marque-secteur'),
          libelle: 'Secteur',
          valeur: secteurId,
          choix: {for (final s in etat.secteursVisibles(rayonId)) s.id: s.nom},
          onChange: (v) => maj(() => secteurId = v),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('marque-libelle'),
          controller: libelle,
          autofocus: nom == null,
          style: Charte.texte(17),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Marque', hintText: 'Ex. : Président'),
        ),
      ],
    ),
  );
  final n = libelle.text.trim();
  final cible = etat.secteur(secteurId);
  if (!ok || n.isEmpty || cible == null) return;
  if (nom == null) {
    etat.ajouterMarqueSecteur(cible, n);
    return;
  }
  if (n != nom) etat.renommerMarqueCatalogue(nom, n);
  if (secteur != null && secteur.id != cible.id) {
    etat.retirerMarqueSecteur(secteur, n);
    etat.ajouterMarqueSecteur(cible, n);
  }
}

/// Petite icône d'un rayon ou d'un secteur ajouté par le foyer.
class SigneAjoute extends StatelessWidget {
  const SigneAjoute({super.key});

  @override
  Widget build(BuildContext context) =>
      Tooltip(message: 'Ajouté par le foyer', child: Text('+', style: Charte.texte(16, gras: true, couleur: Charte.accent)));
}

// ------------------------------------------------------------ Rayons et secteurs ajoutés (26/10/2026)

/// Rayons visibles, dans l'ordre choisi par le foyer (ceux qu'il n'a pas placés gardent leur ordre, à la suite).
List<Rayon> _rayonsRanges(Etat etat) {
  final l = etat.rayonsVisibles;
  if (etat.ordreRayons.isEmpty) return l;
  final rang = {for (var i = 0; i < etat.ordreRayons.length; i++) etat.ordreRayons[i]: i};
  final initial = {for (var i = 0; i < l.length; i++) l[i].nom: i};
  return [...l]..sort((a, b) => (rang[a.nom] ?? 100000 + initial[a.nom]!).compareTo(rang[b.nom] ?? 100000 + initial[b.nom]!));
}

/// Déplacer les rayons au doigt : dans leur univers ou sous un autre.
Future<void> _deplacerRayons(BuildContext context) async {
  final etat = Etat.instance;
  final groupes = <String, List<String>>{for (final u in [...universDesRayons.keys, autresRayons]) u: []};
  for (final r in _rayonsRanges(etat)) {
    groupes[universDuRayon(r.nom, etat.universRayons)]!.add(r.nom);
  }
  final res = await ordonnerParGroupes(context,
      titre: 'Déplacer les rayons', groupes: groupes, couleurs: {for (final e in apparenceUnivers.entries) e.key: e.value.$2});
  if (res != null) etat.rangerRayons(res);
}

Future<void> _nouveauRayon(BuildContext context) async {
  final etat = Etat.instance;
  final nom = await demanderTexte(context, titre: 'Nouveau rayon', aide: 'Animalerie, Bricolage…', valider: 'Suivant');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  final univers = await choisirDansListe<String>(context,
      titre: 'Univers du rayon « ${nom.trim()} »', choix: {for (final u in [...universDesRayons.keys, autresRayons]) u: u});
  if (univers == null || !context.mounted) return;
  final r = etat.ajouterRayonCatalogue(nom, univers: univers == autresRayons ? null : univers);
  if (r == null) {
    Nav.message(context, 'Le rayon « ${nom.trim()} » existe déjà');
    return;
  }
  if (context.mounted) Nav.message(context, 'Rayon « ${r.nom} » ajouté, avec un secteur du même nom');
}

Future<void> _nouveauSecteur(BuildContext context, Rayon r) async {
  final nom = await demanderTexte(context, titre: 'Nouveau secteur · ${r.nom}', aide: 'Nom du secteur', valider: 'Suivant');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  final s = Etat.instance.ajouterSecteurCatalogue(r, nom);
  if (s == null) {
    Nav.message(context, 'Le secteur « ${nom.trim()} » existe déjà dans ce rayon');
    return;
  }
  await choisirImageSecteur(context, r.nom, s.nom);
  if (context.mounted) Nav.message(context, 'Secteur « ${s.nom} » ajouté');
}

Future<void> _renommerRayon(BuildContext context, Rayon r) async {
  final nom = await demanderTexte(context, titre: 'Nom du rayon', initial: r.nom);
  if (nom == null || nom.trim().isEmpty) return;
  Etat.instance.renommerRayonCatalogue(r, nom);
}

Future<void> _renommerSecteur(BuildContext context, Secteur s) async {
  final nom = await demanderTexte(context, titre: 'Nom du secteur', initial: s.nom);
  if (nom == null || nom.trim().isEmpty) return;
  Etat.instance.renommerSecteurCatalogue(s, nom);
}
