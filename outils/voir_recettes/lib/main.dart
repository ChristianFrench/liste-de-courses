// Visionneuse des recettes d'un export Google Keep (10/11/2026, Aristide) : une liste déroulante des recettes
// en haut ; dessous, les attributs (libellés, dates, couleur…), puis les images, puis le texte.
// Les notes (.json) sont lues dans le dossier du programme ; sinon on choisit le dossier.

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

void main() => runApp(const VoirRecettes());

const vert = Color(0xFF3F7D5A);

class Note {
  Note(this.j, this.dossier);
  final Map<String, dynamic> j;
  final String dossier;
  String get titre => (j['title'] as String? ?? '').trim().isEmpty ? '(sans titre)' : (j['title'] as String).trim();
  String get texte => j['textContent'] as String? ?? '';
  List<Map> get cases => (j['listContent'] as List? ?? const []).cast<Map>();
  List<String> get libelles => [for (final l in (j['labels'] as List? ?? const [])) (l as Map)['name'] as String? ?? ''];
  List<String> get images => [
    for (final a in (j['attachments'] as List? ?? const []).cast<Map>())
      if (((a['mimetype'] as String?) ?? '').startsWith('image') ||
          RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(a['filePath'] as String? ?? ''))
        '$dossier${Platform.pathSeparator}${(a['filePath'] as String).split(RegExp(r'[\\/]')).last}',
  ];
  List<Map> get liens => [
    for (final a in (j['annotations'] as List? ?? const []).cast<Map>())
      if (a['url'] != null) a,
  ];
  DateTime? date(String cle) => (j[cle] as num?) == null ? null : DateTime.fromMicrosecondsSinceEpoch((j[cle] as num).toInt());
  bool get epinglee => j['isPinned'] == true;
  bool get archivee => j['isArchived'] == true;
  Color? get couleur => const {
    'RED': Color(0xFFF28B82),
    'ORANGE': Color(0xFFFBBC04),
    'YELLOW': Color(0xFFFFF475),
    'GREEN': Color(0xFFCCFF90),
    'TEAL': Color(0xFFA7FFEB),
    'BLUE': Color(0xFFCBF0F8),
    'CERULEAN': Color(0xFFAECBFA),
    'PURPLE': Color(0xFFD7AEFB),
    'PINK': Color(0xFFFDCFE8),
    'BROWN': Color(0xFFE6C9A8),
    'GRAY': Color(0xFFE8EAED),
  }[j['color']];
}

/// Notes Keep (.json) d'un dossier, sans celles de la corbeille, triées par titre.
List<Note> lireNotes(String dossier) {
  final res = <Note>[];
  final d = Directory(dossier);
  if (!d.existsSync()) return res;
  for (final f in d.listSync().whereType<File>()) {
    if (!f.path.toLowerCase().endsWith('.json')) continue;
    try {
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map<String, dynamic> || j['isTrashed'] == true) continue;
      if (!j.containsKey('textContent') && !j.containsKey('listContent') && !j.containsKey('title')) continue;
      res.add(Note(j, dossier));
    } catch (_) {}
  }
  res.sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
  return res;
}

class VoirRecettes extends StatelessWidget {
  const VoirRecettes({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mes recettes',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: vert, useMaterial3: true, fontFamily: 'Segoe UI'),
    home: const Ecran(),
  );
}

class Ecran extends StatefulWidget {
  const Ecran({super.key});
  @override
  State<Ecran> createState() => _EcranState();
}

class _EcranState extends State<Ecran> {
  String dossier = File(Platform.resolvedExecutable).parent.path;
  List<Note> notes = [];
  int choisie = 0;
  final champ = TextEditingController();

  /// Libellé choisi pour filtrer (null : tous).
  String? libelle;
  List<String> get libelles => {for (final n in notes) ...n.libelles}.where((l) => l.isNotEmpty).toList()..sort();
  List<Note> get visibles => libelle == null ? notes : notes.where((n) => n.libelles.contains(libelle)).toList();

  @override
  void initState() {
    super.initState();
    notes = lireNotes(dossier);
    if (notes.isNotEmpty) champ.text = notes.first.titre;
  }

  Future<void> _choisirDossier() async {
    final d = await getDirectoryPath(confirmButtonText: 'Ouvrir ce dossier');
    if (d == null) return;
    setState(() {
      dossier = d;
      notes = lireNotes(d);
      libelle = null;
      choisie = 0;
      champ.text = notes.isEmpty ? '' : notes.first.titre;
    });
  }

