import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../donnees/images_perso.dart';
import '../donnees/journal_catalogue.dart';
import 'console_catalogue.dart';
import '../donnees/modele.dart';
import '../donnees/signature.dart';
import '../donnees/univers.dart';
import '../navigation.dart';
import '../theme.dart';

// Outil de l'éditeur du catalogue commun (application Windows à part depuis le 06/11/2026 ; voir main.dart, OUTIL_EDITEUR).
// Les modifications forment un brouillon gardé dans le navigateur ; « Généraliser » publie une version numérotée
// pour tous les foyers.

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

class EcranEditeurCatalogue extends StatefulWidget {
  const EcranEditeurCatalogue(
      {super.key, this.auChangement, this.actionsAPart = false, this.large = false, this.versIconographie});

  /// Console Windows : disposition grand écran ([CatalogueLarge]) au lieu de l'écran du téléphone (07/11/2026).
  final bool large;

  /// Ouvre l'iconographie (proposé quand des rayons ou secteurs n'ont pas d'icône à la généralisation).
  final VoidCallback? versIconographie;

  /// Prévenu à chaque modification du brouillon (panneau de droite de la console).
  final VoidCallback? auChangement;

  /// Console Windows : les actions générales sont dans le panneau de droite, pas dans l'écran du téléphone.
  final bool actionsAPart;

  /// Relire la version publiée sur le serveur à l'ouverture (coupé dans les tests, sans serveur).
  static bool actualiserAuServeur = true;

  @override
  State<EcranEditeurCatalogue> createState() => EtatEditeurCatalogue();
}

/// État public : la console d'administration (fenêtre Windows) appelle ses actions depuis le panneau de droite.
class EtatEditeurCatalogue extends State<EcranEditeurCatalogue> {
  Brouillon? b;
  Map<String, dynamic>? publie;
  bool _publication = false;

  /// Historique : étapes validées et gestes en cours (07/11/2026, Aristide).
  JournalCatalogue journal = JournalCatalogue([], []);

  /// Le brouillon au geste précédent, pour noter ce que fait le suivant.
  Map<String, dynamic>? _avant;

  /// Console grand écran : ouvre la fenêtre de l'iconographie (« Compléter » avant de généraliser).
  VoidCallback? ouvrirIconographie;

  /// Nombre de gestes en cours, pas encore validés.
  int get enCours => journal.enCours.length;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Relit la dernière version publiée sur le serveur, puis le brouillon.
  Future<void> _charger() async {
    final c = CatalogueCommun.instance;
    if (EcranEditeurCatalogue.actualiserAuServeur) await c.actualiser();
    final d = await c.dernier();
    final x = await c.brouillon();
    if (mounted) {
      setState(() {
        publie = d;
        b = x;
        journal = c.journal();
        // Premier usage : le point de départ est le brouillon tel qu'il est.
        if (journal.etapes.isEmpty) {
          journal.valider('Point de départ', CatalogueCommun.emballer(x.versJsonSansImages()),
              numero: x.modifications == 0 && _numero > 0 ? _numero : null);
          c.enregistrerJournal(journal);
        }
        _avant = x.versJson();
        remplacerImagesPerso(x.imagesPerso);
      });
      widget.auChangement?.call();
    }
  }

  void _modifie() {
    final c = CatalogueCommun.instance;
    c.enregistrerBrouillon(b!);
    final apres = b!.versJson();
    remplacerImagesPerso(b!.imagesPerso);
    if (_avant != null) journal.noter(gestesEntre(_avant!, apres));
    _avant = apres;
    c.enregistrerJournal(journal);
    setState(() {});
    widget.auChangement?.call();
  }

  /// « Valider les modifications » : les gestes en cours deviennent une étape nommée, point de sauvegarde.
  Future<void> valider() async {
    final b = this.b;
    if (b == null || enCours == 0) return;
    final defaut = JournalCatalogue.nomParDefaut(DateTime.now());
    final nom = await demanderTexte(context,
        titre: 'Valider ${_pluriel(enCours, 'modification')} ?', aide: 'Nom de l\'étape (par défaut le jour et l\'heure)', libelle: 'Nom de l\'étape', initial: defaut, valider: 'Valider');
    if (nom == null || !mounted) return;
    final e = journal.valider(nom.trim().isEmpty ? defaut : nom.trim(), CatalogueCommun.emballer(b.versJsonSansImages()));
    CatalogueCommun.instance.enregistrerJournal(journal);
    setState(() {});
    widget.auChangement?.call();
    Nav.message(context, 'Étape « ${e.nom} » validée : ${_pluriel(e.gestes.length, 'modification')}');
  }

  /// Revient à l'étape [i] de l'historique : tout ce qui l'a suivie est abandonné. Rend vrai si c'est fait.
  Future<bool> revenirA(int i) async {
    final e = journal.etapes[i];
    final suivantes = journal.etapes.length - 1 - i;
    final perdu = [
      if (suivantes > 0) _pluriel(suivantes, 'étape suivante'),
      if (enCours > 0) _pluriel(enCours, 'modification en cours'),
    ].join(' et ');
    final ok = await confirmer(
      context,
      titre: 'Revenir à « ${e.nom} » ?',
      icone: Icons.history,
      contenu: Text(
        perdu.isEmpty ? 'Le catalogue est déjà à cette étape.' : 'Toutes les modifications qui ont suivi sont abandonnées : $perdu.',
        style: Charte.texte(16),
      ),
      plein: 'Annuler',
      contour: 'Revenir',
    );
    if (ok != true || !mounted) return false;
    final c = CatalogueCommun.instance;
    final j = CatalogueCommun.deballer(journal.revenirA(i));
    // Revenue à la version publiée : rien à généraliser ; sinon il y a à généraliser.
    j['modifications'] = e.numero != null && e.numero == _numero ? 0 : ((j['modifications'] as num? ?? 0).toInt()).clamp(1, 1 << 30);
    // Les images ajoutées ne reviennent pas en arrière : elles restent dans la bibliothèque.
    if (b != null && b!.imagesPerso.isNotEmpty) j['imagesPerso'] = imagesPersoVersJson(b!.imagesPerso);
    final nouveau = Brouillon.lire(j);
    c.enregistrerBrouillon(nouveau);
    c.enregistrerJournal(journal);
    setState(() {
      b = nouveau;
      _avant = nouveau.versJson();
    });
    widget.auChangement?.call();
    Nav.message(context, 'Catalogue revenu à « ${e.nom} »');
    return true;
  }

