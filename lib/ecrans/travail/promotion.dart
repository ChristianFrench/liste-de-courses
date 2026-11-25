part of '../travail.dart';


/// Volet d'un article de la liste : packaging, consigne et promotion visée.
Future<void> ouvrirFeuillePromotion(BuildContext context, Liste l, LigneListe g) =>
    volet<void>(context, builder: (_) => FeuillePromotion(liste: l, ligne: g));

/// Volet de l'article : le packaging (pack de x), la consigne, puis la promotion visée.
class FeuillePromotion extends StatefulWidget {
  const FeuillePromotion({super.key, required this.liste, required this.ligne});
  final Liste liste;
  final LigneListe ligne;

  static String nomCourt(TypePromotion? t) => switch (t?.id) {
        null => 'Aucune',
        'prix' => 'Prix promo',
        'lot' => 'Lot x+y',
        'prixGlobal' => 'Lot pour promo',
        'remise' => 'Remise',
        'fidelite' => 'Fidélité',
        _ => t!.nom,
      };

  /// Promotions proposées (03/11/2026 : PX prix promo, LOT x+y, 2=€ lot pour promo, −% remise, FID fidélité, ? autre).
  static const typesProposes = ['prix', 'lot', 'prixGlobal', 'remise', 'fidelite', 'autre'];
  static const aucune = '';

  @override
  State<FeuillePromotion> createState() => _FeuillePromotionState();
}

class _FeuillePromotionState extends State<FeuillePromotion> {
  final etat = Etat.instance;
  /// Promotion visée, posée par le volet « Promo » ; enregistrée avec le reste à « Valider ».
  PromotionLigne? promo;
  final consigne = TextEditingController();
  String? packagingId;

  /// Marque choisie ('' : indifférente) et celle de la ligne à l'ouverture du volet.
  late String marque;
  late final String marqueAvant;

  @override
  void initState() {
    super.initState();
    promo = widget.ligne.promotion;
    packagingId = widget.ligne.packagingId;
    marque = marqueAvant = etat.marque(widget.ligne.marqueId)?.nom ?? '';
    consigne.text = widget.ligne.consigne ?? '';
  }

  @override
  void dispose() {
    consigne.dispose();
    super.dispose();
  }

  void _valider() {
    _enregistrer();
    Navigator.of(context).pop();
  }

  /// Enregistre le volet ; rend l'article de la ligne (il change avec la marque).
  String _enregistrer() {
    final id = widget.ligne.produitId;
    etat.definirPackaging(widget.liste, id, packagingId);
    etat.definirConsigne(widget.liste, id, consigne.text);
    etat.definirPromotion(widget.liste, id, promo);
    // La marque en dernier : « Camembert » devient l'article « Camembert Président ».
    final p = etat.produit(id);
    if (marque != marqueAvant && p != null) return etat.changerMarque(widget.liste, p, marque.isEmpty ? null : marque).id;
    return id;
  }

  /// « Nom, rayon, secteur » : le volet est enregistré, puis l'article renommé ou rangé ailleurs.
  Future<void> _modifierArticle() async {
    final nav = Navigator.of(context);
    final id = _enregistrer();
    nav.pop();
    final p = etat.produit(id);
    if (p != null) await modifierArticle(nav.context, widget.liste, p);
  }

