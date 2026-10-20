import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../donnees/envoi.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'magasin.dart';

// Écrans de travail (barre d'onglets masquée) : préliste (2), construction (3) et son volet
// « Promotion visée » (4), liste complète (7), courses par secteur (8) et son dialogue (9).

/// Écran 2 — Nouvelle liste : magasin et nom (par défaut magasin et date), puis
/// « Liste vide », « Historique » (copie d'une course effectuée) ou « Générer par IA » (prévu plus tard).
class EcranPreliste extends StatefulWidget {
  const EcranPreliste({super.key});

  @override
  State<EcranPreliste> createState() => _EcranPrelisteState();
}

class _EcranPrelisteState extends State<EcranPreliste> {
  final etat = Etat.instance;
  late String magasinId;
  final nom = TextEditingController();
  bool nomModifie = false;
  bool historique = false;

  @override
  void initState() {
    super.initState();
    magasinId = etat.magasins.first.id;
    _initialiser();
  }

  @override
  void dispose() {
    nom.dispose();
    super.dispose();
  }

  void _initialiser() {
    if (!nomModifie) nom.text = etat.nomParDefaut(magasinId, DateTime.now());
  }

  String? get _nom => nom.text.trim() == etat.nomParDefaut(magasinId, DateTime.now()) ? null : nom.text;

  void _creer(List<LigneListe> lignes) {
    final l = etat.creerListe(magasinId, lignes, nom: _nom);
    Nav.remplacerTravail(EcranConstruction(listeId: l.id));
  }

  void _ia() => showDialog<void>(
        context: context,
        barrierColor: Charte.voile,
        builder: (ctx) => AlertDialog(
          backgroundColor: Charte.fond,
          title: Text('Générer par IA', style: Charte.texte(18, gras: true)),
          content: Text('La génération d\'une liste par intelligence artificielle est prévue dans une version future.',
              style: Charte.texte(16)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Compris', style: Charte.texte(16, gras: true)))],
        ),
      );

  /// Affiche une course passée ; « Reprendre ces articles » la copie dans la nouvelle liste.
  Future<void> _voirCourse(Liste ancienne) async {
    final reprendre = await showDialog<bool>(
      context: context,
      barrierColor: Charte.voile,
      builder: (ctx) => AlertDialog(
        backgroundColor: Charte.fond,
        insetPadding: const EdgeInsets.all(16),
        title: Text('Courses ${quandJour(etat.dateCourses(ancienne))} · ${ancienne.lignes.length} articles',
            style: Charte.texte(18, gras: true)),
        content: SizedBox(
          width: 360,
          height: 380,
          child: ListView(
            children: [
              for (final g in ancienne.lignes)
                if (etat.produit(g.produitId) case final p?)
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: p.nom, style: Charte.texte(16)),
                      if (etat.complement(g, p).isNotEmpty) TextSpan(text: ' · ${etat.complement(g, p)}', style: Charte.secondaire),
                      if (g.quantite > 1) TextSpan(text: '  × ${g.quantite}', style: Charte.texte(15, gras: true)),
                    ])),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Fermer', style: Charte.texte(16))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Reprendre ces articles', style: Charte.texte(16, gras: true)),
          ),
        ],
      ),
    );
    if (reprendre == true && mounted) _creer(etat.lignesReprises(ancienne));
  }

  @override
  Widget build(BuildContext context) {
    final passees = etat.dernieresCourses(magasinId);
    return PageBase(
      entete: const EnTeteTravail(titre: 'Nouvelle liste'),
      haut: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text('Magasin', style: Charte.texte(15))),
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
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text('Nom', style: Charte.texte(15))),
              Expanded(
                child: TextField(
                  key: const ValueKey('nom-liste'),
                  controller: nom,
                  style: Charte.texte(16),
                  onChanged: (_) => nomModifie = true,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            children: [
              Expanded(child: Bouton(texte: 'Liste vide', plein: true, taille: 16, onTap: () => _creer([]))),
              const SizedBox(width: 8),
              Expanded(
                child: Bouton(
                  texte: 'Historique',
                  taille: 16,
                  plein: historique,
                  onTap: () => setState(() => historique = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Bouton(texte: 'Générer par IA', taille: 15, pointille: true, onTap: _ia)),
            ],
          ),
        ),
        Container(height: 1, color: Charte.separateurZone),
      ],
      corps: !historique
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  '« Liste vide » : vous choisirez les produits rayon par rayon.\n'
                  '« Historique » : partir d\'une de vos dernières courses dans ce magasin.',
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            )
          : ListView(
              children: [
                _titre('Dernières courses dans ce magasin · touchez pour choisir'),
                if (passees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Aucune course terminée avec ses articles dans ce magasin.',
                        style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                  ),
                for (final c in passees)
                  InkWell(
                    onTap: () => _voirCourse(c),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20, color: Charte.couleurIcone(Icons.history)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: etat.nomListe(c), style: Charte.texte(15, gras: true)),
                              TextSpan(
                                text: ' · ${c.lignes.length} articles · ${quandJour(etat.dateCourses(c))}',
                                style: Charte.secondaire,
                              ),
                            ])),
                          ),
                          Icon(Icons.chevron_right, color: Charte.couleurIcone(Icons.chevron_right)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _titre(String nom) => Container(
        height: 30,
        color: Charte.fondBandeau,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Text(nom.toUpperCase(), style: Charte.texte(12, couleur: Charte.texteSecondaire, espacement: 0.8)),
      );
}

