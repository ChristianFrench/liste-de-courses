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

/// Écran 2 — Nouvelle liste : magasin et nom (par défaut magasin, date et heure ; deux listes ne peuvent pas
/// porter le même nom), puis « Liste type » (tous les articles, rayon par rayon), « Liste personnalisée »
/// (choisir dans une course passée, rien n'est coché d'avance) ou « Liste calculée » (prévue plus tard).
class EcranPreliste extends StatefulWidget {
  const EcranPreliste({super.key});

  @override
  State<EcranPreliste> createState() => _EcranPrelisteState();
}

class _EcranPrelisteState extends State<EcranPreliste> {
  final etat = Etat.instance;
  late String magasinId;
  final nom = TextEditingController();
  final debut = DateTime.now();
  bool nomModifie = false;
  bool personnalisee = false;
  bool types = false;

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
    if (!nomModifie) nom.text = etat.nomLibre(etat.nomParDefaut(magasinId, debut));
  }

  /// Supprimée d'un glissement ; « Annuler » dans le message la remet.
  void _supprimerListeType(ListeType t) {
    final etat = Etat.instance;
    final place = etat.listesTypes.indexOf(t);
    setState(() => etat.supprimerListeType(t));
    Nav.message(context, 'Liste type « ${t.nom} » supprimée', annuler: () {
      if (mounted) setState(() => etat.remettreListeType(t, place));
    });
  }

  void _creer(List<LigneListe> lignes) {
    final texte = nom.text.trim().isEmpty ? etat.nomLibre(etat.nomParDefaut(magasinId, debut)) : nom.text.trim();
    if (etat.nomPris(texte)) {
      Nav.message(context, 'Une liste s\'appelle déjà « $texte » : choisissez un autre nom.');
      return;
    }
    final l = etat.creerListe(magasinId, lignes, nom: texte);
    Nav.remplacerTravail(EcranConstruction(listeId: l.id));
  }

  void _calculee() => showDialog<void>(
        context: context,
        barrierColor: Charte.voile,
        builder: (ctx) => AlertDialog(
          backgroundColor: Charte.fond,
          title: Text('Liste calculée', style: Charte.texte(18, gras: true)),
          content: Text(
              'La liste calculée à partir de vos tickets de caisse (lecture des tickets, puis choix des produits '
              'achetés régulièrement) est prévue dans une version future.',
              style: Charte.texte(16)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Compris', style: Charte.texte(16, gras: true)))],
        ),
      );

  /// Liste personnalisée : les articles d'une course passée, aucun coché d'avance ; on coche ceux à reprendre.
  Future<void> _voirCourse(Liste ancienne) async {
    final lignes = etat.lignesReprises(ancienne);
    final choisis = <int>{};
    final ok = await modale(
      context,
      titre: 'Liste personnalisée',
      icone: Icons.history,
      oui: 'Créer la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Courses du ${quandJour(etat.dateCourses(ancienne))} · cochez les articles à reprendre.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          Align(
            alignment: Alignment.centerRight,
            child: Lien(choisis.length == lignes.length ? 'Tout décocher' : 'Tout cocher', onTap: () => maj(() {
              if (choisis.length == lignes.length) {
                choisis.clear();
              } else {
                choisis.addAll([for (var i = 0; i < lignes.length; i++) i]);
              }
            })),
          ),
          for (var i = 0; i < lignes.length; i++)
            if (etat.produit(lignes[i].produitId) case final p?)
              CaseModale(
                texte: '${p.nom}${lignes[i].quantite > 1 ? ' × ${lignes[i].quantite}' : ''}',
                aide: etat.complement(lignes[i], p).isEmpty ? null : etat.complement(lignes[i], p),
                coche: choisis.contains(i),
                onChange: (v) => maj(() => v ? choisis.add(i) : choisis.remove(i)),
              ),
        ],
      ),
    );
    if (ok && mounted) _creer([for (var i = 0; i < lignes.length; i++) if (choisis.contains(i)) lignes[i]]);
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
        Container(height: 1, color: Charte.separateurZone),
      ],
      corps: ListView(
        children: [
          GroupeRetractable(
            cle: 'preliste/depart',
            titre: 'Type de liste',
            icone: Icons.playlist_add,
            nombre: 3,
            enfants: [
              LigneMenu(
                icone: Icons.note_add_outlined,
                titre: 'Liste type',
                sousTitre: 'Une de vos listes types, ou la liste complète pour en construire une',
                onTap: () => setState(() => types = !types),
                droite: Icon(types ? Icons.expand_less : Icons.expand_more, color: Charte.couleurIcone(Icons.expand_more)),
              ),
              LigneMenu(
                icone: Icons.history,
                titre: 'Liste personnalisée',
                sousTitre: 'Choisir dans une de vos dernières courses (rien n\'est coché d\'avance)',
                onTap: () => setState(() => personnalisee = !personnalisee),
                droite: Icon(personnalisee ? Icons.expand_less : Icons.expand_more, color: Charte.couleurIcone(Icons.expand_more)),
              ),
              LigneMenu(
                icone: Icons.calculate_outlined,
                titre: 'Liste calculée',
                sousTitre: 'À partir de vos tickets de caisse · prévue plus tard',
                onTap: _calculee,
              ),
            ],
          ),
          if (types)
            GroupeRetractable(
              cle: 'preliste/types',
              titre: 'Listes types',
              icone: Icons.note_add_outlined,
              nombre: etat.listesTypes.length,
              enfants: [
                LigneMenu(
                  icone: Icons.format_list_bulleted,
                  titre: 'Liste complète',
                  sousTitre: 'Tous les articles du magasin, rayon par rayon : vous choisissez. '
                      'À la fin, vous pourrez l\'enregistrer comme liste type.',
                  onTap: () => _creer([]),
                ),
                for (final t in etat.listesTypes)
                  Glissable(
                    key: ValueKey('glisser-${t.id}'),
                    titre: t.nom,
                    versGauche: ActionLigne(Icons.delete_outline, 'Supprimer', () => _supprimerListeType(t), danger: true),
                    actions: [
                      ActionLigne(Icons.playlist_add, 'Partir de cette liste type', () => _creer(etat.lignesDeListeType(t))),
                      ActionLigne(Icons.delete_outline, 'Supprimer la liste type', () => _supprimerListeType(t), danger: true),
                    ],
                    child: LigneMenu(
                    icone: Icons.note_alt_outlined,
                    titre: t.nom,
                    sousTitre: '${t.lignes.length} article${t.lignes.length > 1 ? 's' : ''}'
                        '${t.magasinId == magasinId ? '' : ' · faite pour ${etat.magasin(t.magasinId)?.nom ?? 'un autre magasin'}'}',
                    onTap: () => _creer(etat.lignesDeListeType(t)),
                  )),
              ],
            ),
          if (personnalisee)
            GroupeRetractable(
              cle: 'preliste/dernieres',
              titre: 'Dernières courses dans ce magasin',
              icone: Icons.history,
              nombre: passees.length,
              vide: 'Aucune course terminée avec ses articles dans ce magasin.',
              enfants: [
                for (final c in passees)
                  LigneMenu(
                    icone: Icons.receipt_long_outlined,
                    titre: etat.nomListe(c),
                    sousTitre: '${c.lignes.length} articles · ${quandJour(etat.dateCourses(c))} · touchez pour choisir',
                    onTap: () => _voirCourse(c),
                  ),
              ],
            ),
        ],
      ),
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

