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
# Serveur OVH d'Emplettes (06/11/2026) : dès que ses secrets existent, partage, messages et mails passent par lui ;
# EMQX, ntfy.sh et EmailJS ne servent plus (EmailJS reste en secours pour les mails).
if os.environ.get("MQTT_HOTE_VPS") and os.environ.get("MQTT_UTILISATEUR_VPS"):
    valeurs["MQTT_HOTE"] = os.environ["MQTT_HOTE_VPS"]
    valeurs["MQTT_UTILISATEUR"] = os.environ["MQTT_UTILISATEUR_VPS"]
    valeurs["MQTT_MOT_DE_PASSE"] = os.environ.get("MQTT_MOT_DE_PASSE_VPS", "")
if os.environ.get("VPS_HOTE"):
    valeurs["DOMAINE"] = os.environ["VPS_HOTE"]
if os.environ.get("RELAIS_CLE"):
    valeurs["RELAIS_CLE"] = os.environ["RELAIS_CLE"]
# Le code d'éditeur ne sert qu'à l'outil de l'éditeur du catalogue commun (05/11/2026) : pas dans l'application.
application = {k: v for k, v in valeurs.items() if k != "CODE_EDITEUR"}
with open("definitions.json", "w", encoding="utf-8") as f:
    json.dump(application, f)
with open("definitions-editeur.json", "w", encoding="utf-8") as f:
    json.dump(valeurs, f)
print("definitions.json :", ", ".join(sorted(application)))
print("definitions-editeur.json :", ", ".join(sorted(valeurs)))
