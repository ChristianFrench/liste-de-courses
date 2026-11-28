import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../composants/composants.dart' show Bouton, confirmer, demanderTexte;
import '../donnees/moderation.dart' show Moderation;
import 'console_commun.dart';
import '../donnees/journal_catalogue.dart';
import '../donnees/recettes.dart';
import '../donnees/recettes_communes.dart';
import '../navigation.dart' show Nav;
import 'console_recettes_edition.dart';
import '../theme.dart';
import '../donnees/modele.dart' show Etat, EtatChargement;

// Console › Catalogue des recettes (10/11/2026, Aristide) : base séparée, importée des notes Google Keep.
// À gauche, la liste façon catalogue : un bandeau dépliable par type (Plats, Sauces, Desserts…), puis ses
// recettes avec leur vignette. À droite, la fiche de la recette choisie : bandeau du titre et de ses types,
// puis les onglets Photos / Ingrédients / Recette.

class PageRecettes extends StatefulWidget {
  const PageRecettes({super.key, this.base});

  /// Base imposée (tests) ; sinon celle du dossier de la console.
  final BaseRecettes? base;

  @override
  State<PageRecettes> createState() => _PageRecettesState();
}

class _PageRecettesState extends State<PageRecettes> {
  BaseRecettes? base;
  Recette? choisie;
  final ouverts = <String>{};
  String recherche = '';

