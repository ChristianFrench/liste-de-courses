part of '../modele.dart';

// Méthodes de l'état (EtatListes), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatListes on Etat {

  Membre get moi => Etat._trouve(membres, (m) => m.moi) ?? membres.first;
  Membre? membre(String? id) => Etat._trouve(membres, (m) => m.id == id);
  Magasin? magasin(String? id) => Etat._trouve(magasins, (m) => m.id == id) ?? Etat._trouve(magasinsArchives, (m) => m.id == id);
  bool estArchive(String? magasinId) => magasinsArchives.any((m) => m.id == magasinId);
  Rayon? rayon(String? id) => id == null ? null : _indexRayons.trouver(_rayons, id);
  Secteur? secteur(String? id) => id == null ? null : _indexSecteurs.trouver(_secteurs, id);
  Marque? marque(String? id) => Etat._trouve(marques, (m) => m.id == id);
  Packaging? packaging(String? id) => Etat._trouve(packagings, (k) => k.id == id);
  Produit? produit(String? id) => id == null ? null : _indexProduits.trouver(_produits, id);
  Liste? liste(String? id) => Etat._trouve(listes, (l) => l.id == id);
  Parcours? unParcours(String? id) => Etat._trouve(parcours, (p) => p.id == id);
  TypePromotion? typePromotion(String? id) => Etat._trouve(typesPromotion, (t) => t.id == id);
  Course? course(String? id) => Etat._trouve(historique, (c) => c.id == id);
  Ticket? ticketDe(String courseId) => Etat._trouve(tickets, (t) => t.listeId == courseId);

  /// Rayons du catalogue : les mêmes pour tous les magasins ([magasinId] n'est gardé que pour les appels existants).
  List<Rayon> rayonsDu(String magasinId) => List.of(rayons);
  List<Secteur> secteursDu(String rayonId) => secteurs.where((s) => s.rayonId == rayonId).toList();
  List<Secteur> secteursDuMagasin(String magasinId) {
    final ids = rayonsDu(magasinId).map((r) => r.id).toSet();
    return secteurs.where((s) => ids.contains(s.rayonId)).toList();
  }

  /// Secteur où est rangé le produit, le même dans tous les magasins.
  Secteur? secteurDe(String magasinId, String produitId) {
    final e = _indexEmplacements.trouver(_emplacements, produitId);
    return e == null ? null : secteur(e.secteurId);
  }

  Rayon? rayonDe(String magasinId, String produitId) => rayon(secteurDe(magasinId, produitId)?.rayonId);

  List<Produit> produitsDu(String magasinId, String secteurId) => [
        for (final e in emplacements)
          if (e.secteurId == secteurId) produit(e.produitId)
      ].whereType<Produit>().toList();

  int nbProduitsRayon(String magasinId, String rayonId) =>
      secteursDu(rayonId).fold(0, (n, s) => n + produitsDu(magasinId, s.id).length);

  /// Complément affiché en gris : marque et packaging.
  String complement(LigneListe? g, Produit p, {bool marque = true, bool avecPackaging = true}) {
    final m = <String>[];
    final mq = this.marque(g?.marqueId);
    // Pas de répétition quand le nom du produit porte déjà la marque (« Poulet entier Carrefour Bio »).
    if (marque && mq != null && !p.nom.toLowerCase().contains(mq.nom.toLowerCase())) m.add(mq.nom);
    final k = packagingDe(g, p);
    if (avecPackaging && k != null) m.add(k.libelle.toLowerCase());
    return m.join(' · ');
  }

  /// Packaging de la ligne, ou le premier du produit.
  Packaging? packagingDe(LigneListe? g, Produit p) =>
      packaging(g?.packagingId) ?? (p.packagingIds.isNotEmpty ? packaging(p.packagingIds.first) : null);

  // ------------------------------------------------------------ Listes

  List<Liste> listesStatut(StatutListe s) => listes.where((l) => l.statut == s).toList();
  Liste? get coursesEnCours => Etat._trouve(listes, (l) => l.statut == StatutListe.enCours);
  Liste? get preparationInterrompue =>
      Etat._trouve(listes, (l) => l.statut == StatutListe.enConstruction && l.interrompueLe != null);

  /// L'écran de reprise s'affiche au lancement si des courses sont en cours ou une préparation interrompue.
  bool get repriseAuLancement => coursesEnCours != null || preparationInterrompue != null;

  LigneListe? ligne(Liste l, String produitId) => Etat._trouve(l.lignes, (g) => g.produitId == produitId);

  void _toucheConstruction(Liste l) {
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    if (l.statut == StatutListe.enConstruction) l.interrompueLe = DateTime.now();
  }

  void basculer(Liste l, String produitId) {
    final g = ligne(l, produitId);
    if (g == null) {
      final p = produit(produitId);
      p?.nbUtilisations++; // entrée dans une liste (règle R4)
      l.lignes.add(LigneListe(
        produitId: produitId,
        packagingId: (p != null && p.packagingIds.isNotEmpty) ? p.packagingIds.first : null,
      ));
    } else {
      l.lignes.remove(g);
    }
    _toucheConstruction(l);
    modifie();
  }

  void ajouterLigne(Liste l, String produitId) {
    if (ligne(l, produitId) == null) basculer(l, produitId);
  }

  void quantite(Liste l, String produitId, int q) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (q <= 0) {
      l.lignes.remove(g);
    } else {
      g.quantite = q;
    }
    _toucheConstruction(l);
    modifie();
  }

  /// Remet une ligne retirée (« Annuler » du message), à sa place.
  void remettreLigne(Liste l, LigneListe g, int i) {
    if (ligne(l, g.produitId) != null) return;
    l.lignes.insert(i.clamp(0, l.lignes.length), g);
    _toucheConstruction(l);
    modifie();
  }

  void definirPromotion(Liste l, String produitId, PromotionLigne? promo) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.promotion = promo;
    // La quantité suit la promotion qui exige un nombre (« 3 dont 1 gratuit » → 3).
    final requise = promo?.quantiteRequise;
    if (requise != null && g.quantite < requise) g.quantite = requise;
    _toucheConstruction(l);
    modifie();
  }

  void definirPackaging(Liste l, String produitId, String? packagingId) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.packagingId = packagingId;
    _toucheConstruction(l);
    modifie();
  }

  // ------------------------------------------------------------ Listes types

  /// Enregistre les articles de la liste sous un nom (sans coche) ; un nom déjà pris remplace l'ancienne liste type.
  ListeType enregistrerListeType(Liste l, String nom) {
    Sauvegarde.instance.jalon('Liste type enregistrée');
    listesTypes.removeWhere((t) => t.nom.trim().toLowerCase() == nom.trim().toLowerCase());
    final t = ListeType(nouvelId('lt'), nom.trim(), l.magasinId, lignesReprises(l));
    listesTypes.add(t);
    modifie();
    return t;
  }

  void supprimerListeType(ListeType t) {
    listesTypes.remove(t);
    modifie();
  }

  /// Annule [supprimerListeType] : la liste type revient à sa place.
  void remettreListeType(ListeType t, int place) {
    if (listesTypes.contains(t)) return;
    listesTypes.insert(place.clamp(0, listesTypes.length), t);
    modifie();
  }

  /// Articles d'une liste type, à copier dans une nouvelle liste.
  List<LigneListe> lignesDeListeType(ListeType t) => [
        for (final g in t.lignes)
          if (produit(g.produitId) != null)
            LigneListe(
                produitId: g.produitId, marqueId: g.marqueId, packagingId: g.packagingId, quantite: g.quantite, consigne: g.consigne)
      ];

  /// Packaging correspondant à une mesure et un lot (créé au besoin) ; null si ni l'un ni l'autre.
  Packaging? packagingCompose(String? mesure, String? lot) {
    if (mesure == null && lot == null) return null;
    return _packagingNomme(mesure != null && lot != null ? '$lot × $mesure' : (lot ?? mesure)!);
  }

  /// Mesures proposées pour un produit : ses formats, sinon tous les types de packaging qui ne sont pas des lots.
  List<String> mesuresProposees(Produit p) {
    final siens = <String>{
      for (final id in p.packagingIds)
        if (Etat.mesureEtLot(packaging(id)?.libelle).$1 case final m?) m
    };
    if (siens.isNotEmpty) return siens.toList();
    return [
      for (final id in typesPackaging)
        if (packaging(id) case final k? when !Etat.estLot(k.libelle)) k.libelle
    ];
  }

  /// Lots proposés : ceux du produit et tous les types de packaging « lot ».
  List<String> lotsProposes(Produit p) => <String>{
        for (final id in [...p.packagingIds, ...typesPackaging])
          if (Etat.mesureEtLot(packaging(id)?.libelle).$2 case final l?) l
      }.toList();

  /// Ajouter une marque ou choisir un packaging crée un article à part (« Camembert » reste ;
  /// « Camembert Président · 250 g » est créé), rangé aux mêmes endroits ; la ligne passe sur ce nouvel article.
  Produit produitVariante(Liste l, Produit p, {String? marqueNom, String? packagingId}) {
    final mq = (marqueNom ?? '').trim();
    final k = packaging(packagingId);
    final racine = p.nom.split(' · ').first;
    final nom = '$racine${mq.isEmpty ? '' : ' $mq'}${k == null ? '' : ' · ${k.libelle}'}';
    var q = Etat._trouve(produits, (x) => x.nom.toLowerCase() == nom.toLowerCase());
    if (q == null) {
      q = Produit(nouvelId('p'), nom, [...p.marqueIds], [if (k != null) k.id, ...p.packagingIds.where((id) => id != k?.id)], 0);
      produits.add(q);
      _marquerAjoute(q);
      for (final e in emplacements.where((e) => e.produitId == p.id).toList()) {
        emplacements.add(Emplacement(e.magasinId, q.id, e.secteurId));
      }
    }
    if (mq.isNotEmpty) ajouterMarque(q, mq);
    final m = mq.isEmpty ? null : Etat._trouve(marques, (x) => x.nom.toLowerCase() == mq.toLowerCase());
    final i = l.lignes.indexWhere((g) => g.produitId == p.id);
    if (i >= 0 && q.id != p.id && ligne(l, q.id) == null) {
      final g = l.lignes[i];
      q.nbUtilisations++;
      l.lignes[i] = LigneListe(
          produitId: q.id,
          marqueId: m?.id ?? g.marqueId,
          packagingId: k?.id ?? g.packagingId,
          quantite: g.quantite,
          promotion: g.promotion,
          consigne: g.consigne);
    }
    _toucheConstruction(l);
    modifie();
    return q;
  }

  /// Ajoute une marque au produit, hors de toute liste (catalogue ; 08/11/2026 : déclinaison, plus de produit
  /// « Camembert Président » à part). Rend le produit.
  Produit produitDeMarque(Produit p, String marqueNom) {
    final mq = marqueNom.trim();
    if (mq.isNotEmpty) ajouterMarque(p, mq);
    return p;
  }

  /// Mesures et packagings d'un produit du catalogue (02/11/2026).
  void definirFormats(Produit p, List<String> packagingIds) {
    p.packagingIds
      ..clear()
      ..addAll(packagingIds);
    modifie();
  }

  /// Nom de l'article sans la marque de sa ligne (« Camembert Président » → « Camembert »).
  String nomSansMarque(LigneListe? g, Produit p) {
    final mq = marque(g?.marqueId)?.nom;
    if (mq != null && p.nom.toLowerCase().endsWith(' ${mq.toLowerCase()}')) {
      return p.nom.substring(0, p.nom.length - mq.length - 1);
    }
    return p.nom;
  }

  /// Libellé de l'article dans la liste : son nom, avec la marque de la ligne si le nom ne la porte pas déjà.
  String libelleArticle(LigneListe? g, Produit p) {
    final mq = marque(g?.marqueId)?.nom;
    if (mq == null || p.nom.toLowerCase().contains(mq.toLowerCase())) return p.nom;
    return '${p.nom} $mq';
  }

  /// Marques proposées pour un article (08/11/2026, dans cet ordre) : celles déjà rattachées au produit
  /// (achetées par un foyer), celles de son secteur, les marques distributeur de l'enseigne du magasin, puis
  /// celles de sa nature d'après Open Food Facts. Chaque groupe par ordre alphabétique, sans doublon.
  List<String> marquesProposees(LigneListe? g, Produit p, {String? magasinId}) {
    final racine = nomSansMarque(g, p).toLowerCase();
    final s = secteurCatalogue(p.id);
    final ids = <String>{
      ...p.marqueIds,
      for (final q in produits)
        if (q.id != p.id && (q.nom.toLowerCase() == racine || q.nom.toLowerCase().startsWith('$racine '))) ...q.marqueIds,
    };
    List<String> trie(Iterable<String> l) => l.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final groupes = [
      trie([for (final id in ids) if (marque(id)?.nom case final n?) n]),
      trie(s == null ? const <String>[] : marquesDuSecteur(s)),
      if (magasinId != null) marquesDistributeurPour(magasin(magasinId), s),
      trie(naturesOff[racine]?.marques ?? const <String>[]),
    ];
    final noms = <String>[];
    for (final l in groupes) {
      for (final n in l) {
        if (n.trim().isNotEmpty && !noms.any((x) => x.toLowerCase() == n.toLowerCase())) noms.add(n);
      }
    }
    return noms;
  }

  /// Change la marque d'un article de la liste (08/11/2026, Aristide) : la marque est une déclinaison du
  /// produit générique, pas un produit à part. « Camembert » reste l'article de la ligne, la ligne porte
  /// « Président », et Président est rattachée au produit (proposée ensuite à la recherche : « Camembert ·
  /// Président »). Sans marque, la ligne redevient « Camembert ». Rend l'article de la ligne.
  Produit changerMarque(Liste l, Produit p, String? marqueNom) {
    final g = ligne(l, p.id);
    if (g == null) return p;
    final mq = (marqueNom ?? '').trim();
    if (mq.isEmpty) {
      g.marqueId = null;
    } else {
      final m = marqueNommee(mq);
      if (!p.marqueIds.contains(m.id)) p.marqueIds.add(m.id);
      g.marqueId = m.id;
    }
    _toucheConstruction(l);
    modifie();
    return p;
  }

  /// Marques rattachées au produit (achetées par le foyer ou par d'autres foyers), sans celle que son nom
  /// porte déjà : ce sont ses déclinaisons proposées à la recherche.
  List<String> declinaisons(Produit p) {
    final nom = p.nom.toLowerCase();
    final res = <String>[];
    for (final id in p.marqueIds) {
      final n = marque(id)?.nom;
      if (n == null || n.trim().isEmpty || nom.contains(n.toLowerCase())) continue;
      if (!res.any((x) => x.toLowerCase() == n.toLowerCase())) res.add(n);
    }
    return res..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Reprise des anciens produits de marque (08/11/2026) : « Camembert Président », produit ajouté ou reçu
  /// dont le générique « Camembert » existe, devient le générique avec la marque Président sur ses lignes
  /// (listes, historique, listes types) ; Président est rattachée à Camembert, l'ancien produit est masqué.
  /// Rend le nombre de produits repris.
  int reprendreProduitsDeMarque() {
    var n = 0;
    final parNom = <String, Produit>{};
    for (final p in produits) {
      parNom.putIfAbsent(p.nom.trim().toLowerCase(), () => p);
    }
    for (final q in [...produits]) {
      if (!estAjoute(q) && !estRecu(q)) continue;
      if (masques.contains(q.id)) continue;
      final nomQ = q.nom.trim().toLowerCase();
      Produit? p;
      Marque? m;
      for (final id in q.marqueIds) {
        final mq = marque(id);
        if (mq == null) continue;
        final b = mq.nom.trim().toLowerCase();
        if (b.isEmpty || !nomQ.endsWith(' $b')) continue;
        final g = parNom[nomQ.substring(0, nomQ.length - b.length - 1).trim()];
        if (g != null && g.id != q.id) {
          p = g;
          m = mq;
          break;
        }
      }
      if (p == null || m == null) continue;
      void reprendre(List<LigneListe> lignes) {
        for (var i = 0; i < lignes.length; i++) {
          final g = lignes[i];
          if (g.produitId != q.id) continue;
          if (lignes.any((x) => x.produitId == p!.id)) {
            final x = lignes.firstWhere((x) => x.produitId == p!.id);
            x.marqueId ??= m!.id;
            lignes.removeAt(i--);
          } else {
            lignes[i] = LigneListe(
                produitId: p!.id,
                marqueId: m!.id,
                packagingId: g.packagingId,
                quantite: g.quantite,
                promotion: g.promotion,
                cochePar: g.cochePar,
                cocheLe: g.cocheLe,
                consigne: g.consigne);
          }
        }
      }

      for (final l in listes) {
        reprendre(l.lignes);
      }
      for (final t in listesTypes) {
        reprendre(t.lignes);
      }
      if (!p.marqueIds.contains(m.id)) p.marqueIds.add(m.id);
      p.nbUtilisations += q.nbUtilisations;
      masques.add(q.id);
      n++;
    }
    if (n > 0) modifie();
    return n;
  }

  /// Déclinaisons achetées par le foyer, à partager avec tous les foyers (08/11/2026, Aristide :
  /// « l'enrichissement doit être fait par l'usage et non centralisé ») : pour chaque produit rangé coché avec
  /// une marque dans des courses terminées, « Rayon/Secteur/Produit » → marques. Trié : même texte à
  /// données égales.
  Map<String, List<String>> declinaisonsAchetees() {
    final decl = <String, Set<String>>{};
    for (final l in listes) {
      if (l.statut != StatutListe.terminee) continue;
      for (final g in l.lignes) {
        if (!g.coche) continue;
        final mq = marque(g.marqueId)?.nom;
        final p = produit(g.produitId);
        if (mq == null || p == null || Moderation.nomRefuse(mq, marque: true) != null) continue;
        if (p.nom.toLowerCase().contains(mq.toLowerCase()) || p.nom.contains('/') || Moderation.nomRefuse(p.nom) != null) continue;
        final s = secteurCatalogue(p.id);
        final r = s == null ? null : rayon(s.rayonId);
        if (s == null || r == null || r.nom.contains('/') || s.nom.contains('/')) continue;
        if (Etat.estExclu(exclusCommun, rayon: r.nom, secteur: s.nom, produit: p.nom)) continue;
        decl.putIfAbsent('${r.nom}/${s.nom}/${p.nom}', () => {}).add(mq);
      }
    }
    final cles = (decl.keys.toList()..sort()).take(Moderation.plafondProduits);
    return {for (final c in cles) c: (decl[c]!.toList()..sort())};
  }

  /// Rattache aux produits les déclinaisons déposées par les foyers ([lots] : « Rayon/Secteur/Produit » →
  /// marques), après les règles contre les mauvais usages : foyer bloqué ou dépôt trop gros écarté, noms
  /// refusés ignorés. Une marque se rattache au produit du même nom dans le même secteur, rien n'est créé.
  /// Rend le nombre de marques rattachées.
  int appliquerDeclinaisons(Map<String, Map<String, dynamic>> lots) {
    var n = 0;
    String bas(String t) => Moderation.normaliser(t);
    for (final MapEntry(key: foyer, value: j) in lots.entries) {
      if (foyersBloques.contains(foyer) || j.length > Moderation.plafondProduits) continue;
      for (final e in j.entries) {
        final parts = e.key.split('/');
        if (parts.length != 3 || parts.any((x) => x.trim().isEmpty || Moderation.nomRefuse(x) != null) || e.value is! List) continue;
        final ref = Etat._trouve(rayonsCatalogue, (r) => bas(r.nom) == bas(parts[0]));
        final s = ref == null ? null : Etat._trouve(secteursDu(ref.id), (x) => bas(x.nom) == bas(parts[1]));
        final p = s == null ? null : Etat._trouve(_tousDuSecteur(s), (x) => bas(x.nom) == bas(parts[2]));
        if (p == null) continue;
        for (final mq in (e.value as List).take(20).whereType<String>()) {
          if (mq.trim().isEmpty || Moderation.nomRefuse(mq, marque: true) != null) continue;
          if (p.nom.toLowerCase().contains(mq.trim().toLowerCase())) continue;
          final m = marqueNommee(mq);
          if (!p.marqueIds.contains(m.id)) {
            p.marqueIds.add(m.id);
            n++;
          }
        }
      }
    }
    if (n > 0) modifie();
    return n;
  }

  void definirConsigne(Liste l, String produitId, String? consigne) {
    final g = ligne(l, produitId);
    if (g == null) return;
    g.consigne = (consigne == null || consigne.trim().isEmpty) ? null : consigne.trim();
    _toucheConstruction(l);
    modifie();
  }

  /// Nom affiché d'une liste : celui donné par l'utilisateur, sinon « magasin du jj/mm/aaaa ».
  /// Nom complet de la liste d'une course de l'historique.
  String nomCourse(Course c) {
    final l = liste(c.id);
    if (l != null) return nomListe(l);
    return (c.nom != null && c.nom!.isNotEmpty) ? c.nom! : nomParDefaut(c.magasinId, c.dateCourses);
  }

  String nomListe(Liste l) => (l.nom != null && l.nom!.isNotEmpty) ? l.nom! : nomParDefaut(l.magasinId, l.dateCreation);
  /// Magasin, date et heure : deux listes créées n'ont pas le même nom.
  /// (Sans heure connue, comme dans les données de démonstration, la date seule.)
  String nomParDefaut(String magasinId, DateTime d) => '${magasin(magasinId)?.nom ?? 'Liste'} du ${jjmmaaaa(d)}'
      '${d.hour == 0 && d.minute == 0 ? '' : ' à ${heure(d)}'}';

  /// Nom libre à partir d'un nom proposé : « … (2) », « … (3) » si déjà pris.
  String nomLibre(String nom) {
    var n = nom;
    for (var i = 2; nomPris(n); i++) {
      n = '$nom ($i)';
    }
    return n;
  }

  /// Une liste non terminée porte déjà ce nom (deux listes ne peuvent pas avoir le même nom).
  bool nomPris(String nom, {Liste? sauf}) => listes.any((l) =>
      l != sauf && l.statut != StatutListe.terminee && nomListe(l).trim().toLowerCase() == nom.trim().toLowerCase());

  void renommerListe(Liste l, String nom) {
    l.nom = nom.trim().isEmpty ? null : nom.trim();
    modifie();
  }

  /// Une liste prête revient en préparation.
  /// Courses interrompues remises en préparation : les coches sont perdues.
  void coursesEnPreparation(Liste l) {
    for (final g in l.lignes) {
      g.cocheLe = null;
      g.cochePar = null;
    }
    apprentissage.remove(l.id);
    l.interrompueLe = null;
    remettreEnPreparation(l);
  }

  void remettreEnPreparation(Liste l) {
    // Une rectificative remise en préparation devient une liste ordinaire.
    if (rectificatives[l.id]?.signalee ?? false) rectificatives.remove(l.id);
    l.statut = StatutListe.enConstruction;
    l.membreId = null;
    l.parcoursId = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    modifie();
  }

  /// Dernières courses terminées dans un magasin (avec leurs articles), les plus récentes d'abord.
  List<Liste> dernieresCourses(String magasinId, {int nombre = 6}) {
    DateTime date(Liste l) => course(l.id)?.dateCourses ?? l.modifieeLe ?? l.dateCreation;
    final res = listes.where((l) => l.magasinId == magasinId && l.statut == StatutListe.terminee && l.lignes.isNotEmpty).toList()
      ..sort((a, b) => date(b).compareTo(date(a)));
    return res.take(nombre).toList();
  }

  DateTime dateCourses(Liste l) => course(l.id)?.dateCourses ?? l.modifieeLe ?? l.dateCreation;

  /// Articles d'une liste reprise pour une nouvelle préparation (sans coche ni promotion).
  List<LigneListe> lignesReprises(Liste ancienne) => [
        for (final g in ancienne.lignes)
          if (produit(g.produitId) != null)
            LigneListe(produitId: g.produitId, marqueId: g.marqueId, packagingId: g.packagingId, quantite: g.quantite, consigne: g.consigne)
      ];

  /// Quantité requise par la promotion si la ligne n'y suffit pas (règle 11), sinon null.
  int? quantiteInsuffisante(LigneListe g) {
    final r = g.promotion?.quantiteRequise;
    return (r != null && g.quantite < r) ? r : null;
  }

  int nbDansRayon(Liste l, String rayonId) => l.lignes.where((g) => rayonDe(l.magasinId, g.produitId)?.id == rayonId).length;
  int nbDansSecteur(Liste l, String secteurId) =>
      l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == secteurId).length;

  /// Position courante de la construction, gardée pour la reprise.
  void positionConstruction(Liste l, String? rayonId, String? secteurId) {
    if (l.repriseRayonId == rayonId && l.repriseSecteurId == secteurId && l.interrompueLe != null) return;
    l.repriseRayonId = rayonId;
    l.repriseSecteurId = secteurId;
    l.interrompueLe = DateTime.now();
    modifie();
  }

  Liste creerListe(String magasinId, List<LigneListe> lignes, {String? nom}) {
    for (final g in lignes) {
      produit(g.produitId)?.nbUtilisations++; // entrée dans une liste (règle R4)
    }
    final l = Liste(
      id: nouvelId('l'),
      magasinId: magasinId,
      statut: StatutListe.enConstruction,
      dateCreation: DateTime.now(),
      lignes: lignes,
      modifieePar: moi.id,
      modifieeLe: DateTime.now(),
      nom: (nom == null || nom.trim().isEmpty) ? null : nom.trim(),
    );
    listes.add(l);
    modifie();
    return l;
  }

  void _avertir(String texte, {Iterable<String>? a}) {
    try {
      avertir?.call(texte, a);
    } catch (_) {}
  }

  String _articles(Liste l) {
    final n = l.lignes.length;
    return n == 1 ? '1 article' : '$n articles';
  }

  void listePrete(Liste l) {
    Sauvegarde.instance.jalon('Liste prête');
    // Une rectificative refusée ou restée sans réponse est signalée à son auteur, pas annoncée au foyer.
    if (rectificatives[l.id] == null && l.statut != StatutListe.prete) {
      _avertir('Liste « ${nomListe(l)} » prête (${_articles(l)})');
    }
    l.statut = StatutListe.prete;
    l.interrompueLe = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    l.modifieePar = moi.id;
    l.modifieeLe = DateTime.now();
    modifie();
  }

  // ------------------------------------------------------------ Liste rectificative

  Rectificative? rectificativeDe(Liste l) => rectificatives[l.id];

  /// Courses en cours qu'une rectificative peut compléter (pas les listes « À faire », décision du 28/10/2026).
  List<Liste> ciblesRectificative() => [for (final l in listes) if (l.statut == StatutListe.enCours) l];

  /// Rectificative pas encore réglée pour [cible] (en préparation ou en attente de décision) : une seule à la fois.
  Rectificative? rectificativeOuvertePour(Liste cible) => Etat._trouve(
      rectificatives.values, (r) => r.cibleId == cible.id && (r.enRedaction || r.enAttente) && liste(r.listeId) != null);

  /// Rectificative qui attend la décision de celui qui fait la course [cible].
  Rectificative? rectificativeEnAttente(Liste cible) => Etat._trouve(
      rectificatives.values, (r) => r.cibleId == cible.id && r.enAttente && liste(r.listeId) != null);

  /// Rectificatives acceptées pour la course [cible].
  List<Rectificative> rectificativesAcceptees(Liste cible) =>
      [for (final r in rectificatives.values) if (r.cibleId == cible.id && r.acceptee) r];

  /// Mention après le nombre d'articles d'une liste : « rectificative », « rectificative envoyée ».
  String mentionRectificative(Liste l) {
    final r = rectificatives[l.id];
    if (r == null || r.acceptee) return '';
    return r.enAttente ? ' · rectificative envoyée' : ' · rectificative';
  }

  /// Nouvelle liste rectificative de [cible], du même magasin : la recherche, les articles sous leur secteur.
  Liste creerRectificative(Liste cible) {
    final l = creerListe(cible.magasinId, [], nom: nomLibre('Rectificative ${nomListe(cible)}'));
    rectificatives[l.id] = Rectificative(l.id, cible.id, moi.id, DateTime.now(), mode: 'redaction');
    modifie();
    return l;
  }

  /// « Liste prête » d'une rectificative : fusionnée dans une liste pas encore commencée ('fusionnee'),
  /// envoyée à celui qui fait les courses ('envoyee'), ou, les courses finies, mise en « À faire » ('afaire').
  String validerRectificative(Liste l) {
    final r = rectificatives[l.id];
    if (r == null) return '';
    final cible = liste(r.cibleId);
    if (cible?.statut == StatutListe.enCours) {
      r.mode = null;
      l.modifieePar = moi.id;
      l.modifieeLe = DateTime.now();
      modifie();
      _avertir('${moi.nomAffiche} vous envoie une liste rectificative (${_articles(l)}) pour « ${nomListe(cible!)} »',
          a: [if (cible.membreId != null) cible.membreId!]);
      return 'envoyee';
    }
    if (cible != null && cible.statut != StatutListe.terminee) {
      accepterRectificative(r, fusion: true);
      return 'fusionnee';
    }
    _signaler(r);
    return 'afaire';
  }

  void _signaler(Rectificative r, {String? avis}) {
    final l = liste(r.listeId);
    if (l == null) {
      rectificatives.remove(r.listeId);
      modifie();
      return;
    }
    r.mode = 'signalee';
    listePrete(l);
    if (avis != null) _avertir('$avis : elle est dans « À faire »', a: [r.auteurId]);
  }

  /// Refusée : elle passe en « À faire », marquée rectificative.
  void refuserRectificative(Rectificative r) =>
      _signaler(r, avis: '${moi.nomAffiche} a refusé votre liste rectificative');

  /// Ajoute les articles de la rectificative à la course ; un article déjà dans la course n'est pas doublé.
  void accepterRectificative(Rectificative r, {required bool fusion}) {
    final rl = liste(r.listeId);
    final cible = liste(r.cibleId);
    if (rl == null || cible == null) return;
    for (final g in rl.lignes) {
      if (ligne(cible, g.produitId) != null) continue;
      cible.lignes.add(LigneListe(
          produitId: g.produitId,
          marqueId: g.marqueId,
          packagingId: g.packagingId,
          quantite: g.quantite,
          promotion: g.promotion,
          consigne: g.consigne));
      r.produits.add(g.produitId);
    }
    r.mode = fusion ? 'fusion' : 'apart';
    final c = commentaires.remove(rl.id);
    if (c != null) commentaires[cible.id] = [commentaires[cible.id], c].whereType<String>().join('\n');
    listes.remove(rl);
    modifie();
  }

  // ------------------------------------------------------------ Préliste

  Map<String, int> frequencesDu(String magasinId) => frequences[magasinId] ?? const {};

  /// 10/11/2026 (Aristide) : « Mes achats habituels » : les articles achetés au moins [prelistePresencesMin] fois
  /// sur les [prelisteSur] dernières courses du magasin (seuil réduit s'il y a moins de courses), avec la
  /// quantité et le packaging de leur dernier achat ; les plus fréquents d'abord.
  List<LigneListe> preliste(String magasinId) {
    final courses = dernieresCourses(magasinId, nombre: prelisteSur);
    if (courses.isEmpty) return [];
    final seuil = prelistePresencesMin < courses.length ? prelistePresencesMin : courses.length;
    final nb = <String, int>{};
    final derniere = <String, LigneListe>{};
    for (final c in courses) {
      // Les articles achetés : ceux cochés (les manquants ne comptent pas) ; liste sans coche : tous.
      final lignes = c.lignes.any((g) => g.coche) ? c.lignes.where((g) => g.coche) : c.lignes;
      for (final g in lignes) {
        if (produit(g.produitId) == null) continue;
        nb[g.produitId] = (nb[g.produitId] ?? 0) + 1;
        derniere.putIfAbsent(g.produitId, () => g);
      }
    }
    final ids = nb.keys.where((id) => nb[id]! >= seuil).toList()..sort((a, b) => nb[b]!.compareTo(nb[a]!));
    return [
      for (final id in ids)
        LigneListe(
            produitId: id,
            marqueId: derniere[id]!.marqueId,
            packagingId: derniere[id]!.packagingId,
            quantite: derniere[id]!.quantite,
            consigne: derniere[id]!.consigne)
    ];
  }

  /// Nombre de fois où chaque article a été acheté sur les dernières courses (pour « Mes achats habituels »).
  Map<String, int> achatsRecents(String magasinId) {
    final res = <String, int>{};
    for (final c in dernieresCourses(magasinId, nombre: prelisteSur)) {
      final lignes = c.lignes.any((g) => g.coche) ? c.lignes.where((g) => g.coche) : c.lignes;
      for (final g in lignes) {
        res[g.produitId] = (res[g.produitId] ?? 0) + 1;
      }
    }
    return res;
  }
}
