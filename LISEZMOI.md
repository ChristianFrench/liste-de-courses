# Liste de courses — étape 1 (Flutter, trois plateformes)

Application minimale qui affiche l'icône, le nom, la version et la plateforme.
Elle sert à valider la chaîne de compilation GitHub pour Android, Windows et iPhone.
Firebase sera ajouté à l'étape suivante.

À chaque dépôt de fichiers, l'onglet **Actions** lance trois compilations en parallèle :

| Version  | Fichier téléchargeable (section « Artifacts ») |
|----------|------------------------------------------------|
| Android  | Liste de courses Android → `Liste de courses.apk` |
| Windows  | Liste de courses Windows → dossier contenant `liste_de_courses.exe` |
| iPhone   | aucun fichier : la coche verte indique seulement que le code compile pour iPhone |

Sous Windows : décompresser le zip dans un dossier (par exemple `Documents\Liste de courses`)
et lancer `liste_de_courses.exe`. Garder tous les fichiers du dossier ensemble.
La fenêtre s'ouvre au format téléphone (412 × 892), sans redimensionnement.
