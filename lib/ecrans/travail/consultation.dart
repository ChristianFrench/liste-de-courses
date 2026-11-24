part of '../travail.dart';


// ---------------------------------------------------------------- Consultation d'une liste

/// Consultation seule d'une liste, quel que soit son état (en préparation, à faire, en cours, terminée) :
/// les articles sous leurs bandeaux de secteur, cochés et manquants compris. Toucher un article en montre le détail.
class EcranConsultation extends StatelessWidget {
  const EcranConsultation({super.key, required this.listeId});
  final String listeId;

  static String etatDe(Liste l) => switch (l.statut) {
        StatutListe.enConstruction => 'En préparation',
        StatutListe.prete => 'À faire',
        StatutListe.enCours => 'En cours de courses',
        StatutListe.terminee => 'Terminée',
      };

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final l = etat.liste(listeId);
        if (l == null) {
          return PageBase(
            entete: const EnTeteFenetre(retour: true, titre: 'Liste'),
            corps: Center(child: Text('Cette liste n\'existe plus.', style: Charte.texte(16))),
          );
        }
        final avecCoches = l.statut == StatutListe.enCours || l.statut == StatutListe.terminee;
        Widget ligne(LigneListe g) {
          final p = etat.produit(g.produitId);
          if (p == null) return const SizedBox.shrink();
          return LigneArticle(
            key: ValueKey('consulter-${p.id}'),
            ligne: g,
            produit: p,
            coche: avecCoches && g.coche,
            manquant: avecCoches && etat.manquant(l, p.id),
            caseCourse: avecCoches,
            onTap: () => detailArticle(context, g),
            onDetail: () => detailArticle(context, g),
          );
        }

        final commentaire = etat.commentaire(l);
        return PageBase(
          entete: EnTeteFenetre(aide: Aides.consultation, 
            retour: true,
            sousTitre: '${etatDe(l)} · ${etat.magasin(l.magasinId)?.nom ?? ''}',
            titre: etat.nomListe(l),
          ),
          corps: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (commentaire != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(commentaire, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
              if (l.lignes.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('La liste est vide.', style: Charte.texte(16))),
              if (etat.aPlat(l))
                for (final g in l.lignes) ligne(g)
              else
                // Liste en préparation ou prête : l'ordre du catalogue ; en courses ou terminée : celui du parcours.
                for (final x in switch (l.statut) {
                  // 13/11/2026 (Aristide) : courses terminées dans l'ordre du parcours enregistré : celui où les
                  // secteurs ont été visités, puis le parcours suivi (ou celui du magasin) pour les autres.
                  StatutListe.terminee => etat.etapes(l, null, ordreBase: [
                      ...etat.secteursDansLOrdre(l),
                      ...?(etat.unParcours(l.parcoursId) ?? etat.parcoursPourCourses(l.magasinId, l.membreId ?? etat.moi.id))?.etapes,
                    ]),
                  StatutListe.enCours => etat.etapes(l, l.parcoursId),
                  _ => etat.etapes(l, null, ordreBase: secteursOrdreCatalogue(etat)),
                })
                  ...sectionSecteur(pictoEtape(x), 4, [
                    TitreGroupe(nom: x.nom, nonPlace: x.nonPlace, nombre: x.lignes.length, pictoDebordant: pictoEtape(x), pictoGauche: 4),
                    for (final g in x.lignes) ligne(g),
                  ]),
            ],
          ),
        );
      },
    );
  }
}

/// Image du secteur d'une étape de liste (bandeau des listes en préparation et en courses).
String? pictoEtape(Etape x) {
  final s = x.secteur;
  // 02/11/2026 (Aristide) : Apparence › « Icônes dans les listes ».
  if (s == null || !Etat.instance.iconesListes) return null;
  return picto.cleSecteur(Etat.instance.rayon(s.rayonId)?.nom ?? '', s.nom);
}

/// Qui reçoit la liste (02/11/2026, Aristide) : les membres du foyer qui ont une adresse, tous cochés au départ.
/// Rend null si l'on renonce. Sans membre à adresse : la liste vide (la messagerie s'ouvre, on choisit là).
Future<List<String>?> choisirDestinataires(BuildContext context) async {
  final etat = Etat.instance;
  final vues = <String>{};
  final membres = [
    for (final m in etat.membresVisibles)
      if (m.email.trim().isNotEmpty && vues.add(m.email.trim().toLowerCase())) m
  ];
  if (membres.isEmpty) return const [];
  final coches = {for (final m in membres) m.id};
  final ok = await modale(
    context,
    titre: 'Envoyer la liste à',
    icone: Icons.mail_outline,
    oui: 'Envoyer',
    contenu: (context, maj) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupeCases(
          titre: 'Destinataires',
          cases: [
            for (final m in membres)
              CaseModale(
                key: ValueKey('destinataire-${m.id}'),
                texte: m.moi ? '${m.nomAffiche} (moi)' : m.nomAffiche,
                aide: m.email.trim(),
                coche: coches.contains(m.id),
                onChange: (v) => maj(() => v ? coches.add(m.id) : coches.remove(m.id)),
              ),
          ],
        ),
      ],
    ),
  );
  if (!ok) return null;
  // Personne de coché : rien ne part.
  return coches.isEmpty ? null : [for (final m in membres) if (coches.contains(m.id)) m.email.trim()];
}
