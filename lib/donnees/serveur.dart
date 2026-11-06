import 'package:flutter/foundation.dart';

import 'modele.dart';
import 'serveur_acces.dart';

export 'serveur_acces.dart' show SessionShell;

// Serveur OVH d'Emplettes, vu de la console d'administration (Windows, 06/11/2026, Aristide).
// Tout passe par SSH, avec une clé créée sur le PC par la console : rien n'est installé de plus sur le serveur.
// Les mots de passe ne sont jamais gardés : celui du compte debian ne sert qu'une fois, à poser la clé.

/// Réglages de connexion, gardés sur ce PC (réglages de l'appareil).
class Serveur extends ChangeNotifier {
  Serveur._();
  static final instance = Serveur._();

  final acces = AccesServeur();

  String? _reglage(String c) => Etat.instance.stockageFoyer?.reglage(c);
  void _definir(String c, String v) {
    Etat.instance.stockageFoyer?.definirReglage(c, v);
    notifyListeners();
  }

  String get domaine => _reglage('serveur_domaine') ?? 'emplettes.eu';
  set domaine(String v) => _definir('serveur_domaine', v.trim());

  /// Adresse de connexion : le domaine (qui pointe vers le serveur), ou l'IP mise dans les réglages.
  String get hote => _reglage('serveur_hote') ?? domaine;
  set hote(String v) => _definir('serveur_hote', v.trim());

  String get utilisateur => _reglage('serveur_utilisateur') ?? 'debian';
  set utilisateur(String v) => _definir('serveur_utilisateur', v.trim());

  /// Empreinte de la clé du serveur, retenue à la première connexion (une autre ensuite = refus).
  String? get empreinte => _reglage('serveur_empreinte');

  /// Tâches d'initialisation cochées à la main (secrets GitHub…).
  bool fait(String tache) => _reglage('serveur_fait_$tache') == '1';
  void marquer(String tache, bool v) => _definir('serveur_fait_$tache', v ? '1' : '0');

  bool connecte = false;
  String? erreur;

  /// Connexion par la clé de la console ; [motDePasse] seulement pour la poser la première fois.
  Future<bool> connecter({String? motDePasse}) async {
    erreur = null;
    try {
      await acces.connecter(
        hote: hote,
        utilisateur: utilisateur,
        motDePasse: motDePasse,
        empreinte: empreinte,
        nouvelleEmpreinte: (e) => _definir('serveur_empreinte', e),
      );
      connecte = true;
    } catch (e) {
      connecte = false;
      erreur = _message(e);
    }
    notifyListeners();
    return connecte;
  }

  void deconnecter() {
    acces.fermer();
    connecte = false;
    notifyListeners();
  }

