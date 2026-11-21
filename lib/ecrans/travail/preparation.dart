part of '../travail.dart';


/// Écran 3 — Construction par secteur. Chaque action est enregistrée ; quitter ne perd rien.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  /// Après un ajout par la recherche, le volet « Promo » s'ouvre (04/11/2026) ; coupé par certains essais.
  static bool promoApresRecherche = true;

  /// 15/11/2026 : le bouton « Recette » (ingrédients d'une recette à cocher) ; démonstration d'abord, puis toutes
  /// les versions le 17/11/2026 (Aristide). Coupé par certains essais.
  static bool recettes = true;

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
    _filtreRecettes.dispose();
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
            sousTitre: '${simple ? 'Liste simple · ' : ''}$n article${n > 1 ? 's' : ''} · '
                '${etat.coursesPrevues(l).isEmpty ? etat.creeeLe(l) : etat.coursesPrevues(l)}',
            aide: simple ? Aides.listeSimple : Aides.preparation,
            // 15/11/2026 (Aristide) : bouton « Recette » en bas à droite de l'en-tête (toutes les versions depuis le 17/11/2026).
            droite: EcranConstruction.recettes
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    KeyedSubtree(
                      key: const ValueKey('bouton-recette'),
                      child: _BoutonBascule(
                        actif: false,
                        image: 'assets/recettes/recettes-de-cuisine.png',
                        libelle: 'Ajouter les ingrédients d\'une recette',
                        onTap: () => _recette(l),
                      ),
                    ),
                    boutonLoupe(() => setState(() {})),
                  ])
                : boutonLoupe(() => setState(() {})),
            actions: [
              ActionLigne(Icons.event_outlined, 'Changer le magasin ou la date', () => changerMagasinEtDate(context, l)),
              ActionLigne(Icons.mail_outline, 'Envoyer par mail', () async {
                final a = await choisirDestinataires(context);
                if (a == null) return;
                final r = messageEnvoi(await envoyerListe(etat, l, a: a), a.length);
                if (r != null && context.mounted) Nav.message(context, r);
              }),
            ],
          ),
          haut: [
            ChampRecherche(
              key: ValueKey('recherche-${l.id}'),
              produits: () => etat.produitsVisibles,
              detail: ou,
              aide: 'Ajouter un article (3 lettres ou plus)',
              onChoix: (p) => _ajouter(l, p, avecPromo: true),
              // « nut » → Pâte à tartiner chocolat · Nutella : l'article générique, avec sa marque.
              onMarque: (p, marque) {
                if (etat.ligne(l, p.id) == null) etat.ajouterLigne(l, p.id);
                _ajouter(l, etat.changerMarque(l, p, marque), avecPromo: true);
              },
              onNouveau: (nom) async {
                final p = await nouveauProduit(context, nom: nom);
                if (p == null || !mounted) return;
                _ajouter(l, p);
              },
            ),
            Container(height: 1, color: Charte.separateurZone),
          ],
          corps: l.lignes.isEmpty
              ? ListView(children: [
                  ..._recettesChoisies(l),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Tapez le début du nom d\'un article dans le champ ci-dessus et touchez-le : il s\'ajoute à la liste.',
                        style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                  ),
                ])
              : avecLoupe(
                  context,
                  ListView(
                  controller: _defilement,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: simple
                      ? [..._recettesChoisies(l), for (final g in l.lignes) _ligne(l, g)]
                      : [
                          // 21/11/2026 (Aristide) : en tête de liste, les recettes choisies (note préparée).
                          ..._recettesChoisies(l),
                          // 12/11/2026 (Aristide) : en préparation, les secteurs dans l'ordre du catalogue (univers,
                          // rayons, secteurs), pas dans celui du parcours, qui ne sert qu'aux courses.
                          for (final x in etat.etapes(l, null, ordreBase: secteursOrdreCatalogue(etat)))
                           ...sectionSecteur(pictoEtape(x), 4, [
                            TitreGroupe(
                              key: _bandeaux.putIfAbsent(x.id, GlobalKey.new),
                              nom: x.nom,
                              nonPlace: x.nonPlace,
                              pictoDebordant: pictoEtape(x),
                              pictoGauche: 4,
                              // 13/11/2026 (Aristide) : plus le nombre d'articles commandés, mais un bouton « + N » :
                              // les articles du secteur pas encore commandés, à cocher pour les ajouter.
                              apres: _boutonAutres(l, x),
                              onTap: x.nonPlace
                                  ? () => placerNonPlaces(context, [for (final g in x.lignes) if (etat.produit(g.produitId) case final p?) p], liste: l)
                                  : null,
                            ),
                            for (final g in x.lignes) _ligne(l, g),
                            if (_proposes == x.id)
                              for (final p in _autres(l, x)) _ligneProposee(l, p),
                          ]),
                        ],
                ),
                ),
          bas: [BarreAction(boutons: [Bouton(texte: 'Liste prête', icone: Icons.check, plein: true, onTap: () => _valider(l))])],
        );
      },
    );
  }

  /// « Recettes choisies » (21/11/2026, Aristide) : en tête de la liste, sous la forme des secteurs, une ligne
  /// par recette de la note préparée du foyer : à traiter (toucher : ses ingrédients notés, pré-cochés), traitée
  /// (ajoutée à cette liste), ignorée (on a changé d'avis). Un appui long propose les autres gestes.
  List<Widget> _recettesChoisies(Liste l) {
    // Démonstration d'abord (avec les onglets Recettes et Cuisiner).
    final notes = Nav.avecCuisiner ? etat.recettesDeListe(l) : const <NoteRecette>[];
    if (notes.isEmpty) return const [];
    return [BandeauRecettes(cle: 'preparer/recettes', lignes: [for (final n in notes) _ligneRecette(l, n)])];
  }

  Widget _ligneRecette(Liste l, NoteRecette n) {
    final ignoree = n.etat == NoteRecette.ignoree;
    final actions = [
      if (n.etat == NoteRecette.aTraiter) ...[
        ActionLigne(Icons.add_shopping_cart, 'Ajouter ses ingrédients', () => _traiterRecette(l, n)),
        ActionLigne(Icons.cancel_outlined, 'Ignorer (j\'ai changé d\'avis)', () => etat.marquerRecette(n, NoteRecette.ignoree, l)),
      ],
      if (ignoree) ActionLigne(Icons.undo, 'Reprendre', () => etat.marquerRecette(n, NoteRecette.aTraiter, l)),
      ActionLigne(Icons.menu_book_outlined, 'Voir la recette', () => voirRecetteNotee(context, n)),
    ];
    return LigneRecetteChoisie(
      note: n,
      onTap: () => n.etat == NoteRecette.aTraiter ? _traiterRecette(l, n) : menuActions(context, titre: n.titre, actions: actions),
      onLongPress: () => menuActions(context, titre: n.titre, actions: actions),
    );
  }

  Future<void> _traiterRecette(Liste l, NoteRecette n) async {
    final r = await recetteNotee(n);
    if (!mounted) return;
    if (r == null) {
      Nav.message(context, 'Cette recette n\'est plus dans le catalogue des recettes');
      return;
    }
    final (_, premier) = await cocherIngredientsRecette(context, l, r, note: n);
    if (!mounted || premier == null) return;
    // 21/11/2026 (Aristide) : l'écran va sur le premier ingrédient ajouté, sans le laisser en couleur.
    setState(() => _proposes = null);
    _amener(premier, essais: 4);
  }
  /// Secteur dont les articles non commandés sont déployés (un seul à la fois).
  String? _proposes;

  /// Bandeaux des secteurs, pour amener en haut de l'écran celui dont on déploie les autres produits.
  final _bandeaux = <String, GlobalKey>{};

  /// Articles du secteur qui ne sont pas dans la liste. 13/11/2026 (Aristide) : les habituels d'abord (déjà mis
  /// dans des listes, tous magasins ; les plus souvent pris en tête), puis les autres par ordre alphabétique.
  List<Produit> _autres(Liste l, Etape x) {
    final s = x.secteur;
    if (s == null) return const [];
    return [for (final p in etat.produitsDuSecteur(s)) if (etat.ligne(l, p.id) == null) p]
      ..sort((a, b) {
        final u = b.nbUtilisations.compareTo(a.nbUtilisations);
        return u != 0 ? u : normaliser(a.nom).compareTo(normaliser(b.nom));
      });
  }

  /// Bouton « Autres produits » du bandeau : un toucher déploie les articles non commandés, un autre les replie.
  Widget? _boutonAutres(Liste l, Etape x) {
    if (x.nonPlace) return null;
    final ouvert = _proposes == x.id;
    if (!ouvert && _autres(l, x).isEmpty) return null;
    // 17/11/2026 (Aristide) : le bouton occupe toute la hauteur du bandeau sans la changer : il prend dans la
    // rangée la place du texte du titre et déborde sur les marges haute et basse (4 + 4) du bandeau.
    final titre = TextPainter(
      text: TextSpan(text: 'Ag', style: Charte.texte(14, gras: true)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    final place = titre.height;
    titre.dispose();
    final bande = place + 8;
    final libelle = TextPainter(
      text: TextSpan(text: 'Autres produits', style: Charte.texte(13, gras: true)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    // 17/11/2026 : marge d'arrondi ; le libellé ne passe jamais à la ligne (il était coupé sous Windows).
    final largeur = libelle.width.ceilToDouble() + 24 + 6;
    libelle.dispose();
    return SizedBox(
      width: largeur,
      height: place,
      child: OverflowBox(
        minHeight: bande,
        maxHeight: bande,
        child: Semantics(
          button: true,
          label: ouvert ? 'Replier les autres produits de ${x.nom}' : 'Autres produits de ${x.nom}',
          child: Material(
            color: ouvert ? Charte.cadre : Charte.blanc,
            shape: StadiumBorder(side: BorderSide(color: Charte.cadre, width: 1.5)),
            child: InkWell(
              key: ValueKey('autres-${x.id}'),
              customBorder: const StadiumBorder(),
              onTap: () {
                setState(() => _proposes = ouvert ? null : x.id);
                // 13/11/2026 (Aristide) : le secteur déployé vient en haut de l'écran.
                if (!ouvert) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final c = _bandeaux[x.id]?.currentContext;
                    if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250));
                  });
                }
              },
              child: Center(
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Autres produits',
                      maxLines: 1, softWrap: false, overflow: TextOverflow.visible,
                      style: Charte.texte(13, gras: true, couleur: ouvert ? Charte.blanc : Charte.cadre)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Article du secteur pas encore commandé : case vide ; la cocher l'ajoute (quantité 1).
  Widget _ligneProposee(Liste l, Produit p) {
    final hauteur = Charte.ligne * MediaQuery.textScalerOf(context).scale(16) / 16;
    return InkWell(
      key: ValueKey('propose-${p.id}'),
      onTap: () {
        HapticFeedback.selectionClick();
        etat.ajouterLigne(l, p.id);
      },
      child: SizedBox(
        height: hauteur,
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(Icons.check_box_outline_blank, size: 22, color: Charte.texteSecondaire),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(16, couleur: Charte.texteSecondaire)),
          ),
        ]),
      ),
    );
  }

  /// L'article trouvé s'ajoute (s'il n'y est pas) ; l'écran va sur lui et le signale quelques secondes.
  /// 15/11/2026 (Aristide) : une recette (mes recettes, lien internet ou texte) propose ses ingrédients à cocher ;
  /// les produits du placard sont décochés au départ ; les cochés complètent la liste, avec la consigne « pour : … ».
  Future<void> _recette(Liste l) async {
    final source = await choisirDansListe<int>(context, titre: 'Ingrédients d\'une recette', choix: {
      0: 'Mes recettes',
      1: 'Lien d\'une page internet',
      2: 'Texte de la recette',
    });
    if (source == null || !mounted) return;
    _filtreRecettes.clear();
    // 17/11/2026 (Aristide) : « Annuler » sur les ingrédients d'une recette de « Mes recettes » ramène à la liste
    // des recettes.
    while (mounted && !await _recetteChoisie(l, source)) {
      if (source != 0) return;
    }
  }

  /// Une recette, puis ses ingrédients à cocher. Rend faux si l'on a annulé la fenêtre des ingrédients.
  Future<bool> _recetteChoisie(Liste l, int source) async {
    RecetteLue? r;
    if (source == 0) {
      r = await _choisirRecette();
    } else if (source == 1) {
      final lien = await demanderTexte(context,
          titre: 'Lien de la recette', libelle: 'Adresse de la page', valider: 'Lire la recette',
          cleChamp: const ValueKey('lien-recette'));
      if (lien == null || lien.trim().isEmpty || !mounted) return true;
      try {
        Nav.message(context, 'Lecture de la page…');
        r = await recetteDepuisLien(lien);
      } catch (_) {
        if (mounted) {
          Nav.message(context, 'Cette page ne peut pas être lue ici. Copiez le texte de la recette, '
              'puis choisissez « Texte de la recette ».');
        }
        return true;
      }
    } else {
      final texte = TextEditingController();
      final lire = await modale(
        context,
        titre: 'Texte de la recette',
        icone: Icons.notes,
        oui: 'Lire les ingrédients',
        contenu: (context, maj) => TextField(
          key: const ValueKey('texte-recette'),
          controller: texte,
          minLines: 12,
          maxLines: 20,
          style: Charte.texte(15),
          decoration: const InputDecoration(
              labelText: 'Recette (titre, ingrédients…)', hintText: 'Quiche lorraine\n200 g de lardons\n3 œufs\n20 cl de crème…'),
        ),
      );
      if (!lire || texte.text.trim().isEmpty) return true;
      r = lireRecetteTexte(texte.text);
    }
    if (r == null || !mounted) return true;
    final (ok, premier) = await cocherIngredientsRecette(context, l, r);
    if (!ok) return false;
    if (!mounted || premier == null) return true;
    // 21/11/2026 (Aristide) : l'écran va sur le premier ingrédient ajouté, sans le laisser en couleur.
    setState(() => _proposes = null);
    _amener(premier, essais: 4);
    return true;
  }

  /// Le filtre de « Mes recettes », gardé quand on y revient depuis les ingrédients (Annuler).
  final _filtreRecettes = TextEditingController();
  final _criteresRecettes = FiltreRecettes();

  /// Le catalogue de recettes : la recherche (titre ou ingrédient), les filtres combinables (20/11/2026), puis
  /// les titres par ordre alphabétique.
  Future<RecetteLue?> _choisirRecette() async {
    final toutes = await recettesFournies();
    if (!mounted) return null;
    RecetteLue? choix;
    final filtre = _criteresRecettes..texte = _filtreRecettes.text;
    await modale(
      context,
      titre: 'Mes recettes',
      oui: null,
      contenu: (context, maj) {
        final vues = [for (final r in toutes) if (filtre.garde(r)) r];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 17/11/2026 : place au-dessus du cadre pour le libellé, posé sur le bord (il était coupé).
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ChampRechercheRecette(
                champ: _filtreRecettes,
                cle: const ValueKey('filtre-recettes'),
                onTexte: (v) => maj(() => filtre.texte = v),
              ),
            ),
            const SizedBox(height: 4),
            FiltresRecettes(
              filtre: filtre,
              nombre: vues.length,
              onChange: () => maj(() {}),
              onEffacer: () => maj(() {
                filtre.effacer();
                _filtreRecettes.clear();
                filtre.texte = '';
              }),
            ),
            for (final r in vues)
              InkWell(
                key: ValueKey('recette-${r.titre}'),
                onTap: () {
                  choix = r;
                  Navigator.of(context).pop(true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(children: [
                    // 20/11/2026 (Aristide) : l'icône du type de recette devant le titre.
                    imageCritere(imageDuType(r.types), 30),
                    const SizedBox(width: 8),
                    Expanded(child: Text.rich(TextSpan(children: [
                    TextSpan(text: r.titre, style: Charte.texte(16)),
                    TextSpan(
                        text: '  ${[if (r.types.isNotEmpty) FiltreRecettes.libelle(r.types.first), if (r.tempsTotal case final t?) duree(t), if (r.difficulte != null) r.difficulte!].join(' · ')}',
                        style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ]))),
                  ]),
                ),
              ),
            if (vues.isEmpty) Text('Aucune recette', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ],
        );
      },
    );
    return choix;
  }

  void _ajouter(Liste l, Produit p, {bool avecPromo = false}) {
    if (etat.ligne(l, p.id) == null) etat.ajouterLigne(l, p.id);
    // Une nouvelle recherche referme les articles proposés d'un secteur.
    setState(() {
      _surligne = p.id;
      _proposes = null;
    });
    _amener(p.id, essais: 4);
    // 04/11/2026 (Aristide) : la promotion se propose aussitôt, dans son volet (« Sans promo » le ferme).
    final g = etat.ligne(l, p.id);
    if (avecPromo && EcranConstruction.promoApresRecherche && g != null && g.promotion == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) proposerPromo(context, l, g);
      });
    }
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
        // 13/11/2026 (Aristide) : le secteur de l'article en haut de l'écran, l'article visible dessous.
        final l = liste;
        final s = l == null ? null : etat.secteurDe(l.magasinId, produitId);
        final b = s == null ? null : _bandeaux[s.id]?.currentContext;
        if (b == null || !b.mounted) {
          Scrollable.ensureVisible(c, alignment: 0.4, duration: const Duration(milliseconds: 200));
          return;
        }
        Scrollable.ensureVisible(b, duration: const Duration(milliseconds: 200)).then((_) {
          if (mounted && c.mounted) {
            Scrollable.ensureVisible(c,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd, duration: const Duration(milliseconds: 150));
          }
        });
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
            width: 30,
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
      onPromo: () => proposerPromo(context, l, g),
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
          width: 20,
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
    final a = envoyer ? await choisirDestinataires(context) : null;
    if (!mounted) return;
    final envoi = a != null ? messageEnvoi(await envoyerListe(etat, l, a: a), a.length) : null;
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

