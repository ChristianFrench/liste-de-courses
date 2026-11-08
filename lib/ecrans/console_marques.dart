import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../donnees/journal_catalogue.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'administration_serveur.dart' show TitrePageAdmin;
import 'editeur_catalogue.dart' show EcranEditeurCatalogue;

// Console › Catalogue des marques (08/11/2026, Aristide) : une marque est une déclinaison d'un produit générique
// (« Yaourt nature · Yaos »), enrichie par l'usage des foyers, sans être centralisée. La console surveille :
// - à gauche, toutes les marques du catalogue commun avec leurs produits (renommer, fusionner, retirer) ;
// - en haut, les marques achetées par les foyers et pas encore au catalogue commun (« Intégrer ») ;
// - à droite, « À examiner » : ce que la console trouve seule (marques en double, produit qui porte une marque
//   alors que son générique existe, produits en double), avec la correction proposée ou « Accepter ».
// Chaque geste est noté dans l'historique du catalogue et part au prochain « Généraliser ».

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

class PageCatalogueMarques extends StatefulWidget {
  const PageCatalogueMarques({super.key});

  @override
  State<PageCatalogueMarques> createState() => _PageCatalogueMarquesState();
}

class _PageCatalogueMarquesState extends State<PageCatalogueMarques> {
  final c = CatalogueCommun.instance;
  Brouillon? b;
  late JournalCatalogue journal;
  String recherche = '';

  /// Déclinaisons déposées par les foyers (lues sur le serveur à l'ouverture et sur demande).
  Map<String, Map<String, dynamic>>? foyers;
  bool _lecture = false;

  /// Cas « À examiner » acceptés par l'éditeur (gardés sur ce PC).
  Set<String> acceptes = {};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final x = await c.brouillon();
    final a = Etat.instance.stockageFoyer?.reglage('marques_acceptees') ?? '';
    if (!mounted) return;
    setState(() {
      b = x;
      journal = c.journal();
      acceptes = {for (final k in a.split('\n')) if (k.isNotEmpty) k};
    });
    await _lireFoyers();
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

  /// Enregistre le brouillon et note le geste dans l'historique (« en cours »).
  void _modifie(List<String> lignes) {
    c.enregistrerBrouillon(b!);
    journal.noter(lignes);
    c.enregistrerJournal(journal);
    setState(() {});
  }

  void _accepter(AExaminer x) {
    acceptes.add(x.cle);
    Etat.instance.stockageFoyer?.definirReglage('marques_acceptees', acceptes.join('\n'));
    setState(() {});
  }

  Future<void> _renommer(String m) async {
    final t = await demanderTexte(context, titre: 'Renommer la marque', initial: m, libelle: 'Marque');
    if (t == null || t.trim().isEmpty || t.trim() == m) return;
    final existe = b!.marquesDesProduits().keys.any((x) => x.toLowerCase() == t.trim().toLowerCase() && x != m);
    final n = b!.renommerMarque(m, t.trim());
    if (n > 0) {
      _modifie(['Marque « $m » ${existe ? 'fusionnée dans' : 'renommée'} « ${t.trim()} » (${_pluriel(n, 'produit')})']);
    }
  }

  Future<void> _fusionner(String m) async {
    final autres = [for (final x in b!.marquesDesProduits().keys) if (x != m) x];
    final cible = await choisirDansListe<String>(context, titre: 'Fusionner « $m » dans…', choix: {for (final x in autres) x: x});
    if (cible == null) return;
    final n = b!.renommerMarque(m, cible);
    if (n > 0) _modifie(['Marque « $m » fusionnée dans « $cible » (${_pluriel(n, 'produit')})']);
  }

  Future<void> _retirer(String m, int n) async {
    if (!mounted) return;
    final ok = await modale(
      context,
      titre: 'Retirer la marque',
      oui: 'Retirer',
      contenu: (context, maj) =>
          Text('« $m » ne sera plus proposée pour ${_pluriel(n, 'produit')}. Les listes qui la portent la gardent.', style: Charte.texte(16)),
    );
    if (!ok) return;
    final k = b!.retirerMarque(m);
    if (k > 0) _modifie(['Marque « $m » retirée (${_pluriel(k, 'produit')})']);
  }

  void _integrer() {
    final n = b!.integrerDeclinaisons(foyers ?? const {});
    if (n > 0) _modifie(['${_pluriel(n, 'marque')} des foyers ajoutée(s) aux produits du catalogue']);
    Nav.message(context, n == 0 ? 'Rien de nouveau' : '${_pluriel(n, 'déclinaison')} ajoutée(s) : elles partiront au prochain « Généraliser »');
  }

