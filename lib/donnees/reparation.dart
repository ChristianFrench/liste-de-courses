// Réparation des emplacements perdus (12/11/2026).
//
// La conversion vers la structure commune (version 511c095) n'avait pas créé, dans les bases existantes, le
// magasin fictif « Structure commune » : au premier enregistrement, tous les emplacements (le secteur de chaque
// produit) ont été effacés comme orphelins, puis l'effacement est parti vers les autres appareils du foyer.
// Les rayons, secteurs, produits, listes et parcours étaient intacts.
//
// À l'ouverture, quand la plupart des produits n'ont plus de secteur, chaque produit est replacé :
// 1. d'après les copies de sauvegarde de l'appareil qui avaient encore leurs emplacements (secteur retrouvé par
//    les noms du rayon et du secteur) : c'est la seule source pour les produits ajoutés ou déplacés par le foyer ;
// 2. sinon d'après le catalogue commun (le dernier reçu, ou celui livré avec l'application), par nom.

import 'catalogue_commun.dart';
import 'modele.dart';
import 'sauvegarde.dart';

/// Réglage de l'appareil : réparation déjà tentée.
const _reglageFait = 'reparation_emplacements_1211';

/// Vrai quand la base a besoin de la réparation : beaucoup de produits, presque aucun placé.
bool emplacementsPerdus(Etat etat) {
  final visibles = etat.produitsVisibles;
  if (visibles.length < 20) return false;
  final places = {for (final e in etat.emplacements) e.produitId};
  final n = visibles.where((p) => places.contains(p.id)).length;
  return n < visibles.length / 2;
}

/// Lancée à l'ouverture (main.dart). Rend le nombre de produits replacés, ou null si rien n'était à faire.
Future<int?> reparerEmplacementsPerdus() async {
  final etat = Etat.instance;
  final stockage = etat.stockageFoyer;
  if (stockage == null || stockage.reglage(_reglageFait) == '1' || !emplacementsPerdus(etat)) return null;
  final copies = <Map<String, dynamic>>[];
  try {
    for (final c in await Sauvegarde.instance.liste()) {
      final d = await Sauvegarde.instance.ouvrir(c);
      if (d != null && (d['emplacements'] as List? ?? const []).isNotEmpty) copies.add(d);
    }
  } catch (e) {
    etat.noter('Réparation des emplacements : copies illisibles ($e)');
  }
  Map<String, dynamic>? catalogue;
  try {
    catalogue = await CatalogueCommun.instance.dernier();
  } catch (_) {}
  final r = etat.reparerEmplacements(copies: copies, catalogue: catalogue);
  stockage.definirReglage(_reglageFait, '1');
  etat.noter('Réparation des emplacements : ${r.copies} produits replacés d\'après ${copies.length} sauvegarde(s), '
      '${r.catalogue} d\'après le catalogue commun, ${r.restants} encore sans secteur');
  return r.copies + r.catalogue;
}

extension ReparationEmplacements on Etat {
  /// Replace les produits sans secteur : d'abord d'après les [copies] (la plus récente d'abord), puis d'après
  /// le [catalogue] commun.
  ({int copies, int catalogue, int restants}) reparerEmplacements({
    List<Map<String, dynamic>> copies = const [],
    Map<String, dynamic>? catalogue,
  }) {
    // Secteurs actuels par « rayon|secteur ».
    final rayonNom = {for (final r in rayons) r.id: r.nom};
    final secteurParNoms = <String, String>{};
    for (final s in secteurs) {
      if (rayonNom[s.rayonId] case final rn?) secteurParNoms.putIfAbsent('$rn|${s.nom}', () => s.id);
    }
    final places = {for (final e in emplacements) e.produitId};
    final aPlacer = {for (final p in produits) if (!places.contains(p.id)) p.id: p};
    var parCopies = 0, parCatalogue = 0;

    void placerIci(String produitId, String secteurId) {
      // Produit sans emplacement : ajouté directement, un seul enregistrement à la fin.
      emplacements.add(Emplacement(magasinCommun, produitId, secteurId));
      aPlacer.remove(produitId);
    }

    // 1. Sauvegardes : le secteur le plus fréquent du produit parmi les magasins de la copie.
    for (final d in copies) {
      if (aPlacer.isEmpty) break;
      final rn = {for (final r in (d['rayons'] as List? ?? const []).cast<Map>()) r['id']: r['nom']};
      final sn = {
        for (final s in (d['secteurs'] as List? ?? const []).cast<Map>()) s['id']: '${rn[s['rayonId']]}|${s['nom']}'
      };
      final votes = <String, Map<String, int>>{};
      for (final e in (d['emplacements'] as List).cast<Map>()) {
        final p = e['produitId'] as String?;
        if (p == null || !aPlacer.containsKey(p)) continue;
        final cible = secteurParNoms[sn[e['secteurId']]];
        if (cible == null) continue;
        final v = votes[p] ??= {};
        v[cible] = (v[cible] ?? 0) + 1;
      }
      for (final pv in votes.entries) {
        final choix = (pv.value.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key))).first.key;
        placerIci(pv.key, choix);
        parCopies++;
      }
    }

    // 2. Catalogue commun, par nom (rayons et secteurs renommés par le foyer : leurs nouveaux noms).
    if (catalogue != null && aPlacer.isNotEmpty) {
      final parNom = <String, List<String>>{};
      for (final p in aPlacer.values) {
        parNom.putIfAbsent(p.nom.trim().toLowerCase(), () => []).add(p.id);
      }
      // Même ordre sur tous les appareils (l'ordre de la base, lui, diffère de l'un à l'autre).
      for (final ids in parNom.values) {
        ids.sort();
      }
      for (final r in (catalogue['rayons'] as List? ?? const []).whereType<Map>()) {
        final ro = r['nom'] as String? ?? '';
        final rayonIci = renommages['r:$ro'] ?? ro;
        for (final s in (r['secteurs'] as List? ?? const []).whereType<Map>()) {
          final so = s['nom'] as String? ?? '';
          final secteurIci = renommages['s:$ro/$so'] ?? so;
          final cible = secteurParNoms['$rayonIci|$secteurIci'];
          if (cible == null) continue;
          for (final p in (s['produits'] as List? ?? const [])) {
            final nom = (p is Map ? p['nom'] as String? : p as String?)?.trim().toLowerCase();
            final ids = nom == null ? null : parNom[nom];
            if (ids == null || ids.isEmpty) continue;
            // Un même nom dans deux secteurs (libre-service, au comptoir) : un produit pour chacun.
            placerIci(ids.removeAt(0), cible);
            parCatalogue++;
          }
        }
      }
    }
    if (parCopies + parCatalogue > 0) modifie();
    return (copies: parCopies, catalogue: parCatalogue, restants: aPlacer.length);
  }
}

