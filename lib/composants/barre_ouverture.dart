import 'package:flutter/material.dart';

import '../theme.dart';

/// Avancement de la mise à jour faite à l'ouverture (texte et valeur de 0 à 1), null une fois finie.
/// Mis à jour par GuetteurMiseAJour (coquille.dart), affiché par [BarreOuverture] sur la photo de l'accueil.
final ouvertureEnCours = ValueNotifier<({String texte, double valeur})?>(null);

/// Barre de progression légère avec son petit texte, juste au-dessus de « Comment ça marche »
/// (01/11/2026, Aristide).
class BarreOuverture extends StatelessWidget {
  const BarreOuverture({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: ouvertureEnCours,
        builder: (context, o, _) => o == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(o.texte,
                      style: Charte.texte(13, gras: true, couleur: Charte.blanc)
                          .copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)])),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: o.valeur,
                      minHeight: 5,
                      backgroundColor: const Color(0x66FFFFFF),
                      valueColor: AlwaysStoppedAnimation(Charte.niveau(1)),
                    ),
                  ),
                ]),
              ),
      );
}
