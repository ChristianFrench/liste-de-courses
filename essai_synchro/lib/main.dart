// Essai de synchronisation : petite application indépendante de « Liste de courses ».
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'moteur.dart';
import 'transport_mqtt.dart';

const version = String.fromEnvironment('VERSION', defaultValue: 'essai');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppliEssai());
}

/// Réglages gardés dans un petit fichier JSON à côté de la base.
class Reglages {
  Reglages(this.fichier, this.v);
  final File fichier;
  final Map<String, dynamic> v;

  static Future<Reglages> charger() async {
    final dossier = await getApplicationSupportDirectory();
    await dossier.create(recursive: true);
    final f = File('${dossier.path}${Platform.pathSeparator}essai_synchro.json');
    Map<String, dynamic> v = {};
    if (await f.exists()) {
      try {
        v = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    v['foyer'] ??= List.generate(6, (_) => lettres[r.nextInt(lettres.length)]).join();
    v['nom'] ??= Platform.isWindows ? 'PC' : 'Téléphone';
    v['hote'] ??= 'broker.hivemq.com';
    v['port'] ??= 8883;
    v['tls'] ??= true;
    v['utilisateur'] ??= '';
    v['motDePasse'] ??= '';
    v['dernierEnvoi'] ??= '';
    final reg = Reglages(f, v);
    await reg.sauver();
    return reg;
  }

  String get dossierBase => fichier.parent.path;
  Future<void> sauver() => fichier.writeAsString(jsonEncode(v));
}

String get plateforme => Platform.isWindows ? 'Windows' : Platform.isAndroid ? 'Android' : Platform.operatingSystem;

class AppliEssai extends StatefulWidget {
  const AppliEssai({super.key});
  @override
  State<AppliEssai> createState() => _AppliEssaiState();
}

class _AppliEssaiState extends State<AppliEssai> {
  Reglages? _reglages;
  Moteur? _moteur;
  Object? _erreur;
  final _messager = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    try {
      final r = _reglages ?? await Reglages.charger();
      final crdt = await ouvrirBase('${r.dossierBase}${Platform.pathSeparator}essai_synchro.db');
      // Identifiant d'appareil stable d'un lancement à l'autre (sert aussi d'identifiant MQTT).
      if (r.v['id'] == null) {
        r.v['id'] = crdt.nodeId;
        await r.sauver();
      } else if (crdt.nodeId != r.v['id']) {
        await crdt.resetNodeId(r.v['id'] as String);
      }
      final m = Moteur(
        crdt: crdt,
        transport: TransportMqtt(
          hote: r.v['hote'] as String,
          port: r.v['port'] as int,
          tls: r.v['tls'] as bool,
          utilisateur: r.v['utilisateur'] as String,
          motDePasse: r.v['motDePasse'] as String,
        ),
        foyer: r.v['foyer'] as String,
        nom: r.v['nom'] as String,
        plateforme: plateforme,
        dernierEnvoi: r.v['dernierEnvoi'] as String,
        surDernierEnvoi: (d) {
          r.v['dernierEnvoi'] = d;
          r.sauver();
        },
      );
      m.notifications.listen((t) => _messager.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 6))));
      setState(() {
        _reglages = r;
        _moteur = m;
      });
      await m.demarrer();
    } catch (e) {
      setState(() => _erreur = e);
    }
  }

  /// Après un changement de réglages : on ferme tout et on repart.
  Future<void> _redemarrer({bool effacer = false}) async {
    final m = _moteur;
    setState(() => _moteur = null);
    if (m != null) {
      await m.arreter();
      await m.crdt.close();
      m.dispose();
    }
    if (effacer) {
      final f = File('${_reglages!.dossierBase}${Platform.pathSeparator}essai_synchro.db');
      if (await f.exists()) await f.delete();
      _reglages!.v['dernierEnvoi'] = '';
      await _reglages!.sauver();
    }
    await _demarrer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Essai synchro',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messager,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
      home: _erreur != null
          ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Démarrage impossible : $_erreur'))))
          : _moteur == null
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : Accueil(moteur: _moteur!, reglages: _reglages!, redemarrer: _redemarrer),
    );
  }
}

