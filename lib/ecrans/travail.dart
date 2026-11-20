import '../composants/icone.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/composants.dart';
import '../composants/micro.dart';
import '../composants/pictogramme.dart' as picto;
import '../donnees/envoi.dart';
import '../donnees/import_texte.dart';
import '../donnees/modele.dart';
import '../donnees/recette_ingredients.dart';
import '../navigation.dart';
import '../theme.dart';
import 'recettes.dart';
import 'catalogue.dart'
    show actionsNonPlace, autreMarque, modifierArticle, nouveauProduit, placerNonPlaces, secteursOrdreCatalogue;

part 'travail/nouvelle_liste.dart';
part 'travail/preparation.dart';
part 'travail/ligne_article.dart';
part 'travail/promotion.dart';
part 'travail/courses.dart';
part 'travail/consultation.dart';

/// Volet « Changer le magasin ou la date » d'une liste en préparation.
Future<void> changerMagasinEtDate(BuildContext context, Liste l) async {
  final etat = Etat.instance;
  var magasinId = l.magasinId;
  final auj = DateTime.now();
  var prevue = etat.datePrevue(l) ?? DateTime(auj.year, auj.month, auj.day);
  final ok = await modale(
    context,
    titre: 'Magasin et date',
    oui: 'Valider',
    contenu: (context, maj) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        ChoixDeroulant<String>(
          key: const ValueKey('changer-magasin'),
          libelle: 'Magasin',
          valeur: magasinId,
          choix: {for (final m in etat.magasins) m.id: m.nom},
          onChange: (v) => maj(() => magasinId = v),
        ),
        const SizedBox(height: 14),
        ChampDate(
          key: const ValueKey('changer-date'),
          libelle: 'Date des courses',
          valeur: prevue,
          premier:
              DateTime(auj.year, auj.month, auj.day).isAfter(prevue) ? prevue : DateTime(auj.year, auj.month, auj.day),
          dernier: DateTime(auj.year, auj.month, auj.day).add(const Duration(days: 365)),
          onChange: (d) => maj(() => prevue = d),
        ),
      ],
    ),
  );
  if (ok) etat.changerMagasinEtDate(l, magasinId, prevue);
}

/// Clé de tri alphabétique : sans majuscules ni accents (« Œufs » avec les O).
String ordreAlpha(String nom) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae'
  };
  return nom.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

/// Bandeau d'un secteur et ses articles ; avec une image, ils sont réunis pour qu'elle déborde par-dessus.
List<Widget> sectionSecteur(String? picto, double gauche, List<Widget> enfants) =>
    picto == null ? enfants : [SectionDebordante(picto: picto, gauche: gauche, enfants: enfants)];

/// Bouton de l'en-tête des courses qui reste allumé quand il est actif (filtre, loupe) ; [texte] : le palier en cours.
class _BoutonBascule extends StatelessWidget {
  const _BoutonBascule(
      {required this.actif,
      required this.image,
      required this.libelle,
      required this.onTap,
      this.texte,
      this.estompe = false});
  final bool actif;

  /// Chemin de l'image (Noto 3D), seule, sans cadre (03/11/2026, Aristide).
  final String image;

  /// Image pâlie quand le bouton est au repos (filtre).
  final bool estompe;
  final String libelle;
  final String? texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: libelle,
        child: Semantics(
          button: true,
          selected: actif,
          label: libelle,
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: estompe ? 0.55 : 1,
                  child: Image.asset(image, width: 32, height: 32, filterQuality: FilterQuality.medium),
                ),
                if (texte != null) ...[
                  const SizedBox(width: 3),
                  Text(texte!, style: surPhoto(Charte.texte(13, gras: true, couleur: Charte.blanc))),
                ],
              ]),
            ),
          ),
        ),
      );
}

/// 03/11/2026 (Aristide) : loupe des listes (préparation et courses) : deux agrandissements, puis la taille normale.
class Loupe {
  static const paliers = [1.0, 1.3, 1.6];
  static int palier = 0;
  static double get echelle => paliers[palier];
}

Widget boutonLoupe(VoidCallback maj) => KeyedSubtree(
      key: const ValueKey('bouton-loupe'),
      child: _BoutonBascule(
        actif: Loupe.palier > 0,
        image: 'assets/icones/noto3d/magnifying-glass-tilted-left.png',
        libelle: Loupe.palier > 0 ? 'Texte à ${(Loupe.echelle * 100).round()} %' : 'Agrandir le texte',
        texte: Loupe.palier > 0 ? '${(Loupe.echelle * 100).round()} %' : null,
        onTap: () {
          Loupe.palier = (Loupe.palier + 1) % Loupe.paliers.length;
          maj();
        },
      ),
    );

/// La liste, avec le texte à la taille choisie par la loupe.
Widget avecLoupe(BuildContext context, Widget liste) =>
    MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(Loupe.echelle)), child: liste);
