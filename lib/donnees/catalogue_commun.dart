import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'catalogue_type.dart';
import 'modele.dart';
import 'synchro.dart';

// Catalogue commun à tous les foyers (26/10/2026).
// Une seule personne le tient à jour (l'éditeur, déverrouillé par un code fourni à la compilation) ;
// « Publier » le dépose sur le serveur MQTT (message retenu). Chaque application le lit à son
// lancement et ajoute au foyer ce qui est nouveau (Etat.appliquerCatalogueCommun).
//
// Format : celui du catalogue livré (assets/catalogue_type.json), plus
//   version   numéro (millisecondes) ; date
//   images    image choisie pour un rayon ou un secteur (clé : voir images_choisies.dart)
//   renommes  [{type: rayon|secteur|produit, rayon?, ancien, nouveau}], cumulés d'une version à l'autre
//   retires   [{type, rayon?, nom}], cumulés
//
// Catalogue ouvert à tous les foyers (30/10/2026) : chaque foyer dépose aussi ses propres ajouts, en message
// retenu sous « ldc/catalogue-commun/apports/<identifiant du foyer> » (Etat.apports) ; au lancement, chaque
// application lit le catalogue commun et tous les apports, et ajoute au foyer ce qui lui manque.

class CatalogueCommun extends ChangeNotifier {
  CatalogueCommun._();
  static final CatalogueCommun instance = CatalogueCommun._();

  static const sujet = 'ldc/catalogue-commun';
  static const _codeEditeur = String.fromEnvironment('CODE_EDITEUR');

  /// L'application a été compilée avec un code d'éditeur.
  static bool get editeurPossible => _codeEditeur.isNotEmpty;

  String? _reglage(String c) => Etat.instance.stockageFoyer?.reglage(c);
  void _definir(String c, String v) => Etat.instance.stockageFoyer?.definirReglage(c, v);

  /// Cet appareil est celui de l'éditeur.
  bool get editeur => _reglage('editeur_catalogue') == '1';

  bool deverrouiller(String code) {
    if (!editeurPossible || code.trim() != _codeEditeur) return false;
    _definir('editeur_catalogue', '1');
    notifyListeners();
    return true;
  }

  void verrouiller() {
    Etat.instance.stockageFoyer?.effacerReglage('editeur_catalogue');
    notifyListeners();
  }

  // ------------------------------------------------------------ Serveur

  /// Une connexion courte au serveur, le temps de [action].
  Future<T?> _avecServeur<T>(Future<T?> Function(Transport t, Stream<(String, String)> messages) action,
      {String abonnement = sujet}) async {
    final t = Synchro.instance.fabrique(Synchro.instance.serveur);
    final connecte = Completer<bool>();
    final messages = t.messages.asBroadcastStream();
    final sub = t.etats.listen((e) {
      if (e == 'connecte' && !connecte.isCompleted) connecte.complete(true);
      if (e.startsWith('Connexion impossible')) erreur = e.replaceFirst(RegExp(r', nouvel essai.*'), '');
    });
    try {
      unawaited(t.connecter(
        identifiant: 'ldc-catalogue-${DateTime.now().millisecondsSinceEpoch}',
        sujetTestament: 'ldc/verif',
        testament: '',
        abonnement: abonnement,
      ));
      await connecte.future.timeout(const Duration(seconds: 15));
      return await action(t, messages);
    } on TimeoutException {
      return null;
    } finally {
      await sub.cancel();
      await t.fermer();
    }
  }

  /// Le catalogue commun publié, ou null (rien de publié, ou pas de réseau).
  Future<Map<String, dynamic>?> recuperer() => _avecServeur((t, messages) async {
        try {
          final m = await messages.firstWhere((m) => m.$1 == sujet && m.$2.isNotEmpty).timeout(const Duration(seconds: 8));
          return deballer(m.$2);
        } on TimeoutException {
          return null;
        }
      });

