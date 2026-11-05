import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/catalogue_commun.dart';
import '../theme.dart';
import 'editeur_catalogue.dart';

// Outil de l'éditeur du catalogue commun (05/11/2026, Aristide) : une page web à part
// (…/liste-de-courses/editeur/), ouverte par le code d'éditeur (secret GitHub CODE_EDITEUR). L'application
// des foyers n'a plus de menu d'éditeur.

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
        if (CatalogueCommun.instance.editeur) return const EcranEditeurCatalogue();
        return PageBase(
          entete: const EnTeteFenetre(icone: Icons.public, sousTitre: 'Emplettes · outil de l\'éditeur', titre: 'Catalogue commun'),
          corps: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
            Text('Réservé à l\'éditeur du catalogue commun.', style: Charte.texte(18, gras: true)),
            const SizedBox(height: 8),
            Text(
              'Ici, vous préparez une nouvelle version du catalogue commun, puis vous la généralisez : chaque foyer la '
              'reçoit à son lancement et garde ses propres modifications.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('outil-code'),
              controller: _code,
              obscureText: true,
              style: Charte.texte(16),
              decoration: InputDecoration(labelText: 'Code d\'éditeur', errorText: _erreur),
              onSubmitted: (_) => _ouvrir(),
            ),
          ]),
          bas: [
            BarreAction(boutons: [Bouton(key: const ValueKey('outil-ouvrir'), texte: 'Ouvrir', icone: Icons.lock_open, plein: true, onTap: _ouvrir)]),
          ],
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
