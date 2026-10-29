import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../donnees/envoi.dart';
import '../donnees/import_texte.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'catalogue.dart' show actionsNonPlace, autreMarque, nouveauProduit, placerNonPlaces;

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

  void _calculee() => modale(
        context,
        titre: 'Liste calculée',
        oui: null,
        non: 'Compris',
        contenu: (context, maj) => Text(
            'La liste calculée à partir de vos tickets de caisse (lecture des tickets, puis choix des produits '
            'achetés régulièrement) est prévue dans une version future.',
            style: Charte.texte(16)),
      );

  /// Liste depuis un texte : on colle le texte, on vérifie ce qui a été reconnu, puis la liste est créée.
  Future<void> _depuisMail() async {
    await chargerCorrespondances();
    if (!mounted) return;
    final texte = TextEditingController();
    final textes = <String>[];
    final lire = await modale(
      context,
      titre: 'Depuis un texte',
      icone: Icons.notes,
      oui: 'Lire la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('texte-mail'),
            controller: texte,
            minLines: 16,
            maxLines: 24,
            style: Charte.texte(15),
            decoration: const InputDecoration(labelText: 'Texte de la liste', hintText: 'Lait\n2 baguettes\nTomates x4…'),
          ),
        ],
      ),
    );
    if (!lire || !mounted) return;
    if (texte.text.trim().isNotEmpty) textes.add(texte.text);
    final rapport = <Difficulte>[];
    final lus = consoliderTextes(etat, textes, rapport: rapport);
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
          if (rapport.isNotEmpty) ...[
            const TitreSection('Compte rendu de la lecture', cote: 0, haut: 12),
            for (final d in rapport)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '« ${d.ligne} » ', style: Charte.texte(14, gras: true)),
                  TextSpan(text: d.explication, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ])),
              ),
            const TitreSection('Articles', cote: 0, haut: 12),
          ],
          for (var i = 0; i < lus.length; i++)
            CaseModale(
              texte: '${lus[i].produit?.nom ?? '${lus[i].nom} (nouveau)'}${lus[i].quantite > 1 ? ' × ${lus[i].quantite}' : ''}',
              aide: '${lus[i].mails > 1 ? 'Dans ${lus[i].mails} mails · ' : ''}Lu : ${lus[i].texte}'
                  '${lus[i].marque != null ? ' · marque ${lus[i].marque}' : ''}'
                  '${lus[i].produit == null && lus[i].secteur != null ? ' · rangé dans ${lus[i].secteur!.nom}' : ''}',
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
      final p = a.produit ?? etat.creerProduit(a.nom, secteur: a.secteur);
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
      titre: 'Depuis une course passée',
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
    final cibles = etat.ciblesRectificative();
    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.checklist, titre: 'Nouvelle liste', aide: Aides.nouvelleListe),
      haut: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          child: Column(
            children: [
              ChoixDeroulant<String>(
                libelle: 'Magasin',
                valeur: magasinId,
                choix: {for (final m in etat.magasins) m.id: m.nom},
                onChange: (v) => setState(() {
                  magasinId = v;
                  _initialiser();
                }),
              ),
              const SizedBox(height: 14),
              ChampDate(
                libelle: 'Date des courses',
                valeur: prevue,
                premier: DateTime(debut.year, debut.month, debut.day),
                dernier: DateTime(debut.year, debut.month, debut.day).add(const Duration(days: 365)),
                onChange: (d) => setState(() {
                  prevue = DateTime(d.year, d.month, d.day);
                  _initialiser();
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('nom-liste'),
                controller: nom,
                style: Charte.texte(16),
                decoration: const InputDecoration(labelText: 'Nom'),
                onChanged: (_) => nomModifie = true,
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
            nombre: 7,
            enfants: [
              LigneMenu(
                icone: Icons.search,
                titre: 'Nouvelle liste, par secteur',
                sousTitre: 'Cherchez les articles un à un : ils se rangent sous leur secteur au fur et à mesure',
                onTap: () => _creer([]),
              ),
              LigneMenu(
                icone: Icons.edit_note,
                titre: 'Nouvelle liste simple',
                sousTitre: 'Tapez les articles un à un, sans rayons ni secteurs ; rangez-la par rayons à la fin si vous voulez',
                onTap: () => _creer([], simple: true),
              ),
              LigneMenu(
                icone: Icons.list_alt,
                titre: 'Depuis une liste type',
                sousTitre: 'Une de vos listes types, ou une liste vide',
                onTap: () => _choisirListeType(),
              ),
              LigneMenu(
                icone: Icons.history,
                titre: 'Depuis une course passée',
                sousTitre: 'Choisir dans une de vos dernières courses',
                onTap: () => _choisirCourse(passees),
              ),
              LigneMenu(
                icone: Icons.notes,
                titre: 'Depuis un texte',
                sousTitre: 'Collez un texte (mail, message, note) : les articles sont reconnus dans le catalogue',
                onTap: _depuisMail,
              ),
              LigneMenu(
                icone: Icons.playlist_add,
                titre: 'Compléter des courses : rectificative',
                sousTitre: cibles.isEmpty
                    ? 'Aucune course en cours à compléter'
                    : 'Des articles à ajouter à des courses en cours',
                onTap: () => cibles.isEmpty
                    ? Nav.message(context, 'Une rectificative complète des courses en cours : il n\'y en a pas.')
                    : _choisirCible(cibles),
              ),
              LigneMenu(
                icone: Icons.calculate_outlined,
                titre: 'Liste calculée',
                sousTitre: 'À partir de vos tickets de caisse · prévue plus tard',
                onTap: _calculee,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// « Liste rectificative » : la liste à rectifier, puis une liste simple (la recherche dans tout le catalogue).
  Future<void> _choisirCible(List<Liste> cibles) => volet<void>(
        context,
        builder: (ctx) => corpsVolet(
          titre: 'Liste à rectifier',
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final c in cibles)
              LigneMenu(
                titre: etat.nomListe(c),
                sousTitre: [
                  c.statut == StatutListe.enCours
                      ? 'En cours de courses · ${etat.membre(c.membreId)?.nomAffiche ?? '?'}'
                      : 'À faire · ${c.lignes.length} art.',
                  if (etat.rectificativeOuvertePour(c) != null) 'rectificative déjà commencée : la reprendre',
                ].join(' · '),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Une seule rectificative à la fois par liste : celle déjà commencée est reprise.
                  final r = etat.rectificativeOuvertePour(c);
                  final l = r == null ? etat.creerRectificative(c) : etat.liste(r.listeId)!;
                  Nav.remplacerTravail(EcranConstruction(listeId: l.id));
                },
              ),
          ]),
        ),
      );

  /// « Liste type » : une liste vide, ou une liste type (glisser vers la gauche la supprime).
  Future<void> _choisirListeType() => volet<void>(
        context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, maj) => corpsVolet(
            titre: 'Depuis une liste type',
            contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LigneMenu(
                titre: 'Liste vide',
                sousTitre: 'les articles par la recherche',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _creer([]);
                },
              ),
              for (final t in etat.listesTypes)
                Glissable(
                  key: ValueKey('glisser-${t.id}'),
                  titre: t.nom,
                  versGauche: ActionLigne(Icons.delete_outline, 'Supprimer', () => maj(() => _supprimerListeType(t)), danger: true),
                  child: LigneMenu(
                    titre: t.nom,
                    sousTitre: '${t.lignes.length} art.${t.magasinId == magasinId ? '' : ' · ${etat.magasin(t.magasinId)?.nom ?? 'autre magasin'}'}',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _creer(etat.lignesDeListeType(t));
                    },
                  ),
                ),
            ]),
          ),
        ),
      );

  /// « Liste personnalisée » : les dernières courses dans ce magasin ; en toucher une montre ses articles.
  Future<void> _choisirCourse(List<Liste> passees) => volet<void>(
        context,
        builder: (ctx) => corpsVolet(
          titre: 'Dernières courses dans ce magasin',
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (passees.isEmpty)
              Text('Aucune course terminée avec ses articles dans ce magasin.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            for (final c in passees)
              LigneMenu(
                titre: etat.nomListe(c),
                sousTitre: '${c.lignes.length} art. · ${quandJour(etat.dateCourses(c))}',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _voirCourse(c);
                },
              ),
          ]),
        ),
      );
}

