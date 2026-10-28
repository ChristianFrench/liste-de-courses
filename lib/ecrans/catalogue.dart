import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart' show cleRayon, cleSecteur;
import '../composants/signe_perso.dart';
import '../donnees/modele.dart';
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
            for (final r in etat.rayonsCatalogue) ...[
              TitreGroupe(
                nom: r.nom,
                image: cleRayon(r.nom),
                icone: Icons.view_week_outlined,
                fort: true,
                ouvert: ouvert == r.id,
                onTap: () => maj(() => ouvert = ouvert == r.id ? null : r.id),
              ),
              if (ouvert == r.id)
                for (final s in etat.secteursDu(r.id))
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

/// Nouveau produit depuis la recherche d'une liste : son rayon et son secteur (ou « Ne pas ranger »),
/// puis la fenêtre du produit. Rend le produit créé, ou null.
Future<Produit?> nouveauProduit(BuildContext context, {Secteur? secteur, String? nom}) async {
  var s = secteur;
  if (s == null) {
    final choix = await choisirSecteur(context, titre: nom ?? 'le nouveau produit', sansSecteur: true);
    if (choix == null || !context.mounted) return null;
    s = choix.$1;
  }
  return fenetreProduit(context, secteur: s, libelle: nom);
}

/// Fenêtre d'un produit ajouté (avec une croix) : libellé, marque éventuelle, mesure et packaging.
/// Sans [produit] : crée le produit dans [secteur] ; avec [produit] (ajouté par le foyer) : le corrige.
/// Le produit s'appelle toujours « libellé marque » (« Camembert Président »).
Future<Produit?> fenetreProduit(BuildContext context, {Produit? produit, Secteur? secteur, String? libelle, String? marque}) async {
  final etat = Etat.instance;
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
    titre: produit == null ? 'Nouveau produit${secteur == null ? '' : ' · ${secteur.nom}'}' : 'Modifier le produit',
    icone: Icons.shopping_basket_outlined,
    oui: produit == null ? 'Ajouter' : 'Enregistrer',
    non: null,
    croix: true,
    contenu: (context, maj) {
      Widget choix(String titre, List<String> valeurs, String? choisi, int couleur, ValueChanged<String?> onChoix) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Text(titre, style: Charte.texte(15, gras: true)),
              Wrap(spacing: 8, children: [
                for (final v in valeurs)
                  Pastille(v, couleur: Color(couleur), vide: v != choisi, onTap: () => maj(() => onChoix(v == choisi ? null : v))),
              ]),
            ],
          );
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
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('produit-nom'),
            controller: nom,
            autofocus: produit == null && (libelle ?? '').isEmpty,
            style: Charte.texte(17),
            onChanged: (_) => maj(() {}),
            decoration: const InputDecoration(labelText: 'Nom (ex. : Camembert)'),
          ),
          const SizedBox(height: 10),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: mq.text),
            optionsBuilder: (v) => v.text.trim().isEmpty
                ? const <String>[]
                : [for (final m in etat.marquesTriees) if (m.nom.toLowerCase().startsWith(v.text.trim().toLowerCase())) m.nom],
            onSelected: (v) => maj(() => mq.text = v),
            fieldViewBuilder: (context, c, focus, valider) => TextField(
              key: const ValueKey('produit-marque'),
              controller: c,
              focusNode: focus,
              style: Charte.texte(17),
              onChanged: (v) => maj(() => mq.text = v),
              decoration: const InputDecoration(labelText: 'Marque (facultative)'),
            ),
          ),
          // Les mesures sont nombreuses : une liste déroulante.
          const SizedBox(height: 14),
          Text('Mesure', style: Charte.texte(15, gras: true)),
          const SizedBox(height: 4),
          ChoixDeroulant<String>(
            valeur: mesure ?? '',
            choix: {'': 'Aucune', for (final m in mesures) m: m},
            onChange: (v) => maj(() => mesure = v.isEmpty ? null : v),
          ),
          choix('Packaging', lots, lot, etat.couleurLots, (v) => lot = v),
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

