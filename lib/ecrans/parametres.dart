import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';
import 'e13_produits_reels.dart';

// Onglet Paramètres (17) et Types de promotion (18).

/// Écran 17 — Paramètres. En mode démonstration, appui long sur le titre : rétablir les données de démonstration.
class EcranParametres extends StatelessWidget {
  const EcranParametres({super.key});

  Future<void> _basculerDemo(BuildContext context, bool oui) async {
    await Etat.instance.basculerDemo(oui);
    Nav.i.reinitialiser();
    Nav.i.allerOnglet(Nav.parametres);
    if (context.mounted) Nav.message(context, oui ? 'Mode démonstration' : 'Retour à vos données');
  }

  Future<void> _reinitialiser(BuildContext context) async {
    if (!Etat.instance.modeDemo) return;
    final ok = await confirmer(
      context,
      titre: 'Données de démonstration',
      contenu: Text(
        'Revenir aux données de démonstration ? Les listes, parcours et produits modifiés pendant les essais seront remplacés.',
        style: Charte.texte(16),
      ),
      plein: 'Annuler',
      contour: 'Réinitialiser',
    );
    if (ok != true) return;
    await Etat.instance.reinitialiser();
    Nav.i.reinitialiser();
    Nav.message(context, 'Données de démonstration rétablies');
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: EnTeteNiveau(titre: 'Paramètres', onAppuiLong: () => _reinitialiser(context)),
        corps: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const TitreSection('Foyer', cote: 0),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etat.foyerNom, style: Charte.texte(20, gras: true)),
                      Text('Créé le ${jjmmaaaa(etat.foyerCreation)}', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                    ],
                  ),
                ),
                Lien('Renommer', taille: 17, onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du foyer', initial: etat.foyerNom);
                  if (nom != null && nom.isNotEmpty) etat.renommerFoyer(nom);
                }),
              ],
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: Charte.separateurLigne),
            for (final m in etat.membres)
              LigneMenu(
                titre: m.nomAffiche,
                sousTitre: 'Compte Google',
                gauche: CadrePointille(
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
                droite: m.role == 'administrateur' ? Etiquette(m.roleAffiche) : _EtiquetteFine(m.roleAffiche),
              ),
            const SizedBox(height: 12),
            Carte(
              chevron: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code d\'invitation', style: Charte.texte(15)),
                        Text(etat.invitationCode.split('').join(' '), style: Charte.texte(30, gras: true, espacement: 3)),
                        Text('valable jusqu\'au ${jjmmaaaa(etat.invitationExpiration)}',
                            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                      ],
                    ),
                  ),
                  Lien('Envoyer', taille: 17, onTap: () => Nav.plusTard(context)),
                ],
              ),
            ),
            LigneMenu(
              titre: 'J\'ai reçu un code : rejoindre un foyer',
              titreTaille: 16,
              onTap: () async {
                final code = await demanderTexte(context, titre: 'Rejoindre un foyer', aide: 'Code reçu (6 caractères)', valider: 'Rejoindre');
                if (code != null && code.isNotEmpty && context.mounted) Nav.plusTard(context);
              },
            ),
            const TitreSection('Listes', cote: 0),
            LigneMenu(
              titre: 'Types de promotion',
              sousTitre: '${etat.typesPromotion.length} types · libellés proposés en construction de liste',
              onTap: () => Nav.aller(context, const EcranTypesPromotion()),
            ),
            LigneMenu(
              titre: 'Préliste',
              sousTitre: 'Produits présents ${etat.prelistePresencesMin} fois sur les ${etat.prelisteSur} dernières courses',
              onTap: () => _reglerPreliste(context, etat),
            ),
            const TitreSection('Comptes magasin (option à étudier)', cote: 0),
            for (final m in etat.magasins.where((m) => m.enseigne.isNotEmpty))
              LigneMenu(
                titre: m.enseigne,
                sousTitre: 'Identifiant · récupération des tickets',
                onTap: () => Nav.message(context, 'Récupération par compte magasin : option à étudier'),
              ),
            const TitreSection('Données', cote: 0),
            Bascule(
              options: const ['Mes données', 'Démonstration'],
              index: etat.modeDemo ? 1 : 0,
              onChange: (i) => _basculerDemo(context, i == 1),
            ),
            LigneMenu(
              titre: 'Corbeille',
              sousTitre: etat.corbeille.isEmpty
                  ? 'Vide'
                  : '${etat.corbeille.length} élément${etat.corbeille.length > 1 ? 's' : ''} supprimé${etat.corbeille.length > 1 ? 's' : ''} · touchez pour restaurer',
              onTap: () => Nav.aller(context, const EcranCorbeille()),
            ),
            const SizedBox(height: 4),
            Text(
              etat.modeDemo
                  ? 'Données fictives pour essayer l\'application. Vos données sont gardées à part.'
                  : 'Vos données sont enregistrées sur cet appareil.',
              style: Charte.texte(13, couleur: Charte.texteSecondaire),
            ),
            if (etat.modeDemo)
              LigneMenu(
                titre: 'Rétablir les données de démonstration',
                titreTaille: 16,
                onTap: () => _reinitialiser(context),
              ),
            const TitreSection('Essais', cote: 0),
            LigneMenu(
              titre: 'Produits réels — essai Open Food Facts',
              sousTitre: 'Catalogue de vrais produits gardé sur l\'appareil',
              onTap: () => Nav.aller(context, const EcranProduitsReels()),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _reglerPreliste(BuildContext context, Etat etat) async {
    var presences = etat.prelistePresencesMin;
    var sur = etat.prelisteSur;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => AlertDialog(
          backgroundColor: Charte.fond,
          title: Text('Règle de la préliste', style: Charte.texte(18, gras: true)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Un produit entre dans la préliste s\'il figure au moins', style: Charte.texte(15)),
              _Compteur(valeur: presences, min: 1, max: sur, onChange: (v) => maj(() => presences = v)),
              Text('fois sur les dernières courses du magasin, au nombre de', style: Charte.texte(15)),
              _Compteur(valeur: sur, min: presences, max: 20, onChange: (v) => maj(() => sur = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler', style: Charte.texte(16))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Valider', style: Charte.texte(16, gras: true))),
          ],
        ),
      ),
    );
    if (ok == true) etat.reglerPreliste(presences, sur);
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.min, required this.max, required this.onChange});
  final int valeur;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SelecteurQuantite(quantite: valeur, onChange: (v) => onChange(v.clamp(min, max))),
      );
}

