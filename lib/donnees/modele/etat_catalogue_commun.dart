part of '../modele.dart';

// Méthodes de l'état (EtatCatalogueCommun), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatCatalogueCommun on Etat {

  /// Ajoute au foyer une version plus récente du catalogue commun. Rend les nouveautés (vide si rien).
  List<String> appliquerCatalogueCommun(Map<String, dynamic> j) {
    _enLot = true;
    _modifieEnAttente = false;
    try {
      return _appliquerCatalogueCommun(j);
    } finally {
      _enLot = false;
      if (_modifieEnAttente) modifie();
    }
  }

  List<String> _appliquerCatalogueCommun(Map<String, dynamic> j) {
    Sauvegarde.instance.jalon('Catalogue commun reçu');
    final version = (j['version'] as num? ?? 0).toInt();
    // Version déjà appliquée par une version d'Emplettes qui ne retenait pas son numéro : il est repris.
    final numero = (j['numero'] as num? ?? 0).toInt();
    if (version == versionCatalogueCommun && numero > 0 && numeroCatalogueCommun != numero) {
      numeroCatalogueCommun = numero;
      modifie();
    }
    if (version <= versionCatalogueCommun || magasins.isEmpty) return const [];
    // Rayons et secteurs renommés par le foyer : les noms d'origine du catalogue commun deviennent les siens.
    if (renommages.isNotEmpty) {
      final rayonsActuels = {for (final e in renommages.entries) if (e.key.startsWith('r:')) e.value: e.key.substring(2)};
      final secteursActuels = {for (final e in renommages.entries) if (e.key.startsWith('s:')) '${e.key.substring(2, e.key.lastIndexOf('/'))}/${e.value}': e.key.substring(e.key.lastIndexOf('/') + 1)};
      for (final rj in (j['rayons'] as List? ?? const []).whereType<Map>()) {
        final ro = rj['nom'] as String? ?? '';
        for (final sj in (rj['secteurs'] as List? ?? const []).whereType<Map>()) {
          if (secteursActuels['$ro/${sj['nom']}'] case final n?) sj['nom'] = n;
        }
        if (rayonsActuels[ro] case final n?) rj['nom'] = n;
      }
    }
    final lignes = <String>[];
    String bas(String t) => t.trim().toLowerCase();
    // Recherche par nom en table (le premier de ce nom, comme avant), tenue à jour aux renommages et ajouts.
    final parNom = <String, Produit>{};
    void indexer() {
      parNom.clear();
      for (final p in produits) {
        parNom.putIfAbsent(bas(p.nom), () => p);
      }
    }

    indexer();
    Produit? produitNomme(String nom) => parNom[bas(nom)];
    // Un même nom peut être dans plusieurs secteurs : le produit est alors repéré par son secteur.
    String? secteurDuProduit(Produit p) => secteurCatalogue(p.id)?.nom;
    Produit? produitDuSecteur(String nom, Object? secteur) =>
        secteur == null ? produitNomme(nom) : Etat._trouve(produits, (p) => bas(p.nom) == bas(nom) && secteurDuProduit(p) == secteur);
    final places = <String, Set<String>>{};
    for (final rj in (j['rayons'] as List).cast<Map>()) {
      for (final sj in (rj['secteurs'] as List).cast<Map>()) {
        for (final pj in (sj['produits'] as List).cast<Map>()) {
          places.putIfAbsent(bas(pj['nom'] as String), () => {}).add('${rj['nom']}/${sj['nom']}');
        }
      }
    }
    final pris = <String>{};
    exclusCommun = Etat.exclusDu(j);
    foyersBloques = {for (final x in (j['bloques'] as List? ?? const [])) '$x'};

    // 1. Noms changés par l'éditeur.
    var renommes = 0;
    for (final o in (j['renommes'] as List? ?? const []).cast<Map>()) {
      final ancien = o['ancien'] as String, nouveau = o['nouveau'] as String;
      switch (o['type']) {
        case 'rayon':
          if (Etat._trouve(rayons, (r) => r.nom == nouveau) != null) continue;
          for (final r in rayons.where((r) => r.nom == ancien)) {
            r.nom = nouveau;
            renommes++;
          }
        case 'secteur':
          for (final x in secteurs.where((x) => x.nom == ancien && rayon(x.rayonId)?.nom == o['rayon'])) {
            if (Etat._trouve(secteurs, (y) => y.rayonId == x.rayonId && y.nom == nouveau) != null) continue;
            x.nom = nouveau;
            renommes++;
          }
        case 'produit':
          final p = produitDuSecteur(ancien, o['secteur']);
          if (p != null && produitDuSecteur(nouveau, o['secteur']) == null) {
            p.nom = nouveau;
            renommes++;
            indexer();
          }
      }
    }

    // 2. Rayons, secteurs et produits.
    for (final rj in (j['rayons'] as List).cast<Map>()) {
      final rn = rj['nom'] as String;
      final rayonNeuf = Etat._trouve(rayonsCatalogue, (r) => r.nom == rn) == null;
      if (rayonNeuf) lignes.add('Nouveau rayon : $rn');
      structurePerso.remove(rn);
      structureRecue.remove(rn);
      if (Etat._trouve(rayons, (r) => r.nom == rn) == null) rayons.add(Rayon(_idRayon(rn), magasinCommun, rn));
      for (final sj in (rj['secteurs'] as List).cast<Map>()) {
        final sn = sj['nom'] as String;
        final ref = Etat._trouve(rayonsCatalogue, (r) => r.nom == rn)!;
        if (!rayonNeuf && Etat._trouve(secteursDu(ref.id), (x) => x.nom == sn) == null) lignes.add('Nouveau secteur : $rn › $sn');
        structurePerso.remove('$rn/$sn');
        structureRecue.remove('$rn/$sn');
        if (Etat._trouve(secteurs, (x) => x.rayonId == ref.id && x.nom == sn) == null) secteurs.add(Secteur(_idSecteur(rn, sn), ref.id, sn));
        final secteurRef = Etat._trouve(secteursDu(ref.id), (x) => x.nom == sn)!;
        for (final pj in (sj['produits'] as List).cast<Map>()) {
          final nom = pj['nom'] as String;
          final plusieurs = (places[bas(nom)]?.length ?? 0) > 1;
          String? place(Produit x) {
            final c = secteurCatalogue(x.id);
            return c == null ? null : '${rayon(c.rayonId)?.nom}/${c.nom}';
          }

          // Même nom dans plusieurs secteurs : celui de ce secteur, sinon un homonyme rangé ailleurs, sinon un nouveau.
          var p = !plusieurs
              ? produitNomme(nom)
              : Etat._trouve(produits, (x) => bas(x.nom) == bas(nom) && secteurCatalogue(x.id)?.id == secteurRef.id) ??
                  Etat._trouve(produits, (x) => bas(x.nom) == bas(nom) && !pris.contains(x.id) && !places[bas(nom)]!.contains(place(x)));
          if (p != null) {
            // Ajouté par le foyer, maintenant au catalogue commun : il en fait partie.
            produitsPerso.remove(p.id);
            // 08/11/2026 : les marques du catalogue commun s'ajoutent aux déclinaisons du produit.
            for (final mq in (pj['marques'] as List? ?? const []).whereType<String>()) {
              if (mq.trim().isEmpty) continue;
              final m = marqueNommee(mq);
              if (!p.marqueIds.contains(m.id)) p.marqueIds.add(m.id);
            }
          } else {
            final id = 'pc-${Etat._cleNom(nom)}';
            p = Produit(plusieurs && Etat._trouve(produits, (x) => x.id == id) != null ? 'pc-${Etat._cleNom(sn)}-${Etat._cleNom(nom)}' : id, nom, [], [], 0);
            produits.add(p);
            parNom.putIfAbsent(bas(nom), () => p!);
            // 16/11/2026 : un format ou une marque répétés (« 1 kg » et « 1kg ») ne comptent qu'une fois.
            for (final f in (pj['formats'] as List? ?? const []).cast<String>()) {
              final k = _packagingNomme(f).id;
              if (!p.packagingIds.contains(k)) p.packagingIds.add(k);
            }
            for (final mq in (pj['marques'] as List? ?? const []).cast<String>()) {
              final m = marqueNommee(mq).id;
              if (!p.marqueIds.contains(m)) p.marqueIds.add(m);
            }
            lignes.add('$sn : $nom');
          }
          pris.add(p.id);
          // Rangé là où le catalogue commun le met, sauf si le foyer l'a rangé ailleurs ([deplacesFoyer]).
          final ici = secteurCatalogue(p.id);
          if (ici == null || (!estAjoute(p) && !deplacesFoyer.contains(p.id) && ici.id != secteurRef.id)) placer(ref.magasinId, p.id, secteurRef.id);
        }
      }
    }
    for (final e in (j['images'] as Map? ?? const {}).entries) {
      imagesChoisies.putIfAbsent(e.key as String, () => e.value as String);
    }
    // Images ajoutées par l'éditeur : la bibliothèque reçue remplace la précédente (vide si elle n'en a pas).
    remplacerImagesPerso(lireImagesPerso(j['imagesPerso']));
    stockageFoyer?.definirReglage('images_perso', jsonEncode(j['imagesPerso'] ?? const {}));
    // Univers (domaines) : ceux du catalogue s'il en porte, sinon on garde ceux qu'on a.
    if (lireUnivers(j['univers']) case final u?) {
      remplacerUnivers(u);
      stockageFoyer?.definirReglage('univers_catalogue', jsonEncode(j['univers']));
    }

    // 3. Retirés par l'éditeur, s'ils ne servent pas au foyer.
    var retires = 0;
    for (final o in (j['retires'] as List? ?? const []).cast<Map>()) {
      final nom = o['nom'] as String;
      switch (o['type']) {
        case 'produit':
          final p = produitDuSecteur(nom, o['secteur']);
          // Ajouté par un foyer ou non : l'éditeur corrige pour tous ; seul ce qui sert à une liste reste.
          if (p == null || produitUtilise(p)) continue;
          produits.remove(p);
          produitsPerso.remove(p.id);
          emplacements.removeWhere((e) => e.produitId == p.id);
          indexer();
          retires++;
        case 'secteur':
          final ids = {
            for (final x in secteurs)
              if (x.nom == nom && rayon(x.rayonId)?.nom == o['rayon']) x.id
          };
          if (ids.isEmpty || emplacements.any((e) => ids.contains(e.secteurId))) continue;
          secteurs.removeWhere((x) => ids.contains(x.id));
          structurePerso.remove('${o['rayon']}/$nom');
          structureRecue.remove('${o['rayon']}/$nom');
          for (final pc in parcours) {
            pc.etapes.removeWhere(ids.contains);
          }
          retires++;
        case 'rayon':
          final ids = {for (final r in rayons) if (r.nom == nom) r.id};
          if (ids.isEmpty || secteurs.any((x) => ids.contains(x.rayonId))) continue;
          rayons.removeWhere((r) => ids.contains(r.id));
          structurePerso.remove(nom);
          structureRecue.remove(nom);
          retires++;
      }
    }
    if (renommes > 0) lignes.add('$renommes nom${renommes > 1 ? 's' : ''} corrigé${renommes > 1 ? 's' : ''}');
    if (retires > 0) lignes.add('$retires élément${retires > 1 ? 's' : ''} retiré${retires > 1 ? 's' : ''} du catalogue');
    versionCatalogueCommun = version;
    numeroCatalogueCommun = (j['numero'] as num? ?? 0).toInt();
    nomVersionCatalogueCommun = j['libelle'] as String? ?? '';
    {
      // 06/11/2026 (Aristide) : pas la liste des modifications, le total de chaque élément du catalogue reçu.
      final rj = (j['rayons'] as List).cast<Map>();
      final sj = [for (final r in rj) ...(r['secteurs'] as List).cast<Map>()];
      final np = sj.fold(0, (n, x) => n + (x['produits'] as List).length);
      final n = lignes.length;
      final resume = [
        '${rj.length} rayons, ${sj.length} secteurs, $np produits',
        if (n > 0) '$n modification${n > 1 ? 's' : ''} sur $np produits',
      ];
      nouveautesCatalogue = {'version': version, 'date': j['date'], 'lignes': resume, 'total': resume.length};
    }
    modifie();
    return lignes;
  }

  // ------------------------------------------------------------ Catalogue ouvert à tous les foyers (30/10/2026)
  //
  // Un seul catalogue, enrichi par tous : chaque foyer dépose sur le serveur ce qu'il a ajouté (rayons,
  // secteurs, produits rangés avec leur marque et leur format, marques des secteurs), et chaque application
  // ajoute ce que les autres ont déposé. Rien n'est retiré : renommer ou déplacer un article crée un
  // nouveau produit, l'ancien reste. Un foyer isolé garde ce qu'il reçoit, sans le montrer.

  /// Produit reçu d'un autre foyer.
  bool estRecu(Produit p) => produitsPerso[p.id] == 'e';

  bool produitVisible(Produit p) => !masques.contains(p.id) && (!catalogueIsole || !estRecu(p));

  /// Produits proposés à la recherche : ni ceux reçus d'autres foyers, ni ceux que le foyer a masqués.
  List<Produit> get produitsVisibles => [for (final p in produits) if (produitVisible(p)) p];

  /// Masque chez le foyer un produit du catalogue commun (ou le remontre).
  void masquer(Produit p, bool oui) {
    if (oui ? masques.add(p.id) : masques.remove(p.id)) modifie();
  }

  /// Produits masqués par le foyer, par ordre alphabétique.
  List<Produit> get produitsMasques => [for (final p in produits) if (masques.contains(p.id)) p]..sort((a, b) => a.nom.compareTo(b.nom));

  /// Le foyer range ailleurs un produit du catalogue commun : retenu pour les prochaines versions du commun.
  void retenirDeplacement(Produit p) {
    if (!estAjoute(p) && deplacesFoyer.add(p.id)) modifie();
  }

  bool rayonVisible(Rayon r) => !catalogueIsole || !structureRecue.contains(r.nom);
  bool secteurVisible(Secteur s) => !catalogueIsole || !structureRecue.contains(cleSecteur(s));

  /// Rayons et secteurs du catalogue montrés au foyer.
  List<Rayon> get rayonsVisibles => _selonCatalogue([for (final r in rayonsCatalogue) if (rayonVisible(r)) r], (r) => 'r:${r.nom}');
  List<Secteur> secteursVisibles(String rayonId) =>
      _selonCatalogue([for (final s in secteursDu(rayonId)) if (secteurVisible(s)) s], (s) => 's:${rayon(s.rayonId)?.nom}/${s.nom}');
  List<T> _selonCatalogue<T>(List<T> l, String Function(T) cle) {
    if (rangCatalogue.isEmpty) return l;
    final initial = {for (var i = 0; i < l.length; i++) l[i]: i};
    return l..sort((a, b) => (rangCatalogue[cle(a)] ?? 100000 + initial[a]!).compareTo(rangCatalogue[cle(b)] ?? 100000 + initial[b]!));
  }

  /// Numéro court sous lequel l'éditeur voit le catalogue proposé par ce foyer (« AB12 »).
  String get numeroProposition => idApports == null ? '…' : idApports!.substring(0, 4).toUpperCase();

  /// Identifiant des apports du foyer (tiré au premier dépôt).
  String identifiantApports() {
    if (idApports == null) {
      final r = Random();
      idApports = List.generate(12, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)]).join();
      modifie();
    }
    return idApports!;
  }

  /// Ce que le foyer a ajouté au catalogue, à déposer pour les autres foyers (trié : deux appels sur les
  /// mêmes données rendent le même texte).
  Map<String, dynamic> apports() {
    bool exclu(String c) {
      final i = c.indexOf('/');
      return i < 0 ? Etat.estExclu(exclusCommun, rayon: c) : Etat.estExclu(exclusCommun, rayon: c.substring(0, i), secteur: c.substring(i + 1));
    }

    // Preuve d'usage (31/10/2026) : seul part ce qui a été acheté (coché dans des courses terminées).
    final achetes = <String>{}, marquesAchetees = <String>{};
    for (final l in listes) {
      if (l.statut != StatutListe.terminee) continue;
      for (final g in l.lignes) {
        if (!g.coche) continue;
        achetes.add(g.produitId);
        if (marque(g.marqueId)?.nom case final m?) marquesAchetees.add(m.toLowerCase());
      }
    }
    final prods = <Map<String, dynamic>>[];
    final structureUtile = <String>{};
    for (final p in produitsAjoutes) {
      if (!achetes.contains(p.id) || Moderation.nomRefuse(p.nom) != null) continue;
      final s = secteurCatalogue(p.id);
      final r = s == null ? null : rayon(s.rayonId);
      if (s == null || r == null) continue; // un non placé reste dans le foyer
      if (Etat.estExclu(exclusCommun, rayon: r.nom, secteur: s.nom, produit: p.nom)) continue;
      if (Moderation.nomRefuse(r.nom) != null || Moderation.nomRefuse(s.nom) != null) continue;
      if (prods.length >= Moderation.plafondProduits) break;
      structureUtile..add(r.nom)..add('${r.nom}/${s.nom}');
      for (final m in p.marqueIds) {
        if (marque(m)?.nom case final n?) marquesAchetees.add(n.toLowerCase());
      }
      final mq0 = p.marqueIds.isEmpty ? null : marque(p.marqueIds.first)?.nom;
      final mq = mq0 != null && Moderation.nomRefuse(mq0, marque: true) == null ? mq0 : null;
      final formats = [for (final id in p.packagingIds) if (packaging(id)?.libelle case final l?) l];
      prods.add({
        'nom': p.nom,
        'rayon': r.nom,
        'secteur': s.nom,
        if (mq != null) 'marque': mq,
        if (formats.isNotEmpty) 'formats': formats.take(2).toList(),
      });
    }
    prods.sort((a, b) => '${a['rayon']}/${a['secteur']}/${a['nom']}'.compareTo('${b['rayon']}/${b['secteur']}/${b['nom']}'));
    // Rayons et secteurs créés par le foyer : seulement s'ils rangent un produit qui part.
    final rayonsA = [for (final c in structurePerso) if (!c.contains('/') && !exclu(c) && structureUtile.contains(c)) c]..sort();
    final secteursA = [for (final c in structurePerso) if (c.contains('/') && !exclu(c) && structureUtile.contains(c)) c]..sort();
    final mqs = <String, List<String>>{};
    for (final e in (marquesSecteurs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
      final l = [
        for (final m in e.value['+'] ?? const <String>[])
          if (marquesAchetees.contains(m.toLowerCase()) && Moderation.nomRefuse(m, marque: true) == null) m
      ]..sort();
      if (l.isNotEmpty) mqs[e.key] = l;
    }
    return {
      'rayons': rayonsA,
      'secteurs': secteursA,
      'produits': prods,
      'marques': mqs,
      if (signalements.isNotEmpty) 'signales': signalements.toList()..sort(),
    };
  }

  /// Ajoute au foyer ce que les autres foyers ont déposé, après les règles contre les mauvais usages
  /// (Moderation) ; rend le nombre d'éléments ajoutés. Un produit reçu qui n'est plus proposé (foyer bloqué
  /// ou écarté, produit signalé, retiré par son foyer) disparaît, sauf s'il sert à une liste.
  int appliquerApports(Iterable<Map<String, dynamic>> recus) {
    if (magasins.isEmpty) return 0;
    final f = Moderation.filtrer(recus, bloques: foyersBloques, signales: signalements);
    foyersEcartes = f.ecartes;
    var n = 0;
    String bas(String t) => Moderation.normaliser(t);
    Rayon rayonNomme(String rn) {
      final ref = Etat._trouve(rayonsCatalogue, (r) => bas(r.nom) == bas(rn));
      if (ref != null) return ref;
      if (Etat._trouve(rayons, (r) => r.nom == rn) == null) rayons.add(Rayon(_idRayon(rn), magasinCommun, rn));
      structureRecue.add(rn);
      n++;
      return Etat._trouve(rayonsCatalogue, (r) => r.nom == rn)!;
    }

    Secteur secteurNomme(Rayon ref, String sn) {
      final s = Etat._trouve(secteursDu(ref.id), (x) => bas(x.nom) == bas(sn));
      if (s != null) return s;
      secteurs.add(Secteur(_idSecteur(ref.nom, sn), ref.id, sn));
      structureRecue.add('${ref.nom}/$sn');
      n++;
      return Etat._trouve(secteursDu(ref.id), (x) => x.nom == sn)!;
    }

    final gardes = <String>{};
    for (final j in f.lots) {
      for (final rn in (j['rayons'] as List? ?? const []).cast<String>()) {
        if (rn.trim().isNotEmpty && !Etat.estExclu(exclusCommun, rayon: rn)) rayonNomme(rn);
      }
      for (final c in (j['secteurs'] as List? ?? const []).cast<String>()) {
        final i = c.indexOf('/');
        if (i <= 0 || i >= c.length - 1) continue;
        final rn = c.substring(0, i), sn = c.substring(i + 1);
        if (!Etat.estExclu(exclusCommun, rayon: rn, secteur: sn)) secteurNomme(rayonNomme(rn), sn);
      }
      for (final pj in (j['produits'] as List? ?? const []).cast<Map>()) {
        final nom = pj['nom'] as String?, rn = pj['rayon'] as String?, sn = pj['secteur'] as String?;
        if (nom == null || rn == null || sn == null || nom.trim().isEmpty) continue;
        if (Etat.estExclu(exclusCommun, rayon: rn, secteur: sn, produit: nom)) continue;
        final s = secteurNomme(rayonNomme(rn), sn);
        final id = 'pe-${Etat._cleNom(rn)}-${Etat._cleNom(sn)}-${Etat._cleNom(nom)}';
        // Doublons : même nom au pluriel, aux accents ou aux majuscules près ; à une lettre près, mis de côté.
        final autres = [for (final p in _tousDuSecteur(s)) if (p.id != id) p];
        if (autres.any((p) => bas(p.nom) == bas(nom) || Moderation.presque(p.nom, nom))) continue;
        gardes.add(id);
        var p = produit(id);
        if (p == null) {
          p = Produit(id, nom.trim(), [], [], 0);
          if (pj['marque'] case final String mq when mq.trim().isNotEmpty) p.marqueIds.add(marqueNommee(mq).id);
          for (final f in (pj['formats'] as List? ?? const []).cast<String>()) {
            p.packagingIds.add(_packagingNomme(f).id);
          }
          produits.add(p);
          produitsPerso[id] = 'e';
          n++;
        }
        placer('', p.id, s.id);
      }
      for (final e in (j['marques'] as Map? ?? const {}).entries) {
        final l = marquesRecues.putIfAbsent(e.key as String, () => []);
        for (final mq in (e.value as List).cast<String>()) {
          if (!l.any((x) => bas(x) == bas(mq))) {
            l.add(mq);
            n++;
          }
        }
      }
    }
    // Ce qui n'est plus proposé disparaît, sauf ce qui sert à une liste.
    var retires = 0;
    for (final p in [...produits]) {
      if (produitsPerso[p.id] != 'e' || gardes.contains(p.id) || produitUtilise(p)) continue;
      produits.remove(p);
      produitsPerso.remove(p.id);
      emplacements.removeWhere((e) => e.produitId == p.id);
      retires++;
    }
    if (n > 0 || retires > 0) modifie();
    return n;
  }

  /// Signale un produit reçu d'un autre foyer (nom fantaisiste, grossier, faux…) : il disparaît de ce foyer
  /// (sauf s'il sert à une liste), et chaque signalement compte chez les autres foyers.
  void signalerProduit(Produit p) {
    final s = secteurCatalogue(p.id);
    signalements.add(Moderation.cleProduit(s?.nom ?? '', p.nom));
    if (estRecu(p) && !produitUtilise(p)) {
      produits.remove(p);
      produitsPerso.remove(p.id);
      emplacements.removeWhere((e) => e.produitId == p.id);
    }
    modifie();
  }

  /// Renomme ou range autrement un article de la liste : un nouveau produit est créé dans le secteur choisi
  /// (ou repris s'il y existe déjà sous ce nom) ; la ligne le prend, l'ancien produit reste au catalogue.
  /// Rend l'article de la ligne.
  Produit remplacerArticle(Liste l, Produit p, String nom, Secteur? secteur) {
    final n = nom.trim();
    final g = ligne(l, p.id);
    if (n.isEmpty || g == null) return p;
    final avant = secteurCatalogue(p.id);
    if (n == p.nom && avant?.id == secteur?.id) return p;
    var q = Etat._trouve(produits,
        (x) => x.id != p.id && x.nom.toLowerCase() == n.toLowerCase() && secteurCatalogue(x.id)?.id == secteur?.id);
    if (q == null) {
      q = Produit(nouvelId('p'), n, [...p.marqueIds], [...p.packagingIds], 0);
      produits.add(q);
      _marquerAjoute(q);
      if (secteur != null) placer(rayon(secteur.rayonId)?.magasinId ?? '', q.id, secteur.id);
    }
    final i = l.lignes.indexOf(g);
    if (ligne(l, q.id) != null) {
      l.lignes.removeAt(i);
    } else {
      q.nbUtilisations++;
      l.lignes[i] = LigneListe(
          produitId: q.id,
          marqueId: g.marqueId,
          packagingId: g.packagingId,
          quantite: g.quantite,
          promotion: g.promotion,
          consigne: g.consigne);
    }
    _toucheConstruction(l);
    modifie();
    return q;
  }

  // ------------------------------------------------------------ Rayons et secteurs ajoutés (26/10/2026)

  bool rayonAjoute(Rayon r) => structurePerso.contains(r.nom);
  bool secteurAjoute(Secteur s) => structurePerso.contains('${rayon(s.rayonId)?.nom}/${s.nom}');

  /// Nouveau rayon, dans tous les magasins, avec un premier secteur du même nom.
  Rayon? ajouterRayonCatalogue(String nom, {String? univers}) {
    final n = nom.trim();
    if (n.isEmpty || magasins.isEmpty) return null;
    if (Etat._trouve(rayonsCatalogue, (r) => r.nom.toLowerCase() == n.toLowerCase()) != null) return null;
    ajouterSecteur(ajouterRayon(magasinCommun, n).id, n);
    structurePerso
      ..add(n)
      ..add('$n/$n');
    if (univers != null) universRayons[n] = univers;
    modifie();
    return Etat._trouve(rayonsCatalogue, (r) => r.nom == n);
  }

  /// Nouveau secteur dans le rayon [r], dans tous les magasins.
  Secteur? ajouterSecteurCatalogue(Rayon r, String nom) {
    final n = nom.trim();
    if (n.isEmpty) return null;
    if (Etat._trouve(secteursDu(r.id), (s) => s.nom.toLowerCase() == n.toLowerCase()) != null) return null;
    ajouterSecteur(r.id, n);
    structurePerso.add('${r.nom}/$n');
    modifie();
    return Etat._trouve(secteursDu(r.id), (s) => s.nom == n);
  }

  /// Nouvel ordre des secteurs du rayon [r] (par leurs noms), dans tous les magasins.
  void ordonnerSecteursCatalogue(Rayon r, List<String> noms) {
    final rang = {for (var i = 0; i < noms.length; i++) noms[i]: i};
    for (final rid in {for (final x in rayons) if (x.nom == r.nom) x.id}) {
      // Les secteurs de ce rayon reprennent leurs places dans la liste, dans le nouvel ordre.
      final places = [for (var i = 0; i < secteurs.length; i++) if (secteurs[i].rayonId == rid) i];
      final cle = {for (var k = 0; k < places.length; k++) secteurs[places[k]]: rang[secteurs[places[k]].nom] ?? noms.length + k};
      final tries = [for (final i in places) secteurs[i]]..sort((a, b) => cle[a]!.compareTo(cle[b]!));
      for (var k = 0; k < places.length; k++) {
        secteurs[places[k]] = tries[k];
      }
    }
    modifie();
  }

  /// Renomme un rayon dans tous les magasins (02/11/2026 : aussi ceux d'origine, dont le nom d'origine est gardé).
  void renommerRayonCatalogue(Rayon r, String nom) {
    final n = nom.trim(), ancien = r.nom;
    if (n.isEmpty || n == ancien || Etat._trouve(rayons, (x) => x.nom == n) != null) return;
    if (!rayonAjoute(r)) {
      final origine = origineRayon(ancien);
      renommages.remove('r:$ancien');
      if (n != origine) renommages['r:$n'] = origine;
    }
    for (final x in rayons.where((x) => x.nom == ancien)) {
      x.nom = n;
    }
    structurePerso = {for (final c in structurePerso) c == ancien ? n : (c.startsWith('$ancien/') ? '$n/${c.substring(ancien.length + 1)}' : c)};
    if (universRayons.remove(ancien) case final u?) universRayons[n] = u;
    ordreRayons = [for (final x in ordreRayons) x == ancien ? n : x];
    modifie();
  }

  /// Renomme un univers (seulement le nom affiché).
  void renommerUnivers(String origine, String nom) {
    final n = nom.trim();
    if (n.isEmpty || n == origine) {
      nomsUnivers.remove(origine);
    } else {
      nomsUnivers[origine] = n;
    }
    modifie();
  }

  /// Range un rayon ajouté par le foyer dans un univers.
  void changerUniversRayon(Rayon r, String univers) {
    universRayons[r.nom] = univers;
    modifie();
  }

  /// Univers et ordre des rayons du catalogue, après les avoir fait glisser (univers → noms des rayons).
  void rangerRayons(Map<String, List<String>> parUnivers) {
    ordreRayons = [for (final l in parUnivers.values) ...l];
    for (final MapEntry(key: u, value: l) in parUnivers.entries) {
      for (final n in l) {
        universRayons[n] = u;
      }
    }
    modifie();
  }

  /// Renomme un secteur dans tous les magasins (02/11/2026 : aussi ceux d'origine, dont le nom d'origine est gardé).
  void renommerSecteurCatalogue(Secteur s, String nom) {
    final n = nom.trim(), ancien = s.nom, rn = rayon(s.rayonId)?.nom ?? '';
    if (n.isEmpty || n == ancien || Etat._trouve(secteurs, (x) => x.rayonId == s.rayonId && x.nom == n) != null) return;
    final ajoute = secteurAjoute(s);
    if (!ajoute) {
      final ro = origineRayon(rn), origine = origineSecteur(rn, ancien);
      renommages.remove('s:$ro/$ancien');
      if (n != origine) renommages['s:$ro/$n'] = origine;
    }
    for (final x in secteurs.where((x) => x.nom == ancien && rayon(x.rayonId)?.nom == rn)) {
      x.nom = n;
    }
    if (ajoute) {
      structurePerso
        ..remove('$rn/$ancien')
        ..add('$rn/$n');
    }
    modifie();
  }

  /// Un secteur ajouté et vide se supprime (dans tous les magasins) ; rend faux s'il a des produits.
  bool supprimerSecteurCatalogue(Secteur s) {
    if (!secteurAjoute(s) || _tousDuSecteur(s).isNotEmpty) return false;
    final rn = rayon(s.rayonId)?.nom ?? '';
    final ids = {for (final x in secteurs) if (x.nom == s.nom && rayon(x.rayonId)?.nom == rn) x.id};
    secteurs.removeWhere((x) => ids.contains(x.id));
    for (final p in parcours) {
      p.etapes.removeWhere(ids.contains);
    }
    structurePerso.remove('$rn/${s.nom}');
    modifie();
    return true;
  }

  /// Un rayon ajouté se supprime quand ses secteurs sont vides.
  bool supprimerRayonCatalogue(Rayon r) {
    if (!rayonAjoute(r) || secteursDu(r.id).any((s) => _tousDuSecteur(s).isNotEmpty)) return false;
    final ids = {for (final x in rayons) if (x.nom == r.nom) x.id};
    final sids = {for (final x in secteurs) if (ids.contains(x.rayonId)) x.id};
    secteurs.removeWhere((x) => sids.contains(x.id));
    rayons.removeWhere((x) => ids.contains(x.id));
    for (final p in parcours) {
      p.etapes.removeWhere(sids.contains);
    }
    structurePerso.removeWhere((c) => c == r.nom || c.startsWith('${r.nom}/'));
    modifie();
    return true;
  }

  void options({bool? parSecteurs, bool? envoiFoyer, bool? ajoutParRecherche, String? modePreparation}) {
    if (parSecteurs != null) this.parSecteurs = parSecteurs;
    if (envoiFoyer != null) this.envoiFoyer = envoiFoyer;
    if (ajoutParRecherche != null) this.ajoutParRecherche = ajoutParRecherche;
    if (modePreparation != null) this.modePreparation = modePreparation;
    modifie();
  }

  Packaging _packagingNomme(String libelle) {
    var k = Etat._trouve(packagings, (k) => k.libelle.toLowerCase() == libelle.toLowerCase());
    if (k == null) {
      k = Packaging(nouvelId('k'), libelle);
      packagings.add(k);
    }
    return k;
  }

  /// Mise à jour : donne aux produits sans packaging les formats de vente du catalogue,
  /// et fait de tous ces formats les types de packaging (Paramètres), rangés par nature.
  Future<void> appliquerFormats({Map<String, dynamic>? catalogue, bool typesSeulement = false}) async {
    if (formatsAppliques) return;
    try {
      catalogue ??= await CatalogueType.lireJson();
    } catch (e) {
      noter('Formats du catalogue non appliqués (catalogue illisible), nouvel essai au prochain lancement : $e');
      return;
    }
    final parNom = <String, List<String>>{};
    final tous = <String>{};
    for (final r in (catalogue['rayons'] as List).cast<Map>()) {
      for (final s in (r['secteurs'] as List).cast<Map>()) {
        for (final p in (s['produits'] as List).cast<Map>()) {
          final f = (p['formats'] as List? ?? const []).cast<String>();
          parNom[(p['nom'] as String).toLowerCase()] = f;
          tous.addAll(f);
        }
      }
    }
    if (tous.isEmpty) return;
    for (final p in typesSeulement ? const <Produit>[] : produits) {
      if (p.packagingIds.isNotEmpty) continue;
      for (final f in parNom[p.nom.toLowerCase()] ?? const <String>[]) {
        p.packagingIds.add(_packagingNomme(f).id);
      }
    }
    for (final f in tous) {
      final k = _packagingNomme(f);
      if (!typesPackaging.contains(k.id)) typesPackaging.add(k.id);
    }
    // Types de départ (pack de 6 à 2) qu'aucun article n'utilise : retirés
    typesPackaging.removeWhere((id) =>
        RegExp(r'^pack de [2-6]$', caseSensitive: false).hasMatch(packaging(id)?.libelle ?? '') && nbProduitsAvecPackaging(id) == 0);
    trierTypesPackaging();
    formatsAppliques = true;
    modifie();
  }

  /// Types de mesure vides alors que les formats ont été appliqués : on les reprend du catalogue, sans toucher aux articles.
  Future<void> reparerTypesMesure({Map<String, dynamic>? catalogue}) async {
    if (typesMesure.isNotEmpty || !formatsAppliques) return;
    formatsAppliques = false;
    await appliquerFormats(catalogue: catalogue, typesSeulement: true);
    formatsAppliques = true;
  }

  /// Range les types : vente à l'unité, poids, volumes, lots, packs ; puis par quantité.
  void trierTypesPackaging() {
    (int, double) rang(String id) {
      final l = (packaging(id)?.libelle ?? '').toLowerCase();
      final n = double.tryParse(RegExp(r'\d+(?:,\d+)?').firstMatch(l)?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
      if (n == 0) return (0, 0);
      if (RegExp(r'\d\s*k?g\b').hasMatch(l)) return (1, l.contains('kg') ? n * 1000 : n);
      if (RegExp(r'\d\s*(c|m)?l\b').hasMatch(l)) return (2, l.contains('cl') ? n * 10 : (l.contains('ml') ? n : n * 1000));
      if (l.startsWith('pack')) return (4, n);
      return (3, n);
    }

    typesPackaging.sort((a, b) {
      final (ga, na) = rang(a);
      final (gb, nb) = rang(b);
      return ga != gb ? ga.compareTo(gb) : na.compareTo(nb);
    });
  }

  /// Nombre de produits qui proposent ce packaging.
  int nbProduitsAvecPackaging(String id) => produits.where((p) => p.packagingIds.contains(id)).length;

  List<Produit> produitsAvecPackaging(String id) => produits.where((p) => p.packagingIds.contains(id)).toList()
    ..sort((a, b) => a.nom.compareTo(b.nom));

  /// Corrige le libellé d'un format : tous les produits qui l'utilisent sont corrigés d'un coup.
  /// Si le nouveau libellé existe déjà, les deux formats sont fusionnés.
  void renommerMagasin(Magasin m, String nom) {
    if (nom.trim().isEmpty) return;
    m.nom = nom.trim();
    modifie();
  }
}
