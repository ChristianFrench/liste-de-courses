part of '../travail.dart';


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

  /// 03/11/2026 (Aristide) : ne montrer que les articles restant à prendre (pas encore cochés).
  static bool _restants = false;


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
        bool vue(LigneListe g) => !_restants || !g.coche;
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
              droite: Row(mainAxisSize: MainAxisSize.min, children: [
                      KeyedSubtree(
                        key: const ValueKey('bouton-restants'),
                        child: _BoutonBascule(
                          actif: _restants,
                          image: 'assets/emplettes/filtre.png',
                          estompe: !_restants,
                          libelle: _restants ? 'Voir tous les articles' : 'Ne voir que les articles restants',
                          onTap: () => setState(() => _restants = !_restants),
                        ),
                      ),
                      boutonLoupe(() => setState(() {})),
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
                : avecLoupe(
                  context,
                  ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: aplat
                        ? [
                            ..._recettes(context, l),
                            ...ajouts,
                            for (final g in l.lignes)
                              if (!aPart.contains(g.produitId) && vue(g)) _ligne(etat, l, g, ajout: fondus.contains(g.produitId)),
                          ]
                        : [
                            ..._recettes(context, l),
                            ...ajouts,
                            for (final x in etapes)
                              if (x.lignes.any((g) => !aPart.contains(g.produitId) && vue(g)))
                               ...sectionSecteur(pictoEtape(x), 14, [
                                TitreGroupe(
                                  key: _titres.putIfAbsent(x.id, GlobalKey.new),
                                  nom: x.nom,
                                  pictoDebordant: pictoEtape(x),
                                  nonPlace: x.nonPlace,
                                  onTap: x.nonPlace
                                      ? () => placerNonPlaces(context, [for (final g in x.lignes) if (etat.produit(g.produitId) case final p?) p], liste: l)
                                      : null,
                                  marque: x.lignes.any((g) => fondus.contains(g.produitId)) ? Icons.playlist_add : null,
                                ),
                                for (final g in x.lignes)
                                  if (!aPart.contains(g.produitId) && vue(g)) _ligne(etat, l, g, ajout: fondus.contains(g.produitId), x: x),
                              ]),
                          ],
                  ),
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

  /// 21/11/2026 (Aristide) : en tête des courses, comme en préparation, les recettes dont les ingrédients sont
  /// dans cette liste ; les toucher ouvre la recette (rien ne modifie la liste).
  List<Widget> _recettes(BuildContext context, Liste l) {
    if (!Nav.avecCuisiner) return const [];
    final notes = [for (final n in Etat.instance.recettesDeListe(l)) if (n.etat == NoteRecette.traitee) n];
    if (notes.isEmpty) return const [];
    return [
      BandeauRecettes(cle: 'courses/recettes', lignes: [
        for (final n in notes) LigneRecetteChoisie(note: n, courses: true, onTap: () => voirRecetteNotee(context, n)),
      ]),
    ];
  }

  Widget _ligne(Etat etat, Liste l, LigneListe g, {bool ajout = false, Etape? x}) {
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
      // 13/11/2026 (Aristide), généralisé à toutes les versions le 14/11 : aucun geste sur l'article lui-même ;
      // la case coche (deux appuis : manquant) ; appui long sur la case : le détail, fermé seul après 4 secondes.
      onCase: () => _appui(etat, l, p, x),
      onCaseLong: () {
        HapticFeedback.mediumImpact();
        detailArticle(context, g, fermeSeul: true);
      },
    );
  }

  String? _dernierAppui;
  DateTime _dernierAppuiLe = DateTime(2000);

  /// Toucher la case coche ou décoche ; deux appuis rapprochés sur la même case marquent l'article manquant ;
  /// un article manquant touché est trouvé finalement (coché).
  /// 13/11/2026 (Aristide) : le secteur où l'on vient de cocher prend le haut de l'écran.
  void _appui(Etat etat, Liste l, Produit p, Etape? x) {
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
    } else {
      etat.cocher(l, p.id);
    }
    HapticFeedback.selectionClick();
    if (x == null || !(etat.ligne(l, p.id)?.coche ?? false)) return;
    // Après le délai du double appui : la case ne bouge pas sous le doigt entre deux appuis.
    Future.delayed(const Duration(milliseconds: 460), () {
      if (_dernierAppui != p.id || !(etat.ligne(l, p.id)?.coche ?? false)) return;
      final c = _titres[x.id]?.currentContext;
      if (mounted && c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250));
    });
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
          Text('La course ira dans l\'onglet Courses, « Terminées », où vous pourrez joindre le ticket de caisse.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
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
    // 17/11/2026 (Aristide : « la terminaison est très longue ») : l'envoi du résumé (jusqu'à 20 s sans réseau)
    // n'est plus attendu. Le texte est lu tout de suite, avant la fin des courses (la liste garde ses coches et
    // ses manquants), puis le mail part pendant qu'on est déjà revenu aux courses ; son résultat s'affiche après.
    final nb = adressesFoyer(etat).length;
    final envoi = resume ? envoyerResume(etat, l) : null;
    await _patienter(context, 'Fin des courses…', () => etat.terminerCourses(l));
    Nav.i.retourOnglet(Nav.courses);
    Nav.message(null, 'Courses terminées : elles sont dans « Terminées », où joindre le ticket de caisse');
    if (envoi != null) {
      unawaited(envoi.then((e) {
        if (messageEnvoi(e, nb) case final m?) Nav.message(null, m);
      }, onError: (Object e) {
        etat.noter('Résumé des courses non envoyé : $e');
        Nav.message(null, 'Le résumé n\'a pas pu partir');
      }));
    }
  }

  /// Fenêtre d'attente pendant un travail : elle s'affiche avant que le travail commence.
  static Future<void> _patienter(BuildContext context, String texte, void Function() travail) async {
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Charte.blanc,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 18),
                Text(texte, style: Charte.texte(16, gras: true)),
              ]),
            ),
          ),
        ),
      ),
    ));
    // Laisser la fenêtre se dessiner avant le travail, qui occupe l'appareil.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      travail();
    } finally {
      nav.pop();
    }
  }
}
