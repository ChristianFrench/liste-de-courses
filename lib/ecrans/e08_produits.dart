import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e09_fiche_produit.dart';

/// Écran 8 — Produits : catalogue commun.
/// Avec [listeId], l'écran sert à choisir un produit à ajouter à cette liste.
class EcranProduits extends StatefulWidget {
  const EcranProduits({super.key, this.listeId});
  final String? listeId;

  @override
  State<EcranProduits> createState() => _EcranProduitsState();
}

class _EcranProduitsState extends State<EcranProduits> {
  final etat = Etat.instance;
  String recherche = '';
  int filtre = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final liste = etat.liste(widget.listeId);
        final magasinId = liste?.magasinId ?? etat.magasins.first.id;
        final rayons = etat.rayonsDu(magasinId);
        final filtres = <String>['Tous', for (final r in rayons) r.nom, 'En promotion', 'Les plus utilisés'];
        if (filtre >= filtres.length) filtre = 0;
        final nomFiltre = filtres[filtre];

        var produits = etat.produits.where((p) {
          if (recherche.isNotEmpty) {
            final r = recherche.toLowerCase();
            final marques = p.marqueIds.map((id) => etat.marque(id)?.nom.toLowerCase() ?? '');
            if (!p.nom.toLowerCase().contains(r) && !marques.any((m) => m.contains(r))) return false;
          }
          if (nomFiltre == 'Tous' || nomFiltre == 'Les plus utilisés') return true;
          if (nomFiltre == 'En promotion') return etat.promotionsDe(p.id).isNotEmpty;
          return etat.rayonDe(magasinId, p.id)?.nom == nomFiltre;
        }).toList();
        if (nomFiltre == 'Les plus utilisés') {
          produits.sort((a, b) => b.nbUtilisations.compareTo(a.nbUtilisations));
          produits = produits.take(10).toList();
        } else {
          produits.sort((a, b) => a.nom.compareTo(b.nom));
        }

        return PageBase(
          entete: EnTeteGestion(
            titre: liste == null ? 'Produits' : 'Ajouter à la liste',
            action: Text(liste == null ? 'Catalogue commun' : etat.magasin(liste.magasinId)?.nom ?? '',
                style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          ),
          haut: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                style: Charte.texte(16),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un produit, une marque…',
                  prefixIcon: Icon(Icons.search, color: Charte.encre),
                ),
                onChanged: (v) => setState(() => recherche = v.trim()),
              ),
            ),
            BandeauPuces(
              puces: [for (final f in filtres) Puce(f)],
              selection: filtre,
              onChoix: (i) => setState(() => filtre = i),
            ),
          ],
          corps: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 196,
            ),
            itemCount: produits.length + 1,
            itemBuilder: (context, i) {
              if (i == produits.length) return _carteNouveau(context);
              return _carte(context, produits[i], magasinId);
            },
          ),
          bas: [if (liste == null) const BarreNavigation(index: 2)],
        );
      },
    );
  }

  Widget _carte(BuildContext context, Produit p, String magasinId) {
    final promos = etat.promotionsDe(p.id);
    final promo = promos.isEmpty ? null : promos.first;
    final nm = p.marqueIds.length;
    final nk = p.packagingIds.length;
    final dejaDansListe = widget.listeId != null && etat.ligne(etat.liste(widget.listeId)!, p.id) != null;
    return Material(
      color: dejaDansListe ? Charte.fondSelection : Charte.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Nav.aller(context, EcranFicheProduit(produitId: p.id, listeId: widget.listeId)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ImageAbsente(texte: 'IMG', hauteur: 84),
              const SizedBox(height: 6),
              Text(p.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(16, gras: true)),
              Text(
                nm == 0 && nk == 0
                    ? 'Vrac'
                    : '$nm marque${nm > 1 ? 's' : ''} · $nk packaging${nk > 1 ? 's' : ''}',
                style: Charte.texte(12, couleur: Charte.texteSecondaire),
              ),
              const Spacer(),
              if (promo != null)
                Row(
                  children: [
                    IconePromo(type: promo.type),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(promo.libelle,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(12, gras: true)),
                    ),
                  ],
                )
              else if (dejaDansListe)
                Text('Déjà dans la liste', style: Charte.texte(12, gras: true)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteNouveau(BuildContext context) {
    return CadrePointille(
      rayon: 10,
      child: Material(
        color: Charte.fond,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final nom = await demanderTexte(context, titre: 'Nouveau produit', aide: 'Nom générique (ex. : Riz)');
            if (nom == null || nom.isEmpty || !context.mounted) return;
            final p = etat.creerProduit(nom);
            Nav.aller(context, EcranFicheProduit(produitId: p.id, listeId: widget.listeId));
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 30, color: Charte.encre),
                const SizedBox(height: 6),
                Text('Nouveau produit', style: Charte.texte(16, gras: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
