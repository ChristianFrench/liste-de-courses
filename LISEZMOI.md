# Liste de courses (Android, Windows, web)

Application Flutter pour préparer à plusieurs la liste de courses du foyer, puis faire les courses
dans l'ordre des allées du magasin. Une seule base de code pour trois versions :

- **Android** : `Liste-de-courses.apk` ;
- **Windows** : `Liste-de-courses-Windows.zip` (décompresser, lancer `liste_de_courses.exe`) ;
- **web** (iPhone, iPad, PC) : https://christianfrench.github.io/liste-de-courses/web/

Tous les fichiers de la dernière compilation sont sur la page
[derniere-version](https://github.com/ChristianFrench/liste-de-courses/releases/tag/derniere-version).

## Données et partage

Chaque appareil a sa base locale (SQLite ; IndexedDB dans le navigateur) et fonctionne sans réseau.
Au premier lancement, on choisit de l'utiliser **seul** ou **en foyer**. En foyer, les appareils
échangent leurs modifications par un serveur MQTT (EMQX Cloud), la plus récente l'emportant.
L'identifiant du serveur est fourni à la compilation par les secrets GitHub `MQTT_UTILISATEUR`
et `MQTT_MOT_DE_PASSE` ; il n'est jamais écrit dans le dépôt.

## Compilation

À chaque dépôt, le workflow « Compilation Android, Windows, web » (`.github/workflows/build.yml`) :
analyse le code, passe les tests de recette, fait les captures d'écran (branche `captures`),
compile les trois versions, publie la version web sur GitHub Pages et les fichiers sur la page
« derniere-version ». Un message de commit contenant `[rapide]` ne compile que Windows ; `[web]`, que la version web.
En cas d'échec, les erreurs apparaissent en tête de la page du travail (« Annotations »).

Autres workflows : « Catalogue Open Food Facts » (`catalogue.yml`, page « catalogue-off »,
base le 1er du mois, mise à jour chaque nuit) et « Essai Android » (`essai-android.yml`,
l'APK sur un émulateur, lancé à la main).

## Organisation

| Dossier / fichier | Contenu |
|---|---|
| `lib/main.dart` | Démarrage, format téléphone sous Windows |
| `lib/theme.dart` | Charte (couleurs, police, tailles) |
| `lib/donnees/` | Modèle (`modele.dart`), base locale (`stockage.dart`), synchronisation (`synchro.dart`), catalogue |
| `lib/composants/` | Composants réutilisables, en-tête des fenêtres |
| `lib/ecrans/` | Les écrans : accueil, préparation, courses, Gérer (foyer, catalogue, magasins, paramètres…) |
| `assets/` | Catalogue type, correspondances des listes par mail, images, police Atkinson Hyperlegible (OFL) |
| `test/` | Tests de recette et captures d'écran |
| `outils/` | Scripts lancés par la compilation ou par le fil de génération |
| `docs/` | Page de présentation publiée avec la version web |
| `documents/` | Fiches d'évolution, cahier de tests, spécification (dans `Documents.zip`) |
| `ihm/` | Ordres de travail du fil IHM (voir `CLAUDE.md`) |
