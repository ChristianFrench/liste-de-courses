import 'package:flutter/material.dart';

import '../composants/code_barres.dart';
import '../composants/composants.dart';
import '../donnees/catalogue_off.dart';
import '../donnees/modele.dart';
import '../donnees/open_food_facts.dart';
import '../navigation.dart';
import '../theme.dart';

/// Écran d'essai — Produits réels, d'après la base libre Open Food Facts.
/// La recherche se fait dans le catalogue gardé sur l'appareil (sans réseau) :
/// par catégorie, par nom ou marque, ou par code-barres.
class EcranProduitsReels extends StatefulWidget {
  const EcranProduitsReels({super.key, this.rechercheInitiale, this.resultatsInitiaux, this.explicationInitiale = ''});

  /// Pour les captures automatiques : recherche déjà faite.
  final String? rechercheInitiale;
  final List<ArticleOff>? resultatsInitiaux;
  final String explicationInitiale;

  @override
  State<EcranProduitsReels> createState() => _EcranProduitsReelsState();
}

class _EcranProduitsReelsState extends State<EcranProduitsReels> {
  static const exemples = ['Lait demi-écrémé', 'Pâtes', 'Café moulu', 'Yaourt nature', 'Beurre doux', 'Jambon'];

  final saisie = TextEditingController();
  List<ArticleOff>? resultats;
  String explication = '';
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
    explication = widget.explicationInitiale;
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
      final catalogue = CatalogueOff.instance;
      final chiffres = texte.replaceAll(' ', '');
      List<ArticleOff> trouves;
      var texteExplication = '';
      if (RegExp(r'^\d{8,14}$').hasMatch(chiffres)) {
        // Code-barres : catalogue de l'appareil, sinon site d'Open Food Facts
        final local = catalogue.parCode(chiffres);
        if (local != null) {
          trouves = [local];
          texteExplication = 'Code-barres trouvé dans le catalogue';
        } else {
          final a = await OpenFoodFacts.instance.parCode(chiffres);
          trouves = a == null ? [] : [a];
          texteExplication = 'Code-barres absent du catalogue : recherche sur le site d\'Open Food Facts';
        }
      } else {
        final r = catalogue.rechercher(texte);
        trouves = r.articles;
        texteExplication = r.explication;
      }
      if (!mounted) return;
      setState(() {
        resultats = trouves;
        explication = texteExplication;
      });
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
        action: BoutonIcone(
          icone: Icons.cloud_sync_outlined,
          libelle: 'Catalogue et mises à jour',
          onTap: () => Nav.aller(context, const EcranCatalogue()),
        ),
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
        ListenableBuilder(
          listenable: CatalogueOff.instance,
          builder: (context, _) => _EtatCatalogue(onTap: () => Nav.aller(context, const EcranCatalogue())),
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
        'Cherchez une catégorie (« pâtes », « café moulu »…), un nom ou une marque, '
        'ou tapez les chiffres d\'un code-barres. Vous pouvez aussi toucher un exemple ci-dessus.\n\n'
        'La recherche se fait dans le catalogue gardé sur l\'appareil : pas besoin de réseau.',
      );
    }
    if (r.isEmpty) {
      return _message(Icons.search_off,
          CatalogueOff.instance.vide ? 'Le catalogue n\'est pas encore chargé.' : 'Aucun produit trouvé pour « $derniere ».');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: r.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
                r.length >= 100 && explication.isNotEmpty
                    ? '$explication · les 100 plus populaires'
                    : (explication.isEmpty ? '${r.length} produit${r.length > 1 ? 's' : ''}' : explication),
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
          if (a.categories.isNotEmpty) ligne('Catégorie', Text(a.categories.last, style: Charte.texte(15))),
          ligne(
            'Marque',
            a.marque.isEmpty
                ? Text('—', style: Charte.texte(15))
                : Lien('${a.marque} · voir tous ses produits',
                    taille: 15, onTap: () => Nav.aller(context, EcranMarque(marque: a.marque))),
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

/// Tous les produits d'une marque présents dans le catalogue de l'appareil.
class EcranMarque extends StatelessWidget {
  const EcranMarque({super.key, required this.marque});
  final String marque;

  @override
  Widget build(BuildContext context) {
    final articles = CatalogueOff.instance.parMarque(marque);
    return PageBase(
      entete: EnTeteGestion(titre: 'Marque · $marque'),
      corps: ListView.builder(
        itemCount: articles.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                '${articles.length} produit${articles.length > 1 ? 's' : ''} de cette marque dans le catalogue, '
                'les plus populaires d\'abord',
                style: Charte.texte(12, couleur: Charte.texteSecondaire),
              ),
            );
          }
          return LigneArticle(article: articles[i - 1]);
        },
      ),
      bas: const [BarreNavigation(index: 2)],
    );
  }
}

