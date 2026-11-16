part of '../modele.dart';

// Méthodes de l'état (EtatChargement), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatChargement on Etat {
  Stockage? get _actif => _foyer;

  /// Base des vraies données du foyer (la seule qui se synchronise).
  Stockage? get stockageFoyer => _foyer;

  String _chemin(String nom) => cheminBase(_dossier!, nom);

  Future<Map<String, dynamic>> _donneesDemo() async =>
      jsonDecode(await rootBundle.loadString(Etat.fichierDonnees)) as Map<String, dynamic>;

  /// Base illisible : gardée à part sur l'appareil ; au prochain lancement, on repart d'une base neuve
  /// (« Rejoindre un foyer » recharge alors tout depuis le serveur).
  Future<void> mettreBaseDeCote() async {
    if (_dossier == null) return;
    final f = _chemin(Etat.baseFoyer);
    if (baseExiste(f)) await mettreDeCote(f, '$f.endommagee-${Etat._horodatage()}');
  }

  /// Base du foyer (vraies données) et, en mode démonstration, base de démonstration.
  /// [dossier] : dossier des bases (essais) ; par défaut, celui de l'application.
  Future<void> charger({Directory? dossier}) async {
    if (enregistrementActif) {
      try {
        _dossier = await preparerDossierBases(dossier?.path);
        if (!await prendreVerrou()) {
          dejaOuverte = true;
          lire(await _donneesDemo());
          return;
        }
        _foyer = Stockage.ouvrir(_chemin(Etat.baseFoyer));
        await annoncerEtape('Vérification de la base', 0.35);
        await _reparerSiAbimee();
        await _reprendreDemonstration();
        await _ouvrirActif();
        noter('Ouverture ${versionApplication}${reparationBase == null ? '' : ' · $reparationBase'} · ${resumeBase()}');
        return;
      } catch (e, pile) {
        debugPrint('Base locale indisponible : $e');
        // Fermée, pour pouvoir la mettre de côté ensuite.
        try {
          _foyer?.fermer();
        } catch (_) {}
        _foyer = null;
        // Rien n'est montré ni enregistré : l'erreur s'affiche à la place de l'application (29/10/2026,
        // le web montrait les données d'essai et faisait croire la base perdue).
        erreurBase = '$e\n\n${pile.toString().split('\n').take(12).join('\n')}';
      }
    }
    lire(await _donneesDemo());
  }

  // ------------------------------------------------------------ Journal de l'appareil (01/11/2026)
  // Le web a perdu des modifications du catalogue entre deux ouvertures sans qu'on sache pourquoi : l'appareil
  // note à chaque ouverture et à chaque mise en arrière-plan l'état de sa base, hors de la base.

  /// Lignes du journal, la plus récente en premier.
  List<String> get journalAppareil {
    final d = _dossier;
    if (d == null) return const [];
    final t = lireJournal(d);
    return t.isEmpty ? const [] : t.split('\n');
  }

  /// Une erreur qui se répète à chaque enregistrement n'est notée qu'une fois par séance.
  void _noterUneFois(String texte) {
    if (_dejaNote.add(texte)) noter(texte);
  }

  void noter(String texte) {
    final d = _dossier;
    if (d == null || !enregistrementActif) return;
    final h = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    ecrireJournal(d, ['$h  $texte', ...journalAppareil.take(299)].join('\n'));
  }

  /// Ce que contient le foyer, en chiffres : pour comparer d'une ouverture à l'autre.
  String resumeBase() {
    final m = magasinReference;
    final nonPlaces = m == null ? 0 : produits.where((p) => produitVisible(p) && secteurDe(m.id, p.id) == null).length;
    return 'rayons ${rayonsCatalogue.length}, secteurs ${secteurs.length}, '
        'produits ${produits.length} (ajoutés ${produitsAjoutes.length}), non placés $nonPlaces, '
        'emplacements ${emplacements.length}, structure ajoutée ${structurePerso.length}, listes ${listes.length}';
  }

  /// Mise en arrière-plan ou fermeture : état de la base et des écritures sur le disque.
  void noterMiseEnRetrait() {
    final attente = kIsWeb ? ' · écritures sur le disque : ${disqueBloque ? 'BLOQUÉES' : 'à jour'}'
        '${derniereEcritureDisque == null ? '' : ', dernière à ${derniereEcritureDisque!.toIso8601String().substring(11, 19)}'}' : '';
    noter('Mise en arrière-plan · ${resumeBase()}$attente');
  }

  /// Base abîmée à l'ouverture : recopiée dans une base neuve, l'abîmée gardée à part sur l'appareil.
  Future<void> _reparerSiAbimee() async {
    final constat = _foyer!.verifier();
    if (constat == null) return;
    final chemin = _chemin(Etat.baseFoyer), neuve = '$chemin.reparee-${Etat._horodatage()}';
    final (n, echecs, pertes) = _foyer!.recopierDans(neuve);
    if (echecs.isNotEmpty) {
      // Une table illisible : la base neuve serait incomplète, on garde l'abîmée telle quelle.
      reparationBase = 'Base abîmée ($constat), réparation impossible : ${echecs.join(' ; ')}';
      return;
    }
    _foyer!.fermer();
    _foyer = null;
    await mettreDeCote(chemin, '$chemin.endommagee-${Etat._horodatage()}');
    await renommerBase(neuve, chemin);
    _foyer = Stockage.ouvrir(chemin);
    reparationBase = 'Base abîmée réparée au lancement ($constat) : $n lignes recopiées'
        '${pertes.isEmpty ? '' : ' (${pertes.join(' ; ')})'}, '
        'vérification : ${_foyer!.verifier() ?? 'ok'}';
  }

  /// Il n'y a plus de mode démonstration (24/10/2026). Un appareil qui l'affichait garde ce qu'il
  /// montrait : la base de démonstration devient celle du foyer, l'autre est gardée dans un fichier à part.
  Future<void> _reprendreDemonstration() async {
    final f = _foyer!;
    if (f.reglage('mode_demo') != '1') return;
    final demo = _chemin(Etat.baseDemo);
    f.definirReglage('mode_demo', '0');
    if (!baseExiste(demo)) return;
    f.fermer();
    await renommerBase(_chemin(Etat.baseFoyer), '${_chemin(Etat.baseFoyer)}.avant-fusion-${Etat._horodatage()}');
    await renommerBase(demo, _chemin(Etat.baseFoyer));
    _foyer = Stockage.ouvrir(_chemin(Etat.baseFoyer));
  }

  // Ouverture en un seul enregistrement (11/11/2026) : chaque modification de la préparation (magasins du
  // foyer neuf, exemples, démonstration, lots, formats…) réécrivait toute la base ; le premier lancement de la
  // démonstration en était ralenti de plusieurs secondes.
  Future<void> _ouvrirActif() async {
    final dejaEnLot = _enLot;
    _enLot = true;
    _modifieEnAttente = false;
    try {
      await _ouvrirActifEnLot();
    } finally {
      _enLot = dejaEnLot;
      if (_modifieEnAttente && !dejaEnLot) modifie();
    }
  }

  Future<void> _ouvrirActifEnLot() async {
    final s = _actif!;
    if (s.vide) {
      await annoncerEtape(demonstration ? 'Préparation du foyer d\u2019exemple' : 'Préparation du foyer', 0.35);
      lire(_depart(await _donneesDemo()));
      // Démonstration : seulement les trois magasins de son exemple (11/11/2026).
      if (demonstration) magasins.removeWhere((m) => !const ['Intermarché', 'Carrefour', 'Lidl'].contains(m.nom));
      // Une seule structure pour tous les magasins (12/11/2026).
      if (magasins.isNotEmpty) await appliquerModele(magasins.first, Etat.tailleComplete, catalogue: await CatalogueType.lireJson());
      creerExemples(enregistrer: false);
      if (demonstration) remplirDemonstration();
      s.ecrire(versJson());
    } else {
      await annoncerEtape('Lecture de vos listes', 0.5);
      lire(s.lire());
    }
    await annoncerEtape('Préparation', 0.75);
    // Types de mesure vides (types reçus avant leurs libellés, ou foyer rejoint) : on les reprend du catalogue.
    await reparerTypesMesure();
    await appliquerFormats();
    completerLots();
    // 12/11/2026 : une base à l'ancienne (un exemplaire de la structure par magasin) passe à la structure commune.
    unifierStructure();
    // 08/11/2026 : les anciens produits de marque (« Camembert Président ») deviennent des déclinaisons.
    reprendreProduitsDeMarque();
    // Historique de plus de trois mois (réglable) vers les archives, et archives trop anciennes supprimées.
    if (archiverAnciennes() | purgerArchives()) enregistrer();
    // Appareil partagé (tablette, PC de la famille) : on dit qui l'utilise à chaque lancement.
    choixPersonne = appareilPartage && membresVisibles.length > 1;
  }

  /// Trois listes exemples, dans le premier magasin : une en préparation, une prête, une course
  /// interrompue. Les exemples précédents sont remplacés.
  void creerExemples({bool enregistrer = true}) {
    if (magasins.isEmpty) return;
    listes.removeWhere((l) => (l.nom ?? '').startsWith(Etat.prefixeExemple) && l.statut != StatutListe.terminee);
    final m = Etat._trouve(magasins, (m) => m.nom == 'Intermarché') ?? magasins.first;
    final parNom = {for (final p in produits) p.nom.toLowerCase(): p};
    List<LigneListe> lignes(List<String> noms) => [
          for (final n in noms)
            if (parNom[n.toLowerCase()] case final p?) LigneListe(produitId: p.id)
        ];
    final maintenant = DateTime.now();
    Liste nouvelle(String nom, StatutListe statut, List<String> noms) {
      final l = Liste(
        id: nouvelId('l'),
        magasinId: m.id,
        statut: statut,
        dateCreation: maintenant,
        lignes: lignes(noms),
        modifieePar: moi.id,
        modifieeLe: maintenant,
        nom: '${Etat.prefixeExemple}$nom',
      );
      listes.add(l);
      return l;
    }

    nouvelle('liste en préparation', StatutListe.enConstruction, ['Lait demi-écrémé', 'Pain de mie', 'Beurre doux', 'Pommes', 'Yaourts nature', 'Café moulu']);
    nouvelle('liste prête pour les courses', StatutListe.prete, ['Pâtes spaghetti', 'Riz basmati', 'Tomates', 'Œufs', 'Emmental râpé', 'Papier toilette']);
    final enCours = nouvelle('courses en cours', StatutListe.enCours,
        ['Bananes', 'Carottes', 'Jambon blanc', 'Camembert', 'Eau minérale', 'Liquide vaisselle', 'Baguette']);
    enCours
      ..membreId = moi.id
      ..interrompueLe = maintenant;
    for (final g in enCours.lignes.take(2)) {
      g.cocheLe = maintenant;
      g.cochePar = moi.id;
    }
    if (enregistrer) modifie();
  }

  /// Premier lancement : un foyer vide, avec son créateur et un premier magasin (rempli d'après le catalogue complet).
  Map<String, dynamic> _depart(Map<String, dynamic> demo) {
    final auj = DateTime.now();
    const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hasard = Random.secure();
    final code = List.generate(6, (_) => lettres[hasard.nextInt(lettres.length)]).join();
    return {
      '_description': demo['_description'],
      '_ecartsModele': demo['_ecartsModele'],
      'foyer': {'id': nouvelId('f'), 'nom': 'Mon foyer', 'dateCreation': _iso(auj)!.substring(0, 10)},
      'membres': [
        {'id': nouvelId('m'), 'nomAffiche': 'Moi', 'role': 'administrateur', 'moi': true}
      ],
      'invitation': {'code': code, 'expiration': _iso(auj.add(const Duration(days: 7)))!.substring(0, 10)},
      'parametres': demo['parametres'],
      'typesPromotion': demo['typesPromotion'],
      'magasins': [
        for (final e in Etat.enseignesDeDepart) {'id': nouvelId('mg'), 'nom': e, 'enseigne': e, 'ville': ''}
      ],
      for (final cle in ['rayons', 'secteurs', 'marques', 'packagings', 'produits', 'emplacements', 'parcours', 'listes', 'historique', 'tickets'])
        cle: <dynamic>[],
      'frequencesPreliste': {'_regle': (demo['frequencesPreliste'] as Map?)?['_regle'] ?? ''},
    };
  }

  /// Modifications qui ne parviennent pas sur le disque (web : IndexedDB bloqué), ou lignes refusées par la
  /// base : affiché en bandeau rouge, pour ne pas perdre de travail sans le savoir. Null : tout est écrit.
  String? get alerteEnregistrement => disqueBloque
      ? 'Vos modifications ne sont plus écrites sur le disque. Ne fermez pas l\'application et prévenez Claude.'
      : null;

  /// Intègre les modifications reçues des autres appareils du foyer, puis relit la base.
  int integrerDistant(List<Map<String, dynamic>> objets) {
    final s = _foyer;
    if (s == null) return 0;
    enregistrer(); // ce qui vient d'être fait ici passe d'abord
    final n = s.appliquer(objets);
    if (n > 0) {
      lire(s.lire());
      // Objets venus d'un appareil pas encore à jour : rayons, secteurs et emplacements d'un magasin.
      unifierStructure();
      _retrouverMoi(s);
    }
    return n;
  }

  /// Rejoindre un foyer : les données de cet appareil sont mises de côté (fichier gardé)
  /// et remplacées par un foyer vide, avec [nom] comme membre, qui se remplit de ce que les autres envoient.
  Future<void> rejoindreFoyer(String nom, {String email = ''}) async {
    final demo = await _donneesDemo();
    if (_dossier == null) {
      lire(_depart(demo));
      return;
    }
    _foyer?.fermer();
    _foyer = null;
    final f = _chemin(Etat.baseFoyer);
    if (baseExiste(f)) await renommerBase(f, '$f.avant-partage-${Etat._horodatage()}');
    final s = _foyer = Stockage.ouvrir(_chemin(Etat.baseFoyer));
    final depart = _depart(demo);
    final moiJson = (depart['membres'] as List).first as Map;
    moiJson['nomAffiche'] = nom.trim().isEmpty ? 'Nouvel appareil' : nom.trim();
    moiJson['role'] = 'membre';
    moiJson['email'] = email.trim();
    depart['magasins'] = <dynamic>[];
    depart['parametres'] = {
      ...(demo['parametres'] as Map? ?? {}),
      'options': {'formats': 1, 'typesPackaging': <String>[]},
    };
    s.ecrire(depart); // avant la synchronisation : rien de ceci ne part vers les autres
    s.definirReglage('synchro_membre_provisoire', moiJson['id'] as String);
    lire(s.lire());
  }

  /// Membre provisoire de cet appareil, en attendant que la personne choisisse son nom.
  bool get moiProvisoire => _foyer?.reglage('synchro_membre_provisoire') == moi.id;

  Map<String, dynamic> versJson() => {
        '_description': _brut['_description'],
        '_ecartsModele': _brut['_ecartsModele'],
        'foyer': {'id': foyerId, 'nom': foyerNom, 'dateCreation': _iso(foyerCreation)!.substring(0, 10)},
        'membres': [
          for (final m in membres)
            {'id': m.id, 'nomAffiche': m.nomAffiche, 'role': m.role, 'moi': m.moi, if (m.email.isNotEmpty) 'email': m.email}
        ],
        'invitation': {'code': invitationCode, 'expiration': _iso(invitationExpiration)!.substring(0, 10)},
        'parametres': {
          'preliste': {'presencesMin': prelistePresencesMin, 'sur': prelisteSur},
          'options': {
            'parSecteurs': parSecteurs,
            'envoiFoyer': envoiFoyer,
            'ajoutParRecherche': ajoutParRecherche,
            'modePreparation': modePreparation,
            'delaiHistorique': delaiHistorique,
            if (archivees.isNotEmpty) 'archivees': archivees.toList(),
            if (gardeesEnHistorique.isNotEmpty) 'gardeesEnHistorique': gardeesEnHistorique.toList(),
            if (imagesChoisies.isNotEmpty) 'images': imagesChoisies,
            if (couleurs.isNotEmpty) 'couleurs': couleurs,
            if (apprentissage.isNotEmpty) 'apprentissage': apprentissage.toList(),
            if (sansTicket.isNotEmpty) 'sansTicket': sansTicket.toList(),
            if (terminees2) 'terminees2': true,
            if (commentaires.isNotEmpty) 'commentaires': commentaires,
            if (manquants.isNotEmpty) 'manquants': {for (final e in manquants.entries) e.key: e.value.toList()},
            if (simples.isNotEmpty) 'simples': simples.toList(),
            if (datesPrevues.isNotEmpty) 'datesPrevues': datesPrevues,
            if (libellesTickets.isNotEmpty) 'libellesTickets': libellesTickets,
            if (ticketsImage.isNotEmpty) 'ticketsImage': ticketsImage.toList(),
            if (nonRangees.isNotEmpty) 'nonRangees': nonRangees.toList(),
            if (listesTypes.isNotEmpty) 'listesTypes': [for (final t in listesTypes) t.toJson()],
            if (parcoursAppris.isNotEmpty) 'parcoursAppris': parcoursAppris.toList(),
            if (parcoursFusionnes.isNotEmpty) 'parcoursFusionnes': parcoursFusionnes.toList(),
            if (datesParcours.isNotEmpty) 'datesParcours': {for (final e in datesParcours.entries) e.key: e.value.toIso8601String()},
            if (passagesParcours.isNotEmpty) 'passagesParcours': passagesParcours,
            if (produitsPerso.isNotEmpty) 'produitsPerso': produitsPerso,
            if (marquesSecteurs.isNotEmpty) 'marquesSecteurs': marquesSecteurs,
            if (statutsMembres.isNotEmpty) 'statutsMembres': statutsMembres,
            if (structurePerso.isNotEmpty) 'structurePerso': structurePerso.toList()..sort(),
            if (universRayons.isNotEmpty) 'universRayons': universRayons,
            if (renommages.isNotEmpty) 'renommages': renommages,
            if (nomsUnivers.isNotEmpty) 'nomsUnivers': nomsUnivers,
            if (ordreRayons.isNotEmpty) 'ordreRayons': ordreRayons,
            if (masques.isNotEmpty) 'masques': masques.toList()..sort(),
            if (deplacesFoyer.isNotEmpty) 'deplacesFoyer': deplacesFoyer.toList()..sort(),
            if (idApports != null) 'idApports': idApports,
            if (structureRecue.isNotEmpty) 'structureRecue': structureRecue.toList()..sort(),
            if (marquesRecues.isNotEmpty) 'marquesRecues': marquesRecues,
            if (exclusCommun.isNotEmpty) 'exclusCommun': exclusCommun.toList()..sort(),
            if (signalements.isNotEmpty) 'signalements': signalements.toList()..sort(),
            if (foyersBloques.isNotEmpty) 'foyersBloques': foyersBloques.toList()..sort(),
            'typesPackaging': typesPackaging,
            if (magasinsArchives.isNotEmpty) 'magasinsArchives': [for (final m in magasinsArchives) m.id],
            if (delaiArchives > 0) 'delaiArchives': delaiArchives,
            if (apparence != null) 'apparence': apparence,
            if (!iconesListes) 'iconesListes': false,
            if (debordIcones != 'normal') 'debordIcones': debordIcones,
            if (saisonFond != 'auto') 'saisonFond': saisonFond,
            if (formatsAppliques) 'formats': 1,
            if (lotsCompletes) 'lots': 1,
            if (magasinsEnseignes) 'magasinsEnseignes': 1,
            if (versionCatalogueCommun > 0) 'catalogueCommun': versionCatalogueCommun,
            if (numeroCatalogueCommun > 0) 'catalogueCommunNumero': numeroCatalogueCommun,
            if (nomVersionCatalogueCommun.isNotEmpty) 'catalogueCommunLibelle': nomVersionCatalogueCommun,
            if (nouveautesCatalogue != null) 'nouveautesCatalogue': nouveautesCatalogue,
          },
        },
        'typesPromotion': [for (final t in typesPromotion) t.toJson()],
        'magasins': [
          for (final m in magasins) {'id': m.id, 'nom': m.nom, 'enseigne': m.enseigne, 'ville': m.ville},
          for (final m in magasinsArchives) {'id': m.id, 'nom': m.nom, 'enseigne': m.enseigne, 'ville': m.ville, 'archive': true},
        ],
        'rayons': [for (final r in rayons) {'id': r.id, 'magasinId': r.magasinId, 'nom': r.nom}],
        'secteurs': [for (final s in secteurs) {'id': s.id, 'rayonId': s.rayonId, 'nom': s.nom}],
        'marques': [for (final m in marques) {'id': m.id, 'nom': m.nom}],
        'packagings': [for (final k in packagings) {'id': k.id, 'libelle': k.libelle}],
        'produits': [
          for (final p in produits)
            {'id': p.id, 'nom': p.nom, 'marqueIds': p.marqueIds, 'packagingIds': p.packagingIds, 'nbUtilisations': p.nbUtilisations}
        ],
        'emplacements': [
          for (final e in emplacements) {'magasinId': e.magasinId, 'produitId': e.produitId, 'secteurId': e.secteurId}
        ],
        'parcours': [
          for (final p in parcours)
            {'id': p.id, 'magasinId': p.magasinId, 'membreId': p.membreId, 'nom': p.nom, 'parDefaut': p.parDefaut, 'etapes': p.etapes}
        ],
        'listes': [for (final l in listes) l.toJson()],
        'historique': [
          for (final h in historique)
            {'id': h.id, 'magasinId': h.magasinId, 'dateCourses': _iso(h.dateCourses)!.substring(0, 10), 'membreId': h.membreId, 'nbArticles': h.nbArticles, if (h.nom != null) 'nom': h.nom}
        ],
        'tickets': [
          for (final t in tickets)
            {'id': t.id, 'listeId': t.listeId, 'magasinId': t.magasinId, 'date': _iso(t.date)!.substring(0, 10), 'montant': t.montant, 'source': t.source}
        ],
        'frequencesPreliste': {'_regle': regleFrequence, ...frequences},
        'corbeille': [for (final c in corbeille) c.toJson()],
        'rectificatives': [for (final r in rectificatives.values) r.toJson()],
      };
}