  @override
  Widget build(BuildContext context) {
    final b = this.b;
    if (b == null) return Center(child: Text('Chargement…', style: Charte.texte(16, couleur: Charte.texteSecondaire)));
    final marques = b.marquesDesProduits();
    final nbRattachements = marques.values.fold(0, (n, l) => n + l.length);
    final nouvelles = b.declinaisonsNouvelles(foyers ?? const {});
    final connues = <String>{for (final l in Etat.instance.marquesType.values) ...l};
    final examen = b.aExaminer(connues: connues, acceptes: acceptes);
    final q = recherche.trim().toLowerCase();
    final visibles = [
      for (final e in marques.entries)
        if (q.isEmpty || e.key.toLowerCase().contains(q) || e.value.any((x) => x.$3.nom.toLowerCase().contains(q))) e
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TitrePageAdmin(
        'Contenu',
        'Catalogue des marques',
        droite: Text('${_pluriel(marques.length, 'marque')} · ${_pluriel(nbRattachements, 'déclinaison')}',
            style: Charte.texte(15, couleur: Charte.texteSecondaire)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
        child: Text(
            'Une marque est une déclinaison d\'un produit : « Yaourt nature · Yaos ». Les foyers les ajoutent par l\'usage ; '
            'ici on surveille. Chaque geste est noté dans l\'historique et part au prochain « Généraliser ».',
            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      ),
      _bandeauFoyers(nouvelles),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _cadre(_listeMarques(visibles))),
            const SizedBox(width: 16),
            SizedBox(width: 420, child: _cadre(_examen(examen))),
          ]),
        ),
      ),
    ]);
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

  Widget _bandeauFoyers(List<(CatRayon, CatSecteur, CatProduit, String, int)> nouvelles) {
    final f = foyers;
    final texte = _lecture
        ? 'Lecture des marques achetées par les foyers…'
        : f == null
            ? 'Marques des foyers non lues (pas de liaison avec le serveur).'
            : nouvelles.isEmpty
                ? '${_pluriel(f.length, 'foyer')} : toutes leurs marques achetées sont au catalogue commun.'
                : '${_pluriel(f.length, 'foyer')} : ${_pluriel(nouvelles.length, 'déclinaison')} achetée(s) pas encore au catalogue commun '
                    '(${nouvelles.take(4).map((x) => '${x.$3.nom} · ${x.$4}').join(', ')}${nouvelles.length > 4 ? '…' : ''}).';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(color: Charte.fondBandeau, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icone(Icons.groups_outlined, size: 26, color: Charte.cadre),
        const SizedBox(width: 12),
        Expanded(child: Text(texte, style: Charte.texte(15))),
        const SizedBox(width: 8),
        SizedBox(
          width: 200,
          child: Bouton(
          key: const ValueKey('marques-relire'),
          texte: 'Relire les foyers',
          icone: Icons.refresh,
          onTap: _lecture ? null : _lireFoyers,
        )),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: Bouton(
          key: const ValueKey('marques-integrer'),
          texte: 'Intégrer',
          plein: true,
          icone: Icons.download_done,
          onTap: nouvelles.isEmpty ? null : _integrer,
        )),
      ]),
    );
  }

  Widget _listeMarques(List<MapEntry<String, List<(CatRayon, CatSecteur, CatProduit)>>> visibles) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TextField(
            key: const ValueKey('marques-recherche'),
            style: Charte.texte(15),
            decoration: const InputDecoration(labelText: 'Rechercher', hintText: 'Une marque ou un produit'),
            onChanged: (v) => setState(() => recherche = v),
          ),
        ),
      ),
      Container(height: 1, color: Charte.separateurZone),
      Expanded(
        child: visibles.isEmpty
            ? Center(child: Text('Aucune marque', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
            : ListView.builder(
                itemCount: visibles.length,
                itemBuilder: (context, i) {
                  final MapEntry(key: m, value: l) = visibles[i];
                  final produits = l.map((x) => x.$3.nom).toList()..sort();
                  return Container(
                    key: ValueKey('marque-console-$m'),
                    padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                    child: Row(children: [
                      SizedBox(width: 200, child: Text(m, style: Charte.texte(16, gras: true))),
                      SizedBox(width: 90, child: Text(_pluriel(l.length, 'produit'), style: Charte.texte(14, couleur: Charte.texteSecondaire))),
                      Expanded(
                        child: Text(produits.join(' · '),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Actions de « $m »',
                        icon: Icone(Icons.more_vert, color: Charte.cadre),
                        onSelected: (a) => switch (a) {
                          'renommer' => _renommer(m),
                          'fusionner' => _fusionner(m),
                          _ => _retirer(m, l.length),
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'renommer', child: Text('Renommer…')),
                          PopupMenuItem(value: 'fusionner', child: Text('Fusionner dans une autre marque…')),
                          PopupMenuItem(value: 'retirer', child: Text('Retirer la marque')),
                        ],
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _examen(List<AExaminer> examen) {
    String type(TypeExamen t) => switch (t) {
          TypeExamen.marques => 'Marques en double',
          TypeExamen.produitDeMarque => 'Produit qui porte une marque',
          TypeExamen.produits => 'Produits en double',
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: Charte.fondBandeau,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text('À examiner (${examen.length})', style: Charte.texte(17, gras: true, couleur: Charte.encreNiveau)),
      ),
      Expanded(
        child: examen.isEmpty
            ? Center(child: Text('Rien à examiner', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
            : ListView.builder(
                itemCount: examen.length,
                itemBuilder: (context, i) {
                  final x = examen[i];
                  return Container(
                    key: ValueKey('examen-${x.cle}'),
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(type(x.type), style: Charte.texte(12.5, gras: true, couleur: Charte.cadre)),
                      const SizedBox(height: 2),
                      Text(x.titre, style: Charte.texte(15)),
                      const SizedBox(height: 2),
                      Text(x.correction, style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
                      const SizedBox(height: 8),
                      Row(children: [
                        SizedBox(
                          width: 130,
                          child: Bouton(
                          texte: 'Corriger',
                          plein: true,
                          hauteur: 34,
                          taille: 14,
                          onTap: () => _modifie([b!.corriger(x)]),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 130, child: Bouton(texte: 'Accepter', hauteur: 34, taille: 14, onTap: () => _accepter(x))),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
