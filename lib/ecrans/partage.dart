import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Mon foyer › Partage entre appareils : code de partage, état du réseau, serveur MQTT.

class EcranPartage extends StatelessWidget {
  const EcranPartage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Synchro.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([s, Etat.instance]),
      builder: (context, _) => PageBase(
        entete: const EnTeteFenetre(retour: true, sousTitre: 'Gérer › Mon foyer', titre: 'Partage entre appareils'),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            if (Etat.instance.modeDemo)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Mode démonstration : le partage ne concerne que les vraies données du foyer.',
                    style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              ),
            if (s.actif) ..._actif(context, s) else ..._inactif(context, s),
            GroupeRetractable(
              cle: 'partage/serveur',
              titre: 'Serveur MQTT',
              icone: Icons.dns_outlined,
              parDefaut: false,
              enfants: [_Serveur(serveur: s.serveur)],
            ),
            if (s.journal.isNotEmpty)
              GroupeRetractable(
                cle: 'partage/journal',
                titre: 'Échanges récents',
                icone: Icons.history,
                parDefaut: false,
                enfants: [
                  for (final e in s.journal.take(40))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('${heure(e.t)}  ${e.texte}',
                          style: Charte.texte(13, couleur: e.erreur ? _rouge : Charte.encre)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inactif(BuildContext context, Synchro s) => [
        const SizedBox(height: 8),
        Text('Les listes, magasins et produits du foyer peuvent être partagés entre vos téléphones et votre PC. '
            'Chaque appareil garde tout sur lui et fonctionne sans réseau ; les modifications passent dès que le réseau revient.',
            style: Charte.texte(15)),
        const SizedBox(height: 8),
        LigneMenu(
          icone: Icons.share_outlined,
          titre: 'Partager ce foyer',
          sousTitre: 'Premier appareil : crée le code à donner aux autres',
          onTap: () async {
            await s.creerPartage();
            if (context.mounted) Nav.message(context, 'Partage créé : donnez le code aux autres appareils');
          },
        ),
        LigneMenu(
          icone: Icons.login,
          titre: 'Rejoindre un foyer',
          sousTitre: 'J\'ai reçu un code : cet appareil prend les données du foyer',
          onTap: () => _rejoindre(context, s),
        ),
      ];

  List<Widget> _actif(BuildContext context, Synchro s) {
    final (texte, icone, couleur) = switch (s.etatReseau) {
      'connecte' => ('Connecté', Icons.cloud_done_outlined, Charte.encre),
      'connexion' => ('Connexion…', Icons.cloud_sync_outlined, Charte.texteSecondaire),
      _ => ('Hors ligne : les modifications partiront au retour du réseau', Icons.cloud_off_outlined, Charte.texteSecondaire),
    };
    final autres = s.appareils.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Code de partage', style: Charte.texte(15)),
              Text(s.code!.split('').join(' '), style: Charte.texte(28, gras: true, espacement: 2)),
              Text('À saisir sur les autres appareils (Rejoindre un foyer)', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ]),
          ),
          Lien('Copier', taille: 17, onTap: () {
            Clipboard.setData(ClipboardData(text: s.code!));
            Nav.message(context, 'Code copié');
          }),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icone, size: 26, color: Charte.couleurIcone(icone)),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: Charte.texte(16, gras: true, couleur: couleur))),
        ]),
      ),
      if (s.derniereErreur != null && s.etatReseau != 'connecte')
        Text(s.derniereErreur!, style: Charte.texte(13, couleur: _rouge)),
      Text('Cet appareil : ${s.nomAppareil}', style: Charte.texte(15)),
      for (final a in autres)
        Text('${a.enLigne ? '●' : '○'} ${a.nom}${a.enLigne ? ' (en ligne)' : ''}', style: Charte.texte(15)),
      if (autres.isEmpty) Text('Aucun autre appareil vu pour l\'instant', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      const SizedBox(height: 6),
      Text('${s.envoyes} modifications envoyées, ${s.recus} reçues depuis le lancement'
          '${s.enAttente > 0 ? ' · ${s.enAttente} en attente d\'intégration' : ''}',
          style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      const SizedBox(height: 8),
      LigneMenu(
        icone: Icons.sync,
        titre: 'Tout renvoyer',
        sousTitre: 'Si un appareil semble incomplet',
        onTap: s.etatReseau == 'connecte' ? s.toutRenvoyer : null,
      ),
      LigneMenu(
        icone: Icons.link_off,
        titre: 'Arrêter le partage sur cet appareil',
        sousTitre: 'Les données restent ici, elles ne circulent plus',
        onTap: () async {
          final ok = await confirmer(context,
              titre: 'Arrêter le partage ?',
              contenu: Text('Cet appareil garde ses données mais ne reçoit plus les modifications des autres.',
                  style: Charte.texte(16)),
              plein: 'Arrêter',
              contour: 'Annuler');
          if (ok == true) await s.arreterPartage();
        },
      ),
    ];
  }

  Future<void> _rejoindre(BuildContext context, Synchro s) async {
    final code = await demanderTexte(context, titre: 'Rejoindre un foyer', aide: 'Code de partage (10 caractères)', valider: 'Suivant');
    final net = (code ?? '').replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (net.isEmpty || !context.mounted) return;
    if (net.length != 10) {
      Nav.message(context, 'Le code de partage a 10 caractères');
      return;
    }
    final nom = await demanderTexte(context,
        titre: 'Votre nom', initial: Etat.instance.moi.nomAffiche, aide: 'Le nom sous lequel les autres vous voient', valider: 'Suivant');
    if (nom == null || nom.trim().isEmpty || !context.mounted) return;
    final ok = await confirmer(context,
        titre: 'Remplacer les données de cet appareil ?',
        contenu: Text(
            'Les listes, magasins et produits de cet appareil sont remplacés par ceux du foyer. '
            'Une copie de l\'ancienne base est gardée sur l\'appareil.\n\n'
            'Ouvrez l\'application sur un appareil du foyer pour qu\'il envoie les données.',
            style: Charte.texte(16)),
        plein: 'Rejoindre',
        contour: 'Annuler');
    if (ok != true) return;
    await s.rejoindre(net, nom);
    if (context.mounted) Nav.message(context, 'Foyer rejoint : les données arrivent dès qu\'un autre appareil est en ligne');
  }
}

