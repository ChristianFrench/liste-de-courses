import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'magasin.dart';

// Écrans de travail (barre d'onglets masquée) : préliste (2), construction (3) et son volet
// « Promotion visée » (4), liste complète (7), courses par secteur (8) et son dialogue (9).

/// Écran 2 — Nouvelle liste (préliste).
class EcranPreliste extends StatefulWidget {
  const EcranPreliste({super.key});

  @override
  State<EcranPreliste> createState() => _EcranPrelisteState();
}

class _EcranPrelisteState extends State<EcranPreliste> {
  final etat = Etat.instance;
  late String magasinId;
  final Set<String> retenus = {};

  @override
  void initState() {
    super.initState();
    magasinId = etat.magasins.first.id;
    _initialiser();
  }

  void _initialiser() => retenus
    ..clear()
    ..addAll(etat.preliste(magasinId).map((g) => g.produitId));

  void _creer(bool garder) {
    final lignes = <LigneListe>[
      if (garder)
        for (final id in retenus)
          LigneListe(
            produitId: id,
            packagingId: (etat.produit(id)?.packagingIds.isNotEmpty ?? false) ? etat.produit(id)!.packagingIds.first : null,
          ),
    ];
    final l = etat.creerListe(magasinId, lignes);
    Nav.remplacerTravail(EcranConstruction(listeId: l.id));
  }

  @override
  Widget build(BuildContext context) {
    final freq = etat.frequencesDu(magasinId);
    final groupes = <String, List<String>>{};
    final nonPlaces = <String>[];
    final ids = freq.keys.where((id) => etat.produit(id) != null).toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    for (final id in ids) {
      final r = etat.rayonDe(magasinId, id);
      if (r == null) {
        nonPlaces.add(id);
      } else {
        groupes.putIfAbsent(r.id, () => []).add(id);
      }
    }
    final rayons = etat.rayonsDu(magasinId).where((r) => groupes.containsKey(r.id)).toList();

    return PageBase(
      entete: const EnTeteTravail(titre: 'Nouvelle liste'),
      haut: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(
            children: [
              Text('Magasin', style: Charte.texte(15)),
              const SizedBox(width: 12),
              Expanded(
                child: ChoixDeroulant<String>(
                  valeur: magasinId,
                  choix: {for (final m in etat.magasins) m.id: m.nom},
                  onChange: (v) => setState(() {
                    magasinId = v;
                    _initialiser();
                  }),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Préliste', style: Charte.texte(14, gras: true)),
            TextSpan(text: ' d\'après vos dernières courses dans ce magasin', style: Charte.texte(14)),
          ])),
        ),
        Container(height: 1, color: Charte.separateurZone),
      ],
      corps: freq.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Pas encore de courses dans ce magasin : la préliste est vide. Commencez par une liste vide.',
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            )
          : ListView(
              children: [
                for (final r in rayons) ...[
                  _titre(r.nom),
                  for (final id in groupes[r.id]!) _ligne(id, freq[id]!),
                ],
                if (nonPlaces.isNotEmpty) ...[
                  _titre('Non placé'),
                  for (final id in nonPlaces) _ligne(id, freq[id]!),
                ],
              ],
            ),
      bas: [
        BarreAction(boutons: [
          Bouton(texte: 'Liste vide', onTap: () => _creer(false)),
          Bouton(
            texte: retenus.isEmpty ? 'Compléter' : 'Garder ${retenus.length} et compléter',
            plein: true,
            taille: 16,
            onTap: () => _creer(true),
          ),
        ]),
      ],
    );
  }

  Widget _titre(String nom) => Container(
        height: 30,
        color: Charte.fondBandeau,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Text(nom.toUpperCase(), style: Charte.texte(12, couleur: Charte.texteSecondaire, espacement: 0.8)),
      );

  Widget _ligne(String id, int n) {
    final p = etat.produit(id)!;
    final coche = retenus.contains(id);
    return LigneChoix(
      nom: p.nom,
      complement: etat.complement(null, p),
      coche: coche,
      quantite: 1,
      afficherQuantite: false,
      droite: Text('$n/${etat.prelisteSur}', style: Charte.texte(12, couleur: Charte.texteSecondaire)),
      onTap: () => setState(() => coche ? retenus.remove(id) : retenus.add(id)),
      onQuantite: (_) {},
    );
  }
}

