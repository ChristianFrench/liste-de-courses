// Essai à la main contre un serveur SSH local (127.0.0.1, compte essai) : pas lancé par la CI (nom sans _test).
//   flutter test test/serveur_ssh_reel.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/donnees/serveur.dart';
import 'package:liste_de_courses/donnees/serveur_acces_io.dart' as io;

void main() {
  test('clé, pose de la clé par mot de passe, commande, suivi, shell', () async {
    final d = Directory.systemTemp.createTempSync('cle');
    io.AccesServeur.dossierEssai = d.path;
    final a = io.AccesServeur();
    await a.creerCle('essai');
    final pub = await a.clePublique();
    expect(pub, startsWith('ssh-ed25519'));
    String? empreinte;
    await a.connecter(hote: '127.0.0.1', utilisateur: 'essai', motDePasse: 'Motdepasse1', nouvelleEmpreinte: (e) => empreinte = e);
    expect(empreinte, isNotNull);
    await a.executer("mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pub' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys");
    a.fermer();
    await a.connecter(hote: '127.0.0.1', utilisateur: 'essai', empreinte: empreinte, nouvelleEmpreinte: (_) {});
    expect((await a.executer('whoami')).trim(), 'essai');
    final suivi = Serveur.lireSuivi(await a.executer(Serveur.instance.commandeSuivi));
    print(suivi);
    expect(suivi['coeurs'], isNotEmpty);
    expect(suivi.keys, contains('service.nginx'));
    final s = await a.shell(80, 24);
    final sortie = StringBuffer();
    s.sortie.listen((x) => sortie.write(utf8.decode(x, allowMalformed: true)));
    s.ecrire(utf8.encode('echo bonjour-\$((40+2))\nexit\n'));
    await s.fin.timeout(const Duration(seconds: 10));
    expect(sortie.toString(), contains('bonjour-42'));
    a.fermer();
    // Mauvaise empreinte : refus
    await expectLater(
        a.connecter(hote: '127.0.0.1', utilisateur: 'essai', empreinte: 'ssh-ed25519 faux', nouvelleEmpreinte: (_) {}), throwsA(anything));
  });
}
