import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../donnees/serveur.dart';
import '../navigation.dart';
import '../theme.dart';

// Console d'administration › Serveur OVH (06/11/2026, Aristide) : initialisation du serveur, suivi technique,
// console shell. Tout passe par SSH avec la clé de la console (donnees/serveur.dart).

/// Commande du script d'installation (outils/vps/installer.sh), lancée dans la console shell.
const commandeInstallation =
    'curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/installer.sh -o installer.sh && sudo bash installer.sh';

/// Titre d'une page de la console : le chemin en petit, puis le titre.
class TitrePageAdmin extends StatelessWidget {
  const TitrePageAdmin(this.chemin, this.titre, {super.key, this.droite});
  final String chemin, titre;
  final Widget? droite;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chemin, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              Text(titre, style: Charte.texte(26, gras: true, couleur: Charte.encreNiveau)),
            ]),
          ),
          if (droite != null) droite!,
        ]),
      );
}

/// Voyant rond : vert (bon), orange (à surveiller), rouge (en panne), gris (inconnu).
class Voyant extends StatelessWidget {
  const Voyant(this.etat, {super.key, this.taille = 12});
  final bool? etat;
  final double taille;
  static const vert = Color(0xFF2E9E5B), orange = Color(0xFFE39B1B), rouge = Color(0xFFD64541), gris = Color(0xFFB0B0B0);

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(shape: BoxShape.circle, color: etat == null ? gris : (etat! ? vert : rouge)),
      );
}

/// Bandeau de connexion, en haut des pages du serveur : compte, adresse, état, Connecter / Réglages.
class BarreServeur extends StatelessWidget {
  const BarreServeur({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Serveur.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Container(
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 10),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(color: Charte.niveau(3), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Voyant(s.connecte ? true : (s.erreur == null ? null : false)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.utilisateur}@${s.hote} · domaine ${s.domaine}', style: Charte.texte(15, gras: true)),
              Text(
                s.connecte ? 'Connecté par la clé de la console' : (s.erreur ?? 'Pas connecté'),
                style: Charte.texte(13.5, couleur: s.erreur != null && !s.connecte ? Voyant.rouge : Charte.texteSecondaire),
              ),
            ]),
          ),
          SizedBox(
            width: 150,
            child: Bouton(
              key: const ValueKey('serveur-connecter'),
              texte: s.connecte ? 'Déconnecter' : 'Connecter',
              icone: s.connecte ? Icons.link_off : Icons.link,
              hauteur: 38,
              onTap: s.connecte ? s.deconnecter : () => s.connecter(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Bouton(key: const ValueKey('serveur-reglages'), texte: 'Réglages', icone: Icons.tune, hauteur: 38, onTap: () => reglerServeur(context)),
          ),
        ]),
      ),
    );
  }
}

/// Domaine, adresse de connexion et compte.
Future<void> reglerServeur(BuildContext context) async {
  final s = Serveur.instance;
  final domaine = TextEditingController(text: s.domaine), hote = TextEditingController(text: s.hote);
  final compte = TextEditingController(text: s.utilisateur);
  final ok = await confirmer(
    context,
    titre: 'Connexion au serveur',
    icone: Icons.tune,
    contenu: SizedBox(
      width: 420,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: domaine, style: Charte.texte(16), decoration: const InputDecoration(labelText: 'Nom de domaine')),
        const SizedBox(height: 12),
        TextField(controller: hote, style: Charte.texte(16), decoration: const InputDecoration(labelText: 'Adresse du serveur (IP ou nom)')),
        const SizedBox(height: 12),
        TextField(controller: compte, style: Charte.texte(16), decoration: const InputDecoration(labelText: 'Compte')),
      ]),
    ),
    plein: 'Enregistrer',
    contour: 'Annuler',
  );
  if (ok != false && ok != null) {
    s.deconnecter();
    s.domaine = domaine.text;
    s.hote = hote.text;
    s.utilisateur = compte.text;
  }
}

