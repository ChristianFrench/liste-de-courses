import 'dart:convert';

import 'package:flutter/services.dart';

import 'modele.dart';

// Liste créée à partir d'un texte collé (le corps d'un mail contenant une liste de courses) :
// une ligne par article ; on reconnaît les produits du catalogue, la quantité et la marque.

/// Un article lu dans le texte.
class ArticleLu {
  ArticleLu(this.texte, this.nom, this.quantite, {this.produit, this.marque});

  /// Ligne d'origine, telle qu'écrite dans le mail.
  final String texte;

  /// Nom proposé pour un produit à créer (la ligne nettoyée), quand rien n'est reconnu.
  final String nom;
  final int quantite;

  /// Produit du catalogue reconnu, ou null (produit à créer).
  final Produit? produit;
  final String? marque;
}

/// Minuscules, sans accents ni ponctuation : « Pâtes (Panzani) » → « pates panzani ».
String normaliser(String t) {
  const accents = {'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'î': 'i',
      'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae'};
  final s = t.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return s.replaceAll(RegExp(r'[^a-z0-9%]+'), ' ').trim();
}

/// Mot au singulier, pour comparer « tomates » et « tomate », « poireaux » et « poireau ».
String _singulier(String m) {
  if (m.length > 3 && m.endsWith('aux')) return '${m.substring(0, m.length - 3)}al';
  if (m.length > 3 && (m.endsWith('s') || m.endsWith('x'))) return m.substring(0, m.length - 1);
  return m;
}

const _motsVides = {'de', 'des', 'du', 'la', 'le', 'les', 'l', 'd', 'a', 'au', 'aux', 'et', 'en', 'pour', 'un', 'une', 'avec'};

List<String> _mots(String t) => [
      for (final m in normaliser(t).split(' '))
        if (m.isNotEmpty && !_motsVides.contains(m)) _singulier(m)
    ];

/// Lignes réelles des listes envoyées par mail → produit (et marque), apprises sur les listes du foyer.
Map<String, List<String>> _correspondances = {};
bool _chargees = false;

Future<void> chargerCorrespondances() async {
  if (_chargees) return;
  _chargees = true;
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/correspondances_mails.json')) as Map<String, dynamic>;
    _correspondances = {for (final e in j.entries) e.key: (e.value as List).cast<String>()};
  } catch (_) {
    _correspondances = {};
  }
}

/// Lignes à ignorer : formules du mail, signature, lignes sans lettre.
bool _horsListe(String t) {
  final n = normaliser(t);
  if (n.isEmpty || !RegExp(r'[a-z]').hasMatch(n)) return true;
  const debuts = ['bonjour', 'salut', 'coucou', 'merci', 'bisou', 'bises', 'envoye de', 'envoye depuis', 'sent from', 'de :',
      'objet', 'a :', 'le ', 'cordialement', 'liste de courses', 'voici', 'bonne journee', 'a plus', 'cdlt'];
  if (debuts.any((d) => n.startsWith(d.trim()) && (d != 'le ' || n.contains('a ecrit')))) return true;
  if (t.trim().startsWith('>') || t.trim().startsWith('--')) return true;
  return false;
}

/// Retire puce et quantité : « - 2 x Yaourts » → (« Yaourts », 2) ; « Lait x6 » → (« Lait », 6).
(String, int) _nettoyer(String ligne) {
  var t = ligne.trim().replaceFirst(RegExp(r'^[-–—*•·+o>]+\s*'), '').replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
  // Mention de promotion en tête (« P par 2 / », « 3 + 1 gratuit / ») : on garde l'article.
  t = t.replaceFirst(RegExp(r'^(p\b[^/]*|[^/]*(gratuit|offert)[^/]*)/\s*', caseSensitive: false), '');
  var q = 1;
  final avant = RegExp(r'^(\d{1,2})\s*(x|×|\*)?\s+(?=\D)', caseSensitive: false).firstMatch(t);
  if (avant != null) {
    q = int.parse(avant.group(1)!);
    t = t.substring(avant.end);
  } else {
    final apres = RegExp(r'\s*(x|×|\*)\s*(\d{1,2})\s*$', caseSensitive: false).firstMatch(t);
    if (apres != null) {
      q = int.parse(apres.group(2)!);
      t = t.substring(0, apres.start);
    }
  }
  t = t.trim();
  if (t.isNotEmpty) t = t[0].toUpperCase() + t.substring(1);
  return (t, q.clamp(1, 99));
}

/// Le produit du catalogue qui correspond le mieux à [texte] : nom identique, sinon le plus long nom
/// dont tous les mots figurent dans le texte, sinon celui dont le premier mot est le premier mot du texte.
Produit? _chercher(Iterable<Produit> produits, String texte) {
  final mots = _mots(texte);
  if (mots.isEmpty) return null;
  final cle = mots.join(' ');
  Produit? meilleur;
  var score = 0;
  for (final p in produits) {
    final mp = _mots(p.nom.split(' · ').first);
    if (mp.isEmpty) continue;
    if (mp.join(' ') == cle) return p;
    if (mp.every(mots.contains)) {
      // Plus le nom couvre de mots du texte, mieux c'est ; à égalité, le plus court gagne.
      final s = mp.length * 10 + (mp.first == mots.first ? 5 : 0) - p.nom.length ~/ 20;
      if (s > score) {
        score = s;
        meilleur = p;
      }
    }
  }
  return meilleur;
}

/// Lit le texte collé : un article par ligne (ou séparés par des virgules sur une même ligne).
List<ArticleLu> lireTexte(Etat etat, String texte) {
  final res = <ArticleLu>[];
  final produits = etat.produits;
  Produit? parNom(String nom) {
    final n = normaliser(nom);
    for (final p in produits) {
      if (normaliser(p.nom) == n) return p;
    }
    return null;
  }

  var precedente = '';
  for (final brute in texte.split(RegExp(r'\r?\n'))) {
    // Suite d'une longue ligne coupée par la messagerie (« … conserver à » / « l'occasion. »)
    final suite = precedente.length > 30 && RegExp(r'[a-zà-ÿ(,]$').hasMatch(precedente.trim()) &&
        RegExp(r'^[a-zà-ÿ]').hasMatch(brute.trim());
    precedente = brute;
    if (suite && _chercher(produits, brute) == null) continue;
    // « pain, beurre, œufs » : plusieurs articles sur une ligne ; pas une phrase avec une virgule.
    final parts = brute.split(',');
    final morceaux = parts.length > 1 && !brute.contains('(') && !RegExp(r'\d,\d').hasMatch(brute) &&
            parts.every((x) => x.trim().length <= 30)
        ? parts
        : [brute];
    for (final ligne in morceaux) {
      if (_horsListe(ligne)) continue;
      final (nom, q) = _nettoyer(ligne);
      if (nom.isEmpty) continue;
      // Intertitre de rubrique (« FRUITS ET LÉGUMES ») : en capitales, sans article reconnu
      final capitales = nom == nom.toUpperCase() && nom.length > 3;
      final appris = _correspondances[normaliser(ligne)] ?? _correspondances[normaliser(nom)];
      final p = (appris == null ? null : parNom(appris[0])) ?? _chercher(produits, nom);
      if (p == null && capitales) continue;
      res.add(ArticleLu(ligne.trim(), nom, q,
          produit: p, marque: appris == null || appris[1].isEmpty ? null : appris[1]));
    }
  }
  return res;
}
