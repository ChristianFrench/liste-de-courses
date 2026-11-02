import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../donnees/envoi.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';
import 'bienvenue.dart';
import 'parametres.dart' show OptionFoyer, ajouterMembreParNom, repartirANeuf;

// Gérer › Mon foyer › Foyer : seul ou en foyer, code de partage, membres (26/10/2026).
// Pas d'administrateur (27/10/2026) : chaque membre peut ajouter, inviter, renommer ou retirer un membre
// et régénérer le code. Chacun choisit son nom dans la liste des membres en rejoignant le foyer.

const lienApk = 'https://github.com/ChristianFrench/liste-de-courses/releases/download/derniere-version/Liste-de-courses.apk';
const lienWeb = 'https://christianfrench.github.io/liste-de-courses/web/';

String _vu(DateTime d) {
  final j = DateTime.now().difference(d).inDays;
  final quand = j == 0 && d.day == DateTime.now().day ? 'aujourd\'hui' : 'le ${jjmmaaaa(d)}';
  return '$quand à ${heure(d)}';
}

class EcranFoyer extends StatelessWidget {
  const EcranFoyer({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Etat.instance, Synchro.instance]),
        builder: (context, _) => _construire(context),
      );

  Widget _construire(BuildContext context) {
    final etat = Etat.instance, s = Synchro.instance;
    final enFoyer = s.mode == 'foyer' && s.actif;
    return PageBase(
      entete: EnTeteFenetre(
        retour: true,
        icone: Icons.home_outlined,
        sousTitre: 'Gérer › Mon foyer',
        titre: 'Foyer',
        aide: Aides.foyer,
        actions: [
          if (enFoyer) ...[
            ActionLigne(Icons.person_add_outlined, '+ Nouveau membre', () => nouveauMembre(context)),
            ActionLigne(Icons.switch_account_outlined, 'Changer de personne', () => choisirPersonne(context)),
            ActionLigne(Icons.copy, 'Copier le code', () {
              Clipboard.setData(ClipboardData(text: s.code!));
              Nav.message(context, 'Code copié');
            }),
            ActionLigne(Icons.key_outlined, 'Régénérer le code', () => _regenerer(context, s)),
            ActionLigne(Icons.edit_outlined, 'Renommer le foyer', () async {
              final nom = await demanderTexte(context, titre: 'Nom du foyer', initial: etat.foyerNom);
              if (nom != null && nom.isNotEmpty) etat.renommerFoyer(nom);
            }),
          ],
          ActionLigne(Icons.swap_horiz, enFoyer ? 'Utiliser seul' : 'Passer en foyer', () => _changerMode(context, enFoyer)),
          ActionLigne(Icons.restart_alt, 'Foyer neuf', () => repartirANeuf(context), danger: true),
        ],
      ),
      // 02/11/2026 (Aristide) : quatre sections comme le menu de Gérer, les explications passent dans l'aide.
      corps: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        GroupeRetractable(cle: 'foyer/foyer', titre: 'Foyer', icone: Icons.home_outlined, enfants: [
          LigneMenu(
            titre: enFoyer ? etat.foyerNom : 'Seul sur cet appareil',
            sousTitre: enFoyer ? 'Foyer partagé · cet appareil est celui de ${etat.moi.nomAffiche}' : 'Ni membres ni synchronisation',
            onTap: () => menuActions(context, titre: enFoyer ? etat.foyerNom : 'Seul sur cet appareil', actions: [
              if (enFoyer)
                ActionLigne(Icons.edit_outlined, 'Renommer le foyer', () async {
                  final nom = await demanderTexte(context, titre: 'Nom du foyer', initial: etat.foyerNom);
                  if (nom != null && nom.isNotEmpty) etat.renommerFoyer(nom);
                }),
              ActionLigne(Icons.swap_horiz, enFoyer ? 'Utiliser seul' : 'Passer en foyer', () => _changerMode(context, enFoyer)),
            ]),
          ),
          if (enFoyer) ...[
            LigneMenu(
              titre: s.code!.split('').join(' '),
              sousTitre: 'Code de partage',
              onTap: () => menuActions(context, titre: 'Code de partage', actions: [
                ActionLigne(Icons.copy, 'Copier le code', () {
                  Clipboard.setData(ClipboardData(text: s.code!));
                  Nav.message(context, 'Code copié');
                }),
                ActionLigne(Icons.key_outlined, 'Régénérer le code', () => _regenerer(context, s)),
              ]),
            ),
            OptionFoyer(texte: 'Appareil partagé', coche: etat.appareilPartage, onChange: (v) => etat.appareilPartage = v),
          ],
        ]),
        if (enFoyer)
          GroupeRetractable(cle: 'foyer/membres', titre: 'Membres', icone: Icons.groups_outlined, nombre: etat.membresVisibles.length, enfants: [
            for (final m in etat.membresVisibles) LigneMembre(m),
          ]),
        if (enFoyer)
          GroupeRetractable(cle: 'foyer/listes', titre: 'Mails', icone: Icons.mail_outline, enfants: [
            OptionFoyer(texte: 'Envoyer à tout le foyer la liste des courses à faire ou finies', coche: etat.envoiFoyer, onChange: (v) => etat.options(envoiFoyer: v)),
          ]),
        GroupeRetractable(cle: 'foyer/catalogue', titre: 'Catalogue', icone: Icons.menu_book_outlined, enfants: [
          OptionFoyer(texte: 'Catalogue du foyer seul', coche: etat.catalogueIsole, onChange: etat.isolerCatalogue),
        ]),
      ]),
    );
  }

  Future<void> _regenerer(BuildContext context, Synchro s) async {
    final ok = await confirmer(context,
        titre: 'Régénérer le code ?',
        icone: Icons.key_outlined,
        contenu: Text(
            'À faire seulement si quelqu\'un a quitté le foyer et ne doit plus voir les listes. Un nouveau code remplace '
            'l\'ancien : TOUS les autres appareils s\'arrêtent de partager jusqu\'à ce qu\'on y saisisse le nouveau code '
            '(leurs données restent).',
            style: Charte.texte(16)),
        plein: 'Annuler',
        contour: 'Régénérer le code');
    if (ok != true) return;
    await s.regenererCode();
    if (context.mounted) Nav.message(context, 'Nouveau code : donnez-le aux membres du foyer');
  }

  Future<void> _changerMode(BuildContext context, bool enFoyer) async {
    if (!enFoyer) {
      await Nav.aller<void>(context, const EcranBienvenue(depuisFoyer: true));
      return;
    }
    final ok = await confirmer(context,
        titre: 'Utiliser seul ?',
        contenu: Text(
            'Cet appareil garde une copie de tout, mais ne partage plus : les modifications ne circulent plus '
            'entre lui et le foyer. Pour revenir, il faudra le code de partage.',
            style: Charte.texte(16)),
        plein: 'Annuler',
        contour: 'Utiliser seul');
    if (ok == true) await Synchro.instance.choisirSeul();
  }
}

