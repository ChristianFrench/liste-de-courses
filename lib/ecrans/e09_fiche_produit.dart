import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e10_promotion.dart';
import 'e11_magasins_parcours.dart';

/// Écran 9 — Fiche produit.
class EcranFicheProduit extends StatelessWidget {
  const EcranFicheProduit({super.key, required this.produitId, this.listeId});
  final String produitId;

  /// Liste en construction d'où l'on vient (ajout direct), ou null.
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
            entete: const EnTeteGestion(titre: 'Produit'),
            corps: Center(child: Text('Produit introuvable.', style: Charte.texte(16))),
          );
        }
        final promos = etat.promotionsDe(p.id);
        return PageBase(
          entete: EnTeteGestion(
            titre: p.nom,
            action: BoutonIcone(
              icone: Icons.edit_outlined,
              libelle: 'Renommer',
              taille: 22,
              onTap: () async {
                final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
                if (nom != null && nom.isNotEmpty) {
                  p.nom = nom;
                  etat.signaler();
                }
              },
            ),
          ),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 16),
              InkWell(
                onTap: () => Nav.nonDisponible(context),
                child: const ImageAbsente(texte: 'Image du produit · ajouter une photo', hauteur: 120),
              ),
              const TitreSection('Où le trouver', cote: 0),
              for (final m in etat.magasins) _emplacement(context, etat, p, m),
              const TitreSection('Marques', cote: 0),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in p.marqueIds) _pastille(etat.marque(id)?.nom ?? ''),
                  _ajout('+ Marque', () async {
                    final nom = await demanderTexte(context, titre: 'Ajouter une marque', aide: 'Nom de la marque');
                    if (nom != null && nom.isNotEmpty) etat.ajouterMarque(p, nom);
                  }),
                ],
              ),
              const TitreSection('Packagings', cote: 0),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in p.packagingIds) _pastille(etat.packaging(id)?.libelle ?? ''),
                  _ajout('+ Packaging', () async {
                    final nom = await demanderTexte(context,
                        titre: 'Ajouter un packaging', aide: 'Ex. : Pack de 6, 500 g, Bouteille 1 L');
                    if (nom != null && nom.isNotEmpty) etat.ajouterPackaging(p, nom);
                  }),
                ],
              ),
              const TitreSection('Promotions en cours', cote: 0),
              if (promos.isEmpty)
                Text('Aucune promotion en cours.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              for (final pr in promos)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration:
                      const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                  child: Row(
                    children: [
                      IconePromo(type: pr.type),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [pr.libelle, if (etat.packaging(pr.packagingId) != null) etat.packaging(pr.packagingId)!.libelle]
                              .join(' · '),
                          style: Charte.texte(15),
                        ),
                      ),
                      Text('${etat.magasin(pr.magasinId)?.nom ?? ''} · → ${jjmm(pr.fin)}',
                          style: Charte.texte(12, couleur: Charte.texteSecondaire)),
                    ],
                  ),
                ),
              Lien('+ Signaler une promotion',
                  onTap: () => Nav.aller(context, EcranPromotion(produitId: p.id))),
              if (etat.produitUtilise(p)) ...[
                const SizedBox(height: 8),
                CadrePointille(
                  couleur: const Color(0xFF999999),
                  epaisseur: 1.2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 18, color: Charte.texteSecondaire),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Déjà utilisé dans une liste : ni suppression ni archivage',
                              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
          bas: [
            BarreAction(boutons: [
              Bouton(texte: 'Ajouter à la liste', plein: true, onTap: () => _ajouter(context, etat, p)),
            ]),
            if (listeId == null) const BarreNavigation(index: 2),
          ],
        );
      },
    );
  }

  Widget _emplacement(BuildContext context, Etat etat, Produit p, Magasin m) {
    final s = etat.secteurDe(m.id, p.id);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
      child: Row(
        children: [
          Text(m.nom, style: Charte.texte(16, gras: true)),
          const SizedBox(width: 8),
          const Spacer(),
          if (s != null)
            InkWell(
              onTap: () => _placer(context, etat, p, m),
              child: SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text('${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}', style: Charte.texte(16)),
                ),
              ),
            )
          else
            Lien('Non placé · indiquer le secteur', italique: true, taille: 15, onTap: () => _placer(context, etat, p, m)),
        ],
      ),
    );
  }

  Future<void> _placer(BuildContext context, Etat etat, Produit p, Magasin m) async {
    final secteurs = etat.secteursDuMagasin(m.id);
    if (secteurs.isEmpty) {
      Nav.aller(context, EcranMagasinsParcours(magasinId: m.id));
      return;
    }
    final choix = <String, String>{
      for (final s in secteurs) s.id: '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}',
    };
    final sid = await choisirDansListe<String>(context, titre: '${p.nom} · ${m.nom}', choix: choix);
    if (sid != null) etat.placer(m.id, p.id, sid);
  }

  void _ajouter(BuildContext context, Etat etat, Produit p) {
    var l = etat.liste(listeId);
    if (l == null) {
      final enCours = etat.listesEnConstruction;
      l = enCours.isNotEmpty ? enCours.first : etat.creerListe(etat.magasins.first.id, []);
    }
    final nomMagasin = etat.magasin(l.magasinId)?.nom ?? '';
    if (etat.ligne(l, p.id) != null) {
      Nav.message(context, 'Déjà dans la liste $nomMagasin');
    } else {
      etat.ajouterLigne(l, p.id);
      final place = etat.secteurDe(l.magasinId, p.id) != null;
      Nav.message(context, place ? 'Ajouté à la liste $nomMagasin' : 'Ajouté à la liste $nomMagasin (non placé)');
    }
    if (listeId != null) {
      // Retour à la construction : fiche produit puis liste des produits
      var n = 0;
      Navigator.of(context).popUntil((route) => n++ >= 2 || route.isFirst);
    }
  }

  Widget _pastille(String texte) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Charte.encre, width: Charte.traitCadre),
        ),
        child: Text(texte, style: Charte.texte(15)),
      );

  Widget _ajout(String texte, VoidCallback onTap) => CadrePointille(
        rayon: 20,
        child: Material(
          color: Charte.fond,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(texte, style: Charte.texte(15)),
            ),
          ),
        ),
      );
}