// Homonymes du catalogue (12/11/2026, Aristide : « Crevettes cuites » deux fois en libre-service, aucune au
// comptoir, sur l'APK, l'exe et le web ; l'éditeur, lui, est juste). Les appareils du foyer avaient replacé
// les deux produits de même nom dans un ordre différent ; la synchronisation a mêlé les deux résultats.
// Correction déterministe (même résultat sur tous les appareils une fois leurs bases d'accord) : par nom, les
// produits du catalogue (ordre des identifiants) gardent chacun un secteur distinct du catalogue ; ceux qui en
// partagent un vont dans les secteurs du catalogue restés sans ce produit.

/// Nom (en minuscules) → secteurs d'ici où le catalogue commun le range, quand il y en a plusieurs.
Map<String, List<String>> homonymesCatalogue = {};

extension CorrectionHomonymes on Etat {
  /// Retient les noms que le [catalogue] range dans plusieurs secteurs.
  void retenirHomonymes(Map<String, dynamic> catalogue) {
    final rayonNom = {for (final r in rayons) r.id: r.nom};
    final secteurParNoms = <String, String>{};
    for (final s in secteurs) {
      if (rayonNom[s.rayonId] case final rn?) secteurParNoms.putIfAbsent('$rn|${s.nom}', () => s.id);
    }
    final parNom = <String, List<String>>{};
    for (final r in (catalogue['rayons'] as List? ?? const []).whereType<Map>()) {
      final ro = r['nom'] as String? ?? '';
      final rayonIci = renommages['r:$ro'] ?? ro;
      for (final s in (r['secteurs'] as List? ?? const []).whereType<Map>()) {
        final so = s['nom'] as String? ?? '';
        final cible = secteurParNoms['$rayonIci|${renommages['s:$ro/$so'] ?? so}'];
        if (cible == null) continue;
        for (final p in (s['produits'] as List? ?? const [])) {
          final nom = (p is Map ? p['nom'] as String? : p as String?)?.trim().toLowerCase();
          if (nom == null || nom.isEmpty) continue;
          final l = parNom.putIfAbsent(nom, () => []);
          if (!l.contains(cible)) l.add(cible);
        }
      }
    }
    homonymesCatalogue = {for (final e in parNom.entries) if (e.value.length > 1) e.key: e.value};
  }

  /// Rend le nombre de produits replacés.
  int corrigerHomonymes() {
    if (homonymesCatalogue.isEmpty) return 0;
    final parNom = <String, List<Produit>>{};
    for (final p in produits) {
      final nom = p.nom.trim().toLowerCase();
      if (homonymesCatalogue.containsKey(nom) && !estAjoute(p)) parNom.putIfAbsent(nom, () => []).add(p);
    }
    final empl = {for (final e in emplacements) e.produitId: e};
    var n = 0;
    for (final MapEntry(key: nom, value: ps) in parNom.entries) {
      if (ps.length < 2) continue;
      final attendus = homonymesCatalogue[nom]!;
      ps.sort((a, b) => a.id.compareTo(b.id));
      final pris = <String>{};
      final libres = <Produit>[];
      for (final p in ps) {
        final s = empl[p.id]?.secteurId;
        if (s != null && attendus.contains(s) && pris.add(s)) continue;
        libres.add(p);
      }
      final manquants = [for (final s in attendus) if (!pris.contains(s)) s];
      for (var i = 0; i < libres.length && i < manquants.length; i++) {
        final e = empl[libres[i].id];
        if (e == null) {
          emplacements.add(Emplacement(magasinCommun, libres[i].id, manquants[i]));
        } else {
          e.secteurId = manquants[i];
        }
        n++;
      }
    }
    if (n > 0) {
      modifie();
      noter('Homonymes du catalogue : $n produit(s) replacé(s) dans leur secteur');
    }
    return n;
  }
}
