# Résume dans GitHub (annotations) le résultat de l'essai du .bat Mosquitto.
import sys
lignes = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
for l in lignes:
    t = l.strip()
    if t.startswith("[OK]") or t.startswith("[ECHEC]") or t.startswith("[ATTENTION]") or t.startswith("RESULTAT"):
        niveau = "notice" if t.startswith("[OK]") or "convient à" in t else "warning"
        print(f"::{niveau} title=Serveur MQTT Windows::{t}")
