import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e05_liste_complete.dart';
import 'e08_produits.dart';

/// Écran 3 — Construction de la liste, rayon par rayon et secteur par secteur.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  @override
  State<EcranConstruction> createState() => _EcranConstructionState();
}

class _EcranConstructionState extends State<EcranConstruction> {
  final etat = Etat.instance;
  int rayonIndex = 0;
  int secteurIndex = 0;

  /// Un produit est signalé « habituel » à partir de ce nombre d'utilisations.
  static const int seuilHabituel = 5;

  void _allerA(String magasinId, Secteur s) {
    final rayons = etat.rayonsDu(magasinId);
    final ri = rayons.indexWhere((r) => r.id == s.rayonId);
    if (ri < 0) return;
    final si = etat.secteursDu(rayons[ri].id).indexWhere((x) => x.id == s.id);
    setState(() {
      rayonIndex = ri;
      secteurIndex = si < 0 ? 0 : si;
    });
  }

  Future<void> _rechercher(Liste l) async {
    final choisi = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogueRecherche(magasinId: l.magasinId),
    );
    if (choisi == null || !mounted) return;
    etat.ajouterLigne(l, choisi);
    final s = etat.secteurDe(l.magasinId, choisi);
    if (s != null) {
      _allerA(l.magasinId, s);
    } else {
      Nav.message(context, 'Ajouté à la liste (produit non placé dans ce magasin)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(widget.listeId);
        if (l == null) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Liste'),
            corps: Center(child: Text('Cette liste n\'existe plus.', style: Charte.texte(16))),
          );
        }
        final magasin = etat.magasin(l.magasinId);
        final rayons = etat.rayonsDu(l.magasinId);
        if (rayons.isEmpty) {
          return PageBase(
            entete: EnTeteTravail(titre: 'Préparer · ${magasin?.nom ?? ''}'),
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Ce magasin n'a pas encore de rayons décrits. Les rayons et secteurs se décrivent "
                'dans « Magasins et parcours ».',
                style: Charte.texte(15, couleur: Charte.texteSecondaire),
              ),
            ),
            bas: [_barre(context, l)],
          );
        }
        if (rayonIndex >= rayons.length) rayonIndex = 0;
        final rayon = rayons[rayonIndex];
        final secteurs = etat.secteursDu(rayon.id);
        if (secteurIndex >= secteurs.length) secteurIndex = 0;
        final secteur = secteurs.isEmpty ? null : secteurs[secteurIndex];

        final produits = secteur == null ? <Produit>[] : etat.produitsDu(l.magasinId, secteur.id);
        produits.sort((a, b) {
          final ca = etat.ligne(l, a.id) != null ? 0 : 1;
          final cb = etat.ligne(l, b.id) != null ? 0 : 1;
          if (ca != cb) return ca.compareTo(cb);
          return b.nbUtilisations.compareTo(a.nbUtilisations);
        });

        return PageBase(
          entete: EnTeteTravail(
            titre: 'Préparer · ${magasin?.nom ?? ''}',
            action: BoutonIcone(icone: Icons.search, libelle: 'Rechercher un produit', onTap: () => _rechercher(l)),
          ),
          haut: [
            BandeauPuces(
              puces: [for (final r in rayons) Puce(r.nom, compteur: etat.nbDansRayon(l, r.id))],
              selection: rayonIndex,
              onChoix: (i) => setState(() {
                rayonIndex = i;
                secteurIndex = 0;
              }),
            ),
            BandeauPuces(
              pastille: false,
              fond: Charte.fondBandeau,
              puces: [for (final s in secteurs) Puce(s.nom, compteur: etat.nbDansSecteur(l, s.id))],
              selection: secteurIndex,
              onChoix: (i) => setState(() => secteurIndex = i),
            ),
          ],
          corps: ListView(
            children: [
              for (final p in produits) _ligne(l, p),
              InkWell(
                onTap: () => Nav.aller(context, EcranProduits(listeId: l.id)),
                child: Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                  child: Text('+ Produit absent de ce secteur',
                      style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              ),
            ],
          ),
          bas: [_barre(context, l)],
        );
      },
    );
  }

  Widget _ligne(Liste l, Produit p) {
    final g = etat.ligne(l, p.id);
    final promo = etat.promotionActive(l.magasinId, p.id);
    return LigneChoix(
      key: ValueKey(p.id),
      nom: p.nom,
      complement: etat.complement(g, p),
      coche: g != null,
      quantite: g?.quantite ?? 1,
      promo: promo?.type,
      habituel: p.nbUtilisations >= seuilHabituel,
      alerte: g == null ? null : etat.quantiteInsuffisante(l, g),
      onTap: () => etat.basculer(l, p.id),
      onQuantite: (q) => etat.quantite(l, p.id, q),
    );
  }

  Widget _barre(BuildContext context, Liste l) => BarreAction(boutons: [
        Bouton(
          texte: 'Ma liste · ${l.lignes.length}',
          onTap: () => Nav.aller(context, EcranListeComplete(listeId: l.id)),
        ),
        Bouton(
          texte: 'Liste prête',
          plein: true,
          onTap: () {
            etat.listePrete(l);
            Nav.accueil(context);
            Nav.message(context, 'Liste prête : elle apparaît dans « Je fais les courses »');
          },
        ),
      ]);
}

class _DialogueRecherche extends StatefulWidget {
  const _DialogueRecherche({required this.magasinId});
  final String magasinId;

  @override
  State<_DialogueRecherche> createState() => _DialogueRechercheState();
}

class _DialogueRechercheState extends State<_DialogueRecherche> {
  String filtre = '';

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final f = filtre.toLowerCase();
    final trouves = etat.produits.where((p) => f.isEmpty || p.nom.toLowerCase().contains(f)).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    return AlertDialog(
      backgroundColor: Charte.fond,
      insetPadding: const EdgeInsets.all(16),
      title: Text('Rechercher un produit', style: Charte.texte(18, gras: true)),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: Charte.texte(16),
              decoration: const InputDecoration(hintText: 'Nom du produit'),
              onChanged: (v) => setState(() => filtre = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in trouves)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(p.id),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.nom, style: Charte.texte(16))),
                            Text(
                              _ou(etat, p),
                              style: Charte.texte(12, couleur: Charte.texteSecondaire),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fermer', style: Charte.texte(16)),
        ),
      ],
    );
  }

  String _ou(Etat etat, Produit p) {
    final s = etat.secteurDe(widget.magasinId, p.id);
    if (s == null) return 'non placé';
    return '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}';
  }
}
