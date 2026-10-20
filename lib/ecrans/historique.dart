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
    // Une course terminée sans ticket reste dans l'onglet Courses tant qu'elle n'est pas classée
    // (sauf pendant un rattachement de ticket : elle peut alors recevoir le sien).
    final courses = etat.historique
        .where((c) => !etat.estArchive(c.magasinId) && (aRattacher != null || !etat.enInstance(c)))
        .toList();
    final groupes = <String, List<Course>>{};
    for (final c in courses) {
      final cle = vue == 0 ? moisAnnee(c.dateCourses).toUpperCase() : (etat.magasin(c.magasinId)?.nom ?? '').toUpperCase();
      groupes.putIfAbsent(cle, () => []).add(c);
    }
    final libres = etat.tickets.where((t) => etat.course(t.listeId) == null).toList();
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        if (aRattacher != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Bascule(
            douce: true,
            options: const ['Par date', 'Par magasin'],
            index: vue,
            onChange: (i) => setState(() => vue = i),
          ),
        ),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text('Aucune course terminée.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          ),
        for (final g in groupes.entries)
          GroupeRetractable(
            cle: 'historique/$vue/${g.key}',
            titre: g.key,
            icone: vue == 0 ? Icons.calendar_month_outlined : Icons.storefront_outlined,
            nombre: g.value.length,
            enfants: [for (final c in g.value) _ligne(context, etat, c, aRattacher)],
          ),
        if (libres.isNotEmpty && aRattacher == null)
          GroupeRetractable(
            cle: 'historique/tickets',
            titre: 'Tickets non rattachés',
            icone: Icons.receipt_long_outlined,
            nombre: libres.length,
            enfants: [
          for (final t in libres)
            LigneMenu(
              icone: Icons.receipt_long_outlined,
              titre: '${jjmm(t.date)} · ${etat.magasin(t.magasinId)?.nom ?? ''} · ${euros(t.montant)}',
              sousTitre: 'Non rattaché à une course',
              droite: Lien('Rattacher', onTap: () {
                nav.ticketARattacher = t.id;
                nav.signaler();
                setState(() {});
              }),
            ),
            ],
          ),
      ],
    );
  }

  Widget _ligne(BuildContext context, Etat etat, Course c, Ticket? aRattacher) {
    final t = etat.ticketDe(c.id);
    final details = [
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      t == null ? 'sans ticket' : 'ticket joint',
      etat.membre(c.membreId)?.nomAffiche ?? '',
      if (t != null && t.montant > 0) euros(t.montant),
    ].where((x) => x.isNotEmpty);
    return LigneMenu(
      icone: Icons.receipt_long_outlined,
      titre: '${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''}',
      sousTitre: details.join(' · '),
      onTap: aRattacher == null
          ? null
          : () {
              etat.rattacherTicket(aRattacher, c);
              Nav.i.ticketARattacher = null;
              Nav.message(context, 'Ticket rattaché à la course du ${jjmm(c.dateCourses)}');
              Nav.i.signaler();
              setState(() {});
            },
      // Ticket joint : trombone pour l'ouvrir ; sinon, de quoi le joindre.
      droite: t != null
          ? BoutonIcone(icone: Icons.attach_file, libelle: 'Ouvrir le ticket PDF', onTap: () => ouvrirTicketPdf(context, t))
          : BoutonIcone(icone: Icons.upload_file_outlined, libelle: 'Joindre le ticket PDF', onTap: () => joindreTicket(context, etat, c)),
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