  /// Le catalogue part compressé (« gz: » + gzip en base 64) : environ 30 ko au lieu de 160.
  static String emballer(Map<String, dynamic> j) => 'gz:${base64Encode(GZipEncoder().encode(utf8.encode(jsonEncode(j)))!)}';

  static Map<String, dynamic> deballer(String t) =>
      jsonDecode(t.startsWith('gz:') ? utf8.decode(GZipDecoder().decodeBytes(base64Decode(t.substring(3)))) : t) as Map<String, dynamic>;

  /// Pourquoi la dernière publication a échoué (montré à l'éditeur).
  String? erreur;

  /// Publie le catalogue commun (message retenu) ; rend vrai si le serveur l'a renvoyé.
  /// Ne lève jamais d'erreur : en cas d'échec, [erreur] dit pourquoi.
  Future<bool> publier(Map<String, dynamic> j) async {
    erreur = null;
    bool? ok;
    try {
      final texte = emballer(j);
      ok = await _avecServeur((t, messages) async {
        final retour = Completer<bool>();
        final sub = messages.listen((m) {
          if (m.$1 == sujet && m.$2 == texte && !retour.isCompleted) retour.complete(true);
        }, onDone: () {
          erreur ??= 'le serveur a coupé la liaison';
          if (!retour.isCompleted) retour.complete(false);
        });
        t.publier(sujet, texte, retenu: true);
        try {
          return await retour.future.timeout(const Duration(seconds: 20));
        } on TimeoutException {
          erreur ??= 'le serveur n\'a pas renvoyé le catalogue';
          return false;
        } finally {
          await sub.cancel();
        }
      });
      if (ok == null) erreur ??= 'pas de liaison avec le serveur';
    } catch (e) {
      erreur = '$e';
      ok = false;
    }
    if (ok == true) {
      _definir('catalogue_commun', jsonEncode(j));
      // L'éditeur connaît déjà ce qu'il vient de publier : pas de fenêtre « Nouveautés » chez lui.
      Etat.instance.appliquerCatalogueCommun(j);
      final n = Etat.instance.nouveautesCatalogue;
      if (n != null) _definir('nouveautes_vues', '${n['version']}');
      notifyListeners();
    }
    return ok == true;
  }

  // ------------------------------------------------------------ Réception

  /// Nouveautés à montrer sur cet appareil (une fois).
  List<String> get nouveautes {
    final n = Etat.instance.nouveautesCatalogue;
    if (n == null) return const [];
    if ('${n['version']}' == _reglage('nouveautes_vues')) return const [];
    return [...(n['lignes'] as List).cast<String>()];
  }

  int get nbNouveautes => (Etat.instance.nouveautesCatalogue?['total'] as num? ?? 0).toInt();

  void nouveautesVues() {
    final n = Etat.instance.nouveautesCatalogue;
    if (n != null) _definir('nouveautes_vues', '${n['version']}');
    notifyListeners();
  }

  static String sujetApports(String id) => '$sujet/apports/$id';

  /// Apports du foyer tels que le serveur les a (texte JSON), pour ne redéposer que s'ils ont changé.
  String? _deposes;
  Timer? _veille;

