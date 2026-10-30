import 'dart:math';

import 'modele.dart';

/// Version de démonstration (compilée avec --dart-define=DEMONSTRATION=true, publiée à part sur
/// …/liste-de-courses/demo/) : base séparée, sans partage, sans mail direct, remplie d'exemples.
const demonstration = bool.fromEnvironment('DEMONSTRATION');

/// Foyer de démonstration (30/10/2026) : quatre membres, trois magasins avec leur parcours appris,
/// deux mois de courses avec tickets, des listes à tous les stades, des listes types,
/// des promotions, des marques et des consignes. Créé au premier lancement (et par « Foyer neuf »).
extension FoyerDemonstration on Etat {
  void remplirDemonstration() {
    final hasard = Random(7);
    final maintenant = DateTime.now();
    foyerNom = 'Famille Martin';
    moi.nomAffiche = 'Claire';
    moi.email = 'claire.martin@exemple.fr';
    final thomas = ajouterMembre('Thomas', 'thomas.martin@exemple.fr');
    final lea = ajouterMembre('Léa', 'lea.martin@exemple.fr');
    final hugo = ajouterMembre('Hugo', '');
    final claire = moi;

    Magasin magasinNomme(String nom) => magasins.firstWhere((m) => m.nom == nom, orElse: () => magasins.first);
    final inter = magasinNomme('Intermarché'), carrefour = magasinNomme('Carrefour'), lidl = magasinNomme('Lidl');
    inter.nom = 'Intermarché Les Halles';
    carrefour.nom = 'Carrefour Grand Large';
    lidl.nom = 'Lidl centre-ville';
    // Les exemples ordinaires du premier lancement laissent la place à ceux de la démonstration.
    listes.clear();

    final parNom = {for (final p in produits) p.nom.toLowerCase(): p};
    List<LigneListe> lignes(List<String> noms) => [
          for (final n in noms)
            if (parNom[n.toLowerCase()] case final p?) LigneListe(produitId: p.id, quantite: 1)
        ];

    // Ordre de visite propre à chaque magasin : les rayons mélangés une fois pour toutes.
    final ordreMagasin = <String, Map<String, int>>{};
    int rangSecteur(Magasin m, String produitId) {
      final ordre = ordreMagasin.putIfAbsent(m.id, () {
        final rs = rayons.where((r) => r.magasinId == m.id).toList()..shuffle(hasard);
        // Fruits et légumes à l'entrée, comme dans la plupart des magasins.
        rs.sort((a, b) => (b.nom.startsWith('Fruits') ? 1 : 0) - (a.nom.startsWith('Fruits') ? 1 : 0));
        return {for (var i = 0; i < rs.length; i++) rs[i].id: i};
      });
      final s = secteurDe(m.id, produitId);
      if (s == null) return 1 << 20;
      final rang = ordre[s.rayonId] ?? 999;
      return rang * 1000 + secteurs.indexOf(s) % 1000;
    }

    Liste nouvelle(Magasin m, String? nom, StatutListe statut, List<String> noms, DateTime le, Membre par) {
      final l = Liste(
        id: nouvelId('l'),
        magasinId: m.id,
        statut: statut,
        dateCreation: le,
        lignes: lignes(noms),
        modifieePar: par.id,
        modifieeLe: le,
        nom: nom,
      );
      for (final g in l.lignes) {
        produit(g.produitId)?.nbUtilisations++;
      }
      listes.add(l);
      return l;
    }

    // Coche les articles dans l'ordre du magasin, à partir de [debut] (une à trois minutes entre deux).
    void cocherDansLOrdre(Liste l, Membre qui, DateTime debut, {int? combien}) {
      final m = magasin(l.magasinId)!;
      final ordre = [...l.lignes]..sort((a, b) => rangSecteur(m, a.produitId).compareTo(rangSecteur(m, b.produitId)));
      var t = debut;
      for (final g in ordre.take(combien ?? ordre.length)) {
        t = t.add(Duration(seconds: 60 + hasard.nextInt(120)));
        g.cocheLe = t;
        g.cochePar = qui.id;
      }
    }

    void quantite(Liste l, String nom, int q) {
      for (final g in l.lignes) {
        if (produit(g.produitId)?.nom == nom) g.quantite = q;
      }
    }

    // ---- Deux mois de courses terminées, avec leur ticket
    const paniers = [
      ['Bananes', 'Pommes', 'Tomates', 'Salade verte', 'Carottes', 'Lait demi-écrémé', 'Œufs', 'Beurre', 'Yaourts nature',
        'Emmental râpé', 'Jambon blanc supérieur sans nitrite', 'Pâtes spaghetti', 'Pain de mie', 'Café moulu', 'Papier toilette',
        'Eau plate', 'Liquide vaisselle', 'Camembert'],
      ['Courgettes', 'Oignons', 'Ail', 'Poivrons', 'Haché 5 %', 'Pâtes à lasagnes', 'Pulpe de tomate', 'Mozzarella', 'Pâte à pizza',
        'Jus d\'orange', 'Croissants', 'Skyr', 'Essuie-tout', 'Éponges'],
      ['Citrons', 'Avocats', 'Tomates cerises', 'Saumon fumé', 'Crevettes cuites', 'Toasts apéritif', 'Chips allégées',
        'Cacahuètes', 'Bière blonde', 'Vin blanc', 'Pétillant sans alcool', 'Glace vanille-fraise', 'Feta', 'Concombre'],
      ['Pommes de terre', 'Filets de dinde', 'Cuisses de poulet', 'Riz basmati', 'Lait demi-écrémé', 'Œufs plein air', 'Farine',
        'Sucre en poudre', 'Huile d\'olive', 'Moutarde', 'Mayonnaise', 'Ketchup', 'Croquettes pour chat', 'Lessive liquide', 'Shampooing'],
      ['Fraises Gariguette', 'Kiwis jaunes', 'Mandarines', 'Brugnons', 'Melon', 'Surimi', 'Entrecôte', 'Magret de canard',
        'Roquefort', 'Sainte-Maure', 'Baguette', 'Viennoiseries fraîches', 'Eau gazeuse', 'Cola zéro', 'Tablette de chocolat noir'],
    ];
    final tournees = [
      (inter, claire, 58), (lidl, thomas, 54), (inter, claire, 51), (carrefour, lea, 47), (inter, thomas, 44), (lidl, claire, 40),
      (inter, claire, 37), (carrefour, claire, 33), (inter, thomas, 30), (lidl, lea, 26), (inter, claire, 23), (carrefour, thomas, 19),
      (inter, claire, 16), (lidl, thomas, 12), (inter, lea, 9), (carrefour, claire, 5), (inter, claire, 2),
    ];
    for (var i = 0; i < tournees.length; i++) {
      final (m, qui, ilYA) = tournees[i];
      final jour = DateTime(maintenant.year, maintenant.month, maintenant.day - ilYA, 9 + hasard.nextInt(9), hasard.nextInt(60));
      final panier = [...paniers[i % paniers.length], ...paniers[(i + 2) % paniers.length].take(4 + hasard.nextInt(5))];
      final l = nouvelle(m, i % 4 == 1 ? 'Courses du samedi' : null, StatutListe.terminee, panier.toSet().toList(),
          jour.subtract(const Duration(days: 2)), qui)
        ..membreId = qui.id;
      // Quelques articles restent sans coche (pas en rayon, oubliés…)
      final oublis = hasard.nextInt(3);
      cocherDansLOrdre(l, qui, jour, combien: l.lignes.length - oublis);
      // Premières courses de chacun dans un magasin : le parcours s'apprend ; ensuite, il s'enrichit.
      apprentissage.add(l.id);
      retenirParcours(l);
      final c = Course(l.id, m.id, jour.add(Duration(minutes: 20 + l.lignes.length * 2)), qui.id, l.nbCoches, nom: l.nom);
      historique.add(c);
      final t = Ticket(nouvelId('t'), c.id, m.id, c.dateCourses, 0, 'photo');
      t.montant = double.parse((l.nbCoches * (3.1 + hasard.nextDouble() * 2.4)).toStringAsFixed(2));
      tickets.add(t);
    }
    historique.sort((a, b) => b.dateCourses.compareTo(a.dateCourses));
    // Un ticket arrivé sans course choisie
    tickets.add(Ticket(nouvelId('t'), null, lidl.id, maintenant.subtract(const Duration(days: 1)), 23.47, 'photo'));

    // ---- Listes types
    final petitDej = nouvelle(inter, null, StatutListe.terminee, ['Lait demi-écrémé', 'Pain de mie', 'Beurre', 'Confipote myrtilles',
      'Café moulu', 'Jus d\'orange', 'Croissants', 'Nesquik', 'Yaourts nature'], maintenant, claire);
    enregistrerListeType(petitDej, 'Petit-déjeuner');
    final menage = nouvelle(inter, null, StatutListe.terminee, ['Papier toilette', 'Essuie-tout', 'Liquide vaisselle', 'Éponges',
      'Lessive liquide', 'Blocs WC', 'Sacs poubelle'], maintenant, claire);
    enregistrerListeType(menage, 'Ménage du mois');
    final chat = nouvelle(lidl, null, StatutListe.terminee, ['Croquettes pour chat', 'Sachets en sauce pour chat',
      'Sachets en gelée pour chat', 'Litière'], maintenant, thomas);
    enregistrerListeType(chat, 'Pour Mistigri');
    listes..remove(petitDej)..remove(menage)..remove(chat);

    // ---- Listes en cours de vie
    final semaine = nouvelle(inter, 'Courses de la semaine', StatutListe.enConstruction, [
      'Bananes', 'Pommes', 'Tomates grappes', 'Courgettes', 'Salade verte', 'Lait demi-écrémé', 'Œufs plein air', 'Beurre',
      'Camembert', 'Yaourts nature', 'Jambon blanc supérieur sans nitrite', 'Pâtes coquillettes', 'Pain de mie', 'Café moulu',
      'Eau plate', 'Papier toilette', 'Liquide vaisselle',
    ], maintenant.subtract(const Duration(hours: 5)), claire);
    quantite(semaine, 'Eau plate', 2);
    quantite(semaine, 'Yaourts nature', 2);
    definirPromotion(semaine, parNom['eau plate']!.id,
        PromotionLigne('lot', {'quantiteAchetee': 6, 'quantiteOfferte': 2}, '6 achetés = 2 offerts'));
    definirPromotion(semaine, parNom['café moulu']!.id, PromotionLigne('remise', {'pourcentage': 30}, '−30 %'));
    definirPromotion(semaine, parNom['papier toilette']!.id,
        PromotionLigne('prixGlobal', {'quantiteMinimale': 2, 'avantage': '7 €'}, '2 pour 7 €'));
    definirConsigne(semaine, parNom['bananes']!.id, 'Pas trop mûres');
    definirConsigne(semaine, parNom['salade verte']!.id, 'Une batavia si possible');
    final camembert = parNom['camembert']!;
    changerMarque(semaine, camembert, 'Président');
    semaine.modifieePar = lea.id;

    final anniv = nouvelle(carrefour, 'Anniversaire de Léa', StatutListe.prete, [
      'Farine', 'Sucre en poudre', 'Œufs', 'Beurre', 'Levure chimique', 'Tablette de chocolat noir', 'Fraises Gariguette',
      'Glace vanille-fraise', 'Bonbons menthe sans sucre', 'Pétillant sans alcool', 'Cola', 'Chips allégées', 'Tortillas chips',
      'Bougies d\'anniversaire', 'Assiettes en carton', 'Serviettes en papier',
    ], maintenant.subtract(const Duration(days: 1)), lea);
    quantite(anniv, 'Pétillant sans alcool', 3);
    quantite(anniv, 'Chips allégées', 2);
    definirPromotion(anniv, parNom['cola']!.id, PromotionLigne('lot', {'quantiteAchetee': 2, 'remiseDernier': 50}, '2e à −50 %'));
    definirConsigne(anniv, parNom['tablette de chocolat noir']!.id, '70 % minimum, pour le gâteau');
    anniv.modifieePar = lea.id;

    final depannage = nouvelle(lidl, 'Dépannage', StatutListe.enCours, [
      'Pain', 'Lait demi-écrémé', 'Bananes', 'Jambon blanc supérieur sans nitrite', 'Emmental râpé', 'Pâtes spaghetti',
      'Pulpe de tomate', 'Croquettes pour chat', 'Eau gazeuse',
    ], maintenant.subtract(const Duration(hours: 2)), thomas)
      ..membreId = thomas.id
      ..parcoursId = parcoursDe(lidl.id, thomas.id).firstOrNull?.id;
    cocherDansLOrdre(depannage, thomas, maintenant.subtract(const Duration(minutes: 25)), combien: 4);

    final apero = nouvelle(carrefour, 'Apéro de samedi', StatutListe.enConstruction, [
      'Tomates cerises', 'Avocats', 'Citrons', 'Saumon fumé', 'Crevettes roses', 'Toasts apéritif', 'Tapenade noire',
      'Cacahuètes', 'Monster Munch', 'Bière blonde', 'Vin de Bordeaux', 'Champagne',
    ], maintenant.subtract(const Duration(minutes: 40)), hugo);
    quantite(apero, 'Bière blonde', 2);
    definirPromotion(apero, parNom['champagne']!.id, PromotionLigne('remise', {'montant': 5}, '−5 €'));
    apero.modifieePar = hugo.id;

    modifie();
  }
}
