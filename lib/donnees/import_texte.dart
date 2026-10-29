import 'dart:convert';

import 'package:flutter/services.dart';

import 'modele.dart';

// Liste créée à partir d'un texte collé (le corps d'un mail contenant une liste de courses) :
// une ligne par article ; on reconnaît les produits du catalogue, la quantité et la marque.

/// Un article lu dans le texte.
class ArticleLu {
  ArticleLu(this.texte, this.nom, this.quantite, {this.produit, this.marque, this.mails = 1, this.secteur});

  /// Nombre de mails où l'article figure (liste consolidée).
  final int mails;

  /// Ligne d'origine, telle qu'écrite dans le mail.
  final String texte;

  /// Nom proposé pour un produit à créer (la ligne nettoyée), quand rien n'est reconnu.
  final String nom;
  final int quantite;

  /// Produit du catalogue reconnu, ou null (produit à créer).
  final Produit? produit;
  final String? marque;

  /// Secteur du titre sous lequel l'article était écrit : un produit à créer y est rangé.
  final Secteur? secteur;
}

/// Ce que la lecture n'a pas pu faire sûrement : [ligne] telle qu'écrite, [explication] pour l'utilisateur.
class Difficulte {
  const Difficulte(this.ligne, this.explication);
  final String ligne;
  final String explication;
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

/// Plusieurs textes (plusieurs mails) fusionnés en une seule liste : un même produit n'apparaît qu'une fois.
/// Dans un même texte, les quantités s'additionnent ; d'un texte à l'autre, on garde la plus grande
/// (deux personnes qui demandent du lait n'en veulent pas forcément deux fois plus).
/// [rapport] reçoit les titres reconnus et les difficultés rencontrées.
List<ArticleLu> consoliderTextes(Etat etat, List<String> textes, {List<Difficulte>? rapport}) {
  final res = <String, ArticleLu>{};
  for (final t in textes) {
    final duTexte = <String, ArticleLu>{};
    for (final a in lireTexte(etat, t, rapport: rapport)) {
      final cle = a.produit?.id ?? 'nouveau:${normaliser(a.nom)}';
      final d = duTexte[cle];
      duTexte[cle] = d == null
          ? a
          : ArticleLu(d.texte, d.nom, d.quantite + a.quantite, produit: d.produit, marque: d.marque ?? a.marque, secteur: d.secteur);
    }
    for (final e in duTexte.entries) {
      final r = res[e.key];
      res[e.key] = r == null
          ? e.value
          : ArticleLu('${r.texte} | ${e.value.texte}', r.nom, r.quantite > e.value.quantite ? r.quantite : e.value.quantite,
              produit: r.produit, marque: r.marque ?? e.value.marque, mails: r.mails + 1, secteur: r.secteur ?? e.value.secteur);
    }
  }
  return res.values.toList();
}

/// Texte HTML (source d'un mail Gmail, par exemple) ramené à du texte simple : un retour à la ligne
/// par paragraphe, ligne de tableau ou élément de liste ; balises retirées, entités décodées.
/// Un texte sans balise est rendu tel quel.
String depuisHtml(String t) {
  if (!RegExp(r'<(br|p|div|li|tr|td|span|b|i|font|table|ul|ol|html|body)\b', caseSensitive: false).hasMatch(t)) return t;
  var s = t
      .replaceAll(RegExp(r'<(style|script|head)\b[^>]*>.*?</\1\s*>', caseSensitive: false, dotAll: true), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'\r?\n'), ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?(p|div|li|tr|h[1-6]|ul|ol|table)\b[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</td\s*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  const entites = {'nbsp': ' ', 'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'eacute': 'é', 'egrave': 'è',
      'ecirc': 'ê', 'agrave': 'à', 'acirc': 'â', 'ccedil': 'ç', 'ocirc': 'ô', 'icirc': 'î', 'ugrave': 'ù', 'ucirc': 'û',
      'oelig': 'œ', 'euro': '€', 'rsquo': '\u2019', 'laquo': '«', 'raquo': '»', 'middot': '·'};
  s = s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final e = m[1]!;
    if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
    if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
    return entites[e] ?? m[0]!;
  });
  return s.split('\n').map((l) => l.replaceAll(RegExp(r'[ \t\u00a0]+'), ' ').trim()).where((l) => l.isNotEmpty).join('\n');
}

/// Titre de rubrique reconnu : un rayon (et peut-être un de ses secteurs) du catalogue.
class _Titre {
  _Titre(this.rayon, this.secteur);
  final Rayon rayon;
  final Secteur? secteur;
  String get nom => secteur == null ? rayon.nom : '${rayon.nom} › ${secteur!.nom}';
}

