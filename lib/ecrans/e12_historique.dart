import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e03_construction.dart';

/// Écran 12 — Historique et tickets.
class EcranHistorique extends StatefulWidget {
  const EcranHistorique({super.key});

  @override
  State<EcranHistorique> createState() => _EcranHistoriqueState();
}

class _EcranHistoriqueState extends State<EcranHistorique> {
  final etat = Etat.instance;
  int vue = 0; // 0 : par date, 1 : par magasin
  String? choisie;

  void _refaire() {
    if (etat.historique.isEmpty) return;
    final course = etat.historique.firstWhere((c) => c.id == choisie, orElse: () => etat.historique.first);
    final lignes = etat.preliste(course.magasinId);
    final l = etat.creerListe(course.magasinId, lignes);
    Nav.message(context, 'Nouvelle liste à partir des achats habituels de ce magasin');
    Nav.aller(context, EcranConstruction(listeId: l.id));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final courses = etat.historique;
        choisie ??= courses.isEmpty ? null : courses.first.id;
        final lignes = <Widget>[];
        if (vue == 0) {
          for (final c in courses) {
            lignes.add(_ligne(c));
          }
        } else {
          for (final m in etat.magasins) {
            final duMagasin = courses.where((c) => c.magasinId == m.id).toList();
            if (duMagasin.isEmpty) continue;
            lignes.add(TitreGroupe(nom: '${m.nom} · ${duMagasin.length} courses'));
            for (final c in duMagasin) {
              lignes.add(_ligne(c));
            }
          }
        }
        return PageBase(
          entete: const EnTeteGestion(titre: 'Historique et tickets'),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const TitreSection('Ajouter un ticket de caisse', cote: 0),
              Bouton(
                texte: 'Photographier le ticket',
                icone: Icons.photo_camera_outlined,
                taille: 16,
                onTap: () => Nav.nonDisponible(context),
              ),
              const SizedBox(height: 8),
              Bouton(
                texte: 'Récupérer via le compte magasin (à étudier)',
                icone: Icons.sync,
                pointille: true,
                taille: 15,
                onTap: () => Nav.nonDisponible(context),
              ),
              const TitreSection('Courses passées', cote: 0),
              Bascule(
                options: const ['Par date', 'Par magasin'],
                index: vue,
                onChange: (i) => setState(() => vue = i),
              ),
              const SizedBox(height: 8),
              if (courses.isEmpty)
                Text('Aucune course enregistrée.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              ...lignes,
              const SizedBox(height: 12),
              Bouton(
                texte: "Refaire une liste à partir d'une course",
                taille: 16,
                onTap: courses.isEmpty ? null : _refaire,
              ),
              const SizedBox(height: 16),
            ],
          ),
          bas: const [BarreNavigation(index: 4)],
        );
      },
    );
  }

  Widget _ligne(Course c) {
    final choisi = c.id == choisie;
    final details = <String>[
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      etat.membre(c.membreId)?.nomAffiche ?? '',
      if (c.montant != null) euros(c.montant!),
    ];
    return Material(
      color: choisi ? Charte.fondSelection : Charte.fond,
      child: InkWell(
        onTap: () => setState(() => choisie = c.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${jjmmaaaa(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
                        style: Charte.texte(17, gras: true)),
                    Text(details.join(' · '), style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
              if (c.ticketSource != null)
                const Etiquette('Ticket', icone: Icons.check)
              else
                const Etiquette('Sans ticket', pointille: true),
            ],
          ),
        ),
      ),
    );
  }
}
