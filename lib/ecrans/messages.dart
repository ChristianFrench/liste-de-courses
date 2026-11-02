import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../composants/composants.dart';
import '../donnees/messages.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';
import 'essai_mail.dart';
import 'foyer.dart' show LigneMembre;
import 'partage.dart';

// Gérer › Mon foyer › Collaboration (02/11/2026, Aristide : Messages et Synchronisation fusionnés) : les membres
// (chacun ouvre son historique de notifications et de mails), la communication (notification, mail) et la
// synchronisation. Les notifications passent par le service gratuit ntfy.sh.

class EcranCollaboration extends StatefulWidget {
  const EcranCollaboration({super.key});

  @override
  State<EcranCollaboration> createState() => _EcranCollaborationState();
}

class _EcranCollaborationState extends State<EcranCollaboration> {
  Timer? _releve;

  @override
  void initState() {
    super.initState();
    MessagesFoyer.instance.lire();
    _releve = Timer.periodic(const Duration(seconds: 15), (_) => MessagesFoyer.instance.lire());
  }

  @override
  void dispose() {
    _releve?.cancel();
    super.dispose();
  }

  Future<void> _recevoir() async {
    final m = MessagesFoyer.instance;
    // Android : l'appli ntfy s'ouvre sur le canal ; sinon (ou sans l'appli), la page du canal dans le navigateur.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await launchUrl(Uri.parse(m.lienAppli), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    await launchUrl(Uri.parse(m.lienWeb), mode: LaunchMode.externalApplication);
  }

  Future<void> _notifier() async {
    final t = await demanderTexte(context,
        titre: 'Envoyer une notification', libelle: 'Texte de la notification', aide: 'Je passe au marché, il manque quelque chose ?', valider: 'Envoyer');
    if (t == null || t.trim().isEmpty || !mounted) return;
    final r = await MessagesFoyer.instance.envoyer(t, notification: true);
    if (mounted) Nav.message(context, r ?? 'Notification envoyée');
  }

  @override
  Widget build(BuildContext context) {
    final m = MessagesFoyer.instance;
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([m, etat]),
      builder: (context, _) => PageBase(
        entete: EnTeteFenetre(
          retour: true,
          icone: Icons.groups_outlined,
          sousTitre: 'Gérer › Mon foyer',
          titre: 'Collaboration',
          aide: Aides.collaboration,
          actions: [
            ActionLigne(Icons.notifications_active_outlined, 'Recevoir les notifications sur cet appareil', _recevoir),
            ActionLigne(Icons.copy, 'Copier mon adresse de notification', () {
              Clipboard.setData(ClipboardData(text: m.monCanal));
              Nav.message(context, 'Adresse copiée : ${m.monCanal}');
            }),
            ActionLigne(Icons.refresh, 'Rafraîchir', m.lire),
          ],
        ),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            GroupeRetractable(cle: 'collaboration/membres', titre: 'Membres', icone: Icons.groups_outlined, nombre: etat.membresVisibles.length, enfants: [
              for (final x in etat.membresVisibles)
                LigneMembre(x, onTap: () => Nav.aller<void>(context, EcranHistoriqueMembre(membreId: x.id))),
            ]),
            GroupeRetractable(cle: 'collaboration/communication', titre: 'Communication', icone: Icons.chat_outlined, enfants: [
              LigneMenu(titre: 'Envoyer une notification', sousTitre: 'À tous les membres du foyer', onTap: _notifier),
              LigneMenu(titre: 'Envoyer un mail', sousTitre: 'Destinataires, sujet et texte à remplir',
                  onTap: () => Nav.aller<void>(context, const EcranEssaiMail())),
            ]),
            if (Synchro.instance.mode != 'seul')
              GroupeRetractable(cle: 'collaboration/synchro', titre: 'Synchronisation', icone: Icons.sync, enfants: [
                LigneMenu(titre: 'Synchronisation', sousTitre: 'Échanges entre les appareils du foyer',
                    onTap: () => Nav.aller<void>(context, const EcranPartage())),
              ]),
            if (m.erreur != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(m.erreur!, style: Charte.texte(14, couleur: const Color(0xFFB00020))),
              ),
          ],
        ),
      ),
    );
  }
}

/// Historique d'un membre : notifications puis mails, envoyés et reçus, du plus récent au plus ancien
/// (journal du foyer gardé sur cet appareil).
class EcranHistoriqueMembre extends StatelessWidget {
  const EcranHistoriqueMembre({super.key, required this.membreId});
  final String membreId;

  @override
  Widget build(BuildContext context) {
    final m = MessagesFoyer.instance;
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([m, etat]),
      builder: (context, _) {
        final membre = etat.membresVisibles.where((x) => x.id == membreId).firstOrNull;
        String nom(String? id) => id == null ? 'inconnu' : etat.membresVisibles.where((x) => x.id == id).firstOrNull?.nomAffiche ?? 'ancien membre';
        final siens = [for (final x in m.messages.reversed) if (x.envoyePar(membreId) || x.recuPar(membreId)) x];
        Widget ligne(MessageFoyer x) {
          final h = x.heure;
          String d(int n) => n.toString().padLeft(2, '0');
          final quand = '${d(h.day)}/${d(h.month)} ${d(h.hour)}:${d(h.minute)}';
          final envoye = x.envoyePar(membreId);
          final autres = x.a.isEmpty ? 'tout le foyer' : [for (final id in x.a) nom(id)].join(', ');
          return LigneMenu(
            titre: x.texte,
            icone: envoye ? Icons.call_made : Icons.call_received,
            sousTitre: envoye ? 'Envoyé à $autres · $quand' : 'Reçu de ${nom(x.de)} · $quand',
          );
        }

        final notifications = [for (final x in siens) if (!x.mail) ligne(x)];
        final mails = [for (final x in siens) if (x.mail) ligne(x)];
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            icone: Icons.history,
            sousTitre: 'Gérer › Collaboration',
            titre: membre?.nomAffiche ?? 'Membre',
            aide: Aides.historiqueMembre,
          ),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              GroupeRetractable(
                  cle: 'historique-membre/notifications',
                  titre: 'Notifications',
                  icone: Icons.notifications_active_outlined,
                  nombre: notifications.length,
                  vide: 'Aucune notification.',
                  enfants: notifications),
              GroupeRetractable(
                  cle: 'historique-membre/mails',
                  titre: 'Mails',
                  icone: Icons.mail_outline,
                  nombre: mails.length,
                  vide: 'Aucun mail.',
                  enfants: mails),
            ],
          ),
        );
      },
    );
  }
}
