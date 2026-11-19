// Mémo Emplettes (19/11/2026, demandé par Aristide) : les composants d'Emplettes et leurs liens, à personnaliser.
// Les rubriques cochées « Widget » s'affichent dans le widget d'écran d'accueil (android_ajouts/kotlin/MemoWidget.kt).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const Memo());

const vert = Color(0xFF3F7D5A);
const canal = MethodChannel('memo');

class Lien {
  Lien(this.nom, this.adresse);
  String nom, adresse;
  Map<String, dynamic> versJson() => {'nom': nom, 'adresse': adresse};
}

class Rubrique {
  Rubrique(this.titre, this.liens, {this.widget = true});
  String titre;
  bool widget;
  List<Lien> liens;
  Map<String, dynamic> versJson() => {'titre': titre, 'widget': widget, 'liens': [for (final l in liens) l.versJson()]};
  static Rubrique depuis(Map j) => Rubrique(j['titre'] as String? ?? '',
      [for (final l in (j['liens'] as List? ?? [])) Lien(l['nom'] as String? ?? '', l['adresse'] as String? ?? '')],
      widget: j['widget'] as bool? ?? true);
}

const _e = 'https://emplettes.eu';
const _t = '$_e/telechargements';
const _g = 'https://github.com/ChristianFrench/liste-de-courses';

List<Rubrique> origine() => [
      Rubrique('Site et applications web', [
        Lien('Site', _e),
        Lien('Démo web', '$_e/demo/'),
        Lien('Application web complète', '$_e/web/'),
      ]),
      Rubrique('Applications, version officielle', [
        Lien('APK Android (64 bits)', '$_t/Emplettes.apk'),
        Lien('APK démo', '$_t/Emplettes-demo.apk'),
        Lien('Installateur Windows', '$_t/Emplettes-Installation.exe'),
        Lien('Fiche des versions', '$_t/version.json'),
      ]),
      Rubrique('Versions d\'essai (mot de passe)', [
        Lien('APK Android', '$_t/essai/Emplettes.apk'),
        Lien('APK démo', '$_t/essai/Emplettes-demo.apk'),
        Lien('APK 32 bits (à la demande)', '$_t/essai/Emplettes-32bits.apk'),
        Lien('Installateur Windows', '$_t/essai/Emplettes-Installation.exe'),
        Lien('Console catalogue (Windows)', '$_t/console/Emplettes-Editeur-Installation.exe'),
        Lien('Mémo Emplettes (cette application)', '$_t/essai/Memo-Emplettes.apk'),
      ]),
      Rubrique('Documents et vidéo', [
        Lien('Mode d\'emploi', '$_e/documents/mode-emploi.html'),
        Lien('Mode d\'emploi (PDF)', '$_e/documents/Emplettes%20-%20Mode%20d\'emploi.pdf'),
        Lien('Dépliant', '$_e/documents/depliant.html'),
        Lien('Dépliant (PDF)', '$_e/documents/Emplettes%20-%20Depliant.pdf'),
        Lien('Vidéo', '$_e/video/emplettes.mp4'),
        Lien('Vidéo, format téléphone', '$_e/video/emplettes-vertical.mp4'),
      ]),
      Rubrique('Serveur', [
        Lien('Partage des foyers et catalogue', 'mqtt.emplettes.eu (port 8883)'),
        Lien('Notifications', 'https://ntfy.emplettes.eu'),
        Lien('Envoi des mails', 'listes@emplettes.eu'),
        Lien('Domaine et DNS (OVH)', 'https://www.ovh.com/manager/'),
      ], widget: false),
      Rubrique('Développement (GitHub)', [
        Lien('Dépôt du code', _g),
        Lien('Compilations', '$_g/actions'),
        Lien('Secrets', '$_g/settings/secrets/actions'),
        Lien('Ancienne copie du site', 'https://christianfrench.github.io/liste-de-courses/'),
      ], widget: false),
      Rubrique('Services extérieurs', [
        Lien('Firebase (notifications Android)', 'https://console.firebase.google.com/'),
        Lien('EmailJS (mails de secours)', 'https://dashboard.emailjs.com/'),
        Lien('Open Food Facts', 'https://fr.openfoodfacts.org/'),
      ], widget: false),
      Rubrique('Travail avec Claude', [
        Lien('Projet', 'https://claude.ai/code/project/chan_01UtiFSDgVhBKg3kPDpafRot'),
      ]),
    ];

class Memo extends StatelessWidget {
  const Memo({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mémo Emplettes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: vert, useMaterial3: true),
        home: const Accueil(),
      );
}