  Future<void> historique() async {
    await Nav.aller<void>(context, EcranHistoriqueCatalogue(editeur: this));
    if (mounted) setState(() {});
  }

  /// Numéro de la dernière version publiée (0 : aucune).
  int get numeroPublie => _numero;
  bool get enPublication => _publication;

  Future<void> repartir() => _repartir();
  Future<void> nouveauRayon() async {
    final b = this.b;
    if (b == null) return;
    final nom = await demanderTexte(context, titre: 'Nouveau rayon', valider: 'Ajouter');
    if (nom == null || nom.trim().isEmpty) return;
    b.ajouterRayon(nom);
    _modifie();
  }

  Future<void> depuisTexte() async {
    if (b != null && await ajouterDepuisTexte(context, b!)) _modifie();
  }

  Future<void> cleSignature() async {
    if (b != null) await _cleSignature(b!);
  }

  /// La dernière version publiée depuis cet outil manque sur le serveur (publiée ailleurs, ou effacée).
  bool get absenteDuServeur {
    final n = CatalogueCommun.instance.numeroServeur;
    return n != null && _numero > n;
  }

  Future<void> renvoyer() async {
    if (_publication) return;
    if (CatalogueCommun.instance.graineSignature == null && await _demanderPhrase() == null) return;
    if (!mounted) return;
    setState(() => _publication = true);
    widget.auChangement?.call();
    final ok = await CatalogueCommun.instance.renvoyer();
    if (!mounted) return;
    setState(() => _publication = false);
    await _charger();
    if (mounted) {
      Nav.message(
        context,
        ok
            ? 'Version v$_numero renvoyée au serveur : chaque foyer la reçoit à son prochain lancement'
            : 'Rien n\'est envoyé (${CatalogueCommun.instance.erreur ?? 'le serveur ne répond pas'}) : réessayez',
      );
    }
  }

  Future<void> generaliser() async {
    if (b == null || _publication || b!.modifications == 0) return;
    // 07/11/2026 (Aristide) : n'est généralisable que ce qui est validé.
    if (enCours > 0) {
      Nav.message(context, 'Validez d\'abord les ${_pluriel(enCours, 'modification')} en cours');
      return;
    }
    await _publier(b!);
  }

  /// Ce qui changera à la prochaine généralisation.
  Recapitulatif? get recapitulatif => b == null ? null : Recapitulatif.entre(publie ?? const {}, b!.versJson());

  int get _numero => ((publie?['numero'] as num?) ?? 0).toInt();

  static String _cleR(CatRayon r) => 'editeur-r/${r.nom}';
  static String _cleS(CatRayon r, CatSecteur s) => 'editeur-s/${r.nom}/${s.nom}';
  List<String> _cles(Brouillon b) => [
    for (final r in b.catalogue.rayons) ...[_cleR(r), for (final s in r.secteurs) _cleS(r, s)],
  ];
  bool _toutOuvert(Brouillon b) => _cles(b).every((c) => Retractables.i.ouvert(c, parDefaut: false));

  /// 07/11/2026 (Aristide) : arbre comme Gérer › Catalogue. Le bandeau déplie ou replie (chevron), le crayon
  /// ouvre les actions de ce rayon ou de ce secteur ; les produits se déplient sous leur secteur, sur le même écran,
  /// et un toucher sur un produit ouvre ses actions.
  /// Actions d'un rayon (volet du crayon, ici et dans la console grand écran).
  List<ActionLigne> actionsRayon(BuildContext context, CatRayon r) {
    final b = this.b!;
    return [
          ActionLigne(Icons.add, '+ Nouveau secteur', () async {
            final nom = await demanderTexte(context, titre: 'Nouveau secteur · ${r.nom}', valider: 'Ajouter');
            if (nom == null || nom.trim().isEmpty) return;
            b.ajouterSecteur(r, nom);
            _modifie();
          }),
          if (r.secteurs.length > 1)
            ActionLigne(Icons.drag_handle, 'Changer l\'ordre des secteurs', () async {
              final noms = await ordonner(context, titre: 'Ordre des secteurs · ${r.nom}', noms: [for (final s in r.secteurs) s.nom]);
              if (noms == null) return;
              b.ordonnerSecteurs(r, noms);
              _modifie();
            }),
          ActionLigne(Icons.notes, 'Ajouter depuis un texte', () async {
            if (await ajouterDepuisTexte(context, b, rayon: r)) _modifie();
          }),
          ActionLigne(Icons.edit_outlined, 'Renommer le rayon', () async {
            final nom = await demanderTexte(context, titre: 'Nom du rayon', initial: r.nom);
            if (nom == null) return;
            b.renommerRayon(r, nom);
            _modifie();
          }),
          ActionLigne(Icons.delete_outline, 'Supprimer le rayon', () async {
            if (r.secteurs.isNotEmpty &&
                !await _confirmerSuppression(
                  context,
                  'le rayon ${r.nom}',
                  '${_pluriel(r.secteurs.length, 'secteur')} et ${_pluriel(r.secteurs.fold(0, (n, s) => n + s.produits.length), 'produit')}',
                )) {
              return;
            }
            b.retirerRayon(r);
            _modifie();
          }),
    ];
  }

  /// Enregistre le brouillon après un geste et le note au journal.
  void modifie() => _modifie();