// ---------------------------------------------------------------------------------------------- Initialisation

/// Serveur OVH › Initialisation : les étapes, dans l'ordre, chacune avec son état et son action.
class PageInitialisation extends StatefulWidget {
  const PageInitialisation({super.key, required this.ouvrirShell});

  /// Ouvre la console shell en y tapant une commande.
  final void Function(String commande) ouvrirShell;

  @override
  State<PageInitialisation> createState() => _PageInitialisationState();
}

class _PageInitialisationState extends State<PageInitialisation> {
  Map<String, String?>? _adresses;
  String? _clePublique;
  bool _verification = false;

  @override
  void initState() {
    super.initState();
    _lireCle();
  }

  Future<void> _lireCle() async {
    final c = await Serveur.instance.clePublique();
    if (mounted) setState(() => _clePublique = c);
  }

  Future<void> _verifierAdresses() async {
    setState(() => _verification = true);
    final a = await Serveur.instance.adressesDomaine();
    if (mounted) {
      setState(() {
        _adresses = a;
        _verification = false;
      });
    }
  }

  /// Les noms du domaine pointent tous vers l'adresse du serveur (ou, si on se connecte par un nom, vers la même).
  bool? get _adressesBonnes {
    final a = _adresses;
    if (a == null) return null;
    final ip = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(Serveur.instance.hote) ? Serveur.instance.hote : a.values.first;
    return a.values.every((v) => v != null && v == ip);
  }