const _rouge = Color(0xFFB00020);

String heure(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

/// Réglages du serveur MQTT, préremplis pour le serveur public HiveMQ.
class _Serveur extends StatefulWidget {
  const _Serveur({required this.serveur});
  final ServeurMqtt serveur;

  @override
  State<_Serveur> createState() => _ServeurState();
}

class _ServeurState extends State<_Serveur> {
  late final hote = TextEditingController(text: widget.serveur.hote);
  late final port = TextEditingController(text: '${widget.serveur.port}');
  late final utilisateur = TextEditingController(text: widget.serveur.utilisateur);
  late final mdp = TextEditingController(text: widget.serveur.motDePasse);
  late bool tls = widget.serveur.tls;

  @override
  void dispose() {
    for (final c in [hote, port, utilisateur, mdp]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _champ(String titre, TextEditingController c, {String? aide, bool secret = false, bool nombre = false, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextField(
          key: key,
          controller: c,
          obscureText: secret,
          keyboardType: nombre ? TextInputType.number : TextInputType.text,
          autocorrect: false,
          style: Charte.texte(16),
          decoration: InputDecoration(labelText: titre, hintText: aide),
        ),
      );

  void _hivemq() => setState(() {
        hote.text = ServeurMqtt.hoteHiveMq;
        port.text = '8883';
        tls = true;
        utilisateur.text = '';
        mdp.text = '';
      });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Text('Par défaut : serveur public HiveMQ, sans compte. Pour un serveur privé (HiveMQ Cloud, gratuit), '
            'indiquez son adresse, le port 8883 et l\'identifiant créé sur le site de HiveMQ. '
            'Tous les appareils du foyer doivent utiliser le même serveur.',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 6),
        _champ('Adresse du serveur', hote, aide: 'broker.hivemq.com', key: const ValueKey('mqtt-hote')),
        _champ('Port', port, aide: '8883', nombre: true, key: const ValueKey('mqtt-port')),
        InkWell(
          onTap: () => setState(() => tls = !tls),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              CaseACocher(coche: tls, taille: 26),
              const SizedBox(width: 12),
              Expanded(child: Text('Connexion chiffrée (TLS)', style: Charte.texte(16))),
            ]),
          ),
        ),
        _champ('Identifiant', utilisateur, aide: 'vide pour le serveur public'),
        _champ('Mot de passe', mdp, secret: true),
        const SizedBox(height: 6),
        Row(children: [
          Lien('Valeurs HiveMQ', taille: 16, onTap: _hivemq),
          const Spacer(),
          BoutonAction('Enregistrer', plein: true, onTap: () async {
            final p = int.tryParse(port.text.trim());
            if (hote.text.trim().isEmpty || p == null) {
              Nav.message(context, 'Adresse et port du serveur à indiquer');
              return;
            }
            await Synchro.instance.changerServeur(
                ServeurMqtt(hote: hote.text.trim(), port: p, tls: tls, utilisateur: utilisateur.text.trim(), motDePasse: mdp.text));
            if (context.mounted) Nav.message(context, 'Serveur enregistré');
          }),
        ]),
        const SizedBox(height: 8),
      ]);
}
