import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/envoi.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Historique (11) : un seul affichage, par date ou par magasin ; chaque course dit si son
// ticket PDF est joint. Refaire une liste depuis une course se fait au début de la préparation.

class SousEcranHistorique extends StatefulWidget {
  const SousEcranHistorique({super.key});

  @override
  State<SousEcranHistorique> createState() => _SousEcranHistoriqueState();
}

class _SousEcranHistoriqueState extends State<SousEcranHistorique> {
  static int vue = 0; // 0 : par date, 1 : par magasin (retenu tant que l'application est ouverte)

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final nav = Nav.i;
    final aRattacher = etat.tickets.where((t) => t.id == nav.ticketARattacher).firstOrNull;
    final courses = etat.historique.where((c) => !etat.estArchive(c.magasinId)).toList();
    final groupes = <String, List<Course>>{};
    for (final c in courses) {
      final cle = vue == 0 ? moisAnnee(c.dateCourses).toUpperCase() : (etat.magasin(c.magasinId)?.nom ?? '').toUpperCase();
      groupes.putIfAbsent(cle, () => []).add(c);
    }
    final libres = etat.tickets.where((t) => etat.course(t.listeId) == null).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (aRattacher != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            color: Charte.fondSelection,
            child: Row(
              children: [
                Icon(Icons.link, size: 20, color: Charte.couleurIcone(Icons.link)),
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
                    setState(() {});
                  },
                  child: Text('Annuler', style: Charte.texte(14)),
                ),
              ],
            ),
          ),
        Bascule(
          douce: true,
          options: const ['Par date', 'Par magasin'],
          index: vue,
          onChange: (i) => setState(() => vue = i),
        ),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Aucune course terminée.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        for (final g in groupes.entries) ...[
          TitreSection(g.key, cote: 0, haut: 14),
          for (final c in g.value) _ligne(context, etat, c, aRattacher),
        ],
        if (libres.isNotEmpty && aRattacher == null) ...[
          const TitreSection('Tickets non rattachés', cote: 0, haut: 18),
          for (final t in libres)
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${jjmm(t.date)} · ${etat.magasin(t.magasinId)?.nom ?? ''} · ${euros(t.montant)}',
                            style: Charte.texte(16, gras: true)),
                        Text('Non rattaché à une course', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                      ],
                    ),
                  ),
                  Lien('Rattacher', onTap: () {
                    nav.ticketARattacher = t.id;
                    nav.signaler();
                    setState(() {});
                  }),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _ligne(BuildContext context, Etat etat, Course c, Ticket? aRattacher) {
    final t = etat.ticketDe(c.id);
    final details = [
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      etat.membre(c.membreId)?.nomAffiche ?? '',
      if (t != null && t.montant > 0) euros(t.montant),
    ].where((x) => x.isNotEmpty);
    return Material(
      color: Charte.fond,
      child: InkWell(
        onTap: aRattacher == null
            ? null
            : () {
                etat.rattacherTicket(aRattacher, c);
                Nav.i.ticketARattacher = null;
                Nav.message(context, 'Ticket rattaché à la course du ${jjmm(c.dateCourses)}');
                Nav.i.signaler();
                setState(() {});
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
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
              if (t != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ouvrirTicketPdf(context, t),
                  child: const SizedBox(height: 44, child: Center(child: Etiquette('PJ ticket', icone: Icons.attach_file))),
                )
              else
                Lien('Sans PJ · joindre', onTap: () => joindreTicket(context, etat, c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Joint à la course le ticket PDF téléchargé depuis l'application du magasin, puis demande le montant.
Future<void> joindreTicket(BuildContext context, Etat etat, Course c) async {
  final t = await joindreTicketPdf(etat, c);
  if (t == null || !context.mounted) return;
  final m = await demanderTexte(context, titre: 'Montant du ticket', aide: 'Ex. : 84,30 (facultatif)');
  final v = double.tryParse((m ?? '').replaceAll(',', '.').replaceAll('€', '').trim());
  if (v != null) etat.montantTicket(t, v);
  if (context.mounted) Nav.message(context, 'Ticket joint à la course du ${jjmm(c.dateCourses)}');
}

Future<void> ouvrirTicketPdf(BuildContext context, Ticket t) async {
  if (!await ouvrirTicket(t.id) && context.mounted) Nav.message(context, 'Pas de PDF pour ce ticket');
}
