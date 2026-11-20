import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/micro.dart';
import '../donnees/import_texte.dart' show normaliser;
import '../donnees/recette_ingredients.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Courses › Catalogue des recettes (19/11/2026, Aristide) : consulter les recettes hors de la préparation.
// Rangées par type (Entrée, Plat…), un champ pour chercher (titre ou ingrédient), des filtres combinables (20/11/2026) ;
// une recette s'ouvre sur sa fiche.

class EcranRecettes extends StatefulWidget {
  const EcranRecettes({super.key, this.depuisEnTete = false});

  /// Ouvert par l'icône de l'en-tête : pas de « Gérer › Courses » au-dessus du titre.
  final bool depuisEnTete;
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
        retour: true,
        icone: Icons.restaurant_menu_outlined,
        sousTitre: widget.depuisEnTete ? null : 'Gérer › Courses',
        titre: 'Catalogue des recettes',
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

  Future<void> _choisir(BuildContext context, String critere) async {
    final valeurs = filtre.choix[critere]!;
    await modale(
      context,
      titre: critere,
      oui: 'Valider',
      non: null,
      contenu: (context, maj) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final v in FiltreRecettes.criteres[critere]!)
          CaseModale(
            key: ValueKey('valeur-$v'),
            texte: FiltreRecettes.libelle(v),
            coche: valeurs.contains(v),
            onChange: (c) {
              maj(() => c ? valeurs.add(v) : valeurs.remove(v));
              onChange();
            },
            encadree: false,
          ),
      ]),
    );
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final saison = FiltreRecettes.saisonDu(DateTime.now());
    final choixSaison = filtre.choix['Saison']!;
    final deSaison = choixSaison.length == 1 && choixSaison.contains(saison);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, children: [
        for (final c in FiltreRecettes.criteres.keys)
          Pastille(
            switch (filtre.choix[c]!.length) {
              0 => '$c ▾',
              1 => FiltreRecettes.libelle(filtre.choix[c]!.first),
              final n => '$c ($n)',
            },
            key: ValueKey('filtre-$c'),
            couleur: filtre.choix[c]!.isEmpty ? null : Charte.cadre,
            onTap: () => _choisir(context, c),
          ),
        Pastille(
          'De saison',
          key: const ValueKey('filtre-de-saison'),
          couleur: deSaison ? Charte.cadre : null,
          onTap: () {
            choixSaison.clear();
            if (!deSaison) choixSaison.add(saison);
            onChange();
          },
        ),
      ]),
      Row(children: [
        Expanded(
          child: Text('$nombre recette${nombre > 1 ? 's' : ''}',
              key: const ValueKey('nombre-recettes'), style: Charte.texte(14, gras: true, couleur: Charte.texteSecondaire)),
        ),
        if (filtre.actif || filtre.texte.isNotEmpty)
          TextButton(key: const ValueKey('effacer-filtres'), onPressed: onEffacer, child: const Text('Effacer les filtres')),
      ]),
    ]);
  }
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
  const EnTeteRecette({super.key, required this.recette});
  final RecetteLue recette;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    final ligne = r.ligneEnTete;
    final pastilles = [if (r.source != null) 'Recette ${r.source}', ...r.pastilles];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (ligne.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(ligne, key: const ValueKey('ligne-recette'), style: Charte.texte(15, gras: true)),
        ),
      if (pastilles.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 5, runSpacing: 4, children: [
            for (final p in pastilles) Pastille(p, petite: true, couleur: p.startsWith('Recette ') ? Charte.cadre : null),
          ]),
        ),
    ]);
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

  @override
  Widget build(BuildContext context) {
    final r = widget.recette;
    return PageBase(
      entete: EnTeteFenetre(retour: true, icone: Icons.restaurant_menu_outlined, sousTitre: 'Catalogue des recettes', titre: r.titre),
      corps: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        IllustrationRecette(recette: r, cle: const ValueKey('illustration-fiche')),
        EnTeteRecette(recette: r),
        OngletsRecette(recette: _recette, onChange: (v) => setState(() => _recette = v)),
        if (_recette)
          TexteRecette(recette: r)
        else
          for (final i in r.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 3, right: 8), child: Icone(Icons.circle, size: 7, color: Charte.cadre)),
                Expanded(child: Text(i, style: Charte.texte(15))),
              ]),
            ),
      ]),
    );
  }
}

/// Bouton « recette » de l'en-tête (19/11/2026) : 20/11/2026 (Aristide) : pas de volet, le catalogue des recettes
/// lui-même ; la flèche de retour ramène là où l'on était.
Future<void> chercherRecette(BuildContext context) => Nav.aller<void>(context, const EcranRecettes(depuisEnTete: true));
