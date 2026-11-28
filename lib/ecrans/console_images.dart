import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/icone.dart';
import '../composants/pictogramme.dart';
import '../donnees/catalogue_commun.dart';
import '../donnees/images_perso.dart';
import '../donnees/presse_papiers_image.dart';
import '../navigation.dart';
import '../theme.dart';
import 'editeur_catalogue.dart';

// Images ajoutées à la bibliothèque par l'éditeur (console, 07/11/2026, Aristide) : une image collée (Ctrl+V) ou un
// fichier, mise à la taille des autres (96 × 96, fond clair rendu transparent), avec un texte associé. Elles forment
// la bibliothèque « Images ajoutées » et partent vers les foyers avec le catalogue généralisé.

/// Lecture du presse-papiers (remplaçable dans les essais).
Future<Uint8List?> Function() lirePressePapiersImage = imageDuPressePapiers;

Widget _bouton(String texte, VoidCallback? onTap, {IconData? icone, bool plein = false, Key? key}) =>
    IntrinsicWidth(key: key, child: Bouton(texte: texte, icone: icone, onTap: onTap, plein: plein, taille: 15));

/// Fenêtre d'ajout d'une image ; rend la clé de l'image ajoutée, ou null.
Future<String?> ajouterImageBibliotheque(BuildContext context, EtatEditeurCatalogue e) =>
    showDialog<String>(context: context, builder: (_) => _AjoutImage(editeur: e));

class _AjoutImage extends StatefulWidget {
  const _AjoutImage({required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<_AjoutImage> createState() => _AjoutImageState();
}

class _AjoutImageState extends State<_AjoutImage> {
  final _texte = TextEditingController();
  final _zone = FocusNode();
  Uint8List? _png;
  String? _erreur;
  bool _occupe = false;

  Brouillon get b => widget.editeur.b!;

  @override
  void initState() {
    super.initState();
    _texte.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texte.dispose();
    _zone.dispose();
    super.dispose();
  }

  void _prendre(Uint8List? octets, {String? nom}) {
    if (octets == null) {
      setState(() => _erreur = 'Pas d\'image dans le presse-papiers. Copiez une image (ou un fichier image), puis recommencez.');
      return;
    }
    final png = preparerImagePerso(octets);
    setState(() {
      _png = png;
      _erreur = png == null ? 'Cette image n\'est pas lisible (formats acceptés : PNG, JPEG, GIF, BMP, WebP).' : null;
      if (png != null && _texte.text.trim().isEmpty && nom != null) _texte.text = nom;
    });
  }

  Future<void> _coller() async {
    setState(() => _occupe = true);
    final o = await lirePressePapiersImage();
    if (!mounted) return;
    setState(() => _occupe = false);
    _prendre(o);
  }

  Future<void> _fichier() async {
    final x = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp']),
    ]);
    if (x == null || !mounted) return;
    final nom = x.name.contains('.') ? x.name.substring(0, x.name.lastIndexOf('.')) : x.name;
    _prendre(await x.readAsBytes(), nom: nom.replaceAll(RegExp(r'[_-]+'), ' ').trim());
  }

  @override
  Widget build(BuildContext context) {
    final texte = _texte.text.trim();
    final cle = texte.isEmpty ? null : clePerso(texte);
    final existe = cle != null && b.imagesPerso.containsKey(cle);
    final pret = _png != null && texte.isNotEmpty && cle != 'perso--';
    return Dialog(
      backgroundColor: Charte.blanc,
      child: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ajouter une image à la bibliothèque', style: Charte.texte(19, gras: true)),
            const SizedBox(height: 4),
            Text('Elle est mise à la taille des autres images (96 × 96 pixels) ; un fond clair et uni devient transparent.',
                style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // La zone où coller : un clic lui donne le clavier, Ctrl+V y colle l'image.
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true): _coller,
                },
                child: Focus(
                  focusNode: _zone,
                  autofocus: true,
                  child: Builder(
                    builder: (ctx) {
                      final focus = Focus.of(ctx).hasFocus;
                      return GestureDetector(
                        key: const ValueKey('zone-image'),
                        onTap: () => _zone.requestFocus(),
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Charte.niveau(3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: focus ? Charte.accent : Charte.separateurZone, width: focus ? 2.5 : 1.5),
                          ),
                          alignment: Alignment.center,
                          child: _occupe
                              ? const CircularProgressIndicator()
                              : _png != null
                                  ? Image.memory(_png!, width: 160, height: 160, filterQuality: FilterQuality.medium)
                                  : Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        Icone(Icons.content_paste, size: 40, color: Charte.cadre),
                                        const SizedBox(height: 10),
                                        Text('Cliquez ici puis collez une image (Ctrl+V)',
                                            textAlign: TextAlign.center, style: Charte.texte(14, couleur: Charte.texteSecondaire)),
                                      ]),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _bouton('Coller (Ctrl+V)', _coller, icone: Icons.content_paste, key: const ValueKey('image-coller')),
                  const SizedBox(height: 10),
                  _bouton('Choisir un fichier…', _fichier, icone: Icons.folder_open, key: const ValueKey('image-fichier')),
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('image-texte'),
                    controller: _texte,
                    style: Charte.texte(15),
                    decoration: const InputDecoration(labelText: 'Texte associé', hintText: 'Pot de miel, planche à découper…'),
                    onSubmitted: (_) {
                      if (pret) _ajouter();
                    },
                  ),
                  if (_png != null) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Text('Dans une liste :', style: Charte.texte(13, couleur: Charte.texteSecondaire)),
                      const SizedBox(width: 10),
                      Image.memory(_png!, width: 40, height: 40, filterQuality: FilterQuality.medium),
                      const SizedBox(width: 10),
                      Image.memory(_png!, width: 26, height: 26, filterQuality: FilterQuality.medium),
                    ]),
                  ],
                  if (existe) ...[
                    const SizedBox(height: 10),
                    Text('Une image porte déjà ce texte : elle sera remplacée.', style: Charte.texte(13.5, couleur: const Color(0xFFB3261E))),
                  ],
                ]),
              ),
            ]),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Text(_erreur!, style: Charte.texte(14, couleur: const Color(0xFFB3261E))),
            ],
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _bouton('Annuler', () => Navigator.of(context).pop()),
              const SizedBox(width: 10),
              _bouton(existe ? 'Remplacer' : 'Ajouter', pret ? _ajouter : null, plein: true, key: const ValueKey('image-ajouter')),
            ]),
          ]),
        ),
      ),
    );
  }

  void _ajouter() {
    final cle = b.ajouterImagePerso(_texte.text, _png!);
    widget.editeur.modifie();
    Navigator.of(context).pop(cle);
  }
}

