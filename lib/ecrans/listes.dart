import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'travail.dart';

// Onglet Listes : sous-onglets Préparer (écran 1), Parcours (5), Courses (6).

/// Écran 1 — Listes › Préparer.
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
                      Text(etat.magasin(l.magasinId)?.nom ?? '', style: Charte.texte(18, gras: true)),
                      const SizedBox(height: 2),
                      Text(
                        '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · modifiée par '
                        '${etat.membre(l.modifieePar)?.nomAffiche ?? etat.moi.nomAffiche} · '
                        '${l.interrompueLe != null ? quand(l.interrompueLe!) : quandJour(l.modifieeLe ?? l.dateCreation)}',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire),
                      ),
                    ],
                  ),
                ),
                if (l.interrompueLe != null) ...[const SizedBox(width: 8), const Etiquette('Interrompue', pointille: true)],
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
            onTap: () {
              Nav.i.listeAPartir = l.id;
              Nav.i.allerSous(Nav.courses);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etat.magasin(l.magasinId)?.nom ?? '', style: Charte.texte(18, gras: true)),
                const SizedBox(height: 2),
                Text(
                  '${l.lignes.length} article${l.lignes.length > 1 ? 's' : ''} · prête depuis '
                  '${quandJour(l.modifieeLe ?? l.dateCreation)}',
                  style: Charte.texte(14, couleur: Charte.texteSecondaire),
                ),
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

/// Écran 5 — Listes › Parcours. Enregistrement immédiat.
class SousEcranParcours extends StatefulWidget {
  const SousEcranParcours({super.key});

  @override
  State<SousEcranParcours> createState() => _SousEcranParcoursState();
}

class _SousEcranParcoursState extends State<SousEcranParcours> {
  final etat = Etat.instance;
  late String magasinId;
  int membreIndex = 0;
  String? parcoursId;

  @override
  void initState() {
    super.initState();
    magasinId = etat.magasins.first.id;
    membreIndex = etat.membres.indexWhere((m) => m.moi);
    if (membreIndex < 0) membreIndex = 0;
    _parDefaut();
  }

  String get membreId => etat.membres[membreIndex].id;
  void _parDefaut() => parcoursId = etat.parcoursParDefaut(magasinId, membreId)?.id;

