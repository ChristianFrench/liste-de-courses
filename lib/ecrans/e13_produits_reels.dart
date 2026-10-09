import 'package:flutter/material.dart';

import '../composants/code_barres.dart';
import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../donnees/open_food_facts.dart';
import '../navigation.dart';
import '../theme.dart';

/// Écran d'essai — Produits réels, d'après la base libre Open Food Facts.
/// Recherche par nom ou par code-barres ; fiche d'un article ; produits d'une marque.
class EcranProduitsReels extends StatefulWidget {
  const EcranProduitsReels({super.key, this.rechercheInitiale, this.resultatsInitiaux});

  /// Pour les captures automatiques : recherche déjà faite.
  final String? rechercheInitiale;
  final List<ArticleOff>? resultatsInitiaux;

  @override
  State<EcranProduitsReels> createState() => _EcranProduitsReelsState();
}

class _EcranProduitsReelsState extends State<EcranProduitsReels> {
  static const exemples = ['Lait demi-écrémé', 'Pâtes', 'Café moulu', 'Yaourt nature', 'Beurre doux', 'Jambon'];

  final saisie = TextEditingController();
  List<ArticleOff>? resultats;
  String? erreur;
  bool enCours = false;
  String derniere = '';

  @override
  void initState() {
    super.initState();
    if (widget.rechercheInitiale != null) {
      saisie.text = widget.rechercheInitiale!;
      derniere = widget.rechercheInitiale!;
    }
    resultats = widget.resultatsInitiaux;
  }

  @override
  void dispose() {
    saisie.dispose();
    super.dispose();
  }