/// La ligne est-elle le nom d'un rayon ou d'un secteur du catalogue (« BOUCHERIE », « Fruits et légumes : »,
/// « Crèmerie / Fromages ») ? On compare les mots, sans majuscules, accents ni pluriels.
_Titre? _titre(Etat etat, String ligne) {
  final t = ligne.trim();
  if (RegExp(r'^[-–—*•·+>]').hasMatch(t) || RegExp(r'\d').hasMatch(t)) return null;
  final sans = t.replaceFirst(RegExp(r'\s*:\s*$'), '');
  String cle(String x) => _mots(x).join(' ');
  final parties = sans.split(RegExp(r'\s*(/|›|>|-)\s*')).where((x) => x.trim().isNotEmpty).toList();
  final rayons = etat.rayonsCatalogue;
  // « Rayon / Secteur »
  if (parties.length == 2) {
    for (final r in rayons) {
      if (cle(r.nom) != cle(parties[0])) continue;
      for (final x in etat.secteursDu(r.id)) {
        if (cle(x.nom) == cle(parties[1])) return _Titre(r, x);
      }
    }
  }
  final c = cle(sans);
  if (c.isEmpty) return null;
  for (final r in rayons) {
    for (final x in etat.secteursDu(r.id)) {
      if (cle(x.nom) == c) return _Titre(r, x);
    }
  }
  for (final r in rayons) {
    if (cle(r.nom) == c) return _Titre(r, null);
  }
  return null;
}

/// Produits rangés sous un titre (le secteur, ou tout le rayon).
List<Produit> _produitsDu(Etat etat, _Titre t) => t.secteur != null
    ? etat.produitsDuSecteur(t.secteur!)
    : [for (final x in etat.secteursDu(t.rayon.id)) ...etat.produitsDuSecteur(x)];

/// Marques connues (catalogue des marques de tous les secteurs, et marques des produits), les plus longues
/// d'abord : « Paysan Breton » avant « Paysan ».
List<String> _marquesConnues(Etat etat) {
  final res = <String, String>{};
  for (final r in etat.rayonsCatalogue) {
    for (final x in etat.secteursDu(r.id)) {
      for (final n in etat.marquesDuSecteur(x)) {
        res.putIfAbsent(normaliser(n), () => n);
      }
    }
  }
  for (final m in etat.marques) {
    res.putIfAbsent(normaliser(m.nom), () => m.nom);
  }
  res.remove('');
  return res.values.toList()..sort((a, b) => normaliser(b).length.compareTo(normaliser(a).length));
}

/// La marque écrite dans la ligne (mots entiers), si elle n'est pas déjà dans le nom du produit reconnu.
String? _marqueDans(List<String> marques, String ligne, Produit? p) {
  final t = ' ${normaliser(ligne)} ';
  final dansNom = p == null ? '' : ' ${normaliser(p.nom)} ';
  for (final m in marques) {
    final n = normaliser(m);
    if (n.length < 2 || !t.contains(' $n ') || dansNom.contains(' $n ')) continue;
    return m;
  }
  return null;
}

