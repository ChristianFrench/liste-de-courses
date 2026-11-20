import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/micro.dart';
import '../donnees/import_texte.dart' show normaliser;
import '../donnees/modele.dart';
import '../donnees/recette_ingredients.dart';
import '../donnees/recettes_recues.dart';
import '../navigation.dart';
import '../theme.dart';
import 'travail.dart' show cocherIngredientsRecette;

// Gérer › Courses › Catalogue des recettes (19/11/2026, Aristide) : consulter les recettes hors de la préparation.
// Rangées par type (Entrée, Plat…), un champ pour chercher (titre ou ingrédient), des filtres combinables (20/11/2026) ;
// une recette s'ouvre sur sa fiche.

class EcranRecettes extends StatefulWidget {
  const EcranRecettes({super.key, this.depuisEnTete = false, this.onglet = false});

  /// Ouvert par l'icône de l'en-tête : pas de « Gérer › Courses » au-dessus du titre.
  final bool depuisEnTete;

  /// L'onglet « Cuisiner » (20/11/2026, Aristide) : le livre de recettes, à la racine de l'onglet.
  final bool onglet;
  @override
  State<EcranRecettes> createState() => _EcranRecettesState();
}

class _EcranRecettesState extends State<EcranRecettes> {
  List<RecetteLue>? _toutes;
  final _filtre = FiltreRecettes();
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Une recherche ou un filtre ouvre tous les types trouvés ; tout effacer les replie.
  void _changer(void Function() f) {
    f();
    final types = {for (final r in _toutes ?? const <RecetteLue>[]) if (_filtre.garde(r)) _typeDe(r)};
    Retractables.i.fixer([for (final t in types) 'recettes/$t'], _filtre.texte.trim().isNotEmpty || _filtre.actif);
    setState(() {});
  }

  static String _typeDe(RecetteLue r) => r.types.isEmpty ? 'Autres recettes' : r.types.first;

  @override
  void initState() {
    super.initState();
    recettesFournies().then((r) {
      if (mounted) setState(() => _toutes = r);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Retractables.i, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final toutes = _toutes;
    final vues = [for (final r in toutes ?? const <RecetteLue>[]) if (_filtre.garde(r)) r];
    final parType = <String, List<RecetteLue>>{};
    for (final r in vues) {
      parType.putIfAbsent(_typeDe(r), () => []).add(r);
    }
    // Ordre alphabétique des types, les desserts en dernier (comme la console).
    final types = parType.keys.toList()
      ..sort((a, b) {
        final da = normaliser(a).startsWith('dessert'), db = normaliser(b).startsWith('dessert');
        return da == db ? a.compareTo(b) : (da ? 1 : -1);
      });
    final cles = [for (final t in types) 'recettes/$t'];
    final plis = Retractables.i;
    final toutOuvert = cles.isNotEmpty && cles.every((c) => plis.ouvert(c, parDefaut: false));
    return PageBase(
      entete: EnTeteFenetre(
        retour: !widget.onglet,
        icone: Icons.restaurant_menu_outlined,
        sousTitre: widget.depuisEnTete || widget.onglet ? null : 'Gérer › Courses',
        titre: widget.onglet ? 'Cuisiner' : 'Catalogue des recettes',
        // 19/11/2026 (Aristide) : tout déplier / tout replier, comme les autres catalogues.
        droite: boutonEnTete(toutOuvert ? Icons.unfold_less : Icons.unfold_more, toutOuvert ? 'Tout replier' : 'Tout déplier',
            () => plis.tous(cles, !toutOuvert)),
      ),
      corps: toutes == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 16), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: ChampRechercheRecette(
                  champ: _champ,
                  cle: const ValueKey('chercher-recette'),
                  onTexte: (v) => _changer(() => _filtre.texte = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: FiltresRecettes(
                  filtre: _filtre,
                  nombre: vues.length,
                  onChange: () => _changer(() {}),
                  onEffacer: () => _changer(() {
                    _filtre.effacer();
                    _champ.clear();
                    _filtre.texte = '';
                  }),
                ),
              ),
              for (final t in types)
                GroupeRetractable(
                  cle: 'recettes/$t',
                  signe: _imageCritere(imageDuType([t]), 46),
                  titre: FiltreRecettes.libelle(t),
                  nombre: parType[t]!.length,
                  pliable: true,
                  parDefaut: false,
                  enfants: [
                    for (final r in parType[t]!)
                      LigneMenu(
                        key: ValueKey('fiche-${r.titre}'),
                        titre: r.titre,
                        sousTitre: resumeRecette(r),
                        onTap: () => Nav.aller<void>(context, FicheRecette(recette: r)),
                      ),
                  ],
                ),
              if (vues.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucune recette', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
                ),
            ]),
    );
  }
}