  @override
  Widget build(BuildContext context) {
    final liste = etat.parcoursDe(magasinId, membreId);
    if (parcoursId != null && !liste.any((p) => p.id == parcoursId)) _parDefaut();
    final p = etat.unParcours(parcoursId);
    final etapes = p?.etapes ?? const <String>[];

    final haut = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoixDeroulant<String>(
                  valeur: magasinId,
                  choix: {for (final m in etat.magasins) m.id: m.nom},
                  onChange: (v) => setState(() {
                    magasinId = v;
                    _parDefaut();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Bascule(
                  hauteur: 48,
                  options: [for (final m in etat.membres) m.initiales],
                  index: membreIndex,
                  onChange: (i) => setState(() {
                    membreIndex = i;
                    _parDefaut();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: liste.isEmpty
                    ? Text('Aucun parcours pour ${etat.membres[membreIndex].nomAffiche} dans ce magasin.',
                        style: Charte.texte(14, couleur: Charte.texteSecondaire))
                    : ChoixDeroulant<String>(
                        valeur: parcoursId ?? '',
                        choix: {for (final x in liste) x.id: x.parDefaut ? '${x.nom} (par défaut)' : x.nom},
                        onChange: (v) => setState(() => parcoursId = v),
                      ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 124,
                child: Bouton(
                  texte: '+ Nouveau',
                  taille: 16,
                  onTap: () async {
                    final nom = await demanderTexte(context, titre: 'Nouveau parcours', aide: 'Ex. : Au plus court');
                    if (nom == null || nom.isEmpty) return;
                    final n = etat.creerParcours(magasinId, membreId, nom);
                    setState(() => parcoursId = n.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Charte.separateurZone),
          const SizedBox(height: 8),
          Text('Ordre de passage par secteur · glisser pour réordonner',
              style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 4),
        ],
      ),
    );

    final bas = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: p == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Bouton(
                  texte: '+ Ajouter un secteur',
                  pointille: true,
                  taille: 16,
                  onTap: () async {
                    final restants = etat.secteursDuMagasin(magasinId).where((s) => !p.etapes.contains(s.id)).toList();
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
              ],
            ),
    );

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      header: haut,
      footer: bas,
      itemCount: etapes.length,
      onReorderItem: (ancien, nouveau) {
        final sid = p!.etapes.removeAt(ancien);
        p.etapes.insert(nouveau, sid);
        etat.modifie();
        setState(() {});
      },
      itemBuilder: (context, i) => _etape(context, p!, i),
    );
  }

  Widget _etape(BuildContext context, Parcours p, int i) {
    final s = etat.secteur(p.etapes[i]);
    final r = etat.rayon(s?.rayonId);
    final retour = etat.estRetour(p.etapes, i);
    return ReorderableDelayedDragStartListener(
      key: ValueKey('etape-${p.etapes[i]}'),
      index: i,
      child: Material(
        color: Charte.fond,
        child: InkWell(
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
                  child: Text('${i + 1}', style: Charte.texte(14)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: s?.nom ?? '?', style: Charte.texte(19, gras: true)),
                    TextSpan(
                      text: ' · ${r?.nom ?? ''}${retour ? ' (retour)' : ''}',
                      style: Charte.texte(14, couleur: Charte.texteSecondaire),
                    ),
                  ])),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.drag_handle, color: Charte.texteSecondaire),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran 6 — Listes › Courses.
class SousEcranCourses extends StatefulWidget {
  const SousEcranCourses({super.key});

  @override
  State<SousEcranCourses> createState() => _SousEcranCoursesState();
}

class _SousEcranCoursesState extends State<SousEcranCourses> {
  final etat = Etat.instance;
  late String membreId;
  String parcoursId = '';
  String? _listePourParcours;

  @override
  void initState() {
    super.initState();
    membreId = etat.moi.id;
  }

  void _parcoursParDefaut(Liste? l) {
    parcoursId = l == null ? '' : (etat.parcoursParDefaut(l.magasinId, membreId)?.id ?? '');
    _listePourParcours = l?.id;
  }

  @override
  Widget build(BuildContext context) {
    final enCours = etat.coursesEnCours;
    final pretes = etat.listesStatut(StatutListe.prete);
    var choisie = etat.liste(Nav.i.listeAPartir);
    if (choisie == null || choisie.statut != StatutListe.prete) {
      choisie = pretes.isEmpty ? null : pretes.first;
      Nav.i.listeAPartir = choisie?.id;
    }
    if (_listePourParcours != choisie?.id) _parcoursParDefaut(choisie);
    final choixParcours = <String, String>{
      if (choisie != null)
        for (final p in etat.parcoursDe(choisie.magasinId, membreId)) p.id: p.parDefaut ? '${p.nom} (par défaut)' : p.nom,
      '': 'Ordre des rayons',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (enCours != null) ...[
          const TitreSection('Courses interrompues', cote: 0, haut: 8),
          _carteInterrompues(context, enCours),
        ],
        TitreSection('Démarrer des courses', cote: 0, haut: enCours == null ? 8 : 16),
        if (pretes.isEmpty)
          Text('Aucune liste prête : terminez d\'abord une préparation (« Liste prête »).',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        for (final l in pretes) ...[
          Carte(
            chevron: false,
            fond: l.id == choisie?.id ? Charte.fondSelection : Charte.fond,
            onTap: () => setState(() => Nav.i.listeAPartir = l.id),
            child: Row(
              children: [
                Icon(l.id == choisie?.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 28, color: Charte.encre),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: etat.magasin(l.magasinId)?.nom ?? '', style: Charte.texte(18, gras: true)),
                    TextSpan(
                      text: ' · ${l.lignes.length} articles · ${quandJour(l.modifieeLe ?? l.dateCreation)}',
                      style: Charte.texte(14, couleur: Charte.texteSecondaire),
                    ),
                  ])),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (choisie != null) ...[
          Row(
            children: [
              Expanded(
                child: ChoixDeroulant<String>(
                  valeur: membreId,
                  choix: {for (final m in etat.membres) m.id: m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche},
                  onChange: (v) => setState(() {
                    membreId = v;
                    _parcoursParDefaut(choisie);
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoixDeroulant<String>(
                  valeur: parcoursId,
                  choix: choixParcours,
                  onChange: (v) => setState(() => parcoursId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Bouton(
            texte: 'Voir la liste et partir',
            plein: enCours == null,
            onTap: () {
              final l = choisie!;
              etat.demarrerCourses(l, membreId, parcoursId.isEmpty ? null : parcoursId);
              Nav.travail(EcranListeComplete(listeId: l.id));
            },
          ),
        ],
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
              Expanded(child: Text(etat.magasin(l.magasinId)?.nom ?? '', style: Charte.texte(18, gras: true))),
              Text('$faits / $total', style: Charte.texte(18, gras: true)),
              const SizedBox(width: 6),
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