  @override
  void initState() {
    super.initState();
    if (widget.base != null) {
      base = widget.base;
    } else {
      BaseRecettes.ouvrir().then((b) async {
        // 20/11/2026 : le journal démarre sur l'état actuel ; une livraison qui suit y est notée.
        try {
          await b.demarrerJournal();
        } catch (e) {
          Etat.instance.noter('Journal des recettes non démarré : $e');
        }
        // Recettes reformulées et illustrations livrées avec la console : posées sans rien demander.
        try {
          await b.appliquerRecettesFournies();
        } catch (e) {
          Etat.instance.noter('Recettes livrées non appliquées : $e');
        }
        try {
          await b.appliquerIllustrationsFournies();
        } catch (e) {
          Etat.instance.noter('Illustrations livrées non appliquées : $e');
        }
        if (mounted) setState(() => base = b);
      }, onError: (Object e) {
        // Sans dossier de données (tests) : une base vide, en mémoire.
        if (mounted) setState(() => base = BaseRecettes(Directory.systemTemp.createTempSync('recettes')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = base;
    if (b == null) return Center(child: Text('Chargement…', style: Charte.texte(16, couleur: Charte.texteSecondaire)));
    // 21/11/2026 (Aristide) : même présentation que le catalogue des produits ; la hiérarchie type › sous-type ›
    // recettes sur toute la largeur, le détail d'une recette en fenêtre.
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _titre(b),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(child: _cadreListe(b)),
      ]),
    );
  }

  // ------------------------------------------------------------ Versions (20/11/2026)

  String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

  /// En-tête : où en est le catalogue des recettes, Généraliser et le menu ☰, comme pour les produits.
  Widget _titre(BaseRecettes b) {
    final (a, m, r) = RecettesCommunes.changements(b);
    final aPublier = RecettesCommunes.aPublier(b);
    final types = b.parType();
    final illustrees = b.recettes.where((x) => x.illustration != null).length;
    final ecarts = a.length + m.length + r.length;
    return EnTeteConsole(
      signe: Image.asset('assets/recettes/recettes-de-cuisine.png', width: 34, height: 34),
      titre: 'Catalogue des recettes',
      chiffres: [
        b.publiee.isEmpty ? 'Aucune version publiée' : 'Version publiée v${RecettesCommunes.libellePublie(b)} du ${_date('${b.publiee['date']}').split(' ').first}',
        _pluriel(types.length, 'type'),
        _pluriel(b.recettes.length, 'recette'),
        _pluriel(illustrees, 'illustrée'),
        if (a.isNotEmpty || m.isNotEmpty || r.isNotEmpty)
          'depuis la dernière version : ${[
            if (a.isNotEmpty) _pluriel(a.length, 'ajoutée'),
            if (m.isNotEmpty) _pluriel(m.length, 'modifiée'),
            if (r.isNotEmpty) _pluriel(r.length, 'retirée'),
          ].join(', ')}',
      ],
      pastilles: [
        PastilleConsole('en-cours', 'en cours', '${b.enCours}', fort: b.enCours > 0),
        PastilleConsole('etapes', 'étapes', '${b.journal.etapes.length}'),
        PastilleConsole('a-generaliser', 'à généraliser', b.publiee.isEmpty ? '${RecettesCommunes.publiables(b).length}' : (ecarts == 0 ? 'rien' : '$ecarts')),
      ],
      bouton: BoutonConsole(
        key: const ValueKey('recettes-generaliser'),
        texte: _publication != null ? 'Envoi… $_publication' : 'Généraliser…',
        icone: Icons.public,
        plein: true,
        onTap: _publication != null || !aPublier || b.enCours > 0 ? null : () => _generaliser(b),
      ),
      menu: [
        const EntreeMenuConsole('historique', Icons.history, 'Historique…'),
        const EntreeMenuConsole('nouvelle', Icons.add, 'Nouvelle recette…'),
        EntreeMenuConsole('valider', Icons.check, 'Valider les modifications (${b.enCours})…', actif: b.enCours > 0),
        EntreeMenuConsole('generaliser', Icons.public, 'Généraliser…', actif: aPublier && b.enCours == 0 && _publication == null),
      ],
      onMenu: (v) => switch (v) {
        'historique' => _historique(b),
        'nouvelle' => _modifier(b, null),
        'valider' => _valider(b),
        _ => _generaliser(b),
      },
      alertes: [
        if (b.enCours > 0) ('${_pluriel(b.enCours, 'modification')} en cours : validez-les (menu ☰) avant de généraliser.', false),
      ],
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : JournalCatalogue.nomParDefaut(d);
  }

  /// Avancement de la publication (« 12/496 images »), ou null.
  String? _publication;

  Future<Recette?> _modifier(BaseRecettes b, Recette? r) async {
    final x = await editerRecette(context, recette: r, base: b);
    if (x == null || !mounted) return null;
    await b.modifier(r, x);
    if (mounted) setState(() => choisie = x);
    return x;
  }

  Future<Recette?> _illustrer(BaseRecettes b, Recette r) async {
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp'])]);
    if (f == null || !mounted) return null;
    final x = r.copie()..illustration = await b.copierIllustration(r, File(f.path));
    await b.modifier(r, x);
    if (mounted) setState(() => choisie = x);
    return x;
  }

  Future<bool> _supprimer(BaseRecettes b, Recette r) async {
    final ok = await confirmer(context,
        titre: 'Supprimer « ${r.titre} » ?',
        contenu: Text('Elle disparaîtra des applications à la prochaine version généralisée.', style: Charte.texte(15)),
        plein: 'Annuler',
        contour: 'Supprimer');
    if (ok != true || !mounted) return false;
    await b.supprimer(r);
    if (mounted) setState(() => choisie = null);
    return true;
  }

  Future<void> _valider(BaseRecettes b) async {
    final defaut = JournalCatalogue.nomParDefaut(DateTime.now());
    final nom = await demanderTexte(context,
        titre: 'Valider ${_pluriel(b.enCours, 'modification')} ?', aide: 'Nom de l\'étape (par défaut le jour et l\'heure)',
        libelle: 'Nom de l\'étape', initial: defaut, valider: 'Valider');
    if (nom == null || !mounted) return;
    await b.valider(nom.trim().isEmpty ? defaut : nom.trim());
    if (mounted) setState(() {});
  }

  Future<void> _generaliser(BaseRecettes b) async {
    if (b.enCours > 0) {
      Nav.message(context, 'Validez d\'abord les ${_pluriel(b.enCours, 'modification')} en cours');
      return;
    }
    final (a, m, r) = RecettesCommunes.changements(b);
    final complement = RecettesCommunes.libelleSuivant(b), majeure = RecettesCommunes.libelleSuivant(b, majeure: true);
    final choix = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Charte.blanc,
        title: Text('Généraliser le catalogue des recettes', style: Charte.texte(19, gras: true)),
        content: Text(
            '${RecettesCommunes.publiables(b).length} recettes. '
            '${b.publiee.isEmpty ? 'Première version : toutes les recettes et leurs images partent sur le serveur, ce qui peut prendre quelques minutes.' : 'Depuis la v${RecettesCommunes.libellePublie(b)} : ${a.length} ajoutée(s), ${m.length} modifiée(s), ${r.length} retirée(s).'}\n\n'
            'Chaque application la reçoit à son prochain lancement.',
            style: Charte.texte(15)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: Charte.texte(15))),
          if (complement != majeure)
            TextButton(key: const ValueKey('recettes-complement'), onPressed: () => Navigator.of(ctx).pop(false), child: Text('Complément v$complement', style: Charte.texte(15, gras: true))),
          TextButton(key: const ValueKey('recettes-majeure'), onPressed: () => Navigator.of(ctx).pop(true), child: Text('Version v$majeure', style: Charte.texte(15, gras: true))),
        ],
      ),
    );
    if (choix == null || !mounted) return;
    setState(() => _publication = '');
    final libelle = await RecettesCommunes.generaliser(b, majeure: choix, progres: (n, total) {
      if (mounted) setState(() => _publication = '$n/$total images');
    });
    if (!mounted) return;
    setState(() => _publication = null);
    Nav.message(context, libelle != null
        ? 'Recettes v$libelle généralisées : chaque application les reçoit à son prochain lancement'
        : 'Rien n\'est envoyé (${RecettesCommunes.erreur}) : réessayez');
  }

  Future<void> _historique(BaseRecettes b) async {
    await showDialog<void>(context: context, builder: (_) => _Historique(base: b));
    if (mounted) setState(() => choisie = null);
  }

  // ------------------------------------------------------------ la liste (21/11/2026)

  /// Sous-types dépliés (« type|sous-type ») ; [ouverts] garde les types dépliés.
  final sousOuverts = <String>{};

  // Recherche au sens strict, comme pour les produits : « type|id » des recettes trouvées.
  List<String> _resultats = const [];
  int _indice = 0;
  final _defilement = ScrollController();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  static String _plat(String t) => Moderation.sansAccents(t.toLowerCase()).replaceAll('œ', 'oe');

  /// Type › sous-type › recettes (par titre) ; « Sans sous-type » pour une recette qui n'en a pas.
  Map<String, Map<String, List<Recette>>> _arbre(BaseRecettes b) {
    final m = <String, Map<String, List<Recette>>>{};
    for (final MapEntry(key: type, value: l) in b.parType().entries) {
      final s = <String, List<Recette>>{};
      final tries = [...l]..sort((a, c) {
          final x = rangSousType(type, a.sousTypes[type]).compareTo(rangSousType(type, c.sousTypes[type]));
          return x != 0 ? x : _plat(a.titre).compareTo(_plat(c.titre));
        });
      for (final r in tries) {
        s.putIfAbsent(r.sousTypes[type] ?? 'Sans sous-type', () => []).add(r);
      }
      m[type] = s;
    }
    return m;
  }

  void _chercher(BaseRecettes b, String v) {
    recherche = v;
    final q = _plat(v.trim());
    _resultats = q.length < 2
        ? const []
        : [
            for (final MapEntry(key: t, value: s) in _arbre(b).entries)
              for (final l in s.values)
                for (final r in l)
                  if (_plat(r.titre).contains(q) || r.ingredients.any((i) => _plat(i).contains(q))) '$t|${r.id}',
          ];
    _indice = 0;
    if (_resultats.isEmpty) {
      setState(() {});
    } else {
      _allerA(b, 0);
    }
  }

  void _allerA(BaseRecettes b, int i) {
    if (_resultats.isEmpty) return;
    _indice = i % _resultats.length;
    final cle = _resultats[_indice];
    final type = cle.substring(0, cle.indexOf('|')), id = cle.substring(cle.indexOf('|') + 1);
    final r = b.recettes.firstWhere((x) => x.id == id);
    setState(() {
      choisie = r;
      ouverts.add(type);
      sousOuverts.add('$type|${r.sousTypes[type] ?? 'Sans sous-type'}');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      var y = 0.0;
      for (final l in _lignes(b)) {
        if (l.$3 != null && l.$1 == type && l.$3!.id == id) break;
        y += RangeeConsole.hauteurDe(titre: l.$3 == null);
      }
      final pos = _defilement.position;
      _defilement.jumpTo((y - pos.viewportDimension / 3).clamp(0.0, pos.maxScrollExtent));
    });
  }

  /// Les lignes du cadre : (type, sous-type, recette).
  List<(String, String?, Recette?)> _lignes(BaseRecettes b) => [
        for (final MapEntry(key: t, value: s) in _arbre(b).entries) ...[
          (t, null, null),
          if (ouverts.contains(t))
            for (final MapEntry(key: st, value: l) in s.entries) ...[
              (t, st, null),
              if (sousOuverts.contains('$t|$st')) for (final r in l) (t, st, r),
            ],
        ],
      ];

  /// Le détail d'une recette, en fenêtre : la fiche (onglets), ses gestes, Fermer.
  Future<void> _detail(BaseRecettes b, Recette r) async {
    setState(() => choisie = r);
    var courante = r;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => Dialog(
          backgroundColor: Charte.blanc,
          child: SizedBox(
            width: 1040,
            height: 780,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: FicheRecette(
                  key: ValueKey('${courante.id}-${courante.modifieeLe?.millisecondsSinceEpoch}'),
                  recette: courante,
                  base: b,
                  modifier: () async {
                    final x = await _modifier(b, courante);
                    if (x != null) maj(() => courante = x);
                  },
                  illustrer: () async {
                    final x = await _illustrer(b, courante);
                    if (x != null) maj(() => courante = x);
                  },
                  supprimer: () async {
                    if (await _supprimer(b, courante) && ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
              Container(height: 1, color: Charte.separateurZone),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: BoutonConsole(key: const ValueKey('recette-fermer'), texte: 'Fermer', onTap: () => Navigator.of(ctx).pop()),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _menuRecette(BaseRecettes b, Offset ou, Recette r) async {
    setState(() => choisie = r);
    final v = await menuConsole(context, ou, const [
      EntreeMenuConsole('voir', Icons.menu_book_outlined, 'Voir la recette…'),
      EntreeMenuConsole('modifier', Icons.edit_outlined, 'Modifier…'),
      EntreeMenuConsole('illustrer', Icons.add_photo_alternate_outlined, 'Changer l\'illustration…'),
      null,
      EntreeMenuConsole('supprimer', Icons.delete_outline, 'Supprimer'),
    ]);
    if (!mounted) return;
    switch (v) {
      case 'voir':
        await _detail(b, r);
      case 'modifier':
        await _modifier(b, r);
      case 'illustrer':
        await _illustrer(b, r);
      case 'supprimer':
        await _supprimer(b, r);
    }
  }

  Widget _rangee(BaseRecettes b, Map<String, Map<String, List<Recette>>> arbre, (String, String?, Recette?) l) {
    final (type, st, r) = l;
    if (r != null) {
      final cle = '$type|${r.id}';
      return RangeeConsole(
        key: ValueKey('recette-${r.id}-$type'),
        profondeur: 1,
        titre: false,
        libelle: r.titre,
        choisie: identical(r, choisie),
        trouvee: _resultats.isNotEmpty && _resultats[_indice] == cle,
        colonnes: [
          ([if (r.pour != null) r.pour!, if (r.repereTemps.isNotEmpty) r.repereTemps].join(' · '), 4),
          ([if (r.origine != null) r.origine!, if (r.cout != null) r.cout!, ...r.regimes].join(' · '), 3),
        ],
        onTap: () => _detail(b, r),
        onDoubleTap: () => _modifier(b, r),
        onClicDroit: (o) => _menuRecette(b, o, r),
      );
    }
    if (st != null) {
      final k = '$type|$st';
      final ouvert = sousOuverts.contains(k);
      return RangeeConsole(
        key: ValueKey('sous-type-$type-$st'),
        profondeur: 1,
        ouvert: ouvert,
        libelle: st,
        compte: _pluriel(arbre[type]![st]!.length, 'recette'),
        onTap: () => setState(() => ouvert ? sousOuverts.remove(k) : sousOuverts.add(k)),
      );
    }
    final ouvert = ouverts.contains(type);
    final n = arbre[type]!.values.fold(0, (n, l) => n + l.length);
    return RangeeConsole(
      key: ValueKey('type-recette-$type'),
      profondeur: 0,
      ouvert: ouvert,
      signe: Image.asset(iconeTypeRecette(type), width: 30, height: 30),
      libelle: type,
      compte: '${_pluriel(arbre[type]!.length, 'sous-type')} · ${_pluriel(n, 'recette')}',
      onTap: () => setState(() => ouvert ? ouverts.remove(type) : ouverts.add(type)),
    );
  }

  Widget _cadreListe(BaseRecettes b) {
    final arbre = _arbre(b);
    final lignes = _lignes(b);
    final toutes = {for (final MapEntry(key: t, value: s) in arbre.entries) for (final st in s.keys) '$t|$st'};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BarreConsole(
        aideRecherche: 'Une recette ou un ingrédient',
        recherche: recherche,
        onChercher: (v) => _chercher(b, v),
        onSuivant: () => _allerA(b, _indice + 1),
        onPrecedent: () => _allerA(b, _indice - 1 + _resultats.length),
        trouves: _resultats.length,
        indice: _indice,
        onDeplier: () => setState(() {
          ouverts.addAll(arbre.keys);
          sousOuverts.addAll(toutes);
        }),
        onReplier: () => setState(() {
          ouverts.clear();
          sousOuverts.clear();
        }),
        boutons: [
          BoutonConsole(key: const ValueKey('recettes-nouvelle'), texte: 'Nouvelle recette', icone: Icons.add, onTap: () => _modifier(b, null)),
        ],
        aide: 'Clic : voir la recette · Clic droit : voir, modifier, changer l\'illustration, supprimer · Double-clic : modifier',
      ),
      Expanded(
        child: CadreConsole(
          child: lignes.isEmpty
              ? Center(child: Text('Aucune recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
              : ListView.builder(
                  key: const ValueKey('recettes-cadre'),
                  controller: _defilement,
                  itemCount: lignes.length,
                  itemBuilder: (_, i) => _rangee(b, arbre, lignes[i]),
                ),
        ),
      ),
    ]);
  }
}

/// Icône d'un type de recette (images d'Aristide, 11/11/2026) ; « recettes-de-cuisine » pour les autres.
String iconeTypeRecette(String type) {
  final t = type.toLowerCase();
  if (t.startsWith('dessert') || t.startsWith('petit')) return 'assets/recettes/desserts.png';
  if (t.startsWith('entr') || t.startsWith('ap')) return 'assets/recettes/entrees.png';
  if (t.contains('accompagnement')) return 'assets/recettes/plats-accompagnement.png';
  if (t.startsWith('plat')) return 'assets/recettes/plats-complets.png';
  if (t.startsWith('sauce')) return 'assets/recettes/sauces.png';
  return 'assets/recettes/recettes-de-cuisine.png';
}

/// Fiche d'une recette : en-tête (titre, gestes), puis les onglets Caractéristiques, Ingrédients, Recette.
class FicheRecette extends StatelessWidget {
  const FicheRecette({super.key, required this.recette, required this.base, this.modifier, this.illustrer, this.supprimer});
  final Recette recette;
  final BaseRecettes base;

  /// Gestes de la console (20/11/2026) ; absents, la fiche est en lecture seule.
  final VoidCallback? modifier, illustrer, supprimer;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    // 22/11/2026 (Aristide : « réorganiser la fenêtre touffue du détail ») : un en-tête court (titre, gestes),
    // puis trois onglets : Caractéristiques (illustration et critères, tous présentés de la même façon),
    // Ingrédients (nombre de personnes, un ingrédient par ligne) et Recette.
    return DefaultTabController(
      length: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          child: Row(children: [
            Expanded(child: Text(r.titre, style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau))),
            if (modifier != null) ...[
              const SizedBox(width: 10),
              BoutonConsole(key: const ValueKey('recette-modifier'), texte: 'Modifier', icone: Icons.edit_outlined, onTap: modifier),
            ],
            if (illustrer != null) ...[
              const SizedBox(width: 8),
              BoutonConsole(key: const ValueKey('recette-illustrer'), texte: 'Illustration', icone: Icons.image_outlined, onTap: illustrer),
            ],
            if (supprimer != null) ...[
              const SizedBox(width: 8),
              BoutonConsole(key: const ValueKey('recette-supprimer'), texte: 'Supprimer', icone: Icons.delete_outline, onTap: supprimer),
            ],
          ]),
        ),
        TabBar(
          labelStyle: Charte.texte(15, gras: true),
          unselectedLabelStyle: Charte.texte(15),
          labelColor: Charte.encreNiveau,
          indicatorColor: Charte.cadre,
          tabs: const [Tab(text: 'Caractéristiques'), Tab(text: 'Ingrédients'), Tab(text: 'Recette')],
        ),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(
          child: TabBarView(children: [
            _caracteristiques(),
            _ingredients(),
            _recette(),
          ]),
        ),
      ]),
    );
  }

  /// Onglet Caractéristiques : l'illustration à gauche, à droite une ligne « libellé : valeur » par critère.
  Widget _caracteristiques() {
    final r = recette;
    String ou(String? x) => x == null || x.isEmpty ? '—' : x;
    String liste(List<String> l) => l.isEmpty ? '—' : l.join(', ');
    final lignes = <(String, String)>[
      ('Type', r.types.isEmpty ? '—' : [for (final t in r.types) r.sousTypes[t] == null ? t : '$t › ${r.sousTypes[t]}'].join(' ; ')),
      ('Origine', ou(r.origine)),
      ('Préparation', r.tempsPreparation == null ? '—' : dureeRecette(r.tempsPreparation!)),
      ('Cuisson', r.tempsCuisson == null ? '—' : (r.tempsCuisson == 0 ? 'Sans cuisson' : dureeRecette(r.tempsCuisson!))),
      ('Difficulté', ou(r.difficulte)),
      ('Régime', liste(r.regimes)),
      ('Saison', r.saisons.isEmpty ? '—' : r.repereSaisons),
      ('Coût', ou(r.cout)),
      ('Mode de cuisson', liste(r.cuissons)),
      ('Occasion', liste(r.occasions)),
      ('Source', r.source == null ? 'Recette maison' : 'Recette ${r.source}'),
      if (r.modifieeLe != null)
        ('Modifiée le', '${r.modifieeLe!.day.toString().padLeft(2, '0')}/${r.modifieeLe!.month.toString().padLeft(2, '0')}/${r.modifieeLe!.year}'),
    ];
    final nom = r.illustration ?? (r.photos.isEmpty ? null : r.photos.first);
    final f = nom == null ? null : base.photo(nom);
    final image = f != null && f.existsSync()
        ? Image.file(f, fit: BoxFit.cover)
        : Container(color: Charte.fondBandeau, padding: const EdgeInsets.all(40), child: Image.asset(iconeTypeRecette(r.types.isEmpty ? '' : r.types.first)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(key: const ValueKey('recette-illustration'), width: 420, height: 280, child: image)),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (libelle, valeur) in lignes)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 150, child: Text(libelle, style: Charte.texte(15, couleur: Charte.texteSecondaire))),
                  Expanded(child: SelectableText(valeur, style: Charte.texte(15, gras: true, couleur: Charte.encreNiveau))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
      );

  /// Onglet Recette : étapes numérotées, conseils, remarques à confirmer, texte Keep d'origine (replié).
  Widget _recette() {
    final r = recette;
    if (r.etapes.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: SelectableText(r.preparation.isEmpty ? '—' : r.preparation, style: Charte.texte(16).copyWith(height: 1.45)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 22), children: [
      for (var k = 0; k < r.etapes.length; k++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle),
              child: Text('${k + 1}', style: Charte.texte(14, gras: true, couleur: Charte.blanc)),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: SelectableText(r.etapes[k], style: Charte.texte(16).copyWith(height: 1.4)))),
          ]),
        ),
      if (r.conseils.isNotEmpty) ...[
        _titre('Conseils'),
        for (final c in r.conseils) _puce(c),
      ],
      if (r.remarques.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Charte.clair(Charte.orange, 0.88),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Charte.orange),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('À confirmer', style: Charte.texte(15, gras: true, couleur: Charte.orange)),
            const SizedBox(height: 6),
            for (final m in r.remarques) _puce(m),
          ]),
        ),
      if (r.texteOrigine != null && r.texteOrigine!.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Texte d\'origine (Google Keep)', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(r.texteOrigine!.trim(), style: Charte.texte(14, couleur: Charte.texteSecondaire).copyWith(height: 1.4)),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _puce(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle))),
          Expanded(child: SelectableText(t, style: Charte.texte(16))),
        ]),
      );

  Widget _ingredients() {
    final r = recette;
    final pour = r.pour == null
        ? const <Widget>[]
        : [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Pour ${r.pour}', key: const ValueKey('recette-pour'), style: Charte.texte(17, gras: true, couleur: Charte.encreNiveau)),
            ),
          ];
    if (r.detail.isNotEmpty) {
      // Un ingrédient par ligne : nom, quantité, précision.
      return ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 22), children: [
        ...pour,
        for (final i in r.detail)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: SelectableText(i.nom, style: Charte.texte(16, gras: true))),
              Expanded(flex: 3, child: SelectableText(i.quantite.isEmpty ? '—' : i.quantite, style: Charte.texte(16))),
              Expanded(flex: 4, child: SelectableText(i.precision, style: Charte.texte(15, couleur: Charte.texteSecondaire))),
            ]),
          ),
      ]);
    }
    if (r.ingredients.isEmpty) {
      return Center(child: Text(r.memo ? 'Mémo sans ingrédients : voir l\'onglet Recette.' : 'Pas de liste d\'ingrédients : tout est dans l\'onglet Recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 22), children: [
      ...pour,
      if (r.titreIngredients != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(r.titreIngredients!.replaceFirst(RegExp(r'\s*:\s*$'), ''), style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau)),
        ),
      for (final i in r.ingredients)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Charte.cadre, shape: BoxShape.circle))),
            Expanded(child: SelectableText(i, style: Charte.texte(16))),
          ]),
        ),
    ]);
  }
}


