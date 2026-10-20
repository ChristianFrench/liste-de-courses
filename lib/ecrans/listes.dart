import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'corbeille.dart';
import 'travail.dart';

// Onglet Préparer (écran 1), Gérer › Parcours (5), onglet Courses (6).

/// Écran 1 — onglet Préparer.
class SousEcranPreparer extends StatelessWidget {
  const SousEcranPreparer({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final enPreparation = etat.listesStatut(StatutListe.enConstruction);
    final pretes = etat.listesStatut(StatutListe.prete);
    return AvecDecision(
      boutons: [Bouton(texte: '+ Nouvelle liste', plein: true, taille: 18, onTap: () => Nav.travail(const EcranPreliste()))],
      contenu: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          GroupeRetractable(
            cle: 'preparer/enPreparation',
            titre: 'En préparation',
            icone: Icons.edit_note,
            nombre: enPreparation.length,
            vide: 'Aucune liste en préparation.',
            enfants: [
              for (final l in enPreparation)
                LigneMenu(
                  titre: etat.nomListe(l),
                  sousTitre: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · modifiée par '
                      '${etat.membre(l.modifieePar)?.nomAffiche ?? etat.moi.nomAffiche} · '
                      '${l.interrompueLe != null ? quand(l.interrompueLe!) : quandJour(l.modifieeLe ?? l.dateCreation)}',
                  onTap: () => Nav.travail(EcranConstruction(listeId: l.id)),
                  droite: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (l.interrompueLe != null) const Etiquette('Interrompue', pointille: true),
                    BoutonRenommerListe(l),
                    BoutonSupprimerListe(l),
                  ]),
                ),
            ],
          ),
          GroupeRetractable(
            cle: 'preparer/pretes',
            titre: 'Prêtes pour les courses',
            icone: Icons.shopping_cart_outlined,
            nombre: pretes.length,
            vide: 'Aucune liste prête.',
            enfants: [
              for (final l in pretes)
                LigneMenu(
                  titre: etat.nomListe(l),
                  sousTitre: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · prête depuis '
                      '${quandJour(l.modifieeLe ?? l.dateCreation)}',
                  onTap: () => Nav.i.allerOnglet(Nav.courses),
                  droite: Row(mainAxisSize: MainAxisSize.min, children: [
                    BoutonRemettreEnPreparation(l),
                    BoutonSupprimerListe(l),
                  ]),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Une préparation interrompue est conservée telle quelle : touchez-la pour reprendre.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ),
        ],
      ),
    );
  }
}

/// « Magasin 1 · » quand la liste porte un nom choisi (le nom par défaut contient déjà le magasin).
String _magasinSiRenommee(Liste l) =>
    (l.nom == null || l.nom!.isEmpty) ? '' : '${Etat.instance.magasin(l.magasinId)?.nom ?? ''} · ';

class BoutonSupprimerListe extends StatelessWidget {
  const BoutonSupprimerListe(this.liste, {super.key});
  final Liste liste;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Supprimer la liste',
        icon: Icon(Icons.delete_outline, color: Charte.couleurIcone(Icons.delete_outline)),
        onPressed: () => demanderSuppression(context, liste, 'la liste ${Etat.instance.nomListe(liste)}'),
      );
}

class BoutonRenommerListe extends StatelessWidget {
  const BoutonRenommerListe(this.liste, {super.key});
  final Liste liste;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Renommer la liste',
        icon: Icon(Icons.edit_outlined, color: Charte.couleurIcone(Icons.edit_outlined)),
        onPressed: () async {
          final etat = Etat.instance;
          final nom = await demanderTexte(context, titre: 'Nom de la liste', initial: etat.nomListe(liste));
          if (nom != null) etat.renommerListe(liste, nom == etat.nomParDefaut(liste.magasinId, liste.dateCreation) ? '' : nom);
        },
      );
}

class BoutonRemettreEnPreparation extends StatelessWidget {
  const BoutonRemettreEnPreparation(this.liste, {super.key});
  final Liste liste;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Remettre en préparation',
        icon: Icon(Icons.undo, color: Charte.couleurIcone(Icons.undo)),
        onPressed: () {
          Etat.instance.remettreEnPreparation(liste);
          Nav.message(context, '« ${Etat.instance.nomListe(liste)} » est de nouveau en préparation');
        },
      );
}

/// Écran 5 — Gérer › Parcours : d'abord les parcours de la personne, puis le parcours choisi,
/// ordonné par rayon ou par secteur. Enregistrement immédiat.
class SousEcranParcours extends StatefulWidget {
  const SousEcranParcours({super.key});

  @override
  State<SousEcranParcours> createState() => _SousEcranParcoursState();
}

