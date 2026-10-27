import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

// Suppression avec confirmation, et corbeille (Gérer › Corbeille) pour tout remettre.

/// Demande confirmation puis supprime [objet] (magasin, rayon, secteur, produit, liste, parcours).
/// Rend true si la suppression a eu lieu.
Future<bool> demanderSuppression(BuildContext context, Object objet, String quoi) async {
  final etat = Etat.instance;
  final refus = etat.suppressionImpossible(objet);
  if (refus != null) {
    Nav.message(context, refus);
    return false;
  }
  final suite = etat.consequences(objet);
  final ok = await confirmer(
    context,
    titre: 'Supprimer $quoi ?',
    icone: Icons.delete_outline,
    contenu: Text(
      '${suite.isEmpty ? '' : '$suite\n\n'}Vous pourrez le remettre depuis Gérer › Corbeille.',
      style: Charte.texte(16),
    ),
    plein: 'Annuler',
    contour: 'Supprimer',
  );
  if (ok != true) return false;
  etat.supprimer(objet);
  if (context.mounted) Nav.message(context, 'Supprimé : il est dans la corbeille');
  return true;
}

/// Suppression d'un geste (glissement, menu) : sans question quand rien d'autre ne part avec,
/// avec un « Annuler » dans le message ; sinon la confirmation habituelle.
Future<void> supprimerVite(BuildContext context, Object objet, String quoi) async {
  final etat = Etat.instance;
  if (etat.consequences(objet).isNotEmpty) {
    await demanderSuppression(context, objet, quoi);
    return;
  }
  final refus = etat.suppressionImpossible(objet);
  if (refus != null) {
    Nav.message(context, refus);
    return;
  }
  etat.supprimer(objet);
  final c = etat.corbeille.first;
  Nav.message(context, 'Supprimé : $quoi', annuler: () => etat.restaurer(c));
}

void restaurerElement(BuildContext context, ElementCorbeille c) {
  final etat = Etat.instance;
  final refus = etat.restaurationImpossible(c);
  if (refus != null) {
    Nav.message(context, refus);
    return;
  }
  etat.restaurer(c);
  Nav.message(context, 'Restauré : ${c.libelle}');
}

Future<void> viderCorbeille(BuildContext context) async {
  final etat = Etat.instance;
  final n = etat.corbeille.length;
  final ok = await confirmer(
    context,
    titre: 'Vider la corbeille ?',
    icone: Icons.delete_forever_outlined,
    contenu: Text(
        '${n > 1 ? 'Les $n éléments' : 'L\'élément'} de la corbeille ${n > 1 ? 'seront effacés' : 'sera effacé'} pour de bon : '
        'on ne pourra plus ${n > 1 ? 'les' : 'le'} remettre.',
        style: Charte.texte(16)),
    plein: 'Annuler',
    contour: 'Vider',
  );
  if (ok != true || !context.mounted) return;
  etat.viderCorbeille();
  Nav.message(context, 'Corbeille vidée');
}

/// Gérer › Corbeille : toucher un élément propose de le restaurer ; « Vider la corbeille » est dans le menu ⋮.
class EcranCorbeille extends StatelessWidget {
  const EcranCorbeille({super.key});

  static const icones = {
    'magasin': Icons.storefront_outlined,
    'rayon': Icons.view_week_outlined,
    'secteur': Icons.grid_view_outlined,
    'produit': Icons.shopping_basket_outlined,
    'liste': Icons.checklist_outlined,
    'parcours': Icons.route_outlined,
  };

  static const _titres = {
    'magasin': 'Magasins',
    'rayon': 'Rayons',
    'secteur': 'Secteurs',
    'produit': 'Produits',
    'liste': 'Listes',
    'parcours': 'Parcours',
  };

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: EnTeteFenetre(retour: true, sousTitre: 'Gérer', titre: 'Corbeille', actions: [
          if (etat.corbeille.isNotEmpty) ActionLigne(Icons.delete_forever_outlined, 'Vider la corbeille', () => viderCorbeille(context)),
        ]),
        corps: ListView(
          children: [
            for (final type in [for (final c in etat.corbeille) c.type].toSet())
              GroupeRetractable(
                cle: 'corbeille/$type',
                titre: _titres[type] ?? type,
                icone: icones[type] ?? Icons.delete_outline,
                nombre: etat.corbeille.where((c) => c.type == type).length,
                enfants: [
                  for (final c in etat.corbeille.where((c) => c.type == type))
                    Glissable(
                        key: ValueKey('glisser-${c.id}'),
                        titre: c.libelle,
                        detail: 'Supprimé ${quand(c.le)}',
                        auToucher: true,
                        versDroite: ActionLigne(Icons.restore, 'Restaurer', () => restaurerElement(context, c)),
                        actions: [ActionLigne(Icons.restore, 'Restaurer', () => restaurerElement(context, c))],
                        child: LigneMenu(titre: c.libelle, sousTitre: 'Supprimé ${quand(c.le)}')),
                ],
              ),
            if (etat.corbeille.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('La corbeille est vide.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