/// Sous-titre d'une recette dans une liste : « Pour 4 personnes · 35 min · Facile ».
String resumeRecette(RecetteLue r) => [
      if (r.pour != null) 'Pour ${r.pour}',
      if (r.tempsTotal case final t?) duree(t),
      if (r.difficulte != null) r.difficulte!,
    ].join(' · ');

/// Le champ « Chercher une recette » (titre ou ingrédient), avec le micro.
class ChampRechercheRecette extends StatelessWidget {
  const ChampRechercheRecette({super.key, required this.champ, required this.onTexte, this.cle});
  final TextEditingController champ;
  final ValueChanged<String> onTexte;
  final Key? cle;

  @override
  Widget build(BuildContext context) => TextField(
        key: cle,
        controller: champ,
        style: Charte.texte(15),
        decoration: InputDecoration(
          labelText: 'Chercher une recette ou un ingrédient',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: BoutonMicro(controleur: champ, onTexte: onTexte),
        ),
        onChanged: onTexte,
      );
}

/// Les filtres combinables (20/11/2026, Aristide) : une pastille par critère, qui ouvre ses valeurs à cocher,
/// « De saison », le nombre de recettes trouvées et « Effacer les filtres ».
class FiltresRecettes extends StatelessWidget {
  const FiltresRecettes({super.key, required this.filtre, required this.nombre, required this.onChange, required this.onEffacer});
  final FiltreRecettes filtre;
  final int nombre;
  final VoidCallback onChange;
  final VoidCallback onEffacer;

  /// Icône d'Aristide de chaque critère (assets/recettes/criteres/filtre-*.png).
  static const icones = {
    'Type': 'filtre-type-recette',
    'Difficulté': 'filtre-difficulte',
    'Temps': 'filtre-temps-preparation',
    'Régime': 'filtre-regime',
    'Saison': 'filtre-saison',
    'Coût': 'filtre-cout',
    'Cuisson': 'filtre-mode-cuisson',
    'Occasion': 'filtre-occasion',
  };

  /// 20/11/2026 (Aristide) : les valeurs d'un critère en boutons à icône, à toucher pour (dé)sélectionner.
  Future<void> _choisir(BuildContext context, String critere) async {
    final valeurs = filtre.choix[critere]!;
    await modale(
      context,
      titre: critere,
      oui: 'Valider',
      non: null,
      contenu: (context, maj) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final v in FiltreRecettes.criteres[critere]!)
            _Tuile(
              cle: ValueKey('valeur-$v'),
              image: iconeCritere(v) ?? icones[critere]!,
              texte: FiltreRecettes.libelle(v),
              choisi: valeurs.contains(v),
              onTap: () {
                maj(() => valeurs.contains(v) ? valeurs.remove(v) : valeurs.add(v));
                onChange();
              },
            ),
        ]),
      ),
    );
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final saison = FiltreRecettes.saisonDu(DateTime.now());
    final choixSaison = filtre.choix['Saison']!;
    final deSaison = choixSaison.length == 1 && choixSaison.contains(saison);
    Widget bouton(String cle, String image, String aide, int n, bool actif, VoidCallback onTap) => Expanded(
          child: Tooltip(
            message: aide,
            child: Semantics(
              button: true,
              label: aide,
              selected: actif,
              child: InkWell(
                key: ValueKey(cle),
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: actif ? Charte.clair(Charte.accent, 0.55) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: actif ? Charte.cadre : Colors.transparent, width: 1.5),
                  ),
                  child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                    _imageCritere(image, 34),
                    if (n > 0)
                      Positioned(
                        right: 1,
                        top: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: Charte.cadre, borderRadius: BorderRadius.circular(8)),
                          child: Text('$n', style: Charte.texte(11, gras: true, couleur: Charte.blanc)),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final c in FiltreRecettes.criteres.keys)
          bouton('filtre-$c', icones[c]!, c, filtre.choix[c]!.length, filtre.choix[c]!.isNotEmpty, () => _choisir(context, c)),
        bouton('filtre-de-saison', 'filtre-de-saison', 'De saison ($saison)', 0, deSaison, () {
          choixSaison.clear();
          if (!deSaison) choixSaison.add(saison);
          onChange();
        }),
      ]),
      Row(children: [
        Expanded(
          child: Text(
              [
                '$nombre recette${nombre > 1 ? 's' : ''}',
                for (final c in FiltreRecettes.criteres.keys)
                  if (filtre.choix[c]!.isNotEmpty) filtre.choix[c]!.map(FiltreRecettes.libelle).join(' ou '),
              ].join(' · '),
              key: const ValueKey('nombre-recettes'),
              style: Charte.texte(14, gras: true, couleur: Charte.texteSecondaire)),
        ),
        if (filtre.actif || filtre.texte.isNotEmpty)
          TextButton(key: const ValueKey('effacer-filtres'), onPressed: onEffacer, child: const Text('Effacer les filtres')),
      ]),
    ]);
  }
}