/// Mail d'invitation à [m] : envoyé directement, ou prérempli dans la messagerie de l'appareil.
Future<void> envoyerInvitation(BuildContext context, Membre m) async {
  final etat = Etat.instance;
  final code = Synchro.instance.code ?? '';
  final corps = 'Bonjour ${m.nomAffiche},\n\nPour partager nos listes de courses dans le foyer « ${etat.foyerNom} » :\n\n'
      '1. Installez l\'application : sur Android $lienApk ; sur iPhone, iPad ou PC, ouvrez $lienWeb\n'
      '2. Au premier lancement, choisissez « Rejoindre un foyer ».\n'
      '3. Saisissez le code de partage : $code\n'
      '4. Dans la liste des membres, choisissez « ${m.nomAffiche} ».\n\n${etat.moi.nomAffiche}';
  // L'auteur en garde une copie (trace de l'invitation).
  final moi = etat.moi.email.trim();
  final a = [m.email, if (moi.isNotEmpty && moi.toLowerCase() != m.email.trim().toLowerCase()) moi];
  final r = await envoyerMail(a, 'Rejoindre le foyer ${etat.foyerNom}', corps);
  if (!context.mounted) return;
  if (r == Envoi.parti) {
    Nav.message(context, 'Invitation envoyée à ${m.email}');
  } else if (r == Envoi.demonstration) {
    Nav.message(context, messageEnvoi(r, 1)!);
  } else if (r == Envoi.echec) {
    Nav.message(context, 'Aucune messagerie trouvée : copiez le code (titre « Foyer »)');
  }
}