  @override
  Widget build(BuildContext context) {
    final s = Serveur.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final suivi = s.dernierSuivi;
        final installe = suivi?['installe'] == 'oui';
        final servicesOk = suivi != null && Serveur.services.every((x) => suivi['service.$x'] == 'active');
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const TitrePageAdmin('Serveur OVH', 'Initialisation'),
          const BarreServeur(),
          _Etape(
            numero: 1,
            titre: 'Adresses du domaine',
            fait: _adressesBonnes,
            texte: 'Dans l\'espace client OVH (Noms de domaine › ${s.domaine} › Zone DNS), une entrée A vers l\'adresse '
                'du serveur pour chacun des noms ci-dessous. Sans elles, pas de certificats https.',
            detail: _adresses == null
                ? null
                : [for (final e in _adresses!.entries) '${e.key} → ${e.value ?? 'introuvable'}'].join('\n'),
            actions: [
              (_verification ? 'Vérification…' : 'Vérifier', Icons.travel_explore, _verification ? null : _verifierAdresses),
            ],
          ),
          _Etape(
            numero: 2,
            titre: 'Clé de la console',
            fait: _clePublique != null,
            texte: 'Une clé SSH créée sur ce PC, dans le dossier de la console : elle remplace le mot de passe du serveur. '
                'Elle ne quitte jamais ce PC (seule sa partie publique va sur le serveur).',
            detail: _clePublique,
            actions: [
              if (_clePublique == null)
                ('Créer la clé', Icons.key_outlined, () async {
                  await s.creerCle();
                  await _lireCle();
                }),
            ],
          ),
          _Etape(
            numero: 3,
            titre: 'Accès au serveur par la clé',
            fait: s.connecte ? true : (s.fait('acces') ? null : false),
            texte: 'Une seule fois : le mot de passe du compte ${s.utilisateur} (mail d\'OVH) sert à poser la clé sur le '
                'serveur. Il n\'est pas gardé ; ensuite, la clé suffit et le script d\'installation ferme l\'accès par mot de passe.',
            actions: [
              ('Poser la clé', Icons.vpn_key_outlined, _clePublique == null ? null : () => _poserCle(context)),
              ('Essayer la connexion', Icons.link, () async {
                if (await s.connecter()) s.marquer('acces', true);
              }),
            ],
          ),
          _Etape(
            numero: 4,
            titre: 'Installation des services',
            fait: suivi == null ? null : installe && servicesOk,
            texte: 'Le script d\'installation s\'exécute dans la console shell : il pose les questions (domaine, adresse mail, '
                'mots de passe, qui restent sur le serveur), installe Nginx, Mosquitto, ntfy, le relais de mails, les '
                'sauvegardes, puis affiche les secrets à saisir sur GitHub. Il se relance sans risque.',
            detail: suivi == null
                ? 'État inconnu : « Actualiser » dans le suivi technique.'
                : [for (final x in Serveur.services) '$x : ${suivi['service.$x']?.isNotEmpty == true ? suivi['service.$x'] : 'absent'}'].join('\n'),
            actions: [
              ('Lancer l\'installation', Icons.play_arrow, () => widget.ouvrirShell(commandeInstallation)),
              ('Vérifier', Icons.refresh, s.suivre),
            ],
          ),
          _Etape(
            numero: 5,
            titre: 'Secrets GitHub',
            fait: s.fait('secrets'),
            texte: 'À la fin de l\'installation, le script affiche six valeurs : MQTT_HOTE_VPS, MQTT_UTILISATEUR_VPS, '
                'MQTT_MOT_DE_PASSE_VPS, RELAIS_CLE, VPS_HOTE, VPS_CLE_DEPLOIEMENT. Saisissez-les comme secrets du dépôt, '
                'puis cochez.',
            actions: [
              ('Page des secrets', Icons.open_in_new,
                  () => launchUrl(Uri.parse('https://github.com/ChristianFrench/liste-de-courses/settings/secrets/actions'))),
              (s.fait('secrets') ? 'Décocher' : 'C\'est fait', Icons.check, () => s.marquer('secrets', !s.fait('secrets'))),
            ],
          ),
          _Etape(
            numero: 6,
            titre: 'Bascule de l\'application',
            fait: s.fait('bascule'),
            texte: 'Écrivez « VPS prêt » à Claude : l\'application, la version web et le site passent sur le serveur '
                '(partage, notifications, mails), avec les services gratuits gardés en secours le temps de la bascule.',
            actions: [
              (s.fait('bascule') ? 'Décocher' : 'C\'est fait', Icons.check, () => s.marquer('bascule', !s.fait('bascule'))),
            ],
          ),
        ]);
      },
    );
  }

  Future<void> _poserCle(BuildContext context) async {
    final s = Serveur.instance;
    final mdp = await demanderTexte(context,
        titre: 'Mot de passe du compte ${s.utilisateur}', libelle: 'Mot de passe', valider: 'Poser la clé', masque: true);
    if (mdp == null || mdp.isEmpty) return;
    final ok = await s.poserCle(mdp);
    if (ok) s.marquer('acces', true);
    if (context.mounted) Nav.message(context, ok ? 'Clé posée : la console se connecte maintenant sans mot de passe' : (s.erreur ?? 'Échec'));
  }
}

class _Etape extends StatelessWidget {
  const _Etape({required this.numero, required this.titre, required this.fait, required this.texte, this.detail, this.actions = const []});
  final int numero;
  final String titre, texte;
  final bool? fait;
  final String? detail;
  final List<(String, IconData, VoidCallback?)> actions;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fait == true ? Voyant.vert : Charte.separateurZone, width: fait == true ? 1.6 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fait == true ? Voyant.vert : Charte.niveau(2)),
            child: fait == true
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : Text('$numero', style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(titre, style: Charte.texte(17, gras: true)),
                const SizedBox(width: 10),
                Text(fait == true ? 'fait' : (fait == false ? 'à faire' : 'à vérifier'),
                    style: Charte.texte(13.5, gras: true, couleur: fait == true ? Voyant.vert : (fait == false ? Voyant.orange : Charte.texteSecondaire))),
              ]),
              const SizedBox(height: 4),
              Text(texte, style: Charte.texte(14.5, couleur: Charte.texteSecondaire)),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Charte.niveau(4), borderRadius: BorderRadius.circular(6)),
                  child: SelectableText(detail!, style: const TextStyle(fontFamily: 'Consolas', fontFamilyFallback: ['monospace'], fontSize: 13)),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (t, i, f) in actions)
                    SizedBox(width: 220, child: Bouton(key: ValueKey('etape$numero-$t'), texte: t, icone: i, hauteur: 38, taille: 15, onTap: f)),
                ]),
              ],
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------- Suivi technique