/// Écran 3 — Construction par secteur. Chaque action est enregistrée ; quitter ne perd rien.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  @override
  State<EcranConstruction> createState() => _EcranConstructionState();
}

class _EcranConstructionState extends State<EcranConstruction> {
  final etat = Etat.instance;
  int rayonIndex = 0;
  int secteurIndex = 0;
  static const int seuilHabituel = 5;

  Liste? get liste => etat.liste(widget.listeId);

  @override
  void initState() {
    super.initState();
    final l = liste;
    if (l == null) return;
    // Reprise : rayon et secteur où l'on s'était arrêté
    final rayons = etat.rayonsDu(l.magasinId);
    final ri = rayons.indexWhere((r) => r.id == l.repriseRayonId);
    if (ri >= 0) {
      rayonIndex = ri;
      final si = etat.secteursDu(rayons[ri].id).indexWhere((s) => s.id == l.repriseSecteurId);
      if (si >= 0) secteurIndex = si;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _noterPosition());
  }

  void _noterPosition() {
    final l = liste;
    if (l == null || l.statut != StatutListe.enConstruction) return;
    final rayons = etat.rayonsDu(l.magasinId);
    final r = rayons.isEmpty ? null : rayons[rayonIndex.clamp(0, rayons.length - 1)];
    final secteurs = r == null ? <Secteur>[] : etat.secteursDu(r.id);
    final s = secteurs.isEmpty ? null : secteurs[secteurIndex.clamp(0, secteurs.length - 1)];
    etat.positionConstruction(l, r?.id, s?.id);
  }

  void _allerA(Liste l, Secteur s) {
    final rayons = etat.rayonsDu(l.magasinId);
    final ri = rayons.indexWhere((r) => r.id == s.rayonId);
    if (ri < 0) return;
    setState(() {
      rayonIndex = ri;
      secteurIndex = etat.secteursDu(rayons[ri].id).indexWhere((x) => x.id == s.id).clamp(0, 999);
    });
    _noterPosition();
  }

  Future<void> _rechercher(Liste l) async {
    final id = await showDialog<String>(context: context, builder: (_) => _DialogueRecherche(magasinId: l.magasinId));
    if (id == null || !mounted) return;
    etat.ajouterLigne(l, id);
    final s = etat.secteurDe(l.magasinId, id);
    if (s != null) {
      _allerA(l, s);
    } else {
      Nav.message(context, 'Ajouté à la liste (produit non placé dans ce magasin)');
    }
  }

