import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'travail.dart';

// Onglet Magasin : Rayons (13), Secteurs (14), Produits (15), fiche produit (16).

String magasinCourant() {
  final etat = Etat.instance;
  final id = Nav.i.magasinCourant;
  if (id != null && etat.magasin(id) != null) return id;
  Nav.i.magasinCourant = etat.magasins.first.id;
  return Nav.i.magasinCourant!;
}

/// Sélecteur du magasin courant, en haut à droite (+ Nouveau magasin).
class SelecteurMagasin extends StatelessWidget {
  const SelecteurMagasin({super.key});
  static const nouveau = '__nouveau__';

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return SizedBox(
      width: 168,
      child: ChoixDeroulant<String>(
        hauteur: 48,
        valeur: magasinCourant(),
        choix: {for (final m in etat.magasins) m.id: m.nom, nouveau: '+ Nouveau magasin'},
        onChange: (v) async {
          if (v == nouveau) {
            final nom = await demanderTexte(context, titre: 'Nouveau magasin', aide: 'Ex. : Hyper de la gare');
            if (nom == null || nom.isEmpty || !context.mounted) return;
            final taille = await choisirDansListe<int>(context,
                titre: 'Remplir le magasin avec…', choix: Etat.modelesMagasin);
            if (taille == null) return;
            final m = etat.creerMagasin(nom);
            v = m.id;
            final n = await etat.appliquerModele(m, taille);
            if (n > 0 && context.mounted) Nav.message(context, '$nom : $n produits placés dans ses rayons');
          }
          Nav.i.magasinCourant = v;
          Nav.i.filtreRayonSecteurs = Nav.i.filtreRayonProduits = Nav.i.filtreSecteurProduits = null;
          Nav.i.signaler();
        },
      ),
    );
  }
}

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Écran 13 — Magasin › Rayons.
class SousEcranRayons extends StatelessWidget {
  const SousEcranRayons({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final m = magasinCourant();
    final rayons = etat.rayonsDu(m);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (rayons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text("Ce magasin n'a pas encore de rayons.", style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        for (final r in rayons)
          LigneMenu(
            titre: r.nom,
            titreTaille: 19,
            sousTitre: '${_pluriel(etat.secteursDu(r.id).length, 'secteur')} · ${_pluriel(etat.nbProduitsRayon(m, r.id), 'produit')}',
            onTap: () {
              Nav.i.filtreRayonSecteurs = r.id;
              Nav.i.allerSous(Nav.secteurs);
            },
          ),
        const SizedBox(height: 14),
        Bouton(
          texte: '+ Ajouter un rayon',
          pointille: true,
          onTap: () async {
            final nom = await demanderTexte(context, titre: 'Nouveau rayon', aide: 'Nom du rayon');
            if (nom != null && nom.isNotEmpty) etat.ajouterRayon(m, nom);
          },
        ),
      ],
    );
  }
}

/// Écran 14 — Magasin › Secteurs. Sert aussi à indiquer le secteur d'un produit non placé.
class SousEcranSecteurs extends StatelessWidget {
  const SousEcranSecteurs({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final nav = Nav.i;
    final m = magasinCourant();
    final rayons = etat.rayonsDu(m);
    if (nav.filtreRayonSecteurs != null && !rayons.any((r) => r.id == nav.filtreRayonSecteurs)) {
      nav.filtreRayonSecteurs = null;
    }
    final filtre = nav.filtreRayonSecteurs;
    final secteurs = filtre == null ? etat.secteursDuMagasin(m) : etat.secteursDu(filtre);
    final aPlacer = etat.produit(nav.produitAPlacer);
    final rayonAjout = etat.rayon(filtre) ?? (rayons.isEmpty ? null : rayons.first);
    return Column(
      children: [
        if (aPlacer != null)
          Container(
            color: Charte.fondSelection,
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, size: 20, color: Charte.encre),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Où se trouve « ${aPlacer.nom} » dans ${etat.magasin(m)?.nom ?? ''} ? Touchez son secteur.',
                      style: Charte.texte(14, gras: true)),
                ),
                TextButton(
                  onPressed: () {
                    nav.produitAPlacer = null;
                    nav.signaler();
                  },
                  child: Text('Annuler', style: Charte.texte(14)),
                ),
              ],
            ),
          ),
        BandeauPuces(
          puces: [const Puce('Tous'), for (final r in rayons) Puce(r.nom)],
          selection: filtre == null ? 0 : rayons.indexWhere((r) => r.id == filtre) + 1,
          onChoix: (i) {
            nav.filtreRayonSecteurs = i == 0 ? null : rayons[i - 1].id;
            nav.signaler();
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (secteurs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun secteur.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              for (final s in secteurs)
                LigneMenu(
                  titre: s.nom,
                  sousTitre: '${etat.rayon(s.rayonId)?.nom ?? ''} · ${_pluriel(etat.produitsDu(m, s.id).length, 'produit')}',
                  onTap: () {
                    if (aPlacer != null) {
                      etat.placer(m, aPlacer.id, s.id);
                      nav.produitAPlacer = null;
                      Nav.message(context, '« ${aPlacer.nom} » est placé dans ${s.nom}');
                    }
                    nav.filtreRayonProduits = s.rayonId;
                    nav.filtreSecteurProduits = s.id;
                    nav.allerSous(Nav.produits);
                  },
                ),
              const SizedBox(height: 14),
              if (rayonAjout != null)
                Bouton(
                  texte: '+ Ajouter un secteur au rayon ${rayonAjout.nom}',
                  pointille: true,
                  taille: 16,
                  onTap: () async {
                    final nom = await demanderTexte(context, titre: 'Nouveau secteur · ${rayonAjout.nom}', aide: 'Nom du secteur');
                    if (nom != null && nom.isNotEmpty) etat.ajouterSecteur(rayonAjout.id, nom);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Écran 15 — Magasin › Produits : filtres rayon et secteur, recherche en direct.
class SousEcranProduits extends StatefulWidget {
  const SousEcranProduits({super.key});

  @override
  State<SousEcranProduits> createState() => _SousEcranProduitsState();
}

class _SousEcranProduitsState extends State<SousEcranProduits> {
  String recherche = '';

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final nav = Nav.i;
    final m = magasinCourant();
    final rayons = etat.rayonsDu(m);
    if (nav.filtreRayonProduits != null && !rayons.any((r) => r.id == nav.filtreRayonProduits)) {
      nav.filtreRayonProduits = nav.filtreSecteurProduits = null;
    }
    final rayon = nav.filtreRayonProduits;
    final secteursRayon = rayon == null ? <Secteur>[] : etat.secteursDu(rayon);
    if (nav.filtreSecteurProduits != null && !secteursRayon.any((s) => s.id == nav.filtreSecteurProduits)) {
      nav.filtreSecteurProduits = null;
    }
    final secteur = etat.secteur(nav.filtreSecteurProduits);

    Iterable<Produit> produits;
    if (secteur != null) {
      produits = etat.produitsDu(m, secteur.id);
    } else if (rayon != null) {
      produits = [for (final s in secteursRayon) ...etat.produitsDu(m, s.id)];
    } else {
      produits = etat.produits;
    }
    final r = recherche.toLowerCase();
    final liste = produits.where((p) {
      if (r.isEmpty) return true;
      final marques = p.marqueIds.map((id) => etat.marque(id)?.nom.toLowerCase() ?? '');
      return p.nom.toLowerCase().contains(r) || marques.any((x) => x.contains(r));
    }).toList();
    if (secteur == null) liste.sort((a, b) => a.nom.compareTo(b.nom));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoixDeroulant<String>(
                      valeur: rayon ?? '',
                      choix: {'': 'Tous les rayons', for (final x in rayons) x.id: x.nom},
                      onChange: (v) {
                        nav.filtreRayonProduits = v.isEmpty ? null : v;
                        nav.filtreSecteurProduits = null;
                        nav.signaler();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoixDeroulant<String>(
                      valeur: secteur?.id ?? '',
                      choix: {'': 'Tous les secteurs', for (final s in secteursRayon) s.id: s.nom},
                      onChange: (v) {
                        nav.filtreSecteurProduits = v.isEmpty ? null : v;
                        nav.signaler();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                style: Charte.texte(16),
                decoration: const InputDecoration(hintText: 'Rechercher un produit, une marque…'),
                onChanged: (v) => setState(() => recherche = v.trim()),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final p in liste)
                LigneMenu(
                  titre: p.nom,
                  titreTaille: 18,
                  gauche: const _Vignette(),
                  droite: const SizedBox.shrink(),
                  sousTitre: _description(etat, p),
                  onTap: () => Nav.aller(context, EcranFicheProduit(produitId: p.id)),
                ),
              const SizedBox(height: 14),
              Bouton(
                texte: secteur == null ? '+ Nouveau produit' : '+ Nouveau produit dans ${secteur.nom}',
                pointille: true,
                taille: 16,
                onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nouveau produit', aide: 'Nom générique (ex. : Riz)');
                  if (nom == null || nom.isEmpty || !context.mounted) return;
                  final p = etat.creerProduit(nom);
                  if (secteur != null) etat.placer(m, p.id, secteur.id);
                  Nav.aller(context, EcranFicheProduit(produitId: p.id));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _description(Etat etat, Produit p) {
    final nm = p.marqueIds.length;
    final nk = p.packagingIds.length;
    final morceaux = <String>[
      if (nm > 0) _pluriel(nm, 'marque'),
      if (nk > 1) _pluriel(nk, 'packaging'),
      if (nk == 1 && nm == 0) etat.packaging(p.packagingIds.first)?.libelle ?? '',
    ];
    return morceaux.isEmpty ? 'à compléter' : morceaux.join(' · ');
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => CadrePointille(
        rayon: 4,
        epaisseur: 1.2,
        couleur: const Color(0xFF999999),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          color: Charte.placeholder,
          child: Text('IMG', style: Charte.texte(10, couleur: Charte.texteSecondaire)),
        ),
      );
}

/// Écran 16 — Fiche produit (sous-niveau de Magasin › Produits).
/// Avec [listeId] : ouverte depuis la construction, l'ajout revient à cette liste.
class EcranFicheProduit extends StatelessWidget {
  const EcranFicheProduit({super.key, required this.produitId, this.listeId});
  final String produitId;
  final String? listeId;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final p = etat.produit(produitId);
        if (p == null) {
          return PageBase(
            entete: const EnTeteSousNiveau(fil: 'Magasin › Produits', titre: 'Produit'),
            corps: Center(child: Text('Produit introuvable.', style: Charte.texte(16))),
          );
        }
        return PageBase(
          entete: EnTeteSousNiveau(
            fil: 'Magasin › Produits',
            titre: p.nom,
            droite: BoutonIcone(
              icone: Icons.edit_outlined,
              taille: 22,
              libelle: 'Renommer',
              onTap: () async {
                final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
                if (nom != null && nom.isNotEmpty) {
                  p.nom = nom;
                  etat.modifie();
                }
              },
            ),
          ),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Nav.plusTard(context),
                child: const ImageAbsente(texte: 'Image du produit · ajouter une photo', hauteur: 110),
              ),
              const TitreSection('Où le trouver', cote: 0),
              for (final m in etat.magasins) _emplacement(context, etat, p, m),
              const TitreSection('Marques', cote: 0),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final id in p.marqueIds) _pastille(etat.marque(id)?.nom ?? ''),
                _ajout('+ Marque', () async {
                  final nom = await demanderTexte(context, titre: 'Ajouter une marque', aide: 'Nom de la marque');
                  if (nom != null && nom.isNotEmpty) etat.ajouterMarque(p, nom);
                }),
              ]),
              const TitreSection('Packagings', cote: 0),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final id in p.packagingIds) _pastille(etat.packaging(id)?.libelle ?? ''),
                _ajout('+ Packaging', () async {
                  final nom = await demanderTexte(context, titre: 'Ajouter un packaging', aide: 'Ex. : Pack de 6, 500 g');
                  if (nom != null && nom.isNotEmpty) etat.ajouterPackaging(p, nom);
                }),
              ]),
              if (etat.produitUtilise(p)) ...[
                const SizedBox(height: 14),
                CadrePointille(
                  couleur: const Color(0xFF999999),
                  epaisseur: 1.2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      const Icon(Icons.lock_outline, size: 18, color: Charte.texteSecondaire),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Déjà utilisé dans une liste : ni suppression ni archivage',
                            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                      ),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
          bas: [
            BarreAction(boutons: [
              Bouton(texte: 'Ajouter à la liste en préparation', plein: true, taille: 16, onTap: () => _ajouter(context, etat, p)),
            ]),
          ],
        );
      },
    );
  }

  Widget _emplacement(BuildContext context, Etat etat, Produit p, Magasin m) {
    final s = etat.secteurDe(m.id, p.id);
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
      child: Row(
        children: [
          Text(m.nom, style: Charte.texte(16, gras: true)),
          const Spacer(),
          if (s != null)
            Text('${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}', style: Charte.texte(16))
          else
            Lien('Non placé · indiquer le secteur', italique: true, taille: 15, onTap: () => _indiquerSecteur(context, etat, p, m)),
        ],
      ),
    );
  }

