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
| `lib/donnees/import_texte.dart`, `recette_ingredients.dart` | lecture d'une liste collée, d'une recette |
| `lib/ecrans/travail.dart` + `travail/*.dart` | écrans de travail : nouvelle liste, préparation, ligne d'article, promotion, courses, consultation |
| `lib/ecrans/console_*.dart`, `editeur_catalogue.dart`, `administration*.dart` | console Windows (catalogue, recettes, serveur) |
| `outils/fenetre_editeur.py` | fenêtre de la console (taille, redimensionnable, largeur minimum reçue de Dart par le canal `emplettes/fenetre` : menu 270/64 + 1 + 820) |
| `lib/composants/` | éléments d'interface communs (volets, boutons, champs, en-tête, recherche) |
| `outils/` | scripts (icônes, catalogue, site, vidéo, serveur `outils/vps/installer.sh`) |
| `docs/` | mini-site emplettes.eu (généré par `outils/site/generer.py`) |
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
APK démo), Windows (installateur), web (application, démo, site). Marqueurs du message de commit : `[rapide]`
(Windows seul), `[apk]`, `[web]` (voir `CLAUDE.md`). Tout est publié sur la page « derniere-version » (réservée au développement) et déposé sur le serveur OVH dans
`telechargements/essai/` ; « [version] » dans le message (« Clôturer la version ») le dépose aussi dans le dépôt
officiel `telechargements/`.

## 11. Fragilités connues (16/11/2026)

- Un seul compte MQTT pour toutes les applications ; la clé publique de signature n'est pas encore posée
  (`clePubliqueEditeur` vide).
- Pas de sauvegarde centrale des données des foyers.
- `nb_utilisations` ne converge pas exactement entre appareils.
- Correspondances de noms approximatives (listes collées, recettes).
