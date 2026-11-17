part of '../travail.dart';


/// Écran 3 — Construction par secteur. Chaque action est enregistrée ; quitter ne perd rien.
class EcranConstruction extends StatefulWidget {
  const EcranConstruction({super.key, required this.listeId});
  final String listeId;

  /// Après un ajout par la recherche, le volet « Promo » s'ouvre (04/11/2026) ; coupé par certains essais.
  static bool promoApresRecherche = true;

  /// 15/11/2026 : le bouton « Recette » (ingrédients d'une recette à cocher) ; démonstration d'abord.
  static bool recettes = demonstration;

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
            sousTitre: '${simple ? 'Liste simple · ' : ''}$n article${n > 1 ? 's' : ''} · '
                '${etat.coursesPrevues(l).isEmpty ? etat.creeeLe(l) : etat.coursesPrevues(l)}',
            aide: simple ? Aides.listeSimple : Aides.preparation,
            // 15/11/2026 (Aristide) : bouton « Recette » en bas à droite de l'en-tête (démonstration d'abord).
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
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Tapez le début du nom d\'un article dans le champ ci-dessus et touchez-le : il s\'ajoute à la liste.',
                      style: Charte.texte(16, couleur: Charte.texteSecondaire)),
                )
              : avecLoupe(
                  context,
                  ListView(
                  controller: _defilement,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: simple
                      ? [for (final g in l.lignes) _ligne(l, g)]
                      : [
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
    RecetteLue? r;
    if (source == 0) {
      r = await _choisirRecette();
    } else if (source == 1) {
      final lien = await demanderTexte(context,
          titre: 'Lien de la recette', libelle: 'Adresse de la page', valider: 'Lire la recette',
          cleChamp: const ValueKey('lien-recette'));
      if (lien == null || lien.trim().isEmpty || !mounted) return;
      try {
        Nav.message(context, 'Lecture de la page…');
        r = await recetteDepuisLien(lien);
      } catch (_) {
        if (mounted) {
          Nav.message(context, 'Cette page ne peut pas être lue ici. Copiez le texte de la recette, '
              'puis choisissez « Texte de la recette ».');
        }
        return;
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
      if (!lire || texte.text.trim().isEmpty) return;
      r = lireRecetteTexte(texte.text);
    }
    if (r == null || !mounted) return;
    final lus = analyserIngredients(etat, r.ingredients);
    final deja = [for (final a in lus) if (a.produit != null && etat.ligne(l, a.produit!.id) != null) a];
    final aChoisir = [for (final a in lus) if (!deja.contains(a)) a];
    if (aChoisir.isEmpty) {
      Nav.message(context, deja.isEmpty ? 'Aucun ingrédient trouvé dans cette recette' : 'Tous les ingrédients sont déjà dans la liste');
      return;
    }
    final choisis = {for (var i = 0; i < aChoisir.length; i++) if (!aChoisir[i].placard && aChoisir[i].produit != null) i};
    final titre = r.titre;
    final ok = await modale(
      context,
      titre: titre,
      oui: 'Ajouter à la liste',
      contenu: (context, maj) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 17/11/2026 (Aristide) : l'illustration de la recette en haut, 720 × 480, au plus un tiers de l'écran.
          if (r!.image case final image?) _illustration(image),
          Text('Cochez ce qu\'il faut acheter. Les produits du placard (sel, poivre, huile…) et ceux inconnus '
              'du catalogue sont décochés.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 8),
          for (var i = 0; i < aChoisir.length; i++)
            CaseModale(
              key: ValueKey('ingredient-$i'),
              texte: aChoisir[i].produit?.nom ?? '${aChoisir[i].nom} (nouveau)',
              aide: aChoisir[i].texte,
              coche: choisis.contains(i),
              onChange: (v) => maj(() => v ? choisis.add(i) : choisis.remove(i)),
              encadree: false,
            ),
          if (deja.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Déjà dans la liste : ${deja.map((a) => a.produit!.nom).join(', ')}.',
                  style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ),
        ],
      ),
    );
    if (!ok || !mounted || choisis.isEmpty) return;
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
    setState(() {
      _surligne = premier;
      _proposes = null;
    });
    if (premier != null) _amener(premier, essais: 4);
    Nav.message(context, '${choisis.length} produit${choisis.length > 1 ? 's' : ''} ajouté${choisis.length > 1 ? 's' : ''} pour « $titre »');
  }

  Widget _illustration(String image) {
    Widget rien(BuildContext _, Object __, StackTrace? ___) => const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image.startsWith('http')
                ? Image.network(image, key: const ValueKey('illustration-recette'), fit: BoxFit.cover, errorBuilder: rien)
                : Image.asset(image, key: const ValueKey('illustration-recette'), fit: BoxFit.cover, errorBuilder: rien),
          ),
        ),
      ),
    );
  }

  /// Le catalogue de recettes : un champ pour filtrer, puis les titres par ordre alphabétique.
  Future<RecetteLue?> _choisirRecette() async {
    final toutes = await recettesFournies();
    if (!mounted) return null;
    RecetteLue? choix;
    var filtre = '';
    await modale(
      context,
      titre: 'Mes recettes',
      oui: null,
      contenu: (context, maj) {
        final f = normaliser(filtre);
        final vues = [for (final r in toutes) if (f.isEmpty || normaliser(r.titre).contains(f)) r];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('filtre-recettes'),
              style: Charte.texte(15),
              decoration: const InputDecoration(labelText: 'Chercher une recette', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => maj(() => filtre = v),
            ),
            const SizedBox(height: 6),
            for (final r in vues)
              InkWell(
                key: ValueKey('recette-${r.titre}'),
                onTap: () {
                  choix = r;
                  Navigator.of(context).pop(true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: r.titre, style: Charte.texte(16)),
                    if (r.types.isNotEmpty)
                      TextSpan(text: '  ${r.types.first}', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ])),
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