/// Serveur OVH › Suivi technique : système, services, certificats, partage, sécurité, sauvegarde.
/// Relu toutes les minutes tant que la page est ouverte.
class PageSuivi extends StatefulWidget {
  const PageSuivi({super.key, required this.ouvrirShell});
  final void Function(String commande) ouvrirShell;

  /// Lecture à l'ouverture puis chaque minute (coupée dans les tests, sans serveur).
  static bool automatique = true;

  @override
  State<PageSuivi> createState() => _PageSuiviState();
}

class _PageSuiviState extends State<PageSuivi> {
  Timer? _minuterie;
  bool _lecture = false;

  @override
  void initState() {
    super.initState();
    if (PageSuivi.automatique) {
      _actualiser();
      _minuterie = Timer.periodic(const Duration(minutes: 1), (_) => _actualiser());
    }
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _actualiser() async {
    if (_lecture) return;
    setState(() => _lecture = true);
    await Serveur.instance.suivre();
    if (mounted) setState(() => _lecture = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Serveur.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final m = s.dernierSuivi ?? const <String, String>{};
        String v(String k) => m[k]?.isNotEmpty == true ? m[k]! : '?';
        final le = s.suiviLe;
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          TitrePageAdmin(
            'Serveur OVH',
            'Suivi technique',
            droite: SizedBox(
              width: 200,
              child: Bouton(
                key: const ValueKey('suivi-actualiser'),
                texte: _lecture ? 'Lecture…' : 'Actualiser',
                icone: Icons.refresh,
                hauteur: 38,
                onTap: _lecture ? null : _actualiser,
              ),
            ),
          ),
          const BarreServeur(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
            child: Text(
              le == null ? 'Pas encore lu.' : 'Lu à ${le.hour.toString().padLeft(2, '0')}:${le.minute.toString().padLeft(2, '0')}, relu chaque minute.',
              style: Charte.texte(13.5, couleur: Charte.texteSecondaire),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              _Tuile('Système', Icons.dns_outlined, [
                _Ligne('En marche depuis', _francais(v('uptime'))),
                _Ligne('Charge (1, 5, 15 min)', '${v('charge')} · ${v('coeurs')} cœurs', bon: _chargeBonne(m)),
                _Ligne('Mémoire', _mo(m['memoire']), bon: _part(m['memoire']) == null ? null : _part(m['memoire'])! < 0.85),
                _Ligne('Disque', _mo(m['disque']), bon: _part(m['disque']) == null ? null : _part(m['disque'])! < 0.85),
                _Ligne('Mises à jour en attente', v('majs'), bon: m['majs'] == null ? null : (int.tryParse(m['majs']!) ?? 0) < 20),
                _Ligne('Redémarrage demandé', v('redemarrage'), bon: m['redemarrage'] == null ? null : m['redemarrage'] == 'non'),
              ]),
              _Tuile('Services', Icons.settings_suggest_outlined, [
                for (final x in Serveur.services)
                  _Ligne(x, m['service.$x']?.isNotEmpty == true ? m['service.$x']! : 'absent',
                      bon: m.isEmpty ? null : m['service.$x'] == 'active'),
              ]),
              _Tuile('Certificats https', Icons.lock_outline, [
                for (final n in [s.domaine, 'mqtt.${s.domaine}', 'ntfy.${s.domaine}']) _certificat(n, m['certificat.$n']),
              ]),
              _Tuile('Partage et sécurité', Icons.swap_horiz, [
                _Ligne('Appareils connectés (MQTT)', v('clients_mqtt')),
                _Ligne('Navigateurs connectés', v('clients_web')),
                _Ligne('Adresses bannies (SSH)', v('bannis')),
                _Ligne('Dernière sauvegarde', v('sauvegarde'), bon: m.isEmpty ? null : m['sauvegarde']?.isNotEmpty == true),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
            child: Text('Interventions (dans la console shell)', style: Charte.texte(18, gras: true, couleur: Charte.encreNiveau)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (t, i, c) in [
                ('Mettre à jour le système', Icons.system_update_alt, 'sudo apt update && sudo apt -y full-upgrade'),
                ('Journal des services', Icons.receipt_long_outlined,
                    'sudo journalctl -u nginx -u mosquitto -u ntfy -u relais-mail -n 60 --no-pager'),
                ('Relancer les services', Icons.restart_alt, 'sudo systemctl restart nginx mosquitto ntfy relais-mail && systemctl is-active nginx mosquitto ntfy relais-mail'),
                ('Renouveler les certificats', Icons.lock_reset, 'sudo certbot renew'),
                ('Relancer l\'installation', Icons.play_arrow, commandeInstallation),
                ('Redémarrer le serveur', Icons.power_settings_new, 'sudo reboot'),
              ])
                SizedBox(width: 260, child: Bouton(texte: t, icone: i, hauteur: 38, taille: 15, onTap: () => widget.ouvrirShell(c))),
            ]),
          ),
        ]);
      },
    );
  }

  /// « up 3 days, 4 hours, 2 minutes » → « 3 jours, 4 heures, 2 minutes ».
  static String _francais(String t) => t
      .replaceFirst('up ', '')
      .replaceAll(RegExp(r'\bweeks?\b'), 'sem.')
      .replaceAll('days', 'jours')
      .replaceAll(RegExp(r'\bday\b'), 'jour')
      .replaceAll('hours', 'heures')
      .replaceAll(RegExp(r'\bhour\b'), 'heure');

  static double? _part(String? x) {
    final p = x?.split('/');
    if (p == null || p.length != 2) return null;
    final a = double.tryParse(p[0]), b = double.tryParse(p[1]);
    return a == null || b == null || b == 0 ? null : a / b;
  }

  static String _mo(String? x) {
    final p = x?.split('/');
    if (p == null || p.length != 2) return '?';
    String g(String n) => '${((double.tryParse(n) ?? 0) / 1024).toStringAsFixed(1)} Go';
    return '${g(p[0])} sur ${g(p[1])} (${((_part(x) ?? 0) * 100).round()} %)';
  }

  static bool? _chargeBonne(Map<String, String> m) {
    final c = double.tryParse((m['charge'] ?? '').split(' ').first), n = int.tryParse(m['coeurs'] ?? '');
    return c == null || n == null ? null : c < n;
  }

  static _Ligne _certificat(String nom, String? fin) {
    if (fin == null || fin.isEmpty) return _Ligne(nom, 'aucun', bon: fin == null ? null : false);
    final d = _dateOpenssl(fin);
    if (d == null) return _Ligne(nom, fin);
    final jours = d.difference(DateTime.now()).inDays;
    return _Ligne(nom, 'jusqu\'au ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ($jours j)', bon: jours > 14);
  }

  /// « Feb  4 12:00:00 2027 GMT » → date.
  static DateTime? _dateOpenssl(String t) {
    const mois = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final p = t.split(RegExp(r'\s+'));
    if (p.length < 4) return null;
    final m = mois.indexOf(p[0]);
    final j = int.tryParse(p[1]), a = int.tryParse(p[3]);
    return m < 0 || j == null || a == null ? null : DateTime(a, m + 1, j);
  }
}

