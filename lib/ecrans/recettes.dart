import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/micro.dart';
import '../donnees/import_texte.dart' show normaliser;
import '../donnees/recette_ingredients.dart';
import '../navigation.dart';
import '../theme.dart';

// Gérer › Courses › Catalogue des recettes (19/11/2026, Aristide) : consulter les recettes hors de la préparation.
// Rangées par type (Entrée, Plat…), un champ pour chercher ; une recette s'ouvre sur sa fiche.

class EcranRecettes extends StatefulWidget {
  const EcranRecettes({super.key});
  @override
  State<EcranRecettes> createState() => _EcranRecettesState();
}

class _EcranRecettesState extends State<EcranRecettes> {
  List<RecetteLue>? _toutes;
  String _filtre = '';
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _filtrer(String v, List<String> cles) {
    // Une recherche ouvre tous les types trouvés ; l'effacer les replie.
    Retractables.i.fixer(cles, v.trim().isNotEmpty);
    setState(() => _filtre = v);
  }

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
    final f = normaliser(_filtre);
    final vues = [for (final r in toutes ?? const <RecetteLue>[]) if (f.isEmpty || normaliser(r.titre).contains(f)) r];
    final parType = <String, List<RecetteLue>>{};
    for (final r in vues) {
      parType.putIfAbsent(r.types.isEmpty ? 'Autres recettes' : r.types.first, () => []).add(r);
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
        sousTitre: 'Gérer › Courses',
        titre: 'Catalogue des recettes',
        // 19/11/2026 (Aristide) : tout déplier / tout replier, comme les autres catalogues.
        droite: boutonEnTete(toutOuvert ? Icons.unfold_less : Icons.unfold_more, toutOuvert ? 'Tout replier' : 'Tout déplier',
            () => plis.tous(cles, !toutOuvert)),
      ),
      corps: toutes == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 16), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  key: const ValueKey('chercher-recette'),
                  controller: _champ,
                  style: Charte.texte(15),
                  decoration: InputDecoration(
                    labelText: 'Chercher une recette (${toutes.length})',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: BoutonMicro(controleur: _champ, onTexte: (v) => _filtrer(v, [for (final t in parType.keys) 'recettes/$t'])),
                  ),
                  onChanged: (v) => _filtrer(v, [for (final t in parType.keys) 'recettes/$t']),
                ),
              ),
              for (final t in types)
                GroupeRetractable(
                  cle: 'recettes/$t',
                  titre: t,
                  nombre: parType[t]!.length,
                  pliable: true,
                  parDefaut: false,
                  enfants: [
                    for (final r in parType[t]!)
                      LigneMenu(
                        key: ValueKey('fiche-${r.titre}'),
                        titre: r.titre,
                        sousTitre: [if (r.pour != null) 'Pour ${r.pour}', if (r.source != null) r.source!].join(' · '),
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

/// La fiche d'une recette : illustration, ingrédients, étapes numérotées, conseils.
class FicheRecette extends StatelessWidget {
  const FicheRecette({super.key, required this.recette});
  final RecetteLue recette;

  @override
  Widget build(BuildContext context) {
    final r = recette;
    Widget rien(BuildContext _, Object __, StackTrace? ___) => const SizedBox.shrink();
    Widget titre(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: Charte.texte(17, gras: true, couleur: Charte.cadre)),
        );
    return PageBase(
      entete: EnTeteFenetre(retour: true, icone: Icons.restaurant_menu_outlined, sousTitre: 'Catalogue des recettes', titre: r.titre),
      corps: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        if (r.image case final image?)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.startsWith('http')
                    ? Image.network(image, fit: BoxFit.cover, errorBuilder: rien)
                    : Image.asset(image, key: const ValueKey('illustration-fiche'), fit: BoxFit.cover, errorBuilder: rien),
              ),
            ),
          ),
        if (r.pour != null || r.source != null || r.types.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              [if (r.types.isNotEmpty) r.types.first, if (r.pour != null) 'Pour ${r.pour}', if (r.source != null) 'Recette ${r.source}'].join(' · '),
              style: Charte.texte(15, gras: true),
            ),
          ),
        if (r.ingredients.isNotEmpty) ...[
          titre('Ingrédients'),
          for (final i in r.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 3, right: 8), child: Icone(Icons.circle, size: 7, color: Charte.cadre)),
                Expanded(child: Text(i, style: Charte.texte(15))),
              ]),
            ),
        ],
        if (r.etapes.isNotEmpty) ...[
          titre('La recette'),
          for (var k = 0; k < r.etapes.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 26, child: Text('${k + 1}.', style: Charte.texte(15, gras: true, couleur: Charte.cadre))),
                Expanded(child: Text(r.etapes[k], style: Charte.texte(15))),
              ]),
            ),
        ],
        if (r.conseils.isNotEmpty) ...[
          titre('Conseils'),
          for (final c in r.conseils) Text('• $c', style: Charte.texte(15)),
        ],
      ]),
    );
  }
}

/// Bouton « recette » de l'en-tête (19/11/2026, Aristide) : chercher une recette (au clavier ou à la voix),
/// la liste des recettes qui correspondent, puis sa fiche en touchant son titre.
Future<void> chercherRecette(BuildContext context) async {
  final toutes = await recettesFournies();
  if (!context.mounted) return;
  final champ = TextEditingController();
  var filtre = '';
  RecetteLue? choix;
  await modale(
    context,
    titre: 'Chercher une recette',
    icone: Icons.restaurant_menu_outlined,
    oui: null,
    contenu: (context, maj) {
      final f = normaliser(filtre);
      final vues = f.isEmpty ? const <RecetteLue>[] : [for (final r in toutes) if (normaliser(r.titre).contains(f)) r];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextField(
            key: const ValueKey('chercher-recette-entete'),
            controller: champ,
            autofocus: true,
            style: Charte.texte(15),
            decoration: InputDecoration(
              labelText: 'Nom de la recette',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: BoutonMicro(controleur: champ, onTexte: (v) => maj(() => filtre = v)),
            ),
            onChanged: (v) => maj(() => filtre = v),
          ),
        ),
        const SizedBox(height: 6),
        if (f.isEmpty)
          Text('${toutes.length} recettes : tapez ou dites quelques lettres du nom.', style: Charte.texte(14, couleur: Charte.texteSecondaire))
        else if (vues.isEmpty)
          Text('Aucune recette', style: Charte.texte(15, couleur: Charte.texteSecondaire)),
        for (final r in vues)
          InkWell(
            key: ValueKey('trouvee-${r.titre}'),
            onTap: () {
              choix = r;
              Navigator.of(context).pop(true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: r.titre, style: Charte.texte(16)),
                if (r.types.isNotEmpty) TextSpan(text: '  ${r.types.first}', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
              ])),
            ),
          ),
      ]);
    },
  );
  champ.dispose();
  if (choix case final r? when context.mounted) await Nav.aller<void>(context, FicheRecette(recette: r));
}