/// Un élément de la liste de préparation : titre de rayon, titre de secteur, produit, ou « + Produit absent ».
class _Element {
  _Element.rayon(Rayon this.rayon) : secteur = null, produit = null, absent = false;
  _Element.titre(this.secteur) : rayon = null, produit = null, absent = false;
  _Element.produit(this.secteur, Produit this.produit) : rayon = null, absent = false;
  _Element.absent(Secteur this.secteur) : rayon = null, produit = null, absent = true;
  final Rayon? rayon;
  final Secteur? secteur; // null : « Non placé »
  final Produit? produit;
  final bool absent;
  bool get titreSecteur => rayon == null && produit == null && !absent;
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
    // À l'ouverture, rayons et secteurs sont repliés ; à la reprise, seul celui où l'on s'était arrêté s'ouvre.
    Retractables.i.fixer(_toutesLesCles(l), false);
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

  /// Rayons, puis leurs secteurs, puis leurs produits : chaque niveau se déplie au doigt.
  List<_Element> _elements(Liste l) {
    final res = <_Element>[];
    String? rayonCourant;
    for (final s in _secteurs(l)) {
      final produits = [
        for (final p in etat.produitsDu(l.magasinId, s.id))
          if (!maListe || etat.ligne(l, p.id) != null) p,
      ]..sort((a, b) => ordreAlpha(a.nom).compareTo(ordreAlpha(b.nom)));
      if (maListe && produits.isEmpty) continue;
      if (s.rayonId != rayonCourant) {
        rayonCourant = s.rayonId;
        final r = etat.rayon(s.rayonId);
        if (r != null) res.add(_Element.rayon(r));
      }
      if (!Retractables.i.ouvert(_cleRayon(s.rayonId))) continue;
      res.add(_Element.titre(s));
      if (!Retractables.i.ouvert(_cle(s.id))) continue;
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
      if (Retractables.i.ouvert(_cle('nonPlace'))) for (final p in nonPlaces) {
        res.add(_Element.produit(null, p));
      }
    }
    return res;
  }