/// Fenêtre « Images ajoutées » (menu ☰) : la bibliothèque de l'éditeur, pour ajouter, renommer ou retirer.
Future<void> montrerImagesAjoutees(BuildContext context, EtatEditeurCatalogue e) =>
    showDialog<void>(context: context, builder: (_) => _ImagesAjoutees(editeur: e));

class _ImagesAjoutees extends StatefulWidget {
  const _ImagesAjoutees({required this.editeur});
  final EtatEditeurCatalogue editeur;

  @override
  State<_ImagesAjoutees> createState() => _ImagesAjouteesState();
}

class _ImagesAjouteesState extends State<_ImagesAjoutees> {
  Brouillon get b => widget.editeur.b!;

  int _usages(String cle) => b.images.values.where((v) => v == cle).length;

  Future<void> _renommer(String cle) async {
    final t = await demanderTexte(context, titre: 'Texte de l\'image', libelle: 'Texte associé', initial: b.imagesPerso[cle]!.texte);
    if (t == null || t.trim().isEmpty || !mounted) return;
    if (clePerso(t) != cle && b.imagesPerso.containsKey(clePerso(t))) {
      Nav.message(context, 'Une autre image porte déjà ce texte');
      return;
    }
    b.renommerImagePerso(cle, t);
    widget.editeur.modifie();
    setState(() {});
  }

  Future<void> _retirer(String cle) async {
    final n = _usages(cle);
    final ok = await confirmer(
      context,
      titre: 'Retirer « ${b.imagesPerso[cle]!.texte} » ?',
      icone: Icons.delete_outline,
      contenu: Text(
        n == 0
            ? 'L\'image quitte la bibliothèque.'
            : 'Elle sert à ${n == 1 ? 'un rayon ou secteur, qui reprendra' : '$n rayons ou secteurs, qui reprendront'} son image automatique.',
        style: Charte.texte(16),
      ),
      plein: 'Annuler',
      contour: 'Retirer',
    );
    if (ok != true || !mounted) return;
    b.retirerImagePerso(cle);
    widget.editeur.modifie();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cles = b.imagesPerso.keys.toList()..sort((x, y) => nomImage(x).toLowerCase().compareTo(nomImage(y).toLowerCase()));
    return Dialog(
      backgroundColor: Charte.blanc,
      child: SizedBox(
        width: 760,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Images ajoutées (${cles.length})', style: Charte.texte(19, gras: true))),
              _bouton('Ajouter une image…', () async {
                await ajouterImageBibliotheque(context, widget.editeur);
                if (mounted) setState(() {});
              }, icone: Icons.add_photo_alternate_outlined, key: const ValueKey('images-ajouter')),
            ]),
            const SizedBox(height: 4),
            Text('Elles partent vers tous les foyers avec la prochaine généralisation du catalogue.',
                style: Charte.texte(13.5, couleur: Charte.texteSecondaire)),
            const SizedBox(height: 12),
            Expanded(
              child: cles.isEmpty
                  ? Center(
                      child: Text('Aucune image ajoutée pour l\'instant.', style: Charte.texte(15, couleur: Charte.texteSecondaire)))
                  : ListView.separated(
                      itemCount: cles.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Charte.separateurZone),
                      itemBuilder: (_, i) {
                        final c = cles[i];
                        final n = _usages(c);
                        return Padding(
                          key: ValueKey('image-ajoutee-$c'),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Pictogramme(c, taille: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(nomImage(c), style: Charte.texte(15, gras: true)),
                                Text(n == 0 ? 'Pas encore utilisée' : 'Utilisée par $n rayon${n > 1 ? 's' : ''} ou secteur${n > 1 ? 's' : ''}',
                                    style: Charte.texte(12.5, couleur: Charte.texteSecondaire)),
                              ]),
                            ),
                            Tooltip(
                              message: 'Changer le texte',
                              child: IconButton(onPressed: () => _renommer(c), icon: Icone(Icons.edit_outlined, size: 22, color: Charte.cadre)),
                            ),
                            Tooltip(
                              message: 'Retirer de la bibliothèque',
                              child: IconButton(
                                  onPressed: () => _retirer(c), icon: Icone(Icons.delete_outline, size: 22, color: Charte.cadre)),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: _bouton('Fermer', () => Navigator.of(context).pop(), key: const ValueKey('images-fermer'))),
          ]),
        ),
      ),
    );
  }
}
