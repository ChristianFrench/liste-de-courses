# Essai de synchronisation

Petite application indépendante de « Liste de courses », pour éprouver la synchronisation avant de l'intégrer :
base locale **sqlite_crdt** sur chaque appareil, échanges par **MQTT en QoS 1** (session persistante, reconnexion automatique).

Compilée seule par `.github/workflows/essai-synchro.yml` ; publiée sur la page de version « essai-synchro » :
`Essai-synchro.apk` (Android) et `Essai-synchro-Windows.zip` (PC).

## Mode d'emploi

1. Installer l'APK sur le téléphone, dézipper et lancer « Essai synchro.exe » sur le PC.
2. Onglet **Réglages** du PC : noter le code du foyer. Le saisir dans les Réglages du téléphone, puis « Appliquer ».
3. Le bandeau du haut montre l'autre appareil en ligne. Onglet **Liste** : ajouter, cocher, changer les quantités des deux côtés.
4. Onglet **Journal** : tout ce qui part et arrive, avec l'heure à la milliseconde.
5. Onglet **Essais** : message (notification), temps de réponse, volume, durée, simulation à partir de fichiers texte, comparaison des bases.

## Principe

- Chaque modification locale est enregistrée dans la base (horloge hybride, suppression = marque « supprimé »), puis publiée sur `ldc-essai/<foyer>/modifs/<appareil>`.
- L'appareil qui reçoit fusionne (la modification la plus récente l'emporte, ligne par ligne) et renvoie un accusé de réception, qui sert aux mesures.
- À chaque connexion, un appareil publie « bonjour » avec ce qu'il connaît déjà des autres ; chacun lui renvoie ce qui lui manque. Une coupure, même longue, se rattrape donc sans dépendre de la durée de session du serveur.
- Serveur par défaut : `broker.hivemq.com:8883` (public, sans compte). Un serveur privé (HiveMQ Cloud…) se règle dans l'application.
