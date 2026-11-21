part of '../modele.dart';

// Méthodes de l'état (EtatCourses), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatCourses on Etat {

  // ------------------------------------------------------------ Parcours

  List<Parcours> parcoursDe(String magasinId, String membreId) =>
      parcours.where((p) => p.magasinId == magasinId && p.membreId == membreId).toList();

  Parcours? parcoursParDefaut(String magasinId, String membreId) {
    final l = parcoursDe(magasinId, membreId);
    if (l.isEmpty) return null;
    return l.firstWhere((p) => p.parDefaut, orElse: () => l.first);
  }

  /// 03/11/2026 (Aristide) : « Parcours de <membre> », suivi du nom donné au parcours s'il en a un.
  String nomParcours(Parcours p) {
    final de = 'Parcours de ${membre(p.membreId)?.nomAffiche ?? '?'}';
    final n = p.nom.trim();
    return n.isEmpty || n == 'Parcours appris' || n.startsWith('Parcours de ') ? de : '$de · $n';
  }

  /// Date du dernier apprentissage (ou de la fusion) ; à défaut, celle des dernières courses faites avec ce parcours.
  DateTime? dateParcours(Parcours p) {
    if (datesParcours[p.id] case final d?) return d;
    DateTime? res;
    for (final c in historique) {
      if (liste(c.id)?.parcoursId != p.id) continue;
      if (res == null || c.dateCourses.isAfter(res)) res = c.dateCourses;
    }
    return res;
  }

  /// Tous les parcours d'un magasin, quel que soit le membre qui les a appris (03/11/2026 : ils servent à tous).
  List<Parcours> parcoursDuMagasin(String magasinId) => parcours.where((p) => p.magasinId == magasinId).toList();

  /// Parcours proposé au départ des courses (03/11/2026, Aristide) : un parcours issu d'une fusion s'il y en a,
  /// sinon celui de la personne qui fait les courses, sinon un parcours du magasin.
  Parcours? parcoursPourCourses(String magasinId, String membreId) {
    final tous = parcoursDuMagasin(magasinId);
    if (tous.isEmpty) return null;
    final fusion = tous.where((p) => parcoursFusionnes.contains(p.id)).toList();
    if (fusion.isNotEmpty) return fusion.firstWhere((p) => p.parDefaut, orElse: () => fusion.last);
    return parcoursParDefaut(magasinId, membreId) ?? tous.firstWhere((p) => p.parDefaut, orElse: () => tous.first);
  }

  void definirParDefaut(Parcours p, bool oui) {
    for (final autre in parcoursDe(p.magasinId, p.membreId)) {
      autre.parDefaut = oui ? identical(autre, p) : (identical(autre, p) ? false : autre.parDefaut);
    }
    modifie();
  }

  Parcours creerParcours(String magasinId, String membreId, String nom) {
    final p = Parcours(nouvelId('pc'), magasinId, membreId, nom, parcoursDe(magasinId, membreId).isEmpty,
        secteursDuMagasin(magasinId).map((s) => s.id).toList());
    parcours.add(p);
    modifie();
    return p;
  }

  /// 03/11/2026 (Aristide) : fusionne [autre] dans [p] (même magasin) : [p] garde son ordre et reçoit, à leur place,
  /// les secteurs que seul [autre] connaît ; les listes qui suivaient [autre] suivent [p] ; [autre] part dans la corbeille.
  void fusionnerParcours(Parcours p, Parcours autre) {
    if (p.id == autre.id || p.magasinId != autre.magasinId) return;
    p.etapes = Etat.insererSecteurs(p.etapes, autre.etapes);
    for (final l in listes) {
      if (l.parcoursId == autre.id) l.parcoursId = p.id;
    }
    if (autre.parDefaut && autre.membreId == p.membreId) p.parDefaut = true;
    parcoursFusionnes.add(p.id);
    datesParcours[p.id] = DateTime.now();
    datesParcours.remove(autre.id);
    // Les passages des deux parcours servent au lissage du parcours fusionné (les plus récents gardés).
    final passages = [...?passagesParcours[p.id], ...?passagesParcours.remove(autre.id)];
    if (passages.isNotEmpty) passagesParcours[p.id] = passages.sublist(passages.length > Etat.maxPassages ? passages.length - Etat.maxPassages : 0);
    if (parcoursAppris.contains(autre.id)) parcoursAppris.add(p.id);
    modifie();
    supprimer(autre);
  }

  void renommerParcours(Parcours p, String nom) {
    if (nom.trim().isEmpty) return;
    p.nom = nom.trim();
    modifie();
  }

  /// Rayons du parcours dans l'ordre de leur premier passage.
  List<Rayon> rayonsDuParcours(Parcours p) {
    final ids = <String>[];
    for (final sid in p.etapes) {
      final r = secteur(sid)?.rayonId;
      if (r != null && !ids.contains(r)) ids.add(r);
    }
    return [for (final id in ids) if (rayon(id) != null) rayon(id)!];
  }

  /// Déplace un rayon entier (tous ses secteurs) dans le parcours ; les secteurs sont regroupés par rayon.
  void deplacerRayonParcours(Parcours p, int ancien, int nouveau) {
    final rs = rayonsDuParcours(p);
    if (ancien < 0 || ancien >= rs.length) return;
    final r = rs.removeAt(ancien);
    rs.insert(nouveau.clamp(0, rs.length), r);
    p.etapes = [
      for (final x in rs) ...p.etapes.where((sid) => secteur(sid)?.rayonId == x.id),
      ...p.etapes.where((sid) => secteur(sid) == null),
    ];
    modifie();
  }

  /// Parcours d'un membre, tous magasins confondus.
  List<Parcours> parcoursDuMembre(String membreId) => parcours.where((p) => p.membreId == membreId).toList();

  /// « (retour) » : le rayon de l'étape a déjà été visité plus tôt, mais pas à l'étape précédente (règle 7).
  bool estRetour(List<String> etapes, int i) {
    final r = secteur(etapes[i])?.rayonId;
    if (i == 0 || r == null) return false;
    if (secteur(etapes[i - 1])?.rayonId == r) return false;
    return etapes.take(i - 1).any((id) => secteur(id)?.rayonId == r);
  }

  /// Étapes des courses : secteurs ayant au moins un article, dans l'ordre du parcours
  /// (sans parcours : ordre des rayons), puis « Non placé » (règle 9).
  /// [ordreBase] : ordre des secteurs sans parcours (préparation : celui du catalogue).
  List<Etape> etapes(Liste l, String? parcoursId, {List<String>? ordreBase}) {
    final ordre = <String>[...(unParcours(parcoursId)?.etapes ?? const <String>[])];
    for (final id in ordreBase ?? const <String>[]) {
      if (!ordre.contains(id)) ordre.add(id);
    }
    for (final s in secteursDuMagasin(l.magasinId)) {
      if (!ordre.contains(s.id)) ordre.add(s.id);
    }
    final res = <Etape>[];
    for (final sid in ordre) {
      final lignes = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId)?.id == sid).toList();
      final s = secteur(sid);
      if (lignes.isNotEmpty && s != null) res.add(Etape(s, lignes));
    }
    final np = l.lignes.where((g) => secteurDe(l.magasinId, g.produitId) == null).toList();
    if (np.isNotEmpty) res.add(Etape(null, np));
    return res;
  }

  // ------------------------------------------------------------ Courses

  void demarrerCourses(Liste l, String membreId, String? parcoursId) {
    // Ses courses commencent : elle n'est plus marquée rectificative.
    if (rectificatives[l.id]?.signalee ?? false) rectificatives.remove(l.id);
    // Sans parcours dans ce magasin, on propose d'emblée de l'enregistrer.
    if (parcoursDe(l.magasinId, membreId).isEmpty) apprentissage.add(l.id);
    l.statut = StatutListe.enCours;
    l.membreId = membreId;
    l.parcoursId = parcoursId;
    l.interrompueLe = null;
    l.repriseRayonId = null;
    l.repriseSecteurId = null;
    modifie();
    _avertir('${membre(membreId)?.nomAffiche ?? moi.nomAffiche} part faire les courses chez ${magasin(l.magasinId)?.nom ?? '?'}');
  }

  void cocher(Liste l, String produitId) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (g.coche) {
      g.cocheLe = null;
      g.cochePar = null;
    } else {
      g.cocheLe = DateTime.now();
      g.cochePar = l.membreId ?? moi.id;
    }
    modifie();
  }

  /// Changement de parcours pendant les courses : on garde l'étape en cours si elle existe encore.
  void changerParcours(Liste l, String? parcoursId) {
    l.parcoursId = parcoursId;
    modifie();
  }

  bool apprend(Liste l) => apprentissage.contains(l.id);

  void apprendreParcours(Liste l, bool oui) {
    oui ? apprentissage.add(l.id) : apprentissage.remove(l.id);
    modifie();
  }

  /// Secteurs dans l'ordre où leurs premiers articles ont été cochés.
  List<String> secteursDansLOrdre(Liste l) {
    final cochees = l.lignes.where((g) => g.cocheLe != null).toList()..sort((a, b) => a.cocheLe!.compareTo(b.cocheLe!));
    final res = <String>[];
    for (final g in cochees) {
      final s = secteurDe(l.magasinId, g.produitId)?.id;
      if (s != null && !res.contains(s)) res.add(s);
    }
    return res;
  }

  /// Fin de courses enregistrées : crée le parcours appris, ou y insère en silence les secteurs nouveaux,
  /// chacun juste après le secteur visité avant lui (ou juste avant le suivant), sans changer l'ordre existant.
  Parcours? retenirParcours(Liste l) {
    if (!apprentissage.remove(l.id)) return null;
    final suite = secteursDansLOrdre(l);
    if (suite.isEmpty) return null;
    final membreId = l.membreId ?? moi.id;
    // Le parcours suivi, s'il est appris ou fusionné, se complète, quel que soit le membre qui l'a appris.
    final existant = Etat._trouve(parcoursDuMagasin(l.magasinId),
            (p) => p.id == l.parcoursId && (parcoursAppris.contains(p.id) || parcoursFusionnes.contains(p.id))) ??
        Etat._trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id) && p.id == l.parcoursId) ??
        Etat._trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id) && p.parDefaut) ??
        Etat._trouve(parcoursDe(l.magasinId, membreId), (p) => parcoursAppris.contains(p.id));
    if (existant == null) {
      for (final autre in parcoursDe(l.magasinId, membreId)) {
        autre.parDefaut = false;
      }
      final p = Parcours(nouvelId('pc'), l.magasinId, membreId, 'Parcours de ${membre(membreId)?.nomAffiche ?? ''}'.trim(), true, suite);
      parcours.add(p);
      parcoursAppris.add(p.id);
      datesParcours[p.id] = DateTime.now();
      passagesParcours[p.id] = [suite];
      return p;
    }
    final passages = [...?passagesParcours[existant.id], suite];
    if (passages.length > Etat.maxPassages) passages.removeRange(0, passages.length - Etat.maxPassages);
    passagesParcours[existant.id] = passages;
    existant.etapes = Etat.lisserParcours(Etat.insererSecteurs(existant.etapes, suite), passages);
    datesParcours[existant.id] = DateTime.now();
    return existant;
  }

  /// Départ annulé (rien de coché) : la liste redevient prête.
  void annulerDepart(Liste l) {
    apprentissage.remove(l.id);
    // Les courses n'ont pas commencé : la rectificative en attente s'y ajoute.
    for (final r in [...rectificatives.values.where((r) => r.cibleId == l.id && r.enAttente)]) {
      accepterRectificative(r, fusion: true);
    }
    l.statut = StatutListe.prete;
    l.membreId = null;
    l.parcoursId = null;
    l.repriseSecteurId = null;
    l.interrompueLe = null;
    modifie();
  }

    void etapeCourante(Liste l, String etapeId) {
    l.repriseSecteurId = etapeId;
    modifie();
  }

  void interrompreCourses(Liste l) {
    l.interrompueLe = DateTime.now();
    modifie();
  }

  Course terminerCourses(Liste l) {
    Sauvegarde.instance.jalon('Courses terminées');
    // Dans la base, une course de l'historique est la liste elle-même, au statut « terminee ».
    final c = Course(l.id, l.magasinId, DateTime.now(), l.membreId ?? moi.id, l.nbCoches, nom: l.nom);
    historique.insert(0, c);
    // 13/11/2026 : la liste terminée garde le parcours appris (ou complété) pendant ces courses.
    if (retenirParcours(l) case final p?) l.parcoursId = p.id;
    l.statut = StatutListe.terminee;
    l.interrompueLe = null;
    // Une rectificative restée sans réponse passe en « À faire » ; une rectificative en préparation le sera à sa fin.
    for (final r in [...rectificatives.values.where((r) => r.cibleId == l.id)]) {
      if (r.enAttente) {
        _signaler(r, avis: 'Courses terminées sans votre liste rectificative');
      } else if (r.acceptee) {
        rectificatives.remove(r.listeId);
      }
    }
    modifie();
    _avertir('${membre(c.membreId)?.nomAffiche ?? moi.nomAffiche} a terminé les courses chez '
        '${magasin(l.magasinId)?.nom ?? '?'} (${l.nbCoches} ${l.nbCoches == 1 ? 'article acheté' : 'articles achetés'})');
    return c;
  }
}
