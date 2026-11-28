import 'package:flutter/widgets.dart';

/// Étape de l'ouverture montrée dans la fenêtre de progression (12/11/2026, Aristide : « 5 secondes c'est
/// long devant un écran vide, c'est acceptable devant une IHM qui agit »). L'écran s'affiche d'abord, puis la
/// base est lue pendant que la fenêtre avance.
final etapeOuverture = ValueNotifier<({String texte, double valeur})>((texte: 'Démarrage', valeur: 0.2));

/// Vrai quand l'écran d'ouverture est affiché (main.dart) ; ailleurs (essais, console), les étapes ne
/// font rien.
bool ouvertureAffichee = false;

/// Passe à l'étape suivante et laisse l'écran se redessiner avant le calcul qui suit.
Future<void> annoncerEtape(String texte, double valeur) async {
  if (!ouvertureAffichee) return;
  etapeOuverture.value = (texte: texte, valeur: valeur);
  final binding = WidgetsBinding.instance;
  binding.scheduleFrame();
  await Future.any([binding.endOfFrame, Future<void>.delayed(const Duration(milliseconds: 250))]);
}
