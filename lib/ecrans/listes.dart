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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Bouton(
          texte: '+ Nouvelle liste',
          plein: true,
          hauteur: 56,
          taille: 19,
          onTap: () => Nav.travail(const EcranPreliste()),
        ),
        const TitreSection('En préparation', cote: 0),
        if (enPreparation.isEmpty)
          Text('Aucune liste en préparation.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        for (final l in enPreparation) ...[
          Carte(
            onTap: () => Nav.travail(EcranConstruction(listeId: l.id)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etat.nomListe(l), style: Charte.texte(18, gras: true)),
                      const SizedBox(height: 2),
                      Text(
                        '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · modifiée par '
                        '${etat.membre(l.modifieePar)?.nomAffiche ?? etat.moi.nomAffiche} · '
                        '${l.interrompueLe != null ? quand(l.interrompueLe!) : quandJour(l.modifieeLe ?? l.dateCreation)}',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire),
                      ),
                    ],
                  ),
                ),
                if (l.interrompueLe != null) ...[const SizedBox(width: 8), const Etiquette('Interrompue', pointille: true)],
                BoutonRenommerListe(l),
                BoutonSupprimerListe(l),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const TitreSection('Prêtes pour les courses', cote: 0),
        if (pretes.isEmpty)
          Text('Aucune liste prête.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        for (final l in pretes) ...[
          Carte(
            onTap: () => Nav.i.allerOnglet(Nav.courses),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etat.nomListe(l), style: Charte.texte(18, gras: true)),
                      const SizedBox(height: 2),
                      Text(
                        '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · prête depuis '
                        '${quandJour(l.modifieeLe ?? l.dateCreation)}',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire),
                      ),
                    ],
                  ),
                ),
                BoutonRemettreEnPreparation(l),
                BoutonSupprimerListe(l),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Text('Une préparation interrompue est conservée telle quelle : touchez-la pour reprendre.',
            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      ],
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
        icon: const Icon(Icons.delete_outline, color: Charte.texteSecondaire),
        onPressed: () => demanderSuppression(context, liste, 'la liste ${Etat.instance.nomListe(liste)}'),
      );
}

class BoutonRenommerListe extends StatelessWidget {
  const BoutonRenommerListe(this.liste, {super.key});
  final Liste liste;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Renommer la liste',
        icon: const Icon(Icons.edit_outlined, color: Charte.texteSecondaire),
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
        icon: const Icon(Icons.edit_note, color: Charte.texteSecondaire),
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
  bool parRayon = true;

  @override
  void initState() {
    super.initState();
    membreIndex = etat.membres.indexWhere((m) => m.moi);
    if (membreIndex < 0) membreIndex = 0;
  }

  Membre get membre => etat.membres[membreIndex.clamp(0, etat.membres.length - 1)];