  /// Au lancement : lit le catalogue commun et les apports des autres foyers, ajoute au foyer ce qui est
  /// nouveau, puis dépose les apports du foyer s'ils ont changé. Ensuite, toutes les 3 minutes, redépose
  /// les apports du foyer s'ils ont changé.
  Future<void> verifier() async {
    final etat = Etat.instance;
    if (etat.stockageFoyer == null) return;
    try {
      final recus = await _avecServeur<Map<String, String>>((t, messages) async {
        final recus = <String, String>{};
        // Tout arrive dès l'abonnement (messages retenus) : fini quand plus rien n'arrive depuis 2 s.
        final fini = Completer<void>();
        Timer? silence;
        void relancer() {
          silence?.cancel();
          silence = Timer(const Duration(seconds: 2), () {
            if (!fini.isCompleted) fini.complete();
          });
        }

        relancer();
        final sub = messages.listen((m) {
          recus[m.$1] = m.$2;
          relancer();
        });
        await fini.future.timeout(const Duration(seconds: 12), onTimeout: () {});
        silence?.cancel();
        await sub.cancel();
        _appliquerRecus(recus);
        // Puis les apports du foyer, s'ils ont changé (le catalogue commun a pu en reprendre).
        _deposes = _texte(recus[sujetApports(etat.identifiantApports())]);
        if (_deposer(t)) await Future<void>.delayed(const Duration(seconds: 2));
        return recus;
      }, abonnement: '$sujet/#');
      if (recus != null) notifyListeners();
    } catch (e) {
      debugPrint('Catalogue commun : $e');
    } finally {
      _veille ??= Timer.periodic(const Duration(minutes: 3), (_) => _redeposer());
    }
  }

  void _appliquerRecus(Map<String, String> recus) {
    final etat = Etat.instance;
    final commun = recus[sujet];
    if (commun != null && commun.isNotEmpty) {
      final j = deballer(commun);
      _definir('catalogue_commun', jsonEncode(j));
      etat.appliquerCatalogueCommun(j);
    }
    final moi = sujetApports(etat.identifiantApports());
    final apports = [
      for (final e in recus.entries)
        if (e.key.startsWith('$sujet/apports/') && e.key != moi && e.value.isNotEmpty)
          if (_lire(e.value) case final j?) j
    ];
    // Gardés sur l'appareil : l'éditeur les reprend dans son brouillon.
    _definir('apports_recus', jsonEncode(apports));
    etat.appliquerApports(apports);
  }

  static Map<String, dynamic>? _lire(String t) {
    try {
      return deballer(t);
    } catch (_) {
      return null;
    }
  }

  static String? _texte(String? t) => t == null || t.isEmpty ? null : (_lire(t) == null ? null : jsonEncode(_lire(t)));

  /// Dépose les apports du foyer s'ils ont changé depuis le dernier dépôt connu.
  bool _deposer(Transport t) {
    final etat = Etat.instance;
    if (etat.magasins.isEmpty) return false;
    final a = etat.apports();
    final texte = jsonEncode(a);
    if (texte == _deposes) return false;
    final vide = (a['rayons'] as List).isEmpty && (a['secteurs'] as List).isEmpty && (a['produits'] as List).isEmpty && (a['marques'] as Map).isEmpty;
    if (vide && _deposes == null) return false;
    t.publier(sujetApports(etat.identifiantApports()), emballer(a), retenu: true);
    _deposes = texte;
    return true;
  }

  Future<void> _redeposer() async {
    final etat = Etat.instance;
    if (etat.stockageFoyer == null || etat.magasins.isEmpty) return;
    if (jsonEncode(etat.apports()) == _deposes) return;
    try {
      await _avecServeur<bool>((t, messages) async {
        final fait = _deposer(t);
        // Le temps que le message parte avant la fermeture de la liaison.
        if (fait) await Future<void>.delayed(const Duration(seconds: 2));
        return fait;
      }, abonnement: 'ldc/verif');
    } catch (e) {
      debugPrint('Apports au catalogue : $e');
    }
  }

