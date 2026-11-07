import 'journal_catalogue.dart';
import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'catalogue_type.dart';
import 'images_choisies.dart';
import 'modele.dart';
import 'signature.dart';
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
// 05/11/2026 (Aristide) : le catalogue commun est tenu dans un outil à part (application Windows de l'éditeur, main.dart
// avec OUTIL_EDITEUR) ; l'application n'a plus de menu d'éditeur. Chaque version porte un numéro (« numero ») ;
// les 5 dernières restent sur le serveur (« ldc/catalogue-versions/<numéro> »), l'éditeur peut repartir de
// l'une d'elles. Les foyers ne s'envoient plus leurs ajouts : chacun garde ses modifications, réappliquées à
// chaque nouvelle version, et dépose son catalogue comme proposition pour l'éditeur
// (« ldc/catalogue-propositions/<identifiant du foyer> »).
//
// Contre les mauvais usages (31/10/2026) : le catalogue commun est signé par l'éditeur (signature.dart).

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
          if (!await SignatureEditeur.verifie(m.$2)) return null;
          return deballer(m.$2);
        } on TimeoutException {
          return null;
        }
      });

  /// Le catalogue part compressé (« gz: » + gzip en base 64) : environ 30 ko au lieu de 160.
  static String emballer(Map<String, dynamic> j) => 'gz:${base64Encode(GZipEncoder().encode(utf8.encode(jsonEncode(j)))!)}';

  static Map<String, dynamic> deballer(String publie) {
    final t = SignatureEditeur.contenu(publie);
    return jsonDecode(t.startsWith('gz:') ? utf8.decode(GZipDecoder().decodeBytes(base64Decode(t.substring(3)))) : t) as Map<String, dynamic>;
  }

  /// Pourquoi la dernière publication a échoué (montré à l'éditeur).
  String? erreur;

  // ------------------------------------------------------------ Signature de l'éditeur

  /// Graine de la clé de signature, gardée sur l'appareil de l'éditeur après la saisie de sa phrase.
  String? get graineSignature => _reglage('signature_editeur');

  /// Enregistre la phrase de signature ; rend la clé publique, ou null si la phrase ne correspond pas à la
  /// clé publique de l'application.
  Future<String?> definirPhrase(String phrase) async {
    if (phrase.trim().length < 8) return null;
    final g = await SignatureEditeur.graine(phrase);
    final cle = await SignatureEditeur.clePublique(g);
    if (clePubliqueEditeur.isNotEmpty && cle != clePubliqueEditeur) return null;
    _definir('signature_editeur', g);
    return cle;
  }

  Future<String?> clePublique() async => graineSignature == null ? null : SignatureEditeur.clePublique(graineSignature!);

  /// Publie le catalogue commun (message retenu, signé) ; rend vrai si le serveur l'a renvoyé.
  /// Ne lève jamais d'erreur : en cas d'échec, [erreur] dit pourquoi.
  Future<bool> publier(Map<String, dynamic> j) async {
    erreur = null;
    bool? ok;
    try {
      final graine = graineSignature;
      if (graine == null) {
        erreur = 'phrase de signature non saisie';
        return false;
      }
      final texte = await SignatureEditeur.signer(emballer(j), graine);
      ok = await _avecServeur((t, messages) async {
        final retour = Completer<bool>();
        final sub = messages.listen((m) {
          if (m.$1 == sujet && m.$2 == texte && !retour.isCompleted) retour.complete(true);
        }, onDone: () {
          erreur ??= 'le serveur a coupé la liaison';
          if (!retour.isCompleted) retour.complete(false);
        });
        t.publier(sujet, texte, retenu: true);
        // Les 5 dernières versions restent sur le serveur ; la plus ancienne au-delà est effacée.
        if (j['numero'] case final num n) {
          t.publier(sujetVersion(n.toInt()), texte, retenu: true);
          if (n > versionsGardees) t.publier(sujetVersion(n.toInt() - versionsGardees), '', retenu: true);
        }
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
  static const sujetVersions = 'ldc/catalogue-versions';
  static const sujetPropositions = 'ldc/catalogue-propositions';
  static String sujetVersion(int n) => '$sujetVersions/$n';
  static String sujetProposition(String id) => '$sujetPropositions/$id';

  /// Nombre de versions gardées sur le serveur.
  static const versionsGardees = 5;

  /// Proposition du foyer telle qu'elle a été déposée (texte JSON), pour ne redéposer que si elle a changé.
  String? _deposes;
  Timer? _veille;

  /// Au lancement : lit le catalogue commun et l'ajoute au foyer s'il est nouveau, puis dépose le catalogue du
  /// foyer comme proposition pour l'éditeur s'il a changé. Ensuite, toutes les 10 minutes, redépose la
  /// proposition si elle a changé.
  Future<void> verifier() async {
    final etat = Etat.instance;
    if (etat.stockageFoyer == null) return;
    // Ce qu'un foyer avait reçu des autres avant le 05/11/2026 : retiré, sauf ce qui sert à une liste.
    etat.appliquerApports(const []);
    etat.identifiantApports();
    try {
      final ok = await _avecServeur<bool>((t, messages) async {
        String? commun;
        try {
          commun = (await messages.firstWhere((m) => m.$1 == sujet && m.$2.isNotEmpty).timeout(const Duration(seconds: 8))).$2;
        } on TimeoutException {
          commun = null;
        }
        if (commun != null) await _appliquerCommun(commun);
        // Les anciens dépôts du foyer (avant le 05/11/2026) ne servent plus.
        if (_reglage('apports_effaces') != '1') {
          t.publier(sujetApports(etat.identifiantApports()), '', retenu: true);
          _definir('apports_effaces', '1');
        }
        await _deposer(t);
        await Future<void>.delayed(const Duration(seconds: 2));
        return true;
      });
      if (ok != null) notifyListeners();
    } catch (e) {
      debugPrint('Catalogue commun : $e');
    } finally {
      _veille ??= Timer.periodic(const Duration(minutes: 10), (_) => _redeposer());
    }
  }

  Future<void> _appliquerCommun(String commun) async {
    // Un catalogue mal signé (déposé par un autre que l'éditeur) est ignoré : le dernier bon reste.
    if (!await SignatureEditeur.verifie(commun)) return;
    final j = deballer(commun);
    _definir('catalogue_commun', jsonEncode(j));
    Etat.instance.appliquerCatalogueCommun(j);
  }

  static Map<String, dynamic>? _lire(String t) {
    try {
      return deballer(t);
    } catch (_) {
      return null;
    }
  }

  /// Le catalogue du foyer, dans le format du catalogue commun, tel que l'éditeur le verrait s'il le reprenait :
  /// le dernier catalogue commun connu, plus les rayons, secteurs et produits ajoutés, les renommages, les
  /// déplacements, les mesures et packagings, les images et l'ordre du foyer. Null si le foyer n'a rien changé.
  Future<Map<String, dynamic>?> proposition() async {
    final etat = Etat.instance;
    if (etat.magasins.isEmpty) return null;
    final base = await dernier();
    final b = Brouillon.lire(base);
    final n = b.reprendreFoyer(etat);
    if (n == 0) return null;
    final j = b.versJson()..remove('modifications');
    return {...j, 'base': base['numero'] ?? 0, 'changements': n, 'foyer': etat.numeroProposition};
  }

  /// Dépose la proposition du foyer si elle a changé depuis le dernier dépôt (vide : la retire).
  Future<bool> _deposer(Transport t) async {
    final etat = Etat.instance;
    final p = await proposition();
    final texte = p == null ? '' : jsonEncode(p);
    if (texte == (_deposes ?? _reglage('proposition_deposee') ?? '')) return false;
    final avecDate = p == null ? '' : emballer({...p, 'date': DateTime.now().toIso8601String().substring(0, 16)});
    t.publier(sujetProposition(etat.identifiantApports()), avecDate, retenu: true);
    _deposes = texte;
    _definir('proposition_deposee', texte);
    return true;
  }

  Future<void> _redeposer() async {
    final etat = Etat.instance;
    if (etat.stockageFoyer == null || etat.magasins.isEmpty) return;
    final p = await proposition();
    if ((p == null ? '' : jsonEncode(p)) == (_deposes ?? _reglage('proposition_deposee') ?? '')) return;
    try {
      await _avecServeur<bool>((t, messages) async {
        final fait = await _deposer(t);
        // Le temps que le message parte avant la fermeture de la liaison.
        if (fait) await Future<void>.delayed(const Duration(seconds: 2));
        return fait;
      }, abonnement: 'ldc/verif');
    } catch (e) {
      debugPrint('Proposition de catalogue : $e');
    }
  }

  // ------------------------------------------------------------ Outil de l'éditeur

  /// Les versions gardées sur le serveur (signées), de la plus récente à la plus ancienne.
  Future<List<Map<String, dynamic>>> versions() async {
    final recus = await _tout('$sujetVersions/#');
    final res = <Map<String, dynamic>>[];
    for (final v in recus.values) {
      if (v.isEmpty || !await SignatureEditeur.verifie(v)) continue;
      if (_lire(v) case final j?) res.add(j);
    }
    res.sort((a, b) => ((b['numero'] as num?) ?? 0).compareTo((a['numero'] as num?) ?? 0));
    return res;
  }

  /// Les catalogues proposés par les foyers (« foyer » : leur numéro court), du plus récent au plus ancien.
  Future<List<Map<String, dynamic>>> propositions() async {
    final recus = await _tout('$sujetPropositions/#');
    final res = [
      for (final e in recus.entries)
        if (e.value.isNotEmpty)
          if (_lire(e.value) case final j?) {...j, 'id': e.key.substring(sujetPropositions.length + 1)}
    ];
    res.sort((a, b) => '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}'));
    return res;
  }

  /// Tous les messages retenus sous [abonnement] (fini quand plus rien n'arrive depuis 2 s).
  Future<Map<String, String>> _tout(String abonnement) async =>
      await _avecServeur<Map<String, String>>((t, messages) async {
        final recus = <String, String>{};
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
        return recus;
      }, abonnement: abonnement) ??
      {};

  /// Relit sur le serveur la dernière version publiée (pour l'outil, qui n'a pas de foyer à tenir à jour).
  Future<Map<String, dynamic>?> actualiser() async {
    // 06/11/2026 : la v1 publiée par une console encore réglée sur l'ancien serveur n'était pas sur le serveur OVH ;
    // l'outil retient ce qu'il a trouvé sur le serveur pour le dire et proposer de la renvoyer.
    final r = await _avecServeur<(Map<String, dynamic>?,)>((t, messages) async {
      try {
        final m = await messages.firstWhere((m) => m.$1 == sujet && m.$2.isNotEmpty).timeout(const Duration(seconds: 8));
        return (await SignatureEditeur.verifie(m.$2) ? deballer(m.$2) : null,);
      } on TimeoutException {
        return (null,);
      }
    });
    final j = r?.$1;
    numeroServeur = r == null ? null : ((j?['numero'] as num?) ?? 0).toInt();
    if (j != null) _definir('catalogue_commun', jsonEncode(j));
    notifyListeners();
    return j;
  }

  /// Numéro de la version trouvée sur le serveur à la dernière lecture (0 : aucune ; null : serveur non joint).
  int? numeroServeur;

  /// Renvoie au serveur la dernière version publiée depuis cet outil (absente du serveur).
  Future<bool> renvoyer() async {
    final ok = await publier(await dernier());
    if (ok) await actualiser();
    return ok;
  }

  /// Dernier catalogue commun connu (reçu ou publié), sinon le catalogue livré avec l'application.
  Future<Map<String, dynamic>> dernier() async {
    final t = _reglage('catalogue_commun');
    if (t != null) return jsonDecode(t) as Map<String, dynamic>;
    return jsonDecode(await rootBundle.loadString(CatalogueType.fichierLivre)) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------ Brouillon de l'éditeur

  /// Le brouillon en cours, gardé dans l'outil jusqu'à la généralisation.
  Future<Brouillon> brouillon() async {
    final t = _reglage('catalogue_brouillon');
    final b = Brouillon.lire(t != null ? jsonDecode(t) as Map<String, dynamic> : await dernier());
    // Secteurs renommés dans le catalogue livré (31/10/2026) : renommés aussi pour tous les foyers à la publication.
    for (final (rn, ancien, nouveau) in secteursRenommes) {
      final r = b.rayon(rn);
      final s = r == null ? null : b.secteur(r, ancien);
      if (r != null && s != null) b.renommerSecteur(r, s, nouveau);
    }
    for (final (rn, de, nom, vers) in produitsDeplaces) {
      final r = b.rayon(rn);
      final s = r == null ? null : b.secteur(r, de);
      final p = s == null ? null : b.produitDans(s, nom);
      if (r == null || s == null || p == null) continue;
      final cible = b.secteur(r, vers) ?? b.ajouterSecteur(r, vers);
      s.produits.remove(p);
      if (b.produitDans(cible, nom) == null) cible.produits.add(p);
      b.modifications++;
    }
    final livre = jsonDecode(await rootBundle.loadString(CatalogueType.fichierLivre)) as Map<String, dynamic>;
    b.absorber([_nouveautesLivrees(livre)]);
    // Ordre des secteurs du catalogue livré pour les rayons qu'il réorganise.
    for (final rj in (livre['rayons'] as List).cast<Map>()) {
      if (rj['nom'] != 'Textile') continue;
      final r = b.rayon('Textile');
      if (r != null) b.ordonnerSecteurs(r, [for (final sj in (rj['secteurs'] as List).cast<Map>()) sj['nom'] as String]);
    }
    return b;
  }

  /// Secteurs renommés dans le catalogue livré : (rayon, ancien nom, nouveau nom).
  static const secteursRenommes = [
    ('Boucherie', 'Boucherie traditionnelle et Volailles', 'Viandes et volailles au comptoir'),
    ('Charcuterie', 'Charcuterie à la coupe', 'Charcuterie au comptoir'),
    ('Fromagerie', 'Fromages à la coupe', 'Fromages au comptoir'),
    ('Poissonnerie', 'Poissonnerie traditionnelle', 'Poissonnerie au comptoir'),
    ('Traiteur', 'Traiteur à la coupe', 'Traiteur au comptoir'),
    ('Textile', 'Vêtements et chaussures', 'Vêtements femme'),
  ];

  /// Produits déplacés dans le catalogue livré : (rayon, secteur d'avant, nom, secteur d'arrivée).
  static final produitsDeplaces = [
    for (final n in [
      'Baskets', 'Tongs', 'Bottes de pluie', 'Chaussures enfant', 'Bottes', 'Bottines', 'Derbies', 'Escarpins', //
      'Sandales', 'Mules', 'Espadrilles', 'Chaussures de running', 'Chaussons',
    ])
      ('Textile', 'Vêtements femme', n, 'Chaussures'),
    for (final n in ['Gants', 'Bonnets', 'Écharpes']) ('Textile', 'Vêtements femme', n, 'Accessoires de mode'),
    for (final n in ['Vêtements bébé', 'Bodies bébé', 'Ensemble naissance', 'Combinaison pilote'])
      ('Textile', 'Vêtements femme', n, 'Vêtements enfant et bébé'),
    for (final n in ['Polos', 'Joggings', 'Imperméables']) ('Textile', 'Vêtements femme', n, 'Vêtements homme'),
    ('Textile', 'Vêtements femme', 'Chaussettes', 'Lingerie'),
  ];

  /// Produits du catalogue livré avec l'application absents du dernier catalogue publié (ajoutés au catalogue
  /// livré depuis : natures d'Open Food Facts, 31/10/2026). L'éditeur les publie ensuite pour tous les foyers.
  Map<String, dynamic> _nouveautesLivrees(Map<String, dynamic> livre) {
    return {
      'produits': [
        for (final r in (livre['rayons'] as List).cast<Map>())
          for (final s in (r['secteurs'] as List).cast<Map>())
            for (final p in (s['produits'] as List).cast<Map>())
              {'nom': p['nom'], 'rayon': r['nom'], 'secteur': s['nom'], if (p['formats'] is List) 'formats': p['formats']}
      ],
    };
  }

  void enregistrerBrouillon(Brouillon b) => _definir('catalogue_brouillon', jsonEncode(b.versJson()));

  /// Historique des modifications de l'éditeur (étapes validées et gestes en cours), propre à cet appareil.
  JournalCatalogue journal() => JournalCatalogue.lire(_reglage('catalogue_journal'));
  void enregistrerJournal(JournalCatalogue j) => _definir('catalogue_journal', j.ecrire());

  void abandonnerBrouillon() => Etat.instance.stockageFoyer?.effacerReglage('catalogue_brouillon');

  /// Le brouillon repart d'un catalogue (une version gardée, ou la proposition d'un foyer).
  Brouillon repartirDe(Map<String, dynamic> j, {required int modifications}) {
    final base = Map<String, dynamic>.from(j)
      ..remove('id')
      ..remove('foyer')
      ..remove('changements')
      ..remove('base')
      ..['modifications'] = modifications;
    final b = Brouillon.lire(base);
    enregistrerBrouillon(b);
    return b;
  }

  /// Numéro de la prochaine version : celui de la dernière publiée, plus un.
  Future<int> prochainNumero() async => (((await dernier())['numero'] as num?) ?? 0).toInt() + 1;

  Future<bool> publierBrouillon(Brouillon b) async {
    final j = b.versJson()
      ..['version'] = DateTime.now().millisecondsSinceEpoch
      ..['numero'] = await prochainNumero()
      ..['date'] = DateTime.now().toIso8601String().substring(0, 16);
    j.remove('modifications');
    final ok = await publier(j);
    if (ok) abandonnerBrouillon();
    return ok;
  }
}

/// Le catalogue commun en cours de modification par l'éditeur.
class Brouillon {
  Brouillon(this.catalogue, this.images, this.renommes, this.retires, this.version, this.modifications, {Set<String>? bloques})
      : bloques = bloques ?? {};
  final CatalogueType catalogue;
  final Map<String, String> images;
  final List<Map<String, dynamic>> renommes, retires;
  final int version;

  /// Foyers (identifiants d'apports) dont les ajouts sont bloqués pour tous.
  final Set<String> bloques;

  /// Nombre de modifications depuis la dernière publication.
  int modifications;

  factory Brouillon.lire(Map<String, dynamic> j) => Brouillon(
        CatalogueType.lire(j),
        {for (final e in (j['images'] as Map? ?? const {}).entries) e.key as String: e.value as String},
        [for (final o in (j['renommes'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)],
        [for (final o in (j['retires'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)],
        (j['version'] as num? ?? 0).toInt(),
        (j['modifications'] as num? ?? 0).toInt(),
        bloques: {for (final x in (j['bloques'] as List? ?? const [])) '$x'},
      );

  Map<String, dynamic> versJson() => {
        ...catalogue.versJson(),
        'version': version,
        if (images.isNotEmpty) 'images': images,
        if (renommes.isNotEmpty) 'renommes': renommes,
        if (retires.isNotEmpty) 'retires': retires,
        if (bloques.isNotEmpty) 'bloques': bloques.toList()..sort(),
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

  /// Nouvel ordre des rayons (par leurs noms ; console, glisser-déposer).
  void ordonnerRayons(List<String> noms) {
    final avant = [for (final r in catalogue.rayons) r.nom];
    catalogue.rayons = [
      for (final n in noms) ...catalogue.rayons.where((r) => r.nom == n),
      ...catalogue.rayons.where((r) => !noms.contains(r.nom)),
    ];
    if ([for (final r in catalogue.rayons) r.nom].join('\n') != avant.join('\n')) modifications++;
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

  /// Déplace un produit dans un autre secteur (console, glisser-déposer) ; les foyers le rangent dans son nouveau
  /// secteur. Rend faux s'il y est déjà.
  bool deplacerProduit(CatSecteur de, CatProduit p, CatSecteur vers) {
    if (identical(de, vers) || produitDans(vers, p.nom) != null) return false;
    de.produits.remove(p);
    vers.produits.add(p);
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

  /// « Reprendre tout mon catalogue » (02/11/2026, Aristide) : le catalogue du foyer de l'éditeur devient le
  /// brouillon, sans la preuve d'achat demandée aux autres foyers. Reprend les rayons et secteurs renommés,
  /// les rayons, secteurs et produits ajoutés, les produits d'origine déplacés, les mesures et packagings,
  /// les images choisies et l'ordre des rayons et des secteurs. Ce que l'éditeur a retiré reste retiré ;
  /// rien n'est retiré du brouillon. Rend le nombre de changements.
  int reprendreFoyer(Etat e) {
    final avant = modifications;
    final exclus = {...Etat.exclusDu({'retires': retires, 'renommes': renommes}), ...e.exclusCommun};

    // 1. Renommages des rayons et secteurs d'origine.
    for (final r in e.rayonsVisibles) {
      final origine = e.origineRayon(r.nom);
      if (origine != r.nom && rayon(r.nom) == null) {
        if (rayon(origine) case final cr?) renommerRayon(cr, r.nom);
      }
      final cr = rayon(r.nom);
      if (cr == null) continue;
      for (final x in e.secteursVisibles(r.id)) {
        final os = e.origineSecteur(r.nom, x.nom);
        if (os != x.nom && secteur(cr, x.nom) == null) {
          if (secteur(cr, os) case final cs?) renommerSecteur(cr, cs, x.nom);
        }
      }
    }

    // 2. Rayons et secteurs, dans l'ordre du foyer.
    final ordre = e.ordreRayons.isEmpty
        ? e.rayonsVisibles
        : ([...e.rayonsVisibles]..sort((a, b) {
            int rang(String n) => e.ordreRayons.contains(n) ? e.ordreRayons.indexOf(n) : 100000;
            return rang(a.nom).compareTo(rang(b.nom));
          }));
    for (final r in ordre) {
      if (Etat.estExclu(exclus, rayon: r.nom)) continue;
      final cr = rayon(r.nom) ?? ajouterRayon(r.nom);
      final noms = <String>[];
      for (final x in e.secteursVisibles(r.id)) {
        if (Etat.estExclu(exclus, rayon: r.nom, secteur: x.nom)) continue;
        if (secteur(cr, x.nom) == null) ajouterSecteur(cr, x.nom);
        noms.add(x.nom);
      }
      ordonnerSecteurs(cr, noms);
    }
    final rangs = {for (var i = 0; i < ordre.length; i++) _bas(ordre[i].nom): i};
    final avantOrdre = [for (final r in catalogue.rayons) r.nom].join('\n');
    catalogue.rayons.sort((a, b) => (rangs[_bas(a.nom)] ?? 100000).compareTo(rangs[_bas(b.nom)] ?? 100000));
    if ([for (final r in catalogue.rayons) r.nom].join('\n') != avantOrdre) modifications++;

    // 3. Produits du foyer (pas ceux reçus des autres foyers) : ajoutés, déplacés, mesures et packagings.
    final placesFoyer = <String, Set<String>>{};
    for (final p in e.produits) {
      final x = e.secteurCatalogue(p.id);
      if (x != null) (placesFoyer[_bas(p.nom)] ??= {}).add('${_bas(e.rayon(x.rayonId)?.nom ?? '')}/${_bas(x.nom)}');
    }
    for (final p in e.produits) {
      if (e.estRecu(p)) continue;
      final x = e.secteurCatalogue(p.id);
      final r = x == null ? null : e.rayon(x.rayonId);
      if (x == null || r == null || Etat.estExclu(exclus, rayon: r.nom, secteur: x.nom, produit: p.nom)) continue;
      final cr = rayon(r.nom), cs = cr == null ? null : secteur(cr, x.nom);
      if (cs == null) continue;
      final formats = [for (final id in p.packagingIds) if (e.packaging(id)?.libelle case final l?) l];
      final marques = [for (final id in p.marqueIds) if (e.marque(id)?.nom case final n?) n];
      var cp = produitDans(cs, p.nom);
      if (cp == null) {
        // Un produit d'origine rangé ailleurs dans le brouillon, que le foyer n'a plus là-bas : déplacé.
        final ailleurs = e.estAjoute(p) ? null : produit(p.nom);
        if (ailleurs != null && !(placesFoyer[_bas(p.nom)] ?? const {}).contains('${_bas(ailleurs.$1.nom)}/${_bas(ailleurs.$2.nom)}')) {
          ailleurs.$2.produits.remove(ailleurs.$3);
          cp = ailleurs.$3;
          cs.produits.add(cp);
        } else {
          cp = CatProduit(p.nom, 1, marques: marques, formats: formats);
          cs.produits.add(cp);
          _retirerRetire('produit', p.nom, secteur: cs.nom);
        }
        modifications++;
      }
      if (formats.join('\n') != cp.formats.join('\n')) {
        cp.formats = formats;
        modifications++;
      }
    }

    // 4. Images choisies.
    for (final MapEntry(key: cle, value: picto) in imagesChoisies.entries) {
      if (images[cle] != picto) choisirImage(cle, picto);
    }
    return modifications - avant;
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

/// Titre : ligne qui finit par « : » ou qui commence par « Secteur » (« Animalerie / Chats : »,
/// « Secteur Chats », ou « Fruits : » si ce secteur existe ; un secteur inconnu sans rayon va dans le rayon
/// courant ou [rayonDefaut], sinon son rayon est à choisir). Une ligne qui commence par « Rayon » fixe le rayon
/// courant (créé s'il n'existe pas) pour les secteurs qui suivent ; ses produits sans secteur vont dans un
/// secteur du nom du rayon (07/11/2026, Aristide). Les autres lignes sont des produits ; puces et numéros sont
/// enlevés. Sans titre au-dessus, les produits vont dans « Divers ».
LectureCatalogue lireTexteCatalogue(Brouillon b, String texte, {String? rayonDefaut}) {
  final lu = LectureCatalogue();
  GroupeLu? courant;
  String? rayonCourant;
  final vus = <String>{};
  CatSecteur? cible(GroupeLu g) {
    final r = g.rayon.isEmpty ? null : b.rayon(g.rayon);
    return r == null ? null : b.secteur(r, g.secteur);
  }

  GroupeLu groupe(String rn, String sn) {
    final r = b.rayon(rn);
    final s = r == null ? null : b.secteur(r, sn);
    final g = GroupeLu(r?.nom ?? rn, s?.nom ?? sn, rayonNeuf: r == null, secteurNeuf: s == null);
    lu.groupes.add(g);
    return g;
  }

  final motCle = RegExp(r'^(rayon|secteur)\b\s*:?\s*(.*?)\s*:?$', caseSensitive: false);
  for (final brut in const LineSplitter().convert(texte)) {
    final ligne = brut.trim();
    if (ligne.isEmpty) continue;
    final m = motCle.firstMatch(ligne);
    if (m != null && m.group(2)!.isNotEmpty && m.group(1)!.toLowerCase() == 'rayon') {
      final n = m.group(2)!;
      rayonCourant = b.rayon(n)?.nom ?? n[0].toUpperCase() + n.substring(1);
      courant = null;
      continue;
    }
    final estSecteur = m != null && m.group(2)!.isNotEmpty;
    if (estSecteur || ligne.endsWith(':')) {
      final titre = estSecteur ? m.group(2)! : ligne.substring(0, ligne.length - 1).trim();
      final parties = titre.split(RegExp(r'\s*[/›>]\s*'));
      if (parties.length >= 2) {
        courant = groupe(parties.first, parties.sublist(1).join(' '));
        continue;
      }
      if (rayonCourant != null) {
        courant = groupe(rayonCourant, titre);
        continue;
      }
      final x = b.secteurPartout(titre);
      if (x == null && rayonDefaut == null) {
        // Secteur inconnu, rayon non dit : on le demandera (pas de nouveau rayon d'office).
        courant = GroupeLu('', titre, secteurNeuf: true, rayonAChoisir: true);
        lu.groupes.add(courant);
        continue;
      }
      courant = groupe(x?.$1.nom ?? rayonDefaut!, x?.$2.nom ?? titre);
      continue;
    }
    final nom = ligne.replaceFirst(RegExp(r'^([-•*·–]|\d+[.)])\s*'), '').trim();
    if (nom.isEmpty) continue;
    if (courant == null && rayonCourant != null) courant = groupe(rayonCourant, rayonCourant);
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
