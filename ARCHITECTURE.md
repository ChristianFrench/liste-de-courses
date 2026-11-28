# Architecture d'Emplettes

Document de référence pour qui modifie le code : un nouveau fil de génération, ou un développeur.
À lire avant toute modification, et à tenir à jour à chaque changement de structure.

Rédigé le 16/11/2026, après le découpage de `modele.dart` et `travail.dart`.

## 1. Vue d'ensemble

Il n'y a qu'un seul code Flutter. Plusieurs produits en sont compilés, selon les options de compilation (`--dart-define`) :

| Produit | Option | Où il sort |
|---|---|---|
| Emplettes (Android, Windows, web) | — | page « derniere-version », https://emplettes.eu/web/ |
| Démonstration (web et APK « Emplettes démo ») | `DEMONSTRATION=true` | …/demo/, `Emplettes-demo.apk` |
| Console catalogue (Windows) | `OUTIL_EDITEUR=true` | installateur à part (artefact de la CI) |

Chaque appareil garde **toutes** ses données dans une base SQLite locale. Il fonctionne sans réseau. Le partage
entre les appareils d'un foyer passe par un serveur MQTT ; le serveur ne fait que transmettre et garder les
derniers messages, et ne sait rien lire, car tout est chiffré par foyer.

```
 écran (lib/ecrans) ──► Etat (lib/donnees/modele.dart + modele/*) ──► Stockage (stockage.dart, SQLite)
                              ▲                                              │ journal d'échange
                              │ integrerDistant                              ▼
                         Synchro (synchro.dart) ◄──── MQTT (serveur OVH) ◄──► autres appareils
```

## 2. Où est quoi