  Future<void> _produitAbsent(Liste l, Secteur? s) async {
    final nom = await demanderTexte(context, titre: 'Nouveau produit', aide: 'Nom générique (ex. : Riz)');
    if (nom == null || nom.isEmpty || !mounted) return;
    final p = etat.creerProduit(nom);
    if (s != null) etat.placer(l.magasinId, p.id, s.id);
    Nav.travail(EcranFicheProduit(produitId: p.id, listeId: l.id));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = liste;
        if (l == null) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Liste'),
            corps: Center(child: Text("Cette liste n'existe plus.", style: Charte.texte(16))),
          );
        }
        final magasin = etat.magasin(l.magasinId);
        final rayons = etat.rayonsDu(l.magasinId);
        final barre = BarreAction(boutons: [
          Bouton(texte: 'Ma liste · ${l.lignes.length}', onTap: () => Nav.travail(EcranListeComplete(listeId: l.id))),
          Bouton(
            texte: 'Liste prête',
            plein: true,
            onTap: () {
              etat.listePrete(l);
              Nav.i.retourOnglets(Nav.listes, Nav.preparer);
              Nav.message(context, 'Liste prête : elle apparaît dans Listes › Courses');
            },
          ),
        ]);
        final entete = EnTeteTravail(
          titre: 'Préparer · ${magasin?.nom ?? ''}',
          sousTitre: 'Enregistré',
          action: BoutonIcone(icone: Icons.search, libelle: 'Rechercher dans le magasin', onTap: () => _rechercher(l)),
        );
        if (rayons.isEmpty) {
          return PageBase(
            entete: entete,
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Ce magasin n'a pas encore de rayons : décrivez-les dans l'onglet Magasin.",
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
            bas: [barre],
          );
        }
        if (rayonIndex >= rayons.length) rayonIndex = 0;
        final rayon = rayons[rayonIndex];
        final secteurs = etat.secteursDu(rayon.id);
        if (secteurIndex >= secteurs.length) secteurIndex = 0;
        final secteur = secteurs.isEmpty ? null : secteurs[secteurIndex];
        final produits = secteur == null ? <Produit>[] : etat.produitsDu(l.magasinId, secteur.id);
        produits.sort((a, b) {
          final ca = etat.ligne(l, a.id) != null ? 0 : 1;
          final cb = etat.ligne(l, b.id) != null ? 0 : 1;
          return ca != cb ? ca.compareTo(cb) : b.nbUtilisations.compareTo(a.nbUtilisations);
        });

        return PageBase(
          entete: entete,
          haut: [
            BandeauPuces(
              puces: [for (final r in rayons) Puce(r.nom, compteur: etat.nbDansRayon(l, r.id))],
              selection: rayonIndex,
              onChoix: (i) {
                setState(() {
                  rayonIndex = i;
                  secteurIndex = 0;
                });
                _noterPosition();
              },
            ),
            BandeauPuces(
              pastille: false,
              fond: Charte.fondBandeau,
              puces: [for (final s in secteurs) Puce(s.nom, compteur: etat.nbDansSecteur(l, s.id))],
              selection: secteurIndex,
              onChoix: (i) {
                setState(() => secteurIndex = i);
                _noterPosition();
              },
            ),
          ],
          corps: ListView(
            children: [
              for (final p in produits) _ligne(l, p),
              InkWell(
                onTap: () => _produitAbsent(l, secteur),
                child: Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                  child: Text('+ Produit absent de ce secteur', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              ),
            ],
          ),
          bas: [barre],
        );
      },
    );
  }

  Widget _ligne(Liste l, Produit p) {
    final g = etat.ligne(l, p.id);
    return LigneChoix(
      key: ValueKey(p.id),
      nom: p.nom,
      complement: etat.complement(g, p),
      coche: g != null,
      quantite: g?.quantite ?? 1,
      codePromo: etat.typePromotion(g?.promotion?.type)?.code ?? (g?.promotion != null ? '?' : null),
      onPromo: g == null ? null : () => ouvrirFeuillePromotion(context, l, g),
      habituel: p.nbUtilisations >= seuilHabituel,
      alerte: g == null ? null : etat.quantiteInsuffisante(g),
      onTap: () => etat.basculer(l, p.id),
      onQuantite: (q) => etat.quantite(l, p.id, q),
    );
  }
}

class _DialogueRecherche extends StatefulWidget {
  const _DialogueRecherche({required this.magasinId});
  final String magasinId;

  @override
  State<_DialogueRecherche> createState() => _DialogueRechercheState();
}

class _DialogueRechercheState extends State<_DialogueRecherche> {
  String filtre = '';

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final f = filtre.toLowerCase();
    final trouves = etat.produits.where((p) => f.isEmpty || p.nom.toLowerCase().contains(f)).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    return AlertDialog(
      backgroundColor: Charte.fond,
      insetPadding: const EdgeInsets.all(16),
      title: Text('Rechercher dans le magasin', style: Charte.texte(18, gras: true)),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: Charte.texte(16),
              decoration: const InputDecoration(hintText: 'Nom du produit'),
              onChanged: (v) => setState(() => filtre = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in trouves)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(p.id),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.nom, style: Charte.texte(16))),
                            Text(_ou(etat, p), style: Charte.texte(12, couleur: Charte.texteSecondaire)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Fermer', style: Charte.texte(16))),
      ],
    );
  }

  String _ou(Etat etat, Produit p) {
    final s = etat.secteurDe(widget.magasinId, p.id);
    return s == null ? 'non placé' : '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}';
  }
}

// ---------------------------------------------------------------- Écran 4 : volet « Promotion visée »

Future<void> ouvrirFeuillePromotion(BuildContext context, Liste l, LigneListe g) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Charte.voile,
    backgroundColor: Charte.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: Charte.encre, width: Charte.traitCadre),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FeuillePromotion(liste: l, ligne: g),
    ),
  );
}

