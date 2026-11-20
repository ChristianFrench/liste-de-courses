import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../composants/composants.dart' show Bouton, confirmer, demanderTexte;
import '../composants/icone.dart';
import '../donnees/journal_catalogue.dart';
import '../donnees/recettes.dart';
import '../donnees/recettes_communes.dart';
import '../navigation.dart' show Nav;
import 'console_recettes_edition.dart';
import '../theme.dart';
import 'administration_serveur.dart' show TitrePageAdmin;
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 12/11/2026 (Aristide) : plus de bouton d'import Keep ; les recettes reformulées et leurs illustrations
      // sont livrées avec la console et posées à l'ouverture.
      const TitrePageAdmin('Contenu', 'Catalogue des recettes'),
      if (b != null) _barreVersion(b),
      Expanded(
        child: b == null
            ? Center(child: Text('Chargement…', style: Charte.texte(16, couleur: Charte.texteSecondaire)))
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                // La liste rétrécit avec la fenêtre (40 % de la largeur, de 300 à 440), la fiche prend le reste.
                child: LayoutBuilder(
                  builder: (context, c) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: (c.maxWidth * 0.4).clamp(300.0, 440.0), child: _cadre(_liste(b))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _cadre(choisie == null
                            ? _aucune(b)
                            : FicheRecette(
                                key: ValueKey('${choisie!.id}-${choisie!.modifieeLe?.millisecondsSinceEpoch}'),
                                recette: choisie!,
                                base: b,
                                modifier: () => _modifier(b, choisie!),
                                illustrer: () => _illustrer(b, choisie!),
                                supprimer: () => _supprimer(b, choisie!),
                              ))),
                  ]),
                ),
              ),
      ),
    ]);
  }

  // ------------------------------------------------------------ Versions (20/11/2026)

  String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

  /// Bandeau des versions : où en est le catalogue, et les gestes Nouvelle recette / Valider / Historique /
  /// Généraliser, comme pour le catalogue des produits.
  Widget _barreVersion(BaseRecettes b) {
    final (a, m, r) = RecettesCommunes.changements(b);
    final publie = RecettesCommunes.libellePublie(b);
    final aPublier = RecettesCommunes.aPublier(b);
    final etat = b.publiee.isEmpty
        ? 'Jamais généralisé'
        : 'Version v$publie généralisée le ${_date('${b.publiee['date']}')}';
    final ecarts = [
      if (a.isNotEmpty) _pluriel(a.length, 'ajoutée'),
      if (m.isNotEmpty) _pluriel(m.length, 'modifiée'),
      if (r.isNotEmpty) _pluriel(r.length, 'retirée'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('$etat · ${b.enCours == 0 ? 'rien en cours' : '${_pluriel(b.enCours, 'modification')} en cours'}'
            '${ecarts.isEmpty ? '' : ' · depuis la dernière version : ${ecarts.join(', ')}'}',
            key: const ValueKey('recettes-etat'), style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        Bouton(key: const ValueKey('recettes-nouvelle'), texte: 'Nouvelle recette', icone: Icons.add, hauteur: 36, taille: 14, onTap: () => _modifier(b, null)),
        Bouton(key: const ValueKey('recettes-valider'), texte: 'Valider (${b.enCours})', icone: Icons.check, hauteur: 36, taille: 14,
            onTap: b.enCours == 0 ? null : () => _valider(b)),
        Bouton(key: const ValueKey('recettes-historique'), texte: 'Historique', icone: Icons.history, hauteur: 36, taille: 14, onTap: () => _historique(b)),
        Bouton(
          key: const ValueKey('recettes-generaliser'),
          texte: _publication != null ? 'Envoi… $_publication' : 'Généraliser (v${RecettesCommunes.libelleSuivant(b)})',
          icone: Icons.public,
          plein: true,
          hauteur: 36,
          taille: 14,
          onTap: _publication != null || !aPublier ? null : () => _generaliser(b),
        ),
      ]),
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : JournalCatalogue.nomParDefaut(d);
  }

  /// Avancement de la publication (« 12/496 images »), ou null.
  String? _publication;

  Future<void> _modifier(BaseRecettes b, Recette? r) async {
    final x = await editerRecette(context, recette: r, base: b);
    if (x == null || !mounted) return;
    await b.modifier(r, x);
    if (mounted) setState(() => choisie = x);
  }

  Future<void> _illustrer(BaseRecettes b, Recette r) async {
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp'])]);
    if (f == null || !mounted) return;
    final x = r.copie()..illustration = await b.copierIllustration(r, File(f.path));
    await b.modifier(r, x);
    if (mounted) setState(() => choisie = x);
  }

  Future<void> _supprimer(BaseRecettes b, Recette r) async {
    final ok = await confirmer(context,
        titre: 'Supprimer « ${r.titre} » ?',
        contenu: Text('Elle disparaîtra des applications à la prochaine version généralisée.', style: Charte.texte(15)),
        plein: 'Annuler',
        contour: 'Supprimer');
    if (ok != true || !mounted) return;
    await b.supprimer(r);
    if (mounted) setState(() => choisie = null);
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

  Widget _cadre(Widget enfant) => Container(
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Charte.separateurZone),
        ),
        clipBehavior: Clip.antiAlias,
        child: enfant,
      );

  Widget _aucune(BaseRecettes b) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/recettes/recettes-de-cuisine.png', width: 128, height: 128),
          const SizedBox(height: 12),
          Text(b.recettes.isEmpty ? 'Aucune recette.' : 'Choisissez une recette à gauche.',
              style: Charte.texte(16, couleur: Charte.texteSecondaire)),
        ]),
      );

  Widget _liste(BaseRecettes b) {
    final q = recherche.trim().toLowerCase();
    final groupes = b.parType();
    final lignes = <Widget>[];
    for (final MapEntry(key: type, value: l) in groupes.entries) {
      final visibles = [for (final r in l) if (q.isEmpty || r.titre.toLowerCase().contains(q) || r.ingredients.any((i) => i.toLowerCase().contains(q))) r];
      if (visibles.isEmpty) continue;
      final ouvert = q.isNotEmpty || ouverts.contains(type);
      lignes.add(InkWell(
        key: ValueKey('type-recette-$type'),
        onTap: () => setState(() => ouvert && q.isEmpty ? ouverts.remove(type) : ouverts.add(type)),
        child: Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            Icone(ouvert ? Icons.expand_more : Icons.chevron_right, color: Charte.cadre),
            const SizedBox(width: 4),
            Image.asset(iconeTypeRecette(type), width: 36, height: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(type, style: Charte.texte(16, gras: true, couleur: Charte.encreNiveau))),
            Text('${visibles.length}', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ]),
        ),
      ));
      if (!ouvert) continue;
      for (final r in visibles) {
        final actif = identical(r, choisie);
        lignes.add(InkWell(
          key: ValueKey('recette-${r.id}-$type'),
          onTap: () => setState(() => choisie = r),
          child: Container(
            color: actif ? Charte.fondSelection : null,
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(children: [
              _vignette(b, r, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: Charte.texte(15, gras: actif)),
                  Text(r.ingredients.isEmpty ? 'Texte seul' : '${r.ingredients.length} ingrédients',
                      style: Charte.texte(12.5, couleur: Charte.texteSecondaire)),
                ]),
              ),
            ]),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('recettes-recherche'),
              style: Charte.texte(15),
              decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Une recette ou un ingrédient'),
              onChanged: (v) => setState(() => recherche = v),
            ),
          ),
          Tooltip(
            message: ouverts.length == groupes.length ? 'Tout replier' : 'Tout déplier',
            child: IconButton(
              onPressed: () => setState(() => ouverts.length == groupes.length ? ouverts.clear() : ouverts.addAll(groupes.keys)),
              icon: Icone(ouverts.length == groupes.length ? Icons.unfold_less : Icons.unfold_more, color: Charte.cadre),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('${b.recettes.length} recette${b.recettes.length > 1 ? 's' : ''} · ${groupes.length} type${groupes.length > 1 ? 's' : ''}',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ),
      Container(height: 1, color: Charte.separateurZone),
      Expanded(child: ListView(children: lignes)),
    ]);
  }
}

