import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'archives.dart';
import 'corbeille.dart';
import 'historique.dart';
import 'travail.dart';

// Onglet Préparer (écran 1), parcours d'un magasin (5), onglet Courses (6).

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
            nombre: enPreparation.length,
            vide: 'Aucune liste en préparation.',
            enfants: [
              for (final l in enPreparation)
                listeGlissable(
                  context,
                  l,
                  LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.'),
                  detail: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · modifiée par '
                      '${etat.membre(l.modifieePar)?.nomAffiche ?? etat.moi.nomAffiche} · '
                      '${l.interrompueLe != null ? 'interrompue ${quand(l.interrompueLe!)}' : quandJour(l.modifieeLe ?? l.dateCreation)}',
                ),
            ],
          ),
          GroupeRetractable(
            cle: 'preparer/pretes',
            titre: 'Prêtes pour les courses',
            nombre: pretes.length,
            vide: 'Aucune liste prête.',
            enfants: [
              for (final l in pretes)
                listeGlissable(
                  context,
                  l,
                  LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.'),
                  detail: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · prête depuis '
                      '${quandJour(l.modifieeLe ?? l.dateCreation)}',
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Touchez une liste pour voir ce que vous pouvez en faire. Glissez-la vers la gauche pour la supprimer, '
                'vers la droite pour la remettre en préparation.',
                style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ),
        ],
      ),
    );
  }
}

/// « Magasin 1 · » quand la liste porte un nom choisi (le nom par défaut contient déjà le magasin).
String _magasinSiRenommee(Liste l) {
  final m = Etat.instance.magasin(l.magasinId)?.nom ?? '';
  return (l.nom == null || l.nom!.isEmpty || l.nom!.contains(m)) ? '' : '$m · ';
}

Future<void> renommerListe(BuildContext context, Liste liste) async {
  final etat = Etat.instance;
  final nom = await demanderTexte(context, titre: 'Nom de la liste', initial: etat.nomListe(liste));
  if (nom == null) return;
  if (etat.nomPris(nom, sauf: liste)) {
    if (context.mounted) Nav.message(context, 'Une liste s\'appelle déjà « $nom » : choisissez un autre nom.');
    return;
  }
  etat.renommerListe(liste, nom == etat.nomParDefaut(liste.magasinId, liste.dateCreation) ? '' : nom);
}

/// Liste prête remise en préparation (rien n'est perdu).
void remettreEnPreparation(BuildContext context, Liste liste) {
  Etat.instance.remettreEnPreparation(liste);
  Nav.message(context, '« ${Etat.instance.nomListe(liste)} » est de nouveau en préparation');
}

/// Courses interrompues remises en préparation : on prévient que les coches seront perdues.
Future<void> coursesEnPreparation(BuildContext context, Liste l) async {
  final etat = Etat.instance;
  final ok = await modale(
    context,
    titre: 'Remettre en préparation ?',
    icone: Icons.undo,
    oui: 'Remettre en préparation',
    contenu: (context, maj) => Text(
        'Les courses de « ${etat.nomListe(l)} » sont arrêtées. Les ${l.nbCoches} article${l.nbCoches > 1 ? 's' : ''} '
        'déjà coché${l.nbCoches > 1 ? 's' : ''} perdront leur coche ; la liste et ses articles sont gardés.',
        style: Charte.texte(16)),
  );
  if (!ok) return;
  etat.coursesEnPreparation(l);
  if (context.mounted) Nav.message(context, '« ${etat.nomListe(l)} » est de nouveau en préparation');
}