  String _cle(String secteurId) => 'preparation/${widget.listeId}/$secteurId';
  String _cleRayon(String rayonId) => 'preparation/${widget.listeId}/rayon/$rayonId';

  List<String> _toutesLesCles(Liste l) => [
        for (final s in _secteurs(l)) ...[_cle(s.id), _cleRayon(s.rayonId)],
        _cle('nonPlace'),
      ];

  /// Un seul rayon ouvert : ouvrir un rayon replie les autres rayons et tous les secteurs.
  void _ouvrirRayon(Liste l, String rayonId) {
    Retractables.i.tous([
      for (final s in _secteurs(l)) ...[_cle(s.id), if (s.rayonId != rayonId) _cleRayon(s.rayonId)],
      _cle('nonPlace'),
    ], false);
    if (!Retractables.i.ouvert(_cleRayon(rayonId))) Retractables.i.basculer(_cleRayon(rayonId));
  }

  /// Un seul secteur ouvert : ouvrir un secteur replie les autres (et ouvre son rayon, seul).
  void _ouvrirSeul(Liste l, String secteurId) {
    final rayonId = etat.secteur(secteurId)?.rayonId;
    Retractables.i.tous([
      for (final s in _secteurs(l)) ...[
        if (s.id != secteurId) _cle(s.id),
        if (s.rayonId != rayonId) _cleRayon(s.rayonId),
      ],
      if (secteurId != 'nonPlace') _cle('nonPlace'),
    ], false);
    if (rayonId != null && !Retractables.i.ouvert(_cleRayon(rayonId))) Retractables.i.basculer(_cleRayon(rayonId));
    if (!Retractables.i.ouvert(_cle(secteurId))) Retractables.i.basculer(_cle(secteurId));
  }

  final _lignes = <String, GlobalKey>{};