class _SousEcranParcoursState extends State<SousEcranParcours> {
  final etat = Etat.instance;
  int membreIndex = 0;
  String? parcoursId; // null : liste des parcours
  final Set<String> ouverts = {}; // rayons dont les secteurs sont affichés

  @override
  void initState() {
    super.initState();
    membreIndex = etat.membres.indexWhere((m) => m.moi);
    if (membreIndex < 0) membreIndex = 0;
  }

  Membre get membre => etat.membres[membreIndex.clamp(0, etat.membres.length - 1)];

  @override
  Widget build(BuildContext context) {
    final p = etat.unParcours(parcoursId);
    if (p == null) return _liste(context);
    return _edition(context, p);
  }

  Widget _choixMembre() => etat.membres.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Bascule(
            hauteur: 48,
            options: [for (final m in etat.membres) m.nomAffiche],
            index: membreIndex,
            onChange: (i) => setState(() {
              membreIndex = i;
              parcoursId = null;
            }),
          ),
        );

  Widget _liste(BuildContext context) {
    final mes = etat.parcoursDuMembre(membre.id);
    return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _choixMembre()),
          for (final m in etat.magasins)
            GroupeRetractable(
              cle: 'parcours/${m.id}',
              titre: m.nom,
              icone: Icons.storefront_outlined,
              nombre: mes.where((x) => x.magasinId == m.id).length,
              vide: 'Aucun parcours : il s\'enregistre pendant les courses (« Enregistrer le parcours »).',
              enfants: [
                for (final x in mes.where((x) => x.magasinId == m.id))
                  LigneMenu(
                    titre: x.nom,
                    sousTitre: '${x.etapes.length} secteur${x.etapes.length > 1 ? 's' : ''}'
                        '${etat.parcoursAppris.contains(x.id) ? ' · appris pendant les courses' : ''}'
                        '${x.parDefaut ? ' · par défaut' : ''}',
                    onTap: () => setState(() => parcoursId = x.id),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
                'Le parcours s\'apprend pendant les courses : activez « Enregistrer le parcours », l\'ordre dans lequel vous cochez '
                'les articles donne l\'ordre des secteurs. Les courses enregistrées suivantes complètent le parcours appris.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ),
        ],
    );
  }

  Widget _edition(BuildContext context, Parcours p) {
    final runs = _runs(p);
    final items = <_Element>[
      for (var r = 0; r < runs.length; r++) ...[
        _Element(r, null),
        if (ouverts.contains(runs[r].rayonId)) for (final e in runs[r].etapes) _Element(r, e),
      ],
    ];
    final haut = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => parcoursId = null),
              icon: Icon(Icons.chevron_left, color: Charte.couleurIcone(Icons.chevron_left)),
              label: Text('Tous les parcours', style: Charte.texte(15)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: p.nom, style: Charte.texte(19, gras: true)),
                  TextSpan(text: ' · ${etat.magasin(p.magasinId)?.nom ?? ''}', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                ])),
              ),
              IconButton(
                tooltip: 'Renommer le parcours',
                icon: Icon(Icons.edit_outlined, color: Charte.couleurIcone(Icons.edit_outlined)),
                onPressed: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du parcours', initial: p.nom);
                  if (nom != null && nom.isNotEmpty) setState(() => etat.renommerParcours(p, nom));
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Glissez un rayon entier, ou ouvrez-le et glissez un de ses secteurs ailleurs dans le parcours.',
              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 4),
        ],
      ),
    );

    final bas = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Bouton(
            texte: '+ Ajouter un secteur',
            pointille: true,
            taille: 16,
            onTap: () async {
              final restants = etat.secteursDuMagasin(p.magasinId).where((s) => !p.etapes.contains(s.id)).toList();
              if (restants.isEmpty) {
                Nav.message(context, 'Tous les secteurs du magasin sont déjà dans le parcours');
                return;
              }
              final sid = await choisirDansListe<String>(
                context,
                titre: 'Ajouter un secteur',
                choix: {for (final s in restants) s.id: '${s.nom} · ${etat.rayon(s.rayonId)?.nom ?? ''}'},
              );
              if (sid != null) {
                p.etapes.add(sid);
                etat.modifie();
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              etat.definirParDefaut(p, !p.parDefaut);
              setState(() {});
            },
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  CaseACocher(coche: p.parDefaut, taille: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Parcours par défaut pour ce magasin', style: Charte.texte(16))),
                ],
              ),
            ),
          ),
          LienSupprimer(
            texte: 'Supprimer le parcours ${p.nom}',
            onTap: () async {
              if (await demanderSuppression(context, p, 'le parcours ${p.nom}')) setState(() => parcoursId = null);
            },
          ),
        ],
      ),
    );

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      header: haut,
      footer: bas,
      itemCount: items.length,
      onReorderItem: (ancien, nouveau) {
        _deplacer(p, runs, items, ancien, nouveau);
        setState(() {});
      },
      itemBuilder: (context, i) {
        final e = items[i];
        return e.etape == null ? _rayon(context, p, runs, e.run, i) : _secteur(context, p, e.etape!, i);
      },
    );
  }

  /// Passages successifs dans un même rayon : un rayon peut revenir plus loin dans le parcours.
  List<_Passage> _runs(Parcours p) {
    final res = <_Passage>[];
    for (final sid in p.etapes) {
      final r = etat.secteur(sid)?.rayonId ?? '';
      if (res.isEmpty || res.last.rayonId != r) res.add(_Passage(r, []));
      res.last.etapes.add(sid);
    }
    return res;
  }

  /// Applique un glisser-déposer de l'arborescence : un rayon fermé emporte tous ses secteurs,
  /// un rayon ouvert emporte ses secteurs affichés, un secteur se déplace seul.
  void _deplacer(Parcours p, List<_Passage> runs, List<_Element> items, int ancien, int nouveau) {
    final l = [...items];
    final bouge = l.removeAt(ancien);
    var bloc = [bouge];
    if (bouge.etape == null && ouverts.contains(runs[bouge.run].rayonId)) {
      final enfants = <_Element>[];
      while (ancien < l.length && l[ancien].etape != null && l[ancien].run == bouge.run) {
        enfants.add(l.removeAt(ancien));
      }
      if (nouveau > ancien) nouveau -= enfants.length;
      if (nouveau < ancien) {
        // rien à corriger
      }
      bloc = [bouge, ...enfants];
    }
    l.insertAll(nouveau.clamp(0, l.length), bloc);
    p.etapes = [
      for (final e in l)
        if (e.etape != null)
          e.etape!
        else if (!ouverts.contains(runs[e.run].rayonId))
          ...runs[e.run].etapes,
    ];
    etat.modifie();
  }

  Widget _ligneOrdre({required Key key, required int index, required Widget contenu, VoidCallback? onTap, double retrait = 0}) =>
      ReorderableDelayedDragStartListener(
        key: key,
        index: index,
        child: Material(
          color: Charte.fond,
          child: InkWell(
            onTap: onTap,
            child: Container(
              margin: EdgeInsets.only(left: 16 + retrait, right: 16),
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Row(
                children: [
                  Expanded(child: contenu),
                  ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(width: 44, height: 44, child: Icon(Icons.drag_handle, color: Charte.couleurIcone(Icons.drag_handle))),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _rayon(BuildContext context, Parcours p, List<_Passage> runs, int r, int i) {
    final run = runs[r];
    final rayon = etat.rayon(run.rayonId);
    final ouvert = ouverts.contains(run.rayonId);
    final retour = runs.take(r).any((x) => x.rayonId == run.rayonId);
    final img = rayon == null ? null : cleRayon(rayon.nom);
    final n = run.etapes.length;
    return _ligneOrdre(
      key: ValueKey('passage-$r-${run.rayonId}'),
      index: i,
      onTap: () => setState(() => ouvert ? ouverts.remove(run.rayonId) : ouverts.add(run.rayonId)),
      contenu: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Charte.cadre, width: 1.5)),
            child: Text('${r + 1}', style: Charte.texte(14)),
          ),
          const SizedBox(width: 8),
          if (img != null) ...[Pictogramme(img, taille: 44), const SizedBox(width: 10)],
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: rayon?.nom ?? '?', style: Charte.texte(18, gras: true)),
              TextSpan(
                text: ' · $n secteur${n > 1 ? 's' : ''}${retour ? ' (retour)' : ''}',
                style: Charte.texte(14, couleur: Charte.texteSecondaire),
              ),
            ])),
          ),
          Icon(ouvert ? Icons.expand_less : Icons.expand_more, color: Charte.encre),
        ],
      ),
    );
  }

  Widget _secteur(BuildContext context, Parcours p, String sid, int i) {
    final s = etat.secteur(sid);
    final r = etat.rayon(s?.rayonId);
    final img = s == null || r == null ? null : cleSecteur(r.nom, s.nom);
    return _ligneOrdre(
      key: ValueKey('etape-$sid'),
      index: i,
      retrait: 36,
      onTap: () async {
        final retirer = await confirmer(
          context,
          titre: 'Retirer ce secteur ?',
          contenu: Text('« ${s?.nom ?? ''} » ne fera plus partie du parcours « ${p.nom} ».', style: Charte.texte(16)),
          plein: 'Garder',
          contour: 'Retirer du parcours',
        );
        if (retirer == true) {
          p.etapes.remove(sid);
          etat.modifie();
          setState(() {});
        }
      },
      contenu: Row(
        children: [
          if (img != null) ...[Pictogramme(img, taille: 38), const SizedBox(width: 10)],
          Expanded(child: Text(s?.nom ?? '?', style: Charte.texte(16))),
        ],
      ),
    );
  }
}