  Widget _rayon(BuildContext context, Brouillon b, CatRayon r) {
    final plis = Retractables.i;
    final ouvert = plis.ouvert(_cleR(r), parDefaut: false);
    return NiveauArbre(
      cle: _cleR(r),
      niveau: 2,
      profondeur: 1,
      nom: r.nom,
      tailleSigne: 38,
      signe: Pictogramme(iconeRayon(r.nom, b.images), taille: 36),
      nombre: r.secteurs.length,
      ouvert: ouvert,
      onTap: () => setState(() => plis.basculer(_cleR(r), parDefaut: false)),
      onCrayon: () => menuActions(context, titre: 'Rayon ${r.nom}', actions: actionsRayon(context, r)),
      enfants: [
        if (ouvert)
          for (final s in r.secteurs) _secteur(context, b, r, s),
      ],
    );
  }

  Widget _secteur(BuildContext context, Brouillon b, CatRayon r, CatSecteur s) {
    final plis = Retractables.i;
    final ouvert = plis.ouvert(_cleS(r, s), parDefaut: false);
    final produits = ouvert ? ([...s.produits]..sort((a, c) => a.nom.toLowerCase().compareTo(c.nom.toLowerCase()))) : const <CatProduit>[];
    return NiveauArbre(
      cle: _cleS(r, s),
      niveau: 3,
      profondeur: 2,
      nom: s.nom,
      tailleSigne: 32,
      signe: Pictogramme(iconeSecteur(r.nom, s.nom, b.images), taille: 30),
      nombre: s.produits.length,
      ouvert: ouvert,
      onTap: () => setState(() => plis.basculer(_cleS(r, s), parDefaut: false)),
      onCrayon: () => menuActions(context, titre: 'Secteur ${s.nom}', actions: actionsSecteurEditeur(context, b, r, s, _modifie)),
      enfants: [
        if (produits.isEmpty)
          FeuilleArbre(
            profondeur: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Aucun produit dans ce secteur.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
          ),
        for (final p in produits)
          FeuilleArbre(
            profondeur: 3,
            child: LigneMenu(
              key: ValueKey('editeur-p/${r.nom}/${s.nom}/${p.nom}'),
              titre: p.nom,
              fond: Charte.niveau(4),
              onTap: () => menuActions(context, titre: 'Produit ${p.nom}', actions: actionsProduitEditeur(context, b, s, p, _modifie)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = this.b;
    if (widget.large) return CatalogueLarge(editeur: this);
    return PageBase(
      entete: EnTeteFenetre(
        icone: Icons.public,
        sousTitre: 'Emplettes · outil de l\'éditeur',
        titre: 'Catalogue commun',
        // 07/11/2026 (Aristide) : tout déplier, tout replier (rayons et secteurs).
        droite: b == null
            ? null
            : boutonEnTete(
                _toutOuvert(b) ? Icons.unfold_less : Icons.unfold_more,
                _toutOuvert(b) ? 'Tout replier' : 'Tout déplier',
                () => setState(() => Retractables.i.tous(_cles(b), !_toutOuvert(b))),
              ),
        actions: [
          if (b != null && !widget.actionsAPart) ...[
            ActionLigne(Icons.restore, 'Repartir d\'un catalogue', () => _repartir()),
            ActionLigne(Icons.add, '+ Nouveau rayon', () async {
              final nom = await demanderTexte(context, titre: 'Nouveau rayon', valider: 'Ajouter');
              if (nom == null || nom.trim().isEmpty) return;
              b.ajouterRayon(nom);
              _modifie();
            }),
            ActionLigne(Icons.notes, 'Ajouter depuis un texte', () async {
              if (await ajouterDepuisTexte(context, b)) _modifie();
            }),
            ActionLigne(Icons.key_outlined, 'Clé de signature', () => _cleSignature(b)),
            ActionLigne(Icons.history, 'Historique', historique),
          ],
        ],
      ),
      corps: b == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text(
                    '${_numero == 0 ? 'Aucune version publiée : catalogue livré avec l\'application' : 'Version publiée : v$_numero du ${_date((publie!['version'] as num).toInt())}'}.\n'
                    'Brouillon : ${_pluriel(b.catalogue.rayons.length, 'rayon')}, ${_pluriel(b.nbProduits, 'produit')}, '
                    '${b.modifications == 0 ? 'aucune modification.' : '${_pluriel(b.modifications, 'modification')} à généraliser.'}\n'
                    '${enCours == 0 ? 'Rien en cours : tout est validé.' : '${_pluriel(enCours, 'modification')} en cours, à valider.'}',
                    style: Charte.texte(14, couleur: Charte.texteSecondaire),
                  ),
                ),
                ColonneDebord(children: [for (final r in b.catalogue.rayons) _rayon(context, b, r)]),
              ],
            ),
      bas: [
        if (b != null && !widget.actionsAPart)
          BarreAction(
            boutons: [
              Bouton(
                key: const ValueKey('valider'),
                texte: 'Valider ($enCours)',
                icone: Icons.check,
                onTap: enCours == 0 ? null : valider,
              ),
              Bouton(
                key: const ValueKey('generaliser'),
                texte: _publication ? 'Envoi…' : 'Généraliser (v${_numero + 1})',
                icone: Icons.public,
                plein: true,
                onTap: _publication || b.modifications == 0 || enCours > 0 ? null : generaliser,
              ),
            ],
          ),
      ],
    );
  }

  /// « Repartir d'un catalogue » : une des versions gardées sur le serveur, ou le catalogue proposé par un foyer.
  Future<void> _repartir() async {
    Nav.message(context, 'Lecture des versions et des propositions…');
    final c = CatalogueCommun.instance;
    final versions = await c.versions();
    final propositions = await c.propositions();
    if (!mounted) return;
    final choix = <String, String>{
      for (var i = 0; i < versions.length; i++)
        'v$i': 'Version v${versions[i]['numero'] ?? '?'} du ${_date(((versions[i]['version'] as num?) ?? 0).toInt())}',
      for (var i = 0; i < propositions.length; i++)
        'p$i':
            'Foyer n° ${propositions[i]['foyer'] ?? '?'} · ${_pluriel(((propositions[i]['changements'] as num?) ?? 0).toInt(), 'changement')} '
            '· ${'${propositions[i]['date'] ?? ''}'.replaceFirst('T', ' à ')}',
    };
    if (choix.isEmpty) {
      Nav.message(context, 'Ni version gardée ni proposition sur le serveur');
      return;
    }
    final k = await choisirDansListe<String>(context, titre: 'Repartir d\'un catalogue', choix: choix);
    if (k == null || !mounted) return;
    final j = k.startsWith('v') ? versions[int.parse(k.substring(1))] : propositions[int.parse(k.substring(1))];
    final ok = await confirmer(
      context,
      titre: 'Remplacer le brouillon ?',
      icone: Icons.restore,
      contenu: Text('Le brouillon devient « ${choix[k]} ». Ce qu\'il contenait jusqu\'ici est abandonné.', style: Charte.texte(16)),
      plein: 'Annuler',
      contour: 'Remplacer',
    );
    if (ok != true || !mounted) return;
    final nouveau = c.repartirDe(j, modifications: k.startsWith('p') ? ((j['changements'] as num?) ?? 1).toInt() : 1);
    journal.noter(['Repris de « ${choix[k]} »', ...gestesEntre(_avant ?? const {}, nouveau.versJson())]);
    _avant = nouveau.versJson();
    c.enregistrerJournal(journal);
    setState(() => b = nouveau);
    widget.auChangement?.call();
    Nav.message(context, 'Brouillon repris de « ${choix[k]} »');
  }

  Future<void> _publier(Brouillon b) async {
    // 07/11/2026 (Aristide) : avant de généraliser, avertir des rayons et secteurs sans icône.
    final manquantes = sansIcone(b);
    if (manquantes > 0) {
      final generaliser = await confirmer(
        context,
        titre: '${_pluriel(manquantes, 'rayon ou secteur')} sans icône',
        icone: Icons.hide_image_outlined,
        contenu: Text('Vous pouvez compléter l\'iconographie avant de généraliser.', style: Charte.texte(16)),
        plein: 'Compléter',
        contour: 'Généraliser quand même',
      );
      if (!mounted || generaliser == null) return;
      if (!generaliser) {
        (ouvrirIconographie ?? widget.versIconographie)?.call();
        return;
      }
    }
    final recap = Recapitulatif.entre(publie ?? const {}, b.versJson());
    final ok = await confirmer(
      context,
      titre: 'Généraliser la version v${_numero + 1} ?',
      icone: Icons.public,
      contenu: RecapitulatifVue(recap),
      plein: 'Annuler',
      contour: 'Généraliser',
    );
    if (ok != true || !mounted) return;
    // Le catalogue part signé : la phrase est demandée une fois sur cet appareil.
    if (CatalogueCommun.instance.graineSignature == null && await _demanderPhrase() == null) return;
    if (!mounted) return;
    setState(() => _publication = true);
    widget.auChangement?.call();
    var fait = false;
    try {
      fait = await CatalogueCommun.instance.publierBrouillon(b);
    } catch (e) {
      CatalogueCommun.instance.erreur = '$e';
    }
    if (!mounted) return;
    if (fait) {
      setState(() => _publication = false);
      widget.auChangement?.call();
      await _charger();
      journal.generalisee(_numero);
      CatalogueCommun.instance.enregistrerJournal(journal);
      if (mounted) Nav.message(context, 'Version v$_numero généralisée : chaque foyer la reçoit à son prochain lancement');
    } else {
      setState(() => _publication = false);
      widget.auChangement?.call();
      Nav.message(
        context,
        'Rien n\'est publié (${CatalogueCommun.instance.erreur ?? 'le serveur ne répond pas'}) : le brouillon est gardé, réessayez',
      );
    }
  }

  /// Demande la phrase de signature de l'éditeur ; rend la clé publique, ou null.
  Future<String?> _demanderPhrase() async {
    final phrase = await demanderTexte(
      context,
      titre: 'Phrase de signature',
      libelle: 'Phrase',
      aide: 'Au moins 8 caractères, connue de vous seul',
      valider: 'Valider',
    );
    if (phrase == null || !mounted) return null;
    final cle = await CatalogueCommun.instance.definirPhrase(phrase);
    if (cle == null && mounted) {
      Nav.message(
        context,
        phrase.trim().length < 8 ? 'Phrase trop courte (8 caractères au moins)' : 'Ce n\'est pas la phrase de l\'éditeur',
      );
    }
    return cle;
  }

  Future<void> _cleSignature(Brouillon b) async {
    final cle = await CatalogueCommun.instance.clePublique() ?? await _demanderPhrase();
    if (cle == null || !mounted) return;
    final copier = await confirmer(
      context,
      titre: 'Clé de signature',
      icone: Icons.key_outlined,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clePubliqueEditeur.isEmpty
                ? 'Envoyez cette clé à Claude : elle n\'est pas secrète. Une fois dans l\'application, seuls les catalogues '
                      'signés par votre phrase seront acceptés.'
                : 'Cette clé est celle de l\'application : vos versions sont reconnues par tous les foyers.',
            style: Charte.texte(15),
          ),
          const SizedBox(height: 10),
          SelectableText(cle, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ],
      ),
      plein: 'Fermer',
      contour: 'Copier',
    );
    if (copier == true) await Clipboard.setData(ClipboardData(text: cle));
  }
}