/// Gestes d'une liste, partout où elle apparaît : glisser vers la gauche la supprime,
/// vers la droite la remet en préparation (liste prête ou courses interrompues) ; le toucher (ou l'appui long)
/// ouvre son volet : le détail, puis les actions.
Widget listeGlissable(BuildContext context, Liste l, Widget ligne, {bool interrompue = false, String? detail}) {
  final etat = Etat.instance;
  final supprimer =
      ActionLigne(Icons.delete_outline, 'Supprimer', () => supprimerVite(context, l, 'la liste ${etat.nomListe(l)}'), danger: true);
  final renommer = ActionLigne(Icons.edit_outlined, 'Renommer', () => renommerListe(context, l));
  ActionLigne? droite;
  final actions = <ActionLigne>[];
  if (interrompue) {
    actions.add(ActionLigne(Icons.play_arrow_outlined, 'Reprendre les courses', () => Nav.travail(EcranCoursesSecteur(listeId: l.id))));
    droite = ActionLigne(Icons.undo, 'En préparation', () => coursesEnPreparation(context, l));
  } else if (l.statut == StatutListe.prete) {
    actions.add(ActionLigne(Icons.shopping_cart_outlined, 'Faire les courses', () => partirFaireLesCourses(context, l)));
    droite = ActionLigne(Icons.undo, 'En préparation', () => remettreEnPreparation(context, l));
  } else {
    actions.add(ActionLigne(Icons.checklist, 'Continuer la préparation', () => Nav.travail(EcranConstruction(listeId: l.id))));
  }
  if (droite != null) actions.add(ActionLigne(droite.icone, 'Remettre en préparation', droite.faire));
  actions..add(renommer)..add(supprimer);
  return Glissable(
    key: ValueKey('glisser-${l.id}'),
    titre: etat.nomListe(l),
    detail: detail,
    auToucher: true,
    versGauche: supprimer,
    versDroite: droite,
    actions: actions,
    child: ligne,
  );
}

/// Écran 5 — Gérer › Parcours : d'abord les parcours de la personne, puis le parcours choisi,
/// ordonné par rayon ou par secteur. Enregistrement immédiat.
/// Parcours d'un magasin (Gérer › Courses › Magasins › un magasin) : ceux de chaque membre.
class SousEcranParcours extends StatefulWidget {
  const SousEcranParcours({super.key, required this.magasinId});
  final String magasinId;

  @override
  State<SousEcranParcours> createState() => _SousEcranParcoursState();
}

class _SousEcranParcoursState extends State<SousEcranParcours> {
  final etat = Etat.instance;
  int membreIndex = 0;

  @override
  void initState() {
    super.initState();
    membreIndex = etat.membres.indexWhere((m) => m.moi);
    if (membreIndex < 0) membreIndex = 0;
  }

  Membre get membre => etat.membres[membreIndex.clamp(0, etat.membres.length - 1)];