/// Écran 3 — Construction par secteur. Chaque action est enregistrée ; quitter ne perd rien.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  @override
  State<EcranConstruction> createState() => _EcranConstructionState();
}

/// Préparation : la recherche, puis la liste condensée, la même que pendant les courses : de minces bandeaux
/// de secteur dans l'ordre du parcours (liste simple : sans bandeaux, dans l'ordre de saisie), des lignes de 30.
/// Toucher une ligne ouvre son volet (packaging, promotion, consigne) ; − et + règlent la quantité ;
/// un appui long (ou la quantité 0) retire l'article.
class _EcranConstructionState extends State<EcranConstruction> {
  final etat = Etat.instance;
  final _defilement = ScrollController();
  final _lignes = <String, GlobalKey>{};

  /// Article signalé après une recherche (fond coloré quelques secondes).
  String? _surligne;

  Liste? get liste => etat.liste(widget.listeId);

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = liste;
        if (l == null) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, titre: 'Liste'),
            corps: Center(child: Text("Cette liste n'existe plus.", style: Charte.texte(16))),
          );
        }
        final simple = etat.estSimple(l);
        final n = l.lignes.length;
        String ou(Produit p) {
          final s = etat.secteurDe(l.magasinId, p.id);
          if (s == null) return 'Non placé dans ce magasin';
          return '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}';
        }

        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            titre: etat.nomListe(l),
            sousTitre: '${simple ? 'Liste simple · ' : ''}$n article${n > 1 ? 's' : ''} · ${etat.creeeLe(l)}',
            aide: simple ? Aides.listeSimple : Aides.preparation,
            actions: [
              ActionLigne(Icons.event_outlined, 'Changer le magasin ou la date', () => changerMagasinEtDate(context, l)),
              ActionLigne(Icons.mail_outline, 'Envoyer par mail', () async {
                final r = messageEnvoi(await envoyerListe(etat, l), destinataires(etat).length);
                if (r != null && context.mounted) Nav.message(context, r);
              }),
            ],
          ),
          haut: [
            ChampRecherche(
              key: ValueKey('recherche-${l.id}'),
              produits: () => etat.produits,
              detail: ou,
              aide: 'Ajouter un article (3 lettres ou plus)',
              onChoix: (p) => _ajouter(l, p),
              onNouveau: (nom) async {
                final p = await nouveauProduit(context, nom: nom);
                if (p == null || !mounted) return;
                _ajouter(l, p);
              },
            ),
            Container(height: 1, color: Charte.separateurZone),
          ],
          corps: l.lignes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Tapez le début du nom d\'un article dans le champ ci-dessus et touchez-le : il s\'ajoute à la liste.',
                      style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : ListView(
                  controller: _defilement,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: simple
                      ? [for (final g in l.lignes) _ligne(l, g)]
                      : [
                          for (final x in etat.etapes(l, etat.parcoursParDefaut(l.magasinId, etat.moi.id)?.id)) ...[
                            TitreGroupe(
                              nom: x.nom,
                              nonPlace: x.nonPlace,
                              nombre: x.lignes.length,
                              onTap: x.nonPlace
                                  ? () => placerNonPlaces(context, [for (final g in x.lignes) if (etat.produit(g.produitId) case final p?) p], liste: l)
                                  : null,
                            ),
                            for (final g in x.lignes) _ligne(l, g),
                          ],
                        ],
                ),
          bas: [BarreAction(boutons: [Bouton(texte: 'Liste prête', icone: Icons.check, plein: true, onTap: () => _valider(l))])],
        );
      },
    );
  }

  /// L'article trouvé s'ajoute (s'il n'y est pas) ; l'écran va sur lui et le signale quelques secondes.
  void _ajouter(Liste l, Produit p) {
    if (etat.ligne(l, p.id) == null) etat.ajouterLigne(l, p.id);
    setState(() => _surligne = p.id);
    _amener(p.id, essais: 4);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _surligne == p.id) setState(() => _surligne = null);
    });
  }

  /// Fait venir la ligne d'un article à l'écran ; si elle n'est pas encore construite (loin dans la liste),
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

  /// Appui long (ou quantité 0) : l'article quitte la liste, « Annuler » le remet.
  void _retirer(Liste l, Produit p) {
    final g = etat.ligne(l, p.id);
    if (g == null) return;
    final i = l.lignes.indexOf(g);
    HapticFeedback.mediumImpact();
    etat.quantite(l, p.id, 0);
    Nav.message(context, '« ${p.nom} » retiré de la liste', annuler: () => etat.remettreLigne(l, g, i));
  }

  /// Petit bouton − ou + de la ligne.
  Widget _petitBouton(String signe, String libelle, Key cle, VoidCallback onTap) => Semantics(
        button: true,
        label: libelle,
        child: InkWell(
          key: cle,
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: Charte.ligne,
            child: Center(child: Text(signe, style: Charte.texte(20, gras: true, couleur: Charte.cadre))),
          ),
        ),
      );

  Widget _ligne(Liste l, LigneListe g) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    return LigneArticle(
      key: _lignes.putIfAbsent(p.id, GlobalKey.new),
      cle: ValueKey('condense-${p.id}'),
      ligne: g,
      produit: p,
      surligne: _surligne == p.id,
      onTap: () => ouvrirFeuillePromotion(context, l, g),
      onDetail: () => ouvrirFeuillePromotion(context, l, g),
      // Appui long : retirer ; un produit ajouté par le foyer se corrige aussi (renommer, déplacer, supprimer).
      onLongPress: etat.estAjoute(p)
          ? () => menuActions(context, titre: p.nom, actions: [
                ActionLigne(Icons.remove_circle_outline, 'Retirer de la liste', () => _retirer(l, p)),
                ...actionsNonPlace(context, p, liste: l),
              ])
          : () => _retirer(l, p),
      reglage: Row(mainAxisSize: MainAxisSize.min, children: [
        // − N + : à 0, l'article quitte la liste (« Annuler » le remet).
        _petitBouton('−', 'Moins', ValueKey('moins-${p.id}'),
            () => g.quantite <= 1 ? _retirer(l, p) : etat.quantite(l, p.id, g.quantite - 1)),
        SizedBox(
          width: 26,
          child: Text('${g.quantite}',
              key: ValueKey('quantite-${p.id}'),
              textAlign: TextAlign.center,
              style: Charte.texte(15, gras: g.quantite > 1, couleur: g.quantite > 1 ? Charte.encre : Charte.texteSecondaire)),
        ),
        _petitBouton('+', 'Plus', ValueKey('plus-${p.id}'), () => etat.quantite(l, p.id, g.quantite + 1)),
      ]),
    );
  }

  /// Fenêtre modale « Liste prête » : récapitulatif, envoi par mail éventuel, puis la liste passe dans Courses.
  Future<void> _valider(Liste l) async {
    final r = etat.rectificativeDe(l);
    if (r != null && (r.enRedaction || r.enAttente)) return _validerRectificative(l, r);
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
      oui: 'Valider',
      non: 'Continuer la préparation',
      fermable: false,
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
    final envoi = envoyer ? messageEnvoi(await envoyerListe(etat, l), destinataires(etat).length) : null;
    etat.listePrete(l);
    Nav.i.retourOnglet(Nav.courses);
    if (mounted) {
      Nav.message(context, '${enListeType && nom.isNotEmpty ? 'Liste type « $nom » enregistrée. ' : ''}'
          'Liste prête : elle est dans l\'onglet Courses${envoi == null ? '' : '. $envoi'}');
    }
  }

  /// Fin d'une liste rectificative : ajoutée à la liste visée si ses courses n'ont pas commencé, envoyée à
  /// celui qui les fait sinon ; les courses finies, elle passe en « À faire ».
  Future<void> _validerRectificative(Liste l, Rectificative r) async {
    final cible = etat.liste(r.cibleId);
    final commentaire = TextEditingController(text: etat.commentaire(l) ?? '');
    final pour = cible == null || cible.statut == StatutListe.terminee
        ? 'Les courses visées sont terminées : elle ira dans « À faire ».'
        : cible.statut == StatutListe.enCours
            ? 'Pour ${etat.nomListe(cible)}, en cours de courses par ${etat.membre(cible.membreId)?.nomAffiche ?? '?'} : '
                'il l\'acceptera ou la refusera.'
            : 'Ses articles seront ajoutés à ${etat.nomListe(cible)}.';
    final ok = await modale(
      context,
      titre: 'Liste rectificative',
      oui: 'Valider',
      non: 'Continuer la préparation',
      fermable: false,
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}. $pour', style: Charte.texte(16)),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('commentaire-liste'),
            controller: commentaire,
            style: Charte.texte(16),
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Commentaire (facultatif)'),
          ),
        ],
      ),
    );
    if (!ok || !mounted) return;
    etat.commenter(l, commentaire.text);
    final nomCible = cible == null ? '' : etat.nomListe(cible);
    final fait = etat.validerRectificative(l);
    Nav.i.retourOnglet(fait == 'envoyee' ? Nav.preparer : Nav.courses);
    if (!mounted) return;
    Nav.message(
        context,
        switch (fait) {
          'envoyee' => 'Liste rectificative envoyée à ${etat.membre(cible?.membreId)?.nomAffiche ?? 'celui qui fait les courses'}',
          'fusionnee' => 'Articles ajoutés à $nomCible',
          _ => 'Liste rectificative mise dans « À faire »',
        });
  }
}

