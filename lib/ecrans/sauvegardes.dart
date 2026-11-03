import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/sauvegarde.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';

/// Gérer › Paramètres › Données › Sauvegardes (03/11/2026) : les copies faites aux jalons, la sauvegarde
/// manuelle (un fichier à garder ailleurs) et la restauration.
class EcranSauvegardes extends StatefulWidget {
  const EcranSauvegardes({super.key});

  @override
  State<EcranSauvegardes> createState() => _EcranSauvegardesState();
}

class _EcranSauvegardesState extends State<EcranSauvegardes> {
  List<CopieSauvegarde>? _copies;
  String _ou = '';
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final c = await Sauvegarde.instance.liste();
    final ou = await Sauvegarde.instance.emplacement();
    if (mounted) setState(() {
      _copies = c;
      _ou = ou;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copies = _copies;
    final chiffre = Synchro.instance.code != null;
    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.save_outlined, sousTitre: 'Gérer › Paramètres › Données', titre: 'Sauvegardes'),
      corps: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 16), children: [
        GroupeRetractable(
          cle: 'sauvegardes',
          titre: 'Copies de l\'appareil',
          icone: Icons.save_outlined,
          nombre: copies?.length ?? 0,
          vide: copies == null ? 'Lecture…' : 'Aucune copie pour l\'instant : la première se fait à la prochaine liste prête.',
          enfants: [
            for (final c in copies ?? const <CopieSauvegarde>[])
              LigneMenu(
                key: ValueKey('copie-${c.nom}'),
                icone: c.ancre ? Icons.anchor : Icons.save_outlined,
                titre: '${quand(c.le)}${c.ancre ? ' · copie ancienne' : ''}',
                sousTitre: '${c.jalon} · ${c.resume}',
                onTap: _occupe ? null : () => _restaurer(c),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
              'Une copie est faite à chaque étape importante (liste prête, courses terminées, catalogue, foyer), '
              'seulement si quelque chose a changé. Les trois dernières sont gardées, et une plus ancienne d\'au moins un mois. '
              'Elles sont rangées dans $_ou.\n'
              '${chiffre ? 'Elles sont chiffrées avec le code du foyer : notez-le hors du téléphone (Gérer › Foyer), il faut le saisir '
                  'pour restaurer sur un autre appareil.' : 'Sans foyer, les copies ne sont pas chiffrées : gardez le fichier dans un endroit privé.'}\n'
              'Pour vous protéger d\'un téléphone perdu, « Sauvegarder maintenant » donne un fichier à mettre sur Drive, '
              'dans un mail ou sur un ordinateur.',
              style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ),
      ]),
      bas: [
        BarreAction(boutons: [
          Bouton(texte: 'Depuis un fichier', icone: Icons.folder_open_outlined, onTap: _occupe ? null : _depuisFichier),
          Bouton(texte: 'Sauvegarder maintenant', icone: Icons.save_outlined, plein: true, onTap: _occupe ? null : _maintenant),
        ]),
      ],
    );
  }

  Future<void> _maintenant() async {
    setState(() => _occupe = true);
    try {
      final ok = await Sauvegarde.instance.exporter();
      if (mounted && ok) Nav.message(context, 'Fichier de sauvegarde enregistré');
    } catch (e) {
      if (mounted) Nav.message(context, 'Sauvegarde impossible : $e');
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _depuisFichier() async {
    final c = await Sauvegarde.instance.importer();
    if (!mounted) return;
    if (c == null) return;
    await _restaurer(c);
  }

  Future<void> _restaurer(CopieSauvegarde c) async {
    final etat = Etat.instance;
    var donnees = await Sauvegarde.instance.ouvrir(c);
    if (!mounted) return;
    if (donnees == null && c.chiffree) {
      final code = await demanderTexte(context,
          titre: 'Code du foyer « ${c.foyer} »', libelle: 'Code de partage', aide: '10 caractères', valider: 'Ouvrir');
      if (code == null || !mounted) return;
      donnees = await Sauvegarde.instance.ouvrir(c, code: code.replaceAll(RegExp(r'\s'), '').toUpperCase());
      if (!mounted) return;
    }
    if (donnees == null) {
      Nav.message(context, 'Cette sauvegarde ne s\'ouvre pas (code différent ou fichier abîmé)');
      return;
    }
    final foyer = Synchro.instance.code != null;
    final ok = await modale(
      context,
      titre: 'Restaurer cette sauvegarde ?',
      icone: Icons.restore,
      oui: 'Restaurer',
      contenu: (context, maj) => Text(
          'Copie du ${jjmm(c.le)} à ${heure(c.le)} (${c.jalon}) : ${c.resume}.\n'
          'Les données de l\'appareil (${etat.listes.length} listes, ${etat.produits.length} articles) seront remplacées ; '
          'elles sont d\'abord copiées, on peut donc revenir en arrière.'
          '${foyer ? '\nDans un foyer, la sauvegarde restaurée part aussi vers les autres membres.' : ''}',
          style: Charte.texte(16)),
    );
    if (!ok || !mounted) return;
    setState(() => _occupe = true);
    await Sauvegarde.instance.restaurer(donnees);
    if (!mounted) return;
    setState(() => _occupe = false);
    Nav.message(context, 'Sauvegarde restaurée');
    await _relire();
  }
}