/// Une valeur de filtre : son icône, son libellé dessous ; choisie, sur fond vert pâle et cadre.
class _Tuile extends StatelessWidget {
  const _Tuile({required this.cle, required this.image, required this.texte, required this.choisi, required this.onTap});
  final Key cle;
  final String image;
  final String texte;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: choisi,
        child: InkWell(
          key: cle,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 96,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            decoration: BoxDecoration(
              color: choisi ? Charte.clair(Charte.accent, 0.55) : Charte.fondBandeau,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: choisi ? Charte.cadre : Charte.separateurZone, width: choisi ? 2 : 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _imageCritere(image, 48),
              const SizedBox(height: 4),
              Text(texte, textAlign: TextAlign.center, style: Charte.texte(13, gras: choisi)),
            ]),
          ),
        ),
      );
}

/// Illustration d'une recette, 3:2, au plus un tiers de l'écran ; sans illustration, l'image du type.
class IllustrationRecette extends StatelessWidget {
  const IllustrationRecette({super.key, required this.recette, this.cle});
  final RecetteLue recette;
  final Key? cle;

  @override
  Widget build(BuildContext context) {
    Widget rien(BuildContext _, Object __, StackTrace? ___) => const SizedBox.shrink();
    final image = recette.image;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image == null
              ? ColoredBox(
                  color: Charte.fondBandeau,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(imageDuType(recette.types),
                        key: const ValueKey('illustration-type'), fit: BoxFit.contain, errorBuilder: rien),
                  ),
                )
              : image.startsWith('recette:') && RecettesRecues.instance.image(image.substring(8)) != null
                  ? Image.memory(RecettesRecues.instance.image(image.substring(8))!, key: cle, fit: BoxFit.cover, errorBuilder: rien)
                  : image.startsWith('http')
                  ? Image.network(image, key: cle, fit: BoxFit.cover, errorBuilder: rien)
                  : Image.asset(image, key: cle, fit: BoxFit.cover, errorBuilder: rien),
        ),
      ),
    );
  }
}

/// Sous l'illustration : « Pour 4 personnes · Préparation 20 min · Cuisson 40 min · Facile », puis les pastilles
/// de critères et « Recette Emplettes ».
class EnTeteRecette extends StatelessWidget {
  const EnTeteRecette({super.key, required this.recette, this.personnes, this.onPersonnes});
  final RecetteLue recette;

  /// Nombre de personnes choisi (20/11/2026, Aristide) ; avec [onPersonnes], « Pour » porte − et +.
  final int? personnes;
  final ValueChanged<int>? onPersonnes;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    final reglable = onPersonnes != null && r.personnes != null;
    final n = personnes ?? r.personnes ?? 1;
    // 20/11/2026 (Aristide) : ses icônes devant le nombre de personnes, les temps, la difficulté et les critères.
    final infos = <(String?, String)>[
      if (!reglable && r.pour != null) ('nombre-personnes', 'Pour ${r.pour}'),
      if (r.tempsPreparation case final t?) ('temps-preparation', 'Préparation ${duree(t)}'),
      if (r.tempsCuisson case final t?) t == 0 ? ('sans-cuisson', 'Sans cuisson') : ('temps-cuisson', 'Cuisson ${duree(t)}'),
      if (r.difficulte case final d?) (iconeCritere(d), d),
    ];
    final pastilles = [...r.types, ...r.pastilles];
    Widget bouton(IconData i, String cle, String aide, int vers) => IconButton(
          key: ValueKey(cle),
          tooltip: aide,
          visualDensity: VisualDensity.compact,
          onPressed: vers < 1 || vers > 50 ? null : () => onPersonnes!(vers),
          icon: Icone(i, size: 24, color: Charte.cadre),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (r.source != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(alignment: Alignment.centerLeft, child: Pastille('Recette ${r.source}', petite: true, couleur: Charte.cadre)),
        ),
      if (reglable)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            _imageCritere('nombre-personnes', 24),
            const SizedBox(width: 6),
            Text('Pour', style: Charte.texte(15, gras: true)),
            bouton(Icons.remove_circle_outline, 'moins-personnes', 'Moins de personnes', n - 1),
            Text(r.pourN(n), key: const ValueKey('nombre-personnes'), style: Charte.texte(15, gras: true)),
            bouton(Icons.add_circle_outline, 'plus-personnes', 'Plus de personnes', n + 1),
          ]),
        ),
      if (infos.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: reglable ? 0 : 8),
          child: Wrap(key: const ValueKey('ligne-recette'), spacing: 14, runSpacing: 4, children: [
            for (final (icone, texte) in infos)
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (icone != null) ...[_imageCritere(icone, 24), const SizedBox(width: 5)],
                Text(texte, style: Charte.texte(15, gras: true)),
              ]),
          ]),
        ),
      if (pastilles.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [for (final p in pastilles) PastilleCritere(p)]),
        ),
    ]);
  }
}

