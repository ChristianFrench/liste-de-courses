import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

// Suppression avec confirmation, et corbeille (Paramètres › Corbeille) pour tout remettre.

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
      '${suite.isEmpty ? '' : '$suite\n\n'}Vous pourrez le remettre depuis Paramètres › Corbeille.',
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

/// Bouton discret « Supprimer … », en bas d'un écran.
class LienSupprimer extends StatelessWidget {
  const LienSupprimer({super.key, required this.texte, required this.onTap});
  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.delete_outline, size: 20, color: Charte.texteSecondaire),
            label: Text(texte, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        ),
      );
}

/// Paramètres › Corbeille.
class EcranCorbeille extends StatelessWidget {
  const EcranCorbeille({super.key});

  static const _icones = {
    'magasin': Icons.storefront_outlined,
    'rayon': Icons.view_week_outlined,
    'secteur': Icons.grid_view_outlined,
    'produit': Icons.shopping_basket_outlined,
    'liste': Icons.checklist_outlined,
    'parcours': Icons.route_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Paramètres', titre: 'Corbeille'),
        corps: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 10),
            if (etat.corbeille.isEmpty)
              Text('La corbeille est vide.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            for (final c in etat.corbeille)
              LigneMenu(
                titre: c.libelle,
                titreTaille: 16,
                sousTitre: 'Supprimé ${quand(c.le)}',
                gauche: Icon(_icones[c.type] ?? Icons.delete_outline, size: 26, color: Charte.encre),
                droite: Lien('Restaurer', taille: 16, onTap: () {
                  final refus = etat.restaurationImpossible(c);
                  if (refus != null) {
                    Nav.message(context, refus);
                    return;
                  }
                  etat.restaurer(c);
                  Nav.message(context, 'Restauré : ${c.libelle}');
                }),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
