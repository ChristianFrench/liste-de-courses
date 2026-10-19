import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// Catalogue type : rayons, secteurs et produits proposés à la création d'un magasin.
// Livré avec l'application (assets/catalogue_type.json) ; l'application « Gestion du catalogue »
// en enregistre une version modifiée dans le dossier de données, qui a alors priorité.

class CatProduit {
  CatProduit(this.nom, this.taille, {this.listes = 0, List<String>? marques, List<String>? formats})
      : marques = marques ?? [],
        formats = formats ?? [];
  String nom;
  int taille;
  int listes; // nombre de fois dans les listes du foyer
  List<String> marques;
  List<String> formats; // formats de vente (packagings), du plus courant au moins courant

  factory CatProduit.lire(Map j) => CatProduit(j['nom'] as String, (j['taille'] as num).toInt(),
      listes: (j['listes'] as num?)?.toInt() ?? 0,
      marques: [...?(j['marques'] as List?)?.cast<String>()],
      formats: [...?(j['formats'] as List?)?.cast<String>()]);

  Map<String, dynamic> versJson() => {
        'nom': nom,
        'taille': taille,
        if (listes > 0) 'listes': listes,
        if (marques.isNotEmpty) 'marques': marques,
        if (formats.isNotEmpty) 'formats': formats,
      };
}

class CatSecteur {
  CatSecteur(this.nom, this.taille, [List<CatProduit>? produits, List<String>? formats])
      : produits = produits ?? [],
        formats = formats ?? [];
  String nom;
  int taille;
  List<CatProduit> produits;
  List<String> formats; // formats proposés pour un nouvel article du secteur

  factory CatSecteur.lire(Map j) => CatSecteur(j['nom'] as String, (j['taille'] as num).toInt(),
      [for (final p in (j['produits'] as List).cast<Map>()) CatProduit.lire(p)], [...?(j['formats'] as List?)?.cast<String>()]);
}

class CatRayon {
  CatRayon(this.nom, [List<CatSecteur>? secteurs]) : secteurs = secteurs ?? [];
  String nom;
  List<CatSecteur> secteurs;

  factory CatRayon.lire(Map j) =>
      CatRayon(j['nom'] as String, [for (final s in (j['secteurs'] as List).cast<Map>()) CatSecteur.lire(s)]);
}

class CatalogueType {
  CatalogueType(this.rayons);
  List<CatRayon> rayons;

  static const fichierLivre = 'assets/catalogue_type.json';
  static const nomFichier = 'catalogue_type.json';

  static const tailles = {1: 'Proximité', 2: 'Supermarché', 3: 'Hypermarché'};

  factory CatalogueType.lire(Map<String, dynamic> j) =>
      CatalogueType([for (final r in (j['rayons'] as List).cast<Map>()) CatRayon.lire(r)]);

  Map<String, dynamic> versJson() => {
        '_description': "Catalogue type d'un magasin. taille : 1 proximité, 2 supermarché, 3 hypermarché. "
            'listes : nombre de fois où le produit figure dans les listes du foyer. formats : formats de vente proposés (packagings).',
        'tailles': {for (final e in tailles.entries) '${e.key}': e.value},
        'rayons': [
          for (var i = 0; i < rayons.length; i++)
            {
              'nom': rayons[i].nom,
              'ordre': i + 1,
              'secteurs': [
                for (var j = 0; j < rayons[i].secteurs.length; j++)
                  {
                    'nom': rayons[i].secteurs[j].nom,
                    'ordre': j + 1,
                    'taille': rayons[i].secteurs[j].taille,
                    if (rayons[i].secteurs[j].formats.isNotEmpty) 'formats': rayons[i].secteurs[j].formats,
                    'produits': [for (final p in rayons[i].secteurs[j].produits) p.versJson()],
                  }
              ],
            }
        ],
      };

  Iterable<(CatRayon, CatSecteur, CatProduit)> get tousLesProduits sync* {
    for (final r in rayons) {
      for (final s in r.secteurs) {
        for (final p in s.produits) {
          yield (r, s, p);
        }
      }
    }
  }

  /// Fichier modifié par « Gestion du catalogue », dans le dossier de données de l'application.
  static Future<File> fichierLocal() async {
    final d = await getApplicationSupportDirectory();
    if (!d.existsSync()) d.createSync(recursive: true);
    return File('${d.path}${Platform.pathSeparator}$nomFichier');
  }

  /// Version modifiée si elle existe, sinon le catalogue livré.
  static Future<Map<String, dynamic>> lireJson() async {
    try {
      final f = await fichierLocal();
      if (f.existsSync()) return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      // dossier inaccessible : on prend le catalogue livré
    }
    return livre();
  }

  static Future<Map<String, dynamic>> livre() async =>
      jsonDecode(await rootBundle.loadString(fichierLivre)) as Map<String, dynamic>;

  static Future<CatalogueType> charger() async => CatalogueType.lire(await lireJson());

  /// Enregistre ; la version précédente est gardée à côté (« .precedent »).
  Future<File> enregistrer() async {
    final f = await fichierLocal();
    if (f.existsSync()) f.copySync('${f.path}.precedent');
    f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(versJson()));
    return f;
  }
}