  @override
  Widget build(BuildContext context) {
    final mes = etat.parcoursDuMembre(membre.id).where((x) => x.magasinId == widget.magasinId).toList();
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        if (etat.membres.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Bascule(
              hauteur: 48,
              options: [for (final m in etat.membres) m.nomAffiche],
              index: membreIndex,
              onChange: (i) => setState(() => membreIndex = i),
            ),
          ),
        GroupeRetractable(
          cle: 'parcours/${widget.magasinId}',
          titre: 'Parcours',
          icone: Icons.route_outlined,
          nombre: mes.length,
          vide: 'Aucun parcours : il s\'enregistre pendant les courses (« Enregistrer le parcours »).',
          enfants: [
            for (final x in mes)
              LigneMenu(
                icone: Icons.route_outlined,
                titre: x.nom,
                sousTitre: '${x.etapes.length} secteur${x.etapes.length > 1 ? 's' : ''}'
                    '${etat.parcoursAppris.contains(x.id) ? ' · appris pendant les courses' : ''}'
                    '${x.parDefaut ? ' · par défaut' : ''}',
                onTap: () => Nav.aller<void>(context, EcranParcours(parcoursId: x.id)),
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
}

/// Un parcours : rayons et secteurs dans l'ordre de passage, à réordonner par glisser-déposer.
class EcranParcours extends StatefulWidget {
  const EcranParcours({super.key, required this.parcoursId});
  final String parcoursId;

  @override
  State<EcranParcours> createState() => _EcranParcoursState();
}

class _EcranParcoursState extends State<EcranParcours> {
  final etat = Etat.instance;
  final Set<String> ouverts = {}; // rayons dont les secteurs sont affichés

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: etat,
        builder: (context, _) {
          final p = etat.unParcours(widget.parcoursId);
          if (p == null) {
            return PageBase(
              entete: const EnTeteFenetre(retour: true, icone: Icons.route_outlined, titre: 'Parcours'),
              corps: Center(child: Text('Ce parcours n\'existe plus.', style: Charte.texte(16))),
            );
          }
          return PageBase(
            entete: EnTeteFenetre(
              retour: true,
              icone: Icons.route_outlined,
              sousTitre: 'Parcours · ${etat.magasin(p.magasinId)?.nom ?? ''}',
              titre: p.nom,
              aide: Aides.parcours,
            ),
            corps: _edition(context, p),
            bas: [
              BarreAction(boutons: [
                Bouton(texte: 'Renommer', taille: 15, onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du parcours', initial: p.nom);
                  if (nom != null && nom.isNotEmpty) etat.renommerParcours(p, nom);
                }),
                Bouton(texte: '+ Secteur', taille: 15, onTap: () => _ajouterSecteur(context, p)),
                Bouton(texte: 'Supprimer', taille: 15, onTap: () async {
                  if (await demanderSuppression(context, p, 'le parcours ${p.nom}') && context.mounted) Navigator.of(context).pop();
                }),
              ]),
            ],
          );
        },
      );

  Future<void> _ajouterSecteur(BuildContext context, Parcours p) async {
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
    }
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text('Glissez un rayon entier, ou ouvrez-le et glissez un de ses secteurs ailleurs dans le parcours.',
          style: Charte.texte(13, couleur: Charte.texteSecondaire)),
    );

    final bas = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: InkWell(
        onTap: () => etat.definirParDefaut(p, !p.parDefaut),
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

/// Départ en courses, dans une fenêtre modale : qui fait les courses, quel parcours, enregistrer le parcours,
/// et les consignes à lire avant de partir.
Future<void> partirFaireLesCourses(BuildContext context, Liste l) async {
  final etat = Etat.instance;
  var membreId = etat.moi.id;
  String parcoursDefaut() => etat.parcoursParDefaut(l.magasinId, membreId)?.id ?? '';
  var parcoursId = parcoursDefaut();
  var apprendre = etat.parcoursDe(l.magasinId, membreId).isEmpty;
  final avecConsigne = l.lignes.where((g) => g.consigne != null).toList();
  final ok = await modale(
    context,
    titre: 'Faire les courses',
    icone: Icons.shopping_cart_outlined,
    oui: 'Faire les courses',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${etat.nomListe(l)} · ${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}', style: Charte.texte(16)),
        if (etat.membres.length > 1) ...[
          const SizedBox(height: 12),
          Text('Courses faites par', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ChoixDeroulant<String>(
            valeur: membreId,
            choix: {for (final m in etat.membres) m.id: m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche},
            onChange: (v) => maj(() {
              membreId = v;
              parcoursId = parcoursDefaut();
              apprendre = etat.parcoursDe(l.magasinId, membreId).isEmpty;
            }),
          ),
        ],
        const SizedBox(height: 12),
        Text('Parcours', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ChoixDeroulant<String>(
          valeur: parcoursId,
          choix: {for (final p in etat.parcoursDe(l.magasinId, membreId)) p.id: p.nom, '': 'Ordre des rayons'},
          onChange: (v) => maj(() => parcoursId = v),
        ),
        const SizedBox(height: 4),
        CaseModale(
          texte: 'Enregistrer le parcours',
          aide: 'L\'ordre dans lequel vous cocherez les articles donnera l\'ordre des secteurs de ce magasin.',
          coche: apprendre,
          onChange: (v) => maj(() => apprendre = v),
        ),
        if (avecConsigne.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Consignes', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          for (final g in avecConsigne)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${etat.produit(g.produitId)?.nom ?? ''} : ', style: Charte.texte(16, gras: true)),
                TextSpan(text: g.consigne, style: Charte.texte(16)),
              ])),
            ),
        ],
      ],
    ),
  );
  if (!ok) return;
  etat.demarrerCourses(l, membreId, parcoursId.isEmpty ? null : parcoursId);
  etat.apprendreParcours(l, apprendre);
  Nav.travail(EcranCoursesSecteur(listeId: l.id));
}

/// Écran 6 — onglet Courses : les listes prêtes ; un clic montre les consignes éventuelles puis lance les courses.
class SousEcranCourses extends StatefulWidget {
  const SousEcranCourses({super.key});

  @override
  State<SousEcranCourses> createState() => _SousEcranCoursesState();
}

class _SousEcranCoursesState extends State<SousEcranCourses> {
  final etat = Etat.instance;