/// Lit le texte collé : un article par ligne (ou séparés par des virgules sur une même ligne).
/// Le HTML (source d'un mail) est d'abord ramené à du texte. Une ligne qui porte le nom d'un rayon ou
/// d'un secteur est un titre : les produits qui la suivent y sont cherchés d'abord, et un produit inconnu
/// y est rangé. [rapport] reçoit les titres reconnus et les difficultés.
List<ArticleLu> lireTexte(Etat etat, String texte, {List<Difficulte>? rapport}) {
  texte = depuisHtml(texte);
  final res = <ArticleLu>[];
  final produits = etat.produits;
  Produit? parNom(String nom) {
    final n = normaliser(nom);
    for (final p in produits) {
      if (normaliser(p.nom) == n) return p;
    }
    return null;
  }

  final lignes = texte.split(RegExp(r'\r?\n'));
  final marques = _marquesConnues(etat);
  _Titre? titre;
  var precedente = '';
  for (var i = 0; i < lignes.length; i++) {
    final brute = lignes[i];
    // Suite d'une longue ligne coupée par la messagerie (« … conserver à » / « l'occasion. »)
    final suite = precedente.length > 30 && RegExp(r'[a-zà-ÿ(,]$').hasMatch(precedente.trim()) &&
        RegExp(r'^[a-zà-ÿ]').hasMatch(brute.trim());
    precedente = brute;
    if (suite && _chercher(produits, brute) == null) {
      rapport?.add(Difficulte(brute.trim(), 'Prise pour la suite de la ligne précédente, ignorée.'));
      continue;
    }
    // Titre de rayon ou de secteur. En capitales ou suivi de « : », c'est sûr ; sinon (« Fromages » peut être
    // un article), ce n'est un titre que si la ligne suivante est un produit de ce rayon ou secteur.
    final t = _titre(etat, brute);
    if (t != null) {
      final sans = brute.trim().replaceFirst(RegExp(r'\s*:\s*$'), '');
      var estTitre = brute.trim().endsWith(':') || (sans == sans.toUpperCase() && sans.length > 3);
      if (estTitre) {
        rapport?.add(Difficulte(brute.trim(), 'Titre reconnu : ${t.nom}.'));
      } else {
        final suivante = lignes.skip(i + 1).firstWhere((x) => x.trim().isNotEmpty, orElse: () => '');
        estTitre = suivante.isNotEmpty && _chercher(_produitsDu(etat, t), _nettoyer(suivante).$1) != null;
        rapport?.add(Difficulte(brute.trim(), estTitre
            ? 'Nom de ${t.secteur == null ? 'rayon' : 'secteur'} : pris pour le titre ${t.nom}, la ligne suivante en faisant partie.'
            : 'Nom de ${t.secteur == null ? 'rayon' : 'secteur'}, mais la ligne suivante n\'en fait pas partie : pris pour un article.'));
      }
      if (estTitre) {
        titre = t;
        continue;
      }
    }
    // « pain, beurre, œufs » : plusieurs articles sur une ligne ; pas une phrase avec une virgule.
    final parts = brute.split(',');
    final morceaux = parts.length > 1 && !brute.contains('(') && !RegExp(r'\d,\d').hasMatch(brute) &&
            parts.every((x) => x.trim().length <= 30)
        ? parts
        : [brute];
    for (final ligne in morceaux) {
      if (_horsListe(ligne)) {
        if (normaliser(ligne).length > 2 && RegExp(r'[a-z]').hasMatch(normaliser(ligne))) {
          rapport?.add(Difficulte(ligne.trim(), 'Formule du mail (salutation, signature…), ignorée.'));
        }
        continue;
      }
      final (nom, q) = _nettoyer(ligne);
      if (nom.isEmpty) continue;
      final capitales = nom == nom.toUpperCase() && nom.length > 3;
      final appris = _correspondances[normaliser(ligne)] ?? _correspondances[normaliser(nom)];
      Produit? p = appris == null ? null : parNom(appris[0]);
      // Sous un titre, le produit est cherché d'abord dans ce rayon ou secteur.
      if (p == null && titre != null) p = _chercher(_produitsDu(etat, titre), nom);
      p ??= _chercher(produits, nom);
      // Intertitre en capitales qui n'est ni un rayon, ni un secteur, ni un produit.
      if (p == null && capitales) {
        rapport?.add(Difficulte(ligne.trim(), 'En capitales mais inconnu du catalogue : ni rayon, ni secteur, ni produit. '
            'Ignoré ; les produits qui suivent ne sont plus rangés sous le titre précédent.'));
        titre = null;
        continue;
      }
      if (p == null) {
        rapport?.add(Difficulte(ligne.trim(), titre?.secteur != null
            ? 'Produit inconnu : sera créé dans ${titre!.nom}.'
            : titre != null
                ? 'Produit inconnu : sera créé non placé (le titre ${titre.nom} est un rayon, pas un secteur).'
                : 'Produit inconnu : sera créé non placé (aucun titre au-dessus).'));
      } else if (titre != null) {
        final s = etat.secteurCatalogue(p.id);
        final dedans = titre.secteur != null ? s?.id == titre.secteur!.id : s?.rayonId == titre.rayon.id;
        if (!dedans) {
          rapport?.add(Difficulte(ligne.trim(), 'Reconnu comme « ${p.nom} », rangé dans '
              '${s == null ? 'aucun secteur' : '${etat.rayon(s.rayonId)?.nom ?? ''} › ${s.nom}'}, pas sous ${titre.nom}.'));
        }
      }
      // Marque : apprise sur les listes du foyer, sinon écrite dans la ligne (« Beurre Président »).
      // Elle va dans la marque de l'article, pas dans la consigne.
      var marque = appris == null || appris[1].isEmpty ? null : appris[1];
      marque ??= _marqueDans(marques, ligne, p);
      if (marque != null && p != null && normaliser(p.nom).contains(normaliser(marque))) marque = null;
      if (marque != null) rapport?.add(Difficulte(ligne.trim(), 'Marque reconnue : $marque, mise en marque de l\'article.'));
      // Produit à créer : la marque ne fait pas partie de son nom
      final nomSeul = p == null && marque != null
          ? nom.replaceAll(RegExp(RegExp.escape(marque), caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim()
          : nom;
      res.add(ArticleLu(ligne.trim(), nomSeul.isEmpty ? nom : nomSeul, q, produit: p, marque: marque, secteur: titre?.secteur));
    }
  }
  return res;
}