class _Ligne {
  const _Ligne(this.libelle, this.valeur, {this.bon});
  final String libelle, valeur;
  final bool? bon;
}

class _Tuile extends StatelessWidget {
  const _Tuile(this.titre, this.icone, this.lignes);
  final String titre;
  final IconData icone;
  final List<_Ligne> lignes;

  @override
  Widget build(BuildContext context) => Container(
        width: 540,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: Charte.blanc, borderRadius: BorderRadius.circular(10), border: Border.all(color: Charte.separateurZone)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icone(icone, size: 24, color: Charte.cadre),
            const SizedBox(width: 10),
            Text(titre, style: Charte.texte(17, gras: true)),
          ]),
          const SizedBox(height: 8),
          for (final l in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Voyant(l.bon, taille: 10),
                const SizedBox(width: 8),
                Expanded(child: Text(l.libelle, style: Charte.texte(14.5, couleur: Charte.texteSecondaire))),
                Flexible(child: Text(l.valeur, textAlign: TextAlign.right, style: Charte.texte(14.5, gras: true))),
              ]),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------- Console shell

/// La session shell reste ouverte quand on change de page de la console.
class ConsoleShell {
  ConsoleShell._();
  static final instance = ConsoleShell._();

  final terminal = Terminal(maxLines: 10000);
  SessionShell? _session;
  bool get ouverte => _session != null;
  final _etat = ValueNotifier<String>('Pas ouverte');
  ValueListenable<String> get etat => _etat;

