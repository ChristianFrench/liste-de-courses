# Instructions pour le fil de génération (exe, APK, iPhone)

Ce dépôt est alimenté par deux fils de conversation :

- le fil « IHM et ergonomie », qui dépose la conception de l'interface dans `ihm/` ;
- le fil de génération, qui écrit le code Flutter et fait compiler les versions.

Le maître d'ouvrage (M. Bezard) n'intervient pas dans le code.

## Quand le maître d'ouvrage écrit « Générer »

1. Récupérer la dernière version du dépôt (`git pull`) : le fil IHM a pu y déposer de nouveaux éléments.
2. Lire `ihm/A_REALISER.md` : c'est l'ordre de travail en attente.
3. S'il contient un ordre au statut **« À réaliser »**, l'exécuter en suivant le `LISEZMOI.md` du répertoire indiqué (ordre de priorité des fichiers, critères de recette). Signaler au maître d'ouvrage toute contradiction plutôt que de trancher seul.
4. Une fois la version livrée, passer le statut de l'ordre à **« Réalisé »**, en indiquant la version de l'application et la date. Ne jamais supprimer un ordre.
5. S'il n'y a aucun ordre « À réaliser », le dire au maître d'ouvrage et lui demander ce qu'il souhaite.

## Règles

- Ne pas modifier le contenu de `ihm/vX.Y/` : c'est la référence transmise par le fil IHM. Un écart nécessaire se signale dans le compte rendu de livraison.
- Le répertoire `ihm/` n'entre pas dans `Documents.zip`. Copier la spécification dans `documents/` si elle doit figurer dans « 1 Documents ».

## Mode rapide (boucle d'essais) — pour économiser l'utilisation de Claude

Quand le maître d'ouvrage écrit **« Retours »** suivi d'une liste numérotée de remarques (erreurs, améliorations constatées en essayant l'exe) :

1. `git pull`, puis corriger **uniquement** les points listés. Ne lire que les fichiers concernés ; pas de relecture générale, pas de refonte.
2. Pas de fiche d'évolution, pas de cahier de tests, pas de captures, pas de comparaison avec la maquette, pas de navigateur.
3. Un seul commit dont le message contient **`[rapide]`** : seule la version **Windows** est compilée (tests de recette compris) ; l'APK et les captures précédents sont conservés sur la page « derniere-version ».
4. Suivre la compilation avec une seule commande d'attente (pas de vérifications répétées), puis répondre en **une ligne par point** : « corrigé », ou la question à poser. Pas de récapitulatif.
5. Ne pas changer le numéro de version.

Quand le maître d'ouvrage écrit **« Clôturer la version »** : compilation complète (sans `[rapide]`), numéro de version augmenté, fiche d'évolution unique récapitulant tous les retours traités depuis la version précédente, cahier de tests mis à jour.

Conseil au maître d'ouvrage : ouvrir un nouveau fil (avec le dépôt) quand le fil devient long ; tout l'état du projet est dans le dépôt.
