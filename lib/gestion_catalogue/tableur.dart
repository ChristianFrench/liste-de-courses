import 'package:excel/excel.dart';

import '../donnees/catalogue_type.dart';

// Échange du catalogue type avec un tableau Excel : export complet, et import qui ajoute,
// range, renomme ou supprime selon les colonnes présentes (dont « À faire » du tableau
// « Produits de vos listes »).

const _lettres = {1: 'P', 2: 'S', 3: 'H'};

int? _taille(String? v) {
  final t = (v ?? '').trim().toUpperCase();
  if (t.isEmpty) return null;
  if (t.startsWith('P') || t == '1') return 1;
  if (t.startsWith('S') || t == '2') return 2;
  if (t.startsWith('H') || t == '3') return 3;
  return null;
}

List<int> exporterExcel(CatalogueType c) {
  final x = Excel.createExcel();
  final defaut = x.getDefaultSheet()!;
  x.rename(defaut, 'Catalogue');
  final f = x['Catalogue'];
  final entete = ['Rayon', 'Secteur', 'Taille secteur', 'Produit', 'Taille produit', 'Marques', 'Fois dans vos listes',
      'À faire', 'Nouveau nom / rayon / secteur'];
  f.appendRow([for (final e in entete) TextCellValue(e)]);
  for (var i = 0; i < entete.length; i++) {
    f.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(bold: true);
  }
  for (final (r, s, p) in c.tousLesProduits) {
    f.appendRow([
      TextCellValue(r.nom),
      TextCellValue(s.nom),
      TextCellValue(_lettres[s.taille]!),
      TextCellValue(p.nom),
      TextCellValue(_lettres[p.taille]!),
      TextCellValue(p.marques.join(', ')),
      p.listes > 0 ? IntCellValue(p.listes) : TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }
  for (final (col, l) in [(0, 26.0), (1, 30.0), (2, 8.0), (3, 34.0), (4, 8.0), (5, 22.0), (6, 10.0), (7, 12.0), (8, 30.0)]) {
    f.setColumnWidth(col, l);
  }
  return x.save()!;
}

class BilanImport {
  int ajoutes = 0, deplaces = 0, renommes = 0, supprimes = 0, modifies = 0, ignores = 0;
  final List<String> remarques = [];
  int get total => ajoutes + deplaces + renommes + supprimes + modifies;

  @override
  String toString() => [
        if (ajoutes > 0) '$ajoutes produit${ajoutes > 1 ? 's' : ''} ajouté${ajoutes > 1 ? 's' : ''}',
        if (deplaces > 0) '$deplaces déplacé${deplaces > 1 ? 's' : ''}',
        if (renommes > 0) '$renommes renommé${renommes > 1 ? 's' : ''}',
        if (supprimes > 0) '$supprimes supprimé${supprimes > 1 ? 's' : ''}',
        if (modifies > 0) '$modifies modifié${modifies > 1 ? 's' : ''} (taille, marques)',
        if (ignores > 0) '$ignores ligne${ignores > 1 ? 's' : ''} ignorée${ignores > 1 ? 's' : ''}',
      ].join(' · ');
}

/// Applique au catalogue la première feuille du tableau [octets].
BilanImport importerExcel(CatalogueType c, List<int> octets) {
  final x = Excel.decodeBytes(octets);
  final f = x.tables.values.first;
  final bilan = BilanImport();
  if (f.rows.isEmpty) return bilan;
  String texte(Data? d) => d?.value == null ? '' : d!.value.toString().trim();
  final entete = [for (final d in f.rows.first) texte(d).toLowerCase()];
  int col(bool Function(String) test) => entete.indexWhere(test);
  final cRayon = col((e) => e == 'rayon');
  final cSecteur = col((e) => e == 'secteur');
  final cProduit = col((e) => e == 'produit');
  final cTailleS = col((e) => e.startsWith('taille secteur'));
  final cTailleP = col((e) => e.startsWith('taille produit'));
  final cMarques = col((e) => e.startsWith('marque'));
  final cFaire = col((e) => e.startsWith('à faire') || e.startsWith('a faire'));
  final cNouveau = col((e) => e.startsWith('nouveau nom'));
  if (cRayon < 0 || cSecteur < 0 || cProduit < 0) {
    bilan.remarques.add('Colonnes « Rayon », « Secteur » et « Produit » introuvables en première ligne.');
    return bilan;
  }
  String cell(List<Data?> l, int i) => i < 0 || i >= l.length ? '' : texte(l[i]);

  CatRayon rayon(String nom) {
    for (final r in c.rayons) {
      if (r.nom.toLowerCase() == nom.toLowerCase()) return r;
    }
    final r = CatRayon(nom);
    c.rayons.add(r);
    return r;
  }

  CatSecteur secteur(CatRayon r, String nom, int taille) {
    for (final s in r.secteurs) {
      if (s.nom.toLowerCase() == nom.toLowerCase()) return s;
    }
    final s = CatSecteur(nom, taille);
    r.secteurs.add(s);
    return s;
  }

  (CatSecteur, CatProduit)? trouver(String nom) {
    for (final (_, s, p) in c.tousLesProduits) {
      if (p.nom.toLowerCase() == nom.toLowerCase()) return (s, p);
    }
    return null;
  }

  for (final ligne in f.rows.skip(1)) {
    final nr = cell(ligne, cRayon), ns = cell(ligne, cSecteur), np = cell(ligne, cProduit);
    if (np.isEmpty) continue;
    if (nr.isEmpty || ns.isEmpty) {
      bilan.ignores++;
      bilan.remarques.add('« $np » : rayon ou secteur manquant.');
      continue;
    }
    final faire = cell(ligne, cFaire).toLowerCase();
    final nouveau = cell(ligne, cNouveau);
    final trouve = trouver(np);
    if (faire.startsWith('suppr')) {
      if (trouve != null) {
        trouve.$1.produits.remove(trouve.$2);
        bilan.supprimes++;
      }
      continue;
    }
    // Destination : colonnes Rayon / Secteur, ou « Rayon / Secteur » écrit pour un déplacement
    var dr = nr, ds = ns;
    if (faire.startsWith('dépl') || faire.startsWith('depl')) {
      final morceaux = nouveau.split(RegExp(r'\s*[/›>]\s*'));
      if (morceaux.length >= 2) {
        dr = morceaux[0];
        ds = morceaux[1];
      } else if (nouveau.isNotEmpty) {
        ds = nouveau;
      }
    }
    final tS = _taille(cell(ligne, cTailleS)) ?? 2;
    final cible = secteur(rayon(dr), ds, tS);
    final p = trouve?.$2 ?? CatProduit(np, _taille(cell(ligne, cTailleP)) ?? cible.taille);
    if (trouve == null) {
      cible.produits.add(p);
      bilan.ajoutes++;
    } else if (!identical(trouve.$1, cible)) {
      trouve.$1.produits.remove(p);
      cible.produits.add(p);
      bilan.deplaces++;
    }
    if (faire.startsWith('renom') && nouveau.isNotEmpty && nouveau != p.nom) {
      p.nom = nouveau;
      bilan.renommes++;
    }
    var modifie = false;
    final tP = _taille(cell(ligne, cTailleP));
    if (trouve != null && tP != null && tP != p.taille) {
      p.taille = tP;
      modifie = true;
    }
    if (cMarques >= 0) {
      final m = [for (final x in cell(ligne, cMarques).split(',')) if (x.trim().isNotEmpty) x.trim()];
      if (trouve != null && m.join(',') != p.marques.join(',')) {
        p.marques = m;
        modifie = true;
      } else if (trouve == null) {
        p.marques = m;
      }
    }
    if (modifie) bilan.modifies++;
  }
  return bilan;
}