/// Les ingrédients d'une recette à cocher, ajoutés à la liste [l] avec la consigne « pour : <recette> ». Même
/// fenêtre pour le bouton « Recette » (coches standard : placard et inconnus décochés) et pour une recette de la
/// note préparée (21/11/2026, Aristide : les ingrédients notés pré-cochés). La recette est alors marquée traitée
/// pour cette liste. Rend (faux, null) si l'on annule, sinon (vrai, premier produit ajouté).
Future<(bool, String?)> cocherIngredientsRecette(BuildContext context, Liste l, RecetteLue r,
    {int? personnes, NoteRecette? note}) async {
  final etat = Etat.instance;
  final lus = analyserIngredients(etat, r.ingredients);
  final deja = [for (final a in lus) if (a.produit != null && etat.ligne(l, a.produit!.id) != null) a];
  final aChoisir = [for (final a in lus) if (!deja.contains(a)) a];
  void traitee(List<String> lignes) {
    if (note != null) {
      etat.marquerRecette(note, NoteRecette.traitee, l);
    } else if (Nav.avecCuisiner) {
      etat.recetteTraitee(l, recette: r.id, titre: r.titre, personnes: personnes ?? r.personnes, ingredients: lignes);
    }
  }

  if (aChoisir.isEmpty) {
    Nav.message(context, deja.isEmpty ? 'Aucun ingrédient trouvé dans cette recette' : 'Tous les ingrédients sont déjà dans la liste');
    if (deja.isNotEmpty) traitee(const []);
    return (true, null);
  }
  final notes = note == null ? null : {for (final x in note.ingredients) x.trim()};
  final choisis = {
    for (var i = 0; i < aChoisir.length; i++)
      if (notes != null ? notes.contains(aChoisir[i].texte) : !aChoisir[i].placard && aChoisir[i].produit != null) i
  };
  final titre = r.titre;
  // 20/11/2026 (Aristide) : deux onglets, « Ingrédients » (les cases à cocher) et « Recette » (étapes, conseils).
  var ongletRecette = false;
  final avecTexte = r.etapes.isNotEmpty || r.conseils.isNotEmpty;
  // 20/11/2026 (Aristide) : − / + sur le nombre de personnes, les quantités suivent.
  personnes ??= note?.personnes ?? r.personnes;
  Map<String, String> lignesPour(int? n) {
    final p = r.ingredientsPour(n);
    return {for (var i = 0; i < p.length; i++) r.ingredients[i].trim(): p[i]};
  }

  final ok = await modale(
    context,
    titre: titre,
    oui: 'Ajouter à la liste',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 17/11/2026 (Aristide) : l'illustration de la recette en haut, 720 × 480, au plus un tiers de l'écran.
        IllustrationRecette(recette: r, cle: const ValueKey('illustration-recette')),
        VoletCaracteristiques(recette: r, personnes: personnes, onPersonnes: (n) => maj(() => personnes = n)),
        if (avecTexte) OngletsRecette(recette: ongletRecette, onChange: (v) => maj(() => ongletRecette = v)) else const SizedBox(height: 8),
        if (ongletRecette)
          TexteRecette(recette: r)
        else ...[
          Text(
              note != null
                  ? 'Les ingrédients notés sont cochés.'
                  : 'Cochez ce qu\'il faut acheter. Les produits du placard (sel, poivre, huile…) et ceux inconnus '
                      'du catalogue sont décochés.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 8),
          // 21/11/2026 (Aristide) : les ingrédients que le catalogue ne connaît pas, tous à part, sous « Non trouvés ».
          for (final trouve in [true, false]) ...[
            if (!trouve && aChoisir.any((a) => a.produit == null))
              Padding(
                key: const ValueKey('ingredients-non-trouves'),
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text('Non trouvés dans le catalogue', style: Charte.texte(15, gras: true, couleur: Charte.texteSecondaire)),
              ),
            for (var i = 0; i < aChoisir.length; i++)
              if ((aChoisir[i].produit != null) == trouve)
                CaseModale(
                  key: ValueKey('ingredient-$i'),
                  texte: aChoisir[i].produit?.nom ?? aChoisir[i].nom,
                  aide: lignesPour(personnes)[aChoisir[i].texte] ?? aChoisir[i].texte,
                  coche: choisis.contains(i),
                  onChange: (v) => maj(() => v ? choisis.add(i) : choisis.remove(i)),
                  encadree: false,
                ),
          ],
          if (deja.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Déjà dans la liste : ${deja.map((a) => a.produit!.nom).join(', ')}.',
                  style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ),
        ],
      ],
    ),
  );
  if (!ok) return (false, null);
  if (!context.mounted) return (true, null);
  String? premier;
  for (final i in choisis.toList()..sort()) {
    final a = aChoisir[i];
    final p = a.produit ?? etat.creerProduit(a.nom);
    etat.ajouterLigne(l, p.id);
    final c = etat.ligne(l, p.id)?.consigne;
    final pour = 'pour : $titre';
    if (c == null || !c.contains(pour)) etat.definirConsigne(l, p.id, c == null ? pour : '$c · $pour');
    premier ??= p.id;
  }
  traitee([for (final i in choisis.toList()..sort()) aChoisir[i].texte]);
  if (choisis.isNotEmpty) {
    Nav.message(context, '${choisis.length} produit${choisis.length > 1 ? 's' : ''} ajouté${choisis.length > 1 ? 's' : ''} pour « $titre »');
  }
  return (true, premier);
}

