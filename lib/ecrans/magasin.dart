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

/// Actions d'un produit du catalogue : dans le titre de sa fiche, ou dans le volet ouvert en touchant sa ligne
/// du catalogue (02/11/2026, Aristide : plus de page pour voir mesures et packagings, ils sont sur la ligne).
List<ActionLigne> actionsProduit(BuildContext context, Produit p, {String? listeId, bool depuisFiche = false}) {
  final etat = Etat.instance;
  final utilise = etat.produitUtilise(p);
  final ajoute = etat.estAjoute(p);
  return [
    if (etat.secteurCatalogue(p.id) == null)
      ActionLigne(Icons.place_outlined, 'Placer dans un rayon et un secteur', () => placerProduit(context, p)),
    if (ajoute) ...[
      ActionLigne(Icons.edit_outlined, 'Modifier', () => fenetreProduit(context, produit: p, secteur: etat.secteurCatalogue(p.id))),
      ActionLigne(Icons.delete_outline, 'Supprimer', () async {
        if (await demanderSuppression(context, p, 'le produit ${p.nom}') && depuisFiche && context.mounted) Navigator.of(context).pop();
      }, danger: true),
    ],
    ActionLigne(Icons.sell_outlined, 'Créer le même produit d\'une marque', () => produitDeMarque(context, p)),
    // 02/11/2026 (Aristide) : déplacer le produit, mettre à jour ses mesures et packagings.
    if (etat.secteurCatalogue(p.id) != null)
      ActionLigne(Icons.drive_file_move_outline, 'Déplacer le produit', () => deplacerProduit(context, p)),
    ActionLigne(Icons.straighten, 'Mettre à jour mesures et packaging', () => formatsProduit(context, p)),
    // 05/11/2026 (Aristide) : un produit du catalogue commun dont le foyer n'a pas l'usage se masque chez lui.
    if (!ajoute)
      ActionLigne(Icons.visibility_off_outlined, 'Masquer chez nous', () async {
        final ok = await confirmer(
          context,
          titre: 'Masquer « ${p.nom} » ?',
          icone: Icons.visibility_off_outlined,
          contenu: Text(
            'Il disparaît de votre catalogue et de la recherche${utilise ? ', et reste dans vos listes' : ''}. '
            'Les autres foyers le gardent. Gérer › Catalogue › Produits masqués le fait revenir.',
            style: Charte.texte(16),
          ),
          plein: 'Annuler',
          contour: 'Masquer',
        );
        if (ok != true) return;
        etat.masquer(p, true);
        if (context.mounted) {
          if (depuisFiche) Navigator.of(context).pop();
          Nav.message(context, '« ${p.nom} » masqué');
        }
      }),
  ];
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
            actions: actionsProduit(context, p, listeId: listeId, depuisFiche: true),
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
                          : 'Produit du catalogue d\'origine : il ne se modifie pas. « Créer le même produit d\'une marque » en fait un nouveau produit.',
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
