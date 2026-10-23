import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

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
              titre: [
                jjmm(t.date),
                etat.magasin(t.magasinId)?.nom ?? '',
                if (t.montant > 0) euros(t.montant),
              ].where((x) => x.isNotEmpty).join(' · '),
              sousTitre: [etat.libelleTicket(t), 'Non rattaché à une course'].where((x) => x.isNotEmpty).join(' · '),
              droite: Row(mainAxisSize: MainAxisSize.min, children: [
                BoutonIcone(icone: Icons.attach_file, libelle: 'Ouvrir le ticket PDF', onTap: () => ouvrirTicketPdf(context, t)),
                Lien('Rattacher', onTap: () {
                  nav.ticketARattacher = t.id;
                  nav.signaler();
                  setState(() {});
                }),
              ]),
            ),
            ],
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
      ],
    );
  }

  Widget _ligne(BuildContext context, Etat etat, Course c, Ticket? aRattacher) {
    final t = etat.ticketDe(c.id);
    final details = [
      '${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
      t == null ? 'sans ticket' : (etat.libelleTicket(t).isEmpty ? 'ticket joint' : 'ticket « ${etat.libelleTicket(t)} »'),
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
  await decrireTicket(context, t);
  if (context.mounted) Nav.message(context, 'Ticket joint à la course du ${jjmm(c.dateCourses)}');
}

/// Libellé et montant du ticket, demandés ensemble (tous deux facultatifs).
Future<void> decrireTicket(BuildContext context, Ticket t) async {
  final etat = Etat.instance;
  final libelle = TextEditingController(text: etat.libelleTicket(t));
  final montant = TextEditingController(text: t.montant > 0 ? t.montant.toStringAsFixed(2).replaceAll('.', ',') : '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Charte.fond,
      title: Text('Ticket de caisse', style: Charte.texte(18, gras: true)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: const ValueKey('ticket-libelle'),
          controller: libelle,
          autofocus: true,
          style: Charte.texte(16),
          decoration: const InputDecoration(labelText: 'Libellé', hintText: 'Ex. : Courses de la semaine (facultatif)'),
        ),
        TextField(
          key: const ValueKey('ticket-montant'),
          controller: montant,
          style: Charte.texte(16),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Montant', hintText: 'Ex. : 84,30 (facultatif)'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Passer', style: Charte.texte(16))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Valider', style: Charte.texte(16, gras: true))),
      ],
    ),
  );
  if (ok != true) return;
  etat.nommerTicket(t, libelle.text);
  final v = double.tryParse(montant.text.replaceAll(',', '.').replaceAll('€', '').replaceAll(' ', '').trim());
  if (v != null) etat.montantTicket(t, v);
}

/// Affiche le ticket PDF dans l'application (lecteur intégré).
Future<void> ouvrirTicketPdf(BuildContext context, Ticket t) async {
  if (!await ticketAPdf(t.id)) {
    if (context.mounted) Nav.message(context, 'Pas de PDF pour ce ticket');
    return;
  }
  final f = await fichierTicket(t.id);
  if (context.mounted) await Nav.aller<void>(context, EcranTicketPdf(ticket: t, chemin: f.path));
}

/// Lecteur de ticket PDF : défilement, zoom avec deux doigts ; dans le menu, libellé et montant,
/// et ouverture dans une autre application.
class EcranTicketPdf extends StatefulWidget {
  const EcranTicketPdf({super.key, required this.ticket, required this.chemin});
  final Ticket ticket;
  final String chemin;

  @override
  State<EcranTicketPdf> createState() => _EcranTicketPdfState();
}

class _EcranTicketPdfState extends State<EcranTicketPdf> {
  late final _document = PdfController(document: PdfDocument.openFile(widget.chemin));

  @override
  void dispose() {
    _document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final t = widget.ticket;
    final libelle = etat.libelleTicket(t);
    return Scaffold(
      backgroundColor: Charte.fond,
      body: SafeArea(
        child: Column(children: [
          EnTeteFenetre(
            titre: libelle.isEmpty ? 'Ticket de caisse' : libelle,
            icone: Icons.receipt_long_outlined,
            sousTitre: [jjmm(t.date), etat.magasin(t.magasinId)?.nom ?? '', if (t.montant > 0) euros(t.montant)]
                .where((x) => x.isNotEmpty)
                .join(' · '),
            retour: true,
            actions: [
              ActionLigne(Icons.edit_outlined, 'Libellé et montant', () async {
                await decrireTicket(context, t);
                if (mounted) setState(() {});
              }),
              ActionLigne(Icons.open_in_new, 'Ouvrir dans une autre application', () async {
                if (!await ouvrirTicket(t.id) && context.mounted) Nav.message(context, 'Aucune application pour ouvrir ce PDF');
              }),
            ],
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE6E6E6),
              child: PdfView(
                controller: _document,
                scrollDirection: Axis.vertical,
                onDocumentError: (e) => Nav.message(context, 'PDF illisible'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Ticket de caisse PDF reçu d'une autre application (« Partager » ou « Ouvrir avec » sur Android) :
/// on choisit la course à laquelle il appartient (les plus récentes sans ticket d'abord),
/// ou on le garde pour le rattacher plus tard ; puis on donne le montant.
Future<void> recevoirTicketPdf(BuildContext context, String chemin) async {
  final etat = Etat.instance;
  const libre = '\u0000libre';
  final candidates = [for (final c in etat.historique) if (etat.ticketDe(c.id) == null && !etat.estArchive(c.magasinId)) c]
    ..sort((a, b) => b.dateCourses.compareTo(a.dateCourses));
  final choix = await choisirDansListe<String>(context, titre: 'Ticket de caisse reçu · à quelle course le joindre ?', choix: {
    for (final c in candidates.take(10))
      c.id: '${jjmm(c.dateCourses)} · ${etat.magasin(c.magasinId)?.nom ?? ''} · ${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
    libre: candidates.isEmpty ? 'Le garder (aucune course n\'attend de ticket)' : 'Le garder sans course, à rattacher plus tard',
  });
  if (choix == null || !context.mounted) {
    if (context.mounted) Nav.message(context, 'Ticket non enregistré');
    return;
  }
  final Ticket t;
  String fin;
  if (choix == libre) {
    var magasinId = etat.magasins.isEmpty ? '' : etat.magasins.first.id;
    if (etat.magasins.length > 1) {
      final m = await choisirDansListe<String>(context, titre: 'Magasin du ticket', choix: {for (final m in etat.magasins) m.id: m.nom});
      if (m == null || !context.mounted) return;
      magasinId = m;
    }
    t = etat.ajouterTicketLibre(magasinId);
    fin = 'Ticket gardé : rattachez-le dans Gérer › Historique';
  } else {
    final c = etat.historique.firstWhere((x) => x.id == choix);
    t = etat.ajouterTicket(c);
    fin = 'Ticket joint à la course du ${jjmm(c.dateCourses)}';
  }
  await enregistrerPdfTicket(t, chemin);
  if (!context.mounted) return;
  await decrireTicket(context, t);
  if (context.mounted) Nav.message(context, fin);
}
