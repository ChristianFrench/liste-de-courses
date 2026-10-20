import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e13_produits_reels.dart';

// Gérer › Mon foyer, Gérer › Paramètres (17), Types de promotion (18) et Types de packaging.

/// Gérer › Mon foyer : nom du foyer, membres et leurs adresses mail, invitation.
class EcranFoyer extends StatelessWidget {
  const EcranFoyer({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Gérer', titre: 'Mon foyer'),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            GroupeRetractable(
              cle: 'foyer/nom',
              titre: 'Foyer',
              icone: Icons.home_outlined,
              enfants: [
                const SizedBox(height: 8),

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
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'foyer/membres',
              titre: 'Membres',
              icone: Icons.group_outlined,
              enfants: [
                const SizedBox(height: 8),
            for (final m in etat.membres)
              LigneMenu(
                titre: m.nomAffiche,
                sousTitre: '${m.roleAffiche} · ${m.email.isEmpty ? 'adresse mail : touchez pour l\'indiquer' : m.email}',
                onTap: () async {
                  final email = await demanderTexte(context,
                      titre: 'Adresse mail · ${m.nomAffiche}', initial: m.email, aide: 'prenom.nom@exemple.fr');
                  if (email != null) etat.modifierEmail(m, email);
                },
                gauche: IconeRonde(null, texte: m.initiales),
              ),
            LigneMenu(
              icone: Icons.person_add_alt_outlined,
              titre: 'Ajouter un membre',
              sousTitre: 'Son nom et, si vous voulez, son adresse mail (sans invitation)',
              onTap: () => _ajouterMembre(context, etat),
            ),
            _Option(
              texte: 'Envoyer la liste à tout le foyer',
              aide: 'Le mail est préparé avec les adresses de tous les membres',
              coche: etat.envoiFoyer,
              onChange: (v) => etat.options(envoiFoyer: v),
            ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'foyer/invitation',
              titre: 'Invitation',
              icone: Icons.mail_outline,
              enfants: [
                const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
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
              icone: Icons.login,
              titre: 'J\'ai reçu un code : rejoindre un foyer',
              titreTaille: 16,
              onTap: () async {
                final code = await demanderTexte(context, titre: 'Rejoindre un foyer', aide: 'Code reçu (6 caractères)', valider: 'Rejoindre');
                if (code != null && code.isNotEmpty && context.mounted) Nav.plusTard(context);
              },
            ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ajout d'un membre directement par son nom, sans passer par l'invitation.
Future<void> _ajouterMembre(BuildContext context, Etat etat) async {
  final nom = await demanderTexte(context, titre: 'Nouveau membre', aide: 'Prénom ou nom', valider: 'Ajouter');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  if (etat.membres.any((m) => m.nomAffiche.toLowerCase() == nom.trim().toLowerCase())) {
    Nav.message(context, '« ${nom.trim()} » fait déjà partie du foyer');
    return;
  }
  final email = await demanderTexte(context, titre: 'Adresse mail · ${nom.trim()}', aide: 'prenom.nom@exemple.fr (facultatif)');
  etat.ajouterMembre(nom, email ?? '');
  if (context.mounted) Nav.message(context, '${nom.trim()} fait maintenant partie du foyer');
}

/// Écran 17 — Paramètres. En mode démonstration, appui long sur le titre : rétablir les données de démonstration.
class EcranParametres extends StatelessWidget {
  const EcranParametres({super.key});

  Future<void> _basculerDemo(BuildContext context, bool oui) async {
    await Etat.instance.basculerDemo(oui);
    Nav.i.reinitialiser();
    Nav.i.ouvrirRubrique(Nav.parametres);
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
        entete: const EnTeteSousNiveau(fil: 'Gérer', titre: 'Paramètres'),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            GroupeRetractable(
              cle: 'parametres/apparence',
              titre: 'Apparence',
              icone: Icons.palette_outlined,
              enfants: [
                const SizedBox(height: 8),

            Text('Couleurs de l\'application : touchez une palette, elle s\'applique tout de suite.',
                style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pal in palettes)
                  _ChoixPalette(
                    palette: pal,
                    choisie: pal.nom == Charte.palette.nom,
                    onTap: () {
                      etat.choisirApparence(pal.nom);
                      Charte.choisirPalette(pal.nom);
                    },
                  ),
              ],
            ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'parametres/listes',
              titre: 'Listes',
              icone: Icons.checklist,
              enfants: [
                const SizedBox(height: 8),

            LigneMenu(
              icone: Icons.local_offer_outlined,
              titre: 'Types de promotion',
              sousTitre: '${etat.typesPromotion.length} types · chacun avec sa couleur',
              onTap: () => Nav.aller(context, const EcranTypesPromotion()),
            ),
            LigneMenu(
              icone: Icons.inventory_2_outlined,
              titre: 'Types de packaging',
              sousTitre: '${etat.typesPackaging.length} formats (500 g, 75 cl, lot de 4…) · à corriger ici pour tous les articles',
              onTap: () => Nav.aller(context, const EcranTypesPackaging()),
            ),
            LigneMenu(
              icone: Icons.playlist_add_check,
              titre: 'Préliste',
              sousTitre: 'Produits présents ${etat.prelistePresencesMin} fois sur les ${etat.prelisteSur} dernières courses',
              onTap: () => _reglerPreliste(context, etat),
            ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'parametres/comptes',
              titre: 'Comptes magasin (à étudier)',
              icone: Icons.badge_outlined,
              enfants: [
                const SizedBox(height: 8),

            for (final m in etat.magasins.where((m) => m.enseigne.isNotEmpty))
              LigneMenu(
                icone: Icons.badge_outlined,
                titre: m.enseigne,
                sousTitre: 'Identifiant · récupération des tickets',
                onTap: () => Nav.message(context, 'Récupération par compte magasin : option à étudier'),
              ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'parametres/archives',
              titre: 'Archives',
              icone: Icons.inventory_2_outlined,
              enfants: [
                const SizedBox(height: 8),

            LigneMenu(
              icone: Icons.timer_outlined,
              titre: 'Suppression automatique des archives',
              sousTitre: etat.delaiArchives == 0 ? 'Jamais : les archives sont gardées' : 'Après ${etat.delaiArchives} mois',
              onTap: () async {
                final v = await choisirDansListe<int>(context,
                    titre: 'Supprimer les archives après', choix: const {0: 'Jamais', 6: '6 mois', 12: '1 an', 24: '2 ans', 60: '5 ans'});
                if (v != null) etat.reglerDelaiArchives(v);
              },
            ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'parametres/donnees',
              titre: 'Données',
              icone: Icons.storage_outlined,
              enfants: [
                const SizedBox(height: 8),

            Bascule(
              options: const ['Mes données', 'Démonstration'],
              index: etat.modeDemo ? 1 : 0,
              onChange: (i) => _basculerDemo(context, i == 1),
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
                icone: Icons.restart_alt,
                titre: 'Rétablir les données de démonstration',
                titreTaille: 16,
                onTap: () => _reinitialiser(context),
              ),
                const SizedBox(height: 8),
              ],
            ),
            GroupeRetractable(
              cle: 'parametres/essais',
              titre: 'Essais',
              icone: Icons.science_outlined,
              enfants: [
                const SizedBox(height: 8),

            LigneMenu(
              icone: Icons.science_outlined,
              titre: 'Produits réels — essai Open Food Facts',
              sousTitre: 'Catalogue de vrais produits gardé sur l\'appareil',
              onTap: () => Nav.aller(context, const EcranProduitsReels()),
            ),
                const SizedBox(height: 8),
              ],
            ),
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

/// Écran 18 — Paramètres › Types de promotion.
class EcranTypesPromotion extends StatelessWidget {
  const EcranTypesPromotion({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Gérer › Paramètres', titre: 'Types de promotion'),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text('Proposés quand on indique une promotion visée sur une ligne de la liste. Touchez un type pour choisir sa couleur.',
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
            GroupeRetractable(
              cle: 'types/promotion',
              titre: 'Types de promotion',
              icone: Icons.local_offer_outlined,
              nombre: etat.typesPromotion.length,
              enfants: [
            for (final t in etat.typesPromotion)
              LigneMenu(
                titre: t.nom,
                titreTaille: 19,
                sousTitre: '${t.exemple.isEmpty ? '' : (t.id == 'autre' ? t.exemple : 'Ex. : ${t.exemple.replaceAll(' ; ', ' · ')}')}'
                    '\nParamètres : ${t.parametresAffiches}',
                gauche: Pastille(t.code, couleur: _c(etat.couleurPromo(t.id))),
                onTap: () => _changerCouleur(context, 'promo:${t.id}', t.nom),
                droite: _RondCouleur(etat.couleurPromo(t.id)),
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
            const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Case à cocher d'une option, sur toute la largeur.
class _Option extends StatelessWidget {
  const _Option({required this.texte, required this.aide, required this.coche, required this.onChange});
  final String texte;
  final String aide;
  final bool coche;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChange(!coche),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              CaseACocher(coche: coche, taille: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(texte, style: Charte.texte(16, gras: true)),
                    Text(aide, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

Color? _c(int? v) => v == null ? null : Color(v);

const _palette = <int>[
  0xFFE53935, 0xFFFB8C00, 0xFFFDD835, 0xFF43A047, 0xFF00ACC1, 0xFF1E88E5, 0xFF8E24AA, 0xFFEC407A, 0xFF8D6E63, 0xFF757575,
];

/// Choix d'une couleur (ou aucune) pour un type de promotion ou de packaging.
Future<void> _changerCouleur(BuildContext context, String cle, String nom) async {
  final etat = Etat.instance;
  final v = await showDialog<int>(
    context: context,
    barrierColor: Charte.voile,
    builder: (ctx) => AlertDialog(
      backgroundColor: Charte.fond,
      title: Text('Couleur · $nom', style: Charte.texte(18, gras: true)),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in _palette)
            Semantics(
              button: true,
              label: 'Couleur',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(ctx).pop(c),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(c), border: Border.all(color: Charte.encre)),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(-1), child: Text('Couleur par défaut', style: Charte.texte(16))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: Charte.texte(16))),
      ],
    ),
  );
  if (v == null) return;
  etat.choisirCouleur(cle, v == -1 ? null : v);
}

class _RondCouleur extends StatelessWidget {
  const _RondCouleur(this.couleur);
  final int? couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: couleur == null ? Charte.fond : Color(couleur!),
          border: Border.all(color: couleur == null ? Charte.separateurZone : Charte.encre),
        ),
      );
}

/// Paramètres › Types de packaging : pack de 6, de 5… proposés pour chaque article, chacun avec sa couleur.
/// Packaging et promotion s'ajoutent : un pack de 6 peut aussi être en promotion.
class EcranTypesPackaging extends StatelessWidget {
  const EcranTypesPackaging({super.key});

  /// Actions sur un format : couleur, correction du libellé (pour tous ses articles), fusion, articles, suppression.
  Future<void> _agir(BuildContext context, Etat etat, String id) async {
    final k = etat.packaging(id);
    if (k == null) return;
    final n = etat.nbProduitsAvecPackaging(id);
    final action = await choisirDansListe<String>(context, titre: k.libelle, choix: {
      'renommer': 'Corriger le libellé (pour ses $n articles)',
      'fusionner': 'Fusionner avec un autre format',
      'articles': 'Voir les $n articles',
      'couleur': 'Changer la couleur',
      'supprimer': 'Supprimer ce format',
    });
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'renommer':
        final nom = await demanderTexte(context, titre: 'Libellé du format', initial: k.libelle, aide: 'Ex. : 500 g, 75 cl, lot de 4');
        if (nom != null && nom.isNotEmpty) etat.renommerPackaging(id, nom);
      case 'fusionner':
        final cible = await choisirDansListe<String>(context,
            titre: 'Remplacer « ${k.libelle} » par', choix: {for (final x in etat.typesPackaging) if (x != id) x: etat.packaging(x)?.libelle ?? ''});
        if (cible != null) etat.fusionnerPackaging(id, cible);
      case 'articles':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Charte.blanc,
            title: Text('${k.libelle} · $n articles', style: Charte.texte(18, gras: true)),
            content: SizedBox(
              width: 360,
              height: 400,
              child: ListView(children: [
                for (final p in etat.produitsAvecPackaging(id))
                  Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(p.nom, style: Charte.texte(15))),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer', style: Charte.texte(16)))],
          ),
        );
      case 'couleur':
        await _changerCouleur(context, 'pack:$id', k.libelle);
      case 'supprimer':
        final ok = await confirmer(context,
            titre: 'Supprimer « ${k.libelle} » ?',
            contenu: Text('Il ne sera plus proposé pour ses $n articles. Les listes déjà faites le gardent.', style: Charte.texte(16)),
            plein: 'Garder',
            contour: 'Supprimer');
        if (ok == true) etat.supprimerPackaging(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteSousNiveau(fil: 'Gérer › Paramètres', titre: 'Types de packaging'),
        bas: [
          BarreAction(boutons: [
            Bouton(
              texte: '+ Nouveau format',
              plein: true,
              onTap: () async {
                final nom = await demanderTexte(context, titre: 'Nouveau format', aide: 'Ex. : 500 g, 75 cl, lot de 4, pack de 6');
                if (nom != null && nom.isNotEmpty) {
                  etat.ajouterTypePackaging(nom);
                  etat.trierTypesPackaging();
                }
              },
            ),
          ]),
        ],
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text('Les formats de vente proposés pour les articles. Touchez un format pour corriger son libellé '
                  '(tous ses articles sont corrigés), le fusionner avec un autre, voir ses articles ou changer sa couleur.',
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
            // Un groupe par famille de formats : unité, poids, volume, lots et packs.
            for (final (famille, icone) in const [
              ('À l\'unité', Icons.category_outlined),
              ('Au poids', Icons.scale_outlined),
              ('En volume', Icons.water_drop_outlined),
              ('Lots et packs', Icons.inventory_2_outlined),
            ])
              if ([for (final id in etat.typesPackaging) if (_famille(etat.packaging(id)?.libelle ?? '') == famille) id] case final ids
                  when ids.isNotEmpty)
                GroupeRetractable(
                  cle: 'types/packaging/$famille',
                  titre: famille,
                  icone: icone,
                  nombre: ids.length,
                  enfants: [
                    for (final id in ids)
                      if (etat.packaging(id) case final k?)
                        LigneMenu(
                          titre: k.libelle,
                          sousTitre: '${etat.nbProduitsAvecPackaging(id)} articles',
                          gauche: _RondCouleur(etat.couleurPack(id)),
                          onTap: () => _agir(context, etat, id),
                        ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Famille d'un format de vente, pour le ranger dans son groupe.
String _famille(String libelle) {
  final l = libelle.toLowerCase();
  if (RegExp(r'^(lot|pack|paquet|boîte) ').hasMatch(l)) return 'Lots et packs';
  if (RegExp(r'\d\s*(g|kg)$').hasMatch(l) || l == 'au poids') return 'Au poids';
  if (RegExp(r'\d\s*(cl|ml|l)$').hasMatch(l)) return 'En volume';
  return 'À l\'unité';
}

/// Pastille d'une palette : ses teintes, du plus foncé au plus pâle, et son nom.
class _ChoixPalette extends StatelessWidget {
  const _ChoixPalette({required this.palette, required this.choisie, required this.onTap});
  final Palette palette;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: choisie,
        label: 'Palette ${palette.nom}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 104,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: palette.fond,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: choisie ? palette.accentFonce : palette.separateur, width: choisie ? 3 : 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final c in [palette.accentFonce, palette.accent, palette.fondSelection, palette.fondBarre])
                      Expanded(child: Container(height: 22, color: c)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(palette.nom, style: Charte.texte(13, gras: choisie), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}