class _Passage {
  _Passage(this.rayonId, this.etapes);
  final String rayonId;
  final List<String> etapes;
}

class _Element {
  _Element(this.run, this.etape);
  final int run;
  final String? etape; // null : ligne du rayon
}

/// Écran 6 — onglet Courses : les listes prêtes ; un clic montre les consignes éventuelles puis lance les courses.
class SousEcranCourses extends StatefulWidget {
  const SousEcranCourses({super.key});

  @override
  State<SousEcranCourses> createState() => _SousEcranCoursesState();
}

class _SousEcranCoursesState extends State<SousEcranCourses> {
  final etat = Etat.instance;
  late String membreId;

  @override
  void initState() {
    super.initState();
    membreId = etat.moi.id;
  }

  Future<void> _partir(BuildContext context, Liste l) async {
    final avecConsigne = l.lignes.where((g) => g.consigne != null).toList();
    if (avecConsigne.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Charte.voile,
        builder: (ctx) => AlertDialog(
          backgroundColor: Charte.fond,
          title: Text('Consignes · ${etat.nomListe(l)}', style: Charte.texte(18, gras: true)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final g in avecConsigne)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${etat.produit(g.produitId)?.nom ?? ''} : ', style: Charte.texte(16, gras: true)),
                      TextSpan(text: g.consigne, style: Charte.texte(16)),
                    ])),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler', style: Charte.texte(16))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Partir', style: Charte.texte(16, gras: true))),
          ],
        ),
      );
      if (ok != true) return;
    }
    etat.demarrerCourses(l, membreId, etat.parcoursParDefaut(l.magasinId, membreId)?.id);
    Nav.travail(EcranCoursesSecteur(listeId: l.id));
  }

  @override
  Widget build(BuildContext context) {
    final enCours = etat.coursesEnCours;
    final pretes = etat.listesStatut(StatutListe.prete);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (enCours != null)
          GroupeRetractable(
            cle: 'courses/interrompues',
            titre: 'Courses interrompues',
            icone: Icons.pause_circle_outline,
            nombre: 1,
            enfants: [const SizedBox(height: 10), _carteInterrompues(context, enCours), const SizedBox(height: 6)],
          ),
        GroupeRetractable(
          cle: 'courses/pretes',
          titre: 'Listes prêtes',
          icone: Icons.shopping_cart_outlined,
          nombre: pretes.length,
          vide: 'Aucune liste prête : terminez d\'abord une préparation (« Liste prête »).',
          enfants: [
            if (pretes.isNotEmpty && etat.membres.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text('Courses faites par', style: Charte.texte(15)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoixDeroulant<String>(
                        valeur: membreId,
                        choix: {for (final m in etat.membres) m.id: m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche},
                        onChange: (v) => setState(() => membreId = v),
                      ),
                    ),
                  ],
                ),
              ),
            for (final l in pretes)
              LigneMenu(
                titre: etat.nomListe(l),
                sousTitre: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}'
                    '${l.lignes.any((g) => g.consigne != null) ? ' · avec consignes' : ''} · touchez pour partir',
                onTap: () => _partir(context, l),
                droite: BoutonRemettreEnPreparation(l),
              ),
          ],
        ),
      ],
    );
  }

  Widget _carteInterrompues(BuildContext context, Liste l) {
    final total = l.lignes.length;
    final faits = l.nbCoches;
    final etape = etat.etapes(l, l.parcoursId).where((e) => e.id == l.repriseSecteurId).toList();
    final arret = etape.isEmpty ? '' : ' · arrêt au secteur ${etape.first.nom}';
    return Carte(
      chevron: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(etat.nomListe(l), style: Charte.texte(18, gras: true))),
              Text('$faits / $total', style: Charte.texte(18, gras: true)),
              BoutonSupprimerListe(l),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Charte.cadre, width: 1.5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total == 0 ? 0 : faits / total,
                child: Container(color: Charte.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${etat.membre(l.membreId)?.nomAffiche ?? ''}$arret'
            '${l.interrompueLe != null ? ' · ${quand(l.interrompueLe!)}' : ''}',
            style: Charte.texte(14, couleur: Charte.texteSecondaire),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Bouton(
              texte: 'Reprendre les courses',
              plein: true,
              onTap: () => Nav.travail(EcranCoursesSecteur(listeId: l.id)),
            ),
          ),
        ],
      ),
    );
  }
}
