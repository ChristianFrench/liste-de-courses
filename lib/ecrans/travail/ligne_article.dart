part of '../travail.dart';


/// Une ligne d'article, la même en préparation et en courses (30 points) : le nom
/// (et la consigne en petit), la promotion (code et valeur), le packaging en code court, puis la quantité (ou [reglage]).
/// Toucher le P ou le packaging appelle [onDetail] ; toucher le reste de la ligne, [onTap].
class LigneArticle extends StatelessWidget {
  const LigneArticle({
    super.key,
    required this.ligne,
    required this.produit,
    this.cle,
    this.onTap,
    this.onLongPress,
    this.onDetail,
    this.reglage,
    this.coche = false,
    this.manquant = false,
    this.surligne = false,
    this.caseCourse = false,
    this.onPromo,
    this.onCase,
    this.onCaseLong,
  });
  final LigneListe ligne;

  /// Courses (13/11/2026, Aristide) : seule la case réagit (toucher : cocher ; appui long : manquant, détail).
  final VoidCallback? onCase;
  final VoidCallback? onCaseLong;

  /// Toucher la promotion (préparation : le volet « Promo ») ; sinon [onDetail].
  final VoidCallback? onPromo;
  final Produit produit;

  /// Clé de la zone sensible de la ligne.
  final Key? cle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDetail;
  final Widget? reglage;
  final bool coche;

  /// Manquant en rayon : nom en rouge, barré.
  final bool manquant;
  final bool surligne;

  /// Pendant les courses : case cochée (un appui) ou croix rouge (manquant, double appui).
  final bool caseCourse;