/// Nouveau membre du foyer (prénom, mail), puis son invitation.
Future<void> nouveauMembre(BuildContext context) async {
  final etat = Etat.instance;
  final avant = {for (final m in etat.membres) m.id};
  await ajouterMembreParNom(context);
  final m = _trouveNouveau(etat, avant);
  if (m == null || !context.mounted) return;
  final ok = await confirmer(context,
      titre: 'Inviter ${m.nomAffiche} ?',
      contenu: Text(
          MailDirect.disponible
              ? 'Le mail d\'invitation part à ${m.email} : le code de partage, les liens pour installer l\'application, '
                  'et le nom à choisir.'
              : 'Votre messagerie s\'ouvre avec le mail d\'invitation : le code de partage, les liens pour installer '
                  'l\'application, et le nom à choisir. Vous l\'envoyez vous-même.',
          style: Charte.texte(16)),
      plein: 'Plus tard',
      contour: MailDirect.disponible ? 'Envoyer l\'invitation' : 'Préparer le mail');
  if (ok == true && context.mounted) await envoyerInvitation(context, m);
}

Membre? _trouveNouveau(Etat etat, Set<String> avant) {
  for (final m in etat.membres) {
    if (!avant.contains(m.id)) return m;
  }
  return null;
}

class LigneMembre extends StatelessWidget {
  const LigneMembre(this.m, {super.key, this.onTap});
  final Membre m;

  /// Par défaut : la fiche du membre ; Collaboration : son historique.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Synchro.instance;
    final versions = [
      if (m.moi) s.maVersion,
      for (final a in s.appareilsDe(m)) Synchro.libelleVersion(a.plateforme, a.version),
    ].toSet().join(', ');
    final details = [
      if (m.moi) 'vous',
      if (versions.isNotEmpty) versions else if (!m.moi) 'pas encore connecté',
      if (!m.moi && s.appareilsDe(m).isNotEmpty) _connexion(m),
    ];
    return LigneMenu(
      titre: m.nomAffiche,
      sousTitre: details.join(' · '),
      gauche: IconeRonde(null, texte: m.initiales),
      onTap: onTap ?? () => _fiche(context, m),
    );
  }
}

String _connexion(Membre m) {
  final aps = Synchro.instance.appareilsDe(m);
  if (aps.any((a) => a.enLigne)) return 'en ligne';
  final vus = [for (final a in aps) if (a.vu != null) a.vu!]..sort();
  return vus.isEmpty ? 'jamais vu' : 'vu ${_vu(vus.last)}';
}

