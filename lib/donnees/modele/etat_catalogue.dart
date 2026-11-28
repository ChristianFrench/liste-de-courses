part of '../modele.dart';

// Méthodes de l'état (EtatCatalogue), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatCatalogue on Etat {

  // ------------------------------------------------------------ Magasin et catalogue

  Magasin? magasinNomme(String nom) => Etat._trouve(magasins, (m) => m.nom.trim().toLowerCase() == nom.trim().toLowerCase());

  /// Listes non terminées rattachées à un magasin.
  List<Liste> listesDuMagasin(String magasinId) =>
      listes.where((l) => l.magasinId == magasinId && l.statut != StatutListe.terminee).toList();

  Magasin creerMagasin(String nom) {
    Sauvegarde.instance.jalon('Magasin créé');
    final m = Magasin(nouvelId('mg'), nom, '', '');
    magasins.add(m);
    modifie();
    return m;
  }

  /// Un nouveau magasin reçoit le catalogue du foyer (le même pour tous les magasins) ;
  /// le premier magasin du foyer, le catalogue de départ.
  Future<void> remplirMagasin(Magasin m) async {
    // 12/11/2026 : la structure est commune ; seul un foyer qui n'en a pas encore reçoit le catalogue de départ.
    if (rayons.isEmpty) await appliquerModele(m, Etat.tailleComplete);
  }

  /// Remplit un magasin avec les rayons, secteurs et produits du catalogue type jusqu'à la
  /// [taille] donnée (1 proximité, 2 supermarché, 3 hypermarché). Un produit déjà connu du
  /// foyer (même nom) est réutilisé. Rend le nombre de produits placés.
  Future<int> appliquerModele(Magasin m, int taille, {Map<String, dynamic>? catalogue}) async {
    if (taille <= 0) return 0;
    catalogue ??= await CatalogueType.lireJson();
    final parNom = {for (final p in produits) p.nom.toLowerCase(): p};
    // Index locaux (11/11/2026) : sans eux, chaque produit parcourait tous les emplacements, et le premier
    // lancement de la démonstration (six magasins de 2 300 produits) calculait une dizaine de secondes.
    final homonymes = <String, List<Produit>>{};
    for (final p in produits) {
      homonymes.putIfAbsent(p.nom.toLowerCase(), () => []).add(p);
    }
    final ici = <String, Emplacement>{};
    for (final e in emplacements) {
      ici.putIfAbsent(e.produitId, () => e);
    }
    final rayonsIci = {for (final x in rayons.reversed) x.nom: x};
    var n = 0;
    for (final r in (catalogue['rayons'] as List).cast<Map>()) {
      final secteursR = (r['secteurs'] as List).cast<Map>().where((s) => (s['taille'] as num) <= taille).toList();
      if (secteursR.isEmpty) continue;
      final rayon = rayonsIci[r['nom']] ??
          (Rayon(_idRayon(r['nom'] as String), magasinCommun, r['nom'] as String)..let(rayons.add)..let((x) => rayonsIci[x.nom] = x));
      final secteursIci = {for (final x in secteurs.reversed) if (x.rayonId == rayon.id) x.nom: x};
      for (final s in secteursR) {
        final secteur = secteursIci[s['nom']] ??
            (Secteur(_idSecteur(rayon.nom, s['nom'] as String), rayon.id, s['nom'] as String)..let(secteurs.add)..let((x) => secteursIci[x.nom] = x));
        for (final p in (s['produits'] as List).cast<Map>()) {
          if ((p['taille'] as num) > taille) continue;
          final nom = p['nom'] as String;
          final cle = nom.toLowerCase();
          // Une même nature peut être dans deux secteurs (libre-service et à la coupe) : un produit par secteur.
          Produit? connu = parNom[cle];
          if (connu != null) {
            final e = ici[connu.id];
            if (e != null && e.secteurId != secteur.id) {
              connu = Etat._trouve(homonymes[cle] ?? const <Produit>[], (x) {
                final ex = ici[x.id];
                return ex == null || ex.secteurId == secteur.id;
              });
            }
          }
          final produit = connu ??
              (Produit(nouvelId('p'), nom, [], [], 0)
                ..let(produits.add)
                ..let((x) => homonymes.putIfAbsent(cle, () => []).add(x)));
          parNom.putIfAbsent(cle, () => produit);
          if (produit.packagingIds.isEmpty) {
            for (final f in (p['formats'] as List? ?? const []).cast<String>()) {
              produit.packagingIds.add(_packagingNomme(f).id);
            }
          }
          if (!ici.containsKey(produit.id)) {
            final e = Emplacement(magasinCommun, produit.id, secteur.id);
            emplacements.add(e);
            ici[produit.id] = e;
            n++;
          }
        }
      }
    }
    modifie();
    return n;
  }

  Rayon ajouterRayon(String magasinId, String nom) {
    final existant = Etat._trouve(rayons, (r) => r.nom == nom);
    if (existant != null) return existant; // un nom par rayon (contrainte de la base)
    final r = Rayon(_idRayon(nom), magasinCommun, nom);
    rayons.add(r);
    modifie();
    return r;
  }

  Secteur ajouterSecteur(String rayonId, String nom) {
    final existant = Etat._trouve(secteurs, (s) => s.rayonId == rayonId && s.nom == nom);
    if (existant != null) return existant; // un nom par rayon (contrainte de la base)
    final s = Secteur(_idSecteur(rayon(rayonId)?.nom ?? rayonId, nom), rayonId, nom);
    secteurs.add(s);
    modifie();
    return s;
  }
  String _idRayon(String nom) {
    final id = 'rc-${Etat._cleStructure(nom)}';
    return rayon(id) == null ? id : nouvelId('rc');
  }

  String _idSecteur(String rayonNom, String nom) {
    final id = 'sc-${Etat._cleStructure(rayonNom)}/${Etat._cleStructure(nom)}';
    return secteur(id) == null ? id : nouvelId('sc');
  }

  /// Gardé pour les appels existants : le catalogue ne dépend plus d'un magasin.
  Magasin? get magasinReference => magasins.isEmpty ? null : magasins.first;

  /// Rayons du catalogue.
  List<Rayon> get rayonsCatalogue => List.of(rayons);

  /// Secteur du catalogue où est rangé le produit, ou null.
  Secteur? secteurCatalogue(String produitId) => secteurDe(magasinCommun, produitId);

  /// Produits d'un secteur du catalogue ; sans ceux des autres foyers si le catalogue est isolé.
  List<Produit> produitsDuSecteur(Secteur s) => [for (final p in _tousDuSecteur(s)) if (produitVisible(p)) p];

  List<Produit> _tousDuSecteur(Secteur s) => produitsDu(magasinCommun, s.id);

  /// Le secteur est le même dans tous les magasins.
  Secteur? secteurHomologue(String magasinId, Secteur s) => s;

  /// Produit ajouté par le foyer : lui seul peut être modifié ; le catalogue d'origine ne change pas.
  bool estAjoute(Produit p) => produitsPerso[p.id] == 'a';

  /// Produits ajoutés par le foyer, par ordre alphabétique.
  List<Produit> get produitsAjoutes =>
      [for (final p in produits) if (estAjoute(p)) p]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  void _marquerAjoute(Produit p) => produitsPerso[p.id] = 'a';

  /// Marque de ce nom (créée au besoin).
  Marque marqueNommee(String nom) {
    var m = Etat._trouve(marques, (m) => m.nom.toLowerCase() == nom.trim().toLowerCase());
    if (m == null) {
      m = Marque(nouvelId('b'), nom.trim());
      marques.add(m);
      modifie();
    }
    return m;
  }

  /// Libellé d'un produit ajouté, sans sa marque (« Camembert Président » → « Camembert »).
  String libelleSansMarque(Produit p) {
    final m = p.marqueIds.isEmpty ? null : marque(p.marqueIds.first);
    if (m != null && p.nom.toLowerCase().endsWith(' ${m.nom.toLowerCase()}')) {
      return p.nom.substring(0, p.nom.length - m.nom.length - 1);
    }
    return p.nom;
  }

  /// Crée (ou corrige, avec [produit]) un produit ajouté : son nom est le libellé suivi de la marque,
  /// sa mesure et son packaging forment son format de vente.
  Produit enregistrerProduitAjoute({
    Produit? produit,
    required String libelle,
    String? marqueNom,
    String? mesure,
    String? lot,
    Secteur? secteur,
  }) {
    final mq = (marqueNom ?? '').trim();
    final nom = mq.isEmpty ? libelle.trim() : '${libelle.trim()} $mq';
    final p = produit ?? creerProduit(nom, secteur: secteur);
    p.nom = nom;
    p.marqueIds
      ..clear()
      ..addAll([if (mq.isNotEmpty) marqueNommee(mq).id]);
    final k = packagingCompose(mesure, lot);
    p.packagingIds
      ..clear()
      ..addAll([if (k != null) k.id]);
    if (produit != null && secteur != null) placer('', p.id, secteur.id);
    modifie();
    return p;
  }

  /// Range le produit dans le secteur [secteurId], le même dans tous les magasins.
  /// [magasinId] n'est gardé que pour les appels existants.
  void placer(String magasinId, String produitId, String secteurId) {
    final s = secteur(secteurId);
    final p = produit(produitId);
    if (s == null || p == null) return;
    final e = _indexEmplacements.trouver(_emplacements, produitId);
    if (e == null) {
      emplacements.add(Emplacement(magasinCommun, produitId, s.id));
    } else {
      e.secteurId = s.id;
    }
    // Pendant l'application du catalogue commun, un seul enregistrement à la fin (06/11/2026 : un par produit
    // bloquait le téléphone plusieurs minutes).
    modifie();
  }

  /// Nouveau produit du catalogue (marqué « ajouté »), rangé dans [secteur] s'il est donné.
  Produit creerProduit(String nom, {Secteur? secteur}) {
    final p = Produit(nouvelId('p'), nom.trim(), [], [], 0);
    produits.add(p);
    _marquerAjoute(p);
    if (secteur != null) {
      placer(magasinCommun, p.id, secteur.id);
    } else {
      modifie();
    }
    return p;
  }

  void renommerProduit(Produit p, String nom) {
    if (nom.trim().isEmpty || nom.trim() == p.nom) return;
    p.nom = nom.trim();
    modifie();
  }

  /// Gardé pour les appels existants (tests) : voir [unifierStructure].
  bool harmoniserCatalogue() => unifierStructure();

  /// Une seule structure pour tous les magasins (12/11/2026). Une base où chaque magasin avait son exemplaire
  /// des rayons, secteurs et emplacements (ou des objets reçus d'un appareil pas encore à jour) est ramenée
  /// à un exemplaire commun : rayons et secteurs fusionnés par leurs noms (identifiants tirés des noms, les
  /// mêmes sur tous les appareils), chaque produit rangé dans le secteur où il l'était dans le plus de
  /// magasins (à égalité, le premier par ordre alphabétique), parcours et listes reportés sur les secteurs
  /// communs. Rend vrai si quelque chose a changé.
  bool unifierStructure() {
    final c = _unifier() | _structureAConvertir;
    _structureAConvertir = false;
    if (c) modifie();
    return c;
  }

  bool _unifier() {
    final anciensRayons = rayons.where((r) => r.magasinId != magasinCommun).toList();
    final anciensEmplacements = emplacements.where((e) => e.magasinId != magasinCommun).toList();
    if (anciensRayons.isEmpty && anciensEmplacements.isEmpty) return false;
    // Rayons : les communs d'abord, puis ceux des magasins dans l'ordre des magasins (le premier donne l'ordre).
    final rangMagasin = {for (var i = 0; i < magasins.length; i++) magasins[i].id: i};
    final ordre = [...rayons]..sort((a, b) {
        int rang(Rayon r) => r.magasinId == magasinCommun ? -1 : rangMagasin[r.magasinId] ?? magasins.length;
        return rang(a).compareTo(rang(b));
      });
    final ancienRayon = {for (final r in rayons) r.id: r};
    final rayonParNom = <String, Rayon>{};
    final secteurParNom = <String, Secteur>{}; // « rayon|secteur » → secteur commun
    final versRayon = <String, String>{}, versSecteur = <String, String>{};
    final nouveauxRayons = <Rayon>[], nouveauxSecteurs = <Secteur>[];
    final idsPris = <String>{};
    String libre(String id, String prefixe) => idsPris.add(id) ? id : (nouvelId(prefixe)..let(idsPris.add));
    final parRayon = <String, List<Secteur>>{};
    for (final x in secteurs) {
      (parRayon[x.rayonId] ??= []).add(x);
    }
    for (final r in ordre) {
      if (r.magasinId == magasinCommun) idsPris.add(r.id);
    }
    for (final x in secteurs) {
      if (ancienRayon[x.rayonId]?.magasinId == magasinCommun) idsPris.add(x.id);
    }
    for (final r in ordre) {
      final commun = rayonParNom.putIfAbsent(r.nom, () {
        final c = r.magasinId == magasinCommun ? r : Rayon(libre('rc-${Etat._cleStructure(r.nom)}', 'rc'), magasinCommun, r.nom);
        nouveauxRayons.add(c);
        return c;
      });
      versRayon[r.id] = commun.id;
      for (final x in parRayon[r.id] ?? const <Secteur>[]) {
        final cs = secteurParNom.putIfAbsent('${r.nom}|${x.nom}', () {
          final c = r.magasinId == magasinCommun && commun.id == r.id
              ? x
              : Secteur(libre('sc-${Etat._cleStructure(r.nom)}/${Etat._cleStructure(x.nom)}', 'sc'), commun.id, x.nom);
          nouveauxSecteurs.add(c);
          return c;
        });
        versSecteur[x.id] = cs.id;
      }
    }
    // Rangement : un emplacement commun déjà là l'emporte ; sinon le secteur le plus fréquent.
    final votes = <String, Map<String, int>>{};
    final retenu = <String, String>{};
    for (final e in emplacements) {
      final cible = versSecteur[e.secteurId];
      if (cible == null) continue;
      if (e.magasinId == magasinCommun) {
        retenu[e.produitId] = cible;
      } else {
        final v = votes[e.produitId] ??= {};
        v[cible] = (v[cible] ?? 0) + 1;
      }
    }
    for (final pv in votes.entries) {
      if (retenu.containsKey(pv.key)) continue;
      final choix = (pv.value.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key))).first.key;
      retenu[pv.key] = choix;
    }
    rayons = nouveauxRayons;
    secteurs = nouveauxSecteurs;
    emplacements = [for (final e in retenu.entries) Emplacement(magasinCommun, e.key, e.value)];
    // Parcours appris et reprises de listes : vers les secteurs communs (une étape en double disparaît).
    for (final p in parcours) {
      final vus = <String>{};
      p.etapes = [
        for (final id in p.etapes)
          if (versSecteur[id] ?? (secteur(id) != null ? id : null) case final n?) if (vus.add(n)) n
      ];
    }
    for (final l in listes) {
      if (l.repriseRayonId != null) l.repriseRayonId = versRayon[l.repriseRayonId] ?? (rayon(l.repriseRayonId) != null ? l.repriseRayonId : null);
      if (l.repriseSecteurId != null) {
        l.repriseSecteurId = versSecteur[l.repriseSecteurId] ?? (secteur(l.repriseSecteurId) != null ? l.repriseSecteurId : null);
      }
    }
    return true;
  }

  /// Produit présent dans une liste (en préparation, prête, en cours ou dans l'historique).
  bool produitUtilise(Produit p) => listes.any((l) => l.lignes.any((g) => g.produitId == p.id));

  void ajouterMarque(Produit p, String nom) {
    var m = Etat._trouve(marques, (m) => m.nom.toLowerCase() == nom.toLowerCase());
    if (m == null) {
      m = Marque(nouvelId('b'), nom);
      marques.add(m);
    }
    if (!p.marqueIds.contains(m.id)) {
      p.marqueIds.add(m.id);
    }
    modifie();
  }

  void ajouterPackaging(Produit p, String libelle) {
    var k = Etat._trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(nouvelId('k'), libelle);
      packagings.add(k);
    }
    if (!p.packagingIds.contains(k.id)) {
      p.packagingIds.add(k.id);
    }
    modifie();
  }
}
