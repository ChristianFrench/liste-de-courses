import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

/// Écran 11 — Magasins et parcours.
class EcranMagasinsParcours extends StatefulWidget {
  const EcranMagasinsParcours({super.key, this.magasinId});
  final String? magasinId;

  @override
  State<EcranMagasinsParcours> createState() => _EcranMagasinsParcoursState();
}

class _EcranMagasinsParcoursState extends State<EcranMagasinsParcours> {
  final etat = Etat.instance;
  late String magasinId;
  int onglet = 1; // 0 : rayons et secteurs, 1 : parcours
  int membreIndex = 0;
  String? parcoursId;

  // Copie de travail du parcours affiché
  List<String> etapes = [];
  bool parDefaut = false;
  bool modifie = false;

  @override
  void initState() {
    super.initState();
    magasinId = widget.magasinId ?? etat.magasins.first.id;
    membreIndex = etat.membres.indexWhere((m) => m.moi);
    if (membreIndex < 0) membreIndex = 0;
    if (widget.magasinId != null) onglet = 0;
    _chargerParcours(null);
  }

  String get membreId => etat.membres[membreIndex].id;

  void _chargerParcours(String? id) {
    final p = etat.unParcours(id) ?? etat.parcoursParDefaut(magasinId, membreId);
    parcoursId = p?.id;
    etapes = [...?p?.etapes];
    parDefaut = p?.parDefaut ?? false;
    modifie = false;
  }