/// Ce qui change entre la dernière version publiée et le brouillon (comparaison par noms).
class Recapitulatif {
  Recapitulatif(
    this.rayonsAjoutes,
    this.rayonsRetires,
    this.secteursAjoutes,
    this.secteursRetires,
    this.produitsAjoutes,
    this.produitsRetires,
    this.produitsDeplaces,
    this.renommes,
  );
  final List<String> rayonsAjoutes, rayonsRetires, secteursAjoutes, secteursRetires, produitsAjoutes, produitsRetires, produitsDeplaces;
  final int renommes;

  bool get vide =>
      rayonsAjoutes.isEmpty &&
      rayonsRetires.isEmpty &&
      secteursAjoutes.isEmpty &&
      secteursRetires.isEmpty &&
      produitsAjoutes.isEmpty &&
      produitsRetires.isEmpty &&
      produitsDeplaces.isEmpty &&
      renommes == 0;

  factory Recapitulatif.entre(Map<String, dynamic> avant, Map<String, dynamic> apres) {
    ({Set<String> rayons, Set<String> secteurs, Map<String, Set<String>> produits}) lire(Map<String, dynamic> j) {
      final rayons = <String>{}, secteurs = <String>{};
      final produits = <String, Set<String>>{};
      for (final r in (j['rayons'] as List? ?? const []).cast<Map>()) {
        rayons.add('${r['nom']}');
        for (final x in (r['secteurs'] as List? ?? const []).cast<Map>()) {
          secteurs.add('${r['nom']} › ${x['nom']}');
          for (final p in (x['produits'] as List? ?? const []).cast<Map>()) {
            (produits['${p['nom']}'] ??= {}).add('${r['nom']} › ${x['nom']}');
          }
        }
      }
      return (rayons: rayons, secteurs: secteurs, produits: produits);
    }

    final a = lire(avant), b = lire(apres);
    List<String> trie(Iterable<String> l) => l.toList()..sort();
    // Un produit à une seule place avant et après, mais pas la même : déplacé ; sinon chaque place compte à part.
    final deplaces = <String>[];
    final ajoutes = <String>[], retires = <String>[];
    for (final nom in {...a.produits.keys, ...b.produits.keys}) {
      final av = a.produits[nom] ?? const <String>{}, ap = b.produits[nom] ?? const <String>{};
      if (av.length == 1 && ap.length == 1 && av.first != ap.first) {
        deplaces.add('$nom, vers ${ap.first}');
        continue;
      }
      for (final x in ap.difference(av)) {
        ajoutes.add('$nom ($x)');
      }
      for (final x in av.difference(ap)) {
        retires.add('$nom ($x)');
      }
    }
    final renommes = (apres['renommes'] as List? ?? const []).length - (avant['renommes'] as List? ?? const []).length;
    return Recapitulatif(
      trie(b.rayons.difference(a.rayons)),
      trie(a.rayons.difference(b.rayons)),
      trie(b.secteurs.difference(a.secteurs)),
      trie(a.secteurs.difference(b.secteurs)),
      trie(ajoutes),
      trie(retires),
      trie(deplaces),
      renommes < 0 ? 0 : renommes,
    );
  }
}

