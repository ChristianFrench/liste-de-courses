import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'modele.dart';

// Envoi des mails (liste, résumé, invitation) et tickets de caisse en PDF.
// Depuis le 28/10/2026, les mails partent directement par EmailJS (la Gmail de l'application, reliée par le
// maître d'ouvrage ; identifiants = secrets GitHub EMAILJS_*). Sans ces secrets, ou si l'envoi échoue, la
// messagerie de l'appareil s'ouvre avec le mail préparé, comme avant.

class MailDirect {
  static const service = String.fromEnvironment('EMAILJS_SERVICE');
  static const modele = String.fromEnvironment('EMAILJS_MODELE');
  static const cle = String.fromEnvironment('EMAILJS_CLE');

  /// Remplaçable dans les essais.
  static bool? disponibleEssai;
  static http.Client client = http.Client();

  static bool get disponible => disponibleEssai ?? (service.isNotEmpty && modele.isNotEmpty && cle.isNotEmpty);

  /// Paramètres du modèle EmailJS (champs {{...}} du modèle).
  /// [html] : le même contenu mis en forme (champ {{{texte_html}}} du modèle) ; par défaut, le texte tel quel.
  static Map<String, String> parametres(List<String> a, String sujet, String texte, {String? html}) => {
        'destinataires': a.join(','),
        'sujet': sujet,
        'texte': texte,
        'texte_html': html ?? enHtml(texte),
        // Le mail part de la Gmail de l'application : le nom et l'adresse de réponse sont ceux de l'auteur.
        'expediteur': Etat.instance.moi.nomAffiche,
        'repondre_a': Etat.instance.moi.email,
      };

  /// Envoie le mail ; true s'il est parti.
  static Future<bool> envoyer(List<String> a, String sujet, String texte, {String? html}) async {
    if (!disponible || a.isEmpty) return false;
    return (await envoyerParametres(parametres(a, sujet, texte, html: html))).$1;
  }

  /// Texte brut en HTML : caractères protégés, retours à la ligne gardés.
  static String enHtml(String texte) => '<div style="font-family:Arial,sans-serif;font-size:15px">'
      '${_echapper(texte).replaceAll('\n', '<br>')}</div>';

  /// Envoi brut (écran d'essai) : parti ou non, et la réponse d'EmailJS telle quelle.
  static Future<(bool, String)> envoyerParametres(Map<String, String> p) async {
    if (!disponible) return (false, 'Identifiants EmailJS absents de cette version (secrets GitHub EMAILJS_*)');
    try {
      final r = await client
          .post(Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'service_id': service, 'template_id': modele, 'user_id': cle, 'template_params': p}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) debugPrint('EmailJS : ${r.statusCode} ${r.body}');
      return (r.statusCode < 300, 'Réponse ${r.statusCode} : ${r.body}');
    } catch (e) {
      debugPrint('EmailJS : $e');
      return (false, 'Pas de réponse : $e');
    }
  }
}

/// Résultat d'un envoi : parti directement, préparé dans la messagerie, ou rien n'a répondu.
enum Envoi { parti, messagerie, echec }

/// Envoie directement si possible, sinon ouvre la messagerie avec le mail préparé.
Future<Envoi> envoyerMail(List<String> a, String sujet, String texte, {String? html}) async {
  if (await MailDirect.envoyer(a, sujet, texte, html: html)) return Envoi.parti;
  try {
    final ok = await launchUrl(_mailto(a, sujet, texte));
    return ok ? Envoi.messagerie : Envoi.echec;
  } catch (_) {
    return Envoi.echec;
  }
}

Uri _mailto(List<String> a, String sujet, String texte) =>
    Uri(scheme: 'mailto', path: a.join(','), query: _requete({'subject': sujet, 'body': texte}));

/// Message à afficher après un envoi (null : la messagerie s'est ouverte, rien à dire).
String? messageEnvoi(Envoi e, int n) => switch (e) {
      Envoi.parti => n > 1 ? 'Mail envoyé à $n personnes' : 'Mail envoyé',
      Envoi.messagerie => null,
      Envoi.echec => 'Aucune messagerie n\'a répondu sur cet appareil',
    };

String _echapper(String t) => t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Une ligne de la liste envoyée : quantité, nom, marque, packaging (le lot, sans la mesure), promotion.
typedef _LigneMail = ({int quantite, String nom, String detail, String promo});

