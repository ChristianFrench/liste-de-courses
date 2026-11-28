# Clé de signature des APK d'essai

`debug.keystore` signe toutes les versions de l'APK publiées sur « derniere-version » avec la même clé :
une nouvelle version s'installe ainsi par-dessus l'ancienne, sans perdre les données.

Mots de passe standard des clés de débogage Android (`android` / alias `androiddebugkey`).
Clé d'essai seulement : une publication sur le Play Store demandera une vraie clé, gardée hors du dépôt.
