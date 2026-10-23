# Résume dans GitHub (annotations) le résultat de l'essai du .bat Mosquitto ; en cas d'échec,
# la fin du journal est jointe en une seule annotation.
import sys
lignes = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
reussi = any("convient à la synchronisation" in l for l in lignes)
for l in lignes:
    t = l.strip()
    if t.startswith(("[OK]", "[ECHEC]", "[ATTENTION]", "RESULTAT")):
        print(f"::{'notice' if t.startswith('[OK]') or 'convient à' in t else 'warning'} title=Serveur MQTT Windows::{t}")
if not reussi:
    fin = "%0A".join(l.replace("%", "%25") for l in lignes[-45:])
    print(f"::warning title=Journal du .bat::{fin}")