  /// Dernier catalogue commun connu (reçu ou publié), sinon le catalogue livré avec l'application.
  Future<Map<String, dynamic>> dernier() async {
    final t = _reglage('catalogue_commun');
    if (t != null) return jsonDecode(t) as Map<String, dynamic>;
    return jsonDecode(await rootBundle.loadString(CatalogueType.fichierLivre)) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------ Brouillon de l'éditeur

  /// Le brouillon en cours, gardé sur cet appareil jusqu'à la publication.
  /// Les ajouts de tous les foyers (reçus au lancement, et ceux du foyer de l'éditeur) y sont repris :
  /// l'éditeur les voit, et peut les retirer, les renommer ou les déplacer.
  Future<Brouillon> brouillon() async {
    final t = _reglage('catalogue_brouillon');
    final b = Brouillon.lire(t != null ? jsonDecode(t) as Map<String, dynamic> : await dernier());
    final recus = _reglage('apports_recus');
    b.absorber([
      if (recus != null) ...(jsonDecode(recus) as List).cast<Map<String, dynamic>>(),
      Etat.instance.apports(),
    ]);
    return b;
  }

  void enregistrerBrouillon(Brouillon b) => _definir('catalogue_brouillon', jsonEncode(b.versJson()));

  void abandonnerBrouillon() => Etat.instance.stockageFoyer?.effacerReglage('catalogue_brouillon');

  Future<bool> publierBrouillon(Brouillon b) async {
    final j = b.versJson()
      ..['version'] = DateTime.now().millisecondsSinceEpoch
      ..['date'] = DateTime.now().toIso8601String().substring(0, 16);
    j.remove('modifications');
    final ok = await publier(j);
    if (ok) abandonnerBrouillon();
    return ok;
  }
}

/// Le catalogue commun en cours de modification par l'éditeur.
class Brouillon {
  Brouillon(this.catalogue, this.images, this.renommes, this.retires, this.version, this.modifications);
  final CatalogueType catalogue;
  final Map<String, String> images;
  final List<Map<String, dynamic>> renommes, retires;
  final int version;

  /// Nombre de modifications depuis la dernière publication.
  int modifications;

