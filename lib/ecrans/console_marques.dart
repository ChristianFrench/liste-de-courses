import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../donnees/moderation.dart' show Moderation;
import '../donnees/modele.dart';
import '../donnees/univers.dart' show autresRayons;
import '../navigation.dart';
import '../theme.dart';
import 'console_catalogue.dart' show alertesCatalogueCommun, gesteCatalogueCommun, menuCatalogueCommun, signeDomaine;
import 'console_commun.dart';
import 'editeur_catalogue.dart' show EcranEditeurCatalogue, EtatEditeurCatalogue;

// Console › Catalogue des marques (08/11/2026, Aristide) : une marque est une déclinaison d'un produit générique
// (« Yaourt nature · Yaos »), enrichie par l'usage des foyers, sans être centralisée. La console surveille.
// 21/11/2026 (Aristide) : même présentation que le catalogue des produits ([EnTeteConsole], [BarreConsole]) ; la
// hiérarchie est celle des domaines, et dans chaque domaine ses marques (dépliables : les produits de la marque).
// Clic droit sur une marque : renommer, fusionner, retirer ; double-clic : renommer. Les marques achetées par les
// foyers (« Intégrer ») et « À examiner » s'ouvrent en fenêtre, depuis les boutons de la barre ou le menu ☰.
// Chaque geste est noté dans l'historique du catalogue commun et part au prochain « Généraliser ».

String _pluriel(int n, String mot) => plurielConsole(n, mot);

/// La page de la console : l'éditeur du catalogue commun, vu par ses marques.
class PageCatalogueMarques extends StatelessWidget {
  const PageCatalogueMarques({super.key});

  @override
  Widget build(BuildContext context) => const EcranEditeurCatalogue(actionsAPart: true, large: true, marques: true);
}

/// Une ligne du cadre : l'en-tête d'un domaine (sur sa première marque), une marque, ou un produit d'une marque.
class _Ligne {
  _Ligne(this.domaine, this.marque, {this.produit, this.entete = false});
  final String domaine, marque;
  final (CatRayon, CatSecteur, CatProduit)? produit;
  final bool entete;
  String get cle => '$domaine|$marque';
}