/// Ligne d'état du catalogue, sous la recherche.
class _EtatCatalogue extends StatelessWidget {
  const _EtatCatalogue({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CatalogueOff.instance;
    String texte;
    if (!c.charge) {
      texte = 'Chargement du catalogue…';
    } else if (c.vide) {
      texte = 'Catalogue absent : touchez ici pour le télécharger';
    } else {
      final n = c.nbProduits.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
      texte = 'Catalogue : $n produits, à jour au ${c.majDate}${c.enCours ? ' · mise à jour en cours…' : ''}';
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        color: Charte.fondBandeau,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(c.enCours ? Icons.sync : Icons.inventory_2_outlined, size: 16, color: Charte.texteSecondaire),
            const SizedBox(width: 8),
            Expanded(child: Text(texte, style: Charte.texte(12, couleur: Charte.texteSecondaire))),
            const Icon(Icons.chevron_right, size: 18, color: Charte.texteSecondaire),
          ],
        ),
      ),
    );
  }
}

/// Catalogue : version, délai de rafraîchissement, mise à jour manuelle.
class EcranCatalogue extends StatelessWidget {
  const EcranCatalogue({super.key});

  static String _libelleDelai(int j) => switch (j) {
        0 => 'Manuel',
        1 => '1 jour',
        _ => '$j jours',
      };

  @override
  Widget build(BuildContext context) {
    final c = CatalogueOff.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget ligne(String etiquette, String valeur) => Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
              child: Row(
                children: [
                  SizedBox(width: 150, child: Text(etiquette, style: Charte.texte(14, couleur: Charte.texteSecondaire))),
                  Expanded(child: Text(valeur, style: Charte.texte(15))),
                ],
              ),
            );
        final v = c.derniereVerification;
        return PageBase(
          entete: const EnTeteGestion(titre: 'Catalogue des produits réels'),
          corps: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const TitreSection('Contenu', cote: 0),
              ligne('Produits', c.vide ? 'aucun' : '${c.nbProduits}'),
              ligne('Base du', c.baseDate.isEmpty ? '—' : c.baseDate),
              ligne('Mis à jour jusqu\'au', c.majDate.isEmpty ? '—' : c.majDate),
              ligne('Dernière vérification', v == null ? 'jamais' : CatalogueOff.dateHeure(v)),
              const TitreSection('Rafraîchissement automatique', cote: 0),
              Text(
                'L\'application vérifie elle-même s\'il existe une mise à jour, à son ouverture puis toutes les heures, '
                'dès que le délai choisi est écoulé. Seules les modifications sont téléchargées, sauf au changement '
                'de catalogue mensuel.',
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final j in CatalogueOff.delais)
                    SizedBox(
                      width: 80,
                      child: Bouton(
                        texte: _libelleDelai(j),
                        taille: 15,
                        hauteur: 44,
                        plein: c.delaiJours == j,
                        onTap: () => c.changerDelai(j),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Bouton(
                texte: c.enCours ? 'Mise à jour en cours…' : 'Mettre à jour maintenant',
                icone: Icons.sync,
                plein: true,
                onTap: c.enCours ? null : () => c.verifier(force: true),
              ),
              if (c.message != null) ...[
                const SizedBox(height: 10),
                Text(c.message!, style: Charte.texte(14, gras: true)),
              ],
              const TitreSection('Source', cote: 0),
              Text(
                'Open Food Facts (openfoodfacts.org), base collaborative libre : données sous licence ODbL, '
                'photos sous licence CC BY-SA. Extrait : les produits vendus en France les plus scannés, '
                'reconstruit chaque mois et complété chaque nuit.',
                style: Charte.texte(13, couleur: Charte.texteSecondaire),
              ),
              const SizedBox(height: 16),
            ],
          ),
          bas: const [BarreNavigation(index: 2)],
        );
      },
    );
  }
}