/// Une ligne d'article, la même en préparation et en courses (30 points) : le P des promotions, le nom
/// (et la consigne en petit), le packaging en code court, puis la quantité (ou [reglage]).
/// Toucher le P ou le packaging appelle [onDetail] ; toucher le reste de la ligne, [onTap].
class LigneArticle extends StatelessWidget {
  const LigneArticle({
    super.key,
    required this.ligne,
    required this.produit,
    this.cle,
    this.onTap,
    this.onLongPress,
    this.onDetail,
    this.reglage,
    this.coche = false,
    this.manquant = false,
    this.surligne = false,
    this.caseCourse = false,
  });
  final LigneListe ligne;
  final Produit produit;

  /// Clé de la zone sensible de la ligne.
  final Key? cle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDetail;
  final Widget? reglage;
  final bool coche;

  /// Manquant en rayon : nom en rouge, barré.
  final bool manquant;
  final bool surligne;

  /// Pendant les courses : case cochée (un appui) ou croix rouge (manquant, double appui).
  final bool caseCourse;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final g = ligne;
    final k = etat.packagingDe(g, produit);
    final couleurPack = k == null ? null : etat.couleurPack(k.id);
    final couleurPromo = g.promotion == null ? null : etat.couleurPromo(g.promotion!.type);
    final grise = coche || manquant;
    final styleNom = Charte.texte(16, couleur: manquant ? Charte.rouge : (coche ? Charte.texteSecondaire : Charte.encre)).copyWith(
      decoration: grise ? TextDecoration.lineThrough : null,
    );
    // Les petits signes ont une zone de toucher plus large que leur dessin.
    Widget signe(Widget w, String libelle) => Semantics(
          button: true,
          label: libelle,
          child: InkWell(
            onTap: onDetail,
            child: Container(
              height: Charte.ligne,
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: w,
            ),
          ),
        );
    return Material(
      color: surligne ? Charte.fondSelection : Colors.transparent,
      child: InkWell(
        key: cle,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: Charte.ligne,
          padding: const EdgeInsets.only(left: 6, right: 6),
          // Le trait sous la ligne ne prend pas de place : les signes gardent leurs 30 points.
          foregroundDecoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(children: [
            if (caseCourse) ...[
              if (manquant)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Charte.blanc,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Charte.rouge, width: Charte.traitCadre),
                  ),
                  child: Icon(Icons.close, size: 16, color: Charte.rouge),
                )
              else
                CaseACocher(coche: coche, taille: 20),
              const SizedBox(width: 2),
            ],
            SizedBox(
              width: 30,
              child: g.promotion == null
                  ? null
                  : signe(
                      Text('P',
                          key: ValueKey('promo-${produit.id}'),
                          style: Charte.texte(16, gras: true, couleur: couleurPromo == null ? Charte.rouge : Color(couleurPromo))),
                      'Promotion'),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(text: produit.nom, style: styleNom, children: [
                  if (g.consigne != null) TextSpan(text: '  « ${g.consigne} »', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (k != null)
              signe(
                Text(codeCourtPackaging(k.libelle),
                    key: ValueKey('packaging-${produit.id}'),
                    style: Charte.texte(13, gras: true, couleur: couleurPack == null ? Charte.cadre : Color(couleurPack))),
                'Packaging',
              ),
            reglage ??
                SizedBox(
                  width: 30,
                  child: Text('${g.quantite}',
                      textAlign: TextAlign.right,
                      style: Charte.texte(15, gras: g.quantite > 1, couleur: g.quantite > 1 ? Charte.encre : Charte.texteSecondaire)),
                ),
          ]),
        ),
      ),
    );
  }
}