/// Fiche d'un membre : appareils, listes et courses, puis ses actions (tous les membres peuvent les faire).
Future<void> _fiche(BuildContext context, Membre m) => modale(
      context,
      titre: m.nomAffiche,
      oui: null,
      non: null,
      contenu: (ctx, maj) {
        final etat = Etat.instance, s = Synchro.instance;
        final listes = etat.listesDuMembre(m), courses = etat.coursesDuMembre(m);
        final gris = Charte.texte(14, couleur: Charte.texteSecondaire);
        void fermerPuis(void Function() f) {
          Navigator.of(ctx).pop();
          f();
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(m.email.isEmpty ? 'Pas d\'adresse mail' : m.email, style: gris),
          const SizedBox(height: 10),
          Text('Appareils', style: Charte.texte(15, gras: true)),
          if (m.moi) Text('${s.maVersion} · cet appareil', style: Charte.texte(14)),
          for (final a in s.appareilsDe(m))
            Text(
                '${Synchro.libelleVersion(a.plateforme, a.version)}'
                ' · ${a.enLigne ? 'en ligne' : a.vu == null ? 'jamais vu' : 'vu ${_vu(a.vu!)}'}',
                style: Charte.texte(14)),
          if (!m.moi && s.appareilsDe(m).isEmpty) Text('Aucun appareil vu depuis le lancement', style: gris),
          const SizedBox(height: 10),
          Text('Listes préparées (${listes.length})', style: Charte.texte(15, gras: true)),
          for (final l in listes.take(15))
            InkWell(
              onTap: () => _voirListe(ctx, l),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(etat.nomListe(l), style: Charte.texte(14))),
                  Text('${l.lignes.length} art. · ${_statut(l.statut)}', style: gris),
                ]),
              ),
            ),
          if (listes.isEmpty) Text('Aucune', style: gris),
          const SizedBox(height: 10),
          Text('Courses faites (${courses.length})', style: Charte.texte(15, gras: true)),
          for (final c in courses.take(15))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${etat.nomCourse(c)} · ${c.nbArticles} articles', style: Charte.texte(14)),
            ),
          if (courses.isEmpty) Text('Aucune', style: gris),
          const SizedBox(height: 10),
          if (!m.moi)
            LigneMenu(titre: 'Envoyer l\'invitation', onTap: () => fermerPuis(() => envoyerInvitation(context, m))),
          LigneMenu(
            titre: 'Adresse mail',
            onTap: () async {
              final email = await demanderTexte(libelle: 'Adresse mail', ctx, titre: 'Adresse mail · ${m.nomAffiche}', initial: m.email, aide: 'prenom.nom@exemple.fr');
              if (email != null) etat.modifierEmail(m, email);
              maj(() {});
            },
          ),
          LigneMenu(
            titre: 'Renommer',
            onTap: () async {
              final nom = await demanderTexte(ctx, titre: 'Nom du membre', initial: m.nomAffiche);
              if (nom != null && nom.trim().isNotEmpty) etat.renommerMembre(m, nom);
              maj(() {});
            },
          ),
          if (!m.moi) LigneMenu(titre: 'Retirer du foyer', onTap: () => fermerPuis(() => _retirer(context, m))),
        ]);
      },
    );

/// La liste des membres : la personne touche son nom. Après avoir rejoint un foyer, on peut aussi
/// ne pas y être (nouveau membre) ou dire que l'appareil est partagé.
Future<void> choisirPersonne(BuildContext context, {bool premiereFois = false}) async {
  final etat = Etat.instance;
  final membres = [for (final m in etat.membresVisibles) if (!(m.moi && (premiereFois || etat.moiProvisoire))) m];
  final r = await volet<String>(
    context,
    fermable: !premiereFois && !etat.choixPersonne,
    builder: (ctx) => corpsVolet(
      titre: premiereFois ? 'Qui êtes-vous ?' : 'Qui utilise cet appareil ?',
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            premiereFois
                ? 'Touchez votre nom. Une même personne peut utiliser plusieurs appareils (téléphone, PC, navigateur).'
                : 'Touchez votre nom.',
            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 6),
        for (final m in membres)
          LigneMenu(
            key: ValueKey('personne-${m.nomAffiche}'),
            titre: m.nomAffiche,
            gauche: IconeRonde(null, texte: m.initiales),
            sousTitre: m.moi ? 'actuellement' : null,
            onTap: () => Navigator.of(ctx).pop(m.id),
          ),
        if (premiereFois) ...[
          LigneMenu(titre: 'Je ne suis pas dans la liste', onTap: () => Navigator.of(ctx).pop('nouveau')),
          LigneMenu(
            titre: 'Appareil partagé (tablette, PC de la famille)',
            sousTitre: 'on choisira son nom à chaque lancement',
            onTap: () => Navigator.of(ctx).pop('partage'),
          ),
        ],
      ]),
    ),
  );
  if (!context.mounted) return;
  switch (r) {
    case null:
      return;
    case 'nouveau':
      final nom = await demanderTexte(libelle: 'Prénom', context, titre: 'Votre prénom', aide: 'Il apparaîtra sur vos listes', valider: 'Valider');
      if (nom == null || nom.trim().isEmpty) {
        if (context.mounted) await choisirPersonne(context, premiereFois: true);
        return;
      }
      // Prénom déjà dans le foyer : c'est sans doute la même personne sur un autre appareil.
      final meme = [
        for (final m in etat.membresVisibles)
          if (!m.moi && m.nomAffiche.trim().toLowerCase() == nom.trim().toLowerCase()) m
      ];
      if (meme.isNotEmpty && context.mounted) {
        final ok = await confirmer(context,
            titre: 'C\'est vous, ${meme.first.nomAffiche} ?',
            contenu: Text(
                '« ${meme.first.nomAffiche} » fait déjà partie du foyer. Si c\'est vous sur un autre appareil, '
                'cet appareil vous est rattaché. Sinon, choisissez un autre prénom.',
                style: Charte.texte(16)),
            plein: 'C\'est moi',
            contour: 'Autre prénom');
        if (!context.mounted) return;
        if (ok == false) {
          etat.devenir(meme.first); // « C'est moi » (bouton plein)
          Nav.message(context, 'Bonjour ${meme.first.nomAffiche}');
        } else {
          await choisirPersonne(context, premiereFois: true);
        }
        return;
      }
      etat.resterNouveau(nom);
    case 'partage':
      etat.appareilPartage = true;
      await choisirPersonne(context);
      if (etat.moiProvisoire && context.mounted) await choisirPersonne(context, premiereFois: true);
    default:
      final m = etat.membre(r);
      if (m == null) return;
      etat.devenir(m);
      Nav.message(context, 'Bonjour ${m.nomAffiche}');
  }
}