/// Le récapitulatif montré avant de généraliser : un titre par nature de changement, puis les noms.
class RecapitulatifVue extends StatelessWidget {
  const RecapitulatifVue(this.r, {super.key});
  final Recapitulatif r;

  @override
  Widget build(BuildContext context) {
    Widget bloc(String titre, List<String> noms) => noms.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$titre (${noms.length})', style: Charte.texte(15, gras: true)),
                for (final n in noms.take(12)) Text('· $n', style: Charte.texte(14)),
                if (noms.length > 12) Text('· et ${noms.length - 12} autres', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
              ],
            ),
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.vide
                  ? 'Aucune différence avec la version publiée.'
                  : 'Par rapport à la version publiée. Chaque foyer la reçoit à son prochain lancement et garde ses '
                        'propres modifications ; ce qui sert à ses listes n\'est jamais retiré.',
              style: Charte.texte(15, couleur: Charte.texteSecondaire),
            ),
            const SizedBox(height: 10),
            bloc('Rayons ajoutés', r.rayonsAjoutes),
            bloc('Rayons retirés', r.rayonsRetires),
            bloc('Secteurs ajoutés', r.secteursAjoutes),
            bloc('Secteurs retirés', r.secteursRetires),
            bloc('Produits ajoutés', r.produitsAjoutes),
            bloc('Produits déplacés', r.produitsDeplaces),
            bloc('Produits retirés', r.produitsRetires),
            if (r.renommes > 0) Text('Noms corrigés : ${r.renommes}', style: Charte.texte(15, gras: true)),
          ],
        ),
      ),
    );
  }
}

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${jjmmaaaa(d)} à ${heure(d)}';
}

/// Actions d'un produit du catalogue commun.
List<ActionLigne> actionsProduitEditeur(BuildContext context, Brouillon b, CatSecteur s, CatProduit p, VoidCallback modifie) => [
  ActionLigne(Icons.edit_outlined, 'Renommer le produit', () async {
    final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
    if (nom == null) return;
    b.renommerProduit(p, nom);
    modifie();
  }),
  ActionLigne(Icons.delete_outline, 'Retirer le produit', () {
    b.retirerProduit(s, p);
    modifie();
  }, danger: true),
];