/// Icône d'Aristide d'une valeur de critère (assets/recettes/criteres/), ou null.
String? iconeCritere(String valeur) => switch (valeur) {
      '€' => '1-euro',
      '€€' => '2-euros',
      '€€€' => '3-euros',
      'Facile' => 'facile',
      'Moyen' => 'moyen',
      'Difficile' => 'difficile',
      'Avancé' => 'avance',
      'Sans cuisson' => 'sans-cuisson',
      'Four' => 'four',
      'Plaque' => 'plaque',
      'Cocotte-minute' => 'cocotte-minute',
      'Végétarien' => 'vegetarien',
      'Végétalien' => 'vegetalien',
      'Sans gluten' => 'sans-gluten',
      'Sans lactose' => 'sans-lactose',
      'Printemps' => 'printemps',
      'Été' => 'ete',
      'Automne' => 'automne',
      'Hiver' => 'hiver',
      'Toute l\'année' => 'toute-annee',
      'Quotidien' => 'quotidien',
      'À l\'avance' => 'a-l-avance',
      'À recevoir' => 'a-recevoir',
      'À emporter' => 'a-emporter',
      'Moins de 30 min' || 'Moins d\'une heure' || 'Plus d\'une heure' => 'temps-preparation',
      'Entrée' || 'Plats' || 'Plats accompagnement' || 'Sauces' || 'Dessert' => imageDuType([valeur]),
      _ => null,
    };

/// Une icône de critère ou de type de recette, [nom] court (assets/recettes/criteres/) ou chemin complet.
Widget imageCritere(String nom, double taille) => _imageCritere(nom, taille);

Widget _imageCritere(String nom, double taille) =>
    Image.asset(nom.startsWith('assets/') ? nom : 'assets/recettes/criteres/$nom.png', width: taille, height: taille, filterQuality: FilterQuality.medium);

/// Une pastille de critère : l'icône d'Aristide (s'il y en a une) et le libellé.
class PastilleCritere extends StatelessWidget {
  const PastilleCritere(this.valeur, {super.key});
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final icone = iconeCritere(valeur);
    return Container(
      padding: EdgeInsets.fromLTRB(icone == null ? 8 : 4, 2, 8, 2),
      decoration: BoxDecoration(
        color: Charte.fondBandeau,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Charte.separateurZone),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[_imageCritere(icone, 20), const SizedBox(width: 4)],
        Text(FiltreRecettes.libelle(valeur), style: Charte.texte(13, gras: true)),
      ]),
    );
  }
}

/// Les deux onglets d'une recette : « Ingrédients » et « Recette ».
class OngletsRecette extends StatelessWidget {
  const OngletsRecette({super.key, required this.recette, required this.onChange});

  /// Vrai : l'onglet « Recette » est ouvert.
  final bool recette;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    Widget onglet(String t, bool ouvert, bool valeur) => Expanded(
          child: InkWell(
            key: ValueKey(valeur ? 'onglet-recette' : 'onglet-ingredients'),
            onTap: () => onChange(valeur),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ouvert ? Charte.cadre : Charte.separateurZone, width: ouvert ? 3 : 1)),
              ),
              alignment: Alignment.center,
              child: Text(t, style: Charte.texte(16, gras: true, couleur: ouvert ? Charte.cadre : Charte.texteSecondaire)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(children: [onglet('Ingrédients', !recette, false), onglet('Recette', recette, true)]),
    );
  }
}