/// Détail d'un article pendant les courses (toucher son P ou son packaging) : en clair, dans un volet.
Future<void> detailArticle(BuildContext context, LigneListe g) {
  final etat = Etat.instance;
  final p = etat.produit(g.produitId);
  final k = p == null ? null : etat.packagingDe(g, p);
  final promo = g.promotion;
  final lignes = [
    'Quantité : ${g.quantite}',
    if (etat.marque(g.marqueId) case final m?) 'Marque : ${m.nom}',
    if (k != null) 'Packaging : ${k.libelle}',
    if (promo != null)
      'Promotion : ${promo.libelle.isNotEmpty ? promo.libelle : (etat.typePromotion(promo.type)?.nom ?? 'promo')}',
    if (g.consigne != null) 'Consigne : ${g.consigne}',
  ];
  return volet<void>(
    context,
    builder: (ctx) => corpsVolet(
      titre: p?.nom ?? 'Article',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final x in lignes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x, style: Charte.texte(17)))],
      ),
    ),
  );
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

/// Volet d'un article de la liste : packaging, consigne et promotion visée.
Future<void> ouvrirFeuillePromotion(BuildContext context, Liste l, LigneListe g) =>
    volet<void>(context, builder: (_) => FeuillePromotion(liste: l, ligne: g));

