import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';
import 'travail.dart';

// Onglet Historique : Courses effectuées (11), Tickets de caisse (12).

/// Écran 11 — Historique › Courses effectuées. Sert aussi à rattacher un ticket.
class SousEcranCoursesEffectuees extends StatefulWidget {
  const SousEcranCoursesEffectuees({super.key});

  @override
  State<SousEcranCoursesEffectuees> createState() => _SousEcranCoursesEffectueesState();
}

class _SousEcranCoursesEffectueesState extends State<SousEcranCoursesEffectuees> {
  static int vue = 0; // 0 : par date, 1 : par magasin (retenu tant que l'application est ouverte)
  String? choisie;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final nav = Nav.i;
    final aRattacher = etat.tickets.where((t) => t.id == nav.ticketARattacher).firstOrNull;
    final courses = etat.historique;
    final groupes = <String, List<Course>>{};
    for (final c in courses) {
      final cle = vue == 0 ? moisAnnee(c.dateCourses).toUpperCase() : (etat.magasin(c.magasinId)?.nom ?? '').toUpperCase();
      groupes.putIfAbsent(cle, () => []).add(c);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (aRattacher != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            color: Charte.fondSelection,
            child: Row(
              children: [
                const Icon(Icons.link, size: 20, color: Charte.encre),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rattacher le ticket du ${jjmm(aRattacher.date)} (${euros(aRattacher.montant)}) : touchez la course.',
                    style: Charte.texte(14, gras: true),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    nav.ticketARattacher = null;
                    nav.signaler();
                  },
                  child: Text('Annuler', style: Charte.texte(14)),
                ),
              ],
            ),
          ),
        Bascule(
          options: const ['Par date', 'Par magasin'],
          index: vue,
          onChange: (i) => setState(() => vue = i),
        ),
        for (final g in groupes.entries) ...[
          TitreSection(g.key, cote: 0, haut: 14),
          for (final c in g.value) _ligne(context, etat, c, aRattacher),
        ],
        const SizedBox(height: 14),
        Bouton(
          texte: 'Refaire une liste à partir d\'une course',
          taille: 16,
          onTap: courses.isEmpty
              ? null
              : () {
                  final c = etat.course(choisie) ?? courses.first;
                  final l = etat.creerListe(c.magasinId, etat.preliste(c.magasinId));
                  Nav.message(context, 'Nouvelle liste préremplie avec les achats habituels de ${etat.magasin(c.magasinId)?.nom ?? ''}');
                  Nav.travail(EcranConstruction(listeId: l.id));
                },
        ),
      ],
    );
  }

  Widget _ligne(BuildContext context, Etat etat, Course c, Ticket? aRattacher) {
    final t = etat.ticketDe(c.id);
    final details = [
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      etat.membre(c.membreId)?.nomAffiche ?? '',
      if (t != null) euros(t.montant),
    ];
    return Material(
      color: c.id == choisie ? Charte.fondSelection : Charte.fond,
      child: InkWell(
        onTap: () {
          if (aRattacher != null) {
            etat.rattacherTicket(aRattacher, c);
            Nav.i.ticketARattacher = null;
            Nav.message(context, 'Ticket rattaché à la course du ${jjmm(c.dateCourses)}');
            Nav.i.allerSous(Nav.tickets);
            return;
          }
          setState(() => choisie = c.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}', style: Charte.texte(18, gras: true)),
                    Text(details.join(' · '), style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                  ],
                ),
              ),
              if (t != null) const Etiquette('Ticket', icone: Icons.check) else const Etiquette('Sans ticket', pointille: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran 12 — Historique › Tickets de caisse.
class SousEcranTickets extends StatelessWidget {
  const SousEcranTickets({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Bouton(texte: 'Photographier', icone: Icons.photo_camera_outlined, taille: 16, onTap: () => Nav.plusTard(context)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Bouton(
                texte: 'Compte magasin (à étudier)',
                pointille: true,
                taille: 14,
                onTap: () => Nav.message(context, 'Récupération par compte magasin : option à étudier'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (etat.tickets.isEmpty)
          Text('Aucun ticket.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        for (final t in etat.tickets) _ligne(context, etat, t),
      ],
    );
  }

  Widget _ligne(BuildContext context, Etat etat, Ticket t) {
    final c = etat.course(t.listeId);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
      child: Row(
        children: [
          CadrePointille(
            rayon: 2,
            epaisseur: 1.2,
            couleur: const Color(0xFF999999),
            child: Container(
              width: 46,
              height: 58,
              color: Charte.placeholder,
              alignment: Alignment.center,
              child: Text('TICKET', style: Charte.texte(9, couleur: Charte.texteSecondaire)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${jjmm(t.date)} · ${etat.magasin(t.magasinId)?.nom ?? ''} · ${euros(t.montant)}', style: Charte.texte(17, gras: true)),
                if (c != null)
                  Text('Lié à la course du ${jjmm(c.dateCourses)} · ${c.nbArticles} articles',
                      style: Charte.texte(14, couleur: Charte.texteSecondaire))
                else
                  Text('Non rattaché à une course', style: Charte.texte(14, gras: true)),
              ],
            ),
          ),
          if (c == null)
            Lien('Rattacher', onTap: () {
              Nav.i.ticketARattacher = t.id;
              Nav.i.allerSous(Nav.coursesEffectuees);
            }),
        ],
      ),
    );
  }
}
