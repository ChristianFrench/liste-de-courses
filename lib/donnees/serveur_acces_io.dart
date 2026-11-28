import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'dossier_application.dart';

/// Session de console shell sur le serveur.
abstract class SessionShell {
  Stream<Uint8List> get sortie;
  void ecrire(Uint8List donnees);
  void redimensionner(int colonnes, int lignes);
  Future<void> get fin;
  void fermer();
}

class _Session implements SessionShell {
  _Session(this.s);
  final SSHSession s;
  @override
  Stream<Uint8List> get sortie => StreamGroupe.fusion([s.stdout, s.stderr]);
  @override
  void ecrire(Uint8List donnees) => s.write(donnees);
  @override
  void redimensionner(int colonnes, int lignes) => s.resizeTerminal(colonnes, lignes);
  @override
  Future<void> get fin => s.done;
  @override
  void fermer() => s.close();
}

/// Fusion de deux flux (sortie et erreurs du shell).
class StreamGroupe {
  static Stream<T> fusion<T>(List<Stream<T>> flux) {
    final c = StreamController<T>();
    var restants = flux.length;
    for (final f in flux) {
      f.listen(c.add, onError: c.addError, onDone: () {
        if (--restants == 0) c.close();
      });
    }
    return c.stream;
  }
}

/// Accès SSH (Windows) : clé ed25519 de la console dans le dossier de données, créée par ssh-keygen de Windows.
class AccesServeur {
  static const disponible = true;

  /// Essais : dossier de la clé et port du serveur (sinon dossier de l'application et 22).
  static String? dossierEssai;
  static int port = 22;
  SSHClient? _client;

  Future<File> _fichierCle() async =>
      File('${dossierEssai ?? (await dossierApplication()).path}${Platform.pathSeparator}cle_serveur');

  Future<void> connecter({
    required String hote,
    required String utilisateur,
    String? motDePasse,
    String? empreinte,
    required void Function(String) nouvelleEmpreinte,
  }) async {
    fermer();
    final cle = await _fichierCle();
    final identites = cle.existsSync() ? SSHKeyPair.fromPem(cle.readAsStringSync()) : <SSHKeyPair>[];
    if (identites.isEmpty && motDePasse == null) throw Exception('Pas de clé de la console : faites l\'étape « Clé de la console »');
    final socket = await SSHSocket.connect(hote, port, timeout: const Duration(seconds: 10));
    final client = SSHClient(
      socket,
      username: utilisateur,
      identities: motDePasse == null ? identites : null,
      onPasswordRequest: motDePasse == null ? null : () => motDePasse,
      // Certains serveurs (Debian chez OVH) demandent le mot de passe en « clavier interactif ».
      onUserInfoRequest: motDePasse == null
          ? null
          : (demande) {
              final textes = [for (final q in demande.prompts) q.promptText.toLowerCase()];
              if (textes.any((t) => t.contains('new') || t.contains('nouveau'))) {
                throw Exception('Le serveur demande de changer le mot de passe de ${utilisateur} : faites-le une fois '
                    'dans PowerShell (ssh $utilisateur@$hote), puis reposez la clé avec le nouveau');
              }
              return [for (final _ in demande.prompts) motDePasse];
            },
      onVerifyHostKey: (type, empreinteRecue) {
        final e = '$type ${base64.encode(empreinteRecue)}';
        if (empreinte == null || empreinte.isEmpty) {
          nouvelleEmpreinte(e);
          return true;
        }
        return e == empreinte;
      },
    );
    try {
      await client.authenticated.timeout(const Duration(seconds: 15));
    } catch (e) {
      client.close();
      rethrow;
    }
    _client = client;
  }

  Future<String> executer(String commande) async {
    final c = _client;
    if (c == null) throw Exception('Pas connecté');
    return utf8.decode(await c.run(commande), allowMalformed: true);
  }

  Future<SessionShell> shell(int colonnes, int lignes) async {
    final c = _client;
    if (c == null) throw Exception('Pas connecté');
    return _Session(await c.shell(pty: SSHPtyConfig(width: colonnes, height: lignes, type: 'xterm-256color')));
  }

  Future<String?> clePublique() async {
    final f = File('${(await _fichierCle()).path}.pub');
    return f.existsSync() ? f.readAsStringSync().trim() : null;
  }

  Future<void> creerCle(String commentaire) async {
    final f = await _fichierCle();
    if (f.existsSync()) return;
    // ssh-keygen est livré avec Windows 10 et 11 (client OpenSSH).
    final programme = Platform.isWindows && File(r'C:\Windows\System32\OpenSSH\ssh-keygen.exe').existsSync()
        ? r'C:\Windows\System32\OpenSSH\ssh-keygen.exe'
        : 'ssh-keygen';
    final r = await Process.run(programme, ['-q', '-t', 'ed25519', '-N', '', '-C', commentaire, '-f', f.path]);
    if (r.exitCode != 0 || !f.existsSync()) throw Exception('ssh-keygen : ${r.stderr}'.trim());
  }

  Future<String?> adresse(String nom) async {
    try {
      final l = await InternetAddress.lookup(nom, type: InternetAddressType.IPv4).timeout(const Duration(seconds: 6));
      return l.isEmpty ? null : l.first.address;
    } catch (_) {
      return null;
    }
  }

  void fermer() {
    _client?.close();
    _client = null;
  }
}