  String _jour(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final vus = visibles;
    final n = vus.isEmpty ? null : vus[choisie.clamp(0, vus.length - 1)];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        title: Text('Mes recettes · ${libelle == null ? notes.length : '${vus.length} / ${notes.length}'}'),
        actions: [
          TextButton.icon(
            onPressed: _choisirDossier,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.folder_open),
            label: const Text('Changer de dossier'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Aucune note Keep dans\n$dossier', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _choisirDossier,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choisir le dossier des recettes'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: LayoutBuilder(
                    builder: (context, c) => Row(
                      children: [
                        // 10/11/2026 (Aristide) : filtrage par libellé (Recettes Dessert, Recettes Plats…).
                        DropdownMenu<String>(
                          key: ValueKey('libelles-$dossier'),
                          width: 280,
                          initialSelection: '',
                          label: const Text('Libellé'),
                          leadingIcon: const Icon(Icons.label_outline),
                          onSelected: (l) => setState(() {
                            libelle = (l == null || l.isEmpty) ? null : l;
                            choisie = 0;
                            final v = visibles;
                            champ.text = v.isEmpty ? '' : v.first.titre;
                          }),
                          dropdownMenuEntries: [
                            const DropdownMenuEntry(value: '', label: 'Tous les libellés'),
                            for (final l in libelles) DropdownMenuEntry(value: l, label: l),
                          ],
                        ),
                        const SizedBox(width: 16),
                        DropdownMenu<int>(
                          key: ValueKey('menu-$dossier-$libelle'),
                          controller: champ,
                          width: c.maxWidth - 296,
                          menuHeight: 480,
                          initialSelection: choisie,
                          enableFilter: true,
                          enableSearch: true,
                          requestFocusOnTap: true,
                          label: const Text('Recette (tapez pour chercher)'),
                          leadingIcon: const Icon(Icons.menu_book_outlined),
                          onSelected: (i) => setState(() => choisie = i ?? choisie),
                          dropdownMenuEntries: [for (var i = 0; i < vus.length; i++) DropdownMenuEntry(value: i, label: vus[i].titre)],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: n == null ? const Center(child: Text('Aucune recette avec ce libellé.')) : _contenu(n)),
              ],
            ),
    );
  }

  Widget _contenu(Note n) {
    final cree = n.date('createdTimestampUsec'), modif = n.date('userEditedTimestampUsec');
    final attributs = <Widget>[
      for (final l in n.libelles) Chip(label: Text(l), visualDensity: VisualDensity.compact),
      if (cree != null) Text('Créée le ${_jour(cree)}'),
      if (modif != null) Text('Modifiée le ${_jour(modif)}'),
      if (n.epinglee) const Text('📌 Épinglée'),
      if (n.archivee) const Text('Archivée'),
      if (n.couleur != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: n.couleur,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Couleur'),
          ],
        ),
    ];
    return SingleChildScrollView(
      key: ValueKey(n),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: n.couleur ?? const Color(0xFFDDE3DF), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(n.titre, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  // 1. Les attributs.
                  DefaultTextStyle(
                    style: const TextStyle(color: Color(0xFF6B7A70), fontSize: 13),
                    child: Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: attributs),
                  ),
                  // 2. Les images (toucher une image l'agrandit).
                  if (n.images.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final im in n.images)
                          if (File(im).existsSync())
                            GestureDetector(
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (ctx) => GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: InteractiveViewer(child: Image.file(File(im))),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(im), height: 260, fit: BoxFit.contain),
                              ),
                            ),
                      ],
                    ),
                  ],
                  // 3. Le texte (ou la liste à cocher).
                  const SizedBox(height: 18),
                  if (n.cases.isNotEmpty)
                    for (final c in n.cases)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${c['isChecked'] == true ? '☑' : '☐'}  ${c['text'] ?? ''}',
                          style: TextStyle(
                            fontSize: 16,
                            color: c['isChecked'] == true ? const Color(0xFF6B7A70) : null,
                            decoration: c['isChecked'] == true ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      )
                  else
                    SelectableText(n.texte, style: const TextStyle(fontSize: 16, height: 1.5)),
                  for (final l in n.liens) ...[
                    const SizedBox(height: 10),
                    SelectableText('🔗 ${l['title'] ?? ''}  ${l['url']}', style: const TextStyle(color: vert)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
