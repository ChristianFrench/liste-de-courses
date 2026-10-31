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

// Gérer › Courses › Catalogue commun (26/10/2026) : réservé à l'éditeur. Les modifications forment
// un brouillon gardé sur l'appareil ; « Publier » l'envoie à tous les foyers.

String _pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

class EcranEditeurCatalogue extends StatefulWidget {
  const EcranEditeurCatalogue({super.key});

  @override
  State<EcranEditeurCatalogue> createState() => _EcranEditeurCatalogueState();
}

class _EcranEditeurCatalogueState extends State<EcranEditeurCatalogue> {
  Brouillon? b;
  bool _publication = false;

  @override
  void initState() {
    super.initState();
    CatalogueCommun.instance.brouillon().then((x) => mounted ? setState(() => b = x) : null);
  }

  void _modifie() {
    CatalogueCommun.instance.enregistrerBrouillon(b!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final b = this.b;
    return PageBase(
      entete: EnTeteFenetre(
        retour: true,
        icone: Icons.public,
        sousTitre: 'Gérer › Courses',
        titre: 'Catalogue commun',
        actions: [
          if (b != null) ...[
            ActionLigne(Icons.add, '+ Nouveau rayon', () async {
              final nom = await demanderTexte(context, titre: 'Nouveau rayon', valider: 'Ajouter');
              if (nom == null || nom.trim().isEmpty) return;
              b.ajouterRayon(nom);
              _modifie();
            }),
            ActionLigne(Icons.notes, 'Ajouter depuis un texte', () async {
              if (await ajouterDepuisTexte(context, b)) _modifie();
            }),
            ActionLigne(Icons.groups_outlined, 'Foyers contributeurs', () async {
              await Nav.aller<void>(context, EcranContributeurs(b: b, modifie: _modifie));
              if (mounted) setState(() {});
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
                    '${b.version == 0 ? 'Jamais publié : catalogue livré avec l\'application' : 'Publié le ${_date(b.version)}'} · '
                    '${_pluriel(b.catalogue.rayons.length, 'rayon')}, ${_pluriel(b.nbProduits, 'produit')}.\n'
                    '${b.modifications == 0 ? 'Aucune modification en attente.' : '${_pluriel(b.modifications, 'modification')} à publier.'}',
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
                texte: _publication ? 'Envoi…' : 'Publier',
                icone: Icons.public,
                plein: true,
                onTap: _publication || b.modifications == 0 ? null : () => _publier(b),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _publier(Brouillon b) async {
    final ok = await confirmer(
      context,
      titre: 'Publier le catalogue commun ?',
      icone: Icons.public,
      contenu: Text(
        'Les ${_pluriel(b.modifications, 'modification')} partent vers tous les foyers. Chaque application les ajoute '
        'à son lancement et montre les nouveautés. Rien de ce qu\'un foyer utilise n\'est retiré.',
        style: Charte.texte(16),
      ),
      plein: 'Annuler',
      contour: 'Publier',
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
      final nouveau = await CatalogueCommun.instance.brouillon();
      if (!mounted) return;
      setState(() {
        _publication = false;
        this.b = nouveau;
      });
      Nav.message(context, 'Catalogue commun publié');
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
              : 'Cette clé est celle de l\'application : vos publications sont reconnues par tous les foyers.',
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

/// Les foyers qui ajoutent au catalogue (anonymes), du plus suspect au moins suspect ; l'éditeur bloque
/// ou débloque un foyer (effet à la prochaine publication).
class EcranContributeurs extends StatefulWidget {
  const EcranContributeurs({super.key, required this.b, required this.modifie});
  final Brouillon b;
  final VoidCallback modifie;

  @override
  State<EcranContributeurs> createState() => _EcranContributeursState();
}

class _EcranContributeursState extends State<EcranContributeurs> {
  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final liste = CatalogueCommun.instance.contributeurs(b);
    return PageBase(
      entete: const EnTeteFenetre(retour: true, icone: Icons.groups_outlined, sousTitre: 'Catalogue commun', titre: 'Foyers contributeurs'),
      corps: liste.isEmpty
          ? Center(child: Text('Aucun ajout reçu des foyers.', style: Charte.texte(16)))
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text(
                    'Les plus suspects en tête. Bloquer un foyer retire tous ses ajouts chez tous les foyers, '
                    'à la prochaine publication.',
                    style: Charte.texte(14, couleur: Charte.texteSecondaire),
                  ),
                ),
                for (final c in liste)
                  LigneMenu(
                    titre: 'Foyer ${c.id.length > 4 ? c.id.substring(0, 4) : c.id}${c.bloque ? ' · bloqué' : c.ecarte ? ' · écarté' : ''}',
                    icone: c.bloque ? Icons.block : Icons.home_outlined,
                    sousTitre: '${_pluriel(c.produits, 'produit')}'
                        '${c.refuses > 0 ? ', ${_pluriel(c.refuses, 'nom')} refusé${c.refuses > 1 ? 's' : ''}' : ''}'
                        '${c.signales > 0 ? ', ${_pluriel(c.signales, 'produit')} signalé${c.signales > 1 ? 's' : ''}' : ''}',
                    onTap: () => menuActions(context, titre: 'Foyer ${c.id.length > 4 ? c.id.substring(0, 4) : c.id}', actions: [
                      if (c.bloque)
                        ActionLigne(Icons.check_circle_outline, 'Débloquer', () => _bloquer(c.id, false))
                      else
                        ActionLigne(Icons.block, 'Bloquer ce foyer', () => _bloquer(c.id, true), danger: true),
                    ]),
                  ),
              ],
            ),
    );
  }

  void _bloquer(String id, bool oui) {
    if (oui ? !widget.b.bloques.add(id) : !widget.b.bloques.remove(id)) return;
    widget.b.modifications++;
    widget.modifie();
    setState(() {});
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