  @override
  Widget build(BuildContext context) {
    final enCours = etat.coursesEnCours;
    final pretes = etat.listesStatut(StatutListe.prete);
    final enInstance = etat.coursesEnInstance;

    // Une seule liste, dans l'ordre de la vie d'une liste : à faire, en cours, terminée en attente du ticket,
    // historique, archives. Toucher une ligne ouvre son volet : le détail, puis les actions.
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        GroupeRetractable(
          cle: 'courses/pretes',
          titre: 'À faire',
          nombre: pretes.length,
          vide: 'Aucune liste prête : terminez d\'abord une préparation (« Liste prête »).',
          enfants: [
            for (final l in pretes)
              listeGlissable(
                context,
                l,
                LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.lignes.length} art.'),
                detail: '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}'
                    '${l.lignes.any((g) => g.consigne != null) ? ' · avec consignes' : ''}',
              ),
          ],
        ),
        if (enCours != null)
          GroupeRetractable(
            cle: 'courses/interrompues',
            titre: 'En cours',
            nombre: 1,
            enfants: [_ligneInterrompue(context, enCours)],
          ),
        if (enInstance.isNotEmpty)
          GroupeRetractable(
            cle: 'courses/sansTicket',
            titre: 'Terminées sans ticket',
            nombre: enInstance.length,
            enfants: [
              for (final c in enInstance)
                Glissable(
                  key: ValueKey('glisser-${c.id}'),
                  titre: '${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
                  detail: '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''} · ${etat.membre(c.membreId)?.nomAffiche ?? ''} · '
                      'joignez le ticket pour la classer dans l\'historique',
                  auToucher: true,
                  versDroite: ActionLigne(Icons.upload_file_outlined, 'Joindre le ticket', () => joindreTicket(context, etat, c)),
                  actions: [
                    ActionLigne(Icons.upload_file_outlined, 'Joindre le ticket PDF', () => joindreTicket(context, etat, c)),
                    ActionLigne(Icons.receipt_long_outlined, 'Classer sans ticket', () => _classer(context, c)),
                  ],
                  child: LigneMenu(
                    titre: '${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
                    sousTitre: '${c.nbArticles} art.',
                  ),
                ),
            ],
          ),
        ...groupesPasses(context, etat),
      ],
    );
  }

  Future<void> _classer(BuildContext context, Course c) async {
    final ok = await modale(
      context,
      titre: 'Classer sans ticket',
      oui: 'Classer sans ticket',
      contenu: (context, maj) => Text(
          'La course du ${jjmm(c.dateCourses)} passera dans Courses › Historique sans ticket de caisse. '
          'Vous pourrez encore y joindre le ticket.',
          style: Charte.texte(16)),
    );
    if (ok) etat.classerSansTicket(c);
  }

  Widget _ligneInterrompue(BuildContext context, Liste l) {
    final etape = etat.etapes(l, l.parcoursId).where((e) => e.id == l.repriseSecteurId).toList();
    final arret = etape.isEmpty ? '' : ' · arrêt au secteur ${etape.first.nom}';
    return listeGlissable(
      context,
      l,
      interrompue: true,
      LigneMenu(titre: etat.nomListe(l), sousTitre: '${l.nbCoches} / ${l.lignes.length}'),
      detail: '${l.nbCoches} article${l.nbCoches > 1 ? 's' : ''} coché${l.nbCoches > 1 ? 's' : ''} sur ${l.lignes.length} · '
          '${etat.membre(l.membreId)?.nomAffiche ?? ''}$arret'
          '${l.interrompueLe != null ? ' · ${quand(l.interrompueLe!)}' : ''}',
    );
  }
}