  @override
  Widget build(BuildContext context) {
    final p = etat.produit(widget.ligne.produitId);
    final m = etat.magasin(widget.liste.magasinId);
    // Formats du produit, sinon ceux de son secteur
    final proposes = p == null
        ? <String>[]
        : (p.packagingIds.isNotEmpty ? p.packagingIds : etat.formatsDuSecteur(widget.liste.magasinId, p.id));
    // Marques distributeur de l'enseigne du magasin, signalées par l'enseigne
    final mdd = p == null ? const <String>{} : etat.marquesDistributeurPour(m, etat.secteurCatalogue(p.id)).toSet();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p?.nom ?? 'Article', style: Charte.texte(21, gras: true)),
          Text(m?.nom ?? '', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('consigne'),
            controller: consigne,
            style: Charte.texte(17),
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Consigne', hintText: 'Ex. : bien mûres, la moins chère'),
          ),
          if (p != null) ...[
            const SizedBox(height: 14),
            ChoixDeroulant<String>(
              key: const ValueKey('choix-marque'),
              libelle: 'Marque',
              valeur: marque,
              choix: {
                '': 'Indifférente',
                for (final n in {...etat.marquesProposees(widget.ligne, p, magasinId: widget.liste.magasinId), if (marque.isNotEmpty) marque})
                  n: mdd.contains(n) ? '$n · ${etat.enseigneDe(m)}' : n,
                _autre: 'Autre marque…',
              },
              onChange: (v) async {
                if (v != _autre) return setState(() => marque = v);
                final n = await autreMarque(context, etat.secteurCatalogue(p.id));
                if (n == null || !mounted) return;
                setState(() => marque = n);
              },
            ),
          ],
          const SizedBox(height: 14),
          // 03/11/2026 (Aristide) : la promotion se choisit dans le volet « Promo » (nature, puis prix, lot…).
          InkWell(
            key: const ValueKey('choix-promo'),
            onTap: () async {
              final r = await voletPromo(context, article: p?.nom ?? 'l\'article', actuelle: promo);
              if (r != null && mounted) setState(() => promo = r.promo);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Promotion visée', suffixIcon: Icon(Icons.arrow_drop_down)),
              child: Text(promo == null ? 'Aucune' : '${texteCourtPromo(promo!)} · ${promo!.libelle}',
                  style: Charte.texte(17, couleur: promo == null ? Charte.texteSecondaire : Charte.encre)),
            ),
          ),
          const SizedBox(height: 14),
          ChoixDeroulant<String>(
            key: const ValueKey('choix-packaging'),
            libelle: 'Packaging',
            valeur: packagingId ?? '',
            choix: {
              '': 'Indifférent',
              for (final k in {...proposes, if (packagingId != null) packagingId!}) k: etat.packaging(k)?.libelle ?? '',
              _autre: 'Autre format…',
            },
            onChange: (v) async {
              if (v != _autre) return setState(() => packagingId = v.isEmpty ? null : v);
              if (p != null) await _autreFormat(p, proposes);
            },
          ),
          if (p != null && p.packagingIds.isEmpty && proposes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Formats courants du secteur, ce produit n\'en a pas encore.',
                  style: Charte.texte(13, couleur: Charte.texteSecondaire)),
            ),
          const SizedBox(height: 14),
          if (p != null) ...[
            Bouton(key: const ValueKey('modifier-article'), texte: 'Nom, rayon, secteur', onTap: _modifierArticle),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: Bouton(texte: 'Annuler', onTap: () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(child: Bouton(texte: 'Valider', plein: true, onTap: _valider)),
            ],
          ),
        ],
      ),
    );
  }

  static const _autre = '\u0000autre';

  /// « Autre format… » : un format connu de la famille, ou un nouveau.
  Future<void> _autreFormat(Produit p, List<String> proposes) async {
    final autres = [for (final k in etat.typesPackaging) if (!proposes.contains(k)) k];
    final v = await choisirDansListe<String>(
      context,
      titre: 'Choisir un format',
      choix: {'': '+ Nouveau format…', for (final k in autres) k: etat.packaging(k)?.libelle ?? ''},
    );
    if (v == null || !mounted) return;
    if (v.isNotEmpty) {
      etat.ajouterPackaging(p, etat.packaging(v)!.libelle);
      setState(() => packagingId = v);
      return;
    }
    final lib = await demanderTexte(context, libelle: 'Format', titre: 'Nouveau format', aide: 'Ex. : 500 g, 75 cl, lot de 4, pack de 6');
    if (lib == null || lib.isEmpty || !mounted) return;
    etat.ajouterPackaging(p, lib);
    etat.ajouterTypePackaging(lib);
    setState(() => packagingId = p.packagingIds.last);
  }
}


