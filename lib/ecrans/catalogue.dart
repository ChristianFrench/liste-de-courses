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

/// Nouveau produit du catalogue : son rayon, son secteur, puis son nom. Rend le produit créé, ou null.
Future<Produit?> nouveauProduit(BuildContext context, {Secteur? secteur, String? nom}) async {
  final etat = Etat.instance;
  var s = secteur;
  if (s == null) {
    final choix = await choisirSecteur(context, titre: nom ?? 'le nouveau produit', sansSecteur: true);
    if (choix == null || !context.mounted) return null;
    s = choix.$1;
  }
  final n = nom ?? await demanderTexte(context, titre: 'Nouveau produit${s == null ? '' : ' · ${s.nom}'}', aide: 'Nom générique (ex. : Riz)', valider: 'Ajouter');
  if (n == null || n.trim().isEmpty || !context.mounted) return null;
  final existant = etat.produits.where((p) => p.nom.toLowerCase() == n.trim().toLowerCase()).firstOrNull;
  if (existant != null) {
    Nav.message(context, '« ${existant.nom} » est déjà dans le catalogue');
    return existant;
  }
  return etat.creerProduit(n, secteur: s);
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
        entete: const EnTeteFenetre(retour: true, icone: Icons.storefront_outlined, sousTitre: 'Gérer › Courses', titre: 'Magasins', aide: Aides.magasins),
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
        bas: [
          BarreAction(boutons: [
            Bouton(
              texte: '+ Nouveau magasin',
              plein: true,
              onTap: () async {
                final m = await creerMagasinDemande(context);
                if (m != null && context.mounted) Nav.aller<void>(context, EcranMagasin(magasinId: m.id));
              },
            ),
          ]),
        ],
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
          entete: EnTeteFenetre(retour: true, icone: Icons.storefront_outlined, sousTitre: 'Gérer › Courses › Magasins', titre: m.nom, aide: Aides.parcours),
          corps: SousEcranParcours(magasinId: m.id),
          bas: [
            BarreAction(boutons: [
              Bouton(
                texte: 'Renommer',
                onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du magasin', initial: m.nom);
                  if (nom == null || nom.isEmpty || !context.mounted) return;
                  if (etat.magasinNomme(nom) case final autre? when autre.id != m.id) {
                    Nav.message(context, 'Un magasin s\'appelle déjà « $nom »');
                    return;
                  }
                  etat.renommerMagasin(m, nom);
                },
              ),
              Bouton(
                texte: 'Supprimer',
                onTap: () async {
                  if (await demanderSuppression(context, m, 'le magasin ${m.nom}') && context.mounted) Navigator.of(context).pop();
                },
              ),
            ]),
          ],
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
        final perso = etat.produitsAjoutesOuModifies.length;
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.menu_book_outlined,
            sousTitre: 'Gérer › Courses',
            titre: 'Catalogue',
            aide: Aides.catalogue,
          ),
          haut: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const ValueKey('catalogue-recherche'),
                style: Charte.texte(16),
                decoration: const InputDecoration(hintText: 'Rechercher un produit, une marque…', prefixIcon: Icon(Icons.search)),
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
                        enfants: [
                          for (final s in etat.secteursDu(x.id))
                            LigneMenu(
                              titre: s.nom,
                              gauche: imageSecteur(context, s),
                              sousTitre: _pluriel(etat.produitsDuSecteur(s).length, 'produit'),
                              onTap: () => Nav.aller<void>(context, EcranSecteurCatalogue(secteurId: s.id)),
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
          bas: [
            BarreAction(boutons: [
              Bouton(
                texte: 'Ajoutés, modifiés ($perso)',
                taille: 15,
                onTap: () => Nav.aller<void>(context, const EcranProduitsPerso()),
              ),
              Bouton(
                texte: '+ Nouveau produit',
                plein: true,
                taille: 15,
                onTap: () async {
                  final p = await nouveauProduit(context);
                  if (p != null && context.mounted) Nav.aller<void>(context, EcranFicheProduit(produitId: p.id));
                },
              ),
            ]),
          ],
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
          bas: [
            BarreAction(boutons: [
              Bouton(
                texte: '+ Nouveau produit',
                plein: true,
                onTap: () async {
                  final p = await nouveauProduit(context, secteur: s);
                  if (p != null && context.mounted) Nav.aller<void>(context, EcranFicheProduit(produitId: p.id));
                },
              ),
            ]),
          ],
        );
      },
    );
  }
}

