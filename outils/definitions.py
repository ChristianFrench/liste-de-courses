"""Écrit definitions.json, les valeurs passées à la compilation (--dart-define-from-file) : numéro de version,
commit et secrets GitHub. Un seul fichier plutôt qu'une suite d'arguments : sous Windows, flutter.bat
recoupe la ligne de commande et la compilation échouait. Lancé par GitHub Actions ; rien à faire à la main."""
import json
import os
import re

version = re.search(r"^version:\s*([^+\s]+)", open("pubspec.yaml", encoding="utf-8").read(), re.M)[1]
valeurs = {"VERSION": version, "COMMIT": os.environ.get("GITHUB_SHA", "")[:7]}
for n in ["MQTT_UTILISATEUR", "MQTT_MOT_DE_PASSE", "CODE_EDITEUR", "EMAILJS_SERVICE", "EMAILJS_MODELE", "EMAILJS_CLE"]:
    if os.environ.get(n):
        valeurs[n] = os.environ[n]
with open("definitions.json", "w", encoding="utf-8") as f:
    json.dump(valeurs, f)
print("definitions.json :", ", ".join(sorted(valeurs)))
