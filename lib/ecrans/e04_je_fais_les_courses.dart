import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e05_liste_complete.dart';

/// Écran 4 — Je fais les courses : choix de la liste, de la personne et du parcours.
class EcranJeFaisLesCourses extends StatefulWidget {
  const EcranJeFaisLesCourses({super.key});

  @override
  State<EcranJeFaisLesCourses> createState() => _EcranJeFaisLesCoursesState();
}

class _EcranJeFaisLesCoursesState extends State<EcranJeFaisLesCourses> {
  final etat = Etat.instance;
  String? listeId;
  late String membreId;

  /// Identifiant du parcours, ou '' pour « ordre des rayons du magasin ».
  String parcoursId = '';

  List<Liste> get _listes {
    // Listes prêtes d'abord, puis les listes en construction
    return [
      ...etat.listes.where((x) => x.statut == StatutListe.prete),
      ...etat.listes.where((x) => x.statut != StatutListe.prete),
    ];
  }

  @override
  void initState() {
    super.initState();
    membreId = etat.moi.id;
    final listes = _listes;
    if (listes.isNotEmpty) listeId = listes.first.id;
    _parcoursParDefaut();
  }

  void _parcoursParDefaut() {
    final l = etat.liste(listeId);
    if (l == null) {
      parcoursId = '';
      return;
    }
    parcoursId = etat.parcoursParDefaut(l.magasinId, membreId)?.id ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final listes = _listes;
    final l = etat.liste(listeId);
    final choixParcours = <String, String>{};
    if (l != null) {
      for (final p in etat.parcoursDe(l.magasinId, membreId)) {
        choixParcours[p.id] = p.parDefaut ? '${p.nom} (par défaut)' : p.nom;
      }
    }
    choixParcours[''] = 'Ordre des rayons du magasin';

    return PageBase(
      entete: const EnTeteTravail(titre: 'Je fais les courses'),
      corps: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const TitreSection('Quelle liste ?', cote: 0),
          if (listes.isEmpty)
            Text("Aucune liste : préparez d'abord une liste depuis l'accueil.",
                style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          for (final x in listes) ...[
            _carteListe(x),
            const SizedBox(height: 10),
          ],
          const TitreSection('Qui fait les courses ?', cote: 0),
          ChoixDeroulant<String>(
            valeur: membreId,
            choix: {for (final m in etat.membres) m.id: m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche},
            onChange: (v) => setState(() {
              membreId = v;
              _parcoursParDefaut();
            }),
          ),
          const TitreSection('Parcours', cote: 0),
          ChoixDeroulant<String>(
            valeur: parcoursId,
            choix: choixParcours,
            onChange: (v) => setState(() => parcoursId = v),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bas: [
        BarreAction(boutons: [
          Bouton(
            texte: 'Voir la liste et partir',
            plein: true,
            onTap: l == null
                ? null
                : () {
                    etat.demarrerCourses(l, membreId, parcoursId.isEmpty ? null : parcoursId);
                    Nav.remplacer(context, EcranListeComplete(listeId: l.id));
                  },
          ),
        ]),
      ],
    );
  }

  Widget _carteListe(Liste x) {
    final choisie = x.id == listeId;
    final n = x.lignes.length;
    final etatListe = x.statut == StatutListe.prete ? 'prête' : 'en construction';
    return Material(
      color: choisie ? Charte.fondSelection : Charte.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          listeId = x.id;
          _parcoursParDefaut();
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(choisie ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 26, color: Charte.encre),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etat.magasin(x.magasinId)?.nom ?? '', style: Charte.texte(17, gras: true)),
                    const SizedBox(height: 2),
                    Text(
                      '$n article${n > 1 ? 's' : ''} · $etatListe · '
                      '${etat.membre(x.auteurId)?.nomAffiche ?? ''} · ${jjmm(x.dateCreation)}',
                      style: Charte.texte(13, couleur: Charte.texteSecondaire),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