/// En fin d'onglet Courses : l'historique, puis les archives (les groupes vides ne s'affichent pas).
List<Widget> groupesPasses(BuildContext context, Etat etat) {
  final historique = etat.historique.where((c) => !etat.estArchivee(c) && !etat.enInstance(c)).toList()
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));
  final libres = etat.tickets.where((t) => etat.course(t.listeId) == null).length;
  final nbArchives = etat.coursesArchivees.length + etat.magasinsArchives.length;
  return [
    if (historique.isNotEmpty || libres > 0)
      GroupeRetractable(
        cle: 'courses/historique',
        titre: 'Historique',
        nombre: historique.length,
        enfants: [
          for (final c in historique) _ligneHistorique(context, etat, c),
          if (libres > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Bouton(texte: '$libres ticket${libres > 1 ? 's' : ''} à rattacher', hauteur: 40, taille: 15, onTap: () => _pageHistorique(context)),
            ),
        ],
      ),
    if (nbArchives > 0)
      GroupeRetractable(
        cle: 'courses/archives',
        titre: 'Archives',
        nombre: nbArchives,
        enfants: [
          for (final c in etat.coursesArchivees)
            Glissable(
              key: ValueKey('archive-${c.id}'),
              titre: '${jjmmaaaa(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
              detail: '${etat.nomCourse(c)} · ${c.nbArticles} articles${etat.ticketDe(c.id) == null ? '' : ' · avec ticket'}',
              auToucher: true,
              versDroite: ActionLigne(Icons.history, 'Remettre en historique', () => etat.remettreEnHistorique(c)),
              actions: [
                if (etat.ticketDe(c.id) case final t?) ActionLigne(Icons.attach_file, 'Voir le ticket', () => ouvrirTicketPdf(context, t)),
                ActionLigne(Icons.history, 'Remettre en historique', () => etat.remettreEnHistorique(c)),
              ],
              child: LigneMenu(
                titre: '${jjmmaaaa(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
                sousTitre: '${c.nbArticles} art.',
              ),
            ),
          for (final m in etat.magasinsArchives)
            Glissable(
              key: ValueKey('archive-magasin-${m.id}'),
              titre: m.nom,
              detail: 'Magasin supprimé · ${etat.historique.where((c) => c.magasinId == m.id).length} courses',
              auToucher: true,
              actions: [
                ActionLigne(Icons.history, 'Voir ses courses', () => Nav.aller<void>(context, const EcranArchives())),
                ActionLigne(Icons.storefront_outlined, 'Rétablir le magasin', () => etat.restaurerMagasin(m)),
                ActionLigne(Icons.delete_outline, 'Tout supprimer', () => demanderSuppression(context, m, 'les archives de ${m.nom}'),
                    danger: true),
              ],
              child: LigneMenu(titre: '${m.nom} (magasin supprimé)'),
            ),
        ],
      ),
  ];
}

void _pageHistorique(BuildContext context) => Nav.aller<void>(
    context,
    const PageBase(
      entete: EnTeteFenetre(retour: true, icone: Icons.history, sousTitre: 'Courses', titre: 'Historique', aide: Aides.historique),
      corps: SousEcranHistorique(),
    ));

/// Une course de l'historique : toucher ouvre son volet (détail, ticket, actions).
Widget _ligneHistorique(BuildContext context, Etat etat, Course c) {
  final t = etat.ticketDe(c.id);
  final liste = etat.liste(c.id);
  final qui = etat.membre(c.membreId)?.nomAffiche ?? '';
  final titre = '${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}';
  return Glissable(
    key: ValueKey('historique-${c.id}'),
    titre: titre,
    detail: [
      etat.nomCourse(c),
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      if (t != null) euros(t.montant),
      if (qui.isNotEmpty) 'par $qui',
    ].join(' · '),
    auToucher: true,
    actions: [
      if (t != null) ActionLigne(Icons.attach_file, 'Voir le ticket', () => ouvrirTicketPdf(context, t)),
      if (t == null) ActionLigne(Icons.upload_file_outlined, 'Joindre le ticket PDF', () => joindreTicket(context, etat, c)),
      if (liste != null && liste.lignes.isNotEmpty)
        ActionLigne(Icons.playlist_add, 'Créer une liste type', () => creerListeType(context, etat, liste)),
      if (t == null)
        ActionLigne(Icons.undo, 'Remettre en terminées sans ticket', () {
          etat.remettreSansTicket(c);
          Nav.message(context, 'La course est de nouveau dans « Terminées sans ticket »');
        }),
      ActionLigne(Icons.inventory_2_outlined, 'Archiver', () => etat.archiver(c)),
    ],
    child: LigneMenu(titre: titre, sousTitre: t == null ? '${c.nbArticles} art.' : euros(t.montant)),
  );
}
