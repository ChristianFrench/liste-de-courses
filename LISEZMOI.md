# Liste de courses — maquette Flutter (Android, iPhone, Windows)

Version 0.3 — maquette cliquable des 12 écrans de la « Spécification de l'IHM » (v0.1),
avec les données factices de `assets/donnees_maquette.json`. Pas encore de Firebase :
les modifications faites pendant l'essai restent en mémoire et sont perdues à la fermeture.

## Compilation

À chaque dépôt de fichiers, l'onglet **Actions** lance quatre travaux en parallèle :

| Travail       | Rôle | Fichier téléchargeable (section « Artifacts ») |
|---------------|------|------------------------------------------------|
| verification  | Analyse du code et tests de recette de la maquette | aucun : la coche verte indique que les tests passent |
| android       | APK | Liste de courses Android → `Liste de courses.apk` |
| windows       | Exécutable | Liste de courses Windows → dossier contenant `liste_de_courses.exe` |
| iphone        | Vérification | aucun fichier : la coche verte indique seulement que le code compile pour iPhone |

En cas d'échec, les messages d'erreur apparaissent en tête de la page du travail (« Annotations »).

Sous Windows : décompresser le zip dans un dossier (par exemple `Documents\Liste de courses`)
et lancer `liste_de_courses.exe`. Garder tous les fichiers du dossier ensemble.
La fenêtre s'ouvre au format téléphone (rapport 390 × 844), sans redimensionnement.

## Organisation du code

| Dossier / fichier | Contenu |
|---|---|
| `lib/main.dart` | Démarrage, chargement des données, format téléphone sous Windows |
| `lib/theme.dart` | Charte de la maquette (couleurs, police, tailles, hauteurs) |
| `lib/donnees/modele.dart` | Entités du modèle de données, état en mémoire, règles (préliste, alerte de quantité, étapes du parcours) |
| `lib/composants/composants.dart` | Composants réutilisables (chapitre 5) |
| `lib/ecrans/` | Un fichier par écran (chapitre 8), numérotés de `e01` à `e12` |
| `lib/navigation.dart` | Enchaînement des écrans et barre de navigation |
| `assets/` | Données factices, icône, police Atkinson Hyperlegible (licence OFL) |
| `test/widget_test.dart` | Tests de recette (chapitre 12) |
| `outils/` | Scripts lancés par la compilation GitHub |

## Particularités de la maquette

- **Date du jour figée au 9 octobre 2026**, pour que les promotions factices restent visibles.
- **Hors réseau simulé** : toucher « Synchronisé » en haut de l'accueil bascule en « Hors réseau » ;
  le bandeau d'information apparaît alors pendant les courses.
- Photo, envoi du code d'invitation, comptes magasin : boutons présents, fonction affichée « non disponible ».
- Taille des caractères du téléphone prise en compte jusqu'à 115 %, pour éviter les textes coupés.

## Catalogue Open Food Facts (depuis la version 0.5)

Workflow « Catalogue Open Food Facts » (`.github/workflows/catalogue.yml`), page « catalogue-off » :

| Fichier | Contenu | Fréquence |
|---|---|---|
| `catalogue.json.gz` | Base : les 60 000 produits les plus populaires en France | 1er du mois (export JSONL d'Open Food Facts) |
| `catalogue-maj.json.gz` | Mise à jour cumulative depuis la base | chaque nuit (fichiers de changements quotidiens) |
| `catalogue-version.txt` | Versions lues par l'application | à chaque publication |

La base est jointe à l'application à la compilation ; l'application télécharge ensuite
elle-même les mises à jour selon le délai réglé (7 jours par défaut).