/// « PX2,50€ » : code du type de promotion collé à sa valeur.
String texteCourtPromo(PromotionLigne p) {
  final code = Etat.instance.typePromotion(p.type)?.code ?? 'P';
  final v = p.valeur.replaceAll(' ', '');
  return '$code$v';
}

/// Promotion d'une ligne de préparation : le volet « Promo », puis la ligne mise à jour.
/// [abandonner] (ajout par la recherche, 25/11/2026, Aristide) : le volet propose aussi d'abandonner l'article.
Future<void> proposerPromo(BuildContext context, Liste l, LigneListe g, {VoidCallback? abandonner}) async {
  final etat = Etat.instance;
  // 13/11/2026 (Aristide) : le nombre à acheter en haut du même volet.
  final r = await voletPromo(context,
      article: etat.produit(g.produitId)?.nom ?? 'l\'article',
      actuelle: g.promotion,
      quantite: g.quantite,
      onQuantite: (q) => etat.quantite(l, g.produitId, q),
      abandonner: abandonner);
  if (r != null) etat.definirPromotion(l, g.produitId, r.promo);
}

/// Volet « Promo » (04/11/2026, Aristide) : la nature en une rangée de boutons (PX, LOT, 2=€, −%, FID, ?),
/// puis une seule zone de saisie adaptée (prix, x + y, pourcentage ou montant, texte), OK ou Sans promo.
/// Rend la promotion choisie (promo null : sans promotion), ou null si le volet est fermé sans choix.
/// [quantite] et [onQuantite] (ajout par la recherche) : le nombre à acheter, en haut, appliqué aussitôt.
Future<({PromotionLigne? promo})?> voletPromo(BuildContext context,
    {required String article, PromotionLigne? actuelle, int? quantite, ValueChanged<int>? onQuantite, VoidCallback? abandonner}) {
  final etat = Etat.instance;
  var nombre = quantite ?? 1;
  final types = [
    for (final id in FeuillePromotion.typesProposes)
      if (etat.typePromotion(id) case final t?) t,
  ];
  String? type = actuelle?.type;
  final par = actuelle?.parametres ?? const <String, dynamic>{};
  String v(String k) => par[k] == null ? '' : '${par[k]}'.replaceAll('.', ',');
  var enMontant = par.containsKey('montant');
  final a = TextEditingController(
      text: switch (type) {
    'prix' => v('prix'),
    'lot' => v('quantiteAchetee'),
    'prixGlobal' => v('quantiteMinimale'),
    'remise' || 'fidelite' => enMontant ? v('montant') : v('pourcentage'),
    null => '',
    _ => actuelle?.valeur ?? '',
  });
  final b = TextEditingController(text: type == 'lot' ? v('quantiteOfferte') : '');
  final focus = FocusNode();
  final couleur = etat.couleurPromo('prix');
  final c = couleur == null ? Charte.rouge : Color(couleur);

  PromotionLigne construire() {
    final t = type!;
    final nom = FeuillePromotion.nomCourt(etat.typePromotion(t));
    final saisie = switch (t) {
      'lot' => '${a.text.trim()}+${b.text.trim()}',
      'remise' || 'fidelite' => enMontant ? '${a.text.trim()} €' : a.text.trim(),
      _ => a.text.trim(),
    };
    return PromotionLigne.depuisValeur(t, saisie, nomType: nom);
  }

  Widget champ(TextEditingController ct, String libelle, {bool nombre = true, bool auto = true}) => TextField(
        key: ValueKey('promo-saisie-$libelle'),
        controller: ct,
        focusNode: auto ? focus : null,
        autofocus: auto,
        style: Charte.texte(20, gras: true),
        textAlign: TextAlign.center,
        keyboardType: nombre ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: libelle),
      );

  return volet<({PromotionLigne? promo})>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) {
        final zone = switch (type) {
          null => Text('Choisissez la nature de la promotion.', style: Charte.texte(14, couleur: Charte.texteSecondaire)),
          'prix' => champ(a, 'Prix promo (€)'),
          'lot' => Row(children: [
              Expanded(child: champ(a, 'Achetés')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('+', style: Charte.texte(22, gras: true))),
              Expanded(child: champ(b, 'Offerts', auto: false)),
            ]),
          'prixGlobal' => champ(a, 'Quantité à acheter'),
          'remise' || 'fidelite' => Row(children: [
              Expanded(child: champ(a, enMontant ? 'Montant (€)' : 'Pourcentage (%)')),
              const SizedBox(width: 10),
              Bascule(options: const ['%', '€'], index: enMontant ? 1 : 0, onChange: (i) => maj(() => enMontant = i == 1)),
            ]),
          _ => champ(a, 'Description', nombre: false),
        };
        return corpsVolet(
          titre: 'Promo pour $article ?',
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (onQuantite != null) ...[
              Row(children: [
                Expanded(child: Text('Nombre à acheter', style: Charte.texte(16, gras: true))),
                Semantics(
                  button: true,
                  label: 'Un de moins',
                  child: IconButton(
                    key: const ValueKey('promo-moins'),
                    iconSize: 28,
                    onPressed: nombre <= 1
                        ? null
                        : () => maj(() {
                              nombre--;
                              onQuantite(nombre);
                            }),
                    icon: Icon(Icons.remove_circle_outline, color: nombre <= 1 ? Charte.texteSecondaire : Charte.cadre),
                  ),
                ),
                SizedBox(
                    width: 40,
                    child: Text('$nombre', key: const ValueKey('promo-nombre'), textAlign: TextAlign.center, style: Charte.texte(22, gras: true))),
                Semantics(
                  button: true,
                  label: 'Un de plus',
                  child: IconButton(
                    key: const ValueKey('promo-plus'),
                    iconSize: 28,
                    onPressed: () => maj(() {
                      nombre++;
                      onQuantite(nombre);
                    }),
                    icon: Icon(Icons.add_circle_outline, color: Charte.cadre),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in types)
                InkWell(
                  key: ValueKey('nature-promo-${t.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => maj(() {
                    if (type != t.id) {
                      a.text = '';
                      b.text = t.id == 'lot' ? '1' : '';
                    }
                    type = t.id;
                    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
                  }),
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: type == t.id ? Color.alphaBlend(c.withValues(alpha: 0.18), Charte.blanc) : Charte.blanc,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: type == t.id ? c : Charte.cadre, width: type == t.id ? 2 : 1),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.code, style: Charte.texte(16, gras: true, couleur: c)),
                      Text(switch (t.id) { 'prix' => 'Prix', 'lot' => 'Lot', 'prixGlobal' => 'Lot promo', _ => FeuillePromotion.nomCourt(t) },
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Charte.texte(10)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            zone,
          ]),
          boutons: [
            // 25/11/2026 (Aristide) : la promo valide l'article ; on peut aussi l'abandonner (il quitte la liste).
            if (abandonner != null)
              Bouton(
                key: const ValueKey('abandonner-article'),
                texte: 'Abandonner l\'article',
                icone: Icons.remove_circle_outline,
                onTap: () {
                  Navigator.of(ctx).pop();
                  abandonner();
                },
              ),
            Bouton(texte: actuelle == null ? 'Sans promo' : 'Retirer', onTap: () => Navigator.of(ctx).pop((promo: null))),
            Bouton(
                texte: 'OK',
                plein: true,
                onTap: type == null ? null : () => Navigator.of(ctx).pop((promo: construire()))),
          ],
        );
      },
    ),
  );
}
