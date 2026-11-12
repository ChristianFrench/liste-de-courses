import 'package:flutter/material.dart';

import '../composants/icone.dart';
import '../donnees/modele.dart';
import '../donnees/ouverture.dart';
import '../theme.dart';

/// Fenêtre de progression de l'ouverture (12/11/2026, Aristide) : posée au milieu de l'écran, elle remplace la
/// barre qui était sur la photo de l'accueil. La page web montre la même avant le démarrage du moteur
/// (outils/preparer.py, écran « ouverture »).
class FenetreOuverture extends StatelessWidget {
  const FenetreOuverture({super.key, required this.texte, required this.valeur});
  final String texte;
  final double valeur;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          decoration: BoxDecoration(
            color: Charte.blanc,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ouverture d’Emplettes', style: Charte.texte(17, gras: true)),
            const SizedBox(height: 10),
            Text(texte, style: Charte.texte(14)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: valeur,
                minHeight: 6,
                backgroundColor: Charte.clair(Charte.accent, 0.8),
                valueColor: AlwaysStoppedAnimation(Charte.cadre),
              ),
            ),
          ]),
        ),
      );
}

/// Écran montré pendant la lecture de la base : la photo et l'image de l'accueil, la fenêtre de progression
/// par-dessus.
class EcranOuverture extends StatelessWidget {
  const EcranOuverture({super.key});

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 290 + haut,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(Etat.instance.photoFond, fit: BoxFit.cover, alignment: Alignment.topCenter),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0x00000000), Color(0x26000000), Color(0x4D000000)],
                    stops: [0, 0.3, 0.6, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, haut + 34, 18, 0),
                child: const Align(alignment: Alignment.topLeft, child: ImageEmplettes('complet', taille: 96)),
              ),
            ]),
          ),
        ]),
        const Positioned.fill(child: ColoredBox(color: Color(0x22000000))),
        ValueListenableBuilder(
          valueListenable: etapeOuverture,
          builder: (context, e, _) => FenetreOuverture(texte: e.texte, valeur: e.valeur),
        ),
      ]),
    );
  }
}