/// Catalogue › Ajoutés ou modifiés : les produits que le foyer a ajoutés ou modifiés, à corriger ou supprimer.
class EcranProduitsPerso extends StatelessWidget {
  const EcranProduitsPerso({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final tous = etat.produitsAjoutesOuModifies;
        final ajoutes = tous.where(etat.estAjoute).toList();
        final modifies = tous.where(etat.estModifie).toList();
        Widget ligne(Produit p) => Glissable(
              key: ValueKey('perso-${p.id}'),
              titre: p.nom,
              versGauche: etat.produitUtilise(p)
                  ? null
                  : ActionLigne(Icons.delete_outline, 'Supprimer', () => demanderSuppression(context, p, 'le produit ${p.nom}'), danger: true),
              actions: [
                ActionLigne(Icons.edit_outlined, 'Modifier', () => Nav.aller<void>(context, EcranFicheProduit(produitId: p.id))),
                if (!etat.produitUtilise(p))
                  ActionLigne(Icons.delete_outline, 'Supprimer', () => demanderSuppression(context, p, 'le produit ${p.nom}'), danger: true),
              ],
              child: ligneProduit(context, p, avecRangement: true),
            );
        return PageBase(
          entete: const EnTeteFenetre(
              retour: true, icone: Icons.menu_book_outlined, sousTitre: 'Gérer › Courses › Catalogue', titre: 'Ajoutés ou modifiés', aide: Aides.catalogue),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              GroupeRetractable(
                cle: 'perso/ajoutes',
                titre: 'Ajoutés',
                icone: Icons.add_circle_outline,
                nombre: ajoutes.length,
                vide: 'Aucun produit ajouté.',
                enfants: [for (final p in ajoutes) ligne(p)],
              ),
              GroupeRetractable(
                cle: 'perso/modifies',
                titre: 'Modifiés',
                icone: Icons.edit_outlined,
                nombre: modifies.length,
                vide: 'Aucun produit modifié.',
                enfants: [for (final p in modifies) ligne(p)],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                    'Touchez un produit pour le modifier. Glissez-le vers la gauche pour le supprimer, s\'il n\'a encore servi dans aucune liste.',
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

/// Gérer › Courses › Marques : les marques des produits ; les renommer, supprimer celles qui ne servent plus.
class EcranMarques extends StatelessWidget {
  const EcranMarques({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final marques = etat.marquesTriees;
        return PageBase(
          entete: const EnTeteFenetre(retour: true, icone: Icons.sell_outlined, sousTitre: 'Gérer › Courses', titre: 'Marques', aide: Aides.marques),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (marques.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucune marque : elles s\'ajoutent sur la fiche d\'un produit ou dans une liste.',
                      style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              for (final m in marques)
                LigneMenu(
                  titre: m.nom,
                  icone: Icons.sell_outlined,
                  sousTitre: _pluriel(etat.produitsDeMarque(m.id).length, 'produit'),
                  onTap: () => _marque(context, m),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _marque(BuildContext context, Marque m) async {
    final etat = Etat.instance;
    final produits = etat.produitsDeMarque(m.id);
    await menuActions(context, titre: m.nom, actions: [
      ActionLigne(Icons.edit_outlined, 'Renommer', () async {
        final nom = await demanderTexte(context, titre: 'Nom de la marque', initial: m.nom);
        if (nom != null && nom.isNotEmpty) etat.renommerMarque(m, nom);
      }),
      for (final p in produits.take(8))
        ActionLigne(Icons.shopping_basket_outlined, p.nom, () => Nav.aller<void>(context, EcranFicheProduit(produitId: p.id))),
      if (produits.isEmpty)
        ActionLigne(Icons.delete_outline, 'Supprimer', () {
          if (!etat.supprimerMarque(m)) Nav.message(context, 'Cette marque sert encore dans une liste');
        }, danger: true),
    ]);
  }
}
