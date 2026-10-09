"""Construit le « Catalogue Open Food Facts » utilisé par l'application.

Lancé par GitHub Actions (workflow « Catalogue Open Food Facts ») ; rien à faire à la main.

  python outils/catalogue_off.py base <export.csv.gz> <categories.json> <categories.txt> <sortie.json.gz>
      Extrait complet (mensuel) : produits vendus en France, les plus scannés.

  python outils/catalogue_off.py cumul <base.json.gz> <ancien_cumul.json.gz|-> <dossier_deltas> <sortie.json.gz>
      Mise à jour cumulative (quotidienne) : tous les produits modifiés depuis la base,
      d'après les fichiers de changements quotidiens d'Open Food Facts.

Format (JSON compressé) :
  base  : version, jusqua, date, source, licence, categories, produits
  cumul : base, jusqua, date, categories (nouvelles, numérotées à la suite de la base), produits
  categories : [[tag, nom français, synonymes…], …]
  produits   : [[code, nom, marque, quantité, nutriscore, scans, [n° de catégories], photo], …]
"""
import csv
import glob
import gzip
import json
import os
import re
import sys
import time
import unicodedata

MAX_PRODUITS = 60000          # taille de l'extrait de base (les plus scannés)
SCANS_MIN = 2                 # en dessous : produit trop confidentiel


def sans_accents(t):
    t = unicodedata.normalize("NFD", t)
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


def normaliser(t):
    return sans_accents(t.lower()).strip()


def slug(t):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", normaliser(t))).strip("-")


# ---------------------------------------------------------------- Taxonomie

def lire_synonymes(chemin_txt):
    """Synonymes français de la taxonomie source (fichier categories.txt)."""
    synonymes = {}
    bloc = []

    def traiter(bloc):
        tag, fr = None, []
        for ligne in bloc:
            m = re.match(r"^([a-z]{2,3}|xx):\s*(.+)$", ligne)
            if not m:
                continue
            langue, noms = m.group(1), [n.strip() for n in m.group(2).split(",") if n.strip()]
            if langue in ("en", "fr", "xx") and tag is None and langue != "xx":
                tag = f"{langue}:{slug(noms[0])}"
            if langue == "fr":
                fr = noms
        if tag is None:
            for ligne in bloc:
                m = re.match(r"^([a-z]{2,3}):\s*(.+)$", ligne)
                if m and m.group(1) not in ("xx",):
                    tag = f"{m.group(1)}:{slug(m.group(2).split(',')[0])}"
                    break
        if tag and fr:
            synonymes[tag] = fr

    with open(chemin_txt, encoding="utf-8") as f:
        for ligne in f:
            ligne = ligne.rstrip("\n")
            if not ligne.strip():
                if bloc:
                    traiter(bloc)
                bloc = []
            elif not ligne.startswith("#") and not ligne.startswith("<"):
                bloc.append(ligne)
    if bloc:
        traiter(bloc)
    return synonymes


def lire_taxonomie(chemin_json, chemin_txt):
    with open(chemin_json, encoding="utf-8") as f:
        tax = json.load(f)
    synonymes = lire_synonymes(chemin_txt) if chemin_txt and os.path.exists(chemin_txt) else {}
    noms = {}
    avec_syn = 0
    for tag, e in tax.items():
        liste = []
        nom = (e.get("name") or {}).get("fr") or ""
        for s in [nom] + synonymes.get(tag, []):
            if s and normaliser(s) not in {normaliser(x) for x in liste}:
                liste.append(s)
        if liste:
            noms[tag] = liste
            if len(liste) > 1:
                avec_syn += 1
    print(f"taxonomie : {len(tax)} catégories, {len(noms)} avec un nom français, {avec_syn} avec synonymes")
    return noms


# ---------------------------------------------------------------- Outils communs

def chemin_photo_url(url):
    marque = "/images/products/"
    i = url.find(marque)
    return url[i + len(marque):] if i >= 0 else ""