/// Icône d'un type de recette (images d'Aristide, 11/11/2026) ; « recettes-de-cuisine » pour les autres.
String iconeTypeRecette(String type) {
  final t = type.toLowerCase();
  if (t.startsWith('dessert')) return 'assets/recettes/desserts.png';
  if (t.startsWith('entr')) return 'assets/recettes/entrees.png';
  if (t.contains('accompagnement')) return 'assets/recettes/plats-accompagnement.png';
  if (t.startsWith('plat')) return 'assets/recettes/plats-complets.png';
  if (t.startsWith('sauce')) return 'assets/recettes/sauces.png';
  return 'assets/recettes/recettes-de-cuisine.png';
}

Widget _vignette(BaseRecettes b, Recette r, double taille) {
  final nom = r.illustration ?? (r.photos.isEmpty ? null : r.photos.first);
  final f = nom == null ? null : b.photo(nom);
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: taille,
      height: taille,
      child: f == null || !f.existsSync()
          ? Image.asset(iconeTypeRecette(r.types.isEmpty ? '' : r.types.first), fit: BoxFit.contain)
          : Image.file(f, fit: BoxFit.cover, cacheWidth: (taille * 2).round()),
    ),
  );
}

/// Fiche d'une recette : bandeau (photo, titre, types, nombre d'ingrédients), puis les onglets.
class FicheRecette extends StatelessWidget {
  const FicheRecette({super.key, required this.recette, required this.base, this.modifier, this.illustrer, this.supprimer});
  final Recette recette;
  final BaseRecettes base;

