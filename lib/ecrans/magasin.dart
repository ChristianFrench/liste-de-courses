import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../composants/signe_perso.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'catalogue.dart';
import 'corbeille.dart';
import 'travail.dart';

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
        return PageBase(
          entete: EnTeteFenetre(retour: true, icone: Icons.menu_book_outlined, sousTitre: 'Catalogue', titre: p.nom),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Nav.plusTard(context),
                child: const ImageAbsente(texte: 'Image du produit · ajouter une photo', hauteur: 110),
              ),
              if (etat.estAjoute(p) || etat.estModifie(p))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    SignePerso(p, taille: 18),
                    const SizedBox(width: 8),
                    Text(etat.estAjoute(p) ? 'Ajouté par le foyer' : 'Modifié par le foyer',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                  ]),
                ),
              const TitreSection('Rangement (le même dans tous les magasins)', cote: 0),
              Row(
                children: [
                  Expanded(child: Text(rangement(p), style: Charte.texte(16))),
                  const SizedBox(width: 8),
                  BoutonAction('Changer', onTap: () async {
                    final choix = await choisirSecteur(context, titre: p.nom);
                    if (choix?.$1 case final s?) etat.placer('', p.id, s.id);
                  }),
                ],
              ),
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
              if (utilise) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.lock_outline, size: 18, color: Charte.couleurIcone(Icons.lock_outline)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Déjà utilisé dans une liste : il peut être modifié, pas supprimé.',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
            ],
          ),
          bas: [
            BarreAction(boutons: [
              Bouton(
                texte: 'Renommer',
                taille: 15,
                onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
                  if (nom != null && nom.isNotEmpty) etat.renommerProduit(p, nom);
                },
              ),
              if (!utilise)
                Bouton(
                  texte: 'Supprimer',
                  taille: 15,
                  onTap: () async {
                    if (await demanderSuppression(context, p, 'le produit ${p.nom}') && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              Bouton(texte: 'À la liste', plein: true, taille: 15, onTap: () => _ajouter(context, etat, p)),
            ]),
          ],
        );
      },
    );
  }

  Future<void> _ajouter(BuildContext context, Etat etat, Produit p) async {
    var l = etat.liste(listeId);
    if (l == null) {
      final enPrep = etat.listesStatut(StatutListe.enConstruction);
      if (enPrep.isEmpty) {
        final m = etat.magasinReference;
        if (m == null) return;
        l = etat.creerListe(m.id, []);
      } else if (enPrep.length == 1) {
        l = enPrep.first;
      } else {
        final id = await choisirDansListe<String>(context,
            titre: 'Ajouter à quelle liste ?',
            choix: {for (final x in enPrep) x.id: '${etat.nomListe(x)} · ${x.lignes.length} articles'});
        l = etat.liste(id);
        if (l == null) return;
      }
    }
    etat.ajouterLigne(l, p.id);
    if (!context.mounted) return;
    Nav.message(context, '« ${p.nom} » ajouté à la liste ${etat.nomListe(l)}');
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
          border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
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
