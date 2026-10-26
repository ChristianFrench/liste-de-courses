import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../donnees/envoi.dart';
import '../donnees/import_texte.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'catalogue.dart' show choisirSecteur, nouveauProduit;

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

  /// Jour prévu des courses : aujourd'hui par défaut.
  late DateTime prevue = DateTime(debut.year, debut.month, debut.day);
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
    if (!nomModifie) nom.text = etat.nomLibre(etat.nomPrevu(magasinId, prevue));
  }

  /// 0 : aujourd'hui, 1 : demain, 2 : un autre jour.
  int get _choixJour {
    final j = DateTime(debut.year, debut.month, debut.day);
    return prevue == j ? 0 : prevue == j.add(const Duration(days: 1)) ? 1 : 2;
  }

  Future<void> _choisirJour(int i) async {
    final j = DateTime(debut.year, debut.month, debut.day);
    DateTime? d = i == 0 ? j : i == 1 ? j.add(const Duration(days: 1)) : null;
    d ??= await showDatePicker(
      context: context,
      initialDate: prevue,
      firstDate: j,
      lastDate: j.add(const Duration(days: 365)),
      helpText: 'Jour prévu des courses',
    );
    if (d == null || !mounted) return;
    setState(() {
      prevue = d!;
      _initialiser();
    });
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

  void _creer(List<LigneListe> lignes, {bool simple = false}) {
    final texte = nom.text.trim().isEmpty ? etat.nomLibre(etat.nomPrevu(magasinId, prevue)) : nom.text.trim();
    if (etat.nomPris(texte)) {
      Nav.message(context, 'Une liste s\'appelle déjà « $texte » : choisissez un autre nom.');
      return;
    }
    final l = etat.creerListe(magasinId, lignes, nom: texte);
    etat.fixerDatePrevue(l, prevue);
    if (simple) etat.marquerSimple(l, true);
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

  /// Liste depuis un texte : on colle le texte, on vérifie ce qui a été reconnu, puis la liste est créée.
  Future<void> _depuisMail() async {
    await chargerCorrespondances();
    if (!mounted) return;
    final texte = TextEditingController();
    final textes = <String>[];
    final lire = await modale(
      context,
      titre: 'Liste depuis un texte',
      icone: Icons.notes,
      oui: 'Lire la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Copiez la liste (mail, message, note…), puis touchez « Coller » : un article par ligne. '
              'Chaque « Coller » ajoute le texte copié à la suite ; plusieurs textes forment une seule liste.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          if (textes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${textes.length} texte${textes.length > 1 ? 's' : ''} déjà ajouté${textes.length > 1 ? 's' : ''}',
                  style: Charte.texte(15, gras: true)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Lien('Ajouter un autre texte', onTap: () {
                if (texte.text.trim().isEmpty) return;
                maj(() {
                  textes.add(texte.text);
                  texte.clear();
                });
              }),
              Lien('Coller', onTap: () async {
                final d = await Clipboard.getData(Clipboard.kTextPlain);
                // Le texte copié s'ajoute à la suite de ce qui est déjà là.
                final t = d?.text?.trim() ?? '';
                if (t.isNotEmpty) maj(() => texte.text = texte.text.trim().isEmpty ? t : '${texte.text.trimRight()}\n$t');
              }),
            ],
          ),
          TextField(
            key: const ValueKey('texte-mail'),
            controller: texte,
            minLines: 6,
            maxLines: 12,
            style: Charte.texte(15),
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Lait\n2 baguettes\nTomates x4…'),
          ),
        ],
      ),
    );
    if (!lire || !mounted) return;
    if (texte.text.trim().isNotEmpty) textes.add(texte.text);
    final lus = consoliderTextes(etat, textes);
    if (lus.isEmpty) {
      Nav.message(context, 'Aucun article trouvé dans ce texte');
      return;
    }
    final choisis = {for (var i = 0; i < lus.length; i++) i};
    final ok = await modale(
      context,
      titre: 'Articles lus',
      icone: Icons.mail_outline,
      oui: 'Créer la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${lus.where((a) => a.produit != null).length} reconnus dans le catalogue, '
              '${lus.where((a) => a.produit == null).length} nouveaux produits. Décochez ce qu\'il ne faut pas garder.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          for (var i = 0; i < lus.length; i++)
            CaseModale(
              texte: '${lus[i].produit?.nom ?? '${lus[i].nom} (nouveau)'}${lus[i].quantite > 1 ? ' × ${lus[i].quantite}' : ''}',
              aide: '${lus[i].mails > 1 ? 'Dans ${lus[i].mails} mails · ' : ''}Lu : ${lus[i].texte}'
                  '${lus[i].marque != null ? ' · marque ${lus[i].marque}' : ''}',
              coche: choisis.contains(i),
              onChange: (v) => maj(() => v ? choisis.add(i) : choisis.remove(i)),
            ),
        ],
      ),
    );
    if (!ok || !mounted) return;
    // Un même produit lu deux fois : une seule ligne, quantités additionnées.
    final lignes = <String, LigneListe>{};
    for (var i = 0; i < lus.length; i++) {
      if (!choisis.contains(i)) continue;
      final a = lus[i];
      final p = a.produit ?? etat.creerProduit(a.nom);
      final g = lignes[p.id];
      if (g != null) {
        g.quantite += a.quantite;
      } else {
        lignes[p.id] = LigneListe(produitId: p.id, quantite: a.quantite, consigne: a.marque);
      }
    }
    _creer(lignes.values.toList());
  }

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
      entete: const EnTeteFenetre(retour: true, icone: Icons.checklist, titre: 'Nouvelle liste', aide: Aides.nouvelleListe),
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
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text('Courses', style: Charte.texte(15))),
              Expanded(
                child: Bascule(
                  options: ['Aujourd\'hui', 'Demain', _choixJour == 2 ? jjmm(prevue) : 'Autre jour'],
                  index: _choixJour,
                  douce: true,
                  onChange: _choisirJour,
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
            nombre: 5,
            enfants: [
              LigneMenu(
                icone: Icons.edit_note,
                titre: 'Liste simple',
                sousTitre: 'Tapez les articles un à un, sans rayons ni secteurs ; rangez-la par rayons à la fin si vous voulez',
                onTap: () => _creer([], simple: true),
              ),
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
                icone: Icons.notes,
                titre: 'Liste depuis un texte',
                sousTitre: 'Collez un texte (mail, message, note) : les articles sont reconnus dans le catalogue',
                onTap: _depuisMail,
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
    // Modes « Condensé » et « Sans détails » : on ne voit que les articles choisis ; « Avec détails » : tout le catalogue.
    maListe = etat.ajoutParRecherche;
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
      if (ordre.contains(s.id)) continue;
      // Un secteur que le parcours ne cite pas (ajouté depuis) se range après les autres secteurs de son rayon.
      final i = ordre.lastIndexWhere((id) => etat.secteur(id)?.rayonId == s.rayonId);
      if (i < 0) {
        ordre.add(s.id);
      } else {
        ordre.insert(i + 1, s.id);
      }
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

  /// Article touché en dernier : il montre ses quatre pastilles (marque, mesure, packaging, promo).
  String? _focus;

  void _montrerLigne(String produitId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _lignes[produitId]?.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c, alignment: 0.3, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    });
  }

  static const _autre = '\u0000autre';
  static const _sans = '\u0000sans';

  /// Pastille « Marque » : « Camembert » devient l'article « Camembert Président » (créé au besoin).
  Future<void> _choisirMarque(Liste l, Produit p) async {
    final g = etat.ligne(l, p.id);
    if (g == null) return;
    final actuelle = etat.marque(g.marqueId)?.nom;
    final v = await choisirDansListe<String>(context, titre: 'Marque · ${etat.nomSansMarque(g, p)}', choix: {
      if (actuelle != null) _sans: 'Sans marque',
      for (final m in etat.marquesProposees(g, p)) m: m,
      _autre: 'Autre marque…',
    });
    if (v == null || !mounted) return;
    var nom = v == _sans ? '' : v;
    if (v == _autre) {
      nom = await demanderTexte(context, titre: 'Marque', aide: 'Ex. : Président') ?? '';
      if (nom.isEmpty || !mounted) return;
    }
    final q = etat.changerMarque(l, p, nom);
    setState(() => _focus = q.id);
    _montrerLigne(q.id);
  }

  /// Pastilles « Mesure » (poids, contenance) et « Packaging » (lot de x).
  Future<void> _choisirPackaging(Liste l, Produit p, {required bool lot}) async {
    final g = etat.ligne(l, p.id);
    if (g == null) return;
    final (mesure, lotActuel) = Etat.mesureEtLot(etat.packaging(g.packagingId)?.libelle);
    final v = await choisirDansListe<String>(context, titre: '${lot ? 'Packaging' : 'Mesure'} · ${p.nom}', choix: {
      '': lot ? 'À l\'unité' : 'Indifférente',
      for (final x in lot ? etat.lotsProposes(p) : etat.mesuresProposees(p)) x: x,
      _autre: lot ? 'Autre packaging…' : 'Autre mesure…',
    });
    if (v == null || !mounted) return;
    var x = v;
    if (v == _autre) {
      x = await demanderTexte(context, titre: lot ? 'Packaging' : 'Mesure', aide: lot ? 'Ex. : lot de 6' : 'Ex. : 500 g') ?? '';
      if (x.isEmpty || !mounted) return;
      if (lot && RegExp(r'^\d+$').hasMatch(x)) x = 'lot de $x';
    }
    final choix = x.isEmpty ? null : x;
    final k = lot ? etat.packagingCompose(mesure, choix) : etat.packagingCompose(choix, lotActuel);
    etat.definirPackaging(l, p.id, k?.id);
  }

  Future<void> _consigne(Liste l, Produit p) async {
    final g = etat.ligne(l, p.id);
    if (g == null) return;
    final t = await demanderTexte(context, titre: 'Consigne · ${p.nom}', initial: g.consigne ?? '', aide: 'Ex. : bien mûres, la moins chère');
    if (t != null) etat.definirConsigne(l, p.id, t);
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

  /// Fenêtre modale « Liste prête » : récapitulatif, envoi par mail éventuel, puis la liste passe dans Courses.
  Future<void> _valider(Liste l) async {
    var envoyer = false;
    var pourCourses = true;
    var enListeType = false;
    final simple = etat.estSimple(l);
    var ranger = etat.estRangee(l);
    final nomType = TextEditingController(text: etat.nomListe(l));
    final commentaire = TextEditingController(text: etat.commentaire(l) ?? '');
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
          TextField(
            key: const ValueKey('commentaire-liste'),
            controller: commentaire,
            style: Charte.texte(16),
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Commentaire (facultatif)', hintText: 'Ex. : passer aussi à la pharmacie'),
          ),
          const SizedBox(height: 6),
          if (simple)
            CaseModale(
              texte: 'Ranger par rayons et secteurs',
              aide: 'Pendant les courses, la liste suivra l\'ordre du magasin. Sinon, elle garde l\'ordre de saisie. '
                  'En préparation, elle reste une liste simple.',
              coche: ranger,
              onChange: (v) => maj(() => ranger = v),
            ),
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
    etat.commenter(l, commentaire.text);
    if (simple) etat.ranger(l, ranger);
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

  /// « + Produit absent de ce secteur » : son nom suffit ; il est créé, placé ici, coché et touché
  /// (ses pastilles permettent ensuite d'ajouter marque, mesure, packaging, promo).
  Future<void> _produitAbsent(Liste l, Secteur s) async {
    final n = await demanderTexte(context, titre: 'Nouveau produit · ${s.nom}', aide: 'Nom générique (ex. : Riz)', valider: 'Ajouter');
    if (n == null || n.isEmpty || !mounted) return;
    final q = etat.creerProduit(n, secteur: s);
    etat.ajouterLigne(l, q.id);
    setState(() => _focus = q.id);
    Nav.message(context, '« ${q.nom} » ajouté au catalogue et à la liste');
    _montrerLigne(q.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([etat, Retractables.i]),
      builder: (context, _) {
        final l = liste;
        if (l == null) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, titre: 'Liste'),
            corps: Center(child: Text("Cette liste n'existe plus.", style: Charte.texte(16))),
          );
        }
        final simple = etat.estSimple(l);
        final mode = simple ? 'liste' : etat.modePreparation;
        final barre = BarreAction(boutons: [
          Bouton(
            texte: 'Aperçu',
            taille: 15,
            onTap: () => Nav.travail(EcranCoursesSecteur(listeId: l.id, apercu: true)),
          ),
          Bouton(texte: 'Liste prête', plein: true, onTap: () => _valider(l)),
        ]);
        final entete = EnTeteFenetre(
          retour: true,
          icone: Icons.checklist,
          titre: etat.nomListe(l),
          sousTitre: simple
              ? 'Liste simple · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · ${etat.creeeLe(l)}'
              : etat.creeeLe(l),
          aide: simple ? Aides.listeSimple : Aides.preparation,
          deplier: simple ? const [] : _toutesLesCles(l),
          actions: [
            ActionLigne(Icons.mail_outline, 'Envoyer par mail', () async {
              if (!await envoyerListe(etat, l) && context.mounted) {
                Nav.message(context, 'Aucune messagerie n\'a répondu sur cet appareil');
              }
            }),
          ],
        );
        String ou(Produit p) {
          final s = etat.secteurDe(l.magasinId, p.id);
          if (s == null) return 'Non placé dans ce magasin';
          return '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}';
        }

        final recherche = ChampRecherche(
          key: ValueKey('recherche-${l.id}'),
          produits: () => etat.produits,
          detail: ou,
          aide: simple ? 'Ajouter un article (3 lettres ou plus)' : 'Rechercher',
          // Condensé et Sans détails : l'article trouvé s'ajoute ; Avec détails : tout le catalogue, la recherche y amène.
          droite: simple
              ? null
              : SizedBox(
                  width: 150,
                  child: ChoixDeroulant<String>(
                    key: const ValueKey('mode-preparation'),
                    valeur: mode,
                    choix: const {'condense': 'Condensé', 'liste': 'Sans détails', 'detail': 'Avec détails'},
                    onChange: (v) {
                      etat.options(modePreparation: v);
                      setState(() => maListe = v != 'detail');
                    },
                  ),
                ),
          onChoix: (p) => simple
              ? _ajouterSimple(l, p)
              : mode == 'condense'
                  ? _ajouterCondense(l, p)
                  : mode == 'liste'
                      ? _ajouterTrouve(l, p)
                      : _trouver(l, p),
          onNouveau: simple || etat.ajoutParRecherche
              ? (n) async {
                  final p = await nouveauProduit(context, nom: n);
                  if (p == null || !mounted) return;
                  simple ? _ajouterSimple(l, p) : _ajouterTrouve(l, p);
                }
              : null,
        );
        if (simple) {
          return PageBase(
            entete: entete,
            haut: [recherche, Container(height: 1, color: Charte.separateurZone)],
            corps: l.lignes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Tapez le début du nom d\'un article dans le champ ci-dessus : il s\'ajoute en fin de liste.',
                        style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                  )
                : ListView(
                    controller: _defilement,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [for (final g in l.lignes) if (etat.produit(g.produitId) case final p?) _ligne(l, p, simple: true)],
                  ),
            bas: [barre],
          );
        }
        if (mode == 'condense') {
          return PageBase(
            entete: entete,
            haut: [recherche, Container(height: 1, color: Charte.separateurZone)],
            corps: _condense(l),
            bas: [barre],
          );
        }
        if (etat.secteursDuMagasin(l.magasinId).isEmpty) {
          return PageBase(
            entete: entete,
            corps: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Ce magasin n'a pas encore de rayons : le catalogue du foyer est vide (Gérer › Courses › Catalogue).",
                  style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
            bas: [barre],
          );
        }
        final elements = _elements(l);
        final numeros = <String, int>{};
        final premiers = <String, int>{};
        for (var i = 0; i < elements.length; i++) {
          if (elements[i].rayon case final r?) premiers.putIfAbsent(r.id, () => i);
        }
        for (final e in elements) {
          if (e.titreSecteur && e.secteur != null) numeros[e.secteur!.id] = numeros.length + 1;
        }
        Widget element(int i) => _element(l, elements[i], i, numeros, premiers);

        // Le rayon ouvert et son secteur ouvert restent en haut de l'écran pendant que leurs articles défilent.
        final morceaux = <Widget>[];
        var i = 0;
        while (i < elements.length) {
          final e = elements[i];
          if (e.rayon != null && Retractables.i.ouvert(_cleRayon(e.rayon!.id))) {
            final interieur = <Widget>[];
            var j = i + 1;
            while (j < elements.length && elements[j].rayon == null && !(elements[j].titreSecteur && elements[j].secteur == null)) {
              final f = elements[j];
              if (f.titreSecteur && Retractables.i.ouvert(_cle(f.secteur!.id))) {
                var k = j + 1;
                while (k < elements.length && (elements[k].produit != null || elements[k].absent) && elements[k].secteur?.id == f.secteur!.id) {
                  k++;
                }
                interieur.add(SliverMainAxisGroup(slivers: [
                  PinnedHeaderSliver(child: element(j)),
                  SliverList.list(children: [for (var x = j + 1; x < k; x++) element(x)]),
                ]));
                j = k;
              } else {
                interieur.add(SliverToBoxAdapter(child: element(j)));
                j++;
              }
            }
            morceaux.add(SliverMainAxisGroup(slivers: [PinnedHeaderSliver(child: element(i)), ...interieur]));
            i = j;
          } else {
            morceaux.add(SliverToBoxAdapter(child: element(i)));
            i++;
          }
        }

        return PageBase(
          entete: entete,
          haut: [recherche, Container(height: 1, color: Charte.separateurZone)],
          corps: elements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      etat.ajoutParRecherche
                          ? 'Tapez le début du nom d\'un article dans le champ ci-dessus et touchez-le : il s\'ajoute à la liste, '
                              'rangé dans son rayon et son secteur.'
                          : 'La liste est vide.',
                      style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : CustomScrollView(
                  controller: _defilement,
                  slivers: [...morceaux, const SliverPadding(padding: EdgeInsets.only(bottom: 16))],
                ),
          bas: [barre],
        );
      },
    );
  }

  Widget _element(Liste l, _Element e, int i, Map<String, int> numeros, Map<String, int> premiers) {
    final s = e.secteur;
    if (e.rayon != null) {
      final r = e.rayon!;
      final cle = _cleRayon(r.id);
      return TitreGroupe(
        // Un rayon peut revenir plus loin dans le parcours : seule sa première apparition porte la clé.
        key: premiers[r.id] == i ? _titres.putIfAbsent('rayon:${r.id}', GlobalKey.new) : null,
        nom: r.nom,
        image: cleRayon(r.nom),
        icone: Icons.view_week_outlined,
        fort: true,
        nombre: l.lignes.where((g) => etat.secteurDe(l.magasinId, g.produitId)?.rayonId == r.id).length,
        ouvert: Retractables.i.ouvert(cle),
        focus: Retractables.i.ouvert(cle),
        onTap: () {
          if (Retractables.i.ouvert(cle)) {
            Retractables.i.basculer(cle);
          } else {
            _ouvrirRayon(l, r.id);
            _montrer('rayon:${r.id}');
          }
        },
      );
    }
    if (e.produit != null) return _ligne(l, e.produit!);
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
      focus: Retractables.i.ouvert(_cle(s?.id ?? 'nonPlace')),
      onTap: () {
        final id = s?.id ?? 'nonPlace';
        if (Retractables.i.ouvert(_cle(id))) {
          Retractables.i.basculer(_cle(id));
        } else {
          _ouvrirSeul(l, id);
          _montrer(id);
        }
      },
    );
  }

  /// Article choisi dans la recherche : son rayon et son secteur s'ouvrent, la ligne vient à l'écran et se signale.
  void _trouver(Liste l, Produit p) {
    final s = etat.secteurDe(l.magasinId, p.id);
    setState(() {
      maListe = maListe && etat.ligne(l, p.id) != null;
      _surligne = p.id;
      if (etat.ligne(l, p.id) != null) _focus = p.id;
    });
    if (s == null) {
      // Absent des rayons de ce magasin : il rejoint la liste, dans « Non placé ».
      if (etat.ligne(l, p.id) == null) {
        etat.ajouterLigne(l, p.id);
        Nav.message(context, '« ${p.nom} » ajouté à la liste (non placé dans ce magasin)');
      }
      _ouvrirSeul(l, 'nonPlace');
      _montrer('nonPlace');
    } else {
      _allerA(l, s);
    }
    _amener(p.id, essais: 3);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _surligne == p.id) setState(() => _surligne = null);
    });
  }

  /// Mode « Rechercher » : l'article choisi entre dans la liste (s'il n'y est pas) ; on ne voit plus que la liste,
  /// avec seuls son rayon et son secteur ouverts, et l'on est sur l'article, prêt pour la marque, la mesure…
  /// Mode « Condensé » : l'article trouvé s'ajoute (s'il n'y est pas) ; la liste reste serrée.
  void _ajouterCondense(Liste l, Produit p) {
    if (etat.ligne(l, p.id) != null) {
      Nav.message(context, '« ${p.nom} » est déjà dans la liste');
      return;
    }
    etat.ajouterLigne(l, p.id);
    Nav.message(context, '« ${p.nom} » ajouté à la liste');
  }

  /// Mode « Condensé » : la liste comme en magasin, serrée sous de minces bandeaux de secteur ; un P devant
  /// les articles en promotion. Toucher un article passe en « Sans détails », sur cet article.
  Widget _condense(Liste l) {
    final etapes = etat.etapes(l, etat.parcoursParDefaut(l.magasinId, etat.moi.id)?.id);
    if (l.lignes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Tapez le début du nom d\'un article dans le champ ci-dessus et touchez-le : il s\'ajoute à la liste.',
            style: Charte.texte(16, couleur: Charte.texteSecondaire)),
      );
    }
    return ListView(
      controller: _defilement,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final x in etapes) ...[
          Container(
            color: Charte.accent,
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.fromLTRB(16, 4, 14, 4),
            child: Row(children: [
              Expanded(
                  child: Text(x.nom.toUpperCase(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(14, gras: true, couleur: Charte.blanc))),
              Text('${x.lignes.length}', style: Charte.texte(14, gras: true, couleur: Charte.blanc)),
            ]),
          ),
          for (final g in x.lignes)
            if (etat.produit(g.produitId) case final p?)
              InkWell(
                key: ValueKey('condense-${p.id}'),
                onTap: () {
                  etat.options(modePreparation: 'liste');
                  _ajouterTrouve(l, p);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 3, 14, 3),
                  child: Row(children: [
                    SizedBox(
                      width: 22,
                      child: g.promotion == null ? null : Text('P', style: Charte.texte(16, gras: true, couleur: Color(etat.couleurPromotions))),
                    ),
                    Expanded(child: Text(p.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(16))),
                    if (g.quantite > 1) Text('×${g.quantite}', style: Charte.texte(15, gras: true)),
                  ]),
                ),
              ),
        ],
      ],
    );
  }

  void _ajouterTrouve(Liste l, Produit p) {
    final deja = etat.ligne(l, p.id) != null;
    if (!deja) etat.ajouterLigne(l, p.id);
    setState(() {
      maListe = true;
      _focus = p.id;
      _surligne = p.id;
    });
    final s = etat.secteurDe(l.magasinId, p.id);
    if (s == null) {
      _ouvrirSeul(l, 'nonPlace');
      _montrer('nonPlace');
    } else {
      _allerA(l, s);
    }
    _amener(p.id, essais: 3);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _surligne == p.id) setState(() => _surligne = null);
    });
  }

  /// Fait venir la ligne d'un article à l'écran ; si elle n'est pas encore construite (loin dans le secteur),
  /// on descend d'abord par estimation, puis on ajuste.
  void _amener(String produitId, {int essais = 1}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _lignes[produitId]?.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(c, alignment: 0.4, duration: const Duration(milliseconds: 200));
        return;
      }
      if (essais <= 0 || !_defilement.hasClients) return;
      final p = _defilement.position;
      _defilement.jumpTo((p.pixels + p.viewportDimension * 0.8).clamp(0, p.maxScrollExtent));
      _amener(produitId, essais: essais - 1);
    });
  }

  /// Liste simple : l'article choisi s'ajoute en fin de liste (ou, s'il y est déjà, se signale).
  void _ajouterSimple(Liste l, Produit p) {
    final deja = etat.ligne(l, p.id) != null;
    etat.ajouterLigne(l, p.id);
    setState(() {
      _focus = p.id;
      _surligne = p.id;
    });
    if (deja) Nav.message(context, '« ${p.nom} » est déjà dans la liste');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      if (deja) {
        _amener(p.id);
      } else {
        _defilement.animateTo(_defilement.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _surligne == p.id) setState(() => _surligne = null);
    });
  }

  /// Article signalé après une recherche (fond coloré quelques secondes).
  String? _surligne;

  /// Après dépliage, le bandeau monte en haut de l'écran : ce qu'il contient est visible dessous,
  /// même pour le dernier groupe (« Non placé », en fin de liste).
  void _montrer(String cleTitre) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _titres[cleTitre]?.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Article non placé dans ce magasin : on choisit son rayon puis son secteur ; il y rejoint la liste.
  Future<void> _placer(Liste l, Produit p) async {
    final s = (await choisirSecteur(context, titre: p.nom))?.$1;
    if (s == null || !mounted) return;
    etat.placer(l.magasinId, p.id, s.id);
    Nav.message(context, '« ${p.nom} » est placé dans ${s.nom}');
    _allerA(l, s);
  }

  Widget _ligne(Liste l, Produit p, {bool simple = false}) {
    final g = etat.ligne(l, p.id);
    // Non placé : toucher son nom propose un secteur ; il pourra ensuite être coché (pas dans une liste simple).
    final place = simple || etat.secteurDe(l.magasinId, p.id) != null;
    final focus = g != null && _focus == p.id;
    void basculer() {
      etat.basculer(l, p.id);
      final coche = etat.ligne(l, p.id) != null;
      setState(() => _focus = coche ? p.id : (_focus == p.id ? null : _focus));
      final s = etat.secteurDe(l.magasinId, p.id);
      if (s != null) etat.positionConstruction(l, s.rayonId, s.id);
    }

    final (mesure, lot) = Etat.mesureEtLot(etat.packaging(g?.packagingId)?.libelle);
    final promo = g?.promotion;
    final textePromo = promo == null ? null : (promo.libelle.isNotEmpty ? promo.libelle : (etat.typePromotion(promo.type)?.nom ?? 'Promo'));
    final couleurPromo = promo == null ? null : etat.couleurPromo(promo.type);
    final pastilles = <Widget>[
      if (focus) ...[
        Pastille(etat.marque(g.marqueId)?.nom ?? '+ Marque', vide: g.marqueId == null, onTap: () => _choisirMarque(l, p)),
        Pastille(mesure ?? '+ Mesure', vide: mesure == null, onTap: () => _choisirPackaging(l, p, lot: false)),
        Pastille(lot ?? '+ Packaging', vide: lot == null, onTap: () => _choisirPackaging(l, p, lot: true)),
        Pastille(textePromo ?? '+ Promo',
            couleur: couleurPromo == null ? Charte.rouge : Color(couleurPromo),
            vide: promo == null,
            onTap: () => ouvrirFeuillePromotion(context, l, g)),
      ] else if (g != null) ...[
        // Article coché, pas touché en dernier : seulement la mesure et le packaging, s'il y en a.
        if (mesure != null) Pastille(mesure, petite: true),
        if (lot != null) Pastille(lot, petite: true),
      ],
    ];

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
        if (g != null) ActionLigne(Icons.sticky_note_2_outlined, 'Consigne', () => _consigne(l, p)),
        if (!place) ActionLigne(Icons.place_outlined, 'Choisir son secteur', () => _placer(l, p)),
      ],
      child: Container(
      foregroundDecoration: _surligne == p.id ? BoxDecoration(border: Border.all(color: Charte.accent, width: 3)) : null,
      child: LigneChoix(
      key: _lignes.putIfAbsent(p.id, GlobalKey.new),
      nom: g == null ? p.nom : etat.libelleArticle(g, p),
      complement: [
        if (!place) 'Touchez pour choisir son secteur',
        if (g == null) etat.complement(g, p),
        if (g?.consigne != null) '« ${g!.consigne} »',
      ].where((x) => x.isNotEmpty).join(' · '),
      coche: g != null,
      quantite: g?.quantite ?? 1,
      pastilles: pastilles,
      // La promotion, bien visible à gauche de la quantité (quand ses pastilles sont repliées).
      avantQuantite: g == null || focus || textePromo == null
          ? null
          : Container(
              constraints: const BoxConstraints(maxWidth: 76),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: couleurPromo == null ? Charte.rouge : Color(couleurPromo), borderRadius: BorderRadius.circular(5)),
              child: Text(textePromo, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: Charte.texte(11, gras: true, couleur: Charte.blanc)),
            ),
      // Article non choisi : toucher la ligne le coche ; article choisi : il montre (ou replie) ses pastilles.
      onNom: !place
          ? () => _placer(l, p)
          : (g == null ? basculer : () => setState(() => _focus = focus ? null : p.id)),
      habituel: p.nbUtilisations >= seuilHabituel,
      alerte: g == null ? null : etat.quantiteInsuffisante(g),
      onTap: basculer,
      onQuantite: (q) => etat.quantite(l, p.id, q),
    )));
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
            entete: const EnTeteFenetre(retour: true, titre: 'Liste'),
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
          entete: EnTeteFenetre(
            retour: true,
            titre: '${etat.nomListe(l)} · $n article${n > 1 ? 's' : ''}',
            actions: [
              ActionLigne(Icons.mail_outline, 'Envoyer par mail', () async {
                if (!await envoyerListe(etat, l) && context.mounted) {
                  Nav.message(context, 'Aucune messagerie n\'a répondu sur cet appareil');
                }
              }),
            ],
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
  const EcranCoursesSecteur({super.key, required this.listeId, this.apercu = false});
  final String listeId;

  /// Aperçu depuis la préparation : la liste telle qu'elle se présentera en courses, sans coche ni pause.
  final bool apercu;

  static String court(String nom) => nom.split(' ').first;

  @override
  State<EcranCoursesSecteur> createState() => _EcranCoursesSecteurState();
}

