import 'package:flutter/material.dart';

import '../donnees/modele.dart';
import '../theme.dart';

/// Petite icône d'un produit ajouté par le foyer ; rien pour un produit du catalogue d'origine.
class SignePerso extends StatelessWidget {
  const SignePerso(this.produit, {super.key, this.taille = 16});
  final Produit produit;
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (!Etat.instance.estAjoute(produit)) return const SizedBox.shrink();
    return Tooltip(message: 'Ajouté par le foyer', child: Icon(Icons.add_circle, size: taille, color: Charte.accent));
  }
}
