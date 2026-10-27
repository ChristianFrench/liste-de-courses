import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';
import 'bienvenue.dart';
import 'parametres.dart' show OptionFoyer, ajouterMembreParNom, repartirANeuf;

// Gérer › Mon foyer › Foyer : seul ou en foyer, code de partage, membres (26/10/2026).
// L'administrateur voit la dernière connexion et l'activité de chacun, régénère le code,
// renomme, radie ou supprime un membre. Un membre voit le nom et la version de chacun.

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
    final admin = !enFoyer || etat.suisAdministrateur;
    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.home_outlined, sousTitre: 'Gérer › Mon foyer', titre: 'Foyer'),
      corps: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
        Text(etat.foyerNom, style: Charte.texte(20, gras: true)),
        Text(
            enFoyer
                ? 'Foyer partagé · vous en êtes ${etat.suisAdministrateur ? 'l\'administrateur' : 'membre'}'
                : 'Seul sur cet appareil · pas de synchronisation',
            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        if (enFoyer) ..._code(context, s, etat.suisAdministrateur),
        const TitreSection('Membres', cote: 0),
        for (final m in etat.membresVisibles) _LigneMembre(m, admin: admin, enFoyer: enFoyer),
        if (!enFoyer)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Lien('+ Nouveau membre', onTap: () => ajouterMembreParNom(context)),
          ),
        OptionFoyer(
          texte: 'Envoyer la liste à tout le foyer',
          aide: 'Le mail est préparé avec les adresses de tous les membres',
          coche: etat.envoiFoyer,
          onChange: (v) => etat.options(envoiFoyer: v),
        ),
      ]),
      bas: [
        BarreAction(boutons: [
          if (admin)
            Bouton(
              texte: 'Renommer',
              taille: 15,
              onTap: () async {
                final nom = await demanderTexte(context, titre: 'Nom du foyer', initial: etat.foyerNom);
                if (nom != null && nom.isNotEmpty) etat.renommerFoyer(nom);
              },
            ),
          Bouton(texte: enFoyer ? 'Utiliser seul' : 'Passer en foyer', taille: 15, onTap: () => _changerMode(context, enFoyer)),
          if (admin) Bouton(texte: 'Foyer neuf', taille: 15, onTap: () => repartirANeuf(context)),
        ]),
      ],
    );
  }

  List<Widget> _code(BuildContext context, Synchro s, bool admin) => [
        const TitreSection('Code de partage', cote: 0),
        Text(s.code!.split('').join(' '), maxLines: 1, style: Charte.texte(24, gras: true, espacement: 1)),
        Text('À saisir sur un autre appareil : « Rejoindre un foyer ». Tous ceux qui ont ce code font partie du foyer.',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          BoutonAction('Copier', onTap: () {
            Clipboard.setData(ClipboardData(text: s.code!));
            Nav.message(context, 'Code copié');
          }),
          BoutonAction('Envoyer par mail', onTap: () => _envoyerCode(context, s.code!)),
          if (admin) BoutonAction('Régénérer', onTap: () => _regenerer(context, s)),
        ]),
      ];

  Future<void> _envoyerCode(BuildContext context, String code) async {
    final etat = Etat.instance;
    final corps = 'Bonjour,\n\nPour partager nos listes de courses dans le foyer « ${etat.foyerNom} » :\n\n'
        '1. Installez l\'application : sur Android $lienApk ; sur iPhone, iPad ou PC, ouvrez $lienWeb\n'
        '2. Au premier lancement, choisissez « Rejoindre un foyer ».\n'
        '3. Saisissez le code de partage : $code\n\n${etat.moi.nomAffiche}';
    final q = {'subject': 'Rejoindre le foyer ${etat.foyerNom}', 'body': corps}
        .entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final ok = await launchUrl(Uri.parse('mailto:?$q'));
    if (!ok && context.mounted) Nav.message(context, 'Aucune messagerie trouvée : utilisez « Copier »');
  }

  Future<void> _regenerer(BuildContext context, Synchro s) async {
    final ok = await confirmer(context,
        titre: 'Régénérer le code ?',
        icone: Icons.key_outlined,
        contenu: Text(
            'Un nouveau code remplace l\'ancien. Les autres appareils s\'arrêtent de partager et demandent le nouveau code '
            '(leurs données restent). Donnez-le à ceux qui doivent rester dans le foyer.',
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

class _LigneMembre extends StatelessWidget {
  const _LigneMembre(this.m, {required this.admin, required this.enFoyer});
  final Membre m;
  final bool admin, enFoyer;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance, s = Synchro.instance;
    final radie = etat.estRadie(m);
    final versions = [
      if (m.moi) s.maVersion,
      for (final a in s.appareilsDe(m)) Synchro.libelleVersion(a.plateforme, a.version),
    ].toSet().join(', ');
    final details = [
      m.roleAffiche + (m.moi ? ' (vous)' : ''),
      if (radie) 'radié',
      if (enFoyer && versions.isNotEmpty) versions,
      if (enFoyer && admin && !m.moi) _connexion(m),
      if (!enFoyer) m.email.isEmpty ? 'adresse mail : touchez pour l\'indiquer' : m.email,
    ];
    return LigneMenu(
      titre: m.nomAffiche,
      sousTitre: details.join(' · '),
      gauche: Opacity(opacity: radie ? 0.4 : 1, child: IconeRonde(null, texte: m.initiales)),
      onTap: () => _fiche(context, m, admin: admin, enFoyer: enFoyer),
    );
  }
}

String _connexion(Membre m) {
  final aps = Synchro.instance.appareilsDe(m);
  if (aps.any((a) => a.enLigne)) return 'en ligne';
  final vus = [for (final a in aps) if (a.vu != null) a.vu!]..sort();
  return vus.isEmpty ? 'jamais vu' : 'vu ${_vu(vus.last)}';
}

/// Fiche d'un membre : appareils, activité (administrateur), mail, et les actions de l'administrateur.
Future<void> _fiche(BuildContext context, Membre m, {required bool admin, required bool enFoyer}) => modale(
      context,
      titre: m.nomAffiche,
      icone: Icons.person_outline,
      oui: null,
      non: null,
      croix: true,
      contenu: (ctx, maj) {
        final etat = Etat.instance, s = Synchro.instance;
        final radie = etat.estRadie(m);
        final listes = etat.listesDuMembre(m), courses = etat.coursesDuMembre(m);
        final gris = Charte.texte(14, couleur: Charte.texteSecondaire);
        void fermerPuis(void Function() f) {
          Navigator.of(ctx).pop();
          f();
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${m.roleAffiche}${radie ? ' · radié' : ''}', style: Charte.texte(15)),
              Text(m.email.isEmpty ? 'Pas d\'adresse mail' : m.email, style: gris),
              if (enFoyer) ...[
                const SizedBox(height: 10),
                Text('Appareils', style: Charte.texte(15, gras: true)),
                if (m.moi) Text('${s.maVersion} · cet appareil', style: Charte.texte(14)),
                for (final a in s.appareilsDe(m))
                  Text(
                      '${Synchro.libelleVersion(a.plateforme, a.version)}'
                      '${admin ? ' · ${a.enLigne ? 'en ligne' : a.vu == null ? 'jamais vu' : 'vu ${_vu(a.vu!)}'}' : ''}',
                      style: Charte.texte(14)),
                if (!m.moi && s.appareilsDe(m).isEmpty) Text('Aucun appareil vu depuis le lancement', style: gris),
              ],
              if (admin) ...[
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
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (admin || m.moi)
                  BoutonAction('Mail', onTap: () async {
                    final email = await demanderTexte(ctx, titre: 'Adresse mail · ${m.nomAffiche}', initial: m.email, aide: 'prenom.nom@exemple.fr');
                    if (email != null) etat.modifierEmail(m, email);
                    maj(() {});
                  }),
                if (admin || m.moi)
                  BoutonAction('Renommer', onTap: () async {
                    final nom = await demanderTexte(ctx, titre: 'Nom du membre', initial: m.nomAffiche);
                    if (nom != null && nom.trim().isNotEmpty) etat.renommerMembre(m, nom);
                    maj(() {});
                  }),
                if (admin && enFoyer && !m.moi && !radie)
                  BoutonAction('Radier', onTap: () => fermerPuis(() => _radier(context, m))),
                if (admin && enFoyer && radie)
                  BoutonAction('Réactiver', onTap: () {
                    etat.reactiverMembre(m);
                    maj(() {});
                  }),
                if (admin && !m.moi) BoutonAction('Supprimer', onTap: () => fermerPuis(() => _supprimer(context, m))),
                if (enFoyer && !m.moi && !radie) BoutonAction('C\'est moi', onTap: () => fermerPuis(() => _cEstMoi(context, m))),
              ]),
            ]),
          ),
        );
      },
    );