/// Courses : une seule liste, dans l'ordre du parcours, secteur par secteur ; on la fait défiler du doigt.
/// « Reste à faire » cache les articles déjà cochés (et les secteurs terminés) ; un nouvel appui remet la liste complète.
class _EcranCoursesSecteurState extends State<EcranCoursesSecteur> {
  bool resteAFaire = false;
  bool _commentaireVu = false;

  /// Fenêtre simple : se ferme par la croix ou un appui à côté.
  Future<void> _commentaire(BuildContext context, String texte) => modale(
        context,
        titre: 'Commentaire',
        icone: Icons.sticky_note_2_outlined,
        oui: null,
        non: null,
        contenu: (context, maj) => Text(texte, style: Charte.texte(17)),
      );
  final _titres = <String, GlobalKey>{};
  bool _place = false;

  /// Aperçu d'une liste simple : sans rayons ni secteurs (ordre de saisie) ou rangée comme en magasin.
  bool? _aplat;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([etat, Retractables.i]),
      builder: (context, _) {
        final l = etat.liste(widget.listeId);
        final apercu = widget.apercu;
        if (l == null || (!apercu && l.statut != StatutListe.enCours)) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, icone: Icons.shopping_cart_outlined, titre: 'Courses'),
            corps: Center(child: Text('Pas de courses en cours.', style: Charte.texte(16))),
          );
        }
        final etapes = etat.etapes(l, apercu ? etat.parcoursParDefaut(l.magasinId, etat.moi.id)?.id : l.parcoursId);
        // Liste simple non rangée : les articles dans l'ordre de saisie, sans bandeaux.
        final simple = etat.estSimple(l);
        final aplat = apercu ? (_aplat ?? simple) : etat.aPlat(l);
        final total = l.lignes.length;
        final titre = apercu
            ? 'Aperçu · $total article${total > 1 ? 's' : ''}'
            : '${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.nbCoches} / $total';
        final commentaire = etat.commentaire(l);
        // Le commentaire de la liste s'affiche une fois à l'ouverture ; l'icône du titre le remontre.
        if (commentaire != null && !_commentaireVu) {
          _commentaireVu = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _commentaire(context, commentaire);
          });
        }
        // Secteur où l'on en est : le premier qui a encore un article à cocher.
        final e = etapes.firstWhere((x) => x.lignes.any((g) => !g.coche), orElse: () => etapes.isEmpty ? Etape(null, []) : etapes.last);
        if (!apercu) _allerALaReprise(l);
        final numeros = <String, int>{};
        for (final x in etapes) {
          if (!x.nonPlace) numeros[x.id] = numeros.length + 1;
        }
        final visibles = [
          for (final x in etapes)
            if (!resteAFaire || x.lignes.any((g) => !g.coche)) x,
        ];

        return PopScope(
          canPop: apercu,
          onPopInvokedWithResult: (aFerme, _) {
            if (!aFerme) _pause(context, l, e);
          },
          child: PageBase(
            entete: EnTeteFenetre(
              retour: true,
              icone: apercu ? Icons.checklist : Icons.shopping_cart_outlined,
              titre: titre,
              aide: apercu ? Aides.apercu : Aides.enMagasin,
              droite: commentaire == null ? null : boutonEnTete(Icons.sticky_note_2_outlined, 'Commentaire', () => _commentaire(context, commentaire)),
              deplier: aplat || apercu ? const [] : [for (final x in etapes) _cle(x.id)],
            ),
            corps: etapes.isEmpty
                ? Center(child: Text('La liste est vide.', style: Charte.texte(16)))
                : aplat
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final g in l.lignes)
                        if (!resteAFaire || !(g.coche || etat.manquant(l, g.produitId))) _ligne(etat, l, g, apercu),
                    ],
                  )
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
                            avancement: apercu ? null : (x.lignes.where((g) => g.coche).length, x.lignes.length),
                            nombre: apercu ? x.lignes.length : null,
                            // Aperçu : toujours tout déployé, sans chevron
                            ouvert: apercu ? null : Retractables.i.ouvert(_cle(x.id)),
                            focus: !apercu && x.id == e.id && l.nbCoches > 0,
                            onTap: apercu ? null : () => Retractables.i.basculer(_cle(x.id)),
                          ),
                          if (apercu || Retractables.i.ouvert(_cle(x.id)))
                            for (final g in x.lignes)
                              if (!resteAFaire || !(g.coche || etat.manquant(l, g.produitId))) _ligne(etat, l, g, apercu),
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
              if (apercu)
                BarreAction(boutons: [
                  if (simple)
                    BoutonEtat(
                      texte: 'Rayons et secteurs',
                      actif: !aplat,
                      onTap: () => setState(() => _aplat = !aplat),
                    ),
                  Bouton(texte: 'Continuer la préparation', plein: true, onTap: () => Navigator.of(context).maybePop()),
                ])
              else
              BarreAction(boutons: [
                BoutonEtat(
                  texte: 'Reste à faire',
                  actif: resteAFaire,
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

  String _cle(String etapeId) => '${widget.apercu ? 'apercu' : 'courses'}/${widget.listeId}/$etapeId';

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

  Widget _ligne(Etat etat, Liste l, LigneListe g, bool apercu) {
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
      coche: !apercu && g.coche,
      quantite: g.quantite,
      promo: g.promotion == null ? null : (etat.typePromotion(g.promotion!.type)?.code ?? '?'),
      pastilles: pastillesLigne(etat, g),
      alerte: etat.quantiteInsuffisante(g),
      manquant: !apercu && etat.manquant(l, p.id),
      onTap: apercu ? null : () => _appui(etat, l, p),
    );
  }

  String? _dernierAppui;
  DateTime _dernierAppuiLe = DateTime(2000);

  /// Un appui coche ou décoche ; deux appuis rapprochés sur le même article le marquent manquant en rayon.
  /// Toucher un article manquant le coche (trouvé finalement).
  void _appui(Etat etat, Liste l, Produit p) {
    final maintenant = DateTime.now();
    final deuxAppuis = _dernierAppui == p.id && maintenant.difference(_dernierAppuiLe) < const Duration(milliseconds: 450);
    _dernierAppui = deuxAppuis ? null : p.id;
    _dernierAppuiLe = maintenant;
    if (deuxAppuis) {
      HapticFeedback.mediumImpact();
      etat.marquerManquant(l, p.id, true);
      Nav.message(context, '« ${p.nom} » : manquant en rayon');
      return;
    }
    if (etat.manquant(l, p.id)) {
      etat.marquerManquant(l, p.id, false);
      if (!(etat.ligne(l, p.id)?.coche ?? true)) etat.cocher(l, p.id);
      return;
    }
    etat.cocher(l, p.id);
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
    final manquants = [for (final g in l.lignes) if (etat.manquant(l, g.produitId)) etat.produit(g.produitId)?.nom ?? ''];
    final reste = [for (final g in l.lignes) if (!g.coche && !etat.manquant(l, g.produitId)) etat.produit(g.produitId)?.nom ?? ''];
    Widget liste(String titre, List<String> noms, Color couleur) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$titre (${noms.length})', style: Charte.texte(15, gras: true, couleur: couleur)),
              for (final n in noms) Text('• $n', style: Charte.texte(15)),
            ],
          ),
        );
    final secteurs = etat.secteursDansLOrdre(l).length;
    // Résumé au foyer : proposé (et coché d'avance) quand d'autres membres ont une adresse.
    final autres = etat.membres.where((m) => m.id != etat.moi.id && m.email.isNotEmpty).isNotEmpty;
    var resume = autres;
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
          if (manquants.isNotEmpty) liste('Manquants en rayon', manquants, Charte.rouge),
          if (reste.isNotEmpty) liste('Non cochés', reste, Charte.encre),
          if (etat.apprend(l) && secteurs > 0) ...[
            const SizedBox(height: 8),
            Text('Le parcours de ce magasin est enregistré : $secteurs secteur${secteurs > 1 ? 's' : ''} dans l\'ordre de vos passages.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ],
          const SizedBox(height: 8),
          Text('La course attend son ticket de caisse dans l\'onglet Courses (« Terminées sans ticket »).', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 4),
          CaseModale(
            texte: 'Envoyer un résumé au foyer',
            aide: 'Votre messagerie s\'ouvre avec le mail prêt pour tous les membres : oubliés, absents des rayons, achetés.',
            coche: resume,
            onChange: (v) => maj(() => resume = v),
          ),
        ],
      ),
    );
    if (!ok || !context.mounted) return;
    // Le résumé se lit avant la fin des courses (la liste garde ses coches et ses manquants).
    if (resume && !await envoyerResume(etat, l) && context.mounted) {
      Nav.message(context, 'Aucune messagerie n\'a répondu sur cet appareil');
    }
    if (!context.mounted) return;
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