| Dossier / fichier | Rôle |
|---|---|
| `lib/main.dart`, `lib/navigation.dart`, `lib/theme.dart` | lancement, navigation, charte graphique |
| `lib/donnees/modele.dart` | classe `Etat` : champs, chargement, enregistrement, notification des écrans |
| `lib/donnees/modele/entites.dart` | objets du foyer : Magasin, Rayon, Secteur, Produit, Liste, LigneListe, Course… |
| `lib/donnees/modele/etat_*.dart` | méthodes de `Etat` par domaine (extensions) : chargement, listes, courses, catalogue, corbeille, foyer, catalogue commun, marques |
| `lib/donnees/stockage.dart` + `schema_v2.dart` | base SQLite (schéma : `documents/schema-v2.sql`) et journal d'échange |
| `lib/donnees/synchro.dart` | partage MQTT, horloge hybride, présence des appareils |
| `lib/donnees/chiffrement.dart` | chiffrement AES-GCM par foyer |
| `lib/donnees/catalogue_commun.dart`, `signature.dart`, `moderation.dart` | catalogue commun à tous les foyers : publication, signature, filtrage des apports |
| `lib/donnees/reparation.dart` | réparations au démarrage (emplacements perdus, homonymes) |
| `lib/donnees/sauvegarde*.dart` | copies de sauvegarde automatiques |
| `lib/donnees/mise_a_jour*.dart` | mise à jour depuis l'application (fiche `version.json` du serveur, téléchargement, installation) |
| `lib/donnees/messages.dart`, `notifications_telephone.dart`, `envoi.dart` | messages du foyer (ntfy, Firebase), mails, tickets PDF |
| `lib/donnees/import_texte.dart`, `recette_ingredients.dart` | lecture d'une liste collée, d'une recette ; `RecetteLue` (critères, temps, `ingredientsPour(n)`), `FiltreRecettes` (recherche titre + ingrédients, « ou » dans un critère, « et » entre critères), `ajusterQuantite` |
| `lib/ecrans/travail.dart` + `travail/*.dart` | écrans de travail : nouvelle liste, préparation, ligne d'article, promotion, courses, consultation |
| `lib/donnees/modele/etat_recettes.dart` | « Note préparée » du foyer (21/11/2026) : `NoteRecette` (à traiter / traitée / ignorée, liste), option partagée `noteRecettes` ; notée depuis l'onglet Recettes (`FicheRecette(choix: true)`), traitée en tête de la préparation (« Recettes choisies », `_recettesChoisies` dans `travail/preparation.dart`, même fenêtre `cocherIngredientsRecette`, ingrédients groupés : reconnus, à choisir (`candidatsProduit` dans import_texte : même nom dans plusieurs secteurs), non trouvés ; les deux derniers vont dans `NoteRecette.aRegler`, lignes sous la recette, réglées par le même choix que la recherche (`_regler`)) ; bandeau pliable `BandeauRecettes` + `LigneRecetteChoisie` partagés avec les courses (recettes traitées pour la liste, toucher = fiche) |
| `lib/donnees/recettes_recues.dart` | catalogue commun des recettes reçu (20/11/2026) : index signé `ldc/recettes-communes` lu au lancement (`main.dart`, pas en démonstration), gardé dans le réglage `recettes_communes` ; images manquantes par empreinte sur `ldc/recettes-images/<empreinte>` (`Transport.abonner`), gardées en réglages `recette_image:<e>` ; les empreintes des images embarquées (`empreinte` dans `assets/recettes/recettes.json`) ne sont pas téléchargées ; fenêtre « Nouveautés des recettes » (`montrerNouveautesRecettes`, `GuetteurNouveautes`). Publication : console, `recettes_communes.dart` |
| `lib/ecrans/recettes.dart` | onglet « Recettes » (`Nav.avecCuisiner`, vrai dans toutes les versions depuis le 22/11/2026 ; onglet « Cuisiner » supprimé le 23/11, recettes à cuisiner = accueil « Recettes choisies », `FicheRecette(surRecette: true)` ; filtre Type strict, `_typesVus` ; `Nav.recettes`/`Nav.cuisiner`/`Nav.gerer`/`nbOnglets`/`Nav.ordre` en dépendent ; Gérer hors de la barre, roue dentée de l'accueil), sinon Gérer › Courses › Catalogue des recettes et le bouton de l'en-tête (`EnTeteFenetre.chercherRecette`, fixé dans `main.dart`). Filtres (`FiltresRecettes`), fiche à onglets Ingrédients / Recette avec − / + personnes, « Ajouter aux courses » (`ajouterAuxCourses` → `cocherIngredientsRecette` de `travail/preparation.dart`, commun avec le bouton « Recette » de la préparation). Données : `outils/recettes/vers_application.py` → `assets/recettes/recettes.json` (catalogue v7 : `sousTypes`, `origine`). Classement commun console / application dans `lib/donnees/classement_recettes.dart` (`typesRecettes`, `originesRecettes`, `rangSousType`, `rangTypeRecette`, sans dart:io) ; une recette se range sous chacun de ses types, puis par sous-type (`BandeSousType`) ; filtre Origine. Icônes des types et sous-types : `assets/recettes/types/<type>[--<sous-type>].png` (`imageDuType`, `slugRecette`). Tests : `recettesFournies()` est lu dans `setUpAll` (sinon blocage du temps simulé). Icônes d'Aristide : critères `assets/recettes/criteres/` (`iconeCritere`, sources `outils/recettes/icones/`), cocotte `assets/recettes/recettes-de-cuisine.png` (toute `Icons.restaurant_menu_outlined`, cf. `Icone`), onglet `assets/emplettes/cuisiner.png` |
| `lib/composants/recherche.dart`, `micro.dart` | champ de recherche d'article ; micro de dictée de toutes les zones de recherche (Android et web, `speech_to_text`) |
| `lib/ecrans/console_*.dart`, `editeur_catalogue.dart`, `administration*.dart` | console Windows (catalogue, recettes, serveur) |
| `lib/ecrans/console_commun.dart` | présentation commune des trois catalogues de la console (21/11/2026) : `EnTeteConsole` (titre, chiffres, pastilles, Généraliser, menu ☰), `BarreConsole` (recherche stricte, icônes ⇊ tout déplier / ⇈ tout replier sur TOUTE la hiérarchie, boutons, aide), `CadreConsole`, `RangeeConsole` (22/11/2026 : une seule rangée pour tous les niveaux : titre = même fond, même police, chevron à gauche, place d'icône ; feuille = ligne blanche à colonnes), `menuConsole`. Règle : ne jamais créer de bandeau propre à un catalogue. Marques = `EcranEditeurCatalogue(large, marques: true)` → `CatalogueMarquesLarge` (même état et même journal que les produits, domaine › marque › produits) ; recettes = type › sous-type › recettes (sans vignette), détail en fenêtre à trois onglets (Caractéristiques avec l'illustration, Ingrédients avec « Pour N », Recette). Marques : la file « À examiner » n'est calculée qu'à l'ouverture de sa fenêtre (lenteur) |
| `lib/ecrans/catalogues/fenetre_catalogues.dart` | « Emplettes · catalogues » (22/11/2026, Aristide) : logiciel Windows de gestion du contenu, séparé de la console technique (à laquelle on ne touche plus). Compilé avec OUTIL_EDITEUR=true + OUTIL_CATALOGUES=true (mêmes données que la console), installateur `outils/installation/catalogues.iss` (icône provisoire catalogues.ico), déposé avec la console dans telechargements/console/. Normes Windows : barre de menus (Fichier, Édition, Affichage, Insertion, Version, Outils, ?), barre d'outils, zone de travail (les pages des trois catalogues), barre d'état ; écran d'accueil `AccueilCatalogues`, aide F1, raccourcis, à propos. Les menus agissent sur la page affichée via `CommandesConsole` (console_commun.dart). Commandes grisées = étapes suivantes (fiche à droite, stockage sur le serveur, « Proposer cette version »), voir la proposition https://claude.ai/artifact/GWNKPRiwChPXr37KuMWKtK |
| `windows-catalogues/` | 22/11/2026 (Aristide : « un développement purement Windows ») : « Emplettes · catalogues » en C# WinForms (.NET 8), Segoe UI 9 pt. `FormPrincipale` (MenuStrip, ToolStrip, arbre TreeView à gauche, fiche à droite, StatusStrip), `PanneauRecette` (même fiche pour voir et modifier : critères en listes déroulantes, `ListeCochable` pour les critères à plusieurs valeurs, ingrédients et étapes en grilles modifiables), `Icones` (glyphes Segoe Fluent Icons / MDL2 en couleur), `Donnees/` (modèle, `Entrepot` : lit les données de la console sur le PC, %APPDATA%\…\editeur : SQLite `parametre` catalogue_brouillon / catalogue_commun, recettes/recettes.json ; écrit recettes.json avec copie .bak, en gardant les champs inconnus ; déplacements du catalogue des produits écrits dans catalogue_brouillon + une ligne du journal catalogue_journal.enCours, copie .bak de la base à la première écriture). Arbre façon Explorateur (`Natif.ThemeExplorateur`, ImageList 24 px des icônes de l'application via `IconesCatalogue`, installées dans {app}\icones), `Banniere` (version publiée, chiffres, gestes en cours), glisser-déposer et Couper/Copier/Coller (produit → secteur, secteur → rayon, rayon → domaine, recette → type/sous-type ; copier : produit et recette seulement). Catalogue des marques = domaine › rayon › secteur › marque › produits du secteur (22/11/2026, Aristide : marques vues par rapport aux produits d'un secteur ; icônes des secteurs) : `Donnees/Marques.cs` (`MarquesParSecteur`), fichier livré `Donnees/marques-secteurs.json` produit par `outils/marques/hierarchie_secteurs.py` depuis sa hiérarchie `outils/marques/hierarchie-aristide-v2.json`, copié au premier lancement dans marques/secteurs.json des données (.bak à chaque enregistrement) ; les marques des produits d'un secteur s'y ajoutent à l'affichage ; marques de distributeur tous rayons à part ; une marque se glisse ou se copie d'un secteur à l'autre. Compilé par build.yml (dotnet publish autonome win-x64 + catalogues.iss) et vérifié vite par catalogues-verif.yml. Remplace la fenêtre Flutter fenetre_catalogues.dart (gardée tant que le choix n'est pas confirmé) |
| `outils/fenetre_editeur.py` | fenêtre de la console (taille, redimensionnable, largeur minimum reçue de Dart par le canal `emplettes/fenetre` : menu 270/64 + 1 + 820) |
| `outils/recettes/nouvelles_298_497.py`, `nouvelles_498_597.py`, `difficulte.py`, `criteres.py`, `classement.py` (9 types, sous-types, origine), `vers_application.py` | recettes livrées avec la console (`outils/recettes/illustrations/recettes-fournies.json`, version à augmenter pour réappliquer) et leur copie allégée pour l'application |
| `lib/donnees/recettes_communes.dart`, `lib/ecrans/console_recettes_edition.dart` | catalogue des recettes versionné (20/11/2026) : modification dans la console, journal (`journal.json` de la base), « Généraliser » publie l'index signé `ldc/recettes-communes` et les images `ldc/recettes-images/<empreinte>` |
| `lib/composants/` | éléments d'interface communs (volets, boutons, champs, en-tête, recherche) |
| `lib/composants/entete.dart` (`Aides`) | textes d'aide : une ligne par point « icône / Titre / phrase courte » séparés par des barres verticales (icônes dans `_iconesAide`) ; `montrerAide` : titre = fonction de l'écran (1re ligne), sections « #À l'écran » et « #Vous pouvez », gestes communs derrière l'icône en haut à droite (24/11/2026) |
| `outils/` | scripts (icônes, catalogue, site, vidéo, documents de version `outils/documents/odt_version.py`, serveur `outils/vps/installer.sh`) |
| `docs/` | mini-site emplettes.eu (généré par `outils/site/generer.py` ; chiffres produits/marques/recettes écrits par la CI avec `outils/site/chiffres.py` dans `chiffres.json`, lus par `site.js` ; vidéo : `outils/video/`) |
| `ihm/` | ordres de travail du fil IHM (voir `CLAUDE.md`) |

## 3. Le modèle en mémoire : `Etat`

- `Etat.instance` est unique. C'est un `ChangeNotifier` : les écrans l'écoutent et se redessinent.
- Les **champs** (listes de magasins, produits, emplacements…) sont dans `modele.dart`. Les **méthodes** sont
  rangées par domaine dans `modele/etat_*.dart`, sous forme d'extensions (`extension EtatListes on Etat`). Pour
  l'appelant, rien ne change : `etat.ajouterLigne(...)`.
- Toute modification se termine par `modifie()` : enregistrement en base, puis notification des écrans.
- Les recherches fréquentes passent par des index (`liste_suivie.dart`) : ne jamais parcourir les 17 000
  emplacements à chaque affichage.

Contraintes du découpage en extensions (Dart) :

- une méthode qui appelle `notifyListeners` ou `super.` reste dans la classe ;
- un getter et son setter restent ensemble ;
- les membres statiques restent dans la classe et s'écrivent `Etat.xxx` dans les extensions ;
- un `import 'modele.dart' show Etat` doit aussi montrer les extensions utilisées (`show Etat, EtatChargement`).

## 4. La base locale : `Stockage`

- Une table par entité (schéma v2). Les règles de gestion sont tenues par des déclencheurs SQL.
- `ecrire(etat)` compare chaque ligne à son **empreinte** (`_ecrit`) et n'écrit que ce qui a changé.
- Un objet retiré n'est pas effacé : il reçoit `supprime = 1` (ou `archive = 1`). C'est indispensable au partage :
  le retrait doit voyager comme une modification.
- Chaque écriture faite avec une horloge (`horloge != null`) est notée dans le **journal d'échange**
  (`synchro_objet` : table, clé, horloge, appareil, valeurs). C'est ce journal qui part vers les autres appareils.
- Références orphelines (une ligne qui désigne un objet absent) : une référence **facultative** est vidée, la
  ligne est gardée ; seul un lien dont la référence **obligatoire** manque est retiré (règle du 16/11/2026).
- Base abîmée : à l'ouverture, `verifier` / `recopierDans` / `mettreDeCote`. Le web garde la base dans IndexedDB,
  avec un verrou (`Web Locks`) pour interdire deux onglets.

## 5. Le chemin d'une modification

1. L'écran appelle une méthode de `Etat` (par exemple cocher un article).
2. `modifie()` → `Stockage.ecrire` : la ligne change en base et un objet est noté au journal, avec une horloge
   hybride « heure-compteur-appareil » qui ordonne les événements même si les montres diffèrent.
3. `Synchro` publie les nouveaux objets, chiffrés, sur `ldc/<code de partage>/modifs/<appareil>` (QoS 1,
   session persistante : un appareil hors ligne les reçoit à son retour).
4. Chez les autres, `Stockage.appliquer` intègre chaque objet **s'il est plus récent** que celui connu
   (« le plus récent l'emporte »). Un objet refusé par la base (son secteur pas encore arrivé) attend dans
   `synchro_attente` et est réessayé.
5. `Etat.integrerDistant` relit, puis `corrigerHomonymes` remet chaque produit homonyme dans son secteur.
6. À la connexion, `bonjour` dit ce que l'appareil connaît déjà ; les autres renvoient le reste.

## 6. Le catalogue commun

- Il est tenu par une seule personne dans la console Windows et publié en message retenu `ldc/catalogue-commun`,
  compressé (`gz:`) et **signé** (Ed25519, `signature.dart`).
- Chaque application le vérifie, puis `appliquerCatalogueCommun` l'ajoute au foyer avec des **identifiants
  calculés depuis les noms** : deux appareils qui l'appliquent en même temps créent les mêmes objets. Rien de ce
  que le foyer utilise n'est retiré.
- Les foyers renvoient leurs ajouts achetés (`apports`), filtrés à la réception par `moderation.dart`.
- Pour lire le catalogue réellement publié : lancer `.github/workflows/lire-catalogue.yml`. Les copies du dépôt
  (`assets/catalogue_type.json`) sont anciennes.

## 7. Le serveur

- Un VPS OVH installé par `outils/vps/installer.sh` : Mosquitto (MQTT), ntfy (messages, relayés à Firebase pour
  Android), Nginx (site emplettes.eu, version web, WebSocket MQTT), relais de mails, sauvegardes de nuit.
- Les identifiants sont des secrets GitHub, injectés à la compilation, jamais écrits dans le dépôt.
- Les applications à télécharger sont sur le serveur (18/11/2026), plus sur GitHub : `https://<domaine>/telechargements/`
  (versions clôturées, liens du site) et `telechargements/essai/` (chaque compilation). `version.json` y donne,
  pour chaque application (`apk`, `demo`, `exe`), le commit de sa dernière compilation ; l'application le compare
  au sien pour proposer la mise à jour. Le web lit son propre `web/version.json` (ou `demo/`).
- `telechargements/essai/` et `telechargements/console/` sont protégés par mot de passe
  (`outils/vps/proteger_telechargements.sh`, à relancer après une réinstallation du serveur) ; l'APK démo lit
  `essai/` avec le compte « application » (secret `TELECHARGEMENTS_ESSAI`). La console n'y est déposée que si
  son dossier est protégé.
- Changer de VPS : `outils/vps/migrer.sh` (`exporter` sur l'ancien, `importer` sur le nouveau, après le changement
  d'IP dans les DNS) reprend mots de passe, clé de publication, certificats, état MQTT retenu, ntfy, site et
  téléchargements ; aucun secret GitHub ne change (`VPS_HOTE` est le nom de domaine).

## 8. Règles à ne jamais enfreindre

1. **Ne jamais écrire dans la base en dehors de `Stockage.ecrire` / `appliquer`.** Une écriture directe n'est pas
   journalisée : les appareils divergent en silence. (Exception connue : le compteur `nb_utilisations`.)
2. **Ne jamais effacer un objet partagé** : le marquer retiré, pour que le retrait voyage.
3. **Identifiants du catalogue commun déterministes** (calculés depuis les noms).
4. **Pendant les courses, rien ne modifie la liste ni les produits** (décision d'Aristide du 13/11/2026).
5. **Pas d'erreur avalée sans raison** : un `catch` donne une solution de repli prévue, ou note au journal de
   l'appareil (`Etat.noter`), ou prévient l'utilisateur.
6. **Le numéro de version ne change qu'à « Clôturer la version »** (voir `CLAUDE.md`).
7. Toute nouveauté d'essai passe d'abord par la démonstration (`demonstration` / `EcranConstruction.recettes`…).

## 9. Les essais

`flutter test` lance tout ; la CI les lance à chaque compilation et bloque la publication en cas d'échec.

| Fichier | Ce qu'il garantit |
|---|---|
| `test/convergence_test.dart` | trois appareils, modifications au hasard, messages en désordre et en double : tout converge ; base rouverte ; catalogue appliqué deux fois |
| `test/synchro_test.dart` | partage entre deux appareils, catalogue commun, modération, signature, réparation de base |
| `test/stockage_test.dart`, `persistance_catalogue_test.dart` | écriture, relecture, retraits, reprises de versions anciennes |
| `test/widget_test.dart` | parcours d'écrans (préparation, courses, Gérer…) |

Essai long à la main : `GRAINES=200 flutter test test/convergence_test.dart`. Pour comprendre un écart :
`TRACE=<clé> …` affiche les objets du journal concernés.

## 10. La compilation

`.github/workflows/build.yml`, à chaque envoi sur `main` : vérification (analyse et essais), Android (APK +
APK démo, téléphones ARM 32 et 64 bits, sans la partie PC x86_64), Windows (installateur), web (application, démo, site). Marqueurs du message de commit : `[rapide]`
(Windows seul), `[apk]`, `[web]` (voir `CLAUDE.md`). Tout est publié sur la page « derniere-version » (réservée au développement) et déposé sur le serveur OVH dans
`telechargements/essai/` ; « [version] » dans le message (« Clôturer la version ») le dépose aussi dans le dépôt
officiel `telechargements/`.

## 11. Fragilités connues (16/11/2026)

- Un seul compte MQTT pour toutes les applications ; la clé publique de signature n'est pas encore posée
  (`clePubliqueEditeur` vide).
- Pas de sauvegarde centrale des données des foyers.
- `nb_utilisations` ne converge pas exactement entre appareils.
- Correspondances de noms approximatives (listes collées, recettes).
