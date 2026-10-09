"""Construit l'extrait « Catalogue Open Food Facts » utilisé par l'application.

Lancé par GitHub Actions (workflow « Catalogue Open Food Facts ») ; rien à faire à la main.

  python outils/catalogue_off.py base   <export.csv.gz> <categories.json> <sortie>
      → extrait complet : produits vendus en France, les plus scannés

Le fichier produit (JSON compressé) contient :
  version, date, source, licence,
  categories : [[tag, nom français, synonymes…], …]
  produits   : [[code, nom, marque, quantité, nutriscore, scans, [n° de catégories], photo], …]
"""
import csv
import gzip
import io
import json
import sys
import time
import unicodedata

MAX_PRODUITS = 60000          # taille de l'extrait (les plus scannés)
SCANS_MIN = 2                 # en dessous : produit trop confidentiel


def normaliser(t):
    t = unicodedata.normalize("NFD", t.lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn").strip()


def lire_taxonomie(chemin):
    with open(chemin, encoding="utf-8") as f:
        tax = json.load(f)
    noms = {}
    for tag, e in tax.items():
        nom = (e.get("name") or {}).get("fr") or ""
        syn = (e.get("synonyms") or {}).get("fr") or []
        if nom or syn:
            vus, liste = set(), []
            for s in [nom] + list(syn):
                if s and normaliser(s) not in vus:
                    vus.add(normaliser(s))
                    liste.append(s)
            noms[tag] = liste
    print(f"taxonomie : {len(tax)} catégories, {len(noms)} avec un nom français")
    return noms


def chemin_photo(url):
    # https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.633.200.jpg
    marque = "/images/products/"
    i = url.find(marque)
    return url[i + len(marque):] if i >= 0 else ""


def base(export, taxonomie, sortie):
    debut = time.time()
    noms_cat = lire_taxonomie(taxonomie)
    csv.field_size_limit(1 << 30)
    candidats = []
    lus = france = 0
    with gzip.open(export, "rt", encoding="utf-8", errors="replace", newline="") as f:
        lecteur = csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
        print("colonnes :", ", ".join(lecteur.fieldnames[:200]))
        for l in lecteur:
            lus += 1
            if lus % 500000 == 0:
                print(f"  {lus} lignes lues, {france} vendus en France, {len(candidats)} retenus ({time.time()-debut:.0f} s)", flush=True)
            if "en:france" not in (l.get("countries_tags") or ""):
                continue
            france += 1
            nom = (l.get("product_name") or "").strip()
            code = (l.get("code") or "").strip()
            if not nom or not code.isdigit():
                continue
            try:
                scans = int(float(l.get("unique_scans_n") or 0))
            except ValueError:
                scans = 0
            if scans < SCANS_MIN:
                continue
            marques = [m.strip() for m in (l.get("brands") or "").split(",") if m.strip()]
            cats = [c for c in (l.get("categories_tags") or "").split(",") if c in noms_cat]
            ns = (l.get("nutriscore_grade") or "").strip().lower()
            candidats.append((
                code, nom, marques[0] if marques else "", (l.get("quantity") or "").strip(),
                ns if ns in ("a", "b", "c", "d", "e") else "", scans, cats,
                chemin_photo(l.get("image_small_url") or ""),
            ))
    print(f"lu : {lus} lignes ; vendus en France : {france} ; candidats : {len(candidats)}")
    candidats.sort(key=lambda p: -p[5])
    retenus = candidats[:MAX_PRODUITS]
    index, categories = {}, []
    produits = []
    for p in retenus:
        nums = []
        for c in p[6]:
            if c not in index:
                index[c] = len(categories)
                categories.append([c] + noms_cat[c])
            nums.append(index[c])
        produits.append([p[0], p[1], p[2], p[3], p[4], p[5], nums, p[7]])
    version = time.strftime("%Y%m%d")
    contenu = {
        "version": version,
        "date": time.strftime("%d/%m/%Y"),
        "source": "Open Food Facts (openfoodfacts.org)",
        "licence": "Données ODbL, photos CC BY-SA",
        "categories": categories,
        "produits": produits,
    }
    with gzip.open(sortie, "wt", encoding="utf-8") as f:
        json.dump(contenu, f, ensure_ascii=False, separators=(",", ":"))
    print(f"extrait : {len(produits)} produits, {len(categories)} catégories, version {version}")
    print(f"durée : {time.time()-debut:.0f} s")
    # Aperçu pour contrôle
    for mot in ("pates", "lait demi-ecreme", "cafe moulu"):
        cibles = {i for i, c in enumerate(categories) if any(normaliser(s) == mot for s in c[1:])}
        n = sum(1 for p in produits if cibles & set(p[6]))
        print(f"  « {mot} » : catégories {[categories[i][0] for i in cibles]} → {n} produits")


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "base":
        base(*sys.argv[2:])
    else:
        sys.exit(__doc__)
