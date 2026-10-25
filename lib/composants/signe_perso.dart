import 'package:flutter/material.dart';

import '../donnees/modele.dart';
import '../theme.dart';

/// Petite icône d'un produit ajouté (+) ou modifié (crayon) par le foyer ; rien pour un produit du catalogue de départ.
class SignePerso extends StatelessWidget {
  const SignePerso(this.produit, {super.key, this.taille = 16});
  final Produit produit;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final ajoute = etat.estAjoute(produit);
    if (!ajoute && !etat.estModifie(produit)) return const SizedBox.shrink();
    return Tooltip(
      message: ajoute ? 'Ajouté par le foyer' : 'Modifié par le foyer',
      child: Icon(ajoute ? Icons.add_circle : Icons.edit, size: taille, color: Charte.accent),
    );
  }
}