/// Actions d'un secteur du catalogue commun ; [quitter] ferme l'écran du secteur quand il est déplacé ou retiré.
List<ActionLigne> actionsSecteurEditeur(
  BuildContext context,
  Brouillon b,
  CatRayon r,
  CatSecteur s,
  VoidCallback modifie, {
  VoidCallback? quitter,
}) => [
  ActionLigne(Icons.add, '+ Nouveau produit', () async {
    final nom = await demanderTexte(context, titre: 'Nouveau produit · ${s.nom}', valider: 'Ajouter');
    if (nom == null || nom.trim().isEmpty || !context.mounted) return;
    if (!b.ajouterProduit(s, nom)) {
      Nav.message(context, '« ${nom.trim()} » est déjà dans ce secteur');
      return;
    }
    modifie();
  }),
  ActionLigne(Icons.notes, 'Ajouter depuis un texte', () async {
    if (await ajouterDepuisTexte(context, b, rayon: r, secteur: s)) modifie();
  }),
  ActionLigne(Icons.edit_outlined, 'Renommer le secteur', () async {
    final nom = await demanderTexte(context, titre: 'Nom du secteur', initial: s.nom);
    if (nom == null) return;
    b.renommerSecteur(r, s, nom);
    modifie();
  }),
  ActionLigne(Icons.drive_file_move_outline, 'Déplacer dans un autre rayon', () async {
    final vers = await _choisirRayon(context, b, titre: 'Déplacer ${s.nom} vers', sauf: r);
    if (vers == null || !context.mounted) return;
    b.deplacerSecteur(r, s, vers);
    modifie();
    quitter?.call();
    Nav.message(context, '${s.nom} déplacé dans ${vers.nom}');
  }),
  ActionLigne(Icons.delete_outline, 'Supprimer le secteur', () async {
    if (s.produits.isNotEmpty && !await _confirmerSuppression(context, 'le secteur ${s.nom}', _pluriel(s.produits.length, 'produit'))) {
      return;
    }
    b.retirerSecteur(r, s);
    modifie();
    quitter?.call();
  }, danger: true),
];

Future<bool> _confirmerSuppression(BuildContext context, String quoi, String contenu) async {
  final ok = await confirmer(
    context,
    titre: 'Supprimer $quoi ?',
    icone: Icons.delete_outline,
    contenu: Text('Avec son contenu : $contenu. Les foyers ne retirent que ce qu\'ils n\'utilisent pas.', style: Charte.texte(16)),
    plein: 'Annuler',
    contour: 'Supprimer',
  );
  return ok == true;
}

/// Liste des rayons du brouillon, pour y déplacer un secteur.
Future<CatRayon?> _choisirRayon(BuildContext context, Brouillon b, {required String titre, CatRayon? sauf}) async {
  CatRayon? choisi;
  final ok = await modale(
    context,
    titre: titre,
    icone: Icons.drive_file_move_outline,
    oui: 'Déplacer',
    contenu: (context, maj) => ChoixDeroulant<String>(
      libelle: 'Rayon',
      valeur: choisi?.nom ?? '',
      choix: {
        '': 'Choisir un rayon',
        for (final x in b.catalogue.rayons)
          if (!identical(x, sauf)) x.nom: x.nom,
      },
      onChange: (v) => maj(() => choisi = b.rayon(v)),
    ),
  );
  return ok ? choisi : null;
}

/// Coller un texte : titres de secteur (« Animalerie / Chats : ») puis produits, un par ligne.
/// Dans un secteur ([secteur] donné), les lignes sans titre vont dans ce secteur ; depuis un rayon
/// ([rayon] seul), un titre de secteur inconnu y crée le secteur. Sinon son rayon est demandé.
Future<bool> ajouterDepuisTexte(BuildContext context, Brouillon b, {CatRayon? rayon, CatSecteur? secteur}) async {
  final texte = TextEditingController();
  final lire = await modale(
    context,
    titre: 'Ajouter depuis un texte',
    icone: Icons.notes,
    oui: 'Lire le texte',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          (secteur != null
                  ? 'Un produit par ligne : ils vont dans ${secteur.nom}. « Secteur Chats » ouvre un autre secteur.'
                  : rayon != null
                  ? '« Secteur Chats » donne le secteur du rayon ${rayon.nom}, puis un produit par ligne.'
                  : '« Secteur Chats » (ou « Chats : ») donne le secteur, puis un produit par ligne. Un secteur '
                        'existant est trouvé dans son rayon.') +
              ' « Rayon Animalerie » en tête de ligne fixe le rayon, créé s\'il n\'existe pas, des secteurs qui suivent.',
          style: Charte.texte(14, couleur: Charte.texteSecondaire),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Lien(
            'Coller',
            onTap: () async {
              final d = await Clipboard.getData(Clipboard.kTextPlain);
              final t = d?.text?.trim() ?? '';
              if (t.isNotEmpty) maj(() => texte.text = texte.text.trim().isEmpty ? t : '${texte.text.trimRight()}\n$t');
            },
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('editeur-texte'),
          controller: texte,
          minLines: 6,
          maxLines: 12,
          style: Charte.texte(15),
          decoration: const InputDecoration(
            labelText: 'Produits à ajouter',
            hintText: 'Rayon Animalerie\nSecteur Chats\nCroquettes\nLitière',
          ),
        ),
      ],
    ),
  );
  if (!lire || !context.mounted) return false;
  final source = secteur != null && rayon != null ? '${rayon.nom} / ${secteur.nom} :\n${texte.text}' : texte.text;
  final lu = lireTexteCatalogue(b, source, rayonDefaut: rayon?.nom);
  if (lu.nouveaux == 0 && lu.groupes.every((g) => !g.secteurNeuf)) {
    Nav.message(context, lu.connus > 0 ? 'Tous ces produits sont déjà dans leur secteur' : 'Aucun produit trouvé dans ce texte');
    return false;
  }
  final ok = await modale(
    context,
    titre: 'À ajouter',
    icone: Icons.playlist_add,
    oui: 'Ajouter au brouillon',
    contenu: (context, maj) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            '${_pluriel(lu.nouveaux, 'produit nouveau')}${lu.connus > 0 ? ', ${lu.connus} déjà dans leur secteur (ignorés)' : ''}.',
            style: Charte.texte(15, couleur: Charte.texteSecondaire),
          ),
          for (final g in lu.groupes) ...[
            const SizedBox(height: 10),
            if (g.rayonAChoisir) ...[
              const SizedBox(height: 4),
              ChoixDeroulant<String>(
                libelle: '${g.secteur} (nouveau secteur) : rayon',
                valeur: g.rayonNeuf ? '+' : g.rayon,
                choix: {'': 'Choisir un rayon', for (final r in b.catalogue.rayons) r.nom: r.nom, '+': 'Nouveau rayon « ${g.secteur} »'},
                onChange: (v) => maj(() {
                  g.rayonNeuf = v == '+';
                  g.rayon = v == '+' ? g.secteur : v;
                }),
              ),
            ] else
              Text(
                '${g.rayon} › ${g.secteur}${g.rayonNeuf
                    ? ' (nouveau rayon)'
                    : g.secteurNeuf
                    ? ' (nouveau secteur)'
                    : ''}',
                style: Charte.texte(15, gras: true),
              ),
            for (final p in g.nouveaux) Text(p, style: Charte.texte(15)),
            for (final p in g.connus) Text('$p · déjà dans ce secteur', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          ],
        ],
      ),
    ),
  );
  if (!ok || !context.mounted) return false;
  final sansRayon = lu.groupes.where((g) => g.rayon.isEmpty).map((g) => g.secteur).toList();
  final n = ajouterLecture(b, lu);
  if (sansRayon.isNotEmpty) {
    Nav.message(context, 'Sans rayon choisi, non ajouté : ${sansRayon.join(', ')}');
    return n > 0;
  }
  Nav.message(context, '${_pluriel(n, 'produit')} ajouté${n > 1 ? 's' : ''} au brouillon');
  return true;
}