/// Pose la question « Qui êtes-vous ? » dès que le foyer rejoint a été reçu, et « Qui utilise cet appareil ? »
/// au lancement d'un appareil partagé.
class GuetteurQuiSuisJe extends StatefulWidget {
  const GuetteurQuiSuisJe({super.key, required this.child});
  final Widget child;

  @override
  State<GuetteurQuiSuisJe> createState() => _GuetteurQuiSuisJeState();
}

class _GuetteurQuiSuisJeState extends State<GuetteurQuiSuisJe> {
  bool _ouverte = false;

  @override
  void initState() {
    super.initState();
    Etat.instance.addListener(_verifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifier());
  }

  @override
  void dispose() {
    Etat.instance.removeListener(_verifier);
    super.dispose();
  }

  Future<void> _verifier() async {
    final etat = Etat.instance;
    if (_ouverte || !mounted || !(etat.quiSuisJe || etat.choixPersonne)) return;
    _ouverte = true;
    await choisirPersonne(context, premiereFois: etat.quiSuisJe);
    _ouverte = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _statut(StatutListe s) => switch (s) {
      StatutListe.enConstruction => 'en préparation',
      StatutListe.prete => 'prête',
      StatutListe.enCours => 'en courses',
      StatutListe.terminee => 'terminée',
    };

Future<void> _voirListe(BuildContext context, Liste l) {
  final etat = Etat.instance;
  return modale(
    context,
    titre: etat.nomListe(l),
    icone: Icons.checklist,
    oui: null,
    non: null,
    croix: true,
    contenu: (ctx, _) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
      child: ListView(shrinkWrap: true, children: [
        for (final g in l.lignes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('${g.quantite > 1 ? '${g.quantite} × ' : ''}${etat.produit(g.produitId)?.nom ?? '?'}',
                style: Charte.texte(15)),
          ),
        if (l.lignes.isEmpty) Text('Liste vide', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
      ]),
    ),
  );
}

Future<void> _retirer(BuildContext context, Membre m) async {
  final ok = await confirmer(context,
      titre: 'Retirer ${m.nomAffiche} du foyer ?',
      contenu: Text(
          'Il disparaît de la liste des membres et ses appareils cessent de partager. Son nom reste sur ses listes '
          'et ses courses passées. Il pourra revenir avec le code de partage.',
          style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Retirer du foyer');
  if (ok == true) Etat.instance.supprimerMembre(m);
}
