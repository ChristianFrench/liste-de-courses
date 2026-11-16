part of '../modele.dart';

// Méthodes de l'état (EtatFoyer), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatFoyer on Etat {

  // ------------------------------------------------------------ Paramètres et historique

  void renommerFoyer(String nom) {
    foyerNom = nom;
    modifie();
  }

  void reglerPreliste(int presences, int sur) {
    prelistePresencesMin = presences;
    prelisteSur = sur;
    modifie();
  }

  void ajouterTypePromotion(String code, String nom, String exemple) {
    // Le code est unique (contrainte de la base) : « BON », « BON2 »…
    var unique = code;
    for (var i = 2; typesPromotion.any((t) => t.code == unique); i++) {
      unique = '$code$i';
    }
    typesPromotion.add(TypePromotion(nouvelId('tp'), unique, nom, exemple, ['libelle']));
    modifie();
  }

  /// Corrige le nom et le code court d'un type de promotion (le code reste unique).
  void modifierTypePromotion(TypePromotion t, {required String nom, required String code}) {
    if (nom.trim().isEmpty || code.trim().isEmpty) return;
    var unique = code.trim().toUpperCase();
    for (var i = 2; typesPromotion.any((x) => x.id != t.id && x.code == unique); i++) {
      unique = '${code.trim().toUpperCase()}$i';
    }
    t
      ..nom = nom.trim()
      ..code = unique;
    modifie();
  }

  /// Retire un type de promotion ; les listes déjà faites gardent leurs promotions.
  void supprimerTypePromotion(TypePromotion t) {
    typesPromotion.remove(t);
    modifie();
  }

  /// Courses terminées en instance : ni ticket joint, ni classées sans ticket. Elles restent dans l'onglet Courses.
  /// Courses « Terminées » (onglet Courses), avec ou sans ticket, pas encore passées dans l'historique.
  List<Course> get coursesEnInstance =>
      historique.where((c) => !estArchive(c.magasinId) && !sansTicket.contains(c.id) && !archivees.contains(c.id)).toList();
  bool enInstance(Course c) => !sansTicket.contains(c.id);

  String? commentaire(Liste l) => commentaires[l.id];

  bool manquant(Liste l, String produitId) => manquants[l.id]?.contains(produitId) ?? false;

  /// Article absent des rayons (double appui sur sa case) : il est décoché et marqué manquant.
  void marquerManquant(Liste l, String produitId, bool oui) {
    final g = ligne(l, produitId);
    if (g == null) return;
    if (oui) {
      g.cocheLe = null;
      g.cochePar = null;
      (manquants[l.id] ??= {}).add(produitId);
    } else {
      manquants[l.id]?.remove(produitId);
      if (manquants[l.id]?.isEmpty ?? false) manquants.remove(l.id);
    }
    modifie();
  }

  bool estSimple(Liste l) => simples.contains(l.id);

  DateTime? datePrevue(Liste l) => DateTime.tryParse(datesPrevues[l.id] ?? '');

  void fixerDatePrevue(Liste l, DateTime d) {
    datesPrevues[l.id] = _iso(DateTime(d.year, d.month, d.day))!.substring(0, 10);
    modifie();
  }

  /// Change le magasin et le jour prévu d'une liste en préparation. Le nom suit s'il était celui proposé
  /// à la création (« Intermarché · samedi 25/10 ») ; un nom choisi par l'utilisateur est gardé.
  void changerMagasinEtDate(Liste l, String magasinId, DateTime prevue) {
    final avant = datePrevue(l) ?? l.dateCreation;
    final ancienMagasin = l.magasinId;
    final propose = nomPrevu(l.magasinId, avant);
    final nomAuto = l.nom == null ||
        l.nom == propose ||
        l.nom == nomParDefaut(l.magasinId, l.dateCreation) ||
        RegExp('^${RegExp.escape(propose)} \\(\\d+\\)\$').hasMatch(l.nom!);
    if (l.magasinId != magasinId) {
      l.magasinId = magasinId;
      l.parcoursId = null; // le parcours est propre à un magasin
    }
    datesPrevues[l.id] = _iso(DateTime(prevue.year, prevue.month, prevue.day))!.substring(0, 10);
    if (nomAuto) {
      l.nom = null;
      l.nom = nomLibre(nomPrevu(magasinId, prevue));
    } else if (l.nom != null) {
      // 05/11/2026 (Aristide) : « la date ne change pas ». Un nom retouché qui contient une date
      // (« Intermarché · samedi 25/10 + apéro », « Leclerc 25/10/2026 ») prend la nouvelle, avec son jour.
      var n = l.nom!.replaceFirstMapped(RegExp('(?:(?:${joursSemaine.join('|')}) +)?(\\d{1,2})/(\\d{1,2})(/\\d{4})?'),
          (m) => '${joursSemaine[prevue.weekday - 1]} ${m.group(3) == null ? jjmm(prevue) : jjmmaaaa(prevue)}');
      final mAvant = magasin(ancienMagasin)?.nom, mApres = magasin(magasinId)?.nom;
      if (mAvant != null && mApres != null && mAvant != mApres && n.startsWith(mAvant)) n = '$mApres${n.substring(mAvant.length)}';
      if (n != l.nom) {
        l.nom = null;
        l.nom = nomLibre(n);
      }
    }
    modifie();
  }

  /// Nom proposé à la création : le magasin et le jour prévu des courses (« Intermarché · samedi 25/10 »).
  String nomPrevu(String magasinId, DateTime prevue) =>
      '${magasin(magasinId)?.nom ?? 'Liste'} · ${joursSemaine[prevue.weekday - 1]} ${jjmm(prevue)}';

  /// Deuxième ligne de l'en-tête d'une liste : date de création.
  String creeeLe(Liste l) => 'Créée le ${jjmm(l.dateCreation)} à ${heure(l.dateCreation)}';

  /// Jour prévu des courses d'une liste en préparation, en clair (« courses samedi 07/11 ») ; vide sans date.
  String coursesPrevues(Liste l) {
    final d = datePrevue(l);
    return d == null ? '' : 'courses ${joursSemaine[d.weekday - 1]} ${jjmm(d)}';
  }

  void marquerSimple(Liste l, bool oui) {
    if (oui ? simples.add(l.id) : simples.remove(l.id)) modifie();
  }

  /// Liste simple suivie par rayons et secteurs pendant les courses.
  bool estRangee(Liste l) => !nonRangees.contains(l.id);

  void ranger(Liste l, bool oui) {
    if (oui ? nonRangees.remove(l.id) : nonRangees.add(l.id)) modifie();
  }

  /// Liste montrée sans rayons ni secteurs pendant les courses : simple et non rangée.
  bool aPlat(Liste l) => estSimple(l) && !estRangee(l);

  void commenter(Liste l, String texte) {
    if (texte.trim().isEmpty) {
      commentaires.remove(l.id);
    } else {
      commentaires[l.id] = texte.trim();
    }
    modifie();
  }

  /// « Terminées » → Historique (glissement à droite).
  void classerSansTicket(Course c) => mettreEnHistorique(c);

  void mettreEnHistorique(Course c) {
    sansTicket.add(c.id);
    modifie();
  }

  /// Historique › « Remettre dans Terminées » : la course revient dans l'onglet Courses.
  void remettreSansTicket(Course c) {
    sansTicket.remove(c.id);
    archivees.remove(c.id);
    modifie();
  }

  /// Course rangée dans les archives (magasin supprimé, ou passée de l'historique aux archives).
  bool estArchivee(Course c) => estArchive(c.magasinId) || archivees.contains(c.id);

  void archiver(Course c) {
    archivees.add(c.id);
    gardeesEnHistorique.remove(c.id);
    modifie();
  }

  void remettreEnHistorique(Course c) {
    archivees.remove(c.id);
    gardeesEnHistorique.add(c.id);
    modifie();
  }

  /// Courses archivées des magasins actifs, les plus récentes d'abord.
  List<Course> get coursesArchivees => historique.where((c) => !estArchive(c.magasinId) && archivees.contains(c.id)).toList()
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));

  void reglerDelaiHistorique(int mois) {
    delaiHistorique = mois;
    archiverAnciennes();
    modifie();
  }

  /// Les courses classées de plus de [delaiHistorique] mois passent dans les archives (sauf celles remises
  /// à la main dans l'historique). Rend vrai si quelque chose a changé.
  bool archiverAnciennes() {
    if (delaiHistorique <= 0) return false;
    final limite = DateTime.now().subtract(Duration(days: 30 * delaiHistorique));
    var change = false;
    for (final c in historique) {
      if (c.dateCourses.isBefore(limite) && !enInstance(c) && !gardeesEnHistorique.contains(c.id) && archivees.add(c.id)) change = true;
    }
    return change;
  }

  Membre ajouterMembre(String nom, String email) {
    Sauvegarde.instance.jalon('Membre ajouté');
    final m = Membre(nouvelId('m'), nom.trim(), 'membre', false, email: email.trim());
    membres.add(m);
    modifie();
    return m;
  }

  void rattacherTicket(Ticket t, Course c) {
    t.listeId = c.id;
    modifie();
  }

  /// Ticket joint à une course (PDF fourni par l'application du magasin).
  Ticket ajouterTicket(Course c) {
    final t = Ticket(nouvelId('t'), c.id, c.magasinId, c.dateCourses, 0, 'photo');
    tickets.add(t);
    modifie();
    return t;
  }

  /// Ticket reçu sans course choisie : il attend dans Courses › Historique (« Tickets non rattachés »).
  /// (Source « photo » : la seule, avec « compte_magasin », que la base accepte.)
  Ticket ajouterTicketLibre(String magasinId) {
    final t = Ticket(nouvelId('t'), null, magasinId, DateTime.now(), 0, 'photo');
    tickets.add(t);
    modifie();
    return t;
  }

  String libelleTicket(Ticket t) => libellesTickets[t.id] ?? '';

  bool ticketImage(Ticket t) => ticketsImage.contains(t.id);

  void marquerTicketImage(Ticket t, bool image) {
    if (image ? !ticketsImage.add(t.id) : !ticketsImage.remove(t.id)) return;
    modifie();
  }

  void nommerTicket(Ticket t, String libelle) {
    libelle = libelle.trim();
    if (libelle.isEmpty ? libellesTickets.remove(t.id) == null : libellesTickets[t.id] == libelle) return;
    if (libelle.isNotEmpty) libellesTickets[t.id] = libelle;
    modifie();
  }

  void dateTicket(Ticket t, DateTime date) {
    if (t.date == date) return;
    t.date = date;
    modifie();
  }

  void montantTicket(Ticket t, double montant) {
    t.montant = montant;
    modifie();
  }

  void modifierEmail(Membre m, String email) {
    m.email = email.trim();
    modifie();
  }

  // ------------------------------------------------------------ Membres du foyer (26/10/2026)

  /// Membres visibles : tous sauf ceux qui ont été retirés du foyer (ou radiés, avant le 27/10/2026).
  /// Leurs noms restent sur leurs listes et leurs courses.
  List<Membre> get membresVisibles => [for (final m in membres) if (!statutsMembres.containsKey(m.id)) m];

  /// Cet appareil a été retiré du foyer par un autre membre.
  bool get moiExclu => statutsMembres.containsKey(moi.id);

  void renommerMembre(Membre m, String nom) {
    if (nom.trim().isEmpty) return;
    m.nomAffiche = nom.trim();
    modifie();
  }

  /// Retirer du foyer : le membre disparaît de la liste ; ses listes et ses courses restent.
  /// Son appareil cesse de partager ; il revient en saisissant le code de partage.
  void supprimerMembre(Membre m) {
    Sauvegarde.instance.jalon('Membre retiré');
    statutsMembres[m.id] = 's';
    modifie();
  }

  void reactiverMembre(Membre m) {
    if (statutsMembres.remove(m.id) != null) modifie();
  }

  /// Listes préparées par un membre, et ses courses.
  List<Liste> listesDuMembre(Membre m) => [for (final l in listes) if (l.membreId == m.id) l]
    ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
  List<Course> coursesDuMembre(Membre m) => [for (final c in historique) if (c.membreId == m.id) c]
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));

  /// Avant de rejoindre un foyer : les produits ajoutés et les listes non terminées de cet appareil,
  /// décrits par leurs noms (les identifiants changent d'un foyer à l'autre).
  Map<String, Object?> aReprendre() {
    String? rangementDe(Produit p) {
      final s = secteurCatalogue(p.id);
      return s == null ? null : '${rayon(s.rayonId)?.nom}/${s.nom}';
    }

    return {
      'produits': [
        for (final p in produitsAjoutes)
          {
            'nom': p.nom,
            'rangement': rangementDe(p),
            'marques': [for (final id in p.marqueIds) marque(id)?.nom],
            'formats': [for (final id in p.packagingIds) packaging(id)?.libelle],
          }
      ],
      'listes': [
        for (final l in listes)
          if (l.statut == StatutListe.enConstruction || l.statut == StatutListe.prete)
            {
              'nom': nomListe(l),
              'magasin': magasin(l.magasinId)?.nom,
              'prete': l.statut == StatutListe.prete,
              'lignes': [
                for (final g in l.lignes)
                  if (produit(g.produitId) case final p?)
                    {'produit': p.nom, 'quantite': g.quantite, 'consigne': g.consigne}
              ],
            }
      ],
    };
  }

  /// Une fois les données du foyer reçues : les produits et les listes gardés sont ajoutés au foyer.
  /// Rend vrai si c'est fait (le foyer a des magasins), faux s'il faut attendre encore.
  bool reprendre(Map<String, dynamic> a) {
    if (magasins.isEmpty) return false;
    for (final x in (a['produits'] as List? ?? const []).cast<Map>()) {
      final nom = x['nom'] as String;
      if (Etat._trouve(produits, (p) => p.nom.toLowerCase() == nom.toLowerCase()) != null) continue;
      Secteur? s;
      final r = (x['rangement'] as String?)?.split('/');
      if (r != null && r.length == 2) {
        final ry = Etat._trouve(rayonsCatalogue, (y) => y.nom == r[0]);
        if (ry != null) s = Etat._trouve(secteursDu(ry.id), (y) => y.nom == r[1]);
      }
      final p = creerProduit(nom, secteur: s);
      for (final m in (x['marques'] as List? ?? const []).whereType<String>()) {
        p.marqueIds.add(marqueNommee(m).id);
      }
      for (final f in (x['formats'] as List? ?? const []).whereType<String>()) {
        p.packagingIds.add(_packagingNomme(f).id);
      }
    }
    for (final x in (a['listes'] as List? ?? const []).cast<Map>()) {
      final m = magasinNomme(x['magasin'] as String? ?? '') ?? magasins.first;
      final l = creerListe(m.id, []);
      l.nom = x['nom'] as String?;
      for (final g in (x['lignes'] as List? ?? const []).cast<Map>()) {
        final p = Etat._trouve(produits, (p) => p.nom.toLowerCase() == (g['produit'] as String).toLowerCase());
        if (p == null) continue;
        ajouterLigne(l, p.id);
        final ligne = l.lignes.last;
        ligne.quantite = (g['quantite'] as num?)?.toInt() ?? 1;
        ligne.consigne = g['consigne'] as String?;
      }
      if (x['prete'] == true) l.statut = StatutListe.prete;
    }
    modifie();
    return true;
  }
}