/// Les articles de la liste par « Rayon - Secteur », dans l'ordre du magasin ; les non placés à la fin
/// (30/10/2026).
List<(String, List<_LigneMail>)> _groupesListe(Etat etat, Liste l) {
  final parSecteur = <String, List<_LigneMail>>{};
  final nonPlaces = <_LigneMail>[];
  for (final g in l.lignes) {
    final p = etat.produit(g.produitId);
    if (p == null) continue;
    final mq = etat.marque(g.marqueId);
    final lot = Etat.mesureEtLot(etat.packagingDe(g, p)?.libelle).$2;
    final detail = [
      if (mq != null && !p.nom.toLowerCase().contains(mq.nom.toLowerCase())) mq.nom,
      if (lot != null) lot,
    ].join(' · ');
    final promo = g.promotion == null ? '' : (g.promotion!.libelle.isEmpty ? 'promotion' : g.promotion!.libelle);
    final ligne = (quantite: g.quantite, nom: p.nom, detail: detail, promo: promo);
    final s = etat.secteurDe(l.magasinId, p.id);
    if (s == null) {
      nonPlaces.add(ligne);
    } else {
      parSecteur.putIfAbsent(s.id, () => []).add(ligne);
    }
  }
  return [
    for (final r in etat.rayonsDu(l.magasinId))
      for (final s in etat.secteursDu(r.id))
        if (parSecteur[s.id] case final lignes?) (r.nom == s.nom ? r.nom : '${r.nom} - ${s.nom}', lignes),
    if (nonPlaces.isNotEmpty) ('Non placé', nonPlaces),
  ];
}

String _enTeteListe(Etat etat, Liste l) => 'Liste de courses · ${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.lignes.length} articles';

/// Texte de la liste (messagerie de l'appareil), par rayon et secteur dans l'ordre du magasin.
String texteListe(Etat etat, Liste l) {
  final b = StringBuffer('${_enTeteListe(etat, l)}\n');
  final commentaire = etat.commentaire(l);
  if (commentaire != null) b.write('\n$commentaire\n');
  for (final (titre, lignes) in _groupesListe(etat, l)) {
    b.write('\n${titre.toUpperCase()}\n');
    for (final x in lignes) {
      b.write('- ${x.quantite > 1 ? '${x.quantite} × ' : ''}${x.nom}'
          '${x.detail.isEmpty ? '' : ', ${x.detail}'}${x.promo.isEmpty ? '' : ' (promo : ${x.promo})'}\n');
    }
  }
  return b.toString();
}

/// La même liste mise en forme pour le mail envoyé directement : titres en gras, promotions en rouge.
String htmlListe(Etat etat, Liste l) {
  final b = StringBuffer('<div style="font-family:Arial,sans-serif;font-size:15px;color:#1f2a24">'
      '<p style="font-size:17px;margin:0 0 8px"><b>${_echapper(_enTeteListe(etat, l))}</b></p>');
  final commentaire = etat.commentaire(l);
  if (commentaire != null) b.write('<p style="margin:0 0 8px"><i>${_echapper(commentaire).replaceAll('\n', '<br>')}</i></p>');
  for (final (titre, lignes) in _groupesListe(etat, l)) {
    b.write('<p style="margin:14px 0 4px;padding:3px 8px;background:#3c7a58;color:#ffffff"><b>${_echapper(titre)}</b></p>'
        '<ul style="margin:0;padding-left:22px">');
    for (final x in lignes) {
      b.write('<li>${x.quantite > 1 ? '<b>${x.quantite} ×</b> ' : ''}<b>${_echapper(x.nom)}</b>'
          '${x.detail.isEmpty ? '' : ', ${_echapper(x.detail)}'}'
          '${x.promo.isEmpty ? '' : ' <span style="color:#c62828"><b>promo : ${_echapper(x.promo)}</b></span>'}</li>');
    }
    b.write('</ul>');
  }
  b.write('</div>');
  return b.toString();
}

/// Les membres du foyer qui ont une adresse, l'auteur compris : le mail garde la trace d'un acte important
/// (décision du 29/10/2026). Une adresse n'apparaît qu'une fois.
List<String> adressesFoyer(Etat etat) {
  final vues = <String>{};
  return [
    for (final m in etat.membresVisibles)
      if (m.email.isNotEmpty && vues.add(m.email.trim().toLowerCase())) m.email.trim()
  ];
}

/// Destinataires de la liste : le foyer quand le mail part directement ou si l'option est choisie ;
/// sinon personne (on choisit dans la messagerie).
List<String> destinataires(Etat etat) => (MailDirect.disponible || etat.envoiFoyer) ? adressesFoyer(etat) : const [];