  Future<void> _nouveau(BuildContext context) async {
    var magasinId = etat.magasins.length == 1 ? etat.magasins.first.id : null;
    magasinId ??= await choisirDansListe<String>(context,
        titre: 'Parcours dans quel magasin ?', choix: {for (final m in etat.magasins) m.id: m.nom});
    if (magasinId == null || !context.mounted) return;
    final nom = await demanderTexte(context,
        titre: 'Nouveau parcours', initial: 'Parcours de ${membre.nomAffiche.split(' ').first}', aide: 'Ex. : Au plus court');
    if (nom == null || nom.isEmpty) return;
    // Tous les rayons et secteurs du magasin, dans l'ordre des rayons : il reste à les ordonner.
    final n = etat.creerParcours(magasinId, membre.id, nom);
    setState(() {
      parcoursId = n.id;
      parRayon = true;
    });
  }

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _choixMembre(),
        Text('Parcours de ${membre.nomAffiche}', style: Charte.texte(15, gras: true)),
        const SizedBox(height: 4),
        if (mes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun parcours pour le moment.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        for (final x in mes)
          LigneMenu(
            titre: x.nom,
            sousTitre: '${etat.magasin(x.magasinId)?.nom ?? ''} · ${x.etapes.length} secteur${x.etapes.length > 1 ? 's' : ''}'
                '${x.parDefaut ? ' · par défaut' : ''}',
            onTap: () => setState(() => parcoursId = x.id),
          ),
        const SizedBox(height: 14),
        Bouton(texte: '+ Nouveau parcours', pointille: true, taille: 16, onTap: () => _nouveau(context)),
        const SizedBox(height: 8),
        Text('Un nouveau parcours reprend tous les rayons et secteurs du magasin ; ordonnez-les ensuite par rayon ou par secteur.',
            style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      ],
    );
  }

  Widget _edition(BuildContext context, Parcours p) {
    final rayonsP = etat.rayonsDuParcours(p);
    final n = parRayon ? rayonsP.length : p.etapes.length;
    final haut = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => parcoursId = null),
              icon: const Icon(Icons.chevron_left, color: Charte.encre),
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
                icon: const Icon(Icons.edit_outlined, color: Charte.texteSecondaire),
                onPressed: () async {
                  final nom = await demanderTexte(context, titre: 'Nom du parcours', initial: p.nom);
                  if (nom != null && nom.isNotEmpty) setState(() => etat.renommerParcours(p, nom));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Bascule(
            hauteur: 48,
            options: const ['Par rayon', 'Par secteur'],
            index: parRayon ? 0 : 1,
            onChange: (i) => setState(() => parRayon = i == 0),
          ),
          const SizedBox(height: 8),
          Text(
            parRayon
                ? 'Ordre de passage par rayon · glisser pour réordonner'
                : 'Ordre de passage par secteur · glisser pour réordonner',
            style: Charte.texte(13, couleur: Charte.texteSecondaire),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );

    final bas = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!parRayon)
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
      itemCount: n,
      onReorderItem: (ancien, nouveau) {
        if (parRayon) {
          etat.deplacerRayonParcours(p, ancien, nouveau);
        } else {
          final sid = p.etapes.removeAt(ancien);
          p.etapes.insert(nouveau, sid);
          etat.modifie();
        }
        setState(() {});
      },
      itemBuilder: (context, i) => parRayon ? _rayon(context, p, rayonsP[i], i) : _etape(context, p, i),
    );
  }

  Widget _ligneOrdre({required Key key, required int index, required String numero, required Widget texte, VoidCallback? onTap, Widget? image}) =>
      ReorderableDelayedDragStartListener(
        key: key,
        index: index,
        child: Material(
          color: Charte.fond,
          child: InkWell(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(minHeight: 56),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Charte.encre, width: 1.5)),
                    child: Text(numero, style: Charte.texte(14)),
                  ),
                  const SizedBox(width: 10),
                  if (image != null) ...[image, const SizedBox(width: 8)],
                  Expanded(child: texte),
                  ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(width: 44, height: 44, child: Icon(Icons.drag_handle, color: Charte.texteSecondaire)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _rayon(BuildContext context, Parcours p, Rayon r, int i) {
    final ns = p.etapes.where((sid) => etat.secteur(sid)?.rayonId == r.id).length;
    final img = cleRayon(r.nom);
    return _ligneOrdre(
      key: ValueKey('rayon-${r.id}'),
      index: i,
      numero: '${i + 1}',
      image: img == null ? null : Pictogramme(img, taille: 32),
      texte: Text.rich(TextSpan(children: [
        TextSpan(text: r.nom, style: Charte.texte(18, gras: true)),
        TextSpan(text: ' · $ns secteur${ns > 1 ? 's' : ''}', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      ])),
    );
  }

  Widget _etape(BuildContext context, Parcours p, int i) {
    final s = etat.secteur(p.etapes[i]);
    final r = etat.rayon(s?.rayonId);
    final retour = etat.estRetour(p.etapes, i);
    return _ligneOrdre(
      key: ValueKey('etape-${p.etapes[i]}'),
      index: i,
      numero: '${i + 1}',
      onTap: () async {
        final retirer = await confirmer(
          context,
          titre: 'Retirer ce secteur ?',
          contenu: Text('« ${s?.nom ?? ''} » ne fera plus partie du parcours « ${p.nom} ».', style: Charte.texte(16)),
          plein: 'Garder',
          contour: 'Retirer du parcours',
        );
        if (retirer == true) {
          p.etapes.removeAt(i);
          etat.modifie();
          setState(() {});
        }
      },
      texte: Text.rich(TextSpan(children: [
        TextSpan(text: s?.nom ?? '?', style: Charte.texte(18, gras: true)),
        TextSpan(
          text: ' · ${r?.nom ?? ''}${retour ? ' (retour)' : ''}',
          style: Charte.texte(14, couleur: Charte.texteSecondaire),
        ),
      ])),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (enCours != null) ...[
          const TitreSection('Courses interrompues', cote: 0, haut: 8),
          _carteInterrompues(context, enCours),
        ],
        TitreSection('Listes prêtes', cote: 0, haut: enCours == null ? 8 : 16),
        if (pretes.isEmpty)
          Text('Aucune liste prête : terminez d\'abord une préparation (« Liste prête »).',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        if (pretes.isNotEmpty && etat.membres.length > 1) ...[
          Row(
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
          const SizedBox(height: 10),
        ],
        for (final l in pretes) ...[
          Carte(
            onTap: () => _partir(context, l),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etat.nomListe(l), style: Charte.texte(18, gras: true)),
                      const SizedBox(height: 2),
                      Text(
                        '${_magasinSiRenommee(l)}${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''}'
                        '${l.lignes.any((g) => g.consigne != null) ? ' · avec consignes' : ''}',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire),
                      ),
                    ],
                  ),
                ),
                BoutonRemettreEnPreparation(l),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (pretes.isNotEmpty)
          Text('Touchez une liste pour partir faire les courses.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
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
                border: Border.all(color: Charte.encre, width: 1.5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total == 0 ? 0 : faits / total,
                child: Container(color: Charte.encre),
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
