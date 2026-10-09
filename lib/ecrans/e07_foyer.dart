import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

/// Écran 7 — Foyer : membres et invitation.
class EcranFoyer extends StatelessWidget {
  const EcranFoyer({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteGestion(titre: 'Foyer'),
        corps: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const TitreSection('Nom du foyer', cote: 0),
            Row(
              children: [
                Expanded(child: Text(etat.foyer.nom, style: Charte.texte(19, gras: true))),
                Lien('Renommer', onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du foyer', initial: etat.foyer.nom);
                  if (nom != null && nom.isNotEmpty) {
                    etat.foyer.nom = nom;
                    etat.signaler();
                  }
                }),
              ],
            ),
            Text('Créé le ${jjmmaaaa(etat.foyer.dateCreation)}',
                style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            const TitreSection('Membres', cote: 0),
            for (final m in etat.membres)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                child: Row(
                  children: [
                    CadrePointille(
                      rayon: 22,
                      epaisseur: 1.2,
                      couleur: const Color(0xFF999999),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Charte.fondSelection),
                        child: Text(m.initiales, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche, style: Charte.texte(17, gras: true)),
                          Text('Compte Google', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                        ],
                      ),
                    ),
                    Etiquette(m.roleAffiche),
                  ],
                ),
              ),
            const TitreSection('Inviter une personne', cote: 0),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Charte.encre, width: Charte.traitCadre),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Code à saisir sur l'autre téléphone :", style: Charte.texte(15)),
                  const SizedBox(height: 10),
                  CadrePointille(
                    child: Container(
                      height: 64,
                      alignment: Alignment.center,
                      child: Text(etat.invitation.code.split('').join(' '),
                          style: Charte.texte(30, gras: true, espacement: 4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Valable jusqu'au ${jjmmaaaa(etat.invitation.expiration)}",
                      textAlign: TextAlign.center, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  const SizedBox(height: 10),
                  Bouton(
                    texte: 'Envoyer le code (SMS, mail…)',
                    plein: true,
                    taille: 16,
                    onTap: () => Nav.nonDisponible(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Bouton(
              texte: "J'ai reçu un code : rejoindre un foyer",
              pointille: true,
              taille: 16,
              onTap: () async {
                final code = await demanderTexte(context,
                    titre: 'Rejoindre un foyer', aide: 'Code reçu (6 caractères)', valider: 'Rejoindre');
                if (code != null && code.isNotEmpty && context.mounted) Nav.nonDisponible(context);
              },
            ),
            const TitreSection('Comptes magasin (option à étudier)', cote: 0),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etat.magasins.first.enseigne, style: Charte.texte(17, gras: true)),
                  Text('Identifiant · dernière récupération : jamais',
                      style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ],
              ),
            ),
            Lien('+ Ajouter un compte magasin', onTap: () => Nav.nonDisponible(context)),
            const SizedBox(height: 16),
          ],
        ),
        bas: const [BarreNavigation(index: 0)],
      ),
    );
  }
}
