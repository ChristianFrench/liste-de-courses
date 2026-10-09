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