/// Résumé de fin de courses pour le foyer : les oubliés (non cochés), les absents des rayons (manquants)
/// et les achetés. Un mail n'a pas de couleurs : des pastilles de couleur les remplacent.
String texteResume(Etat etat, Liste l) {
  String nom(LigneListe g) {
    final p = etat.produit(g.produitId);
    return p == null ? '' : '${g.quantite > 1 ? '${g.quantite} × ' : ''}${p.nom}';
  }

  final manquants = [for (final g in l.lignes) if (etat.manquant(l, g.produitId)) nom(g)];
  final oublies = [for (final g in l.lignes) if (!g.coche && !etat.manquant(l, g.produitId)) nom(g)];
  final achetes = [for (final g in l.lignes) if (g.coche && !etat.manquant(l, g.produitId)) nom(g)];
  final b = StringBuffer('Courses terminées · ${etat.magasin(l.magasinId)?.nom ?? ''} · ${etat.nomListe(l)}\n'
      '${achetes.length} acheté${achetes.length > 1 ? 's' : ''} sur ${l.lignes.length}\n');
  void bloc(String titre, List<String> noms) {
    if (noms.isEmpty) return;
    b
      ..write('\n$titre (${noms.length})\n')
      ..writeAll(noms.where((x) => x.isNotEmpty).map((x) => '- $x\n'));
  }

  bloc('🔴 OUBLIÉS (non cochés)', oublies);
  bloc('🔵 ABSENTS DES RAYONS', manquants);
  bloc('✅ ACHETÉS', achetes);
  return b.toString();
}

/// Résumé des courses à tous les membres du foyer qui ont une adresse.
Future<Envoi> envoyerResume(Etat etat, Liste l) {
  return envoyerMail(adressesFoyer(etat), 'Courses terminées · ${etat.magasin(l.magasinId)?.nom ?? ''}', texteResume(etat, l));
}

// Uri(queryParameters:) code les espaces en « + », que les messageries affichent tels quels.
String _requete(Map<String, String> p) =>
    p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

/// La liste, au foyer si l'option est choisie ; sinon la messagerie s'ouvre et l'on choisit à qui l'envoyer.
Future<Envoi> envoyerListe(Etat etat, Liste l) =>
    envoyerMail(destinataires(etat), _sujetListe(etat, l), texteListe(etat, l), html: htmlListe(etat, l));

String _sujetListe(Etat etat, Liste l) => 'Liste de courses · ${etat.magasin(l.magasinId)?.nom ?? ''}';

/// Le mail préparé de la liste, pour la messagerie.
Uri lienMail(Etat etat, Liste l) => _mailto(destinataires(etat), _sujetListe(etat, l), texteListe(etat, l));

// ------------------------------------------------------------ Tickets PDF

Future<File> fichierTicket(String ticketId) async {
  final d = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}tickets');
  if (!d.existsSync()) d.createSync(recursive: true);
  return File('${d.path}${Platform.pathSeparator}$ticketId.pdf');
}

/// Choisit un PDF sur l'appareil et le joint à la course. Rend le ticket créé, ou null si rien n'a été choisi.
Future<Ticket?> joindreTicketPdf(Etat etat, Course c) async {
  final x = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf'], uniformTypeIdentifiers: ['com.adobe.pdf']),
  ]);
  if (x == null) return null;
  final t = etat.ajouterTicket(c);
  await (await fichierTicket(t.id)).writeAsBytes(await x.readAsBytes());
  return t;
}

/// Range comme PDF du ticket [t] le fichier reçu d'une autre application ([chemin], copie temporaire).
Future<void> enregistrerPdfTicket(Ticket t, String chemin) async {
  final source = File(chemin);
  await source.copy((await fichierTicket(t.id)).path);
  try {
    await source.delete();
  } catch (_) {}
}

Future<bool> ticketAPdf(String ticketId) async {
  try {
    return (await fichierTicket(ticketId)).existsSync();
  } catch (_) {
    return false;
  }
}

Future<bool> ouvrirTicket(String ticketId) async {
  final f = await fichierTicket(ticketId);
  if (!f.existsSync()) return false;
  if (Platform.isAndroid) {
    // Android refuse de passer un chemin de fichier à une autre application : le code Android
    // (outils/android/MainActivity.kt) le transmet au lecteur de PDF par un FileProvider.
    try {
      return await const MethodChannel('fr.listecourses/ticket').invokeMethod<bool>('ouvrirPdf', f.path) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
  try {
    return await launchUrl(Uri.file(f.path));
  } catch (_) {
    return false;
  }
}