/// L'onglet « Recette » : étapes numérotées, puis les conseils.
class TexteRecette extends StatelessWidget {
  const TexteRecette({super.key, required this.recette});
  final RecetteLue recette;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var k = 0; k < r.etapes.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 26, child: Text('${k + 1}.', style: Charte.texte(15, gras: true, couleur: Charte.cadre))),
            Expanded(child: Text(r.etapes[k], style: Charte.texte(15))),
          ]),
        ),
      if (r.conseils.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text('Conseils', style: Charte.texte(16, gras: true, couleur: Charte.cadre)),
        ),
        for (final c in r.conseils)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $c', style: Charte.texte(15))),
      ],
      if (r.etapes.isEmpty && r.conseils.isEmpty)
        Text('Pas encore de texte pour cette recette.', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
    ]);
  }
}

/// La fiche d'une recette : illustration, en-tête et critères, puis les onglets « Ingrédients » et « Recette ».
class FicheRecette extends StatefulWidget {
  const FicheRecette({super.key, required this.recette});
  final RecetteLue recette;

  @override
  State<FicheRecette> createState() => _FicheRecetteState();
}

class _FicheRecetteState extends State<FicheRecette> {
  var _recette = false;
  late int? _personnes = widget.recette.personnes;

  @override
  Widget build(BuildContext context) {
    final r = widget.recette;
    return PageBase(
      entete: EnTeteFenetre(retour: true, icone: Icons.restaurant_menu_outlined, sousTitre: 'Recettes', titre: r.titre),
      corps: AvecDecision(
        // 20/11/2026 (Aristide) : un seul pont vers les courses.
        boutons: [
          Bouton(
            key: const ValueKey('ajouter-aux-courses'),
            texte: 'Ajouter aux courses',
            icone: Icons.add_shopping_cart,
            plein: true,
            onTap: () => ajouterAuxCourses(context, r, personnes: _personnes),
          ),
        ],
        contenu: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
          IllustrationRecette(recette: r, cle: const ValueKey('illustration-fiche')),
          EnTeteRecette(recette: r, personnes: _personnes, onPersonnes: (n) => setState(() => _personnes = n)),
          OngletsRecette(recette: _recette, onChange: (v) => setState(() => _recette = v)),
          if (_recette)
            TexteRecette(recette: r)
          else
            for (final i in r.ingredientsPour(_personnes))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 3, right: 8), child: Icone(Icons.circle, size: 7, color: Charte.cadre)),
                  Expanded(child: Text(i, style: Charte.texte(15))),
                ]),
              ),
        ]),
      ),
    );
  }
}

/// « Ajouter aux courses » (20/11/2026, Aristide) : une seule liste en préparation, les ingrédients y vont ;
/// plusieurs, on choisit ; aucune, une liste est créée (magasin à choisir s'il y en a plusieurs).
Future<void> ajouterAuxCourses(BuildContext context, RecetteLue r, {int? personnes}) async {
  final etat = Etat.instance;
  final enPreparation = [...etat.listesStatut(StatutListe.enConstruction), ...etat.listesStatut(StatutListe.prete)];
  Liste? liste;
  Liste Function()? creer;
  if (enPreparation.length == 1) {
    liste = enPreparation.single;
  } else if (enPreparation.length > 1) {
    final id = await choisirDansListe<String>(context,
        titre: 'Ajouter à quelle liste ?', choix: {for (final l in enPreparation) l.id: etat.nomListe(l)});
    if (id == null || !context.mounted) return;
    liste = etat.liste(id);
  } else {
    if (etat.magasins.isEmpty) {
      Nav.message(context, 'Créez d\'abord un magasin (Gérer › Magasins)');
      return;
    }
    var magasin = etat.magasins.first.id;
    if (etat.magasins.length > 1) {
      final m = await choisirDansListe<String>(context,
          titre: 'Nouvelle liste : quel magasin ?', choix: {for (final m in etat.magasins) m.id: m.nom});
      if (m == null || !context.mounted) return;
      magasin = m;
    }
    creer = () => etat.creerListe(magasin, []);
  }
  if (!context.mounted) return;
  await cocherIngredientsRecette(context, liste, r, direListe: true, creer: creer, personnes: personnes);
}

/// Bouton « recette » de l'en-tête (19/11/2026) : 20/11/2026 (Aristide) : pas de volet, le catalogue des recettes
/// lui-même ; la flèche de retour ramène là où l'on était.
Future<void> chercherRecette(BuildContext context) => Nav.aller<void>(context, const EcranRecettes(depuisEnTete: true));