  @override
  Widget build(BuildContext context) {
    final etat = Etat.instance;
    final g = ligne;
    final k = etat.packagingDe(g, produit);
    final couleurPack = k == null ? null : etat.couleurPack(k.id);
    final couleurPromo = g.promotion == null ? null : etat.couleurPromo(g.promotion!.type);
    final grise = coche || manquant;
    // La ligne grandit avec le texte (loupe des courses, réglage du téléphone).
    // En courses, la ligne fait 40 points pour une grande case (30 en préparation).
    // Essai des gestes de courses (démonstration seulement, 13/11/2026) : grande case, seule à réagir.
    final essai = caseCourse && onCase != null;
    final hauteur = (essai ? Charte.ligneListe : Charte.ligne) * MediaQuery.textScalerOf(context).scale(16) / 16;
    // 21/11/2026 (Aristide) : les cases un peu plus petites (0,72 → 0,64 de la ligne).
    final taille = hauteur * 0.64;
    final styleNom = Charte.texte(16, couleur: manquant ? Charte.rouge : (coche ? Charte.texteSecondaire : Charte.encre)).copyWith(
      decoration: grise ? TextDecoration.lineThrough : null,
    );
    // Les petits signes ont une zone de toucher plus large que leur dessin.
    Widget signe(Widget w, String libelle, {VoidCallback? onTap}) => Semantics(
          button: true,
          label: libelle,
          child: InkWell(
            onTap: onTap ?? onDetail,
            child: Container(
              height: hauteur,
              constraints: const BoxConstraints(minWidth: 30),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: w,
            ),
          ),
        );
    return Material(
      color: surligne ? Charte.fondSelection : Colors.transparent,
      child: InkWell(
        key: cle,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: hauteur,
          padding: EdgeInsets.only(left: essai ? 0 : 6, right: 6),
          // Le trait sous la ligne ne prend pas de place : les signes gardent leurs 30 points.
          foregroundDecoration: BoxDecoration(border: Border(bottom: BorderSide(color: Charte.separateurLigne))),
          child: Row(children: [
            if (caseCourse && !essai) ...[
              if (manquant)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Charte.blanc,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Charte.rouge, width: Charte.traitCadre),
                  ),
                  child: Icone(Icons.close, size: 16, color: Charte.rouge),
                )
              else
                CaseACocher(coche: coche, taille: 20),
              const SizedBox(width: 2),
            ],
            if (essai) ...[
              Semantics(
                button: true,
                checked: coche,
                label: manquant ? 'Manquant : toucher si trouvé' : (coche ? 'Décocher' : 'Cocher'),
                child: InkWell(
                  key: ValueKey('case-${produit.id}'),
                  onTap: onCase,
                  onLongPress: onCaseLong,
                  child: SizedBox(
                    width: taille + 22,
                    height: hauteur,
                    child: Center(
                      child: manquant
                          ? Container(
                              width: taille,
                              height: taille,
                              decoration: BoxDecoration(
                                color: Charte.blanc,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Charte.rouge, width: Charte.traitCadre),
                              ),
                              child: Icone(Icons.close, size: taille * 0.8, color: Charte.rouge),
                            )
                          : CaseACocher(coche: coche, taille: taille),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(text: produit.nom, style: styleNom, children: [
                  // 13/11/2026 (Aristide) : la marque choisie se voit sur la ligne (« Lait demi-écrémé · Lactel »).
                  if (Etat.instance.marque(g.marqueId) case final m? when !produit.nom.toLowerCase().contains(m.nom.toLowerCase()))
                    TextSpan(text: ' · ${m.nom}', style: Charte.texte(15, couleur: coche || manquant ? (styleNom.color ?? Charte.cadre) : Charte.cadre)),
                  if (g.consigne != null) TextSpan(text: '  « ${g.consigne} »', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 21/11/2026 (Aristide) : pendant les courses, une icône signale la consigne ; la toucher l'affiche.
            if (essai && g.consigne != null)
              Semantics(
                button: true,
                label: 'Consigne',
                child: InkWell(
                  key: ValueKey('consigne-${produit.id}'),
                  onTap: () => detailArticle(context, g),
                  child: SizedBox(
                    width: 34,
                    height: hauteur,
                    child: Center(child: Opacity(opacity: grise ? 0.5 : 1, child: imageCritere('consigne', 24))),
                  ),
                ),
              ),
            // 04/11/2026 (Aristide) : la promotion avant la mesure, en texte seul dans la couleur des promotions
            // (« PX2,50€ », « LOT3+1 ») ; la toucher rouvre le volet « Promo » ([onPromo]).
            if (g.promotion case final pr?)
              signe(
                onTap: onPromo,
                Text(texteCourtPromo(pr),
                    key: ValueKey('promo-${produit.id}'),
                    style: Charte.texte(13, gras: true, couleur: couleurPromo == null ? Charte.rouge : Color(couleurPromo))),
                'Promotion'),
            if (k != null)
              signe(
                Text(codeCourtPackaging(k.libelle),
                    key: ValueKey('packaging-${produit.id}'),
                    style: Charte.texte(13, gras: true, couleur: couleurPack == null ? Charte.cadre : Color(couleurPack))),
                'Packaging',
              ),
            reglage ??
                SizedBox(
                  width: 30,
                  child: Text('${g.quantite}',
                      textAlign: TextAlign.right,
                      style: Charte.texte(15, gras: g.quantite > 1, couleur: g.quantite > 1 ? Charte.encre : Charte.texteSecondaire)),
                ),
          ]),
        ),
      ),
    );
  }
}

/// Détail d'un article pendant les courses : en clair, dans un volet.
/// [fermeSeul] (appui long sur la case, 13/11/2026, Aristide) : le volet se ferme tout seul après 4 secondes.
Future<void> detailArticle(BuildContext context, LigneListe g, {bool fermeSeul = false}) async {
  final etat = Etat.instance;
  final p = etat.produit(g.produitId);
  final k = p == null ? null : etat.packagingDe(g, p);
  final promo = g.promotion;
  final lignes = [
    'Quantité : ${g.quantite}',
    if (etat.marque(g.marqueId) case final m?) 'Marque : ${m.nom}',
    if (k != null) 'Packaging : ${k.libelle}',
    if (promo != null)
      'Promotion : ${promo.libelle.isNotEmpty ? promo.libelle : (etat.typePromotion(promo.type)?.nom ?? 'promo')}',
    if (g.consigne != null) 'Consigne : ${g.consigne}',
  ];
  var ouvert = true;
  final nav = Navigator.of(context);
  if (fermeSeul) {
    Future.delayed(const Duration(seconds: 4), () {
      if (ouvert && nav.mounted) nav.pop();
    });
  }
  await volet<void>(
    context,
    builder: (ctx) => corpsVolet(
      titre: p?.nom ?? 'Article',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final x in lignes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x, style: Charte.texte(17)))],
      ),
    ),
  );
  ouvert = false;
}

// ---------------------------------------------------------------- Écran 4 : volet « Promotion visée »

/// Code court d'un packaging sur le bouton de la ligne : « ×6 » pour un pack de 6, sinon le début du libellé.
String codeCourtPackaging(String libelle) {
  final l = libelle.trim().toLowerCase();
  const unites = {'à la pièce': 'pce', 'au poids': 'kg', 'à la coupe': 'cpe', 'botte': 'bte', 'paire': 'pr', 'rouleau': 'rlx'};
  if (unites[l] case final u?) return u;
  final n = RegExp(r'\d+').firstMatch(l)?.group(0);
  if (n != null && (l.startsWith('pack') || l.startsWith('lot') || l.startsWith('boîte de') || l.startsWith('paquet'))) return '×$n';
  final t = l.replaceAll(' ', '');
  return t.length <= 5 ? t : t.substring(0, 5);
}
