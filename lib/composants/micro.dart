import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme.dart';
import 'icone.dart';

/// Micro des zones de recherche (19/11/2026, Aristide) : le texte dicté s'écrit dans le champ, comme au clavier ;
/// on choisit soi-même dans les résultats. Android et web (reconnaissance du système ou du navigateur) ;
/// toutes les versions depuis le 19/11/2026 au soir.
class BoutonMicro extends StatefulWidget {
  const BoutonMicro({super.key, required this.controleur, this.focus, this.onTexte, this.taille = 24});
  final TextEditingController controleur;
  final FocusNode? focus;

  /// Appelé à chaque mot reconnu (les champs filtrés par « onChanged » ne voient pas un texte posé par le code).
  final void Function(String texte)? onTexte;
  final double taille;

  static final bool possible = kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  State<BoutonMicro> createState() => _BoutonMicroState();
}

class _BoutonMicroState extends State<BoutonMicro> {
  static final _voix = SpeechToText();
  static bool? _prete;
  bool _ecoute = false;

  @override
  void dispose() {
    if (_ecoute) _voix.stop();
    super.dispose();
  }

  Future<void> _dicter() async {
    if (_ecoute) {
      await _voix.stop();
      if (mounted) setState(() => _ecoute = false);
      return;
    }
    _prete ??= await _voix.initialize(onError: (_) {
      if (mounted) setState(() => _ecoute = false);
    }, onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) setState(() => _ecoute = false);
    });
    if (!mounted) return;
    if (_prete != true) {
      _prete = null;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Reconnaissance vocale indisponible sur cet appareil')));
      return;
    }
    widget.focus?.requestFocus();
    setState(() => _ecoute = true);
    await _voix.listen(
      localeId: 'fr_FR',
      listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.search, cancelOnError: true),
      onResult: (r) {
        if (!mounted) return;
        final t = r.recognizedWords;
        widget.controleur.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
        widget.onTexte?.call(t);
        if (r.finalResult) setState(() => _ecoute = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!BoutonMicro.possible) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('micro-recherche'),
      tooltip: _ecoute ? 'Arrêter l\'écoute' : 'Dicter',
      icon: Icone(_ecoute ? Icons.mic : Icons.mic_none, size: widget.taille, color: _ecoute ? Colors.red : Charte.cadre),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      onPressed: _dicter,
    );
  }
}