/// Historique des modifications du catalogue des recettes : les étapes (et ce qui est en cours) à gauche, le
/// détail à droite, « Revenir à cette étape » avec confirmation.
class _Historique extends StatefulWidget {
  const _Historique({required this.base});
  final BaseRecettes base;

  @override
  State<_Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<_Historique> {
  late int? choix = widget.base.enCours > 0 ? -1 : (widget.base.journal.etapes.isEmpty ? null : widget.base.journal.etapes.length - 1);

  @override
  Widget build(BuildContext context) {
    final j = widget.base.journal;
    String date(DateTime d) => JournalCatalogue.nomParDefaut(d);
    Widget ligne(int i) {
      final enCours = i < 0;
      final et = enCours ? null : j.etapes[i];
      final gestes = enCours ? j.enCours : et!.gestes;
      final etat = enCours ? 'en cours' : (et!.numero != null ? 'généralisée ${et.version}' : 'validée');
      return Material(
        color: choix == i ? Charte.fondSelection : Colors.transparent,
        child: InkWell(
          key: ValueKey('historique-recettes-$i'),
          onTap: () => setState(() => choix = i),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(enCours ? 'Modifications en cours' : et!.nom, style: Charte.texte(15, gras: true)),
              Text('${enCours ? '' : '${date(et!.date)} · '}$etat · ${gestes.length} modification${gestes.length > 1 ? 's' : ''}',
                  style: Charte.texte(12.5, couleur: enCours ? Charte.cadre : Charte.texteSecondaire)),
            ]),
          ),
        ),
      );
    }

    final c = choix;
    final gestes = c == null ? const <GesteCatalogue>[] : (c < 0 ? j.enCours : j.etapes[c].gestes);
    return Dialog(
      backgroundColor: Charte.blanc,
      child: SizedBox(
        width: 1000,
        height: 640,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Text('Historique du catalogue des recettes', style: Charte.texte(19, gras: true)),
          ),
          Container(height: 1, color: Charte.separateurZone),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 360,
                child: ListView(children: [
                  if (j.enCours.isNotEmpty) ligne(-1),
                  for (var i = j.etapes.length - 1; i >= 0; i--) ligne(i),
                ]),
              ),
              VerticalDivider(width: 1, thickness: 1, color: Charte.separateurZone),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (c != null && gestes.isEmpty) Text('Aucune modification.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                  for (final g in gestes.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final l in g.lignes) Text(l, style: Charte.texte(15)),
                        Text(date(g.date), style: Charte.texte(12, couleur: Charte.texteSecondaire)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
          Container(height: 1, color: Charte.separateurZone),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (c != null && c >= 0 && (c < j.etapes.length - 1 || j.enCours.isNotEmpty))
                Bouton(
                  key: const ValueKey('historique-recettes-revenir'),
                  texte: 'Revenir à cette étape',
                  icone: Icons.restore,
                  onTap: () async {
                    final suivantes = j.etapes.length - 1 - c;
                    final ok = await confirmer(context,
                        titre: 'Revenir à « ${j.etapes[c].nom} » ?',
                        contenu: Text(
                            [
                              if (suivantes > 0) '$suivantes étape${suivantes > 1 ? 's' : ''} suivante${suivantes > 1 ? 's' : ''}',
                              if (j.enCours.isNotEmpty) '${j.enCours.length} modification${j.enCours.length > 1 ? 's' : ''} en cours',
                            ].join(' et ') +
                                ' seront abandonnées.',
                            style: Charte.texte(15)),
                        plein: 'Annuler',
                        contour: 'Revenir');
                    if (ok != true) return;
                    await widget.base.revenirA(c);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              const SizedBox(width: 10),
              Bouton(texte: 'Fermer', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ]),
      ),
    );
  }
}