  /// Fenêtre de l'article ; un article non choisi est d'abord coché (décoché si l'on abandonne).
  /// Si un nouvel article est créé (marque, packaging), l'écran reste sur lui.
  Future<void> _modifier(Liste l, Produit p) async {
    final ajoute = etat.ligne(l, p.id) == null;
    if (ajoute) etat.basculer(l, p.id);
    final q = await detailsArticle(context, l, p);
    if (q == null) {
      if (ajoute && etat.ligne(l, p.id) != null) etat.basculer(l, p.id);
      return;
    }
    if (q.id == p.id || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _lignes[q.id]?.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c, alignment: 0.3);
    });
  }

  /// Fait venir le bandeau d'un secteur en haut de l'écran (hauteurs estimées, puis ajustement).
  void _allerA(Liste l, Secteur s, {bool noter = true}) {
    if (noter) etat.positionConstruction(l, s.rayonId, s.id);
    _ouvrirSeul(l, s.id);
    if (!_defilement.hasClients) return;
    final elements = _elements(l);
    var y = 0.0;
    for (final e in elements) {
      if (e.titreSecteur && e.secteur?.id == s.id) break;
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

  /// Fenêtre modale « Liste prête » : récapitulatif, envoi par mail éventuel, puis la liste passe dans Courses.
  Future<void> _valider(Liste l) async {
    var envoyer = false;
    var pourCourses = true;
    var enListeType = false;
    final nomType = TextEditingController(text: etat.nomListe(l));
    final nbSecteurs = {for (final g in l.lignes) etat.secteurDe(l.magasinId, g.produitId)?.id}.length;
    final ok = await modale(
      context,
      titre: 'Fin de la liste',
      icone: Icons.checklist,
      oui: 'Valider',
      non: 'Continuer la préparation',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${etat.nomListe(l)} : ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} '
              'dans $nbSecteurs secteur${nbSecteurs > 1 ? 's' : ''}.', style: Charte.texte(16)),
          const SizedBox(height: 6),
          const SizedBox(height: 6),
          CaseModale(
            texte: 'Prête pour les courses',
            aide: 'Elle passe en instance de courses ; vous pourrez encore la remettre en préparation.',
            coche: pourCourses,
            onChange: (v) => maj(() => pourCourses = v),
          ),
          CaseModale(
            texte: 'Enregistrer comme liste type',
            aide: 'Proposée ensuite dans « Liste type » pour une nouvelle liste.',
            coche: enListeType,
            onChange: (v) => maj(() => enListeType = v),
          ),
          if (enListeType)
            Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 6),
              child: TextField(
                key: const ValueKey('nom-liste-type'),
                controller: nomType,
                style: Charte.texte(16),
                decoration: const InputDecoration(labelText: 'Nom de la liste type'),
              ),
            ),
          if (pourCourses)
            CaseModale(
              texte: 'Envoyer la liste par mail',
              aide: etat.envoiFoyer ? 'À tout le foyer' : null,
              coche: envoyer,
              onChange: (v) => maj(() => envoyer = v),
            ),
        ],
      ),
    );
    final nom = nomType.text.trim();
    if (!ok || !mounted) return;
    if (enListeType && nom.isNotEmpty) etat.enregistrerListeType(l, nom);
    if (!pourCourses) {
      if (enListeType && nom.isNotEmpty) Nav.message(context, 'Liste type « $nom » enregistrée');
      return;
    }
    if (envoyer) await envoyerListe(etat, l);
    etat.listePrete(l);
    Nav.i.retourOnglet(Nav.courses);
    if (mounted) {
      Nav.message(context, '${enListeType && nom.isNotEmpty ? 'Liste type « $nom » enregistrée. ' : ''}'
          'Liste prête : elle est dans l\'onglet Courses');
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
      listenable: Listenable.merge([etat, Retractables.i]),
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
          Bouton(texte: 'Liste prête', plein: !maListe, onTap: () => _valider(l)),
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
            BoutonReduire(cles: _toutesLesCles(l)),
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
          if (e.titreSecteur && e.secteur != null) numeros[e.secteur!.id] = numeros.length + 1;
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
                    if (e.rayon != null) {
                      final r = e.rayon!;
                      final cle = _cleRayon(r.id);
                      return TitreGroupe(
                        nom: r.nom,
                        image: cleRayon(r.nom),
                        icone: Icons.view_week_outlined,
                        fort: true,
                        nombre: l.lignes.where((g) => etat.secteurDe(l.magasinId, g.produitId)?.rayonId == r.id).length,
                        ouvert: Retractables.i.ouvert(cle),
                        onTap: () => Retractables.i.ouvert(cle) ? Retractables.i.basculer(cle) : _ouvrirRayon(l, r.id),
                      );
                    }
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
                      nombre: s == null ? null : etat.nbDansSecteur(l, s.id),
                      ouvert: Retractables.i.ouvert(_cle(s?.id ?? 'nonPlace')),
                      onTap: () => Retractables.i.ouvert(_cle(s?.id ?? 'nonPlace'))
                          ? Retractables.i.basculer(_cle(s?.id ?? 'nonPlace'))
                          : _ouvrirSeul(l, s?.id ?? 'nonPlace'),
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
    void basculer() {
      etat.basculer(l, p.id);
      final s = etat.secteurDe(l.magasinId, p.id);
      if (s != null) etat.positionConstruction(l, s.rayonId, s.id);
    }

    // Glisser vers la droite ajoute l'article, vers la gauche le retire ; appui long : menu.
    final ajouter = ActionLigne(Icons.add_shopping_cart, 'Ajouter', basculer);
    final retirer = ActionLigne(Icons.remove_shopping_cart_outlined, 'Retirer', basculer, danger: true);
    return Glissable(
      key: ValueKey('glisser-${p.id}'),
      titre: p.nom,
      versDroite: g == null ? ajouter : null,
      versGauche: g == null ? null : retirer,
      actions: [
        if (g == null) ajouter else retirer,
        ActionLigne(Icons.edit_note, 'Packaging, promotion, marque', () => _modifier(l, p)),
      ],
      child: LigneChoix(
      key: _lignes.putIfAbsent(p.id, GlobalKey.new),
      nom: p.nom,
      // Packaging, promotion et consigne en clair sous le nom ; l'icône à droite de la coche les modifie.
      complement: [
        etat.complement(g, p),
        if (g?.promotion != null)
          g!.promotion!.libelle.isNotEmpty ? g.promotion!.libelle : (etat.typePromotion(g.promotion!.type)?.nom ?? 'promo'),
        if (g?.consigne != null) '« ${g!.consigne} »',
      ].where((x) => x.isNotEmpty).join(' · '),
      coche: g != null,
      quantite: g?.quantite ?? 1,
      onDetails: g == null ? null : () => _modifier(l, p),
      onNom: () => _modifier(l, p),
      habituel: p.nbUtilisations >= seuilHabituel,
      alerte: g == null ? null : etat.quantiteInsuffisante(g),
      onTap: basculer,
      onQuantite: (q) => etat.quantite(l, p.id, q),
    ));
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

/// Clé de tri alphabétique : sans majuscules ni accents (« Œufs » avec les O).
String ordreAlpha(String nom) {
  const accents = {'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae'};
  return nom.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

/// Fenêtre de l'article choisi : mesure et lot (packaging), promotion, marque, consigne.
/// Une marque ajoutée ou un packaging changé crée l'article correspondant (« Camembert Président · 250 g »).
/// Rend l'article de la ligne après enregistrement (null si abandon).
Future<Produit?> detailsArticle(BuildContext context, Liste l, Produit p) async {
  final etat = Etat.instance;
  final g = etat.ligne(l, p.id);
  if (g == null) return null;
  var (mesure, lot) = Etat.mesureEtLot(etat.packaging(g.packagingId)?.libelle);
  var promo = g.promotion?.type ?? '';
  final precision = TextEditingController(text: g.promotion?.libelle ?? '');
  final marque = TextEditingController();
  final consigne = TextEditingController(text: g.consigne ?? '');
  final mesures = etat.mesuresProposees(p);
  final lots = etat.lotsProposes(p);
  if (mesure != null && !mesures.contains(mesure)) mesures.insert(0, mesure);
  if (lot != null && !lots.contains(lot)) lots.insert(0, lot);
  Widget titre(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(t, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      );
  final ok = await modale(
    context,
    titre: p.nom,
    icone: Icons.edit_note,
    oui: 'Enregistrer',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titre('Mesure (poids, contenance, à la pièce…)'),
        ChoixDeroulant<String>(
          valeur: mesure ?? '',
          choix: {'': 'Indifférente', for (final m in mesures) m: m},
          onChange: (v) => maj(() => mesure = v.isEmpty ? null : v),
        ),
        titre('Packaging (nombre d\'articles par lot)'),
        ChoixDeroulant<String>(
          valeur: lot ?? '',
          choix: {'': 'À l\'unité', for (final x in lots) x: x},
          onChange: (v) => maj(() => lot = v.isEmpty ? null : v),
        ),
        titre('Promotion'),
        ChoixDeroulant<String>(
          valeur: promo,
          choix: {'': 'Aucune', for (final t in etat.typesPromotion) t.id: t.nom},
          onChange: (v) => maj(() => promo = v),
        ),
        if (promo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(
              key: const ValueKey('precision-promo'),
              controller: precision,
              style: Charte.texte(16),
              decoration: InputDecoration(labelText: 'Précision (ex. : ${etat.typePromotion(promo)?.exemple ?? ''})'),
            ),
          ),
        titre('Ajouter une marque'),
        TextField(
          key: const ValueKey('marque-article'),
          controller: marque,
          style: Charte.texte(16),
          decoration: InputDecoration(hintText: 'Ex. : Président (crée « ${p.nom} Président »)'),
        ),
        titre('Consigne'),
        TextField(
          key: const ValueKey('consigne-article'),
          controller: consigne,
          style: Charte.texte(16),
          decoration: const InputDecoration(hintText: 'Ex. : bien mûres, la moins chère'),
        ),
      ],
    ),
  );
  final texteMarque = marque.text.trim();
  final textePrecision = precision.text.trim();
  final texteConsigne = consigne.text;
  if (!ok) return null;
  final avant = g.packagingId;
  final apres = etat.packagingCompose(mesure, lot)?.id;
  etat.definirPackaging(l, p.id, apres);
  final ancienne = g.promotion;
  etat.definirPromotion(
      l,
      p.id,
      promo.isEmpty
          ? null
          : PromotionLigne(promo, ancienne?.type == promo ? ancienne!.parametres : {}, textePrecision));
  etat.definirConsigne(l, p.id, texteConsigne);
  if (texteMarque.isNotEmpty || (apres != null && apres != avant)) {
    final q = etat.produitVariante(l, p,
        marqueNom: texteMarque, packagingId: apres != null && apres != avant ? apres : null);
    if (context.mounted) Nav.message(context, '« ${q.nom} » ajouté au catalogue et à la liste');
    return q;
  }
  return p;
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
      listenable: Listenable.merge([etat, Retractables.i]),
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
            entete: EnTeteTravail(titre: titre, action: BoutonReduire(cles: [for (final x in etapes) _cle(x.id)])),
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
                            ouvert: Retractables.i.ouvert(_cle(x.id)),
                            onTap: () => Retractables.i.basculer(_cle(x.id)),
                          ),
                          if (Retractables.i.ouvert(_cle(x.id)))
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

  String _cle(String etapeId) => 'courses/${widget.listeId}/$etapeId';

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

  /// Écran 9 — « Interrompre les courses ? » ; sans rien de coché, on peut simplement revenir aux listes prêtes.
  Future<void> _pause(BuildContext context, Liste l, Etape e) async {
    // Même sans article coché, la course est interrompue (elle reste dans « Courses interrompues »).
    final interrompre = await confirmer(
      context,
      icone: Icons.pause_circle_outline,
      titre: 'Interrompre les courses ?',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(style: Charte.texte(17), children: [
            const TextSpan(text: 'Rien n\'est perdu : '),
            TextSpan(text: '${l.nbCoches} article${l.nbCoches > 1 ? 's' : ''} coché${l.nbCoches > 1 ? 's' : ''} sur ${l.lignes.length}', style: Charte.texte(17, gras: true)),
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

  /// Fenêtre modale « Terminer les courses » : ce qui est coché, ce qui reste, et le parcours enregistré.
  Future<void> _terminer(BuildContext context, Liste l) async {
    final etat = Etat.instance;
    final reste = [for (final g in l.lignes) if (!g.coche) etat.produit(g.produitId)?.nom ?? ''];
    final secteurs = etat.secteursDansLOrdre(l).length;
    final ok = await modale(
      context,
      titre: 'Terminer les courses ?',
      icone: Icons.flag_outlined,
      oui: 'Terminer les courses',
      non: 'Continuer les courses',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l.nbCoches} article${l.nbCoches > 1 ? 's' : ''} coché${l.nbCoches > 1 ? 's' : ''} sur ${l.lignes.length}.',
              style: Charte.texte(16, gras: true)),
          if (reste.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Non cochés : ${reste.take(8).join(', ')}${reste.length > 8 ? '…' : ''}', style: Charte.texte(15)),
          ],
          if (etat.apprend(l) && secteurs > 0) ...[
            const SizedBox(height: 8),
            Text('Le parcours de ce magasin est enregistré : $secteurs secteur${secteurs > 1 ? 's' : ''} dans l\'ordre de vos passages.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ],
          const SizedBox(height: 8),
          Text('La course attend son ticket de caisse dans l\'onglet Courses (« Terminées sans ticket »).', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ],
      ),
    );
    if (!ok || !context.mounted) return;
    Etat.instance.terminerCourses(l);
    Nav.i.retourOnglet(Nav.courses);
    Nav.message(context, 'Courses terminées : joignez le ticket de caisse pour les classer dans l\'historique');
  }
}

/// Image du secteur d'une étape des courses (aucune pour « Non placé »).
String? imageEtape(Etat etat, Etape e) {
  final r = e.secteur == null ? null : etat.rayon(e.secteur!.rayonId);
  return r == null ? null : cleSecteur(r.nom, e.secteur!.nom);
}