  Future<void> _chercher(String texte) async {
    texte = texte.trim();
    if (texte.isEmpty || enCours) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saisie.text = texte;
      derniere = texte;
      enCours = true;
      erreur = null;
    });
    try {
      final chiffres = texte.replaceAll(' ', '');
      List<ArticleOff> trouves;
      if (RegExp(r'^\d{8,14}$').hasMatch(chiffres)) {
        final a = await OpenFoodFacts.instance.parCode(chiffres);
        trouves = a == null ? [] : [a];
      } else {
        trouves = await OpenFoodFacts.instance.rechercher(texte);
      }
      if (!mounted) return;
      setState(() => resultats = trouves);
    } on ErreurOff catch (e) {
      if (!mounted) return;
      setState(() => erreur = e.message);
    } finally {
      if (mounted) setState(() => enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBase(
      entete: EnTeteGestion(
        titre: 'Produits réels (essai)',
        action: Text('Open Food Facts', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ),
      haut: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: saisie,
                  style: Charte.texte(16),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Nom du produit ou code-barres'),
                  onSubmitted: _chercher,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Bouton(texte: '', icone: Icons.search, plein: true, onTap: () => _chercher(saisie.text)),
              ),
            ],
          ),
        ),
        BandeauPuces(
          puces: [for (final e in exemples) Puce(e)],
          selection: exemples.indexOf(derniere),
          onChoix: (i) => _chercher(exemples[i]),
        ),
      ],
      corps: _corps(),
      bas: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          color: Charte.fondBandeau,
          child: Text(
            'Données et photos : Open Food Facts (openfoodfacts.org), base collaborative libre — '
            'licences ODbL et CC BY-SA.',
            style: Charte.texte(11, couleur: Charte.texteSecondaire),
          ),
        ),
        const BarreNavigation(index: 2),
      ],
    );
  }

  Widget _corps() {
    if (enCours) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Charte.encre),
            const SizedBox(height: 12),
            Text('Recherche « $derniere »…', style: Charte.texte(15)),
          ],
        ),
      );
    }
    if (erreur != null) {
      return _message(Icons.cloud_off_outlined, erreur!, bouton: 'Réessayer', onTap: () => _chercher(derniere));
    }
    final r = resultats;
    if (r == null) {
      return _message(
        Icons.travel_explore,
        'Cherchez un produit par son nom ou tapez les chiffres de son code-barres, '
        'ou touchez un exemple ci-dessus.\n\nUne connexion internet est nécessaire.',
      );
    }
    if (r.isEmpty) return _message(Icons.search_off, 'Aucun produit trouvé pour « $derniere ».');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: r.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('${r.length} produit${r.length > 1 ? 's' : ''} vendus en France · codes-barres français d\'abord',
                style: Charte.texte(12, couleur: Charte.texteSecondaire)),
          );
        }
        return LigneArticle(article: r[i - 1]);
      },
    );
  }

  Widget _message(IconData icone, String texte, {String? bouton, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 40, color: Charte.texteSecondaire),
          const SizedBox(height: 12),
          Text(texte, textAlign: TextAlign.center, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
          if (bouton != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: 200, child: Bouton(texte: bouton, onTap: onTap)),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'un article : photo, nom, marque, quantité, Nutri-Score, code-barres.
class LigneArticle extends StatelessWidget {
  const LigneArticle({super.key, required this.article});
  final ArticleOff article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    return Material(
      color: Charte.fond,
      child: InkWell(
        onTap: () => Nav.aller(context, EcranArticle(article: a)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoArticle(url: a.imagePetite, taille: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: Charte.texte(16, gras: true)),
                    const SizedBox(height: 2),
                    Text(
                      [if (a.marque.isNotEmpty) a.marque, if (a.quantite.isNotEmpty) a.quantite].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Charte.texte(13, couleur: Charte.texteSecondaire),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 15, color: Charte.texteSecondaire),
                        const SizedBox(width: 3),
                        Text(a.code, style: Charte.texte(12, couleur: Charte.texteSecondaire)),
                        const Spacer(),
                        PastilleNutriscore(lettre: a.nutriscore),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Charte.encre),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fiche d'un article réel.
class EcranArticle extends StatelessWidget {
  const EcranArticle({super.key, required this.article});
  final ArticleOff article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    Widget ligne(String etiquette, Widget valeur) => Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(etiquette, style: Charte.texte(14, couleur: Charte.texteSecondaire))),
              Expanded(child: valeur),
            ],
          ),
        );
    return PageBase(
      entete: EnTeteGestion(titre: a.nom),
      corps: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 12),
          Center(child: PhotoArticle(url: a.imageGrande.isNotEmpty ? a.imageGrande : a.imagePetite, taille: 200)),
          const SizedBox(height: 12),
          Center(child: CodeBarres(code: a.code)),
          const SizedBox(height: 8),
          ligne('Nom', Text(a.nom, style: Charte.texte(16, gras: true))),
          if (a.nomGenerique.isNotEmpty) ligne('Dénomination', Text(a.nomGenerique, style: Charte.texte(15))),
          ligne(
            'Marque',
            a.marqueTag == null
                ? Text(a.marque.isEmpty ? '—' : a.marque, style: Charte.texte(15))
                : Lien('${a.marque} · voir tous ses produits',
                    taille: 15, onTap: () => Nav.aller(context, EcranMarque(marque: a.marque, marqueTag: a.marqueTag!))),
          ),
          if (a.marques.length > 1) ligne('Autres marques', Text(a.marques.skip(1).join(', '), style: Charte.texte(15))),
          ligne('Quantité', Text(a.quantite.isEmpty ? '—' : a.quantite, style: Charte.texte(15))),
          ligne('Code-barres', Text(a.code, style: Charte.texte(15))),
          ligne(
            'Nutri-Score',
            Align(
              alignment: Alignment.centerLeft,
              child: a.nutriscore.isEmpty
                  ? Text('non calculé', style: Charte.texte(15))
                  : PastilleNutriscore(lettre: a.nutriscore),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fiche Open Food Facts : ${OpenFoodFacts.hote}/produit/${a.code}',
            style: Charte.texte(12, couleur: Charte.texteSecondaire),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bas: [
        BarreAction(boutons: [
          Bouton(texte: 'Ajouter au catalogue', plein: true, onTap: () => _ajouter(context)),
        ]),
      ],
    );
  }

  /// Rattache l'article à un produit générique de la maquette :
  /// sa marque et sa quantité deviennent une marque et un packaging du produit.
  Future<void> _ajouter(BuildContext context) async {
    final etat = Etat.instance;
    const nouveau = '__nouveau__';
    final proposition = article.nomGenerique.isNotEmpty ? article.nomGenerique : article.nom;
    final produits = [...etat.produits]..sort((x, y) => x.nom.compareTo(y.nom));
    final choix = await choisirDansListe<String>(
      context,
      titre: 'Rattacher « ${article.nom} » à quel produit ?',
      choix: {
        nouveau: '+ Nouveau produit : $proposition',
        for (final p in produits) p.id: p.nom,
      },
    );
    if (choix == null || !context.mounted) return;
    Produit p;
    if (choix == nouveau) {
      final nom = await demanderTexte(context, titre: 'Nom du produit générique', initial: proposition);
      if (nom == null || nom.isEmpty || !context.mounted) return;
      p = etat.creerProduit(nom);
    } else {
      p = etat.produit(choix)!;
    }
    if (article.marque.isNotEmpty) etat.ajouterMarque(p, article.marque);
    if (article.quantite.isNotEmpty) etat.ajouterPackaging(p, article.quantite);
    Nav.message(context, 'Ajouté à « ${p.nom} » : marque et packaging');
  }
}

/// Tous les produits d'une marque (vendus en France).
class EcranMarque extends StatefulWidget {
  const EcranMarque({super.key, required this.marque, required this.marqueTag, this.initial});
  final String marque;
  final String marqueTag;

  /// Pour les captures automatiques : résultat déjà chargé.
  final (int, List<ArticleOff>)? initial;

  @override
  State<EcranMarque> createState() => _EcranMarqueState();
}

class _EcranMarqueState extends State<EcranMarque> {
  (int, List<ArticleOff>)? resultat;
  String? erreur;

  @override
  void initState() {
    super.initState();
    resultat = widget.initial;
    if (resultat == null) _charger();
  }

  Future<void> _charger() async {
    setState(() => erreur = null);
    try {
      final r = await OpenFoodFacts.instance.parMarque(widget.marqueTag);
      if (mounted) setState(() => resultat = r);
    } on ErreurOff catch (e) {
      if (mounted) setState(() => erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    Widget corps;
    if (erreur != null) {
      corps = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(erreur!, textAlign: TextAlign.center, style: Charte.texte(15, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 16),
            SizedBox(width: 200, child: Bouton(texte: 'Réessayer', onTap: _charger)),
          ],
        ),
      );
    } else if (r == null) {
      corps = const Center(child: CircularProgressIndicator(color: Charte.encre));
    } else {
      corps = ListView.builder(
        itemCount: r.$2.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            final affiches = r.$2.length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                r.$1 > affiches
                    ? '${r.$1} produits vendus en France · les $affiches plus scannés'
                    : '${r.$1} produit${r.$1 > 1 ? 's' : ''} vendu${r.$1 > 1 ? 's' : ''} en France',
                style: Charte.texte(12, couleur: Charte.texteSecondaire),
              ),
            );
          }
          return LigneArticle(article: r.$2[i - 1]);
        },
      );
    }
    return PageBase(
      entete: EnTeteGestion(
        titre: 'Marque · ${widget.marque}',
        action: Text('Open Food Facts', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
      ),
      corps: corps,
      bas: const [BarreNavigation(index: 2)],
    );
  }
}