  /// Exécute une commande (connexion au besoin) ; rend sa sortie.
  Future<String> executer(String commande) async {
    if (!connecte && !await connecter()) throw Exception(erreur);
    try {
      return await acces.executer(commande);
    } catch (e) {
      connecte = false;
      erreur = _message(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<SessionShell> shell(int colonnes, int lignes) async {
    if (!connecte && !await connecter()) throw Exception(erreur);
    return acces.shell(colonnes, lignes);
  }

  Future<String?> clePublique() => acces.clePublique();

  /// Crée la clé de la console sur ce PC (une fois).
  Future<bool> creerCle() async {
    erreur = null;
    try {
      await acces.creerCle('console-emplettes@${domaine.isEmpty ? 'admin' : domaine}');
    } catch (e) {
      erreur = _message(e);
    }
    notifyListeners();
    return erreur == null;
  }

  /// Pose la clé de la console sur le serveur, avec le mot de passe du compte (une seule fois, jamais gardé).
  Future<bool> poserCle(String motDePasse) async {
    final cle = await clePublique();
    if (cle == null) {
      erreur = 'Créez d\'abord la clé de la console';
      notifyListeners();
      return false;
    }
    if (!await connecter(motDePasse: motDePasse)) return false;
    try {
      final c = cle.trim().replaceAll("'", '');
      await acces.executer("mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && "
          "chmod 600 ~/.ssh/authorized_keys && (grep -qxF '$c' ~/.ssh/authorized_keys || echo '$c' >> ~/.ssh/authorized_keys)");
    } catch (e) {
      erreur = _message(e);
      notifyListeners();
      return false;
    }
    deconnecter();
    // Vérification : la clé seule suffit maintenant.
    return connecter();
  }

  static String _message(Object e) {
    final t = '$e'.replaceFirst('Exception: ', '');
    if (t.contains('SSHAuthFail') || t.contains('SSHAuthAbort')) return 'Connexion refusée ($t) : clé non posée ou mot de passe faux';
    if (t.contains('SocketException') || t.contains('Connection refused') || t.contains('timed out')) {
      return 'Serveur injoignable ($hoteActuel)';
    }
    return t;
  }

  static String get hoteActuel => instance.hote;

  // ------------------------------------------------------------ Suivi technique

  /// Les services installés par le script d'installation (outils/vps/installer.sh).
  static const services = ['nginx', 'mosquitto', 'ntfy', 'relais-mail', 'fail2ban', 'emplettes-sauvegarde.timer'];

  /// Une seule commande, lignes « clé=valeur » : état du système, des services, des certificats, des clients.
  String get commandeSuivi {
    final d = domaine;
    return [
      'echo "uptime=\$(uptime -p)"',
      'echo "charge=\$(cut -d" " -f1-3 /proc/loadavg)"',
      'echo "coeurs=\$(nproc)"',
      "free -m | awk '/Mem:/{print \"memoire=\"\$3\"/\"\$2}'",
      "df -m / | awk 'NR==2{print \"disque=\"\$3\"/\"\$2}'",
      'for s in ${services.join(' ')}; do echo "service.\$s=\$(systemctl is-active \$s 2>/dev/null)"; done',
      'echo "majs=\$(apt list --upgradable 2>/dev/null | grep -c upgradable)"',
      'echo "redemarrage=\$([ -f /var/run/reboot-required ] && echo oui || echo non)"',
      'echo "installe=\$([ -d /etc/emplettes ] && echo oui || echo non)"',
      'for n in $d mqtt.$d ntfy.$d; do echo "certificat.\$n=\$(echo | timeout 6 openssl s_client -servername \$n -connect \$n:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)"; done',
      'echo "clients_mqtt=\$(ss -Htn state established \'( sport = :8883 )\' 2>/dev/null | wc -l)"',
      'echo "clients_web=\$(ss -Htn state established \'( sport = :9001 )\' 2>/dev/null | wc -l)"',
      'echo "sauvegarde=\$(sudo -n ls -t /var/backups/emplettes 2>/dev/null | head -1)"',
      'echo "bannis=\$(sudo -n fail2ban-client status sshd 2>/dev/null | awk -F: \'/Currently banned/{gsub(/ /,"",\$2);print \$2}\')"',
    ].join('; ');
  }

  /// Lit la sortie de [commandeSuivi].
  static Map<String, String> lireSuivi(String sortie) => {
        for (final l in sortie.split('\n'))
          if (l.contains('=')) l.substring(0, l.indexOf('=')).trim(): l.substring(l.indexOf('=') + 1).trim(),
      };

  Map<String, String>? dernierSuivi;
  DateTime? suiviLe;

  Future<Map<String, String>?> suivre() async {
    try {
      dernierSuivi = lireSuivi(await executer(commandeSuivi));
      suiviLe = DateTime.now();
    } catch (_) {
      // erreur déjà notée
    }
    notifyListeners();
    return dernierSuivi;
  }

  /// Les quatre noms du domaine que le script d'installation demande.
  List<String> get nomsDomaine => [domaine, 'www.$domaine', 'mqtt.$domaine', 'ntfy.$domaine'];

  /// Adresse de chaque nom du domaine (null : introuvable).
  Future<Map<String, String?>> adressesDomaine() async => {for (final n in nomsDomaine) n: await acces.adresse(n)};

  @visibleForTesting
  static bool get disponible => AccesServeur.disponible;
}