/// Fenêtre « Nouveautés du catalogue », montrée une fois sur chaque appareil après l'ajout d'une version.
Future<void> montrerNouveautes(BuildContext context) async {
  final c = CatalogueCommun.instance;
  final lignes = c.nouveautes;
  if (lignes.isEmpty) return;
  final reste = c.nbNouveautes - lignes.length;
  await modale(
    context,
    titre: 'Nouveautés du catalogue',
    oui: 'Fermer',
    non: null,
    fermable: false,
    contenu: (context, _) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Le catalogue commun passe en ${Etat.instance.libelleVersion(Etat.instance.numeroCatalogueCommun).toLowerCase()} :',
            style: Charte.texte(14, couleur: Charte.texteSecondaire),
          ),
          const SizedBox(height: 8),
          for (final l in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: Charte.texte(15)),
            ),
          if (reste > 0) Text('… et $reste autres', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        ],
      ),
    ),
  );
  c.nouveautesVues();
}

/// Montre les nouveautés du catalogue dès qu'il y en a (au lancement, après la lecture du serveur).
class GuetteurNouveautes extends StatefulWidget {
  const GuetteurNouveautes({super.key, required this.child});
  final Widget child;

  @override
  State<GuetteurNouveautes> createState() => _GuetteurNouveautesState();
}

class _GuetteurNouveautesState extends State<GuetteurNouveautes> {
  bool _ouverte = false;

  @override
  void initState() {
    super.initState();
    CatalogueCommun.instance.addListener(_verifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifier());
  }

  @override
  void dispose() {
    CatalogueCommun.instance.removeListener(_verifier);
    super.dispose();
  }