class Accueil extends StatefulWidget {
  const Accueil({super.key, required this.moteur, required this.reglages, required this.redemarrer});
  final Moteur moteur;
  final Reglages reglages;
  final Future<void> Function({bool effacer}) redemarrer;
  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.moteur;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final enLigne = m.pairs.values.where((p) => p.enLigne).toList();
        final (couleur, etat) = switch (m.etatReseau) {
          'connecte' => (Colors.green, 'Connecté'),
          'connexion' => (Colors.orange, 'Connexion…'),
          _ => (Colors.red, 'Hors ligne'),
        };
        return Scaffold(
          appBar: AppBar(
            title: Text('${m.nom} · foyer ${m.foyer}'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(Icons.circle, color: couleur, size: 14),
                  label: Text(enLigne.isEmpty ? etat : '$etat · ${enLigne.map((p) => p.nom).join(', ')}'),
                ),
              ),
            ],
          ),
          body: switch (_onglet) {
            0 => OngletListe(moteur: m),
            1 => OngletJournal(moteur: m),
            2 => OngletEssais(moteur: m),
            _ => OngletReglages(reglages: widget.reglages, moteur: m, redemarrer: widget.redemarrer),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: _onglet,
            onDestinationSelected: (i) => setState(() => _onglet = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'Liste'),
              NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Journal'),
              NavigationDestination(icon: Icon(Icons.speed), label: 'Essais'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Réglages'),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Liste

class OngletListe extends StatefulWidget {
  const OngletListe({super.key, required this.moteur});
  final Moteur moteur;
  @override
  State<OngletListe> createState() => _OngletListeState();
}

class _OngletListeState extends State<OngletListe> {
  String? _liste;
  final _saisie = TextEditingController();

  Future<String?> _demander(String titre, [String initial = '']) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moteur;
    return StreamBuilder<List<Map<String, Object?>>>(
      stream: m.listes(),
      builder: (context, snap) {
        final listes = snap.data ?? [];
        if (_liste != null && !listes.any((l) => l['id'] == _liste)) _liste = null;
        _liste ??= listes.isEmpty ? null : listes.first['id'] as String;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _liste,
                    hint: const Text('Aucune liste'),
                    items: [
                      for (final l in listes)
                        DropdownMenuItem(value: l['id'] as String, child: Text('${l['nom']}  ·  créée par ${l['par']}')),
                    ],
                    onChanged: (v) => setState(() => _liste = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Nouvelle liste',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () async {
                    final n = await _demander('Nom de la nouvelle liste');
                    if (n != null && n.trim().isNotEmpty) {
                      final id = await m.ajouterListe(n.trim());
                      setState(() => _liste = id);
                    }
                  },
                ),
                if (_liste != null)
                  IconButton(
                    tooltip: 'Supprimer la liste',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => m.supprimerListe(_liste!),
                  ),
              ]),
            ),
            if (_liste != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _saisie,
                  decoration: const InputDecoration(hintText: 'Ajouter un article (ex. « 2 lait »)', prefixIcon: Icon(Icons.add)),
                  onSubmitted: (v) {
                    final a = Moteur.lireArticles(v);
                    if (a.isNotEmpty) m.ajouterLigne(_liste!, a.first.$1, a.first.$2);
                    _saisie.clear();
                  },
                ),
              ),
            Expanded(
              child: _liste == null
                  ? const Center(child: Text('Créez une liste, ou chargez un fichier dans « Essais ».'))
                  : StreamBuilder<List<Map<String, Object?>>>(
                      key: ValueKey(_liste),
                      stream: m.lignesDe(_liste!),
                      builder: (context, snap) {
                        final lignes = snap.data ?? [];
                        return ListView.builder(
                          itemCount: lignes.length,
                          itemBuilder: (context, i) {
                            final l = lignes[i];
                            final id = l['id'] as String, coche = l['coche'] == 1, q = l['quantite'] as int? ?? 1;
                            return ListTile(
                              dense: true,
                              leading: Checkbox(value: coche, onChanged: (v) => m.cocher(id, v ?? false)),
                              title: Text('${l['article']}',
                                  style: coche ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
                              subtitle: Text('modifié par ${l['par']}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.remove), onPressed: () => m.changerQuantite(id, q - 1)),
                                Text('$q', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add), onPressed: () => m.changerQuantite(id, q + 1)),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => m.supprimerLigne(id)),
                              ]),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Journal

class OngletJournal extends StatelessWidget {
  const OngletJournal({super.key, required this.moteur});
  final Moteur moteur;

  static const _icones = {
    'envoi': (Icons.north_east, Colors.blue),
    'reception': (Icons.south_west, Colors.green),
    'erreur': (Icons.error_outline, Colors.red),
    'message': (Icons.chat_bubble_outline, Colors.purple),
    'mesure': (Icons.timer_outlined, Colors.orange),
    'info': (Icons.info_outline, Colors.grey),
  };

  String _h(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';

  @override
  Widget build(BuildContext context) {
    final m = moteur;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: Text('Envoyé : ${m.lotsEnvoyes} lots, ${m.changementsEnvoyes} changements\n'
                'Reçu : ${m.lotsRecus} lots, ${m.changementsRecus} changements'),
          ),
          TextButton.icon(
            onPressed: () {
              m.journal.clear();
              m.noter('info', 'Journal effacé');
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Effacer'),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView.builder(
          itemCount: m.journal.length,
          itemBuilder: (context, i) {
            final e = m.journal[i];
            final (icone, couleur) = _icones[e.type] ?? (Icons.circle, Colors.grey);
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(icone, color: couleur, size: 20),
              title: SelectableText(e.texte),
              subtitle: Text(_h(e.t)),
            );
          },
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Essais

class OngletEssais extends StatefulWidget {
  const OngletEssais({super.key, required this.moteur});
  final Moteur moteur;
  @override
  State<OngletEssais> createState() => _OngletEssaisState();
}

class _OngletEssaisState extends State<OngletEssais> {
  int _volume = 1000;
  int _dureeMin = 5;
  int _intervalle = 2;
  int _rythmeMs = 1000;
  String? _listeSimulee;
  bool _volumeEnCours = false, _pingEnCours = false;
  final _message = TextEditingController();

  Moteur get m => widget.moteur;

  void _voirJournal() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Résultats dans l\'onglet Journal'), duration: Duration(seconds: 2)));

  Future<void> _chargerFichiers() async {
    final fichiers = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(label: 'Texte', extensions: ['txt', 'csv', 'md'], mimeTypes: ['text/*']),
    ]);
    for (final f in fichiers) {
      final articles = Moteur.lireArticles(await f.readAsString());
      final nom = f.name.replaceFirst(RegExp(r'\.[^.]*$'), '');
      await m.ajouterListe(nom, articles: articles);
      m.noter('mesure', 'Fichier « ${f.name} » : liste créée avec ${articles.length} articles');
    }
  }

  Widget _section(String titre, String explication, List<Widget> contenu) => Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(explication, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: contenu),
          ]),
        ),
      );

  DropdownButton<int> _choix(int valeur, List<int> valeurs, String Function(int) libelle, void Function(int) changer) =>
      DropdownButton<int>(
        value: valeur,
        items: [for (final v in valeurs) DropdownMenuItem(value: v, child: Text(libelle(v)))],
        onChanged: (v) => setState(() => changer(v!)),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      _section(
        'Appareils du foyer',
        'Les appareils connectés avec le même code de foyer.',
        [
          if (m.pairs.isEmpty) const Text('Aucun autre appareil vu pour l\'instant.'),
          for (final p in m.pairs.values)
            Chip(
              avatar: Icon(Icons.circle, size: 12, color: p.enLigne ? Colors.green : Colors.grey),
              label: Text('${p.nom} (${p.plateforme}) · ${p.changementsRecus} reçus'),
            ),
        ],
      ),
      _section(
        'Message',
        'Envoie une notification aux autres appareils (bandeau en bas de leur écran).',
        [
          SizedBox(width: 260, child: TextField(controller: _message, decoration: const InputDecoration(hintText: 'Votre message'))),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Envoyer'),
            onPressed: () {
              if (_message.text.trim().isEmpty) return;
              m.message(_message.text.trim());
              _message.clear();
            },
          ),
        ],
      ),
      _section(
        'Temps de réponse (ping)',
        '10 petits messages ; mesure de l\'aller-retour avec chaque appareil.',
        [
          FilledButton.tonal(
            onPressed: _pingEnCours
                ? null
                : () async {
                    setState(() => _pingEnCours = true);
                    _voirJournal();
                    await m.ping();
                    if (mounted) setState(() => _pingEnCours = false);
                  },
            child: Text(_pingEnCours ? 'En cours…' : 'Mesurer'),
          ),
        ],
      ),
      _section(
        'Essai en volume',
        'Crée d\'un coup une liste de N articles et mesure le temps jusqu\'à ce que chaque appareil confirme les avoir enregistrés.',
        [
          _choix(_volume, const [100, 1000, 5000, 20000], (v) => '$v articles', (v) => _volume = v),
          FilledButton.tonal(
            onPressed: _volumeEnCours
                ? null
                : () async {
                    setState(() => _volumeEnCours = true);
                    _voirJournal();
                    await m.essaiVolume(_volume);
                    if (mounted) setState(() => _volumeEnCours = false);
                  },
            child: Text(_volumeEnCours ? 'En cours…' : 'Lancer'),
          ),
        ],
      ),
      _section(
        'Essai dans la durée',
        'Modifie un article à intervalle régulier ; compte les envois confirmés, perdus, et le temps aller-retour. '
            'Coupez le wifi en cours d\'essai pour voir le rattrapage.',
        [
          _choix(_dureeMin, const [1, 5, 15, 60], (v) => '$v min', (v) => _dureeMin = v),
          _choix(_intervalle, const [1, 2, 5, 10], (v) => 'toutes les $v s', (v) => _intervalle = v),
          m.enduranceEnCours
              ? OutlinedButton(onPressed: m.arreterEndurance, child: const Text('Arrêter'))
              : FilledButton.tonal(
                  onPressed: () {
                    _voirJournal();
                    m.essaiEndurance(Duration(minutes: _dureeMin), Duration(seconds: _intervalle));
                  },
                  child: const Text('Lancer'),
                ),
        ],
      ),
      _section(
        'Simulation à partir de fichiers',
        'Chargez un ou plusieurs fichiers texte (un article par ligne, quantité facultative : « 2 lait » ou « lait 2 ») : '
            'chacun devient une liste partagée. Puis simulez des courses : les articles sont cochés un par un.',
        [
          OutlinedButton.icon(icon: const Icon(Icons.file_open), label: const Text('Charger des fichiers'), onPressed: _chargerFichiers),
          StreamBuilder<List<Map<String, Object?>>>(
            stream: m.listes(),
            builder: (context, snap) {
              final listes = snap.data ?? [];
              if (!listes.any((l) => l['id'] == _listeSimulee)) _listeSimulee = null;
              return DropdownButton<String>(
                value: _listeSimulee,
                hint: const Text('Liste à simuler'),
                items: [for (final l in listes) DropdownMenuItem(value: l['id'] as String, child: Text('${l['nom']}'))],
                onChanged: (v) => setState(() => _listeSimulee = v),
              );
            },
          ),
          _choix(_rythmeMs, const [200, 1000, 3000], (v) => 'un article / ${v < 1000 ? '$v ms' : '${v ~/ 1000} s'}', (v) => _rythmeMs = v),
          m.simulationEnCours
              ? OutlinedButton(onPressed: m.arreterSimulation, child: const Text('Arrêter'))
              : FilledButton.tonal(
                  onPressed: _listeSimulee == null ? null : () => m.simulerCourses(_listeSimulee!, Duration(milliseconds: _rythmeMs)),
                  child: const Text('Simuler les courses'),
                ),
        ],
      ),
      _section(
        'Vérifier que les bases sont identiques',
        'Calcule une empreinte du contenu et la compare à celle des autres appareils.',
        [
          FilledButton.tonal(
            onPressed: () {
              _voirJournal();
              m.comparerEmpreintes();
            },
            child: const Text('Comparer'),
          ),
        ],
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Réglages

class OngletReglages extends StatefulWidget {
  const OngletReglages({super.key, required this.reglages, required this.moteur, required this.redemarrer});
  final Reglages reglages;
  final Moteur moteur;
  final Future<void> Function({bool effacer}) redemarrer;
  @override
  State<OngletReglages> createState() => _OngletReglagesState();
}

class _OngletReglagesState extends State<OngletReglages> {
  late final Map<String, TextEditingController> _c = {
    for (final k in ['nom', 'foyer', 'hote', 'port', 'utilisateur', 'motDePasse']) k: TextEditingController(text: '${widget.reglages.v[k]}'),
  };
  late bool _tls = widget.reglages.v['tls'] as bool;

  Widget _champ(String cle, String libelle, {String? aide, bool secret = false, bool nombre = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _c[cle],
          obscureText: secret,
          keyboardType: nombre ? TextInputType.number : null,
          decoration: InputDecoration(labelText: libelle, helperText: aide, border: const OutlineInputBorder()),
        ),
      );

  Future<void> _appliquer() async {
    final v = widget.reglages.v;
    v['nom'] = _c['nom']!.text.trim().isEmpty ? v['nom'] : _c['nom']!.text.trim();
    v['foyer'] = _c['foyer']!.text.trim().isEmpty ? v['foyer'] : _c['foyer']!.text.trim().toUpperCase();
    v['hote'] = _c['hote']!.text.trim();
    v['port'] = int.tryParse(_c['port']!.text.trim()) ?? v['port'];
    v['tls'] = _tls;
    v['utilisateur'] = _c['utilisateur']!.text.trim();
    v['motDePasse'] = _c['motDePasse']!.text;
    await widget.reglages.sauver();
    await widget.redemarrer();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _champ('nom', 'Nom de cet appareil', aide: 'Affiché chez les autres (« PC », « Téléphone d\'Aristide »…)'),
      _champ('foyer', 'Code du foyer', aide: 'Le même code sur le PC et le téléphone pour qu\'ils se voient'),
      const Divider(height: 32),
      Text('Serveur MQTT', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Par défaut, le serveur public gratuit de HiveMQ : aucun compte, mais tout le monde peut lire ce qui passe '
        'si on connaît le code du foyer. N\'y mettez que des données d\'essai.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      _champ('hote', 'Adresse du serveur'),
      _champ('port', 'Port', aide: '8883 avec chiffrement TLS, 1883 sans', nombre: true),
      SwitchListTile(title: const Text('Chiffrement TLS'), value: _tls, onChanged: (v) => setState(() => _tls = v)),
      _champ('utilisateur', 'Utilisateur (vide pour le serveur public)'),
      _champ('motDePasse', 'Mot de passe', secret: true),
      const SizedBox(height: 8),
      FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Appliquer et se reconnecter'), onPressed: _appliquer),
      const Divider(height: 32),
      OutlinedButton.icon(
        icon: const Icon(Icons.delete_forever),
        label: const Text('Effacer la base locale de cet appareil'),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text('Effacer toutes les données de cet appareil ? Les autres appareils renverront ce qu\'ils ont '
                  'créé à la prochaine connexion.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Effacer')),
              ],
            ),
          );
          if (ok == true) await widget.redemarrer(effacer: true);
        },
      ),
      const SizedBox(height: 16),
      Text('Version $version · $plateforme · identifiant ${widget.moteur.id}', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
