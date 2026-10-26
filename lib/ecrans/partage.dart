import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Synchronisation : partage entre appareils (code, état du réseau, serveur MQTT, journal des échanges).
// L'appui sur le nuage de la barre de titre ouvre seulement l'état : [montrerEtatSynchro].

/// Titre de l'état du partage, selon le voyant.
String titreEtatSynchro(Synchro s) {
  final autres = s.autresEnLigne;
  return switch (s.pastille) {
    'blanc' => 'Foyer non partagé',
    'rouge' => s.etatReseau == 'connexion' ? 'Connexion au serveur…' : 'Pas de connexion au serveur',
    'orange' => 'Aucun autre appareil connecté',
    _ => s.enEchange ? 'Synchronisation en cours…' : 'À jour avec $autres appareil${autres > 1 ? 's' : ''}',
  };
}

/// Fenêtre ouverte par le nuage : l'état actuel, la signification du voyant, les appareils. Rien d'autre.
Future<void> montrerEtatSynchro(BuildContext context) => modale(
      context,
      titre: 'Synchronisation',
      icone: Icons.cloud_outlined,
      oui: null,
      non: null,
      contenu: (context, _) => ListenableBuilder(
        listenable: Synchro.instance,
        builder: (context, _) {
          final s = Synchro.instance;
          final actuel = s.pastille == 'vert' && s.enEchange ? 'clignotant' : s.pastille;
          Widget voyant(String cle, Color couleur, String texte) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  PointSynchro(taille: 16, couleur: couleur),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(texte,
                          style: Charte.texte(15, gras: cle == actuel, couleur: cle == actuel ? Charte.encre : Charte.texteSecondaire))),
                ]),
              );
          final autres = s.appareils.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              PointSynchro(taille: 20, couleur: BoutonSynchro.couleur(s.pastille), clignote: actuel == 'clignotant'),
              const SizedBox(width: 10),
              Expanded(child: Text(titreEtatSynchro(s), style: Charte.texte(19, gras: true))),
            ]),
            if (s.actif && !s.liaisonOk && s.derniereErreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s.derniereErreur!, style: Charte.texte(13, couleur: _rouge)),
              ),
            const SizedBox(height: 14),
            Text('Signification du voyant', style: Charte.texte(15, gras: true)),
            voyant('blanc', Charte.blanc, 'Blanc : foyer non partagé'),
            voyant('rouge', BoutonSynchro.rouge, 'Rouge : pas de connexion au serveur MQTT ou pas de réseau'),
            voyant('orange', BoutonSynchro.orange, 'Orange : connecté, aucun autre appareil du foyer en ligne'),
            voyant('vert', BoutonSynchro.vert, 'Vert : synchronisé avec au moins un autre appareil'),
            voyant('clignotant', BoutonSynchro.vert.withValues(alpha: 0.45), 'Vert clignotant : échange en cours'),
            if (s.actif) ...[
              const SizedBox(height: 14),
              Text('Appareils', style: Charte.texte(15, gras: true)),
              _Appareil('${s.nomAppareil} (cet appareil)', s.liaisonOk),
              for (final a in autres) _Appareil('${a.nom} (${a.enLigne ? 'en ligne' : 'hors ligne'})', a.enLigne),
              if (autres.isEmpty) Text('Aucun autre appareil vu pour l\'instant', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ],
          ]);
        },
      ),
    );

class _Appareil extends StatelessWidget {
  const _Appareil(this.texte, this.enLigne, {this.retirer});
  final String texte;
  final bool enLigne;
  final VoidCallback? retirer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: enLigne ? BoutonSynchro.vert : Charte.placeholder, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: Charte.texte(15))),
          if (retirer != null)
            OutlinedButton(onPressed: retirer, child: Text('Retirer', style: Charte.texte(14, gras: true))),
        ]),
      );
}

