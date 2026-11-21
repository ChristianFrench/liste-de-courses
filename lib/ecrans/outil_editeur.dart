import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/catalogue_commun.dart';
import '../theme.dart';
import '../composants/icone.dart';
import 'administration.dart';

// Console d'administration d'Emplettes (application Windows seule, 06/11/2026, Aristide) : à chaque lancement,
// le code d'éditeur (secret GitHub CODE_EDITEUR) ouvre la console (administration.dart).

class EcranOutilEditeur extends StatefulWidget {
  const EcranOutilEditeur({super.key});

  @override
  State<EcranOutilEditeur> createState() => _EcranOutilEditeurState();
}

class _EcranOutilEditeurState extends State<EcranOutilEditeur> {
  final _code = TextEditingController();
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CatalogueCommun.instance,
      builder: (context, _) {
        if (CatalogueCommun.instance.editeur) return const ConsoleAdministration();
        return Material(
          color: Charte.niveau(4),
          child: Center(
            child: Container(
              width: 440,
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
              decoration: BoxDecoration(
                color: Charte.blanc,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Charte.separateurZone),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const ImageEmplettes('complet', taille: 64),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Emplettes', style: Charte.texte(24, gras: true, couleur: Charte.encreNiveau)),
                    Text('Administration', style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                  ]),
                ]),
                const SizedBox(height: 22),
                TextField(
                  key: const ValueKey('outil-code'),
                  controller: _code,
                  autofocus: true,
                  obscureText: true,
                  style: Charte.texte(16),
                  decoration: InputDecoration(labelText: 'Code secret', errorText: _erreur),
                  onSubmitted: (_) => _ouvrir(),
                ),
                const SizedBox(height: 18),
                Bouton(key: const ValueKey('outil-ouvrir'), texte: 'Ouvrir', icone: Icons.lock_open, plein: true, onTap: _ouvrir),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _ouvrir() {
    if (CatalogueCommun.instance.deverrouiller(_code.text)) {
      _code.clear();
    } else {
      setState(() => _erreur = CatalogueCommun.editeurPossible ? 'Code incorrect' : 'Outil compilé sans code d\'éditeur');
    }
  }
}
