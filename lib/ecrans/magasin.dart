import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../composants/signe_perso.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'catalogue.dart';
import 'corbeille.dart';

// Création d'un magasin, fiche produit, images des rayons et secteurs.

/// Demande le nom d'un nouveau magasin (refuse un nom déjà pris) ; il reçoit le catalogue du foyer.
Future<Magasin?> creerMagasinDemande(BuildContext context) async {
  final etat = Etat.instance;
  final nom = await demanderTexte(context, titre: 'Nouveau magasin', aide: 'Ex. : Hyper de la gare');
  if (nom == null || nom.isEmpty || !context.mounted) return null;
  if (etat.magasinNomme(nom) != null) {
    Nav.message(context, 'Un magasin s\'appelle déjà « $nom » : choisissez un autre nom');
    return null;
  }
  final m = etat.creerMagasin(nom);
  await etat.remplirMagasin(m);
  return m;
}

/// Fiche produit (Gérer › Courses › Catalogue) : nom, rangement (le même dans tous les magasins), marques, packagings.
/// Avec [listeId] : ouverte depuis la préparation, l'ajout revient à cette liste.
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
            entete: const EnTeteFenetre(retour: true, sousTitre: 'Catalogue', titre: 'Produit'),
            corps: Center(child: Text('Produit introuvable.', style: Charte.texte(16))),
          );
        }
        final utilise = etat.produitUtilise(p);
        final ajoute = etat.estAjoute(p);
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.menu_book_outlined,
            sousTitre: 'Catalogue',
            titre: p.nom,
            actions: [
              if (ajoute) ...[
                ActionLigne(Icons.edit_outlined, 'Modifier', () => fenetreProduit(context, produit: p, secteur: etat.secteurCatalogue(p.id))),
                ActionLigne(Icons.delete_outline, 'Supprimer', () async {
                  if (await demanderSuppression(context, p, 'le produit ${p.nom}') && context.mounted) Navigator.of(context).pop();
                }, danger: true),
              ] else
                ActionLigne(Icons.sell_outlined, 'Avec une marque', () async {
                  final q = await fenetreProduit(context, secteur: etat.secteurCatalogue(p.id), libelle: p.nom);
                  if (q != null && context.mounted) {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => EcranFicheProduit(produitId: q.id, listeId: listeId)));
                  }
                }),
            ],
          ),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 10),
              Row(children: [
                if (ajoute) ...[SignePerso(p, taille: 18), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                      ajoute
                          ? 'Ajouté par le foyer : il peut être modifié.'
                          : 'Produit du catalogue d\'origine : il ne se modifie pas. Avec une marque, il devient un nouveau produit.',
                      style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ),
              ]),
              const TitreSection('Rangement (le même dans tous les magasins)', cote: 0),
              Text(rangement(p), style: Charte.texte(16)),
              if (p.marqueIds.isNotEmpty) ...[
                const TitreSection('Marque', cote: 0),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final id in p.marqueIds) Pastille(etat.marque(id)?.nom ?? '')]),
              ],
              if (p.packagingIds.isNotEmpty) ...[
                const TitreSection('Formats', cote: 0),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final id in p.packagingIds)
                    Pastille(etat.packaging(id)?.libelle ?? '', couleur: Color(etat.couleurPack(id) ?? Etat.couleurMesureDefaut)),
                ]),
              ],
              if (ajoute && utilise) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text('Il est dans une liste : il peut être modifié ; pour le supprimer, retirez-le d\'abord de la liste.',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Image d'un secteur, à changer en la touchant.
Widget imageSecteur(BuildContext context, Secteur s) {
  final rayon = Etat.instance.rayon(s.rayonId)?.nom ?? '';
  return ImageModifiable(cle: cleSecteur(rayon, s.nom), taille: 44, onTap: () => choisirImageSecteur(context, rayon, s.nom));
}

Future<void> choisirImageRayon(BuildContext context, String rayon) async {
  final c = await choisirPictogramme(context, titre: 'Image du rayon $rayon');
  if (c != null) Etat.instance.choisirImage(cleChoixRayon(rayon), c == imageAutomatique ? null : c);
}

Future<void> choisirImageSecteur(BuildContext context, String rayon, String secteur) async {
  final c = await choisirPictogramme(context, titre: 'Image du secteur $secteur');
  if (c != null) Etat.instance.choisirImage(cleChoixSecteur(rayon, secteur), c == imageAutomatique ? null : c);
}
