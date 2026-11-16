part of '../modele.dart';

// Méthodes de l'état (EtatMarques), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatMarques on Etat {

  Future<void> chargerMarquesType() async {
    try {
      lireMarquesType(jsonDecode(await rootBundle.loadString(Etat.fichierMarques)) as Map<String, dynamic>);
      lireMarquesDistributeur(jsonDecode(await rootBundle.loadString(Etat.fichierMarquesDistributeur)) as Map<String, dynamic>);
      lireNaturesOff(jsonDecode(await rootBundle.loadString(Etat.fichierNaturesOff)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Catalogue des marques illisible : $e');
    }
  }

  void lireNaturesOff(Map<String, dynamic> j) {
    naturesOff = {
      for (final e in (j['natures'] as Map).entries)
        (e.key as String).toLowerCase(): (n: ((e.value as Map)['n'] as num).toInt(), marques: _ids((e.value as Map)['m']))
    };
    naturesParMarque = {};
    for (final e in naturesOff.entries) {
      for (final m in e.value.marques) {
        naturesParMarque.putIfAbsent(m.toLowerCase(), () => []).add(e.key);
      }
    }
  }

  /// Nombre de produits de cette nature vendus en France (0 : inconnu).
  int popularite(Produit p) => naturesOff[p.nom.toLowerCase()]?.n ?? 0;

  void lireMarquesDistributeur(Map<String, dynamic> j) {
    marquesDistributeur = {
      for (final e in (j['enseignes'] as Map).entries)
        e.key as String: [
          for (final m in (e.value as List).cast<Map>())
            MarqueDistributeur(m['marque'] as String, m['categorie'] as String? ?? '', _ids(m['cibles']))
        ]
    };
  }

  /// Enseignes qui ont des marques distributeur.
  List<String> get enseignesMdd => marquesDistributeur.keys.toList();

  /// Enseigne d'un magasin pour ses marques distributeur : celle choisie, sinon reconnue dans son nom.
  String? enseigneDe(Magasin? m) {
    if (m == null || m.enseigne == '-') return null; // « Aucune » choisie
    if (marquesDistributeur.containsKey(m.enseigne)) return m.enseigne;
    final t = ' ${m.enseigne} ${m.nom} '.toLowerCase();
    for (final e in Etat._motsEnseignes.entries) {
      if (e.value.any(t.contains)) return e.key;
    }
    return null;
  }

  /// Crée, une fois, un magasin pour chaque enseigne à marques distributeur qui n'en a pas encore.
  Future<void> ajouterMagasinsEnseignes() async {
    if (magasinsEnseignes || marquesDistributeur.isEmpty || magasins.isEmpty) return;
    magasinsEnseignes = true;
    final presentes = {for (final m in magasins) enseigneDe(m)};
    for (final e in enseignesMdd) {
      if (presentes.contains(e) || magasinNomme(e) != null) continue;
      final m = creerMagasin(e);
      m.enseigne = e;
      await remplirMagasin(m);
    }
    modifie();
  }

  void definirEnseigne(Magasin m, String enseigne) {
    m.enseigne = enseigne;
    modifie();
  }

  /// Marques distributeur de l'enseigne du magasin pour un article du secteur [s].
  List<String> marquesDistributeurPour(Magasin? m, Secteur? s) {
    final liste = marquesDistributeur[enseigneDe(m)] ?? const <MarqueDistributeur>[];
    final rayonNom = s == null ? null : rayon(s.rayonId)?.nom;
    final cle = s == null ? null : cleSecteur(s);
    return [
      for (final x in liste)
        if (x.cibles.any((c) => c == '*' || c == rayonNom || c == cle)) x.marque
    ];
  }

  /// « Version 7 », ou « Version d'origine » pour le catalogue livré avec l'application (Gérer, 06/11/2026).
  String libelleVersion(int n) => n > 0 ? 'Version $n' : 'Version d\'origine';

  void lireMarquesType(Map<String, dynamic> j) {
    marquesType = {for (final e in (j['secteurs'] as Map).entries) e.key as String: _ids(e.value)};
  }

  String cleSecteur(Secteur s) {
    final rn = rayon(s.rayonId)?.nom ?? '';
    return '${origineRayon(rn)}/${origineSecteur(rn, s.nom)}';
  }

  /// Nombre de marques connues (catalogue des marques, ajouts du foyer, marques des produits), pour Gérer.
  int get nbMarquesConnues => {
        for (final l in marquesType.values) ...l.map((n) => n.toLowerCase()),
        for (final m in marquesSecteurs.values) ...(m['+'] ?? const <String>[]).map((n) => n.toLowerCase()),
        for (final m in marques) m.nom.toLowerCase(),
      }.length;

  /// Marques d'un secteur : celles du catalogue des marques, celles ajoutées par le foyer et celles des
  /// produits du secteur, sans celles que le foyer a retirées ; par ordre alphabétique.
  List<String> marquesDuSecteur(Secteur s) {
    final cle = cleSecteur(s);
    final perso = marquesSecteurs[cle] ?? const {};
    final retirees = {for (final n in perso['-'] ?? const <String>[]) n.toLowerCase()};
    final vues = <String>{};
    final res = <String>[];
    void ajoute(String n) {
      if (retirees.contains(n.toLowerCase()) || !vues.add(n.toLowerCase())) return;
      res.add(n);
    }
    for (final n in marquesType[cle] ?? const <String>[]) {
      ajoute(n);
    }
    for (final n in perso['+'] ?? const <String>[]) {
      ajoute(n);
    }
    if (!catalogueIsole) {
      for (final n in marquesRecues[cle] ?? const <String>[]) {
        ajoute(n);
      }
    }
    for (final p in produitsDuSecteur(s)) {
      for (final id in p.marqueIds) {
        if (marque(id)?.nom case final n?) ajoute(n);
      }
    }
    return res..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void ajouterMarqueSecteur(Secteur s, String nom) {
    final n = nom.trim();
    if (n.isEmpty) return;
    final perso = marquesSecteurs.putIfAbsent(cleSecteur(s), () => {});
    perso['-']?.removeWhere((x) => x.toLowerCase() == n.toLowerCase());
    if (!marquesDuSecteur(s).any((x) => x.toLowerCase() == n.toLowerCase())) (perso['+'] ??= []).add(n);
    modifie();
  }

  void retirerMarqueSecteur(Secteur s, String nom) {
    final perso = marquesSecteurs.putIfAbsent(cleSecteur(s), () => {});
    perso['+']?.removeWhere((x) => x.toLowerCase() == nom.toLowerCase());
    if (!(perso['-'] ?? []).any((x) => x.toLowerCase() == nom.toLowerCase())) (perso['-'] ??= []).add(nom);
    modifie();
  }

  /// Renomme une marque partout : dans les secteurs où elle figure, et ses produits (« Camembert Président »).
  void renommerMarqueCatalogue(String ancien, String nouveau) {
    final n = nouveau.trim();
    if (n.isEmpty || n == ancien) return;
    for (final s in [for (final r in rayonsCatalogue) ...secteursDu(r.id)]) {
      if (!marquesDuSecteur(s).any((x) => x.toLowerCase() == ancien.toLowerCase())) continue;
      retirerMarqueSecteur(s, ancien);
      ajouterMarqueSecteur(s, n);
    }
    if (Etat._trouve(marques, (m) => m.nom.toLowerCase() == ancien.toLowerCase()) case final m?) renommerMarque(m, n);
    modifie();
  }

  /// Marques, par ordre alphabétique.
  List<Marque> get marquesTriees => [...marques]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  List<Produit> produitsDeMarque(String marqueId) => [for (final p in produits) if (p.marqueIds.contains(marqueId)) p];

  /// Renomme une marque ; si le nouveau nom est déjà celui d'une autre marque, les deux n'en font plus qu'une.
  void renommerMarque(Marque m, String nom) {
    final n = nom.trim();
    if (n.isEmpty || n == m.nom) return;
    // Les produits de la marque portent son nom (« Camembert Président ») : ils sont renommés aussi.
    final ancien = RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(m.nom)}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);
    for (final p in produitsDeMarque(m.id)) {
      p.nom = p.nom.replaceAll(ancien, n);
    }
    final autre = Etat._trouve(marques, (x) => x.id != m.id && x.nom.toLowerCase() == n.toLowerCase());
    if (autre != null) {
      for (final p in produits) {
        if (p.marqueIds.remove(m.id) && !p.marqueIds.contains(autre.id)) p.marqueIds.add(autre.id);
      }
      for (final l in listes) {
        for (final g in l.lignes) {
          if (g.marqueId == m.id) g.marqueId = autre.id;
        }
      }
      marques.remove(m);
    } else {
      m.nom = n;
    }
    modifie();
  }

  /// Supprime une marque qu'aucun produit ne porte.
  bool supprimerMarque(Marque m) {
    if (produitsDeMarque(m.id).isNotEmpty || listes.any((l) => l.lignes.any((g) => g.marqueId == m.id))) return false;
    marques.remove(m);
    modifie();
    return true;
  }

  void renommerPackaging(String id, String libelle) {
    final k = packaging(id);
    if (k == null || libelle.trim().isEmpty) return;
    final autre = Etat._trouve(packagings, (x) => x.id != id && x.libelle.toLowerCase() == libelle.trim().toLowerCase());
    if (autre != null) {
      fusionnerPackaging(id, autre.id);
      return;
    }
    k.libelle = libelle.trim();
    modifie();
  }

  /// Remplace partout le format [source] par [cible] (produits, lignes de liste, types) puis l'oublie.
  void fusionnerPackaging(String source, String cible) {
    if (source == cible || packaging(cible) == null) return;
    for (final p in produits) {
      final i = p.packagingIds.indexOf(source);
      if (i < 0) continue;
      if (p.packagingIds.contains(cible)) {
        p.packagingIds.removeAt(i);
      } else {
        p.packagingIds[i] = cible;
      }
    }
    for (final l in listes) {
      for (final g in l.lignes) {
        if (g.packagingId == source) g.packagingId = cible;
      }
    }
    final t = typesPackaging.indexOf(source);
    if (t >= 0) {
      if (typesPackaging.contains(cible)) {
        typesPackaging.removeAt(t);
      } else {
        typesPackaging[t] = cible;
      }
    }
    couleurs.remove('pack:$source');
    if (!listes.any((l) => l.lignes.any((g) => g.packagingId == source))) packagings.removeWhere((k) => k.id == source);
    modifie();
  }

  /// Retire un format de la liste des types et de tous les produits (les listes déjà faites le gardent).
  void supprimerPackaging(String id) {
    for (final p in produits) {
      p.packagingIds.remove(id);
    }
    typesPackaging.remove(id);
    couleurs.remove('pack:$id');
    modifie();
  }

  /// Formats les plus courants des autres produits du même secteur (produit sans format connu).
  List<String> formatsDuSecteur(String magasinId, String produitId, {int max = 8}) {
    final s = secteurDe(magasinId, produitId);
    if (s == null) return [];
    final n = <String, int>{};
    for (final e in emplacements.where((e) => e.secteurId == s.id)) {
      for (final k in produit(e.produitId)?.packagingIds ?? const <String>[]) {
        n[k] = (n[k] ?? 0) + 1;
      }
    }
    final ids = n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
    return ids.take(max).toList();
  }

  void ajouterTypePackaging(String libelle) {
    final k = _packagingNomme(libelle);
    if (!typesPackaging.contains(k.id)) typesPackaging.add(k.id);
    modifie();
  }

  void retirerTypePackaging(String id) {
    typesPackaging.remove(id);
    modifie();
  }
  int get couleurPromotions => couleurs['promo'] ?? Etat.couleurPromoDefaut;
  int get couleurMesures => couleurs['mesure'] ?? Etat.couleurMesureDefaut;
  int get couleurLots => couleurs['lot'] ?? Etat.couleurLotDefaut;
  int? couleurPromo(String? typeId) => typeId == null ? null : couleurPromotions;
  int? couleurPack(String? packagingId) {
    final k = packaging(packagingId);
    if (k == null) return null;
    return Etat.mesureEtLot(k.libelle).$2 != null ? couleurLots : couleurMesures;
  }

  /// Types de mesure (poids, volume, à la pièce…) et types de packaging (lots), parmi les formats proposés.
  List<String> get typesMesure => [for (final id in typesPackaging) if (!Etat.estLot(packaging(id)?.libelle ?? '')) id];
  List<String> get typesLot => [for (final id in typesPackaging) if (Etat.estLot(packaging(id)?.libelle ?? '')) id];

  /// Les packagings sont surtout des lots de 2 à 10 : ceux qui manquent sont ajoutés une fois.
  void completerLots() {
    if (lotsCompletes) return;
    for (var n = 2; n <= 10; n++) {
      final existe = typesLot.any((id) => RegExp('\\b$n\\b').hasMatch(packaging(id)?.libelle ?? ''));
      if (!existe) ajouterTypePackaging('Lot de $n');
    }
    lotsCompletes = true;
    trierTypesPackaging();
    modifie();
  }

  void choisirCouleur(String cle, int? couleur) {
    if (couleur == null) {
      couleurs.remove(cle);
    } else {
      couleurs[cle] = couleur;
    }
    modifie();
  }

  void montrerIconesListes(bool oui) {
    iconesListes = oui;
    modifie();
  }

  void choisirDebordIcones(String d) {
    debordIcones = d;
    taillePictoListes = Etat.tailleDebord(d);
    modifie();
  }

  void choisirApparence(String nom) {
    apparence = nom;
    modifie();
  }

  void reglerDelaiArchives(int mois) {
    delaiArchives = mois;
    purgerArchives();
    modifie();
  }

  /// Courses des magasins archivés.
  List<Liste> listesArchivees(String magasinId) => listes.where((l) => l.magasinId == magasinId).toList()
    ..sort((a, b) => dateCourses(b).compareTo(dateCourses(a)));

  /// Supprime les archives plus anciennes que le délai réglé (rien si « jamais ») ; rend vrai si quelque chose est parti.
  bool purgerArchives() {
    if (delaiArchives <= 0) return false;
    final limite = DateTime.now().subtract(Duration(days: 30 * delaiArchives));
    final ids = {
      for (final m in magasinsArchives)
        for (final c in historique.where((c) => c.magasinId == m.id && c.dateCourses.isBefore(limite))) c.id,
      for (final c in historique.where((c) => archivees.contains(c.id) && c.dateCourses.isBefore(limite))) c.id,
    };
    if (ids.isEmpty) return false;
    archivees.removeAll(ids);
    listes.removeWhere((l) => ids.contains(l.id));
    historique.removeWhere((c) => ids.contains(c.id));
    for (final m in [...magasinsArchives]) {
      if (!historique.any((c) => c.magasinId == m.id) && !listes.any((l) => l.magasinId == m.id)) magasinsArchives.remove(m);
    }
    return true;
  }

  /// Un magasin supprimé qui a un historique part dans les archives ; ses listes non terminées sont effacées.
  bool aUnHistorique(Magasin m) =>
      historique.any((c) => c.magasinId == m.id) || listes.any((l) => l.magasinId == m.id && l.statut == StatutListe.terminee);

  void restaurerMagasin(Magasin m) {
    magasinsArchives.remove(m);
    if (!magasins.contains(m)) magasins.add(m);
    modifie();
  }

  /// Image choisie pour un rayon ou un secteur (clé : voir images_choisies.dart) ; null = image automatique.
  void choisirImage(String cle, String? picto) {
    if (picto == null) {
      imagesChoisies.remove(cle);
    } else {
      imagesChoisies[cle] = picto;
    }
    modifie();
  }
}