  Future<void> ouvrir() async {
    if (_session != null) return;
    _etat.value = 'Connexion…';
    try {
      final s = await Serveur.instance.shell(terminal.viewWidth, terminal.viewHeight);
      _session = s;
      _etat.value = 'Ouverte';
      terminal.onOutput = (d) => s.ecrire(utf8.encode(d));
      terminal.onResize = (l, h, _, __) => s.redimensionner(l, h);
      s.sortie.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen(terminal.write);
      s.fin.whenComplete(() {
        if (_session == s) _session = null;
        _etat.value = 'Fermée';
        terminal.write('\r\n[session fermée]\r\n');
      });
    } catch (e) {
      _etat.value = 'Échec : ${Serveur.instance.erreur ?? e}';
    }
  }

  /// Tape une commande dans la session (ouverte au besoin).
  Future<void> envoyer(String commande) async {
    await ouvrir();
    _session?.ecrire(utf8.encode('$commande\n'));
  }

  void fermer() {
    _session?.fermer();
    _session = null;
  }
}

/// Serveur OVH › Console shell : le terminal du serveur, dans la console.
class PageShell extends StatefulWidget {
  const PageShell({super.key, this.commande});

  /// Commande à taper à l'ouverture (« Lancer l'installation »…).
  final String? commande;

  /// Ouverture de la session à l'affichage (coupée dans les tests, sans serveur).
  static bool ouvrirAuto = true;

  @override
  State<PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<PageShell> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (!PageShell.ouvrirAuto) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = widget.commande;
      if (c != null) {
        await ConsoleShell.instance.envoyer(c);
      } else {
        await ConsoleShell.instance.ouvrir();
      }
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ConsoleShell.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TitrePageAdmin(
        'Serveur OVH',
        'Console shell',
        droite: ValueListenableBuilder<String>(
          valueListenable: c.etat,
          builder: (context, e, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: Bouton(
                key: const ValueKey('shell-ouvrir'),
                texte: c.ouverte ? 'Fermer' : 'Ouvrir',
                icone: c.ouverte ? Icons.close : Icons.terminal,
                hauteur: 38,
                onTap: () async {
                  if (c.ouverte) {
                    c.fermer();
                  } else {
                    await c.ouvrir();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
          ]),
        ),
      ),
      const BarreServeur(),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: TerminalThemes.defaultTheme.background, borderRadius: BorderRadius.circular(8)),
          child: TerminalView(
            c.terminal,
            focusNode: _focus,
            autofocus: true,
            textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'Consolas'),
          ),
        ),
      ),
    ]);
  }
}