/// Écran 3 — Construction par secteur. Chaque action est enregistrée ; quitter ne perd rien.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  @override
  State<EcranConstruction> createState() => _EcranConstructionState();
}

/// Un élément de la liste de préparation : titre de secteur, produit, ou « + Produit absent ».
class _Element {
  _Element.titre(this.secteur) : produit = null, absent = false;
  _Element.produit(this.secteur, Produit this.produit) : absent = false;
  _Element.absent(Secteur this.secteur) : produit = null, absent = true;
  final Secteur? secteur; // null : « Non placé »
  final Produit? produit;
  final bool absent;
}

/// Préparation : la même liste que pendant les courses. Tous les secteurs du magasin, dans l'ordre du parcours
/// (sans parcours : ordre des rayons), chacun sous son bandeau ; on fait défiler du doigt.
/// « Ma liste » ne garde que les articles choisis ; un nouvel appui (« Tout ») remet tout le catalogue.
class _EcranConstructionState extends State<EcranConstruction> {
  final etat = Etat.instance;
  static const int seuilHabituel = 5;
  bool maListe = false;
  final _defilement = ScrollController();
  final _titres = <String, GlobalKey>{};

  Liste? get liste => etat.liste(widget.listeId);

  @override
  void initState() {
    super.initState();
    final l = liste;
    if (l == null) return;
    _ordonner(l);
    // Reprise : la liste s'ouvre sur le secteur où l'on s'était arrêté.
    final s = etat.secteur(l.repriseSecteurId ?? '');
    if (s != null) WidgetsBinding.instance.addPostFrameCallback((_) => _allerA(l, s, noter: false));
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  /// Secteurs du magasin dans l'ordre du parcours par défaut, puis ceux qu'il ne cite pas.
  List<Secteur> _secteurs(Liste l) {
    final ordre = <String>[...(etat.parcoursParDefaut(l.magasinId, etat.moi.id)?.etapes ?? const <String>[])];
    for (final s in etat.secteursDuMagasin(l.magasinId)) {
      if (!ordre.contains(s.id)) ordre.add(s.id);
    }
    return [for (final id in ordre) etat.secteur(id)].whereType<Secteur>().toList();
  }

  // Ordre des produits figé pendant la préparation : cocher ne déplace rien.
  // À l'ouverture, les produits choisis passent en premier dans leur secteur, puis les plus achetés.
  final Map<String, int> _ordre = {};

  void _ordonner(Liste l) {
    final tous = [for (final s in etat.secteursDuMagasin(l.magasinId)) ...etat.produitsDu(l.magasinId, s.id)]..sort((a, b) {
        final ca = etat.ligne(l, a.id) != null ? 0 : 1;
        final cb = etat.ligne(l, b.id) != null ? 0 : 1;
        return ca != cb ? ca.compareTo(cb) : b.nbUtilisations.compareTo(a.nbUtilisations);
      });
    _ordre
      ..clear()
      ..addAll({for (var i = 0; i < tous.length; i++) tous[i].id: i});
  }

  List<_Element> _elements(Liste l) {
    final res = <_Element>[];
    for (final s in _secteurs(l)) {
      final produits = [
        for (final p in etat.produitsDu(l.magasinId, s.id))
          if (!maListe || etat.ligne(l, p.id) != null) p,
      ]..sort((a, b) => (_ordre[a.id] ?? 1 << 20).compareTo(_ordre[b.id] ?? 1 << 20));
      if (maListe && produits.isEmpty) continue;
      res.add(_Element.titre(s));
      for (final p in produits) {
        res.add(_Element.produit(s, p));
      }
      if (!maListe) res.add(_Element.absent(s));
    }
    final nonPlaces = [
      for (final g in l.lignes)
        if (etat.secteurDe(l.magasinId, g.produitId) == null) etat.produit(g.produitId),
    ].whereType<Produit>().toList();
    if (nonPlaces.isNotEmpty) {
      res.add(_Element.titre(null));
      for (final p in nonPlaces) {
        res.add(_Element.produit(null, p));
      }
    }
    return res;
  }

  /// Fait venir le bandeau d'un secteur en haut de l'écran (hauteurs estimées, puis ajustement).
  void _allerA(Liste l, Secteur s, {bool noter = true}) {
    if (noter) etat.positionConstruction(l, s.rayonId, s.id);
    if (!_defilement.hasClients) return;
    final elements = _elements(l);
    var y = 0.0;
    for (final e in elements) {
      if (e.produit == null && !e.absent && e.secteur?.id == s.id) break;
      y += e.produit == null ? 52 : (etat.ligne(l, e.produit!.id) != null ? 110 : Charte.ligneCourses);
    }
    _defilement.jumpTo(y.clamp(0, _defilement.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _titres[s.id]?.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c);
    });
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

  Future<void> _produitAbsent(Liste l, Secteur s) async {
    final nom = await demanderTexte(context, titre: 'Nouveau produit', aide: 'Nom générique (ex. : Riz)');
    if (nom == null || nom.isEmpty || !mounted) return;
    final p = etat.creerProduit(nom);
    etat.placer(l.magasinId, p.id, s.id);
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
        final barre = BarreAction(boutons: [
          Bouton(
            texte: maListe ? 'Tout' : 'Ma liste · ${l.lignes.length}',
            icone: maListe ? Icons.format_list_bulleted : Icons.checklist,
            taille: 16,
            plein: maListe,
            onTap: () => setState(() => maListe = !maListe),
          ),
          Bouton(
            texte: 'Liste prête',
            plein: !maListe,
            onTap: () {
              etat.listePrete(l);
              Nav.i.retourOnglet(Nav.preparer);
              Nav.message(context, 'Liste prête : elle apparaît dans l\'onglet Courses');
            },
          ),
        ]);
        final entete = EnTeteTravail(
          titre: etat.nomListe(l),
          sousTitre: 'Enregistré',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            BoutonIcone(
              icone: Icons.mail_outline,
              libelle: 'Envoyer par mail',
              onTap: () async {
                if (!await envoyerListe(etat, l) && context.mounted) {
                  Nav.message(context, 'Aucune messagerie n\'a répondu sur cet appareil');
                }
              },
            ),
            BoutonIcone(icone: Icons.search, libelle: 'Rechercher dans le magasin', onTap: () => _rechercher(l)),
          ]),
        );
        if (etat.secteursDuMagasin(l.magasinId).isEmpty) {
          return PageBase(
            entete: entete,
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Ce magasin n'a pas encore de rayons : décrivez-les dans Gérer › Magasins et catalogue.",
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
            bas: [barre],
          );
        }
        final elements = _elements(l);
        final numeros = <String, int>{};
        for (final e in elements) {
          if (e.produit == null && !e.absent && e.secteur != null) numeros[e.secteur!.id] = numeros.length + 1;
        }