/// Bandeau pliable « Recettes choisies » (21/11/2026, Aristide), en tête de la préparation et des courses.
class BandeauRecettes extends StatelessWidget {
  const BandeauRecettes({super.key, required this.cle, required this.lignes});
  final String cle;
  final List<Widget> lignes;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Retractables.i,
        builder: (context, _) {
          final ouvert = Retractables.i.ouvert(cle);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            TitreGroupe(
              key: const ValueKey('recettes-choisies'),
              nom: 'Recettes choisies',
              icone: Icons.menu_book_outlined,
              nombre: lignes.length,
              ouvert: ouvert,
              onTap: () => Retractables.i.basculer(cle),
            ),
            if (ouvert) ...lignes,
          ]);
        },
      );
}

/// Une recette de la note : son état (à traiter, ajoutée, ignorée) par une icône, son titre.
class LigneRecetteChoisie extends StatelessWidget {
  const LigneRecetteChoisie({super.key, required this.note, this.onTap, this.onLongPress, this.courses = false});
  final NoteRecette note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Pendant les courses : seulement le titre et le nombre de personnes.
  final bool courses;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final (icone, couleur, etatTexte) = switch (n.etat) {
      NoteRecette.traitee => (Icons.check_circle, Charte.vert, courses ? (n.personnes == null ? '' : 'pour ${n.personnes} pers.') : 'ajoutée à la liste'),
      NoteRecette.ignoree => (Icons.cancel_outlined, Charte.texteSecondaire, 'ignorée'),
      _ => (Icons.pending_outlined, Charte.orange, '${n.ingredients.length} ingrédient${n.ingredients.length > 1 ? 's' : ''} à ajouter'),
    };
    final ignoree = n.etat == NoteRecette.ignoree;
    return InkWell(
      key: ValueKey('recette-choisie-${n.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Icone(icone, size: 24, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: n.titre,
                  style: Charte.texte(16, couleur: ignoree ? Charte.texteSecondaire : Charte.encre)
                      .copyWith(decoration: ignoree ? TextDecoration.lineThrough : null)),
              TextSpan(text: '  $etatTexte', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ])),
          ),
        ]),
      ),
    );
  }
}

/// La recette d'une note, dans le catalogue des recettes (null si elle n'y est plus).
Future<RecetteLue?> recetteNotee(NoteRecette n) async {
  final toutes = await recettesFournies();
  return toutes.where((r) => n.recette != null ? r.id == n.recette : r.titre == n.titre).firstOrNull;
}

Future<void> voirRecetteNotee(BuildContext context, NoteRecette n) async {
  final r = await recetteNotee(n);
  if (r != null && context.mounted) await Nav.aller<void>(context, FicheRecette(recette: r));
}