class CatalogueMarquesLarge extends StatefulWidget {
  const CatalogueMarquesLarge({super.key, required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<CatalogueMarquesLarge> createState() => _CatalogueMarquesLargeState();
}

class _CatalogueMarquesLargeState extends State<CatalogueMarquesLarge> {
  EtatEditeurCatalogue get e => widget.editeur;
  Brouillon get b => e.b!;
  final c = CatalogueCommun.instance;

  /// Marques dépliées (« domaine|marque ») ; marque choisie.
  final ouvertes = <String>{};
  String? choisie;

  // Recherche au sens strict, comme pour les produits : elle montre une correspondance à la fois.
  String recherche = '';
  List<String> _resultats = const [];
  int _indice = 0;
  final _defilement = ScrollController();

  /// Déclinaisons déposées par les foyers (lues sur le serveur à l'ouverture et sur demande).
  Map<String, Map<String, dynamic>>? foyers;
  bool _lecture = false;

  /// Cas « À examiner » acceptés par l'éditeur (gardés sur ce PC).
  Set<String> acceptes = {};

  @override
  void initState() {
    super.initState();
    final a = Etat.instance.stockageFoyer?.reglage('marques_acceptees') ?? '';
    acceptes = {for (final k in a.split('\n')) if (k.isNotEmpty) k};
    _lireFoyers();
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _lireFoyers() async {
    // Dans les tests, pas de serveur (comme pour le catalogue des produits).
    if (!EcranEditeurCatalogue.actualiserAuServeur) return;
    setState(() => _lecture = true);
    final l = await c.lireDeclinaisons();
    if (!mounted) return;
    setState(() {
      _lecture = false;
      if (l != null) foyers = l;
    });
    if (l == null) Nav.message(context, 'Pas de liaison avec le serveur : les marques des foyers ne sont pas lues.');
  }

  void _modifie(List<String> lignes) {
    e.modifieAvec(lignes);
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ données

  /// Domaines, dans l'ordre du catalogue, avec leurs marques (par ordre alphabétique) et leurs produits.
  Map<String, Map<String, List<(CatRayon, CatSecteur, CatProduit)>>> _parDomaine() {
    final marques = b.marquesDesProduits();
    final m = <String, Map<String, List<(CatRayon, CatSecteur, CatProduit)>>>{
      for (final u in [...b.univers.keys, autresRayons]) u: {},
    };
    final noms = marques.keys.toList()..sort((a, c) => a.toLowerCase().compareTo(c.toLowerCase()));
    for (final nom in noms) {
      for (final x in marques[nom]!) {
        final u = b.universDe(x.$1.nom);
        m.putIfAbsent(u, () => {}).putIfAbsent(nom, () => []).add(x);
      }
    }
    m.removeWhere((_, v) => v.isEmpty);
    for (final v in m.values) {
      for (final l in v.values) {
        l.sort((a, c) => a.$3.nom.toLowerCase().compareTo(c.$3.nom.toLowerCase()));
      }
    }
    return m;
  }

  List<_Ligne> _lignes(Map<String, Map<String, List<(CatRayon, CatSecteur, CatProduit)>>> d) {
    final l = <_Ligne>[];
    for (final MapEntry(key: u, value: marques) in d.entries) {
      var premiere = true;
      for (final MapEntry(key: m, value: produits) in marques.entries) {
        l.add(_Ligne(u, m, entete: premiere));
        premiere = false;
        if (!ouvertes.contains('$u|$m')) continue;
        for (final p in produits) {
          l.add(_Ligne(u, m, produit: p));
        }
      }
    }
    return l;
  }

  static String _plat(String t) => Moderation.sansAccents(t.toLowerCase()).replaceAll('œ', 'oe');

  void _chercher(String v) {
    recherche = v;
    final q = _plat(v.trim());
    final d = _parDomaine();
    _resultats = q.length < 2
        ? const []
        : [
            for (final MapEntry(key: u, value: marques) in d.entries)
              for (final MapEntry(key: m, value: produits) in marques.entries)
                if (_plat(m).contains(q) || produits.any((x) => _plat(x.$3.nom).contains(q))) '$u|$m',
          ];
    _indice = 0;
    if (_resultats.isEmpty) {
      setState(() {});
    } else {
      _allerA(0);
    }
  }

  void _allerA(int i) {
    if (_resultats.isEmpty) return;
    _indice = i % _resultats.length;
    final cle = _resultats[_indice];
    final q = _plat(recherche.trim());
    setState(() {
      choisie = cle;
      // Trouvée par un de ses produits : la marque se déplie pour le montrer.
      if (!_plat(cle.split('|').last).contains(q)) ouvertes.add(cle);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      var y = 0.0;
      for (final l in _lignes(_parDomaine())) {
        if (l.produit == null && l.cle == cle) break;
        y += (l.entete ? BandeauDomaineConsole.hauteur : 0) + RangeeConsole.hauteurDe(l.produit == null ? 1 : 3);
      }
      final pos = _defilement.position;
      _defilement.jumpTo((y - pos.viewportDimension / 3).clamp(0.0, pos.maxScrollExtent));
    });
  }

  // ------------------------------------------------------------ gestes

  Future<void> _renommer(String m) async {
    final t = await demanderTexte(context, titre: 'Renommer la marque', initial: m, libelle: 'Marque');
    if (t == null || t.trim().isEmpty || t.trim() == m) return;
    final existe = b.marquesDesProduits().keys.any((x) => x.toLowerCase() == t.trim().toLowerCase() && x != m);
    final n = b.renommerMarque(m, t.trim());
    if (n > 0) _modifie(['Marque « $m » ${existe ? 'fusionnée dans' : 'renommée'} « ${t.trim()} » (${_pluriel(n, 'produit')})']);
  }

  Future<void> _fusionner(String m) async {
    final autres = [for (final x in b.marquesDesProduits().keys) if (x != m) x]..sort((a, c) => a.toLowerCase().compareTo(c.toLowerCase()));
    final cible = await choisirDansListe<String>(context, titre: 'Fusionner « $m » dans…', choix: {for (final x in autres) x: x});
    if (cible == null) return;
    final n = b.renommerMarque(m, cible);
    if (n > 0) _modifie(['Marque « $m » fusionnée dans « $cible » (${_pluriel(n, 'produit')})']);
  }

  Future<void> _retirer(String m) async {
    final n = b.marquesDesProduits()[m]?.length ?? 0;
    final ok = await modale(
      context,
      titre: 'Retirer la marque',
      oui: 'Retirer',
      contenu: (context, maj) =>
          Text('« $m » ne sera plus proposée pour ${_pluriel(n, 'produit')}. Les listes qui la portent la gardent.', style: Charte.texte(16)),
    );
    if (!ok) return;
    final k = b.retirerMarque(m);
    if (k > 0) _modifie(['Marque « $m » retirée (${_pluriel(k, 'produit')})']);
  }

  Future<void> _menuMarque(Offset ou, String m) async {
    final v = await menuConsole(context, ou, const [
      EntreeMenuConsole('renommer', Icons.edit_outlined, 'Renommer…'),
      EntreeMenuConsole('fusionner', Icons.merge, 'Fusionner dans une autre marque…'),
      null,
      EntreeMenuConsole('retirer', Icons.delete_outline, 'Retirer la marque'),
    ]);
    if (!mounted) return;
    switch (v) {
      case 'renommer':
        await _renommer(m);
      case 'fusionner':
        await _fusionner(m);
      case 'retirer':
        await _retirer(m);
    }
  }

  Future<void> _menuGeneral(String v) async {
    switch (v) {
      case 'foyers':
        await _fenetreFoyers();
      case 'examen':
        await _fenetreExamen();
      default:
        await gesteCatalogueCommun(context, e, v);
    }
    if (mounted) setState(() {});
  }

  List<AExaminer> _examen() {
    final connues = <String>{for (final l in Etat.instance.marquesType.values) ...l};
    return b.aExaminer(connues: connues, acceptes: acceptes);
  }

  List<(CatRayon, CatSecteur, CatProduit, String, int)> get _nouvelles => b.declinaisonsNouvelles(foyers ?? const {});

  // ------------------------------------------------------------ fenêtres

  Future<void> _fenetreFoyers() => showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, maj) {
          final f = foyers, nouvelles = _nouvelles;
          final texte = _lecture
              ? 'Lecture des marques achetées par les foyers…'
              : f == null
                  ? 'Marques des foyers non lues (pas de liaison avec le serveur).'
                  : nouvelles.isEmpty
                      ? '${_pluriel(f.length, 'foyer')} : toutes leurs marques achetées sont au catalogue commun.'
                      : '${_pluriel(f.length, 'foyer')} : ${_pluriel(nouvelles.length, 'déclinaison')} achetée(s) pas encore au catalogue commun.';
          return Dialog(
            backgroundColor: Charte.blanc,
            child: SizedBox(
              width: 760,
              height: 560,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Text('Marques achetées par les foyers', style: Charte.texte(19, gras: true)),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 10), child: Text(texte, style: Charte.texte(15))),
                Container(height: 1, color: Charte.separateurZone),
                Expanded(
                  child: ListView(children: [
                    for (final x in nouvelles)
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text('${x.$3.nom} · ${x.$4}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14.5))),
                          Expanded(
                            flex: 3,
                            child: Text('${x.$1.nom} › ${x.$2.nom}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
                          ),
                          Text(_pluriel(x.$5, 'foyer'), style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
                        ]),
                      ),
                  ]),
                ),
                Container(height: 1, color: Charte.separateurZone),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    BoutonConsole(
                      key: const ValueKey('marques-relire'),
                      texte: 'Relire les foyers',
                      icone: Icons.refresh,
                      onTap: _lecture
                          ? null
                          : () async {
                              await _lireFoyers();
                              maj(() {});
                            },
                    ),
                    const SizedBox(width: 10),
                    BoutonConsole(
                      key: const ValueKey('marques-integrer'),
                      texte: 'Intégrer',
                      icone: Icons.download_done,
                      plein: true,
                      onTap: nouvelles.isEmpty
                          ? null
                          : () {
                              final n = b.integrerDeclinaisons(foyers ?? const {});
                              if (n > 0) _modifie(['${_pluriel(n, 'marque')} des foyers ajoutée(s) aux produits du catalogue']);
                              maj(() {});
                            },
                    ),
                    const SizedBox(width: 10),
                    BoutonConsole(texte: 'Fermer', onTap: () => Navigator.of(ctx).pop()),
                  ]),
                ),
              ]),
            ),
          );
        }),
      );

  Future<void> _fenetreExamen() => showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, maj) {
          final examen = _examen();
          String type(TypeExamen t) => switch (t) {
                TypeExamen.marques => 'Marques en double',
                TypeExamen.produitDeMarque => 'Produit qui porte une marque',
                TypeExamen.produits => 'Produits en double',
              };
          return Dialog(
            backgroundColor: Charte.blanc,
            child: SizedBox(
              width: 820,
              height: 640,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Text('À examiner (${examen.length})', style: Charte.texte(19, gras: true)),
                ),
                Container(height: 1, color: Charte.separateurZone),
                Expanded(
                  child: examen.isEmpty
                      ? Center(child: Text('Rien à examiner', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
                      : ListView(children: [
                          for (final x in examen)
                            Container(
                              key: ValueKey('examen-${x.cle}'),
                              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(type(x.type), style: Charte.texte(12.5, gras: true, couleur: Charte.cadre)),
                                    Text(x.titre, style: Charte.texte(15)),
                                    Text(x.correction, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
                                  ]),
                                ),
                                const SizedBox(width: 10),
                                BoutonConsole(
                                  texte: 'Corriger',
                                  plein: true,
                                  onTap: () {
                                    _modifie([b.corriger(x)]);
                                    maj(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                BoutonConsole(
                                  texte: 'Accepter',
                                  onTap: () {
                                    acceptes.add(x.cle);
                                    Etat.instance.stockageFoyer?.definirReglage('marques_acceptees', acceptes.join('\n'));
                                    setState(() {});
                                    maj(() {});
                                  },
                                ),
                              ]),
                            ),
                        ]),
                ),
                Container(height: 1, color: Charte.separateurZone),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(alignment: Alignment.centerRight, child: BoutonConsole(texte: 'Fermer', onTap: () => Navigator.of(ctx).pop())),
                ),
              ]),
            ),
          );
        }),
      );

  // ------------------------------------------------------------ affichage

  Widget _titre(int nbMarques, int nbDeclinaisons, int nbDomaines, int aExaminer) {
    final p = e.publie;
    final numero = e.numeroPublie, libelle = e.libellePublie;
    final date = p?['date'] as String?;
    final nouvelles = _nouvelles.length;
    return EnTeteConsole(
      signe: Icone(Icons.sell_outlined, size: 32, color: Charte.cadre),
      titre: 'Catalogue des marques',
      chiffres: [
        numero == 0 ? 'Aucune version publiée' : 'Version publiée v$libelle${date == null ? '' : ' du ${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}'}',
        _pluriel(nbDomaines, 'domaine'),
        _pluriel(nbMarques, 'marque'),
        _pluriel(nbDeclinaisons, 'déclinaison'),
        if (nouvelles > 0) '$nouvelles achetée${nouvelles > 1 ? 's' : ''} par les foyers à intégrer',
      ],
      pastilles: [
        PastilleConsole('en-cours', 'en cours', '${e.enCours}', fort: e.enCours > 0),
        PastilleConsole('etapes', 'étapes', '${e.journal.etapes.length}'),
        PastilleConsole('a-generaliser', 'à généraliser', b.modifications == 0 ? 'rien' : '${b.modifications}'),
      ],
      bouton: BoutonConsole(
        key: const ValueKey('generaliser'),
        texte: e.enPublication ? 'Envoi…' : 'Généraliser…',
        icone: Icons.public,
        plein: true,
        onTap: e.enPublication || b.modifications == 0 || e.enCours > 0 ? null : () => _menuGeneral('generaliser'),
      ),
      menu: menuCatalogueCommun(e, extras: [
        EntreeMenuConsole('foyers', Icons.groups_outlined, 'Marques des foyers…${nouvelles > 0 ? ' ($nouvelles)' : ''}'),
        EntreeMenuConsole('examen', Icons.rule, 'À examiner… ($aExaminer)'),
      ]),
      onMenu: _menuGeneral,
      alertes: alertesCatalogueCommun(e),
    );
  }

  Widget _rangee(_Ligne l, Map<String, List<(CatRayon, CatSecteur, CatProduit)>> marquesDuDomaine) {
    final trouvee = _resultats.isNotEmpty && _resultats[_indice] == l.cle && l.produit == null;
    final Widget r;
    if (l.produit case final p?) {
      r = RangeeConsole(
        key: ValueKey('marque-produit-${l.cle}/${p.$3.nom}'),
        niveau: 3,
        libelle: p.$3.nom,
        colonnes: [('${p.$1.nom} › ${p.$2.nom}', 4), (p.$3.marques.where((x) => x != l.marque).take(4).join(', '), 3)],
        onClicDroit: (o) => _menuMarque(o, l.marque),
      );
    } else {
      final ouvert = ouvertes.contains(l.cle);
      final n = marquesDuDomaine[l.marque]!.length;
      r = RangeeConsole(
        key: ValueKey('marque-console-${l.cle}'),
        niveau: 1,
        ouvert: ouvert,
        libelle: l.marque,
        compte: _pluriel(n, 'produit'),
        choisie: choisie == l.cle,
        trouvee: trouvee,
        onTap: () => setState(() {
          choisie = l.cle;
          ouvert ? ouvertes.remove(l.cle) : ouvertes.add(l.cle);
        }),
        onDoubleTap: () => _renommer(l.marque),
        onClicDroit: (o) {
          setState(() => choisie = l.cle);
          _menuMarque(o, l.marque);
        },
      );
    }
    if (!l.entete) return r;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      BandeauDomaineConsole(
        key: ValueKey('marques-domaine-${l.domaine}'),
        signe: signeDomaine(l.domaine, 32),
        nom: l.domaine,
        compte: _pluriel(marquesDuDomaine.length, 'marque'),
      ),
      r,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (e.b == null) return Center(child: Text('Chargement…', style: Charte.texte(16, couleur: Charte.texteSecondaire)));
    final d = _parDomaine();
    final marques = b.marquesDesProduits();
    final nbDeclinaisons = marques.values.fold(0, (n, l) => n + l.length);
    final examen = _examen();
    final lignes = _lignes(d);
    final toutes = {for (final MapEntry(key: u, value: m) in d.entries) for (final x in m.keys) '$u|$x'};
    final toutOuvert = toutes.isNotEmpty && ouvertes.containsAll(toutes);
    return Scaffold(
      backgroundColor: Charte.fond,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _titre(marques.length, nbDeclinaisons, d.length, examen.length),
        Container(height: 1, color: Charte.separateurZone),
        BarreConsole(
          aideRecherche: 'Une marque ou un produit',
          recherche: recherche,
          onChercher: _chercher,
          onSuivant: () => _allerA(_indice + 1),
          onPrecedent: () => _allerA(_indice - 1 + _resultats.length),
          trouves: _resultats.length,
          indice: _indice,
          toutOuvert: toutOuvert,
          onTout: () => setState(() => toutOuvert ? ouvertes.clear() : ouvertes.addAll(toutes)),
          boutons: [
            BoutonConsole(
              key: const ValueKey('marques-foyers'),
              texte: 'Marques des foyers${_nouvelles.isEmpty ? '' : ' (${_nouvelles.length})'}…',
              icone: Icons.groups_outlined,
              onTap: _fenetreFoyers,
            ),
            BoutonConsole(
              key: const ValueKey('marques-examen'),
              texte: 'À examiner (${examen.length})…',
              icone: Icons.rule,
              onTap: _fenetreExamen,
            ),
          ],
          aide: 'Clic : déplier la marque (ses produits) · Clic droit : renommer, fusionner, retirer · Double-clic : renommer',
        ),
        Expanded(
          child: CadreConsole(
            child: lignes.isEmpty
                ? Center(child: Text('Aucune marque', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
                : ListView.builder(
                    key: const ValueKey('marques-cadre'),
                    controller: _defilement,
                    itemCount: lignes.length,
                    itemBuilder: (_, i) => _rangee(lignes[i], d[lignes[i].domaine]!),
                  ),
          ),
        ),
      ]),
    );
  }
}
