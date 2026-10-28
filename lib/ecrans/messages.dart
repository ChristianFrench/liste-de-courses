import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../composants/composants.dart';
import '../donnees/messages.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Mon foyer › Messages (maquette ntfy du 27/10/2026) : écrire à tout le foyer ; on est prévenu
// par l'appli ntfy (Android) ou par ntfy.sh dans le navigateur, même quand Liste de courses est fermée.

class EcranMessages extends StatefulWidget {
  const EcranMessages({super.key});

  @override
  State<EcranMessages> createState() => _EcranMessagesState();
}

class _EcranMessagesState extends State<EcranMessages> {
  final _texte = TextEditingController();
  Timer? _releve;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    MessagesFoyer.instance.lire();
    _releve = Timer.periodic(const Duration(seconds: 15), (_) => MessagesFoyer.instance.lire());
  }

  @override
  void dispose() {
    _releve?.cancel();
    _texte.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_envoi) return;
    setState(() => _envoi = true);
    final r = await MessagesFoyer.instance.envoyer(_texte.text);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (r == null) {
      _texte.clear();
    } else {
      Nav.message(context, r);
    }
  }

  Future<void> _abonner() async {
    final m = MessagesFoyer.instance;
    // Android : l'appli ntfy s'ouvre sur le canal ; sinon (ou sans l'appli), la page du canal dans le navigateur.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await launchUrl(Uri.parse(m.lienAppli), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    await launchUrl(Uri.parse(m.lienWeb), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final m = MessagesFoyer.instance;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) => PageBase(
        entete: EnTeteFenetre(
          retour: true,
          icone: Icons.chat_outlined,
          sousTitre: 'Gérer › Mon foyer',
          titre: 'Messages',
          actions: [
            ActionLigne(Icons.notifications_active_outlined, 'Être prévenu (ntfy)', _abonner),
            ActionLigne(Icons.copy, 'Copier le nom du canal', () {
              Clipboard.setData(ClipboardData(text: m.monCanal));
              Nav.message(context, 'Canal copié : ${m.monCanal}');
            }),
            ActionLigne(Icons.refresh, 'Rafraîchir', m.lire),
          ],
        ),
        corps: ListView(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          children: [
            for (final x in m.messages.reversed) _Bulle(x),
            if (m.messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(m.enCours ? 'Lecture des messages…' : 'Aucun message depuis deux jours.',
                    style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              ),
            if (m.erreur != null) Text(m.erreur!, style: Charte.texte(14, couleur: const Color(0xFFB00020))),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'Les messages et les notifications (liste prête, départ et fin des courses, liste rectificative) '
                  'passent par le service gratuit ntfy. Pour les recevoir même quand l\'application est fermée, touchez '
                  'le titre « Messages » puis « Être prévenu (ntfy) » : sur Android, installez d\'abord l\'appli ntfy ; '
                  'dans un navigateur, autorisez les notifications sur la page ntfy. Votre canal : ${m.monCanal}',
                  style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ),
          ],
        ),
        bas: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(color: Charte.fondBandeau, border: Border(top: BorderSide(color: Charte.cadre))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('message-texte'),
                  controller: _texte,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: Charte.texte(16),
                  decoration: const InputDecoration(hintText: 'Message au foyer', isDense: true),
                  onSubmitted: (_) => _envoyer(),
                ),
              ),
              const SizedBox(width: 8),
              Bouton(texte: 'Envoyer', icone: Icons.send, plein: true, onTap: _envoi ? () {} : _envoyer),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle(this.m);
  final MessageFoyer m;

  @override
  Widget build(BuildContext context) {
    final h = m.heure;
    String d(int n) => n.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Charte.blanc,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Charte.cadre),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${m.titre.split(' · ').first} · ${d(h.day)}/${d(h.month)} ${d(h.hour)}:${d(h.minute)}',
            style: Charte.texte(13, gras: true, couleur: Charte.texteSecondaire)),
        Text(m.texte, style: Charte.texte(16)),
      ]),
    );
  }
}