/// « C'est moi » : cet appareil appartient à [m] (la même personne sur un autre appareil).
Future<void> _cEstMoi(BuildContext context, Membre m) async {
  final etat = Etat.instance;
  final ok = await confirmer(
    context,
    titre: 'Vous êtes ${m.nomAffiche} ?',
    icone: Icons.person_outline,
    contenu: Text(
        'Cet appareil sera rattaché à ${m.nomAffiche}, avec ses autres appareils. « ${etat.moi.nomAffiche} », le nom utilisé '
        'jusqu\'ici sur cet appareil, disparaît de la liste des membres ; ses listes et ses courses passent à ${m.nomAffiche}.',
        style: Charte.texte(16)),
    plein: 'Annuler',
    contour: 'C\'est moi',
  );
  if (ok != true || !context.mounted) return;
  etat.devenir(m);
  Nav.message(context, 'Cet appareil est maintenant celui de ${m.nomAffiche}');
}

/// Après avoir rejoint un foyer : « Qui êtes-vous ? » parmi les membres, ou nouveau membre.
Future<void> demanderQuiSuisJe(BuildContext context) async {
  final etat = Etat.instance;
  final autres = [for (final m in etat.membresVisibles) if (!m.moi && !etat.estRadie(m)) m];
  Membre? choisi;
  final ok = await modale(
    context,
    titre: 'Qui êtes-vous ?',
    icone: Icons.person_outline,
    oui: 'Valider',
    non: null,
    contenu: (context, maj) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Une même personne peut utiliser plusieurs appareils (téléphone, PC, navigateur) : choisissez votre nom '
          's\'il est déjà dans le foyer.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      const SizedBox(height: 8),
      for (final m in autres)
        CaseModale(texte: m.nomAffiche, coche: identical(choisi, m), onChange: (_) => maj(() => choisi = m)),
      CaseModale(
        texte: 'Je suis un nouveau membre : ${etat.moi.nomAffiche}',
        coche: choisi == null,
        onChange: (_) => maj(() => choisi = null),
      ),
    ]),
  );
  if (!ok) return;
  if (choisi == null) {
    etat.resterNouveau();
  } else {
    etat.devenir(choisi!);
  }
}

/// Pose la question « Qui êtes-vous ? » dès que le foyer rejoint a été reçu.
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
  }

  @override
  void dispose() {
    Etat.instance.removeListener(_verifier);
    super.dispose();
  }

  Future<void> _verifier() async {
    if (_ouverte || !mounted || !Etat.instance.quiSuisJe) return;
    _ouverte = true;
    await demanderQuiSuisJe(context);
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

Future<void> _radier(BuildContext context, Membre m) async {
  final ok = await confirmer(context,
      titre: 'Radier ${m.nomAffiche} ?',
      contenu: Text(
          'Son appareil cesse de partager et garde ses données. Pour revenir, il lui faudra le code de partage, '
          'que vous lui redonnerez. Pour l\'exclure sûrement, régénérez aussi le code.',
          style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Radier');
  if (ok == true) Etat.instance.radierMembre(m);
}

Future<void> _supprimer(BuildContext context, Membre m) async {
  final ok = await confirmer(context,
      titre: 'Supprimer ${m.nomAffiche} ?',
      contenu: Text(
          'Il disparaît de la liste des membres et son appareil cesse de partager. Ses listes et ses courses passées restent.',
          style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Supprimer');
  if (ok == true) Etat.instance.supprimerMembre(m);
}
