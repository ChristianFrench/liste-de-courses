import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/envoi.dart';
import '../donnees/modele.dart';
import '../theme.dart';

// Gérer › Mon foyer › Essai d'envoi de mail (demande du 29/10/2026) : les champs du modèle EmailJS, préremplis
// comme l'application les remplit, modifiables, et la réponse d'EmailJS affichée telle quelle.

class EcranEssaiMail extends StatefulWidget {
  const EcranEssaiMail({super.key});

  @override
  State<EcranEssaiMail> createState() => _EcranEssaiMailState();
}

class _EcranEssaiMailState extends State<EcranEssaiMail> {
  late final Map<String, TextEditingController> _champs;
  String? _reponse;
  bool? _parti;
  bool _envoi = false;

  static const _libelles = {
    'destinataires': 'To Email · {{destinataires}}',
    'sujet': 'Subject · {{sujet}}',
    'texte': 'Content · {{texte}}',
    'expediteur': 'From Name · {{expediteur}}',
    'repondre_a': 'Reply To · {{repondre_a}}',
  };

  @override
  void initState() {
    super.initState();
    final etat = Etat.instance;
    final a = adressesFoyer(etat);
    final p = MailDirect.parametres(a.isEmpty ? [etat.moi.email] : a, 'Essai · Liste de courses',
        'Ceci est un mail d\'essai envoyé par ${etat.moi.nomAffiche} depuis Liste de courses.');
    _champs = {for (final k in _libelles.keys) k: TextEditingController(text: p[k] ?? '')};
  }

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_envoi) return;
    setState(() {
      _envoi = true;
      _reponse = null;
    });
    final (parti, reponse) = await MailDirect.envoyerParametres({for (final e in _champs.entries) e.key: e.value.text.trim()});
    if (!mounted) return;
    setState(() {
      _envoi = false;
      _parti = parti;
      _reponse = reponse;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.outgoing_mail, sousTitre: 'Gérer › Mon foyer', titre: 'Essai d\'envoi de mail'),
      corps: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
              MailDirect.disponible
                  ? 'Identifiants EmailJS présents dans cette version. Les champs sont remplis comme l\'application le fait ; '
                      'modifiez-les si besoin, puis « Envoyer ».'
                  : 'Identifiants EmailJS absents de cette version : l\'envoi ne peut pas partir.',
              style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 8),
          for (final e in _libelles.entries)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                key: ValueKey('essai-${e.key}'),
                controller: _champs[e.key],
                minLines: e.key == 'texte' ? 4 : 1,
                maxLines: e.key == 'texte' ? 10 : 1,
                style: Charte.texte(16),
                decoration: InputDecoration(labelText: e.value),
              ),
            ),
          if (_reponse != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('${_parti! ? 'Envoyé. ' : 'Refusé. '}$_reponse',
                  style: Charte.texte(15, gras: true, couleur: _parti! ? const Color(0xFF1B7F3B) : const Color(0xFFB00020))),
            ),
        ],
      ),
      bas: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Bouton(texte: _envoi ? 'Envoi…' : 'Envoyer', icone: Icons.send, plein: true, onTap: _envoyer),
        ),
      ],
    );
  }
}