class FeuillePromotion extends StatefulWidget {
  const FeuillePromotion({super.key, required this.liste, required this.ligne});
  final Liste liste;
  final LigneListe ligne;

  @override
  State<FeuillePromotion> createState() => _FeuillePromotionState();
}

class _FeuillePromotionState extends State<FeuillePromotion> {
  final etat = Etat.instance;
  late String type;
  final c1 = TextEditingController(); // achetés, quantité minimale, valeur, gain
  final c2 = TextEditingController(); // offerts, prix global
  final libelle = TextEditingController();
  bool libelleModifie = false;
  bool enMontant = false;
  String? packagingId;

  @override
  void initState() {
    super.initState();
    final p = widget.ligne.promotion;
    type = p?.type ?? 'lot';
    final par = p?.parametres ?? const {};
    String v(String k) => par[k] == null ? '' : '${par[k]}'.replaceAll('.', ',');
    switch (type) {
      case 'lot':
        c1.text = p == null ? '3' : v('quantiteAchetee');
        c2.text = p == null ? '1' : v('quantiteOfferte');
      case 'prixGlobal':
        c1.text = v('quantiteMinimale');
        c2.text = v('prixGlobal');
      case 'remise':
      case 'fidelite':
        enMontant = par.containsKey('montant');
        c1.text = enMontant ? v('montant') : v('pourcentage');
      case 'packagingSpecial':
        c1.text = v('gain');
        packagingId = par['packagingId'] as String? ?? widget.ligne.packagingId;
    }
    libelle.text = p?.libelle ?? _auto();
    libelleModifie = p != null && p.libelle != _auto();
  }