  /// Gestes de la console (20/11/2026) ; absents, la fiche est en lecture seule.
  final VoidCallback? modifier, illustrer, supprimer;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    return DefaultTabController(
      length: 3,
      initialIndex: r.ingredients.isEmpty ? 2 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Charte.fondBandeau,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(children: [
            _vignette(base, r, 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.titre, style: Charte.texte(22, gras: true, couleur: Charte.encreNiveau)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (r.source != null)
                    Container(
                      key: const ValueKey('recette-source'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Charte.cadre, borderRadius: BorderRadius.circular(12)),
                      child: Text('Recette ${r.source}', style: Charte.texte(13, gras: true, couleur: Charte.blanc)),
                    ),
                  for (final t in r.types)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Charte.blanc, borderRadius: BorderRadius.circular(12), border: Border.all(color: Charte.cadre)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset(iconeTypeRecette(t), width: 18, height: 18),
                        const SizedBox(width: 5),
                        Text(t, style: Charte.texte(13, couleur: Charte.cadre)),
                      ]),
                    ),
                  Text(
                      '${r.pour == null ? '' : 'Pour ${r.pour} · '}${r.repereTemps.isEmpty ? '' : '${r.repereTemps} · '}${r.ingredients.length} ingrédient${r.ingredients.length > 1 ? 's' : ''} · ${r.photos.length} photo${r.photos.length > 1 ? 's' : ''}'
                      '${r.modifieeLe == null ? '' : ' · modifiée le ${r.modifieeLe!.day.toString().padLeft(2, '0')}/${r.modifieeLe!.month.toString().padLeft(2, '0')}/${r.modifieeLe!.year}'}',
                      style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ]),
                // Critères de choix (20/11/2026) : une pastille par valeur, groupées par critère.
                if (r.regimes.isNotEmpty || r.saisons.isNotEmpty || r.cout != null || r.cuissons.isNotEmpty || r.occasions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(key: const ValueKey('recette-criteres'), spacing: 6, runSpacing: 4, children: [
                    for (final x in [
                      ...r.regimes,
                      if (r.saisons.isNotEmpty) r.repereSaisons,
                      if (r.cout != null) r.cout!,
                      ...r.cuissons,
                      ...r.occasions,
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Charte.clair(Charte.cadre, 0.85), borderRadius: BorderRadius.circular(10)),
                        child: Text(x, style: Charte.texte(12.5, couleur: Charte.encreNiveau)),
                      ),
                  ]),
                ],
              ]),
            ),
            if (modifier != null || illustrer != null || supprimer != null) ...[
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                if (modifier != null)
                  Bouton(key: const ValueKey('recette-modifier'), texte: 'Modifier', icone: Icons.edit_outlined, hauteur: 34, taille: 14, onTap: modifier),
                if (illustrer != null) ...[
                  const SizedBox(height: 6),
                  Bouton(key: const ValueKey('recette-illustrer'), texte: 'Illustration', icone: Icons.image_outlined, hauteur: 34, taille: 14, onTap: illustrer),
                ],
                if (supprimer != null) ...[
                  const SizedBox(height: 6),
                  Bouton(key: const ValueKey('recette-supprimer'), texte: 'Supprimer', icone: Icons.delete_outline, hauteur: 34, taille: 14, onTap: supprimer),
                ],
              ]),
            ],
          ]),
        ),
        TabBar(
          labelStyle: Charte.texte(15, gras: true),
          unselectedLabelStyle: Charte.texte(15),
          labelColor: Charte.encreNiveau,
          indicatorColor: Charte.cadre,
          tabs: const [Tab(text: 'Photos'), Tab(text: 'Ingrédients'), Tab(text: 'Recette')],
        ),
        Container(height: 1, color: Charte.separateurZone),
        Expanded(
          child: TabBarView(children: [
            _photos(),
            _ingredients(),
            _recette(),
          ]),
        ),
      ]),
    );
  }

  Widget _photos() {
    final fichiers = [
      for (final p in [if (recette.illustration != null) recette.illustration!, ...recette.photos]) base.photo(p)
    ].where((f) => f.existsSync()).toList();
    if (fichiers.isEmpty) return Center(child: Text('Pas de photo', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final f in fichiers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(f, fit: BoxFit.contain)),
            ),
          ),
        ),
    ]);
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
    if (r.detail.isNotEmpty) {
      // Recette normalisée : quantité · nom · précision, en colonnes.
      return ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 22), children: [
        for (final i in r.detail)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: SelectableText(i.quantite.isEmpty ? '—' : i.quantite, style: Charte.texte(16, couleur: Charte.texteSecondaire))),
              Expanded(
                child: SelectableText.rich(TextSpan(children: [
                  TextSpan(text: i.nom, style: Charte.texte(16, gras: true)),
                  if (i.precision.isNotEmpty) TextSpan(text: '  ${i.precision}', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ])),
              ),
            ]),
          ),
      ]);
    }
    if (r.ingredients.isEmpty) {
      return Center(child: Text(r.memo ? 'Mémo sans ingrédients : voir l\'onglet Recette.' : 'Pas de liste d\'ingrédients : tout est dans l\'onglet Recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 22), children: [
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
