// Mise à jour depuis l'application (18/11/2026, Aristide), démonstration d'abord.
//
// Les applications sont déposées par la compilation sur le serveur OVH (https://<domaine>/telechargements/,
// dossier essai/ pour chaque compilation, protégé par mot de passe, racine pour les versions clôturées), avec une fiche version.json
// qui donne, pour chaque application, le commit de sa dernière compilation. L'application compare ce commit
// au sien :
// - Android : elle télécharge l'APK et la confie à l'installateur d'Android (qui demande confirmation) ;
// - Windows : elle télécharge l'installateur, le lance en mode silencieux et se ferme ; il la rouvre ;
// - web : la fiche est celle du site (même adresse) ; « Recharger » passe à la nouvelle version.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'demonstration.dart';
import 'mise_a_jour_io.dart' if (dart.library.js_interop) 'mise_a_jour_web.dart' as plateforme;
import 'modele.dart' show Etat, EtatChargement;

const _commit = String.fromEnvironment('COMMIT');
const _domaine = String.fromEnvironment('DOMAINE', defaultValue: 'emplettes.eu');

/// Compte « application:mot de passe » du dossier protégé telechargements/essai/ (secret GitHub
/// TELECHARGEMENTS_ESSAI, donné à l'APK démo seulement). Sans lui, la démo suit le dépôt officiel.
const _compteEssai = String.fromEnvironment('TELECHARGEMENTS_ESSAI');

class MiseAJour extends ChangeNotifier {
  MiseAJour._();
  static final instance = MiseAJour._();

  /// 18/11/2026 : la démonstration d'abord. Coupé dans les essais.
  static bool active = demonstration;

  /// Les versions d'essai (chaque compilation) plutôt que les versions clôturées : la démonstration les suit.
  static bool get essai => demonstration && _compteEssai.isNotEmpty;

  static Map<String, String> get _entetes =>
      essai ? {'Authorization': 'Basic ${base64Encode(utf8.encode(_compteEssai))}'} : const {};

  /// Le commit publié, quand il diffère de celui de l'application.
  String? disponible;
  String? version;

  /// Téléchargement en cours : de 0 à 1 (null : rien en cours).
  double? progression;

  /// Message à montrer (échec, autorisation à donner).
  String? message;

  /// Bandeau fermé par l'utilisateur pour ce commit.
  String? _ecarte;

  bool get aProposer => disponible != null && disponible != _ecarte;

  static String get _depot => 'https://$_domaine/telechargements/${essai ? 'essai/' : ''}';

  /// Le nom de l'application pour cette plateforme dans version.json, et son fichier.
  static (String, String)? get _application => switch (plateforme.systeme) {
        'android' => demonstration ? ('demo', 'Emplettes-demo.apk') : ('apk', 'Emplettes.apk'),
        'windows' => ('exe', 'Emplettes-Installation.exe'),
        _ => null,
      };

  /// Lit la fiche de version ; sans réseau ou sans fiche, rien n'est proposé.
  Future<void> verifier() async {
    if (!active || _commit.isEmpty || progression != null) return;
    try {
      String? publie;
      if (kIsWeb) {
        final r = await http.get(Uri.base.resolve('version.json').replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'}))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) return;
        publie = (jsonDecode(r.body) as Map)['commit'] as String?;
      } else {
        final appli = _application;
        if (appli == null) return;
        final r = await http.get(Uri.parse('${_depot}version.json'), headers: _entetes).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) return;
        final j = jsonDecode(r.body) as Map;
        publie = j[appli.$1] as String?;
        version = j['version'] as String?;
      }
      final nouveau = (publie == null || publie.isEmpty || publie == _commit) ? null : publie;
      if (nouveau != disponible) {
        disponible = nouveau;
        notifyListeners();
      }
    } catch (e) {
      // Sans réseau : on réessaiera au prochain retour dans l'application.
      debugPrint('Mise à jour : $e');
    }
  }

  void ecarter() {
    _ecarte = disponible;
    notifyListeners();
  }

  /// Télécharge et installe (Android, Windows) ou recharge (web).
  Future<void> mettreAJour() async {
    if (progression != null) return;
    message = null;
    if (kIsWeb) {
      progression = 0;
      notifyListeners();
      await plateforme.recharger();
      return;
    }
    final appli = _application;
    if (appli == null) return;
    progression = 0;
    notifyListeners();
    try {
      final resultat = await plateforme.telechargerEtInstaller(Uri.parse('$_depot${appli.$2}'), appli.$2, _entetes, (p) {
        progression = p;
        notifyListeners();
      });
      message = switch (resultat) {
        'autorisation' => 'Autorisez Emplettes à installer des applications (réglage qui vient de s\'ouvrir), '
            'puis touchez à nouveau « Mettre à jour ».',
        'ok' => null,
        _ => 'La mise à jour n\'a pas pu se faire : $resultat',
      };
      if (resultat != 'ok' && resultat != 'autorisation') Etat.instance.noter('Mise à jour : $resultat');
    } catch (e) {
      message = 'Téléchargement impossible. Vérifiez le réseau, puis réessayez.';
      Etat.instance.noter('Mise à jour : $e');
    } finally {
      progression = null;
      notifyListeners();
    }
  }
}
