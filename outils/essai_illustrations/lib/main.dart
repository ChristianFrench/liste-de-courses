// Essai des tailles d'illustration des recettes (17/11/2026, demandé par Aristide) :
// - « Comparer » : une recette, ses quatre tailles l'une sous l'autre, en bandeau comme dans la fenêtre des ingrédients ;
// - « Catalogue » : charge et décode les 296 illustrations dans une taille, chronomètre, puis les affiche.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const Essai());

const vert = Color(0xFF3F7D5A);
const tailles = ['240', '360', '480', '720'];
String dimension(String t) => '$t × ${int.parse(t) * 2 ~/ 3}';
String chemin(String t, String nom) => 'assets/i$t/$nom.webp';

class Essai extends StatelessWidget {
  const Essai({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Essai illustrations',
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
  List<String> noms = [];
  Map<String, int> poids = {};

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/liste.json').then((t) {
      final j = jsonDecode(t) as Map<String, dynamic>;
      setState(() {
        noms = (j['noms'] as List).cast<String>();
        poids = (j['poids'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      });
    });
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: vert,
            foregroundColor: Colors.white,
            title: const Text('Essai des illustrations'),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'Comparer'), Tab(text: 'Catalogue')],
            ),
          ),
          body: noms.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [Comparer(noms: noms), Catalogue(noms: noms, poids: poids)]),
        ),
      );
}

/// Bandeau : toute la largeur, un tiers de la hauteur de l'écran, image recadrée au centre.
Widget bandeau(BuildContext context, String image) => SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height / 3,
      child: Image.asset(image, fit: BoxFit.cover, gaplessPlayback: true),
    );

class Comparer extends StatefulWidget {
  const Comparer({super.key, required this.noms});
  final List<String> noms;
  @override
  State<Comparer> createState() => _ComparerState();
}

class _ComparerState extends State<Comparer> {
  int i = 0;
  final ko = <String, int>{};

  Future<void> _poids() async {
    for (final t in tailles) {
      final b = await rootBundle.load(chemin(t, widget.noms[i]));
      ko[t] = (b.lengthInBytes / 1024).round();
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _poids();
  }

  void _aller(int d) {
    setState(() => i = (i + d) % widget.noms.length);
    ko.clear();
    _poids();
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.noms[i];
    final ecran = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Row(children: [
            IconButton(onPressed: () => _aller(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(nom.replaceAll('-', ' '), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => _aller(1), icon: const Icon(Icons.chevron_right)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Votre écran : ${(ecran.width * ratio).round()} pixels réels de large. '
            'Source : 768 × 512.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        for (final t in tailles) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('${dimension(t)}${ko[t] == null ? '' : ' · ${ko[t]} Ko'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: vert)),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(title: Text(dimension(t))),
                body: InteractiveViewer(maxScale: 6, child: Center(child: Image.asset(chemin(t, nom)))),
              ),
            )),
            child: bandeau(context, chemin(t, nom)),
          ),
        ],
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Touchez une image pour l\'agrandir avec deux doigts.', style: TextStyle(fontSize: 13, color: Colors.black54)),
        ),
      ],
    );
  }
}

class Mesure {
  Mesure(this.taille, this.nb, this.ms, this.octets, this.plusLong);
  final String taille;
  final int nb, ms, octets, plusLong;
}

class Catalogue extends StatefulWidget {
  const Catalogue({super.key, required this.noms, required this.poids});
  final List<String> noms;
  final Map<String, int> poids;
  @override
  State<Catalogue> createState() => _CatalogueState();
}

class _CatalogueState extends State<Catalogue> {
  String taille = '720';
  bool enCours = false;
  int fait = 0;
  final mesures = <String, Mesure>{};
  String? affiche;

  /// Lit et décode chaque image (sans la garder en mémoire : 296 images en 720 feraient 400 Mo).
  Future<void> _charger(String t) async {
    setState(() {
      enCours = true;
      fait = 0;
      affiche = null;
      taille = t;
    });
    imageCache.clear();
    final chrono = Stopwatch()..start();
    var octets = 0, plusLong = 0;
    for (final n in widget.noms) {
      final debut = chrono.elapsedMilliseconds;
      final b = await rootBundle.load(chemin(t, n));
      octets += b.lengthInBytes;
      final codec = await ui.instantiateImageCodec(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
      final f = await codec.getNextFrame();
      f.image.dispose();
      codec.dispose();
      final duree = chrono.elapsedMilliseconds - debut;
      if (duree > plusLong) plusLong = duree;
      fait++;
      if (fait % 8 == 0 && mounted) setState(() {});
    }
    chrono.stop();
    if (!mounted) return;
    setState(() {
      mesures[t] = Mesure(t, widget.noms.length, chrono.elapsedMilliseconds, octets, plusLong);
      enCours = false;
      affiche = t;
    });
  }

  Future<void> _lesQuatre() async {
    for (final t in tailles.reversed) {
      await _charger(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.noms.length;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('$n illustrations. Choisissez une taille : elles sont toutes lues et décodées, chronomètre en main, puis affichées.',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in tailles.reversed)
                FilledButton(
                  onPressed: enCours ? null : () => _charger(t),
                  style: FilledButton.styleFrom(backgroundColor: vert),
                  child: Text(dimension(t)),
                ),
              OutlinedButton(onPressed: enCours ? null : _lesQuatre, child: const Text('Les quatre')),
            ]),
            if (enCours) ...[
              const SizedBox(height: 14),
              Text('Chargement en ${dimension(taille)} : $fait / $n'),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: fait / n, color: vert),
            ],
            if (mesures.isNotEmpty) ...[
              const SizedBox(height: 16),
              Table(
                columnWidths: const {0: FlexColumnWidth(1.3)},
                border: TableBorder.all(color: Colors.black12),
                children: [
                  const TableRow(children: [_C('Taille', gras: true), _C('Poids total', gras: true), _C('Tout charger', gras: true), _C('Par image', gras: true)]),
                  for (final t in tailles.reversed)
                    if (mesures[t] case final m?)
                      TableRow(children: [
                        _C(dimension(t)),
                        _C('${(m.octets / 1e6).toStringAsFixed(1)} Mo'),
                        _C('${(m.ms / 1000).toStringAsFixed(1)} s'),
                        _C('${(m.ms / m.nb).round()} ms (max ${m.plusLong})'),
                      ]),
                ],
              ),
              const SizedBox(height: 6),
              const Text('« Par image » : le temps d\'apparition d\'une illustration à l\'ouverture d\'une recette.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ]),
        ),
      ),
      if (affiche case final t?)
        SliverList.builder(
          itemCount: n,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Stack(children: [
              bandeau(context, chemin(t, widget.noms[i])),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: Colors.black54,
                  child: Text('${i + 1}. ${widget.noms[i].replaceAll('-', ' ')} · ${dimension(t)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _C extends StatelessWidget {
  const _C(this.texte, {this.gras = false});
  final String texte;
  final bool gras;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(texte, style: TextStyle(fontSize: 13, fontWeight: gras ? FontWeight.bold : FontWeight.normal)),
      );
}
