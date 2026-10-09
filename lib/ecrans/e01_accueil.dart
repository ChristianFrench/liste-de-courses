import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'e02_nouvelle_liste.dart';
import 'e03_construction.dart';
import 'e04_je_fais_les_courses.dart';
import 'e06_courses_secteur.dart';
import 'e07_foyer.dart';
import 'e08_produits.dart';
import 'e10_promotion.dart';
import 'e11_magasins_parcours.dart';
import 'e12_historique.dart';

/// Écran 1 — Accueil.
class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) => PageBase(
        entete: EnTeteGestion(
          titre: etat.foyer.nom,
          retour: false,
          gauche: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icone_ronde.png', width: 34, height: 34),
          ),
          onTitre: () => Nav.aller(context, const EcranFoyer()),
          action: _IndicateurSynchro(horsReseau: etat.horsReseau, onTap: etat.basculerReseau),
        ),
        corps: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Bouton(
                      texte: 'Préparer une liste',
                      hauteur: 72,
                      onTap: () => Nav.aller(context, const EcranNouvelleListe()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Bouton(
                      texte: 'Je fais les courses',
                      plein: true,
                      hauteur: 72,
                      onTap: () => Nav.aller(context, const EcranJeFaisLesCourses()),
                    ),
                  ),
                ],
              ),
            ),
            if (etat.courses != null && etat.listeEnCours != null) ..._coursesEnCours(context, etat),
            const TitreSection('Listes en construction'),
            if (etat.listesEnConstruction.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Aucune liste en construction.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
              ),
            for (final l in etat.listesEnConstruction)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _CarteListe(liste: l),
              ),
            const TitreSection('Gérer'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  Bouton(texte: 'Produits', taille: 16, onTap: () => Nav.aller(context, const EcranProduits())),
                  Bouton(
                      texte: 'Magasins et parcours',
                      taille: 16,
                      onTap: () => Nav.aller(context, const EcranMagasinsParcours())),
                  Bouton(texte: 'Historique', taille: 16, onTap: () => Nav.aller(context, const EcranHistorique())),
                  Bouton(
                      texte: 'Tickets de caisse',
                      taille: 16,
                      onTap: () => Nav.aller(context, const EcranHistorique())),
                  Bouton(
                      texte: 'Promotions',
                      taille: 16,
                      onTap: () => Nav.aller(context, EcranPromotion(produitId: etat.produits.first.id))),
                  Bouton(texte: 'Foyer', taille: 16, onTap: () => Nav.aller(context, const EcranFoyer())),
                ],
              ),
            ),
          ],
        ),
        bas: const [BarreNavigation(index: 0)],
      ),
    );
  }

  List<Widget> _coursesEnCours(BuildContext context, Etat etat) {
    final c = etat.courses!;
    final l = etat.listeEnCours!;
    final total = l.lignes.length;
    final faits = c.coches.length;
    final p = etat.unParcours(c.parcoursId);
    return [
      const TitreSection('Courses en cours'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Charte.encre, width: Charte.traitCadre),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(etat.magasin(l.magasinId)?.nom ?? '', style: Charte.texte(17, gras: true))),
                  Text('$faits / $total', style: Charte.texte(17, gras: true)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : faits / total,
                  minHeight: 10,
                  color: Charte.encre,
                  backgroundColor: Charte.fondSelection,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${etat.membre(c.membreId)?.nomAffiche ?? ''} · '
                '${p == null ? 'ordre des rayons' : 'parcours « ${p.nom} »'}',
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
              const SizedBox(height: 10),
              Bouton(
                texte: 'Reprendre les courses',
                plein: true,
                onTap: () => Nav.aller(context, const EcranCoursesSecteur()),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _IndicateurSynchro extends StatelessWidget {
  const _IndicateurSynchro({required this.horsReseau, required this.onTap});
  final bool horsReseau;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Maquette : toucher pour simuler une coupure de réseau',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(horsReseau ? Icons.cloud_off_outlined : Icons.circle, size: horsReseau ? 16 : 10, color: Charte.encre),
              const SizedBox(width: 6),
              Text(horsReseau ? 'Hors réseau' : 'Synchronisé', style: Charte.texte(13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteListe extends StatelessWidget {
  const _CarteListe({required this.liste});
  final Liste liste;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final n = etat.nbArticles(liste);
    final auteur = etat.membre(liste.auteurId)?.nomAffiche ?? '';
    final quand = liste.derniereModification == null ? 'le ${jjmm(liste.dateCreation)}' : "aujourd'hui";
    return Material(
      color: Charte.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Nav.aller(context, EcranConstruction(listeId: liste.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etat.magasin(liste.magasinId)?.nom ?? '', style: Charte.texte(17, gras: true)),
                    const SizedBox(height: 2),
                    Text('$n article${n > 1 ? 's' : ''} · modifiée par $auteur $quand',
                        style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 28, color: Charte.encre),
            ],
          ),
        ),
      ),
    );
  }
}
