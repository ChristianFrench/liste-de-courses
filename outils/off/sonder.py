"""Interroge Open Food Facts (produits vendus en France) : pour chaque catégorie demandée, le nombre de produits,
leurs marques et leurs sous-catégories, avec leurs nombres. Lancé à la main par le workflow « Open Food Facts »
(l'environnement de Claude n'a pas accès au site) ; le résultat sort en notes (annotations) de la compilation."""
import json, sys, time, urllib.request

AGENT = "ListeDeCourses/0.7 (outil de catalogue ; https://github.com/ChristianFrench/liste-de-courses)"


def lire(url):
    for essai in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            print(f"{url} : {e}", file=sys.stderr)
            time.sleep(10 * (essai + 1))
    return None


def facette(categorie, quoi):
    j = lire(f"https://world.openfoodfacts.org/country/france/category/{categorie}/{quoi}.json")
    return [] if j is None else [(t["name"], t["products"]) for t in j.get("tags", [])]


def note(titre, lignes):
    texte = "\n".join(lignes).replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::notice title={titre}::{texte}")


for cat in sys.argv[1].split(","):
    cat = cat.strip()
    if not cat:
        continue
    marques = facette(cat, "brands")
    sous = facette(cat, "categories")
    j = lire(f"https://world.openfoodfacts.org/country/france/category/{cat}.json?page_size=1&fields=code")
    total = j.get("count") if j else "?"
    lignes = [f"{cat} : {total} produits en France, {len(marques)} marques"]
    lignes += ["Marques : " + " ; ".join(f"{n} ({c})" for n, c in marques[:60])]
    lignes += ["Catégories : " + " ; ".join(f"{n} ({c})" for n, c in sous[:60])]
    note(cat, lignes)
    time.sleep(3)