  void _enregistrer() {
    final p = etat.unParcours(parcoursId);
    if (p == null) return;
    p.etapes = [...etapes];
    if (parDefaut) {
      etat.definirParDefaut(p);
    } else {
      p.parDefaut = false;
      etat.signaler();
    }
    setState(() => modifie = false);
    Nav.message(context, 'Parcours enregistré');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: const EnTeteGestion(titre: 'Magasins et parcours'),
        corps: onglet == 1 ? _parcours(context) : _rayons(context),
        bas: [
          if (onglet == 1)
            BarreAction(boutons: [
              Bouton(
                texte: 'Enregistrer le parcours',
                plein: true,
                onTap: parcoursId == null ? null : _enregistrer,
              ),
            ]),
          const BarreNavigation(index: 3),
        ],
      ),
    );
  }

  Widget _enTete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('Magasin', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 4),
        ChoixDeroulant<String>(
          valeur: magasinId,
          choix: {for (final m in etat.magasins) m.id: m.nom},
          onChange: (v) => setState(() {
            magasinId = v;
            _chargerParcours(null);
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => onglet = i),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: onglet == i ? Charte.encre : Charte.separateurZone,
                          width: onglet == i ? 4 : 1,
                        ),
                      ),
                    ),
                    child: Text(i == 0 ? 'Rayons et secteurs' : 'Parcours',
                        style: Charte.texte(16, gras: onglet == i)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ------------------------------------------------------------ Parcours

  Widget _parcours(BuildContext context) {
    final liste = etat.parcoursDe(magasinId, membreId);
    final entete = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _enTete(),
        Bascule(
          options: [for (final m in etat.membres) m.nomAffiche],
          index: membreIndex,
          onChange: (i) => setState(() {
            membreIndex = i;
            _chargerParcours(null);
          }),
        ),
        const SizedBox(height: 12),
        Text('Parcours', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: liste.isEmpty
                  ? Text('Aucun parcours pour ce membre dans ce magasin.',
                      style: Charte.texte(14, couleur: Charte.texteSecondaire))
                  : ChoixDeroulant<String>(
                      valeur: parcoursId ?? '',
                      choix: {for (final p in liste) p.id: p.parDefaut ? '${p.nom} (par défaut)' : p.nom},
                      onChange: (v) => setState(() => _chargerParcours(v)),
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Bouton(
                texte: '+ Nouveau',
                taille: 16,
                onTap: () async {
                  final nom = await demanderTexte(context, titre: 'Nouveau parcours', aide: 'Ex. : Au plus court');
                  if (nom == null || nom.isEmpty) return;
                  final p = etat.creerParcours(magasinId, membreId, nom);
                  setState(() => _chargerParcours(p.id));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: Charte.separateurZone),
        const SizedBox(height: 10),
        Text('Ordre de passage par secteur · glisser pour réordonner',
            style: Charte.texte(13, couleur: Charte.texteSecondaire)),
        const SizedBox(height: 8),
      ],
    );

    final pied = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parcoursId != null) ...[
          Bouton(
            texte: '+ Ajouter un secteur au parcours',
            pointille: true,
            taille: 16,
            onTap: () async {
              final restants = etat.secteursDuMagasin(magasinId).where((s) => !etapes.contains(s.id)).toList();
              if (restants.isEmpty) {
                Nav.message(context, 'Tous les secteurs du magasin sont déjà dans le parcours');
                return;
              }
              final sid = await choisirDansListe<String>(
                context,
                titre: 'Ajouter un secteur',
                choix: {for (final s in restants) s.id: '${s.nom} · rayon ${etat.rayon(s.rayonId)?.nom ?? ''}'},
              );
              if (sid != null) {
                setState(() {
                  etapes.add(sid);
                  modifie = true;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() {
              parDefaut = !parDefaut;
              modifie = true;
            }),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  CaseACocher(coche: parDefaut, taille: 24),
                  const SizedBox(width: 10),
                  Text('Parcours par défaut', style: Charte.texte(16)),
                ],
              ),
            ),
          ),
          if (modifie)
            Text('Modifications non enregistrées', style: Charte.texte(13, gras: true)),
        ],
        const SizedBox(height: 16),
      ],
    );

    return ReorderableListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      header: entete,
      footer: pied,
      onReorderItem: (ancien, nouveau) => setState(() {
        final sid = etapes.removeAt(ancien);
        etapes.insert(nouveau, sid);
        modifie = true;
      }),
      children: [
        for (var i = 0; i < etapes.length; i++) _carteEtape(i),
      ],
    );
  }

  Widget _carteEtape(int i) {
    final s = etat.secteur(etapes[i]);
    final rayon = etat.rayon(s?.rayonId);
    // « Retour dans ce rayon » : rayon déjà visité plus tôt, mais pas à l'étape précédente (règle 7)
    var retour = false;
    if (i > 0 && rayon != null) {
      final precedent = etat.secteur(etapes[i - 1])?.rayonId;
      final dejaVu = etapes.take(i - 1).any((id) => etat.secteur(id)?.rayonId == rayon.id);
      retour = precedent != rayon.id && dejaVu;
    }
    return Padding(
      key: ValueKey('etape-${etapes[i]}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: Charte.fond,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Charte.encre, width: Charte.traitCadre),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Charte.encre, width: 1.5)),
              child: Text('${i + 1}', style: Charte.texte(14, gras: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s?.nom ?? '?', style: Charte.texte(17, gras: true)),
                  Text('Rayon ${rayon?.nom ?? ''}${retour ? ' · retour dans ce rayon' : ''}',
                      style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ],
              ),
            ),
            BoutonIcone(
              icone: Icons.close,
              taille: 20,
              libelle: 'Retirer du parcours',
              onTap: () => setState(() {
                etapes.removeAt(i);
                modifie = true;
              }),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Rayons et secteurs

  Widget _rayons(BuildContext context) {
    final rayons = etat.rayonsDu(magasinId);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _enTete(),
        if (rayons.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text("Ce magasin n'a pas encore de rayons.", style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        for (final r in rayons) ...[
          TitreGroupe(nom: r.nom),
          for (final s in etat.secteursDu(r.id))
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Row(
                children: [
                  Expanded(child: Text(s.nom, style: Charte.texte(16))),
                  Text(_nbProduits(s), style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Lien('+ Secteur', taille: 15, onTap: () async {
              final nom = await demanderTexte(context, titre: 'Nouveau secteur · ${r.nom}', aide: 'Nom du secteur');
              if (nom != null && nom.isNotEmpty) etat.ajouterSecteur(r.id, nom);
            }),
          ),
        ],
        const SizedBox(height: 8),
        Bouton(
          texte: '+ Ajouter un rayon',
          pointille: true,
          taille: 16,
          onTap: () async {
            final nom = await demanderTexte(context, titre: 'Nouveau rayon', aide: 'Nom du rayon');
            if (nom != null && nom.isNotEmpty) etat.ajouterRayon(magasinId, nom);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _nbProduits(Secteur s) {
    final n = etat.produitsDu(magasinId, s.id).length;
    return n == 0 ? 'aucun produit' : '$n produit${n > 1 ? 's' : ''}';
  }
}