LigneMenu ligneProduit(BuildContext context, Produit p, {bool avecRangement = false}) => LigneMenu(
      titre: p.nom,
      icone: Icons.shopping_basket_outlined,
      apresTitre: SignePerso(p),
      sousTitre: avecRangement ? rangement(p) : _description(p),
      onTap: () => Nav.aller<void>(context, EcranFicheProduit(produitId: p.id)),
    );

String _description(Produit p) {
  final etat = Etat.instance;
  final nm = p.marqueIds.length;
  final nk = p.packagingIds.length;
  final morceaux = <String>[
    if (nm > 0) _pluriel(nm, 'marque'),
    if (nk > 1) _pluriel(nk, 'packaging'),
    if (nk == 1 && nm == 0) etat.packaging(p.packagingIds.first)?.libelle ?? '',
  ];
  return morceaux.isEmpty ? 'à compléter' : morceaux.join(' · ');
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
          padding: const EdgeInsets.only(bottom: 16),
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
                  icone: Icons.storefront_outlined,
                  sousTitre: '${_pluriel(etat.parcours.where((p) => p.magasinId == m.id).length, 'parcours')} · '
                      '${_pluriel(etat.listesDuMagasin(m.id).length, 'liste')} en cours',
                  onTap: () => Nav.aller<void>(context, EcranMagasin(magasinId: m.id)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                  'Tous les magasins ont le même catalogue. Supprimer un magasin efface ses parcours et ses listes en cours '
                  '(après confirmation) ; son historique de courses part dans les archives.',
                  style: Charte.texte(14, couleur: Charte.texteSecondaire)),
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

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final r = recherche.toLowerCase();
        bool garde(Produit p) =>
            p.nom.toLowerCase().contains(r) || p.marqueIds.any((id) => (etat.marque(id)?.nom.toLowerCase() ?? '').contains(r));
        final trouves = r.length < 2 ? <Produit>[] : ([for (final p in etat.produits) if (garde(p)) p]..sort((a, b) => a.nom.compareTo(b.nom)));
        final nonRanges = [for (final p in etat.produits) if (etat.secteurCatalogue(p.id) == null) p]..sort((a, b) => a.nom.compareTo(b.nom));
        final perso = etat.produitsAjoutes.length;
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.menu_book_outlined,
            sousTitre: 'Gérer › Courses',
            titre: 'Catalogue',
            aide: Aides.catalogue,
            actions: [
              ActionLigne(Icons.add, '+ Nouveau rayon', () => _nouveauRayon(context)),
              ActionLigne(Icons.edit_outlined, 'Produits ajoutés ($perso)', () => Nav.aller<void>(context, const EcranProduitsPerso())),
            ],
          ),
          haut: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const ValueKey('catalogue-recherche'),
                style: Charte.texte(16),
                decoration: const InputDecoration(hintText: 'Rechercher un produit, une marque…'),
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
                    for (final x in etat.rayonsCatalogue)
                      GroupeRetractable(
                        cle: 'catalogue/${x.nom}',
                        parDefaut: false,
                        titre: x.nom,
                        image: cleRayon(x.nom),
                        nombre: etat.secteursDu(x.id).length,
                        ajoute: etat.rayonAjoute(x),
                        actions: [
                          ActionLigne(Icons.add, '+ Nouveau secteur', () => _nouveauSecteur(context, x)),
                          if (etat.secteursDu(x.id).length > 1)
                            ActionLigne(Icons.drag_handle, 'Changer l\'ordre des secteurs', () async {
                              final noms = await ordonner(context,
                                  titre: 'Ordre des secteurs · ${x.nom}', noms: [for (final s in etat.secteursDu(x.id)) s.nom]);
                              if (noms != null) etat.ordonnerSecteursCatalogue(x, noms);
                            }),
                          if (etat.rayonAjoute(x)) ...[
                            ActionLigne(Icons.edit_outlined, 'Renommer le rayon', () => _renommerRayon(context, x)),
                            ActionLigne(Icons.delete_outline, 'Supprimer le rayon', () => _supprimerRayon(context, x), danger: true),
                          ],
                        ],
                        enfants: [
                          for (final s in etat.secteursDu(x.id))
                            LigneMenu(
                              titre: s.nom,
                              apresTitre: etat.secteurAjoute(s) ? const SigneAjoute() : null,
                              gauche: imageSecteur(context, s),
                              sousTitre: _pluriel(etat.produitsDuSecteur(s).length, 'produit'),
                              onTap: () => menuActions(context, titre: s.nom, actions: [
                                ActionLigne(Icons.list, 'Voir et modifier les produits', () => Nav.aller<void>(context, EcranSecteurCatalogue(secteurId: s.id))),
                                ...actionsSecteur(context, s),
                              ]),
                            ),
                        ],
                      ),
                    if (nonRanges.isNotEmpty)
                      GroupeRetractable(
                        cle: 'catalogue/nonRanges',
                        titre: 'Non rangés',
                        icone: Icons.help_outline,
                        nombre: nonRanges.length,
                        enfants: [for (final p in nonRanges) ligneProduit(context, p)],
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

/// Actions d'un secteur du catalogue : nouveau produit ; renommer et supprimer s'il a été ajouté par le foyer.
List<ActionLigne> actionsSecteur(BuildContext context, Secteur s) => [
      ActionLigne(Icons.add, '+ Nouveau produit', () async {
        final p = await fenetreProduit(context, secteur: s);
        if (p != null && context.mounted) Nav.message(context, '« ${p.nom} » ajouté au catalogue');
      }),
      if (Etat.instance.secteurAjoute(s)) ...[
        ActionLigne(Icons.edit_outlined, 'Renommer le secteur', () => _renommerSecteur(context, s)),
        ActionLigne(Icons.delete_outline, 'Supprimer le secteur', () => _supprimerSecteur(context, s), danger: true),
      ],
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
                  versGauche: ActionLigne(Icons.delete_outline, 'Supprimer', () => demanderSuppression(context, p, 'le produit ${p.nom}'), danger: true),
                  actions: [
                    ActionLigne(Icons.edit_outlined, 'Modifier', () => modifier(p)),
                    ActionLigne(Icons.delete_outline, 'Supprimer', () => demanderSuppression(context, p, 'le produit ${p.nom}'), danger: true),
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
                    'Les produits d\'origine du catalogue ne se modifient pas. Touchez un produit ajouté pour le modifier '
                    'ou le supprimer (s\'il n\'est dans aucune liste).',
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
        for (final r in etat.rayonsCatalogue) {
          final secteurs = [
            for (final s in etat.secteursDu(r.id))
              if (etat.marquesDuSecteur(s) case final noms when noms.isNotEmpty) (s, noms)
          ];
          if (secteurs.isEmpty) continue;
          // Rayons repliés au départ ; un rayon déployé montre ses secteurs, déployés au départ.
          final cleR = 'marques/r/${r.nom}';
          final rOuvert = plis.ouvert(cleR, parDefaut: false);
          cles.add(cleR);
          enfants.add(TitreGroupe(
              key: ValueKey('rayon-marques-${r.nom}'),
              nom: r.nom,
              grand: true,
              image: cleRayon(r.nom),
              ouvert: rOuvert,
              onTap: () => plis.basculer(cleR, parDefaut: false),
              nombre: {for (final (_, noms) in secteurs) ...noms.map((n) => n.toLowerCase())}.length));
          for (final (s, noms) in secteurs) {
            final cleS = 'marques/s/${r.nom}/${s.nom}';
            cles.add(cleS);
            if (!rOuvert) continue;
            final sOuvert = plis.ouvert(cleS);
            enfants.add(TitreGroupe(
                key: ValueKey('secteur-marques-${s.nom}'),
                nom: s.nom,
                nonPlace: true,
                nombre: noms.length,
                ouvert: sOuvert,
                onTap: () => plis.basculer(cleS)));
            if (!sOuvert) continue;
            for (final n in noms) {
              enfants.add(Glissable(
                key: ValueKey('glisser-marque-${s.id}-$n'),
                titre: n,
                versGauche: ActionLigne(Icons.delete_outline, 'Retirer', () => _retirer(context, s, n), danger: true),
                child: _LigneMarque(
                  key: ValueKey('marque-$n'),
                  nom: n,
                  detail: _produitsDeMarque(n),
                  onTap: () => fenetreMarque(context, secteur: s, nom: n),
                  onSupprimer: () => _retirer(context, s, n),
                ),
              ));
            }
            enfants.add(_LigneMarque(
              key: ValueKey('nouvelle-marque-${s.nom}'),
              nom: '+ Nouvelle marque',
              ajout: true,
              onTap: () => fenetreMarque(context, secteur: s),
            ));
          }
        }
        // Marques distributeur, par enseigne (proposées selon l'enseigne du magasin de la liste)
        for (final e in etat.marquesDistributeur.entries) {
          final cleE = 'marques/r/mdd/${e.key}';
          final eOuvert = plis.ouvert(cleE, parDefaut: false);
          cles.add(cleE);
          enfants.add(TitreGroupe(
              key: ValueKey('mdd-${e.key}'),
              nom: 'Marques distributeur · ${e.key}',
              grand: true,
              icone: Icons.local_mall_outlined,
              nombre: e.value.length,
              ouvert: eOuvert,
              onTap: () => plis.basculer(cleE, parDefaut: false)));
          if (!eOuvert) continue;
          for (final x in e.value) {
            enfants.add(_LigneMarque(nom: x.marque, detail: x.categorie, onTap: () {}));
          }
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
                : enfants,
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
        color: Charte.fond,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: Charte.ligneListe,
            padding: const EdgeInsets.only(left: 16, right: 4),
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
                  icon: Icon(Icons.delete_outline, size: 22, color: Charte.couleurIcone(Icons.delete_outline)),
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
  final rayons = [for (final r in etat.rayonsCatalogue) if (etat.secteursDu(r.id).isNotEmpty) r];
  if (rayons.isEmpty) return;
  var rayonId = secteur?.rayonId ?? rayons.first.id;
  var secteurId = secteur?.id ?? etat.secteursDu(rayonId).first.id;
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
        Text('Rayon', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 4),
        ChoixDeroulant<String>(
          key: const ValueKey('marque-rayon'),
          valeur: rayonId,
          choix: {for (final r in rayons) r.id: r.nom},
          onChange: (v) => maj(() {
            rayonId = v;
            secteurId = etat.secteursDu(v).first.id;
          }),
        ),
        const SizedBox(height: 10),
        Text('Secteur', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 4),
        ChoixDeroulant<String>(
          key: const ValueKey('marque-secteur'),
          valeur: secteurId,
          choix: {for (final s in etat.secteursDu(rayonId)) s.id: s.nom},
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

Future<void> _nouveauRayon(BuildContext context) async {
  final etat = Etat.instance;
  final nom = await demanderTexte(context, titre: 'Nouveau rayon', aide: 'Animalerie, Bricolage…', valider: 'Suivant');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  final r = etat.ajouterRayonCatalogue(nom);
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

Future<void> _supprimerRayon(BuildContext context, Rayon r) async {
  final etat = Etat.instance;
  if (etat.secteursDu(r.id).any((s) => etat.produitsDuSecteur(s).isNotEmpty)) {
    Nav.message(context, 'Ce rayon contient des produits : déplacez-les ou supprimez-les d\'abord');
    return;
  }
  final ok = await confirmer(context,
      titre: 'Supprimer le rayon ${r.nom} ?',
      contenu: Text('Le rayon et ses secteurs disparaissent de tous les magasins.', style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Supprimer');
  if (ok == true) etat.supprimerRayonCatalogue(r);
}

Future<void> _renommerSecteur(BuildContext context, Secteur s) async {
  final nom = await demanderTexte(context, titre: 'Nom du secteur', initial: s.nom);
  if (nom == null || nom.trim().isEmpty) return;
  Etat.instance.renommerSecteurCatalogue(s, nom);
}

Future<void> _supprimerSecteur(BuildContext context, Secteur s) async {
  final etat = Etat.instance;
  if (etat.produitsDuSecteur(s).isNotEmpty) {
    Nav.message(context, 'Ce secteur contient des produits : déplacez-les ou supprimez-les d\'abord');
    return;
  }
  final ok = await confirmer(context,
      titre: 'Supprimer le secteur ${s.nom} ?',
      contenu: Text('Il disparaît de tous les magasins.', style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Supprimer');
  if (ok != true) return;
  etat.supprimerSecteurCatalogue(s);
  if (context.mounted) Navigator.of(context).pop();
}
