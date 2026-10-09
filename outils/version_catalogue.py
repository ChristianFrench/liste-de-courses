"""Écrit catalogue-version.txt, lu par l'application pour savoir quoi télécharger.

Usage : python outils/version_catalogue.py <base.json.gz> <cumul.json.gz>
"""
import gzip
import json
import sys
import time

b = json.load(gzip.open(sys.argv[1], "rt", encoding="utf-8"))
c = json.load(gzip.open(sys.argv[2], "rt", encoding="utf-8"))
print(f"base={b['version']}")
print(f"base_date={b['date']}")
print(f"base_produits={len(b['produits'])}")
print(f"maj={c['jusqua']}")
print(f"maj_date={time.strftime('%d/%m/%Y', time.gmtime(c['jusqua']))}")
print(f"maj_produits={len(c['produits'])}")