  /// « Non placé · indiquer le secteur » → Magasin › Secteurs, en mode « placer ce produit ».
  /// Depuis la construction (écran de travail), un choix direct évite de quitter la liste.
  Future<void> _indiquerSecteur(BuildContext context, Etat etat, Produit p, Magasin m) async {
    if (listeId != null || etat.secteursDuMagasin(m.id).isEmpty) {
      final secteurs = etat.secteursDuMagasin(m.id);
      if (secteurs.isEmpty) {
        Nav.message(context, '${m.nom} n\'a pas encore de rayons : décrivez-les dans l\'onglet Magasin');
        return;
      }
      final sid = await choisirDansListe<String>(context,
          titre: '${p.nom} · ${m.nom}', choix: {for (final s in secteurs) s.id: '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}'});
      if (sid != null) etat.placer(m.id, p.id, sid);
      return;
    }
    Nav.i.produitAPlacer = p.id;
    Nav.i.magasinCourant = m.id;
    Nav.i.filtreRayonSecteurs = null;
    Navigator.of(context).pop();
    Nav.i.allerSous(Nav.secteurs);
  }

  Future<void> _ajouter(BuildContext context, Etat etat, Produit p) async {
    var l = etat.liste(listeId);
    if (l == null) {
      final enPrep = etat.listesStatut(StatutListe.enConstruction);
      if (enPrep.isEmpty) {
        l = etat.creerListe(magasinCourant(), []);
      } else if (enPrep.length == 1) {
        l = enPrep.first;
      } else {
        final id = await choisirDansListe<String>(context,
            titre: 'Ajouter à quelle liste ?',
            choix: {for (final x in enPrep) x.id: '${etat.magasin(x.magasinId)?.nom ?? ''} · ${x.lignes.length} articles'});
        l = etat.liste(id);
        if (l == null) return;
      }
    }
    etat.ajouterLigne(l, p.id);
    if (!context.mounted) return;
    Nav.message(context, '« ${p.nom} » ajouté à la liste ${etat.magasin(l.magasinId)?.nom ?? ''}');
    if (listeId != null) {
      Navigator.of(context).pop();
    } else {
      Nav.travail(EcranConstruction(listeId: l.id));
    }
  }

  Widget _pastille(String texte) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Charte.encre, width: Charte.traitCadre),
        ),
        child: Center(widthFactor: 1, child: Text(texte, style: Charte.texte(16))),
      );

  Widget _ajout(String texte, VoidCallback onTap) => CadrePointille(
        rayon: 22,
        child: Material(
          color: Charte.fond,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(widthFactor: 1, child: Text(texte, style: Charte.texte(16))),
            ),
          ),
        ),
      );
}