/// Volet de l'article : le packaging (pack de x), la consigne, puis la promotion visée.
class FeuillePromotion extends StatefulWidget {
  const FeuillePromotion({super.key, required this.liste, required this.ligne});
  final Liste liste;
  final LigneListe ligne;

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

  /// Marque choisie ('' : indifférente) et celle de la ligne à l'ouverture du volet.
  late String marque;
  late final String marqueAvant;

  @override
  void initState() {
    super.initState();
    final p = widget.ligne.promotion;
    type = p?.type ?? FeuillePromotion.aucune;
    packagingId = widget.ligne.packagingId;
    marque = marqueAvant = etat.marque(widget.ligne.marqueId)?.nom ?? '';
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
    _majVolet?.call(() {});
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
    etat.definirPackaging(widget.liste, id, packagingId);
    etat.definirConsigne(widget.liste, id, consigne.text);
    if (type == FeuillePromotion.aucune) {
      etat.definirPromotion(widget.liste, id, null);
    } else {
      final lib = libelle.text.trim().isEmpty ? _auto() : libelle.text.trim();
      etat.definirPromotion(widget.liste, id, PromotionLigne(type, _parametres(), lib));
    }
    // La marque en dernier : « Camembert » devient l'article « Camembert Président ».
    final p = etat.produit(id);
    if (marque != marqueAvant && p != null) etat.changerMarque(widget.liste, p, marque.isEmpty ? null : marque);
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
    // Marques distributeur de l'enseigne du magasin, signalées par l'enseigne
    final mdd = p == null ? const <String>{} : etat.marquesDistributeurPour(m, etat.secteurCatalogue(p.id)).toSet();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p?.nom ?? 'Article', style: Charte.texte(21, gras: true)),
          Text(m?.nom ?? '', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('consigne'),
            controller: consigne,
            style: Charte.texte(17),
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Consigne', hintText: 'Ex. : bien mûres, la moins chère'),
          ),
          if (p != null) ...[
            const SizedBox(height: 14),
            ChoixDeroulant<String>(
              key: const ValueKey('choix-marque'),
              libelle: 'Marque',
              valeur: marque,
              choix: {
                '': 'Indifférente',
                for (final n in {...etat.marquesProposees(widget.ligne, p, magasinId: widget.liste.magasinId), if (marque.isNotEmpty) marque})
                  n: mdd.contains(n) ? '$n · ${etat.enseigneDe(m)}' : n,
                _autre: 'Autre marque…',
              },
              onChange: (v) async {
                if (v != _autre) return setState(() => marque = v);
                final n = await autreMarque(context, etat.secteurCatalogue(p.id));
                if (n == null || !mounted) return;
                setState(() => marque = n);
              },
            ),
          ],
          const SizedBox(height: 14),
          ChoixDeroulant<String>(
            key: const ValueKey('choix-promo'),
            libelle: 'Promotion visée',
            valeur: type,
            choix: {FeuillePromotion.aucune: 'Aucune', for (final t in types) t.id: _nomCourt(t)},
            onChange: (v) {
              _choisirType(v);
              if (v != FeuillePromotion.aucune) _completerPromo();
            },
          ),
          if (type != FeuillePromotion.aucune)
            InkWell(
              key: const ValueKey('complement-promo'),
              onTap: _completerPromo,
              child: Container(
                constraints: const BoxConstraints(minHeight: Charte.ligneListe),
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  Expanded(child: Text(libelle.text.isEmpty ? _auto() : libelle.text, style: Charte.texte(16))),
                  Icon(Icons.edit_outlined, size: 20, color: Charte.couleurIcone(Icons.edit_outlined)),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          ChoixDeroulant<String>(
            key: const ValueKey('choix-packaging'),
            libelle: 'Packaging',
            valeur: packagingId ?? '',
            choix: {
              '': 'Indifférent',
              for (final k in {...proposes, if (packagingId != null) packagingId!}) k: etat.packaging(k)?.libelle ?? '',
              _autre: 'Autre format…',
            },
            onChange: (v) async {
              if (v != _autre) return setState(() => packagingId = v.isEmpty ? null : v);
              if (p != null) await _autreFormat(p, proposes);
            },
          ),
          if (p != null && p.packagingIds.isEmpty && proposes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Formats courants du secteur, ce produit n\'en a pas encore.',
                  style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ),
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
    );
  }

  static const _autre = '\u0000autre';

  void _choisirType(String id) {
    if (type != id) {
      type = id;
      enMontant = false;
      libelleModifie = false;
      // Valeurs proposées pour le type choisi
      c1.text = switch (type) { 'lot' => '3', 'prixGlobal' => '2', _ => '' };
      c2.text = switch (type) { 'lot' => '1', _ => '' };
    }
    _majLibelle();
  }

  StateSetter? _majVolet;

