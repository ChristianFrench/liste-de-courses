import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'messages.dart';
import 'modele.dart';

// Notifications du foyer sur Android par Firebase (06/11/2026, Aristide : « Firebase, qui est un standard,
// déjà présent sur les téléphones »). Le serveur ntfy d'Emplettes publie chaque message aussi sur le sujet
// Firebase du même nom : le téléphone s'abonne à son canal personnel ([MessagesFoyer.monCanal]), et le service
// Android NotificationsEmplettes l'affiche, même application fermée. Plus besoin de l'appli ntfy.
// Ailleurs (Windows, navigateur) ou sans Firebase dans la version (secret GOOGLE_SERVICES_JSON), rien ne change.

class NotificationsTelephone {
  NotificationsTelephone._();
  static final instance = NotificationsTelephone._();

  static const _canal = MethodChannel('fr.listecourses/notifications');

  /// Remplaçable dans les essais.
  static bool? androidEssai;
  static bool get android => androidEssai ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  bool? disponible;
  bool autorisees = false;
  String? sujet;
  String? erreur;

  Future<bool> _disponible() async {
    if (!android) return false;
    try {
      return disponible ??= await _canal.invokeMethod<bool>('disponible') ?? false;
    } catch (_) {
      return disponible = false;
    }
  }

  /// Abonne ce téléphone au canal de la personne (et le désabonne de l'ancien s'il a changé).
  /// Appelé à chaque connexion au serveur du partage : le code du foyer ou la personne ont pu changer.
  Future<void> mettreAJour() async {
    if (!await _disponible()) return;
    final base = Etat.instance.stockageFoyer;
    final nouveau = MessagesFoyer.instance.monCanal;
    final ancien = base?.reglage('fcm_sujet');
    try {
      autorisees = await _canal.invokeMethod<bool>('autoriser') ?? false;
      if (ancien == nouveau && sujet == nouveau) return;
      if (ancien != null && ancien != nouveau) await _canal.invokeMethod<bool>('desabonner', ancien);
      if (await _canal.invokeMethod<bool>('abonner', nouveau) ?? false) {
        sujet = nouveau;
        base?.definirReglage('fcm_sujet', nouveau);
        erreur = null;
      } else {
        erreur = 'Abonnement refusé par Firebase (réseau ?)';
      }
    } catch (e) {
      erreur = '$e';
      debugPrint('Notifications : $e');
    }
  }
}