class _EtiquetteFine extends StatelessWidget {
  const _EtiquetteFine(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Charte.encre, width: 1)),
        child: Text(texte, style: Charte.texte(12)),
      );
}

/// Écran 18 — Paramètres › Types de promotion.
class EcranTypesPromotion extends StatelessWidget {
  const EcranTypesPromotion({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Paramètres', titre: 'Types de promotion'),
        corps: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),
            Text('Proposés quand on indique une promotion visée sur une ligne de la liste. La liste reste ouverte.',
                style: Charte.texte(16, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 6),
            for (final t in etat.typesPromotion)
              LigneMenu(
                titre: t.nom,
                titreTaille: 19,
                sousTitre: '${t.exemple.isEmpty ? '' : (t.id == 'autre' ? t.exemple : 'Ex. : ${t.exemple.replaceAll(' ; ', ' · ')}')}'
                    '\nParamètres : ${t.parametresAffiches}',
                gauche: Container(
                  width: 50,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Charte.encre, width: Charte.traitCadre),
                  ),
                  child: Text(t.code, style: Charte.texte(14, gras: true)),
                ),
                droite: BoutonIcone(icone: Icons.edit_outlined, taille: 22, libelle: 'Modifier', onTap: () => Nav.plusTard(context)),
              ),
            const SizedBox(height: 14),
            Bouton(
              texte: '+ Ajouter un type de promotion',
              pointille: true,
              taille: 16,
              onTap: () async {
                final nom = await demanderTexte(context, titre: 'Nouveau type de promotion', aide: 'Nom (ex. : Bon de réduction)');
                if (nom == null || nom.isEmpty || !context.mounted) return;
                final code = await demanderTexte(context,
                    titre: 'Code court (3 caractères)', initial: nom.substring(0, nom.length < 3 ? nom.length : 3).toUpperCase());
                if (code == null || code.isEmpty) return;
                etat.ajouterTypePromotion(code.length > 4 ? code.substring(0, 4) : code, nom, '');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