def chemin_photo_doc(doc):
    """Chemin de la photo de face (200 px) d'après un document produit complet."""
    code = str(doc.get("code") or "")
    images = doc.get("images") or {}
    langue = doc.get("lang") or "fr"
    for cle in ("front_fr", f"front_{langue}", "front"):
        rev = (images.get(cle) or {}).get("rev")
        if rev:
            break
    else:
        return ""
    if code.isdigit() and len(code) <= 13:
        c = code.zfill(13)
        dossier = f"{c[0:3]}/{c[3:6]}/{c[6:9]}/{c[9:]}"
    else:
        dossier = code
    return f"{dossier}/{cle}.{rev}.200.jpg"


def nutriscore(v):
    v = (v or "").strip().lower()
    return v if v in ("a", "b", "c", "d", "e") else ""


class Categories:
    """Catégories numérotées dans l'ordre d'apparition."""

    def __init__(self, noms, existantes=None):
        self.noms = noms
        self.liste = list(existantes or [])
        self.index = {c[0]: i for i, c in enumerate(self.liste)}
        self.nouvelles = []

    def numeros(self, tags):
        nums = []
        for c in tags:
            if c not in self.noms:
                continue
            if c not in self.index:
                self.index[c] = len(self.liste)
                entree = [c] + self.noms[c]
                self.liste.append(entree)
                self.nouvelles.append(entree)
            nums.append(self.index[c])
        return nums


def ecrire(chemin, contenu):
    with gzip.open(chemin, "wt", encoding="utf-8") as f:
        json.dump(contenu, f, ensure_ascii=False, separators=(",", ":"))
    print(f"écrit : {chemin} ({os.path.getsize(chemin) // 1024} Ko)")


def apercu(categories, produits):
    for mot in ("pates", "lait demi-ecreme", "cafe moulu", "yaourt nature", "pates a tartiner"):
        cibles = {i for i, c in enumerate(categories) if any(normaliser(s) == mot for s in c[1:])}
        n = sum(1 for p in produits if cibles & set(p[6]))
        print(f"  « {mot} » : {[categories[i][0] for i in cibles]} → {n} produits")


# ---------------------------------------------------------------- Base

def base(export, tax_json, tax_txt, sortie):
    debut = time.time()
    noms = lire_taxonomie(tax_json, tax_txt)
    csv.field_size_limit(1 << 30)
    candidats = []
    lus = france = 0
    jusqua = max_maj = recents = 0
    with gzip.open(export, "rt", encoding="utf-8", errors="replace", newline="") as f:
        lecteur = csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
        for l in lecteur:
            lus += 1
            if lus % 1000000 == 0:
                print(f"  {lus} lignes lues ({time.time()-debut:.0f} s)", flush=True)
            try:
                m = int(l.get("last_modified_t") or 0)
                u = int(l.get("last_updated_t") or 0)
                jusqua = max(jusqua, m)
                max_maj = max(max_maj, u)
                if m >= 1788220800:
                    recents += 1
            except ValueError:
                pass
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
            candidats.append((code, nom, marques[0] if marques else "", (l.get("quantity") or "").strip(),
                              nutriscore(l.get("nutriscore_grade")), scans,
                              (l.get("categories_tags") or "").split(","),
                              chemin_photo_url(l.get("image_small_url") or "")))
    print(f"lu : {lus} lignes ; vendus en France : {france} ; candidats : {len(candidats)}")
    print(f"dernière modification : {time.strftime('%d/%m/%Y %H:%M', time.gmtime(jusqua))} ; "
          f"dernière mise à jour : {time.strftime('%d/%m/%Y %H:%M', time.gmtime(max_maj))} ; "
          f"modifiés depuis le 01/09/2026 : {recents}")
    candidats.sort(key=lambda p: -p[5])
    cats = Categories(noms)
    produits = [[p[0], p[1], p[2], p[3], p[4], p[5], cats.numeros(p[6]), p[7]] for p in candidats[:MAX_PRODUITS]]
    contenu = {
        "version": time.strftime("%Y%m%d"),
        "jusqua": jusqua,
        "date": time.strftime("%d/%m/%Y"),
        "source": "Open Food Facts (openfoodfacts.org)",
        "licence": "Données ODbL, photos CC BY-SA",
        "categories": cats.liste,
        "produits": produits,
    }
    ecrire(sortie, contenu)
    print(f"base : {len(produits)} produits, {len(cats.liste)} catégories, version {contenu['version']}, "
          f"modifications jusqu'au {time.strftime('%d/%m/%Y %H:%M', time.gmtime(jusqua))} UTC")
    apercu(cats.liste, produits)
    print(f"durée : {time.time()-debut:.0f} s")