  factory Brouillon.lire(Map<String, dynamic> j) => Brouillon(
        CatalogueType.lire(j),
        {for (final e in (j['images'] as Map? ?? const {}).entries) e.key as String: e.value as String},
        [for (final o in (j['renommes'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)],
        [for (final o in (j['retires'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)],
        (j['version'] as num? ?? 0).toInt(),
        (j['modifications'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> versJson() => {
        ...catalogue.versJson(),
        'version': version,
        if (images.isNotEmpty) 'images': images,
        if (renommes.isNotEmpty) 'renommes': renommes,
        if (retires.isNotEmpty) 'retires': retires,
        if (modifications > 0) 'modifications': modifications,
      };

  static String _bas(String t) => t.trim().toLowerCase();

  CatRayon? rayon(String nom) {
    for (final r in catalogue.rayons) {
      if (_bas(r.nom) == _bas(nom)) return r;
    }
    return null;
  }

  CatSecteur? secteur(CatRayon r, String nom) {
    for (final s in r.secteurs) {
      if (_bas(s.nom) == _bas(nom)) return s;
    }
    return null;
  }

  /// Le secteur, dans quelque rayon que ce soit (« Fruits »), avec son rayon.
  (CatRayon, CatSecteur)? secteurPartout(String nom) {
    for (final r in catalogue.rayons) {
      final s = secteur(r, nom);
      if (s != null) return (r, s);
    }
    return null;
  }

  /// Où est déjà ce produit (même nom), ou null.
  (CatRayon, CatSecteur, CatProduit)? produit(String nom) {
    for (final x in catalogue.tousLesProduits) {
      if (_bas(x.$3.nom) == _bas(nom)) return x;
    }
    return null;
  }

  /// Le produit de ce nom dans ce secteur (un même nom peut être dans plusieurs secteurs).
  CatProduit? produitDans(CatSecteur s, String nom) {
    for (final p in s.produits) {
      if (_bas(p.nom) == _bas(nom)) return p;
    }
    return null;
  }

  CatSecteur? _secteurDe(CatProduit p) {
    for (final x in catalogue.tousLesProduits) {
      if (identical(x.$3, p)) return x.$2;
    }
    return null;
  }

  int get nbProduits => catalogue.tousLesProduits.length;

  CatRayon ajouterRayon(String nom) {
    final r = rayon(nom) ?? (CatRayon(nom.trim())..let(catalogue.rayons.add));
    _retirerRetire('rayon', nom);
    modifications++;
    return r;
  }

  CatSecteur ajouterSecteur(CatRayon r, String nom) {
    final s = secteur(r, nom) ?? (CatSecteur(nom.trim(), 1)..let(r.secteurs.add));
    _retirerRetire('secteur', nom);
    modifications++;
    return s;
  }

  /// Rend faux si le produit est déjà dans ce secteur (le même nom peut être dans un autre secteur).
  bool ajouterProduit(CatSecteur s, String nom) {
    if (nom.trim().isEmpty || produitDans(s, nom) != null) return false;
    s.produits.add(CatProduit(nom.trim(), 1));
    _retirerRetire('produit', nom, secteur: s.nom);
    modifications++;
    return true;
  }

  /// Nouvel ordre des secteurs du rayon [r] (par leurs noms).
  void ordonnerSecteurs(CatRayon r, List<String> noms) {
    final avant = [for (final s in r.secteurs) s.nom];
    r.secteurs = [for (final n in noms) ...r.secteurs.where((s) => s.nom == n), ...r.secteurs.where((s) => !noms.contains(s.nom))];
    if ([for (final s in r.secteurs) s.nom].join('\n') != avant.join('\n')) modifications++;
  }

  void renommerRayon(CatRayon r, String nom) {
    if (nom.trim().isEmpty || nom.trim() == r.nom || rayon(nom) != null) return;
    renommes.add({'type': 'rayon', 'ancien': r.nom, 'nouveau': nom.trim()});
    r.nom = nom.trim();
    modifications++;
  }

  void renommerSecteur(CatRayon r, CatSecteur s, String nom) {
    if (nom.trim().isEmpty || nom.trim() == s.nom || secteur(r, nom) != null) return;
    renommes.add({'type': 'secteur', 'rayon': r.nom, 'ancien': s.nom, 'nouveau': nom.trim()});
    s.nom = nom.trim();
    modifications++;
  }

  void renommerProduit(CatProduit p, String nom) {
    final s = _secteurDe(p);
    if (s == null || nom.trim().isEmpty || nom.trim() == p.nom || produitDans(s, nom) != null) return;
    renommes.add({'type': 'produit', 'secteur': s.nom, 'ancien': p.nom, 'nouveau': nom.trim()});
    p.nom = nom.trim();
    modifications++;
  }

  void retirerProduit(CatSecteur s, CatProduit p) {
    s.produits.remove(p);
    retires.add({'type': 'produit', 'secteur': s.nom, 'nom': p.nom});
    modifications++;
  }

  /// Le secteur et ses produits (les foyers ne retirent que ce qu'ils n'utilisent pas).
  bool retirerSecteur(CatRayon r, CatSecteur s) {
    for (final p in s.produits) {
      retires.add({'type': 'produit', 'secteur': s.nom, 'nom': p.nom});
    }
    r.secteurs.remove(s);
    retires.add({'type': 'secteur', 'rayon': r.nom, 'nom': s.nom});
    modifications++;
    return true;
  }

  /// Le rayon, ses secteurs et leurs produits.
  bool retirerRayon(CatRayon r) {
    for (final s in [...r.secteurs]) {
      retirerSecteur(r, s);
    }
    catalogue.rayons.remove(r);
    retires.add({'type': 'rayon', 'nom': r.nom});
    modifications++;
    return true;
  }

  /// Déplace un secteur dans un autre rayon (fusionné avec un secteur du même nom s'il y en a un).
  /// Les foyers rangent ses produits dans le nouveau secteur ; l'ancien, vide, est retiré.
  void deplacerSecteur(CatRayon de, CatSecteur s, CatRayon vers) {
    if (identical(de, vers)) return;
    de.secteurs.remove(s);
    final meme = secteur(vers, s.nom);
    if (meme == null) {
      vers.secteurs.add(s);
    } else {
      meme.produits.addAll(s.produits.where((p) => produitDans(meme, p.nom) == null));
    }
    retires.add({'type': 'secteur', 'rayon': de.nom, 'nom': s.nom});
    if (de.secteurs.isEmpty) {
      catalogue.rayons.remove(de);
      retires.add({'type': 'rayon', 'nom': de.nom});
    }
    modifications++;
  }

  /// Reprend les ajouts des foyers ([Etat.apports]) qui manquent au brouillon, sauf ce que l'éditeur a
  /// retiré ou renommé. Rend le nombre d'éléments repris (comptés comme modifications).
  int absorber(Iterable<Map<String, dynamic>> lots) {
    final exclus = Etat.exclusDu({'retires': retires, 'renommes': renommes});
    var n = 0;
    CatRayon? rayonNomme(String rn) {
      if (Etat.estExclu(exclus, rayon: rn)) return null;
      final r = rayon(rn);
      if (r != null) return r;
      n++;
      return CatRayon(rn.trim())..let(catalogue.rayons.add);
    }

    CatSecteur? secteurNomme(String rn, String sn) {
      if (Etat.estExclu(exclus, rayon: rn, secteur: sn)) return null;
      final r = rayonNomme(rn);
      if (r == null) return null;
      final s = secteur(r, sn);
      if (s != null) return s;
      n++;
      return CatSecteur(sn.trim(), 1)..let(r.secteurs.add);
    }

    for (final j in lots) {
      for (final rn in (j['rayons'] as List? ?? const []).cast<String>()) {
        rayonNomme(rn);
      }
      for (final c in (j['secteurs'] as List? ?? const []).cast<String>()) {
        final i = c.indexOf('/');
        if (i > 0 && i < c.length - 1) secteurNomme(c.substring(0, i), c.substring(i + 1));
      }
      for (final pj in (j['produits'] as List? ?? const []).cast<Map>()) {
        final nom = pj['nom'] as String?, rn = pj['rayon'] as String?, sn = pj['secteur'] as String?;
        if (nom == null || rn == null || sn == null || nom.trim().isEmpty) continue;
        if (Etat.estExclu(exclus, rayon: rn, secteur: sn, produit: nom)) continue;
        final s = secteurNomme(rn, sn);
        if (s == null || produitDans(s, nom) != null) continue;
        s.produits.add(CatProduit(nom.trim(), 1, marques: [if (pj['marque'] case final String m) m], formats: [...(pj['formats'] as List? ?? const []).cast<String>()]));
        n++;
      }
    }
    modifications += n;
    return n;
  }

  void choisirImage(String cle, String? picto) {
    if (picto == null) {
      images.remove(cle);
    } else {
      images[cle] = picto;
    }
    modifications++;
  }

  /// Un nom remis au catalogue après avoir été retiré : il n'est plus à retirer des foyers.
  void _retirerRetire(String type, String nom, {String? secteur}) => retires.removeWhere((o) =>
      o['type'] == type && _bas(o['nom'] as String) == _bas(nom) && (secteur == null || o['secteur'] == null || o['secteur'] == secteur));
}

extension _Let<T> on T {
  void let(void Function(T) f) => f(this);
}

// ------------------------------------------------------------ Ajout depuis un texte

/// Ce qu'un texte ajoute : par secteur, les produits nouveaux et ceux déjà au catalogue.
class LectureCatalogue {
  final groupes = <GroupeLu>[];
  int get nouveaux => groupes.fold(0, (n, g) => n + g.nouveaux.length);
  int get connus => groupes.fold(0, (n, g) => n + g.connus.length);
}

class GroupeLu {
  GroupeLu(this.rayon, this.secteur, {this.rayonNeuf = false, this.secteurNeuf = false, this.rayonAChoisir = false});
  String rayon;
  final String secteur;
  bool rayonNeuf;
  final bool secteurNeuf;

  /// Titre sans rayon (« Chats : ») et secteur inconnu : le rayon est à choisir (vide tant qu'il ne l'est pas).
  final bool rayonAChoisir;
  final nouveaux = <String>[];
  final connus = <String>[];
}

/// Titre : ligne qui finit par « : » (« Animalerie / Chats : », ou « Fruits : » si ce secteur existe ;
/// un secteur inconnu sans rayon va dans [rayonDefaut], sinon son rayon est à choisir).
/// Les autres lignes sont des produits ; puces et numéros sont enlevés. Sans titre au-dessus, les
/// produits vont dans « Divers ».
LectureCatalogue lireTexteCatalogue(Brouillon b, String texte, {String? rayonDefaut}) {
  final lu = LectureCatalogue();
  GroupeLu? courant;
  final vus = <String>{};
  CatSecteur? cible(GroupeLu g) {
    final r = g.rayon.isEmpty ? null : b.rayon(g.rayon);
    return r == null ? null : b.secteur(r, g.secteur);
  }

  for (final brut in const LineSplitter().convert(texte)) {
    final ligne = brut.trim();
    if (ligne.isEmpty) continue;
    if (ligne.endsWith(':')) {
      final titre = ligne.substring(0, ligne.length - 1).trim();
      final parties = titre.split(RegExp(r'\s*[/›>]\s*'));
      String rn, sn;
      if (parties.length >= 2) {
        rn = parties.first;
        sn = parties.sublist(1).join(' ');
      } else {
        final x = b.secteurPartout(titre);
        if (x == null && rayonDefaut == null) {
          // Secteur inconnu, rayon non dit : on le demandera (pas de nouveau rayon d'office).
          courant = GroupeLu('', titre, secteurNeuf: true, rayonAChoisir: true);
          lu.groupes.add(courant);
          continue;
        }
        rn = x?.$1.nom ?? rayonDefaut!;
        sn = x?.$2.nom ?? titre;
      }
      final r = b.rayon(rn);
      final s = r == null ? null : b.secteur(r, sn);
      courant = GroupeLu(r?.nom ?? rn, s?.nom ?? sn, rayonNeuf: r == null, secteurNeuf: s == null);
      lu.groupes.add(courant);
      continue;
    }
    final nom = ligne.replaceFirst(RegExp(r'^([-•*·–]|\d+[.)])\s*'), '').trim();
    if (nom.isEmpty) continue;
    if (courant == null) {
      // Produits sans titre : secteur « Divers » du rayon donné, ou d'un rayon Divers existant, sinon à choisir.
      final r = rayonDefaut != null ? b.rayon(rayonDefaut) : b.rayon('Divers');
      courant = r == null
          ? GroupeLu('', 'Divers', secteurNeuf: true, rayonAChoisir: true)
          : GroupeLu(r.nom, 'Divers', secteurNeuf: b.secteur(r, 'Divers') == null);
      lu.groupes.add(courant);
    }
    if (!vus.add('${courant.rayon}/${courant.secteur}/${nom.toLowerCase()}')) continue;
    final s = cible(courant);
    (s != null && b.produitDans(s, nom) != null ? courant.connus : courant.nouveaux).add(nom[0].toUpperCase() + nom.substring(1));
  }
  lu.groupes.removeWhere((g) => g.nouveaux.isEmpty && g.connus.isEmpty && !g.secteurNeuf);
  return lu;
}

/// Ajoute au brouillon ce qu'un texte a donné ; rend le nombre de produits ajoutés.
int ajouterLecture(Brouillon b, LectureCatalogue lu) {
  var n = 0;
  for (final g in lu.groupes) {
    if (g.rayon.isEmpty) continue;
    final r = b.ajouterRayon(g.rayon);
    final s = b.ajouterSecteur(r, g.secteur);
    for (final p in g.nouveaux) {
      if (b.ajouterProduit(s, p)) n++;
    }
  }
  return n;
}