class Accueil extends StatefulWidget {
  const Accueil({super.key});
  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  List<Rubrique>? rubriques;
  bool modifier = false;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    List<Rubrique> r;
    try {
      final t = await canal.invokeMethod<String>('lire');
      r = t == null ? origine() : [for (final j in jsonDecode(t) as List) Rubrique.depuis(j as Map)];
    } catch (_) {
      r = origine();
    }
    setState(() => rubriques = r);
    await _ecrire();
  }

  Future<void> _ecrire() async {
    try {
      await canal.invokeMethod('ecrire', jsonEncode([for (final r in rubriques!) r.versJson()]));
    } catch (_) {}
  }

  void _changer(VoidCallback f) {
    setState(f);
    _ecrire();
  }

  Future<void> _ouvrir(String adresse) async {
    if (!adresse.startsWith('http')) {
      await Clipboard.setData(ClipboardData(text: adresse));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié')));
      return;
    }
    final ok = await canal.invokeMethod<bool>('ouvrir', adresse) ?? false;
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir ce lien')));
  }

  Future<List<String>?> _saisir(String titre, List<(String, String)> champs) {
    final c = [for (final ch in champs) TextEditingController(text: ch.$2)];
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < champs.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(controller: c[i], autofocus: i == 0, decoration: InputDecoration(labelText: champs[i].$1, border: const OutlineInputBorder())),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, [for (final x in c) x.text.trim()]), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _lien(Rubrique r, [Lien? l]) async {
    final v = await _saisir(l == null ? 'Nouveau lien' : 'Modifier le lien', [('Nom', l?.nom ?? ''), ('Adresse', l?.adresse ?? 'https://')]);
    if (v == null || v[0].isEmpty) return;
    _changer(() {
      if (l == null) {
        r.liens.add(Lien(v[0], v[1]));
      } else {
        l
          ..nom = v[0]
          ..adresse = v[1];
      }
    });
  }

  Future<void> _rubrique([Rubrique? r]) async {
    final v = await _saisir(r == null ? 'Nouvelle rubrique' : 'Renommer la rubrique', [('Titre', r?.titre ?? '')]);
    if (v == null || v[0].isEmpty) return;
    _changer(() => r == null ? rubriques!.add(Rubrique(v[0], [])) : r.titre = v[0]);
  }

  Future<bool> _confirmer(String question) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(content: Text(question), actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ]),
      ) ??
      false;

  void _deplacer<T>(List<T> l, int i, int d) {
    final j = i + d;
    if (j < 0 || j >= l.length) return;
    _changer(() => l.insert(j, l.removeAt(i)));
  }

  @override
  Widget build(BuildContext context) {
    final rs = rubriques;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        title: const Text('Mémo Emplettes'),
        actions: [
          IconButton(
            tooltip: modifier ? 'Terminer' : 'Modifier',
            icon: Icon(modifier ? Icons.check : Icons.edit_outlined),
            onPressed: () => setState(() => modifier = !modifier),
          ),
          PopupMenuButton<String>(
            onSelected: (_) async {
              if (await _confirmer('Remettre la liste d\'origine ? Vos modifications seront perdues.')) _changer(() => rubriques = origine());
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'origine', child: Text('Rétablir la liste d\'origine'))],
          ),
        ],
      ),
      floatingActionButton: modifier
          ? FloatingActionButton.extended(onPressed: _rubrique, backgroundColor: vert, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Rubrique'))
          : null,
      body: rs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text(
                  modifier
                      ? 'Modifiez, ajoutez, déplacez ou supprimez rubriques et liens. « Widget » choisit ce qui s\'affiche sur l\'écran d\'accueil.'
                      : 'Touchez un lien pour l\'ouvrir. Pour le widget : appui long sur l\'écran d\'accueil › Widgets › Mémo Emplettes.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              for (var i = 0; i < rs.length; i++) _carte(rs, i),
            ]),
    );
  }

  Widget _carte(List<Rubrique> rs, int i) {
    final r = rs[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(children: [
              Expanded(child: Text(r.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: vert))),
              const Text('Widget', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Switch(value: r.widget, activeThumbColor: vert, onChanged: (v) => _changer(() => r.widget = v)),
            ]),
          ),
          if (modifier)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(tooltip: 'Monter', icon: const Icon(Icons.arrow_upward), onPressed: () => _deplacer(rs, i, -1)),
              IconButton(tooltip: 'Descendre', icon: const Icon(Icons.arrow_downward), onPressed: () => _deplacer(rs, i, 1)),
              IconButton(tooltip: 'Renommer', icon: const Icon(Icons.edit_outlined), onPressed: () => _rubrique(r)),
              IconButton(
                tooltip: 'Supprimer la rubrique',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await _confirmer('Supprimer la rubrique « ${r.titre} » et ses liens ?')) _changer(() => rs.removeAt(i));
                },
              ),
            ]),
          for (var j = 0; j < r.liens.length; j++)
            ListTile(
              dense: true,
              title: Text(r.liens[j].nom, style: const TextStyle(fontSize: 15)),
              subtitle: Text(r.liens[j].adresse, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => modifier ? _lien(r, r.liens[j]) : _ouvrir(r.liens[j].adresse),
              trailing: modifier
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.arrow_upward, size: 20), onPressed: () => _deplacer(r.liens, j, -1)),
                      IconButton(icon: const Icon(Icons.arrow_downward, size: 20), onPressed: () => _deplacer(r.liens, j, 1)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _changer(() => r.liens.removeAt(j))),
                    ])
                  : const Icon(Icons.open_in_new, size: 18),
            ),
          if (modifier)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => _lien(r), icon: const Icon(Icons.add), label: const Text('Ajouter un lien')),
            ),
        ]),
      ),
    );
  }
}