        return PageBase(
          entete: entete,
          corps: elements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('La liste est vide.', style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : ListView.builder(
                  controller: _defilement,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: elements.length,
                  itemBuilder: (context, i) {
                    final e = elements[i];
                    final s = e.secteur;
                    if (e.produit != null) {
                      return _ligne(l, e.produit!);
                    }
                    if (e.absent) {
                      return InkWell(
                        onTap: () => _produitAbsent(l, s!),
                        child: Container(
                          height: 44,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
                          child: Text('+ Produit absent de ce secteur', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                        ),
                      );
                    }
                    final r = s == null ? null : etat.rayon(s.rayonId);
                    return TitreGroupe(
                      key: _titres.putIfAbsent(s?.id ?? 'nonPlace', GlobalKey.new),
                      nom: s?.nom ?? 'Non placé',
                      numero: s == null ? null : numeros[s.id]?.toString(),
                      nonPlace: s == null,
                      image: r == null ? null : cleSecteur(r.nom, s!.nom),
                      fort: true,
                      nombre: s == null ? null : etat.nbDansSecteur(l, s.id),
                    );
                  },
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
      complement: [etat.complement(g, p, avecPackaging: g == null), if (g?.consigne != null) '« ${g!.consigne} »']
          .where((x) => x.isNotEmpty)
          .join(' · '),
      coche: g != null,
      quantite: g?.quantite ?? 1,
      codePromo: g?.promotion == null
          ? null
          : (g!.promotion!.libelle.isNotEmpty ? g.promotion!.libelle : (etat.typePromotion(g.promotion!.type)?.nom ?? 'Promo')),
      couleurPromo: g?.promotion == null ? null : Color(etat.couleurPromo(g!.promotion!.type)!),
      onPromo: g == null ? null : () => ouvrirFeuillePromotion(context, l, g),
      codePackaging: g?.packagingId == null ? null : etat.packaging(g!.packagingId)?.libelle,
      couleurPackaging: Color(etat.couleurPack(g?.packagingId ?? '')!),
      onPackaging: g == null ? null : () => ouvrirFeuillePromotion(context, l, g, packaging: true),
      habituel: p.nbUtilisations >= seuilHabituel,
      alerte: g == null ? null : etat.quantiteInsuffisante(g),
      onTap: () {
        etat.basculer(l, p.id);
        final s = etat.secteurDe(l.magasinId, p.id);
        if (s != null) etat.positionConstruction(l, s.rayonId, s.id);
      },
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
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
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

/// Code court d'un packaging sur le bouton de la ligne : « ×6 » pour un pack de 6, sinon le début du libellé.
String codeCourtPackaging(String libelle) {
  final l = libelle.trim().toLowerCase();
  const unites = {'à la pièce': 'pce', 'au poids': 'kg', 'à la coupe': 'cpe', 'botte': 'bte', 'paire': 'pr', 'rouleau': 'rlx'};
  if (unites[l] case final u?) return u;
  final n = RegExp(r'\d+').firstMatch(l)?.group(0);
  if (n != null && (l.startsWith('pack') || l.startsWith('lot') || l.startsWith('boîte de') || l.startsWith('paquet'))) return '×$n';
  final t = l.replaceAll(' ', '');
  return t.length <= 5 ? t : t.substring(0, 5);
}

/// Volet du packaging (et de la consigne) ou volet de la promotion d'un article.
Future<void> ouvrirFeuillePromotion(BuildContext context, Liste l, LigneListe g, {bool packaging = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Charte.voile,
    backgroundColor: Charte.fond,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FeuillePromotion(liste: l, ligne: g, packaging: packaging),
    ),
  );
}

/// Volet de l'article : soit le packaging (pack de x) et la consigne, soit la promotion visée.
class FeuillePromotion extends StatefulWidget {
  const FeuillePromotion({super.key, required this.liste, required this.ligne, this.packaging = false});
  final Liste liste;
  final LigneListe ligne;
  final bool packaging;

  /// Promotions proposées : lot « 3 dont 1 gratuit », lot pour bénéficier d'une promo, remise simple, autre.
  static const typesProposes = ['lot', 'prixGlobal', 'remise', 'autre'];
  static const aucune = '';

  @override
  State<FeuillePromotion> createState() => _FeuillePromotionState();
}

class _FeuillePromotionState extends State<FeuillePromotion> {
  final etat = Etat.instance;
  late String type; // FeuillePromotion.aucune : sans promotion
  final c1 = TextEditingController(); // lot de, quantité, valeur
  final c2 = TextEditingController(); // dont gratuits, avantage
  final libelle = TextEditingController();
  final consigne = TextEditingController();
  bool libelleModifie = false;
  bool enMontant = false;
  String? packagingId;

  @override
  void initState() {
    super.initState();
    final p = widget.ligne.promotion;
    type = p?.type ?? FeuillePromotion.aucune;
    packagingId = widget.ligne.packagingId;
    consigne.text = widget.ligne.consigne ?? '';
    final par = p?.parametres ?? const {};
    String v(String k) => par[k] == null ? '' : '${par[k]}'.replaceAll('.', ',');
    switch (type) {
      case 'lot':
        c1.text = v('quantiteAchetee');
        c2.text = v('quantiteOfferte');
      case 'prixGlobal':
        c1.text = v('quantiteMinimale');
        c2.text = par['avantage'] as String? ?? (par['prixGlobal'] != null ? '${v('prixGlobal')} €' : '');
      case 'remise':
      case 'fidelite':
        enMontant = par.containsKey('montant');
        c1.text = enMontant ? v('montant') : v('pourcentage');
    }
    libelle.text = p?.libelle ?? _auto();
    libelleModifie = p != null && p.libelle != _auto();
  }

  @override
  void dispose() {
    c1.dispose();
    c2.dispose();
    libelle.dispose();
    consigne.dispose();
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  String _f(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toString().replaceAll('.', ',');

  String _auto() {
    switch (type) {
      case 'lot':
        return '${_f(_n(c1))} dont ${_f(_n(c2))} gratuit${_n(c2) > 1 ? 's' : ''}';
      case 'prixGlobal':
        return 'Par ${_f(_n(c1))}${c2.text.trim().isEmpty ? '' : ' : ${c2.text.trim()}'}';
      case 'remise':
        return enMontant ? 'Remise de ${euros(_n(c1).toDouble())}' : 'Remise de ${_f(_n(c1))} %';
      case FeuillePromotion.aucune:
        return '';
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
        return {'quantiteMinimale': _n(c1), 'avantage': c2.text.trim()};
      case 'remise':
      case 'fidelite':
        return enMontant ? {'montant': _n(c1)} : {'pourcentage': _n(c1)};
      default:
        return {};
    }
  }

  void _valider() {
    final id = widget.ligne.produitId;
    if (widget.packaging) {
      etat.definirPackaging(widget.liste, id, packagingId);
      etat.definirConsigne(widget.liste, id, consigne.text);
    } else if (type == FeuillePromotion.aucune) {
      etat.definirPromotion(widget.liste, id, null);
    } else {
      final lib = libelle.text.trim().isEmpty ? _auto() : libelle.text.trim();
      etat.definirPromotion(widget.liste, id, PromotionLigne(type, _parametres(), lib));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = etat.produit(widget.ligne.produitId);
    final m = etat.magasin(widget.liste.magasinId);
    final types = [
      for (final id in FeuillePromotion.typesProposes)
        if (etat.typePromotion(id) case final t?) t,
    ];
    // Formats du produit, sinon ceux de son secteur
    final proposes = p == null
        ? <String>[]
        : (p.packagingIds.isNotEmpty ? p.packagingIds : etat.formatsDuSecteur(widget.liste.magasinId, p.id));
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
            Text(p?.nom ?? 'Article', style: Charte.texte(21, gras: true)),
            Text(m?.nom ?? '', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            if (widget.packaging) ...[
            const TitreSection('Packaging', cote: 0, haut: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pastille('Indifférent', packagingId == null, () => setState(() => packagingId = null)),
              for (final k in {...proposes, if (packagingId != null) packagingId!})
                _pastille(etat.packaging(k)?.libelle ?? '', packagingId == k, () => setState(() => packagingId = k)),
              _pastille('Autre format…', false, () async {
                final autres = [for (final k in etat.typesPackaging) if (!proposes.contains(k)) k];
                final v = await choisirDansListe<String>(
                  context,
                  titre: 'Choisir un format',
                  choix: {'': '+ Nouveau format…', for (final k in autres) k: etat.packaging(k)?.libelle ?? ''},
                );
                if (v == null || p == null) return;
                if (v.isNotEmpty) {
                  etat.ajouterPackaging(p, etat.packaging(v)!.libelle);
                  setState(() => packagingId = v);
                  return;
                }
                if (!context.mounted) return;
                final lib = await demanderTexte(context, titre: 'Nouveau format', aide: 'Ex. : 500 g, 75 cl, lot de 4, pack de 6');
                if (lib == null || lib.isEmpty) return;
                etat.ajouterPackaging(p, lib);
                etat.ajouterTypePackaging(lib);
                setState(() => packagingId = p.packagingIds.last);
              }),
            ]),
            if (p != null && p.packagingIds.isEmpty && proposes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Formats courants du secteur, ce produit n\'en a pas encore.',
                    style: Charte.texte(13, couleur: Charte.texteSecondaire)),
              ),
            const TitreSection('Consigne', cote: 0, haut: 14),
            TextField(
              key: const ValueKey('consigne'),
              controller: consigne,
              style: Charte.texte(17),
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Ex. : bien mûres, la moins chère'),
            ),
            ] else ...[
            const TitreSection('Promotion visée', cote: 0, haut: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.75,
              children: [_tuile(null), for (final t in types) _tuile(t)],
            ),
            const SizedBox(height: 12),
            ..._champs(),
            if (type != FeuillePromotion.aucune) ...[
              const SizedBox(height: 10),
              Text('Libellé', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              const SizedBox(height: 4),
              TextField(
                controller: libelle,
                style: Charte.texte(17),
                onChanged: (_) => libelleModifie = true,
              ),
            ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Bouton(texte: 'Annuler', onTap: () => Navigator.of(context).pop())),
                const SizedBox(width: 10),
                Expanded(child: Bouton(texte: 'Valider', plein: true, onTap: _valider)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastille(String texte, bool choisi, VoidCallback onTap) => Material(
        color: choisi ? Charte.accent : Charte.blanc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(texte, style: Charte.texte(15, gras: choisi, couleur: choisi ? Charte.blanc : Charte.encre)),
            ),
          ),
        ),
      );

  Widget _tuile(TypePromotion? t) {
    final id = t?.id ?? FeuillePromotion.aucune;
    final choisi = id == type;
    return Material(
      color: choisi ? Charte.accent : Charte.blanc,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Charte.cadre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (type != id) {
            type = id;
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
            if (t != null) IconePromo(code: t.code, inverse: choisi) else const SizedBox(height: 4),
            const SizedBox(height: 4),
            Text(_nomCourt(t), textAlign: TextAlign.center,
                style: Charte.texte(14, gras: choisi, couleur: choisi ? Charte.blanc : Charte.encre)),
          ],
        ),
      ),
    );
  }

  static String _nomCourt(TypePromotion? t) => switch (t?.id) {
        null => 'Aucune',
        'lot' => 'Lot x dont y',
        'prixGlobal' => 'Lot pour promo',
        'remise' => 'Remise',
        _ => t!.nom,
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
      case FeuillePromotion.aucune:
        return const [];
      case 'lot':
        return [
          _deux(_champ('Lot de', _nombre(c1)), _champ('dont gratuits', _nombre(c2))),
          const SizedBox(height: 6),
          Text('La quantité de la liste est mise au nombre du lot.', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        ];
      case 'prixGlobal':
        return [
          _deux(
            _champ('Quantité à acheter', _nombre(c1)),
            _champ(
              'Avantage',
              TextField(
                controller: c2,
                style: Charte.texte(17),
                decoration: const InputDecoration(hintText: '2e à −50 %'),
                onChanged: (_) => _majLibelle(),
              ),
            ),
          ),
        ];
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
      default:
        return [Text('Décrivez l\'offre dans le libellé.', style: Charte.texte(14, couleur: Charte.texteSecondaire))];
    }
  }
}

/// Packaging et promotion d'une ligne, en clair et dans leur couleur.
List<Pastille> pastillesLigne(Etat etat, LigneListe g, {bool petite = false}) {
  final p = etat.produit(g.produitId);
  final k = p == null ? null : etat.packagingDe(g, p);
  Color? c(int? v) => v == null ? null : Color(v);
  return [
    if (k != null) Pastille(k.libelle, couleur: c(etat.couleurPack(k.id)), petite: petite),
    if (g.promotion != null)
      Pastille(g.promotion!.libelle.isEmpty ? (etat.typePromotion(g.promotion!.type)?.nom ?? 'Promo') : g.promotion!.libelle,
          couleur: c(etat.couleurPromo(g.promotion!.type)), petite: petite),
  ];
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
          entete: EnTeteTravail(
            titre: '${etat.nomListe(l)} · $n article${n > 1 ? 's' : ''}',
            action: BoutonIcone(
              icone: Icons.mail_outline,
              libelle: 'Envoyer par mail',
              onTap: () async {
                if (!await envoyerListe(etat, l) && context.mounted) {
                  Nav.message(context, 'Aucune messagerie n\'a répondu sur cet appareil');
                }
              },
            ),
          ),
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
                      TitreGroupe(
                        nom: e.nom,
                        numero: e.nonPlace ? null : '${++numero}',
                        nonPlace: e.nonPlace,
                        image: e.secteur == null ? null : cleSecteur(etat.rayon(e.secteur!.rayonId)?.nom ?? '', e.nom),
                      ),
                      for (final g in e.lignes)
                        LigneCompacte(
                          nom: etat.produit(g.produitId)?.nom ?? '',
                          complement: [
                            etat.complement(g, etat.produit(g.produitId)!, marque: false, avecPackaging: false),
                            if (g.consigne != null) '« ${g.consigne} »',
                          ].where((x) => x.isNotEmpty).join(' · '),
                          pastilles: pastillesLigne(etat, g, petite: true),
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

class EcranCoursesSecteur extends StatefulWidget {
  const EcranCoursesSecteur({super.key, required this.listeId});
  final String listeId;

  static String court(String nom) => nom.split(' ').first;

  @override
  State<EcranCoursesSecteur> createState() => _EcranCoursesSecteurState();
}

/// Courses : une seule liste, dans l'ordre du parcours, secteur par secteur ; on la fait défiler du doigt.
/// « Reste à faire » cache les articles déjà cochés (et les secteurs terminés) ; un nouvel appui remet la liste complète.
class _EcranCoursesSecteurState extends State<EcranCoursesSecteur> {
  bool resteAFaire = false;
  final _titres = <String, GlobalKey>{};
  bool _place = false;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(widget.listeId);
        if (l == null || l.statut != StatutListe.enCours) {
          return PageBase(
            entete: const EnTeteTravail(titre: 'Courses'),
            corps: Center(child: Text('Pas de courses en cours.', style: Charte.texte(16))),
          );
        }
        final etapes = etat.etapes(l, l.parcoursId);
        final total = l.lignes.length;
        final titre = '${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.nbCoches} / $total';
        // Secteur où l'on en est : le premier qui a encore un article à cocher.
        final e = etapes.firstWhere((x) => x.lignes.any((g) => !g.coche), orElse: () => etapes.isEmpty ? Etape(null, []) : etapes.last);
        _allerALaReprise(l);
        final numeros = <String, int>{};
        for (final x in etapes) {
          if (!x.nonPlace) numeros[x.id] = numeros.length + 1;
        }
        final visibles = [
          for (final x in etapes)
            if (!resteAFaire || x.lignes.any((g) => !g.coche)) x,
        ];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (aFerme, _) {
            if (!aFerme) _pause(context, l, e);
          },
          child: PageBase(
            entete: EnTeteTravail(titre: titre),
            haut: [_choixParcours(context, etat, l)],
            corps: etapes.isEmpty
                ? Center(child: Text('La liste est vide.', style: Charte.texte(16)))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final x in visibles) ...[
                          TitreGroupe(
                            key: _titres.putIfAbsent(x.id, GlobalKey.new),
                            nom: x.nom,
                            numero: numeros[x.id]?.toString(),
                            nonPlace: x.nonPlace,
                            image: imageEtape(etat, x),
                            fort: true,
                            avancement: (x.lignes.where((g) => g.coche).length, x.lignes.length),
                          ),
                          for (final g in x.lignes)
                            if (!resteAFaire || !g.coche) _ligne(etat, l, g),
                      ],
                      if (resteAFaire && visibles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 22, color: Charte.couleurIcone(Icons.check_circle_outline)),
                              const SizedBox(width: 8),
                              Text('Tout est coché', style: Charte.texte(16, gras: true)),
                            ],
                          ),
                        ),
                    ],
                  ),
            // Zone de décision : reste à faire / liste complète, pause, fin des courses.
            bas: [
              BarreAction(boutons: [
                Bouton(
                  texte: resteAFaire ? 'Tout' : 'Reste à faire',
                  icone: resteAFaire ? Icons.format_list_bulleted : Icons.checklist,
                  taille: 16,
                  plein: resteAFaire,
                  onTap: () => setState(() => resteAFaire = !resteAFaire),
                ),
                Bouton(texte: 'Pause', icone: Icons.pause, taille: 16, onTap: () => _pause(context, l, e)),
                Bouton(
                  texte: 'Terminer les courses',
                  taille: 15,
                  plein: l.nbCoches == total,
                  onTap: () => _terminer(context, l),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  /// À la reprise de courses interrompues, la liste s'ouvre sur le secteur où l'on s'était arrêté.
  void _allerALaReprise(Liste l) {
    if (_place) return;
    _place = true;
    final id = l.repriseSecteurId;
    if (id == null || l.nbCoches == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _titres[id]?.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c);
    });
  }

  Widget _ligne(Etat etat, Liste l, LigneListe g) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    final morceaux = [
      etat.complement(g, p, avecPackaging: false),
      if (g.consigne != null) '« ${g.consigne} »',
    ].where((x) => x.isNotEmpty);
    return LigneCourse(
      key: ValueKey(p.id),
      nom: p.nom,
      complement: morceaux.join(' · '),
      coche: g.coche,
      quantite: g.quantite,
      promo: g.promotion == null ? null : (etat.typePromotion(g.promotion!.type)?.code ?? '?'),
      pastilles: pastillesLigne(etat, g),
      alerte: etat.quantiteInsuffisante(g),
      onTap: () => etat.cocher(l, p.id),
    );
  }

  /// Changer de parcours pendant les courses, quand la personne en a plusieurs (ou un, plus l'ordre des rayons).
  Widget _choixParcours(BuildContext context, Etat etat, Liste l) {
    final membreId = l.membreId ?? etat.moi.id;
    final choix = <String, String>{
      for (final p in etat.parcoursDe(l.magasinId, membreId)) p.id: p.nom,
      '': 'Ordre des rayons',
    };
    if (choix.length < 2) return const SizedBox.shrink();
    final actuel = etat.unParcours(l.parcoursId)?.nom ?? 'Ordre des rayons';
    return InkWell(
      onTap: () async {
        final v = await choisirDansListe<String>(context, titre: 'Changer de parcours', choix: choix);
        if (v != null) etat.changerParcours(l, v.isEmpty ? null : v);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
        child: Row(
          children: [
            Icon(Icons.route_outlined, size: 20, color: Charte.couleurIcone(Icons.route_outlined)),
            const SizedBox(width: 8),
            Expanded(child: Text('Parcours : $actuel', style: Charte.texte(15), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('Changer', style: Charte.texte(15, gras: true)),
            Icon(Icons.expand_more, color: Charte.couleurIcone(Icons.expand_more)),
          ],
        ),
      ),
    );
  }

  /// Écran 9 — « Interrompre les courses ? » ; sans rien de coché, on peut simplement revenir aux listes prêtes.
  Future<void> _pause(BuildContext context, Liste l, Etape e) async {
    if (l.nbCoches == 0) {
      final quitter = await confirmer(
        context,
        titre: 'Quitter les courses ?',
        contenu: Text('Rien n\'est encore coché : la liste redevient « prête » dans l\'onglet Courses.', style: Charte.texte(17)),
        plein: 'Continuer les courses',
        contour: 'Quitter',
      );
      if (quitter != true) return;
      Etat.instance.annulerDepart(l);
      Nav.i.retourOnglet(Nav.courses);
      return;
    }
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
          Text('Vous reprendrez depuis l\'onglet Courses, ou au prochain lancement de l\'application.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        ],
      ),
      plein: 'Continuer les courses',
      contour: 'Interrompre',
    );
    if (interrompre != true) return;
    Etat.instance.etapeCourante(l, e.id);
    Etat.instance.interrompreCourses(l);
    Nav.i.retourOnglet(Nav.courses);
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
    Nav.i.ouvrirRubrique(Nav.historique, sous: Nav.coursesEffectuees);
    Nav.message(context, 'Courses terminées : joignez le ticket PDF dans Gérer › Historique');
  }
}

/// Image du secteur d'une étape des courses (aucune pour « Non placé »).
String? imageEtape(Etat etat, Etape e) {
  final r = e.secteur == null ? null : etat.rayon(e.secteur!.rayonId);
  return r == null ? null : cleSecteur(r.nom, e.secteur!.nom);
}
