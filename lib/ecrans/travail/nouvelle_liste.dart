part of '../travail.dart';


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

  /// [marques] : marque à donner à l'article d'un produit (« Beurre » devient « Beurre Président »).
  void _creer(List<LigneListe> lignes, {bool simple = false, Map<String, String> marques = const {}}) {
    final texte = nom.text.trim().isEmpty ? etat.nomLibre(etat.nomPrevu(magasinId, prevue)) : nom.text.trim();
    if (etat.nomPris(texte)) {
      Nav.message(context, 'Une liste s\'appelle déjà « $texte » : choisissez un autre nom.');
      return;
    }
    final l = etat.creerListe(magasinId, lignes, nom: texte);
    etat.fixerDatePrevue(l, prevue);
    for (final e in marques.entries) {
      if (etat.produit(e.key) case final p?) etat.changerMarque(l, p, e.value);
    }
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
              encadree: false,
            ),
        ],
      ),
    );
    if (!ok || !mounted) return;
    // Un même produit lu deux fois : une seule ligne, quantités additionnées.
    final lignes = <String, LigneListe>{};
    final marques = <String, String>{};
    for (var i = 0; i < lus.length; i++) {
      if (!choisis.contains(i)) continue;
      final a = lus[i];
      final p = a.produit ?? etat.creerProduit(a.nom, secteur: a.secteur);
      final g = lignes[p.id];
      if (g != null) {
        g.quantite += a.quantite;
      } else {
        lignes[p.id] = LigneListe(produitId: p.id, quantite: a.quantite);
      }
      if (a.marque != null) marques[p.id] = a.marque!;
    }
    _creer(lignes.values.toList(), marques: marques);
  }

  /// 10/11/2026 (Aristide) : « Mes achats habituels » : les articles achetés régulièrement dans ce magasin,
  /// tous cochés d'avance ; on décoche ceux dont on n'a pas besoin cette fois.
  Future<void> _achatsHabituels() async {
    final lignes = etat.preliste(magasinId);
    final nb = etat.achatsRecents(magasinId);
    final courses = etat.dernieresCourses(magasinId, nombre: etat.prelisteSur).length;
    if (lignes.isEmpty) {
      Nav.message(context, courses == 0 ? 'Aucune course passée dans ce magasin.' : 'Aucun article acheté assez souvent dans ce magasin.');
      return;
    }
    final seuil = etat.prelistePresencesMin < courses ? etat.prelistePresencesMin : courses;
    final choisis = <int>{for (var i = 0; i < lignes.length; i++) i};
    final ok = await modale(
      context,
      titre: 'Mes achats habituels',
      icone: Icons.restart_alt,
      oui: 'Créer la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Achetés au moins $seuil fois sur vos $courses dernières courses ici · décochez ceux dont vous n\'avez pas besoin.',
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
                key: ValueKey('habituel-${p.id}'),
                texte: '${p.nom}${lignes[i].quantite > 1 ? ' × ${lignes[i].quantite}' : ''}',
                aide: [
                  '${nb[p.id] ?? 0} fois sur $courses',
                  if (etat.complement(lignes[i], p).isNotEmpty) etat.complement(lignes[i], p),
                ].join(' · '),
                coche: choisis.contains(i),
                onChange: (v) => maj(() => v ? choisis.add(i) : choisis.remove(i)),
                encadree: false,
              ),
        ],
      ),
    );
    if (ok && mounted) _creer([for (var i = 0; i < lignes.length; i++) if (choisis.contains(i)) lignes[i]]);
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
                encadree: false,
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
            nombre: 8,
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
                key: const ValueKey('achats-habituels'),
                icone: Icons.restart_alt,
                titre: 'Mes achats habituels',
                sousTitre: 'Les articles achetés au moins ${etat.prelistePresencesMin} fois sur vos ${etat.prelisteSur} dernières courses ici',
                onTap: _achatsHabituels,
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