  /// Complément de la promotion (lot, quantité, remise…) et son libellé, dans un volet.
  Future<void> _completerPromo() async {
    await volet<void>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, maj) {
        _majVolet = maj;
        return corpsVolet(
          titre: _nomCourt(etat.typePromotion(type)),
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            ..._champs(),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('libelle-promo'),
              controller: libelle,
              style: Charte.texte(17),
              decoration: const InputDecoration(labelText: 'Libellé'),
              onChanged: (_) => libelleModifie = true,
            ),
          ]),
          boutons: [Bouton(texte: 'OK', plein: true, onTap: () => Navigator.of(ctx).pop())],
        );
      }),
    );
    _majVolet = null;
    if (mounted) setState(() {});
  }

  /// « Autre format… » : un format connu de la famille, ou un nouveau.
  Future<void> _autreFormat(Produit p, List<String> proposes) async {
    final autres = [for (final k in etat.typesPackaging) if (!proposes.contains(k)) k];
    final v = await choisirDansListe<String>(
      context,
      titre: 'Choisir un format',
      choix: {'': '+ Nouveau format…', for (final k in autres) k: etat.packaging(k)?.libelle ?? ''},
    );
    if (v == null || !mounted) return;
    if (v.isNotEmpty) {
      etat.ajouterPackaging(p, etat.packaging(v)!.libelle);
      setState(() => packagingId = v);
      return;
    }
    final lib = await demanderTexte(context, libelle: 'Format', titre: 'Nouveau format', aide: 'Ex. : 500 g, 75 cl, lot de 4, pack de 6');
    if (lib == null || lib.isEmpty || !mounted) return;
    etat.ajouterPackaging(p, lib);
    etat.ajouterTypePackaging(lib);
    setState(() => packagingId = p.packagingIds.last);
  }

  static String _nomCourt(TypePromotion? t) => switch (t?.id) {
        null => 'Aucune',
        'lot' => 'Lot x dont y',
        'prixGlobal' => 'Lot pour promo',
        'remise' => 'Remise',
        _ => t!.nom,
      };

  Widget _nombre(TextEditingController c, String libelle) => TextField(
        controller: c,
        style: Charte.texte(17),
        decoration: InputDecoration(labelText: libelle),
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
          _deux(_nombre(c1, 'Lot de'), _nombre(c2, 'dont gratuits')),
          const SizedBox(height: 6),
          Text('La quantité de la liste est mise au nombre du lot.', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        ];
      case 'prixGlobal':
        return [
          _deux(
            _nombre(c1, 'Quantité à acheter'),
            TextField(
              controller: c2,
              style: Charte.texte(17),
              decoration: const InputDecoration(labelText: 'Avantage', hintText: '2e à −50 %'),
              onChanged: (_) => _majLibelle(),
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
          _nombre(c1, enMontant ? 'Montant (€)' : 'Pourcentage (%)'),
        ];
      default:
        return [Text('Décrivez l\'offre dans le libellé.', style: Charte.texte(14, couleur: Charte.texteSecondaire))];
    }
  }
}

/// Volet « Changer le magasin ou la date » d'une liste en préparation.
Future<void> changerMagasinEtDate(BuildContext context, Liste l) async {
  final etat = Etat.instance;
  var magasinId = l.magasinId;
  final auj = DateTime.now();
  var prevue = etat.datePrevue(l) ?? DateTime(auj.year, auj.month, auj.day);
  final ok = await modale(
    context,
    titre: 'Magasin et date',
    oui: 'Valider',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        ChoixDeroulant<String>(
          key: const ValueKey('changer-magasin'),
          libelle: 'Magasin',
          valeur: magasinId,
          choix: {for (final m in etat.magasins) m.id: m.nom},
          onChange: (v) => maj(() => magasinId = v),
        ),
        const SizedBox(height: 14),
        ChampDate(
          key: const ValueKey('changer-date'),
          libelle: 'Date des courses',
          valeur: prevue,
          premier: DateTime(auj.year, auj.month, auj.day).isAfter(prevue) ? prevue : DateTime(auj.year, auj.month, auj.day),
          dernier: DateTime(auj.year, auj.month, auj.day).add(const Duration(days: 365)),
          onChange: (d) => maj(() => prevue = d),
        ),
      ],
    ),
  );
  if (ok) etat.changerMagasinEtDate(l, magasinId, prevue);
}