  @override
  void dispose() {
    c1.dispose();
    c2.dispose();
    libelle.dispose();
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  String _f(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toString().replaceAll('.', ',');

  String _auto() {
    switch (type) {
      case 'lot':
        return '${_f(_n(c1))} achetés = ${_f(_n(c2))} offert${_n(c2) > 1 ? 's' : ''}';
      case 'prixGlobal':
        return '${_f(_n(c1))} pour ${euros(_n(c2).toDouble())}';
      case 'remise':
        return enMontant ? '−${euros(_n(c1).toDouble())}' : '−${_f(_n(c1))} %';
      case 'fidelite':
        return enMontant ? '${euros(_n(c1).toDouble())} sur la carte' : '${_f(_n(c1))} % sur la carte';
      case 'packagingSpecial':
        return c1.text.trim().isEmpty ? 'Packaging spécial' : c1.text.trim();
      default:
        return etat.typePromotion(type)?.nom ?? 'Promotion';
    }
  }

  void _majLibelle() {
    if (!libelleModifie) libelle.text = _auto();
    setState(() {});
  }

  Map<String, dynamic> _parametres() {
    switch (type) {
      case 'lot':
        return {'quantiteAchetee': _n(c1), 'quantiteOfferte': _n(c2)};
      case 'prixGlobal':
        return {'quantiteMinimale': _n(c1), 'prixGlobal': _n(c2)};
      case 'remise':
      case 'fidelite':
        return enMontant ? {'montant': _n(c1)} : {'pourcentage': _n(c1)};
      case 'packagingSpecial':
        return {if (packagingId != null) 'packagingId': packagingId, 'gain': c1.text.trim()};
      default:
        return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = etat.produit(widget.ligne.produitId);
    final k = etat.packaging(widget.ligne.packagingId);
    final m = etat.magasin(widget.liste.magasinId);
    final types = etat.typesPromotion;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Charte.texteSecondaire, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Promotion visée', style: Charte.texte(21, gras: true)),
            Text(
              '${[p?.nom, k?.libelle.toLowerCase(), m?.nom].whereType<String>().join(' · ')} — d\'après le catalogue du magasin',
              style: Charte.texte(14, couleur: Charte.texteSecondaire),
            ),
            const TitreSection('Type', cote: 0, haut: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.75,
              children: [for (final t in types) _tuile(t)],
            ),
            const SizedBox(height: 12),
            ..._champs(),
            const SizedBox(height: 10),
            Text('Libellé', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 4),
            TextField(
              controller: libelle,
              style: Charte.texte(17),
              onChanged: (_) => libelleModifie = true,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Bouton(
                    texte: 'Sans promotion',
                    onTap: () {
                      etat.definirPromotion(widget.liste, widget.ligne.produitId, null);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Bouton(
                    texte: 'Valider',
                    plein: true,
                    onTap: () {
                      final lib = libelle.text.trim().isEmpty ? _auto() : libelle.text.trim();
                      etat.definirPromotion(widget.liste, widget.ligne.produitId, PromotionLigne(type, _parametres(), lib));
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tuile(TypePromotion t) {
    final choisi = t.id == type;
    return Material(
      color: choisi ? Charte.encre : Charte.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (type != t.id) {
            type = t.id;
            enMontant = false;
            libelleModifie = false;
            // Valeurs proposées pour le type choisi
            c1.text = switch (type) { 'lot' => '3', 'prixGlobal' => '2', _ => '' };
            c2.text = switch (type) { 'lot' => '1', _ => '' };
          }
          _majLibelle();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconePromo(code: t.code, inverse: choisi),
            const SizedBox(height: 4),
            Text(_nomCourt(t), style: Charte.texte(14, gras: choisi, couleur: choisi ? Charte.fond : Charte.encre)),
          ],
        ),
      ),
    );
  }

  static String _nomCourt(TypePromotion t) => switch (t.id) {
        'remise' => 'Remise',
        'packagingSpecial' => 'Packaging',
        _ => t.nom,
      };

  Widget _champ(String etiquette, Widget champ) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiquette, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 4),
          champ,
        ],
      );

  Widget _nombre(TextEditingController c) => TextField(
        controller: c,
        style: Charte.texte(17),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _majLibelle(),
      );

  Widget _deux(Widget a, Widget b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  List<Widget> _champs() {
    switch (type) {
      case 'lot':
        return [_deux(_champ('Achetés', _nombre(c1)), _champ('Offerts', _nombre(c2)))];
      case 'prixGlobal':
        return [_deux(_champ('Quantité minimale', _nombre(c1)), _champ('Prix global (€)', _nombre(c2)))];
      case 'remise':
      case 'fidelite':
        return [
          Bascule(
            options: const ['Pourcentage', 'Montant'],
            index: enMontant ? 1 : 0,
            onChange: (i) {
              enMontant = i == 1;
              _majLibelle();
            },
          ),
          const SizedBox(height: 10),
          _champ(enMontant ? 'Montant (€)' : 'Pourcentage (%)', _nombre(c1)),
        ];
      case 'packagingSpecial':
        final p = etat.produit(widget.ligne.produitId);
        return [
          _deux(
            _champ(
              'Packaging',
              ChoixDeroulant<String>(
                valeur: packagingId ?? '',
                choix: {'': '—', for (final id in p?.packagingIds ?? <String>[]) id: etat.packaging(id)?.libelle ?? ''},
                onChange: (v) => setState(() => packagingId = v.isEmpty ? null : v),
              ),
            ),
            _champ(
              'Gain',
              TextField(
                controller: c1,
                style: Charte.texte(17),
                decoration: const InputDecoration(hintText: '+20 % gratuit'),
                onChanged: (_) => _majLibelle(),
              ),
            ),
          ),
        ];
      default:
        return [Text('Décrivez l\'offre dans le libellé.', style: Charte.texte(14, couleur: Charte.texteSecondaire))];
    }
  }
}

// ---------------------------------------------------------------- Écran 7 : liste complète

class EcranListeComplete extends StatelessWidget {
  const EcranListeComplete({super.key, required this.listeId, this.depuisCourses = false});
  final String listeId;
  final bool depuisCourses;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(listeId);
        if (l == null) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Liste'),
            corps: Center(child: Text("Cette liste n'existe plus.", style: Charte.texte(16))),
          );
        }
        final enCours = l.statut == StatutListe.enCours;
        final membreId = enCours ? (l.membreId ?? etat.moi.id) : etat.moi.id;
        final parcoursId = enCours ? l.parcoursId : etat.parcoursParDefaut(l.magasinId, membreId)?.id;
        final p = etat.unParcours(parcoursId);
        final etapes = etat.etapes(l, parcoursId);
        final nbSecteurs = etapes.where((e) => !e.nonPlace).length;
        final n = l.lignes.length;
        final commence = l.nbCoches > 0 || l.repriseSecteurId != null;
        var numero = 0;
        return PageBase(
          entete: EnTeteTravail(titre: '${etat.magasin(l.magasinId)?.nom ?? ''} · $n article${n > 1 ? 's' : ''}'),
          haut: [
            Container(
              width: double.infinity,
              color: Charte.fondBandeau,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '${p?.nom ?? 'Ordre des rayons'} · ${etat.membre(membreId)?.nomAffiche ?? ''} · '
                '$nbSecteurs secteur${nbSecteurs > 1 ? 's' : ''}',
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
            ),
          ],
          corps: n == 0
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('La liste est vide.', style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : ListView(
                  children: [
                    for (final e in etapes) ...[
                      TitreGroupe(nom: e.nom, numero: e.nonPlace ? null : '${++numero}', nonPlace: e.nonPlace),
                      for (final g in e.lignes)
                        LigneCompacte(
                          nom: etat.produit(g.produitId)?.nom ?? '',
                          complement: etat.complement(g, etat.produit(g.produitId)!, marque: false),
                          quantite: g.quantite,
                          promo: g.promotion == null ? null : (etat.typePromotion(g.promotion!.type)?.code ?? '?'),
                          coche: g.coche,
                        ),
                    ],
                  ],
                ),
          bas: [
            if (enCours)
              BarreAction(boutons: [
                Bouton(
                  texte: commence ? 'Reprendre les courses' : 'Commencer · secteur 1',
                  plein: true,
                  onTap: n == 0
                      ? null
                      : () {
                          if (depuisCourses) {
                            Navigator.of(context).pop();
                          } else {
                            Nav.remplacerTravail(EcranCoursesSecteur(listeId: l.id));
                          }
                        },
                ),
              ])
            else
              BarreAction(boutons: [
                Bouton(texte: 'Continuer la préparation', plein: true, onTap: () => Navigator.of(context).pop()),
              ]),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Écrans 8 et 9 : courses par secteur

class EcranCoursesSecteur extends StatelessWidget {
  const EcranCoursesSecteur({super.key, required this.listeId});
  final String listeId;

  static String court(String nom) => nom.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(listeId);
        if (l == null || l.statut != StatutListe.enCours) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Courses'),
            corps: Center(child: Text('Pas de courses en cours.', style: Charte.texte(16))),
          );
        }
        final etapes = etat.etapes(l, l.parcoursId);
        var i = etapes.indexWhere((e) => e.id == l.repriseSecteurId);
        if (i < 0) i = 0;
        final total = l.lignes.length;
        final titre = '${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.nbCoches} / $total';
        if (etapes.isEmpty) {
          return PageBase(
            entete: EnTeteTravail(titre: titre),
            corps: Center(child: Text('La liste est vide.', style: Charte.texte(16))),
            bas: [
              BarreAction(boutons: [Bouton(texte: 'Terminer les courses', plein: true, onTap: () => _terminer(context, l))]),
            ],
          );
        }
        final e = etapes[i];
        final cochesSecteur = e.lignes.where((g) => g.coche).length;
        final termine = cochesSecteur == e.lignes.length;
        void aller(int k) => etat.etapeCourante(l, etapes[k].id);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (aFerme, _) {
            if (!aFerme) _pause(context, l, e);
          },
          child: PageBase(
            entete: EnTeteTravail(
              titre: titre,
              gauche: BoutonIcone(
                icone: Icons.format_list_bulleted,
                libelle: 'Liste complète',
                onTap: () => Nav.travail(EcranListeComplete(listeId: l.id, depuisCourses: true)),
              ),
              action: BoutonPause(onTap: () => _pause(context, l, e)),
            ),
            haut: [
              BandeauPuces(
                pastille: false,
                puces: [
                  for (var k = 0; k < etapes.length; k++)
                    Puce(
                      etapes[k].nonPlace ? '? Non placé' : '${k + 1} ${court(etapes[k].nom)}',
                      termine: etapes[k].lignes.every((g) => g.coche),
                    ),
                ],
                selection: i,
                onChoix: aller,
              ),
              Container(
                height: 34,
                color: Charte.fondBandeau,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: e.nom, style: Charte.texte(15, gras: true)),
                          if (!e.nonPlace)
                            TextSpan(text: ' · rayon ${etat.rayon(e.secteur!.rayonId)?.nom ?? ''}', style: Charte.texte(15)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('$cochesSecteur / ${e.lignes.length} coché${cochesSecteur > 1 ? 's' : ''}', style: Charte.texte(15)),
                  ],
                ),
              ),
            ],
            corps: ListView(
              children: [
                for (final g in e.lignes) _ligne(etat, l, g),
                if (termine)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20, color: Charte.encre),
                        const SizedBox(width: 8),
                        Text(i < etapes.length - 1 ? 'Secteur terminé' : 'Tout est coché', style: Charte.texte(15, gras: true)),
                      ],
                    ),
                  ),
              ],
            ),
            bas: [
              BarreAction(boutons: [
                if (i > 0)
                  Bouton(texte: court(etapes[i - 1].nom), icone: Icons.arrow_left, taille: 16, onTap: () => aller(i - 1))
                else
                  const Bouton(texte: '', icone: Icons.arrow_left, onTap: null),
                if (i < etapes.length - 1)
                  Bouton(
                    texte: etapes[i + 1].nonPlace ? 'Non placé' : court(etapes[i + 1].nom),
                    iconeApres: Icons.arrow_right,
                    taille: termine ? 17 : 16,
                    plein: true,
                    onTap: () => aller(i + 1),
                  )
                else
                  Bouton(texte: 'Terminer les courses', taille: 16, plein: true, onTap: () => _terminer(context, l)),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _ligne(Etat etat, Liste l, LigneListe g) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    final morceaux = [etat.complement(g, p), if (g.promotion != null) g.promotion!.libelle].where((x) => x.isNotEmpty);
    return LigneCourse(
      key: ValueKey(p.id),
      nom: p.nom,
      complement: morceaux.join(' · '),
      coche: g.coche,
      quantite: g.quantite,
      promo: g.promotion == null ? null : (etat.typePromotion(g.promotion!.type)?.code ?? '?'),
      alerte: etat.quantiteInsuffisante(g),
      onTap: () => etat.cocher(l, p.id),
    );
  }

  /// Écran 9 — « Interrompre les courses ? »
  Future<void> _pause(BuildContext context, Liste l, Etape e) async {
    final interrompre = await confirmer(
      context,
      icone: Icons.pause_circle_outline,
      titre: 'Interrompre les courses ?',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(style: Charte.texte(17), children: [
            const TextSpan(text: 'Rien n\'est perdu : '),
            TextSpan(text: '${l.nbCoches} articles cochés sur ${l.lignes.length}', style: Charte.texte(17, gras: true)),
            const TextSpan(text: ', arrêt au secteur '),
            TextSpan(text: e.nom, style: Charte.texte(17, gras: true)),
            const TextSpan(text: '.'),
          ])),
          const SizedBox(height: 10),
          Text('Vous reprendrez depuis Listes › Courses, ou au prochain lancement de l\'application.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        ],
      ),
      plein: 'Continuer les courses',
      contour: 'Interrompre',
    );
    if (interrompre != true) return;
    Etat.instance.etapeCourante(l, e.id);
    Etat.instance.interrompreCourses(l);
    Nav.i.retourOnglets(Nav.listes, Nav.courses);
  }

  Future<void> _terminer(BuildContext context, Liste l) async {
    final reste = l.lignes.where((g) => !g.coche).length;
    if (reste > 0) {
      final ok = await confirmer(
        context,
        titre: 'Terminer les courses ?',
        contenu: Text('Il reste $reste article${reste > 1 ? 's' : ''} non coché${reste > 1 ? 's' : ''}.', style: Charte.texte(17)),
        plein: 'Continuer les courses',
        contour: 'Terminer',
      );
      if (ok != true) return;
    }
    Etat.instance.terminerCourses(l);
    Nav.i.retourOnglets(Nav.historique, Nav.coursesEffectuees);
    Nav.message(context, 'Courses terminées : elles apparaissent dans l\'historique');
  }
}
