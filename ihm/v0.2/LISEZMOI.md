# Dossier maquette Flutter — Application liste de courses

Version 0.2 du 9 octobre 2026 (maquette v0.4, validée par le maître d'ouvrage). À lire en premier. Remplace la version 0.1 du dossier.

## La démarche

Ce dossier vient du fil « IHM et ergonomie » du projet. Il sert à réaliser une **maquette Flutter** de l'application. Un seul code est compilé pour trois plateformes, **dans cet ordre** :

1. **Windows** (.exe), en premier, pour les essais du maître d'ouvrage : fenêtre fixe de 390 × 844, même rendu qu'un téléphone ;
2. **Android** (APK) ;
3. **iPhone**.

La maquette montre les 18 écrans validés et tous leurs enchaînements, avec des **données factices** et **sans Firebase**. Elle sert à valider l'ergonomie avant le développement réel.

L'interface a d'abord été conçue sous forme de maquette fil de fer cliquable. Ce dossier la transmet sous plusieurs formes complémentaires, chacune pour un usage précis :

- la **disposition** est décrite par le code HTML des écrans ;
- les **valeurs de style** sont dans un fichier de « design tokens » au format W3C ;
- le **comportement et la navigation** sont dans un fichier YAML structuré ;
- les **données à afficher** sont dans un fichier JSON ;
- une **version lisible** pour le maître d'ouvrage est fournie en ODT.

## Contenu du zip

| Fichier ou dossier | Ce qu'il contient | Comment s'en servir |
|---|---|---|
| LISEZMOI.md | Ce texte | À lire en premier |
| Ecrans.yaml | La navigation (4 onglets et leurs sous-onglets), les règles d'interruption et de reprise, les promotions, les composants réutilisables et les 18 écrans. Pour chaque écran : identifiant (= nom de route), onglet, gabarit, zones de haut en bas, actions et écran cible, règles de gestion. S'y ajoutent les décisions validées. | **Référence pour le comportement et la navigation.** |
| Charte.tokens.json | Couleurs, police, tailles, hauteurs (barre d'onglets, sous-onglets, en-têtes, lignes), espacements, rayons, traits, voile. Format W3C Design Tokens (DTCG 2025.10) ; px = pixel logique Flutter. | **Référence pour les valeurs**, à traduire en `ThemeData` et en constantes. |
| Ecrans maquette/ | Sources HTML des 18 écrans | **Référence pour la disposition et les libellés** |
| Captures/ | Image PNG de chaque écran, numérotée comme dans Ecrans.yaml | Contrôle visuel |
| Données maquette.json | Données factices : foyer, membres, paramètres, types de promotion, magasins, rayons, secteurs, produits, emplacements, parcours, 4 listes (une préparation interrompue, une en construction, une prête, des courses interrompues), historique, tickets, fréquences de la préliste. Le champ `_ecartsModele` liste les écarts avec le modèle de données. | Asset chargé au premier lancement. |
| Spécification IHM.odt | Le même contenu rédigé pour le maître d'ouvrage, avec les captures | Le chapitre « Critères de recette » sert de liste de contrôle avant livraison |

## Points d'attention pour la réalisation

- **Interruption et reprise.** Chaque action est enregistrée immédiatement. Pour que la reprise fonctionne après fermeture, la maquette garde son état dans un **fichier JSON local** (dossier de données de l'application). Au premier lancement, ce fichier est initialisé depuis « Données maquette.json ». Prévoir aussi un moyen de **réinitialiser les données de démonstration**, par exemple un appui long sur le titre de Paramètres.
- **Écran de reprise au lancement** (`relance`). Il s'affiche avant tout le reste dès qu'il existe une liste au statut `enCours`, ou une liste `enConstruction` ayant un `interrompueLe`.
- **Barre d'onglets.** Elle est masquée sur les écrans de travail : préliste, construction, liste complète, courses par secteur. Ce choix est validé.
- **Windows.** La fenêtre est fixe en 390 × 844 et non redimensionnable, réglée au démarrage. Le retour système correspond à la touche Échap.
- **Photos.** Les boutons sont présents ; ils affichent seulement « Disponible plus tard ».

## Lire les sources HTML

Les fichiers `*.dc.html` viennent d'un outil de maquettage. Ce qu'il faut savoir pour les lire :

- `<x-dc>`, `<helmet>` et le script `support.js` sont propres à l'outil : à ignorer ;
- les styles `style="…"` et le bloc `<style>` donnent les valeurs exactes en pixels logiques ;
- `defaultChecked="{{ true }}"` signifie « case cochée dans l'exemple » ;
- les liens `href="Xxx.dc.html"` indiquent la navigation ; la correspondance entre fichier et identifiant d'écran est donnée par le champ `maquette` de Ecrans.yaml ;
- les textes entre crochets (`[Magasin 1]`, `[Membre 1]`, `[date]`) sont à remplacer par les données du fichier JSON ;
- les codes `LOT`, `2=€`, `−%`, `PK`, `FID`, `?` sont des icônes de promotion provisoires.

## En cas de contradiction

1. **Ecrans.yaml** prime pour le comportement, la navigation et les règles.
2. **Charte.tokens.json** prime pour les valeurs de style.
3. **Les sources HTML** priment pour la disposition et les libellés.
4. Signaler toute contradiction restante au maître d'ouvrage plutôt que de trancher en silence.

## Résultat attendu

- **Première livraison :** un installateur ou un exécutable Windows, prêt à lancer, avec les 18 écrans, toute la navigation et l'interruption/reprise. Les critères de recette de la spécification doivent être vérifiés.
- **Ensuite :** l'APK Android, puis la version iPhone, à partir du même code.
- **Hors périmètre :** connexion Google, Firebase, synchronisation, photos réelles, notifications, modifications en cours de courses.

## Documents de référence du projet

« Cahier des charges » (version 0.1) et « Modèle de données ». Les numéros de règles cités dans Ecrans.yaml renvoient aux règles de gestion numérotées du modèle de données.
