part of '../modele.dart';

// Méthodes de l'état (EtatCorbeille), sorties de la classe Etat le 16/11/2026, sans changement.

extension EtatCorbeille on Etat {

  // ------------------------------------------------------------ Suppression et corbeille

  /// Raison pour laquelle [objet] ne peut pas être supprimé, ou null.
  String? suppressionImpossible(Object objet) {
    if (objet is Magasin) {
      if (magasins.contains(objet) && magasins.length <= 1) return 'C\'est le seul magasin : créez-en un autre avant de le supprimer.';

    }
    if (objet is Produit && produitUtilise(objet)) return 'Ce produit est dans une liste : retirez-le d\'abord de la liste pour pouvoir le supprimer.';
    return null;
  }

  /// Ce qu'emporte la suppression de [objet], en clair (pour la confirmation).
  String consequences(Object objet) {
    String n(int x, String mot) => '$x $mot${x > 1 ? 's' : ''}';
    if (objet is Magasin) {
      if (estArchive(objet.id)) {
        return 'Ses ${n(listesArchivees(objet.id).length, 'course')} archivée${listesArchivees(objet.id).length > 1 ? 's' : ''} seront supprimées.';
      }
      final l = listes.where((x) => x.magasinId == objet.id && x.statut != StatutListe.terminee).length;
      return 'Avec ${n(parcours.where((p) => p.magasinId == objet.id).length, 'parcours')} '
          'et ${l == 0 ? 'aucune liste en cours' : '${n(l, 'liste')} en cours, effacée${l > 1 ? 's' : ''} aussi'}.'
          '${aUnHistorique(objet) ? ' Son historique de courses part dans Courses › Archives.' : ''}';
    }
    if (objet is Rayon) {
      return 'Avec ${n(secteursDu(objet.id).length, 'secteur')} ; ses produits deviennent « non placés ».';
    }
    if (objet is Secteur) return 'Ses ${n(produitsDu(magasinCommun, objet.id).length, 'produit')} deviennent « non placés ».';
    return '';
  }

  /// Supprime [objet] et ce qui en dépend ; le tout va dans la corbeille.
  void supprimer(Object objet) {
    final j = versJson();
    final retires = <String, List<dynamic>>{};
    void retirer(String collection, bool Function(Map o) test) {
      final l = (j[collection] as List).cast<Map>();
      final partis = l.where(test).toList();
      if (partis.isEmpty) return;
      (retires[collection] ??= []).addAll(partis);
      l.removeWhere(test);
    }

    void retirerSecteurs(Set<String> ids) {
      retirer('secteurs', (o) => ids.contains(o['id']));
      retirer('emplacements', (o) => ids.contains(o['secteurId']));
      // Les parcours gardent leurs autres étapes.
      for (final p in (j['parcours'] as List).cast<Map>()) {
        (p['etapes'] as List).removeWhere(ids.contains);
      }
    }

    late String type, libelle;
    if (objet is Magasin) {
      type = 'magasin';
      libelle = objet.nom;
      // 12/11/2026 : les rayons, secteurs et emplacements sont communs, ils restent.
      retirer('magasins', (o) => o['id'] == objet.id);
      retirer('parcours', (o) => o['magasinId'] == objet.id);
      final archive = estArchive(objet.id);
      retirer('listes', (o) => o['magasinId'] == objet.id && (archive || o['statut'] != StatutListe.terminee.name));
      if (archive) {
        retirer('historique', (o) => o['magasinId'] == objet.id);
      } else if (aUnHistorique(objet)) {
        // L'historique reste : le magasin passe dans les archives.
        (j['magasins'] as List).add({'id': objet.id, 'nom': objet.nom, 'enseigne': objet.enseigne, 'ville': objet.ville, 'archive': true});
        libelle = '${objet.nom} (historique gardé dans les archives)';
      }
    } else if (objet is Rayon) {
      type = 'rayon';
      libelle = objet.nom;
      retirer('rayons', (o) => o['id'] == objet.id);
      retirerSecteurs(secteursDu(objet.id).map((s) => s.id).toSet());
    } else if (objet is Secteur) {
      type = 'secteur';
      libelle = '${objet.nom} · ${rayon(objet.rayonId)?.nom ?? ''}';
      retirerSecteurs({objet.id});
    } else if (objet is Produit) {
      type = 'produit';
      libelle = objet.nom;
      retirer('produits', (o) => o['id'] == objet.id);
      retirer('emplacements', (o) => o['produitId'] == objet.id);
    } else if (objet is Course) {
      // 03/11/2026 : une course de l'historique se supprime (glissement à gauche), sa liste avec elle.
      type = 'liste';
      libelle = 'Courses ${nomCourse(objet)} · ${objet.nbArticles} articles';
      retirer('listes', (o) => o['id'] == objet.id);
      retirer('historique', (o) => o['id'] == objet.id);
    } else if (objet is Liste) {
      type = 'liste';
      libelle = 'Liste ${nomListe(objet)} · ${objet.lignes.length} articles';
      retirer('listes', (o) => o['id'] == objet.id);
      retirer('historique', (o) => o['id'] == objet.id);
    } else if (objet is Parcours) {
      type = 'parcours';
      libelle = 'Parcours ${objet.nom} · ${magasin(objet.magasinId)?.nom ?? ''}';
      retirer('parcours', (o) => o['id'] == objet.id);
    } else {
      return;
    }
    (j['corbeille'] as List).insert(0, ElementCorbeille(nouvelId('cb'), type, libelle, DateTime.now(), retires).toJson());
    lire(j);
    enregistrer();
  }

  /// Ce qui manque pour restaurer [c] (son magasin, son rayon…), ou null.
  String? restaurationImpossible(ElementCorbeille c) {
    final contenu = c.contenu;
    final ids = <String>{for (final l in contenu.values) for (final o in (l as List).cast<Map>()) if (o['id'] != null) o['id'] as String};
    bool existe(String? id) => id == null || id == magasinCommun || ids.contains(id) || magasin(id) != null || rayon(id) != null;
    for (final o in (contenu['rayons'] as List? ?? []).cast<Map>()) {
      if (!existe(o['magasinId'] as String?)) return 'Restaurez d\'abord le magasin de ce rayon.';
    }
    for (final o in (contenu['secteurs'] as List? ?? []).cast<Map>()) {
      if (!existe(o['rayonId'] as String?)) return 'Restaurez d\'abord le rayon de ce secteur.';
    }
    for (final o in [...(contenu['listes'] as List? ?? []), ...(contenu['parcours'] as List? ?? [])].cast<Map>()) {
      if (!existe(o['magasinId'] as String?)) return 'Restaurez d\'abord le magasin.';
    }
    return null;
  }

  /// Remet en place un élément de la corbeille.
  void restaurer(ElementCorbeille c) {
    if (restaurationImpossible(c) != null) return;
    final j = versJson();
    c.contenu.forEach((collection, objets) {
      final l = <dynamic>[...j[collection] as List];
      for (final o in objets as List) {
        final id = (o as Map)['id'];
        if (id == null || !l.any((x) => (x as Map)['id'] == id)) l.add(o);
      }
      j[collection] = l;
    });
    (j['corbeille'] as List).removeWhere((x) => (x as Map)['id'] == c.id);
    lire(j);
    unifierStructure(); // élément mis à la corbeille avant le 12/11/2026 : rayons et secteurs d'un magasin
    enregistrer();
  }

  /// Vide la corbeille : ce qu'elle contient ne pourra plus être remis.
  void viderCorbeille() {
    corbeille.clear();
    modifie();
  }
}
