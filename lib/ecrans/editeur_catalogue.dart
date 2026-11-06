import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/pictogramme.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/catalogue_type.dart';
import '../donnees/modele.dart';
import '../donnees/signature.dart';
import '../navigation.dart';
import '../theme.dart';

// Outil de l'éditeur du catalogue commun (application Windows à part depuis le 06/11/2026 ; voir main.dart, OUTIL_EDITEUR).
// Les modifications forment un brouillon gardé dans le navigateur ; « Généraliser » publie une version numérotée
// pour tous les foyers.

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

class EcranEditeurCatalogue extends StatefulWidget {
  const EcranEditeurCatalogue({super.key});

  /// Relire la version publiée sur le serveur à l'ouverture (coupé dans les tests, sans serveur).
  static bool actualiserAuServeur = true;

  @override
  State<EcranEditeurCatalogue> createState() => _EcranEditeurCatalogueState();
}

class _EcranEditeurCatalogueState extends State<EcranEditeurCatalogue> {
  Brouillon? b;
  Map<String, dynamic>? publie;
  bool _publication = false;

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
      });
    }
  }

  void _modifie() {
    CatalogueCommun.instance.enregistrerBrouillon(b!);
    setState(() {});
  }

  int get _numero => ((publie?['numero'] as num?) ?? 0).toInt();

  @override
  Widget build(BuildContext context) {
    final b = this.b;
    return PageBase(
      entete: EnTeteFenetre(
        icone: Icons.public,
        sousTitre: 'Emplettes · outil de l\'éditeur',
        titre: 'Catalogue commun',
        actions: [
          if (b != null) ...[
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
                    '${b.modifications == 0 ? 'aucune modification.' : '${_pluriel(b.modifications, 'modification')} à généraliser.'}',
                    style: Charte.texte(14, couleur: Charte.texteSecondaire),
                  ),
                ),
                for (final r in b.catalogue.rayons)
                  GroupeRetractable(
                    cle: 'editeur/${r.nom}',
                    parDefaut: false,
                    titre: r.nom,
                    image: b.images[cleChoixRayon(r.nom)] ?? cleRayon(r.nom),
                    nombre: r.secteurs.length,
                    actions: [
                      ActionLigne(Icons.chevron_right, '+ Nouveau secteur', () async {
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
                      ActionLigne(Icons.chevron_right, 'Depuis un texte', () async {
                          if (await ajouterDepuisTexte(context, b, rayon: r)) _modifie();
                        }),
                      ActionLigne(Icons.chevron_right, 'Renommer', () async {
                          final nom = await demanderTexte(context, titre: 'Nom du rayon', initial: r.nom);
                          if (nom == null) return;
                          b.renommerRayon(r, nom);
                          _modifie();
                        }),
                      ActionLigne(Icons.chevron_right, 'Supprimer', () async {
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
                    ],
                    enfants: [
                      for (final s in r.secteurs)
                        LigneMenu(
                          titre: s.nom,
                          gauche: Pictogramme(b.images[cleChoixSecteur(r.nom, s.nom)] ?? cleSecteur(r.nom, s.nom), taille: 32),
                          sousTitre: _pluriel(s.produits.length, 'produit'),
                          onTap: () => menuActions(context, titre: s.nom, actions: [
                            ActionLigne(Icons.list, 'Voir et modifier les produits', () async {
                              await Nav.aller<void>(context, EcranEditeurSecteur(b: b, r: r, s: s));
                              if (mounted) setState(() {});
                            }),
                            ...actionsSecteurEditeur(context, b, r, s, _modifie),
                          ]),
                        ),
                    ],
                  ),
              ],
            ),
      bas: [
        if (b != null)
          BarreAction(
            boutons: [
              Bouton(
                key: const ValueKey('generaliser'),
                texte: _publication ? 'Envoi…' : 'Généraliser (v${_numero + 1})',
                icone: Icons.public,
                plein: true,
                onTap: _publication || b.modifications == 0 ? null : () => _publier(b),
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
        'p$i': 'Foyer n° ${propositions[i]['foyer'] ?? '?'} · ${_pluriel(((propositions[i]['changements'] as num?) ?? 0).toInt(), 'changement')} '
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
    setState(() => b = nouveau);
    Nav.message(context, 'Brouillon repris de « ${choix[k]} »');
  }

  Future<void> _publier(Brouillon b) async {
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
    var fait = false;
    try {
      fait = await CatalogueCommun.instance.publierBrouillon(b);
    } catch (e) {
      CatalogueCommun.instance.erreur = '$e';
    }
    if (!mounted) return;
    if (fait) {
      setState(() => _publication = false);
      await _charger();
      if (mounted) Nav.message(context, 'Version v$_numero généralisée : chaque foyer la reçoit à son prochain lancement');
    } else {
      setState(() => _publication = false);
      Nav.message(context,
          'Rien n\'est publié (${CatalogueCommun.instance.erreur ?? 'le serveur ne répond pas'}) : le brouillon est gardé, réessayez');
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
      Nav.message(context, phrase.trim().length < 8 ? 'Phrase trop courte (8 caractères au moins)' : 'Ce n\'est pas la phrase de l\'éditeur');
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
      contenu: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          clePubliqueEditeur.isEmpty
              ? 'Envoyez cette clé à Claude : elle n\'est pas secrète. Une fois dans l\'application, seuls les catalogues '
                  'signés par votre phrase seront acceptés.'
              : 'Cette clé est celle de l\'application : vos versions sont reconnues par tous les foyers.',
          style: Charte.texte(15),
        ),
        const SizedBox(height: 10),
        SelectableText(cle, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
      ]),
      plein: 'Fermer',
      contour: 'Copier',
    );
    if (copier == true) await Clipboard.setData(ClipboardData(text: cle));
  }
}

/// Ce qui change entre la dernière version publiée et le brouillon (comparaison par noms).
class Recapitulatif {
  Recapitulatif(this.rayonsAjoutes, this.rayonsRetires, this.secteursAjoutes, this.secteursRetires, this.produitsAjoutes,
      this.produitsRetires, this.produitsDeplaces, this.renommes);
  final List<String> rayonsAjoutes, rayonsRetires, secteursAjoutes, secteursRetires, produitsAjoutes, produitsRetires, produitsDeplaces;
  final int renommes;

  bool get vide =>
      rayonsAjoutes.isEmpty && rayonsRetires.isEmpty && secteursAjoutes.isEmpty && secteursRetires.isEmpty &&
      produitsAjoutes.isEmpty && produitsRetires.isEmpty && produitsDeplaces.isEmpty && renommes == 0;

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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$titre (${noms.length})', style: Charte.texte(15, gras: true)),
              for (final n in noms.take(12)) Text('· $n', style: Charte.texte(14)),
              if (noms.length > 12) Text('· et ${noms.length - 12} autres', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
            ]),
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
  }
}

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${jjmmaaaa(d)} à ${heure(d)}';
}

/// Un secteur du catalogue commun : ses produits, à renommer ou retirer.
class EcranEditeurSecteur extends StatefulWidget {
  const EcranEditeurSecteur({super.key, required this.b, required this.r, required this.s});
  final Brouillon b;
  final CatRayon r;
  final CatSecteur s;

  @override
  State<EcranEditeurSecteur> createState() => _EcranEditeurSecteurState();
}

class _EcranEditeurSecteurState extends State<EcranEditeurSecteur> {
  void _modifie() {
    CatalogueCommun.instance.enregistrerBrouillon(widget.b);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b, r = widget.r, s = widget.s;
    final produits = [...s.produits]..sort((a, c) => a.nom.toLowerCase().compareTo(c.nom.toLowerCase()));
    return PageBase(
      entete: EnTeteFenetre(
        retour: true,
        icone: Icons.public,
        sousTitre: 'Catalogue commun › ${r.nom}',
        titre: s.nom,
        actions: actionsSecteurEditeur(context, b, r, s, _modifie, quitter: () => Navigator.of(context).pop()),
      ),
      corps: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (produits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucun produit dans ce secteur.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            ),
          for (final p in produits)
            LigneMenu(
              titre: p.nom,
              onTap: () => menuActions(context, titre: p.nom, actions: [
                ActionLigne(Icons.edit_outlined, 'Renommer', () async {
                  final nom = await demanderTexte(context, titre: 'Nom du produit', initial: p.nom);
                  if (nom == null) return;
                  b.renommerProduit(p, nom);
                  _modifie();
                }),
                ActionLigne(Icons.delete_outline, 'Retirer', () {
                  b.retirerProduit(s, p);
                  _modifie();
                }, danger: true),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Actions d'un secteur du catalogue commun ; [quitter] ferme l'écran du secteur quand il est déplacé ou retiré.
List<ActionLigne> actionsSecteurEditeur(BuildContext context, Brouillon b, CatRayon r, CatSecteur s, VoidCallback modifie,
        {VoidCallback? quitter}) =>
    [
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
          secteur != null
              ? 'Un produit par ligne : ils vont dans ${secteur.nom}. Une ligne finie par « : » ouvre un autre secteur.'
              : rayon != null
              ? 'Une ligne finie par « : » donne le secteur du rayon ${rayon.nom} (« Chats : »), puis un produit par ligne.'
              : 'Une ligne finie par « : » donne le secteur : « Animalerie / Chats : » (rayon / secteur), '
                    'ou « Fruits : » pour un secteur existant. Puis un produit par ligne.',
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
          decoration: const InputDecoration(labelText: 'Produits à ajouter', hintText: 'Animalerie / Chats :\nCroquettes\nLitière'),
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
            'Le catalogue commun a été mis à jour ; ceci est maintenant dans votre catalogue.',
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
