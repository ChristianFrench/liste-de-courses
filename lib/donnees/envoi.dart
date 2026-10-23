import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'modele.dart';

// Envoi de la liste par la messagerie de l'appareil, et tickets de caisse en PDF.

/// Texte de la liste, rangé par rayon dans l'ordre du magasin.
String texteListe(Etat etat, Liste l) {
  final parRayon = <String, List<String>>{};
  final nonPlaces = <String>[];
  for (final g in l.lignes) {
    final p = etat.produit(g.produitId);
    if (p == null) continue;
    final complement = etat.complement(g, p);
    final promo = g.promotion == null ? '' : ' (${g.promotion!.libelle.isEmpty ? 'promotion' : g.promotion!.libelle})';
    final ligne = '- ${g.quantite > 1 ? '${g.quantite} × ' : ''}${p.nom}${complement.isEmpty ? '' : ', $complement'}$promo';
    final s = etat.secteurDe(l.magasinId, p.id);
    if (s == null) {
      nonPlaces.add(ligne);
    } else {
      parRayon.putIfAbsent(s.rayonId, () => []).add(ligne);
    }
  }
  final b = StringBuffer('Liste de courses · ${etat.magasin(l.magasinId)?.nom ?? ''} · ${l.lignes.length} articles\n');
  final commentaire = etat.commentaire(l);
  if (commentaire != null) b.write('\n$commentaire\n');
  for (final r in etat.rayonsDu(l.magasinId)) {
    final lignes = parRayon[r.id];
    if (lignes == null) continue;
    b
      ..write('\n${r.nom.toUpperCase()}\n')
      ..writeAll(lignes.map((x) => '$x\n'));
  }
  if (nonPlaces.isNotEmpty) {
    b
      ..write('\nNON PLACÉ\n')
      ..writeAll(nonPlaces.map((x) => '$x\n'));
  }
  return b.toString();
}

/// Adresses des destinataires : tout le foyer si l'option est choisie, sinon personne (on choisit dans la messagerie).
List<String> destinataires(Etat etat) =>
    etat.envoiFoyer ? [for (final m in etat.membres) if (m.email.isNotEmpty) m.email] : const [];

Uri lienMail(Etat etat, Liste l) => Uri(
      scheme: 'mailto',
      path: destinataires(etat).join(','),
      query: _requete({'subject': 'Liste de courses · ${etat.magasin(l.magasinId)?.nom ?? ''}', 'body': texteListe(etat, l)}),
    );

// Uri(queryParameters:) code les espaces en « + », que les messageries affichent tels quels.
String _requete(Map<String, String> p) =>
    p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

/// Ouvre la messagerie avec la liste déjà écrite. Rend false si aucune messagerie n'a répondu.
Future<bool> envoyerListe(Etat etat, Liste l) async {
  try {
    return await launchUrl(lienMail(etat, l));
  } catch (_) {
    return false;
  }
}

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