# ---------------------------------------------------------------- Cumul

def bornes(nom_fichier):
    nombres = [int(n) for n in re.findall(r"(\d{9,11})", nom_fichier)]
    return (nombres[0], nombres[-1]) if nombres else (0, 0)


def cumul(chemin_base, chemin_ancien, dossier_deltas, sortie, tax_json=None, tax_txt=None):
    debut = time.time()
    b = json.load(gzip.open(chemin_base, "rt", encoding="utf-8"))
    dans_base = {p[0] for p in b["produits"]}
    ancien = None
    if chemin_ancien != "-" and os.path.exists(chemin_ancien):
        ancien = json.load(gzip.open(chemin_ancien, "rt", encoding="utf-8"))
        if ancien.get("base") != b["version"]:
            print("ancien cumul d'une autre base : ignoré")
            ancien = None
    depuis = ancien["jusqua"] if ancien else b["jusqua"]
    noms = lire_taxonomie(tax_json, tax_txt) if tax_json else {c[0]: c[1:] for c in b["categories"]}
    existantes = b["categories"] + (ancien["categories"] if ancien else [])
    cats = Categories(noms, existantes)
    produits = {p[0]: p for p in (ancien["produits"] if ancien else [])}
    jusqua = depuis
    fichiers = sorted(glob.glob(os.path.join(dossier_deltas, "*.json.gz")))
    lus = retenus = 0
    for chemin in fichiers:
        fin = bornes(os.path.basename(chemin))[1]
        if fin and fin <= depuis:
            continue
        with gzip.open(chemin, "rt", encoding="utf-8", errors="replace") as f:
            for ligne in f:
                try:
                    doc = json.loads(ligne)
                except ValueError:
                    continue
                lus += 1
                modifie = int(doc.get("last_modified_t") or 0)
                if modifie <= depuis:
                    continue
                jusqua = max(jusqua, modifie)
                code = str(doc.get("code") or "")
                if not code.isdigit() or "en:france" not in (doc.get("countries_tags") or []):
                    continue
                nom = (doc.get("product_name_fr") or doc.get("product_name") or "").strip()
                scans = int(doc.get("unique_scans_n") or 0)
                if not nom or (scans < SCANS_MIN and code not in dans_base):
                    continue
                marques = [m.strip() for m in (doc.get("brands") or "").split(",") if m.strip()]
                produits[code] = [code, nom, marques[0] if marques else "", (doc.get("quantity") or "").strip(),
                                  nutriscore(doc.get("nutriscore_grade")), scans,
                                  cats.numeros(doc.get("categories_tags") or []), chemin_photo_doc(doc)]
                retenus += 1
        print(f"  {os.path.basename(chemin)} : traité ({time.time()-debut:.0f} s)", flush=True)
    contenu = {
        "base": b["version"],
        "jusqua": jusqua,
        "date": time.strftime("%d/%m/%Y"),
        "categories": (ancien["categories"] if ancien else []) + cats.nouvelles,
        "produits": list(produits.values()),
    }
    ecrire(sortie, contenu)
    nouveaux = sum(1 for c in produits if c not in dans_base)
    print(f"cumul : {lus} changements lus, {retenus} retenus ; {len(produits)} produits "
          f"({nouveaux} nouveaux, {len(produits) - nouveaux} mis à jour) ; "
          f"jusqu'au {time.strftime('%d/%m/%Y %H:%M', time.gmtime(jusqua))} UTC ; {time.time()-debut:.0f} s")


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 5 and a[0] == "base":
        base(*a[1:])
    elif len(a) in (5, 7) and a[0] == "cumul":
        cumul(*a[1:])
    else:
        sys.exit(__doc__)
