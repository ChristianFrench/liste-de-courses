import 'dart:async';
import 'dart:convert';

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
  Future<T?> _avecServeur<T>(Future<T?> Function(Transport t, Stream<(String, String)> messages) action) async {
    final t = Synchro.instance.fabrique(Synchro.instance.serveur);
    final connecte = Completer<bool>();
    final messages = t.messages.asBroadcastStream();
    final sub = t.etats.listen((e) {
      if (e == 'connecte' && !connecte.isCompleted) connecte.complete(true);
    });
    try {
      unawaited(t.connecter(
        identifiant: 'ldc-catalogue-${DateTime.now().millisecondsSinceEpoch}',
        sujetTestament: 'ldc/verif',
        testament: '',
        abonnement: sujet,
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
          final m = await messages.firstWhere((m) => m.$1 == sujet && m.$2.isNotEmpty).timeout(const Duration(seconds: 6));
          return jsonDecode(m.$2) as Map<String, dynamic>;
        } on TimeoutException {
          return null;
        }
      });

  /// Publie le catalogue commun (message retenu) ; rend vrai si le serveur l'a renvoyé.
  Future<bool> publier(Map<String, dynamic> j) async {
    final texte = jsonEncode(j);
    final ok = await _avecServeur((t, messages) async {
      final retour = messages.firstWhere((m) => m.$1 == sujet && m.$2 == texte).timeout(const Duration(seconds: 15));
      t.publier(sujet, texte, retenu: true);
      try {
        await retour;
        return true;
      } on TimeoutException {
        return false;
      }
    });
    if (ok == true) {
      _definir('catalogue_commun', texte);
      _appliquer(j);
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

  /// Au lancement : lit le catalogue commun et ajoute au foyer ce qui est nouveau.
  Future<void> verifier() async {
    if (Etat.instance.stockageFoyer == null) return;
    try {
      final j = await recuperer();
      if (j == null) return;
      _definir('catalogue_commun', jsonEncode(j));
      _appliquer(j);
    } catch (e) {
      debugPrint('Catalogue commun : $e');
    }
  }

  void _appliquer(Map<String, dynamic> j) {
    Etat.instance.appliquerCatalogueCommun(j);
    notifyListeners();
  }

  /// Dernier catalogue commun connu (reçu ou publié), sinon le catalogue livré avec l'application.
  Future<Map<String, dynamic>> dernier() async {
    final t = _reglage('catalogue_commun');
    if (t != null) return jsonDecode(t) as Map<String, dynamic>;
    return jsonDecode(await rootBundle.loadString(CatalogueType.fichierLivre)) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------ Brouillon de l'éditeur

  /// Le brouillon en cours, gardé sur cet appareil jusqu'à la publication.
  Future<Brouillon> brouillon() async {
    final t = _reglage('catalogue_brouillon');
    return Brouillon.lire(t != null ? jsonDecode(t) as Map<String, dynamic> : await dernier());
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

  /// Rend faux si le produit existe déjà quelque part.
  bool ajouterProduit(CatSecteur s, String nom) {
    if (nom.trim().isEmpty || produit(nom) != null) return false;
    s.produits.add(CatProduit(nom.trim(), 1));
    _retirerRetire('produit', nom);
    modifications++;
    return true;
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
    if (nom.trim().isEmpty || nom.trim() == p.nom || produit(nom) != null) return;
    renommes.add({'type': 'produit', 'ancien': p.nom, 'nouveau': nom.trim()});
    p.nom = nom.trim();
    modifications++;
  }

  void retirerProduit(CatSecteur s, CatProduit p) {
    s.produits.remove(p);
    retires.add({'type': 'produit', 'nom': p.nom});
    modifications++;
  }

  /// Le secteur et ses produits (les foyers ne retirent que ce qu'ils n'utilisent pas).
  bool retirerSecteur(CatRayon r, CatSecteur s) {
    for (final p in s.produits) {
      retires.add({'type': 'produit', 'nom': p.nom});
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
      meme.produits.addAll(s.produits);
    }
    retires.add({'type': 'secteur', 'rayon': de.nom, 'nom': s.nom});
    if (de.secteurs.isEmpty) {
      catalogue.rayons.remove(de);
      retires.add({'type': 'rayon', 'nom': de.nom});
    }
    modifications++;
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
  void _retirerRetire(String type, String nom) => retires.removeWhere((o) => o['type'] == type && _bas(o['nom'] as String) == _bas(nom));
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
    final cle = nom.toLowerCase();
    if (!vus.add(cle)) continue;
    (b.produit(nom) != null ? courant.connus : courant.nouveaux).add(nom[0].toUpperCase() + nom.substring(1));
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
