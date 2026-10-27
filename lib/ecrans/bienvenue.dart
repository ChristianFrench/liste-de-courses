import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/synchro.dart';
import '../navigation.dart';
import '../theme.dart';

// Premier lancement (26/10/2026) : seul sur cet appareil, créer un foyer ou rejoindre un foyer.
// Revient quand le partage s'est arrêté sans que l'appareil le demande (code régénéré, membre retiré),
// et s'ouvre depuis Gérer › Foyer (« Passer en foyer »).

class EcranBienvenue extends StatefulWidget {
  const EcranBienvenue({super.key, this.depuisFoyer = false});

  /// Ouvert depuis Gérer › Foyer : flèche de retour, et retour à Foyer une fois le choix fait.
  final bool depuisFoyer;

  @override
  State<EcranBienvenue> createState() => _EcranBienvenueState();
}

class _EcranBienvenueState extends State<EcranBienvenue> {
  String? _choix; // 'creer', 'rejoindre'
  bool _occupe = false;
  String? _erreur;
  final _nomFoyer = TextEditingController(), _code = TextEditingController();
  late final _nom = TextEditingController(text: Etat.instance.moi.nomAffiche);
  late final _email = TextEditingController(text: Etat.instance.moi.email);

  @override
  void dispose() {
    for (final c in [_nomFoyer, _code, _nom, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fini(String message) {
    if (!mounted) return;
    if (widget.depuisFoyer) Navigator.of(context).pop();
    Nav.message(context, message);
  }

  Future<void> _faire(Future<String?> Function() action) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    final r = await action();
    if (!mounted) return;
    setState(() {
      _occupe = false;
      _erreur = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Synchro.instance;
    final suspendu = s.actif ? null : s.suspendu;
    return PageBase(
      entete: EnTeteFenetre(retour: widget.depuisFoyer, icone: Icons.home_outlined, titre: 'Bienvenue', sousTitre: 'Liste de courses'),
      corps: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (suspendu != null) ..._suspendu(suspendu),
        Text('Comment utilisez-vous l\'application ?', style: Charte.texte(20, gras: true)),
        const SizedBox(height: 12),
        _carte(
          'seul',
          Icons.person_outline,
          'Seul, sur cet appareil',
          'Vos listes restent sur cet appareil, sans synchronisation. Vous pourrez passer en foyer plus tard (Gérer › Foyer).',
        ),
        _carte(
          'creer',
          Icons.add_home_outlined,
          'Créer un foyer',
          'Vos données deviennent celles du foyer. Vous ajoutez ensuite les membres et leur envoyez l\'invitation avec le code de partage.',
        ),
        if (_choix == 'creer') ..._formCreer(),
        _carte(
          'rejoindre',
          Icons.login,
          'Rejoindre un foyer',
          'Avec le code de partage reçu d\'un membre du foyer.',
        ),
        if (_choix == 'rejoindre') ..._formRejoindre(),
      ]),
    );
  }

  List<Widget> _suspendu(String raison) => [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Charte.blanc,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Charte.cadre, width: Charte.traitCadre),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                raison == 'radie'
                    ? 'Un membre du foyer « ${Etat.instance.foyerNom} » a retiré cette personne du foyer.'
                    : 'Le code de partage du foyer « ${Etat.instance.foyerNom} » a changé.',
                style: Charte.texte(16, gras: true)),
            const SizedBox(height: 4),
            Text('Vos données sont gardées. Pour revenir dans le foyer, saisissez le code de partage qu\'un membre du foyer vous donne.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            _champ('Code de partage', _code, cle: 'bienvenue-code-retour', majuscules: true),
            Align(
              alignment: Alignment.centerRight,
              child: BoutonAction('Revenir dans le foyer', plein: true, onTap: () {
                final c = _code.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
                if (c.length != 10) return setState(() => _erreur = 'Le code de partage a 10 caractères');
                Synchro.instance.reprendreAvecCode(c);
              }),
            ),
            if (_erreur != null && _choix == null) Text(_erreur!, style: Charte.texte(14, couleur: _rouge)),
          ]),
        ),
      ];

  Widget _carte(String cle, IconData icone, String titre, String texte) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Carte(
          key: ValueKey('bienvenue-$cle'),
          fond: _choix == cle ? Charte.fondBandeau : null,
          onTap: _occupe
              ? null
              : () async {
                  if (cle != 'seul') return setState(() {
                        _choix = _choix == cle ? null : cle;
                        _erreur = null;
                      });
                  await Synchro.instance.choisirSeul();
                  _fini('Vous utilisez l\'application seul sur cet appareil');
                },
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: Charte.texte(17, gras: true)),
                Text(texte, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
              ]),
            ),
          ]),
        ),
      );

  Widget _champ(String titre, TextEditingController c, {String? aide, required String cle, bool majuscules = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: TextField(
          key: ValueKey(cle),
          controller: c,
          autocorrect: false,
          textCapitalization: majuscules ? TextCapitalization.characters : TextCapitalization.sentences,
          style: Charte.texte(16),
          decoration: InputDecoration(labelText: titre, hintText: aide),
        ),
      );

  List<Widget> _pied(String texte, VoidCallback action) => [
        if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erreur!, style: Charte.texte(14, couleur: _rouge))),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _occupe
              ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
              : BoutonAction(texte, plein: true, onTap: action),
        ),
        const SizedBox(height: 16),
      ];

  List<Widget> _formCreer() => [
        _champ('Nom du foyer', _nomFoyer, aide: 'Famille Dupont', cle: 'bienvenue-nom-foyer'),
        _champ('Votre nom', _nom, cle: 'bienvenue-nom'),
        _champ('Votre adresse mail', _email, aide: 'prenom.nom@exemple.fr', cle: 'bienvenue-mail'),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Le nom du foyer doit être unique : l\'application vérifie sur le serveur qu\'il est libre.',
              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        ),
        ..._pied('Créer le foyer', () => _faire(() async {
              if (_nomFoyer.text.trim().isEmpty) return 'Saisissez le nom du foyer.';
              final etat = Etat.instance;
              if (_nom.text.trim().isNotEmpty) etat.renommerMembre(etat.moi, _nom.text);
              final r = await Synchro.instance.creerFoyer(_nomFoyer.text, _email.text);
              if (r == null) _fini('Foyer créé : ajoutez les membres dans Gérer › Foyer (touchez le titre « Foyer »)');
              return r;
            })),
      ];

  List<Widget> _formRejoindre() => [
        _champ('Code de partage', _code, aide: '10 caractères', cle: 'bienvenue-code', majuscules: true),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              'Quand le foyer est reçu, vous choisissez votre nom dans la liste des membres. Les données du foyer remplacent celles de cet appareil. Vos produits ajoutés et vos listes en préparation '
              'ou prêtes sont gardés et ajoutés au foyer ; une copie de l\'ancienne base reste sur l\'appareil.',
              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        ),
        ..._pied('Rejoindre le foyer', () => _faire(() async {
              final c = _code.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
              if (c.length != 10) return 'Le code de partage a 10 caractères.';
              await Synchro.instance.rejoindre(c, '');
              _fini('Foyer rejoint : les données arrivent dès qu\'un autre appareil est en ligne');
              return null;
            })),
      ];
}

const _rouge = Color(0xFFB00020);
