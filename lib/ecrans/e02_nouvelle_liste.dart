import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e03_construction.dart';

/// Écran 2 — Nouvelle liste (préliste tirée de l'historique).
class EcranNouvelleListe extends StatefulWidget {
  const EcranNouvelleListe({super.key, this.magasinId});
  final String? magasinId;

  @override
  State<EcranNouvelleListe> createState() => _EcranNouvelleListeState();
}

class _EcranNouvelleListeState extends State<EcranNouvelleListe> {
  final etat = Etat.instance;
  late String magasinId;
  final Set<String> retenus = {};

  @override
  void initState() {
    super.initState();
    magasinId = widget.magasinId ?? etat.magasins.first.id;
    _initialiser();
  }

  void _initialiser() {
    retenus
      ..clear()
      ..addAll(etat.preliste(magasinId).map((g) => g.produitId));
  }

  void _creer(bool garder) {
    final lignes = garder
        ? etat.preliste(magasinId).where((g) => retenus.contains(g.produitId)).toList()
        : <LigneListe>[];
    if (garder) {
      for (final id in retenus) {
        if (!lignes.any((g) => g.produitId == id)) {
          final p = etat.produit(id);
          lignes.add(LigneListe(
            produitId: id,
            packagingId: (p?.packagingIds.isNotEmpty ?? false) ? p!.packagingIds.first : null,
            promotionId: etat.promotionActive(magasinId, id)?.id,
          ));
        }
      }
    }
    final l = etat.creerListe(magasinId, lignes);
    Nav.remplacer(context, EcranConstruction(listeId: l.id));
  }

  @override
  Widget build(BuildContext context) {
    final freq = etat.frequencesDu(magasinId);
    // Regroupement par rayon, dans l'ordre des rayons du magasin
    final groupes = <String, List<String>>{};
    final nonPlaces = <String>[];
    final ids = freq.keys.toList()..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    for (final id in ids) {
      final r = etat.rayonDe(magasinId, id);
      if (r == null) {
        nonPlaces.add(id);
      } else {
        groupes.putIfAbsent(r.id, () => []).add(id);
      }
    }
    final ordreRayons = etat.rayonsDu(magasinId).where((r) => groupes.containsKey(r.id)).toList();

    return PageBase(
      entete: const EnTeteTravail(titre: 'Nouvelle liste'),
      haut: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text('Magasin', style: Charte.texte(15)),
              const SizedBox(width: 12),
              Expanded(
                child: ChoixDeroulant<String>(
                  valeur: magasinId,
                  choix: {for (final m in etat.magasins) m.id: m.nom},
                  onChange: (v) => setState(() {
                    magasinId = v;
                    _initialiser();
                  }),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Préliste', style: Charte.texte(13, gras: true)),
              TextSpan(
                text: " d'après vos 6 dernières courses dans ce magasin : "
                    'produits achetés au moins ${Etat.seuilPreliste} fois (règle à valider).',
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
            ]),
          ),
        ),
        Container(height: 1, color: Charte.separateurZone),
      ],
      corps: freq.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Pas encore de courses enregistrées dans ce magasin : la préliste est vide. "
                'Commencez par une liste vide.',
                style: Charte.texte(15, couleur: Charte.texteSecondaire),
              ),
            )
          : ListView(
              children: [
                for (final r in ordreRayons) ...[
                  _titre(r.nom),
                  for (final id in groupes[r.id]!) _ligne(id, freq[id]!),
                ],
                if (nonPlaces.isNotEmpty) ...[
                  _titre('Non placé'),
                  for (final id in nonPlaces) _ligne(id, freq[id]!),
                ],
              ],
            ),
      bas: [
        BarreAction(boutons: [
          Bouton(texte: 'Liste vide', onTap: () => _creer(false)),
          Bouton(
            texte: retenus.isEmpty ? 'Compléter' : 'Garder ${retenus.length} et compléter',
            plein: true,
            taille: 16,
            onTap: () => _creer(true),
          ),
        ]),
      ],
    );
  }

  Widget _titre(String nom) => Container(
        height: 30,
        color: Charte.fondBandeau,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(nom.toUpperCase(), style: Charte.texte(12, couleur: Charte.texteSecondaire, espacement: 1.0)),
      );

  Widget _ligne(String produitId, int n) {
    final p = etat.produit(produitId);
    if (p == null) return const SizedBox.shrink();
    final coche = retenus.contains(produitId);
    final complement = etat.complement(null, p);
    return Material(
      color: Charte.fond,
      child: InkWell(
        onTap: () => setState(() {
          if (coche) {
            retenus.remove(produitId);
          } else {
            retenus.add(produitId);
          }
        }),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Charte.separateurLigne)),
          ),
          child: Row(
            children: [
              CaseACocher(coche: coche, taille: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: p.nom, style: Charte.texte(16)),
                    if (complement.isNotEmpty) TextSpan(text: ' · $complement', style: Charte.secondaire),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$n/6', style: Charte.texte(12, couleur: Charte.texteSecondaire)),
            ],
          ),
        ),
      ),
    );
  }
}