  Future<void> _verifier() async {
    if (_ouverte || !mounted || CatalogueCommun.instance.nouveautes.isEmpty) return;
    _ouverte = true;
    await montrerNouveautes(context);
    _ouverte = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ce qu'un geste a changé, de [avant] à [apres] (brouillons), en lignes lisibles pour l'historique.
List<String> gestesEntre(Map<String, dynamic> avant, Map<String, dynamic> apres) {
  Map<String, dynamic> sans(Map<String, dynamic> j) => Map.of(j)..remove('modifications');
  if (jsonEncode(sans(avant)) == jsonEncode(sans(apres))) return const [];
  const types = {'rayon': 'Rayon', 'secteur': 'Secteur', 'produit': 'Produit'};
  final ra = (avant['renommes'] as List? ?? const []).length;
  final rb = (apres['renommes'] as List? ?? const []);
  if (rb.length > ra) {
    return [
      for (final o in rb.sublist(ra).cast<Map>()) '${types[o['type']] ?? 'Élément'} renommé : ${o['ancien']} → ${o['nouveau']}',
    ];
  }
  final x = Recapitulatif.entre(avant, apres);
  // Un secteur passé d'un rayon à un autre : une ligne, pas ses produits un à un.
  String sec(String c) => c.split(' › ').last;
  final deplaces = <String>[];
  final ajoutes = [...x.secteursAjoutes], retires = [...x.secteursRetires];
  for (final a in [...ajoutes]) {
    final de = retires.where((r) => sec(r) == sec(a)).firstOrNull;
    if (de == null) continue;
    deplaces.add('Secteur déplacé : ${sec(a)}, de ${de.split(' › ').first} vers ${a.split(' › ').first}');
    ajoutes.remove(a);
    retires.remove(de);
  }
  final cibles = {for (final l in deplaces) l.split(', de ').first.replaceFirst('Secteur déplacé : ', '')};
  final lignes = [
    for (final n in x.rayonsAjoutes) 'Rayon ajouté : $n',
    for (final n in x.rayonsRetires) 'Rayon retiré : $n',
    ...deplaces,
    for (final n in ajoutes) 'Secteur ajouté : $n',
    for (final n in retires) 'Secteur retiré : $n',
    for (final n in x.produitsAjoutes) 'Produit ajouté : $n',
    for (final n in x.produitsRetires) 'Produit retiré : $n',
    for (final n in x.produitsDeplaces)
      if (!cibles.contains(sec(n))) 'Produit déplacé : $n',
  ];
  final ia = (avant['images'] as Map? ?? const {}), ib = (apres['images'] as Map? ?? const {});
  for (final k in {...ia.keys, ...ib.keys}) {
    if (ia[k] == ib[k]) continue;
    final quoi = '$k'.replaceAll('--', ' › ').replaceAll('-', ' ');
    lignes.add(ib[k] == null ? 'Icône remise automatique : $quoi' : 'Icône choisie : $quoi → ${nomImage('${ib[k]}')}');
  }
  final pa = (avant['imagesPerso'] as Map? ?? const {}), pb = (apres['imagesPerso'] as Map? ?? const {});
  String texte(Object? o) => '${(o as Map?)?['t'] ?? ''}';
  for (final k in {...pa.keys, ...pb.keys}) {
    if (jsonEncode(pa[k]) == jsonEncode(pb[k])) continue;
    lignes.add(pb[k] == null
        ? 'Image retirée de la bibliothèque : ${texte(pa[k])}'
        : pa[k] == null
            ? 'Image ajoutée à la bibliothèque : ${texte(pb[k])}'
            : 'Image de la bibliothèque remplacée : ${texte(pb[k])}');
  }
  // Univers (domaines) : rayon changé de domaine, domaine ajouté, retiré (08/11/2026).
  Map<String, String> domaines(Object? j) => {
        for (final e in (lireUnivers(j) ?? const <String, List<String>>{}).entries)
          for (final r in e.value) r: e.key,
      };
  if (avant['univers'] != null && apres['univers'] != null && jsonEncode(avant['univers']) != jsonEncode(apres['univers'])) {
    final da = domaines(avant['univers']), db = domaines(apres['univers']);
    final ua = (lireUnivers(avant['univers']) ?? const {}).keys.toSet(), ub = (lireUnivers(apres['univers']) ?? const {}).keys.toSet();
    final renomme = ua.difference(ub).length == 1 && ub.difference(ua).length == 1;
    if (renomme) {
      lignes.add('Domaine renommé : ${ua.difference(ub).single} → ${ub.difference(ua).single}');
    } else {
      for (final u in ub.difference(ua)) {
        lignes.add('Domaine ajouté : $u');
      }
      for (final u in ua.difference(ub)) {
        lignes.add('Domaine retiré : $u');
      }
    }
    for (final r in {...da.keys, ...db.keys}) {
      if (renomme || da[r] == db[r] || x.rayonsAjoutes.contains(r) || x.rayonsRetires.contains(r)) continue;
      lignes.add('Rayon $r : domaine ${da[r] ?? autresRayons} → ${db[r] ?? autresRayons}');
    }
  }
  if (lignes.isEmpty) return const ['Ordre modifié'];
  const max = 12;
  return lignes.length <= max ? lignes : [...lignes.take(max), '… et ${lignes.length - max} autres changements'];
}

/// L'historique des modifications du catalogue commun : les gestes en cours, puis les étapes validées (la plus
/// récente en haut) ; le crayon d'une étape propose d'y revenir (07/11/2026, Aristide).
class EcranHistoriqueCatalogue extends StatefulWidget {
  const EcranHistoriqueCatalogue({super.key, required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<EcranHistoriqueCatalogue> createState() => _EcranHistoriqueCatalogueState();
}

class _EcranHistoriqueCatalogueState extends State<EcranHistoriqueCatalogue> {
  String _date(DateTime d) => JournalCatalogue.nomParDefaut(d);

  List<Widget> _gestes(List<GesteCatalogue> gestes) => [
        if (gestes.isEmpty)
          FeuilleArbre(
            profondeur: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Aucune modification.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
          ),
        for (final g in gestes.reversed)
          FeuilleArbre(
            profondeur: 2,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in g.lignes) Text(l, style: Charte.texte(15)),
                Text(_date(g.date), style: Charte.texte(12, couleur: Charte.texteSecondaire)),
              ]),
            ),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final e = widget.editeur;
    final j = e.journal;
    final plis = Retractables.i;
    Widget niveau(String cle, String nom, List<GesteCatalogue> gestes, {VoidCallback? crayon, bool parDefaut = false}) {
      final ouvert = plis.ouvert(cle, parDefaut: parDefaut);
      return NiveauArbre(
        cle: cle,
        niveau: 2,
        profondeur: 1,
        nom: nom,
        nombre: gestes.length,
        ouvert: ouvert,
        onTap: () => setState(() => plis.basculer(cle, parDefaut: parDefaut)),
        onCrayon: crayon,
        enfants: _gestes(gestes),
      );
    }

    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.history, sousTitre: 'Catalogue commun', titre: 'Historique'),
      corps: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            'En cours : modifications enregistrées, pas encore validées. Une étape validée est un point de sauvegarde ; '
            'seul ce qui est validé se généralise. Revenir à une étape abandonne tout ce qui l\'a suivie.',
            style: Charte.texte(14, couleur: Charte.texteSecondaire),
          ),
        ),
        ColonneDebord(children: [
          niveau('historique/en-cours', 'En cours', j.enCours, parDefaut: true),
          for (var i = j.etapes.length - 1; i >= 0; i--)
            niveau(
              'historique/${j.etapes[i].date.toIso8601String()}',
              '${j.etapes[i].nom} · ${j.etapes[i].numero != null ? 'généralisée v${j.etapes[i].numero}' : 'validée'}',
              j.etapes[i].gestes,
              crayon: () => menuActions(context, titre: 'Étape ${j.etapes[i].nom}', actions: [
                ActionLigne(Icons.history, 'Revenir à cette étape', () async {
                  if (await e.revenirA(i) && mounted) setState(() {});
                }, danger: true),
              ]),
            ),
        ]),
      ]),
      bas: [
        BarreAction(boutons: [
          Bouton(
            key: const ValueKey('historique-valider'),
            texte: 'Valider les modifications (${e.enCours})',
            icone: Icons.check,
            plein: true,
            onTap: e.enCours == 0
                ? null
                : () async {
                    await e.valider();
                    if (mounted) setState(() {});
                  },
          ),
        ]),
      ],
    );
  }
}