/// Clé de tri alphabétique : sans majuscules ni accents (« Œufs » avec les O).
String ordreAlpha(String nom) {
  const accents = {'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae'};
  return nom.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

// ---------------------------------------------------------------- Écrans 8 et 9 : courses

class EcranCoursesSecteur extends StatefulWidget {
  const EcranCoursesSecteur({super.key, required this.listeId});
  final String listeId;

  static String court(String nom) => nom.split(' ').first;

  /// Clignotement de l'icône de la liste rectificative (coupé dans les tests, qui attendent l'immobilité).
  static bool clignoter = true;

  @override
  State<EcranCoursesSecteur> createState() => _EcranCoursesSecteurState();
}

/// Courses : la liste condensée, comme en préparation, dans l'ordre du parcours, sous de minces bandeaux de secteur.
/// Toucher une ligne la coche (elle reste à sa place, grisée et barrée) ; toucher son P ou son packaging en montre
/// le détail ; un appui long propose ses actions.
class _EcranCoursesSecteurState extends State<EcranCoursesSecteur> {
  bool _commentaireVu = false;

  /// Fenêtre simple : se ferme par la poignée ou un appui à côté.
  Future<void> _commentaire(BuildContext context, String texte) => modale(
        context,
        titre: 'Commentaire',
        oui: null,
        non: null,
        contenu: (context, maj) => Text(texte, style: Charte.texte(17)),
      );
  final _titres = <String, GlobalKey>{};
  bool _place = false;

  // ---------------------------------------------- Liste rectificative en attente de décision
  Timer? _clignote;
  Timer? _rappel;
  bool _allume = true;
  String? _rectifSuivie;
  bool _rectifOuverte = false;

  /// L'icône clignote et un résumé s'ouvre (tout de suite, puis toutes les 60 s) tant que la décision n'est pas prise.
  void _suivreRectificative(Rectificative? r) {
    if (r?.listeId == _rectifSuivie) return;
    _rectifSuivie = r?.listeId;
    _clignote?.cancel();
    _rappel?.cancel();
    _clignote = _rappel = null;
    _allume = true;
    if (r == null) return;
    if (EcranCoursesSecteur.clignoter) {
      _clignote = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (mounted) setState(() => _allume = !_allume);
      });
    }
    _rappel = Timer.periodic(const Duration(seconds: 60), (_) => _resumer());
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumer());
  }

  @override
  void dispose() {
    _clignote?.cancel();
    _rappel?.cancel();
    super.dispose();
  }

  Rectificative? _enAttente() {
    final l = Etat.instance.liste(widget.listeId);
    return l == null ? null : Etat.instance.rectificativeEnAttente(l);
  }

  Widget _articlesRectificative(Rectificative r, {int? max}) {
    final etat = Etat.instance;
    final noms = [for (final g in etat.liste(r.listeId)?.lignes ?? const <LigneListe>[]) etat.produit(g.produitId)?.nom ?? ''];
    final vus = max == null || noms.length <= max ? noms : noms.sublist(0, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${etat.membre(r.auteurId)?.nomAffiche ?? 'Un membre'} propose ${noms.length} article${noms.length > 1 ? 's' : ''} '
            'à ajouter à vos courses :', style: Charte.texte(16, gras: true)),
        const SizedBox(height: 6),
        for (final n in vus) Text('• $n', style: Charte.texte(15)),
        if (vus.length < noms.length) Text('… et ${noms.length - vus.length} autre${noms.length - vus.length > 1 ? 's' : ''}', style: Charte.texte(15)),
      ],
    );
  }

  /// Résumé périodique : il propose d'ouvrir la décision.
  Future<void> _resumer() async {
    final r = _enAttente();
    if (!mounted || r == null || _rectifOuverte || ModalRoute.of(context)?.isCurrent == false) return;
    _rectifOuverte = true;
    final voir = await confirmer(
      context,
      titre: 'Liste rectificative',
      contenu: _articlesRectificative(r, max: 6),
      plein: 'Voir et décider',
      contour: 'Plus tard',
    );
    _rectifOuverte = false;
    if (voir == false && mounted) await _decider();
  }

  /// La rectificative s'accepte ou se refuse en entier ; acceptée, ses articles rejoignent la liste
  /// (surlignés dans leur secteur) ou restent à part, en tête.
  Future<void> _decider() async {
    final etat = Etat.instance;
    final r = _enAttente();
    if (r == null || _rectifOuverte) return;
    final auteur = etat.membre(r.auteurId)?.nomAffiche ?? 'un membre';
    _rectifOuverte = true;
    try {
      final refus = await confirmer(context,
          titre: 'Liste rectificative de $auteur', contenu: _articlesRectificative(r), plein: 'Accepter', contour: 'Refuser');
      if (refus == null || !mounted) return;
      if (refus) {
        etat.refuserRectificative(r);
        Nav.message(context, 'Refusée : elle redevient une liste en préparation de $auteur');
        return;
      }
      final aPart = await confirmer(
        context,
        titre: 'Où mettre ces articles ?',
        contenu: Text('Ajoutés à votre liste, ils sont surlignés dans leur secteur. Gardés à part, ils sont groupés en tête, '
            'sous « Ajouts de $auteur ».', style: Charte.texte(16)),
        plein: 'Ajouter à ma liste',
        contour: 'Garder à part',
      );
      if (aPart == null || !mounted) return;
      etat.accepterRectificative(r, fusion: !aPart);
      final n = r.produits.length;
      Nav.message(context, n == 0 ? 'Ces articles étaient déjà dans votre liste' : '$n article${n > 1 ? 's' : ''} ajouté${n > 1 ? 's' : ''}');
    } finally {
      _rectifOuverte = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(widget.listeId);
        if (l == null || l.statut != StatutListe.enCours) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, titre: 'Courses'),
            corps: Center(child: Text('Pas de courses en cours.', style: Charte.texte(16))),
          );
        }
        final etapes = etat.etapes(l, l.parcoursId);
        final rectif = etat.rectificativeEnAttente(l);
        _suivreRectificative(rectif);
        final acceptees = etat.rectificativesAcceptees(l);
        final aPart = {for (final r in acceptees) if (!r.fusion) ...r.produits};
        final fondus = {for (final r in acceptees) if (r.fusion) ...r.produits};
        final ajouts = [
          for (final r in acceptees)
            if (!r.fusion && r.produits.any((id) => etat.ligne(l, id) != null)) ...[
              TitreGroupe(
                  key: ValueKey('ajouts-${r.listeId}'), nom: 'Ajouts de ${etat.membre(r.auteurId)?.nomAffiche ?? '?'}', marque: Icons.playlist_add),
              for (final id in r.produits)
                if (etat.ligne(l, id) case final g?) _ligne(etat, l, g, ajout: true),
            ],
        ];
        // Liste simple non rangée : les articles dans l'ordre de saisie, sans bandeaux.
        final aplat = etat.aPlat(l);
        final total = l.lignes.length;
        final commentaire = etat.commentaire(l);
        // Le commentaire de la liste s'affiche une fois à l'ouverture ; le bouton du titre le remontre.
        if (commentaire != null && !_commentaireVu) {
          _commentaireVu = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _commentaire(context, commentaire);
          });
        }
        // Secteur où l'on en est : le premier qui a encore un article à cocher.
        final e = etapes.firstWhere((x) => x.lignes.any((g) => !g.coche), orElse: () => etapes.isEmpty ? Etape(null, []) : etapes.last);
        _allerALaReprise(l);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (aFerme, _) {
            if (!aFerme) _pause(context, l, e);
          },
          child: PageBase(
            entete: EnTeteFenetre(
              retour: true,
              titre: '${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.nbCoches} / $total',
              aide: Aides.enMagasin,
              droite: commentaire == null && rectif == null
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (rectif != null)
                        KeyedSubtree(
                          key: const ValueKey('bouton-rectificative'),
                          child: AnimatedOpacity(
                            opacity: _allume ? 1 : 0.2,
                            duration: const Duration(milliseconds: 250),
                            child: boutonEnTete(Icons.playlist_add, 'Liste rectificative', _decider),
                          ),
                        ),
                      if (commentaire != null)
                        boutonEnTete(Icons.sticky_note_2_outlined, 'Commentaire', () => _commentaire(context, commentaire)),
                    ]),
            ),
            corps: etapes.isEmpty
                ? Center(child: Text('La liste est vide.', style: Charte.texte(16)))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: aplat
                        ? [
                            ...ajouts,
                            for (final g in l.lignes)
                              if (!aPart.contains(g.produitId)) _ligne(etat, l, g, ajout: fondus.contains(g.produitId)),
                          ]
                        : [
                            ...ajouts,
                            for (final x in etapes)
                              if (x.lignes.any((g) => !aPart.contains(g.produitId))) ...[
                                TitreGroupe(
                                  key: _titres.putIfAbsent(x.id, GlobalKey.new),
                                  nom: x.nom,
                                  nonPlace: x.nonPlace,
                                  onTap: x.nonPlace
                                      ? () => placerNonPlaces(context, [for (final g in x.lignes) if (etat.produit(g.produitId) case final p?) p], liste: l)
                                      : null,
                                  marque: x.lignes.any((g) => fondus.contains(g.produitId)) ? Icons.playlist_add : null,
                                ),
                                for (final g in x.lignes)
                                  if (!aPart.contains(g.produitId)) _ligne(etat, l, g, ajout: fondus.contains(g.produitId)),
                              ],
                          ],
                  ),
            bas: [
              BarreAction(boutons: [
                Bouton(texte: 'Pause', icone: Icons.pause, onTap: () => _pause(context, l, e)),
                Bouton(
                  texte: 'Terminer',
                  icone: Icons.flag_outlined,
                  plein: true,
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

  Widget _ligne(Etat etat, Liste l, LigneListe g, {bool ajout = false}) {
    final p = etat.produit(g.produitId);
    if (p == null) return const SizedBox.shrink();
    final manquant = etat.manquant(l, p.id);
    return LigneArticle(
      key: ValueKey(p.id),
      ligne: g,
      produit: p,
      coche: g.coche,
      manquant: manquant,
      surligne: ajout,
      caseCourse: true,
      onTap: () => _appui(etat, l, p),
      onDetail: () => detailArticle(context, g),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        menuActions(context, titre: p.nom, actions: [
          if (manquant)
            ActionLigne(Icons.check, 'Trouvé finalement', () => _appui(etat, l, p))
          else
            ActionLigne(Icons.remove_circle_outline, 'Manquant en rayon', () {
              etat.marquerManquant(l, p.id, true);
              Nav.message(context, '« ${p.nom} » : manquant en rayon');
            }),
          ActionLigne(Icons.info_outline, 'Détail', () => detailArticle(context, g)),
        ]);
      },
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
      fermable: false,
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
    final envoi = resume ? messageEnvoi(await envoyerResume(etat, l), adressesFoyer(etat).length) : null;
    if (!context.mounted) return;
    Etat.instance.terminerCourses(l);
    Nav.i.retourOnglet(Nav.courses);
    Nav.message(context, '${envoi == null ? '' : '$envoi. '}Courses terminées : joignez le ticket de caisse pour les classer dans l\'historique');
  }
}

// ---------------------------------------------------------------- Consultation d'une liste

/// Consultation seule d'une liste, quel que soit son état (en préparation, à faire, en cours, terminée) :
/// les articles sous leurs bandeaux de secteur, cochés et manquants compris. Toucher un article en montre le détail.
class EcranConsultation extends StatelessWidget {
  const EcranConsultation({super.key, required this.listeId});
  final String listeId;

  static String etatDe(Liste l) => switch (l.statut) {
        StatutListe.enConstruction => 'En préparation',
        StatutListe.prete => 'À faire',
        StatutListe.enCours => 'En cours de courses',
        StatutListe.terminee => 'Terminée',
      };

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
            corps: Center(child: Text('Cette liste n\'existe plus.', style: Charte.texte(16))),
          );
        }
        final avecCoches = l.statut == StatutListe.enCours || l.statut == StatutListe.terminee;
        Widget ligne(LigneListe g) {
          final p = etat.produit(g.produitId);
          if (p == null) return const SizedBox.shrink();
          return LigneArticle(
            key: ValueKey('consulter-${p.id}'),
            ligne: g,
            produit: p,
            coche: avecCoches && g.coche,
            manquant: avecCoches && etat.manquant(l, p.id),
            caseCourse: avecCoches,
            onTap: () => detailArticle(context, g),
            onDetail: () => detailArticle(context, g),
          );
        }

        final commentaire = etat.commentaire(l);
        return PageBase(
          entete: EnTeteFenetre(
            retour: true,
            sousTitre: '${etatDe(l)} · ${etat.magasin(l.magasinId)?.nom ?? ''}',
            titre: etat.nomListe(l),
          ),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (commentaire != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(commentaire, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              if (l.lignes.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('La liste est vide.', style: Charte.texte(16))),
              if (etat.aPlat(l))
                for (final g in l.lignes) ligne(g)
              else
                for (final x in etat.etapes(l, l.parcoursId)) ...[
                  TitreGroupe(nom: x.nom, nonPlace: x.nonPlace, nombre: x.lignes.length),
                  for (final g in x.lignes) ligne(g),
                ],
            ],
          ),
        );
      },
    );
  }
}