class EcranPartage extends StatelessWidget {
  const EcranPartage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Synchro.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([s, Etat.instance]),
      builder: (context, _) => PageBase(
        entete: const EnTeteFenetre(retour: true, icone: Icons.sync, sousTitre: 'Gérer › Paramètres', titre: 'Synchronisation'),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                PointSynchro(taille: 20, couleur: BoutonSynchro.couleur(s.pastille), clignote: s.pastille == 'vert' && s.enEchange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      s.actif ? titreEtatSynchro(s) : 'Cet appareil ne partage pas : choisissez « Passer en foyer » dans Gérer › Foyer.',
                      style: Charte.texte(16, gras: s.actif)),
                ),
              ]),
            ),
            if (s.actif && !s.liaisonOk && s.derniereErreur != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(s.derniereErreur!, style: Charte.texte(13, couleur: _rouge)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Le code de partage et les membres sont dans Gérer › Foyer.',
                  style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ),
            if (s.actif)
              GroupeRetractable(
                cle: 'partage/depannage',
                titre: 'Dépannage',
                icone: Icons.build_outlined,
                parDefaut: false,
                enfants: [..._depannage(context, s),
                  for (final e in s.journal.take(40))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('${heure(e.t)}  ${e.texte}',
                          style: Charte.texte(13, couleur: e.erreur ? _rouge : Charte.encre)),
                    ),
                ],
              ),
            GroupeRetractable(
              cle: 'partage/serveur',
              titre: 'Avancé : serveur',
              icone: Icons.dns_outlined,
              parDefaut: false,
              enfants: [_Serveur(serveur: s.serveur)],
            ),
          ],
        ),
      ),
    );
  }

  /// Appareils (retirer un ancien), compteurs, tout renvoyer, journal : replié par défaut.
  List<Widget> _depannage(BuildContext context, Synchro s) {
    final autres = s.appareils.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    return [
      const SizedBox(height: 8),
      Text('Appareils', style: Charte.texte(15, gras: true)),
      _Appareil('${s.nomAppareil} (cet appareil)', s.liaisonOk),
      for (final a in autres)
        _Appareil(
            '${a.nom} (${a.enLigne ? 'en ligne' : 'hors ligne'})'
            '${a.enLigne && (a.decalage ?? 0).abs() >= 5 ? ' · horloge décalée de ${a.decalage} s' : ''}',
            a.enLigne,
            retirer: a.enLigne ? null : () => s.oublier(a.id)),
      const SizedBox(height: 6),
      Text('${s.envoyes} modifications envoyées, ${s.recus} reçues depuis le lancement'
          '${s.enAttente > 0 ? ' · ${s.enAttente} en attente d\'intégration' : ''}',
          style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      const SizedBox(height: 10),
      Bouton(
        texte: 'Tout renvoyer',
        icone: Icons.sync,
        onTap: s.liaisonOk
            ? () {
                s.toutRenvoyer();
                Nav.message(context, 'Tout le foyer est renvoyé aux autres appareils');
              }
            : null,
      ),
      const SizedBox(height: 10),
      if (s.journal.isNotEmpty) Text('Échanges récents', style: Charte.texte(15, gras: true)),
    ];
  }

}

const _rouge = Color(0xFFB00020);

String heure(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

/// Réglages du serveur MQTT (dépannage) ; par défaut le serveur fourni avec l'application.
class _Serveur extends StatefulWidget {
  const _Serveur({required this.serveur});
  final ServeurMqtt serveur;

  @override
  State<_Serveur> createState() => _ServeurState();
}

class _ServeurState extends State<_Serveur> {
  late final hote = TextEditingController(text: widget.serveur.hote);
  late final port = TextEditingController(text: '${widget.serveur.port}');
  // Le serveur imposé garde son identifiant caché : les champs restent vides.
  late final utilisateur = TextEditingController(text: widget.serveur.parDefaut ? '' : widget.serveur.utilisateur);
  late final mdp = TextEditingController(text: widget.serveur.parDefaut ? '' : widget.serveur.motDePasse);
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

  Future<void> _parDefaut() async {
    await Synchro.instance.serveurParDefaut();
    setState(() {
      hote.text = ServeurMqtt.hoteDefaut;
      port.text = '${ServeurMqtt.portDefaut}';
      tls = true;
      utilisateur.text = '';
      mdp.text = '';
    });
    if (mounted) Nav.message(context, 'Serveur par défaut');
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Text('Le serveur est fourni avec l\'application. À ne modifier que pour un dépannage : '
            'tous les appareils du foyer doivent utiliser le même serveur. '
            'Identifiant et mot de passe vides : ceux du serveur fourni.',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 6),
        _champ('Adresse du serveur', hote, aide: ServeurMqtt.hoteDefaut, key: const ValueKey('mqtt-hote')),
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
        if (Synchro.instance.certificatRefuse case final refuse?) ...[
          Text('Le serveur présente un autre certificat (${ServeurMqtt.empreinteCourte(refuse)}) que celui reconnu '
              'au départ (${ServeurMqtt.empreinteCourte(widget.serveur.empreinte)}). Acceptez-le seulement si vous '
              'avez réinstallé votre serveur : comparez avec l\'empreinte affichée par le .bat.',
              style: Charte.texte(14, couleur: _rouge)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: BoutonAction('Accepter ce certificat', onTap: Synchro.instance.accepterCertificat),
          ),
          const SizedBox(height: 8),
        ] else if (tls && widget.serveur.empreinte.isNotEmpty) ...[
          Text('Certificat du serveur reconnu : ${ServeurMqtt.empreinteCourte(widget.serveur.empreinte)}',
              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 8),
        ],
        _champ('Identifiant', utilisateur, aide: 'vide : celui du serveur fourni'),
        _champ('Mot de passe', mdp, secret: true),
        const SizedBox(height: 6),
        Row(children: [
          Lien('Serveur par défaut', taille: 16, onTap: _parDefaut),
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
