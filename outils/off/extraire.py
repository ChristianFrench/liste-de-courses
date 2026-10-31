"""Marques des produits Open Food Facts vendus en France, pour chaque nature (produit générique) du catalogue.

Lit l'export complet d'Open Food Facts (CSV, environ 1 Go compressé, lu au fil de l'eau), garde les produits
vendus en France, et range chacun sous la nature du catalogue la plus précise dont tous les mots sont dans son nom
(« Pâte à tartiner chocolat noisette » va à « Pâte à tartiner chocolat », pas à « Pâte »), à condition que le nom
commence comme la nature (« Yaourt à la fraise » n'est pas une fraise, « Jambon -25 % de sel » n'est pas du sel). Pour chaque nature :
le nombre de produits (sa popularité) et les marques présentes dans au moins 3 produits.
Écrit outils/off/natures_off.json. Lancé par le workflow « Open Food Facts - extraction » (l'environnement de
Claude n'a pas accès au site)."""
import collections, csv, gzip, io, json, re, sys, time, unicodedata, urllib.request

EXPORT = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
VIDES = {"de", "du", "des", "la", "le", "les", "l", "d", "a", "au", "aux", "et", "en", "pour", "avec", "un", "une", "sans"}


def sans_accents(t):
    return "".join(c for c in unicodedata.normalize("NFD", t) if unicodedata.category(c) != "Mn").replace("œ", "oe").replace("æ", "ae")


def liste_mots(nom):
    res = []
    for m in re.split(r"[^a-z0-9]+", sans_accents(nom.lower())):
        if not m or m in VIDES or m.isdigit():
            continue
        if len(m) > 3 and m[-1] in "sx":
            m = m[:-1]
        res.append(m)
    return res


def mots(nom):
    return frozenset(liste_mots(nom))


def cle_marque(m):
    return re.sub(r"[^a-z0-9]", "", sans_accents(m.lower()))


# Natures du catalogue
cat = json.load(open("assets/catalogue_type.json", encoding="utf-8"))
natures = []  # (clé, mots)
for r in cat["rayons"]:
    for s in r["secteurs"]:
        for p in s["produits"]:
            lm = liste_mots(p["nom"])
            if lm:
                natures.append((f"{r['nom']}/{s['nom']}/{p['nom']}", frozenset(lm), lm[0]))
par_mot = collections.defaultdict(list)
for i, (_, m, _) in enumerate(natures):
    for x in m:
        par_mot[x].append(i)

compte = collections.Counter()
marques = collections.defaultdict(collections.Counter)  # nature → clé de marque → nombre
graphies = collections.defaultdict(collections.Counter)  # clé de marque → graphies
lus = francais = ranges = 0
debut = time.time()
csv.field_size_limit(1 << 30)
req = urllib.request.Request(EXPORT, headers={"User-Agent": "ListeDeCourses/0.7 (catalogue)"})
with urllib.request.urlopen(req, timeout=300) as flux:
    texte = io.TextIOWrapper(gzip.GzipFile(fileobj=flux), encoding="utf-8", errors="replace", newline="")
    lecteur = csv.reader(texte, delimiter="\t", quoting=csv.QUOTE_NONE)
    entete = next(lecteur)
    col = {n: i for i, n in enumerate(entete)}
    i_nom, i_marques, i_pays = col["product_name"], col["brands"], col["countries_tags"]
    for ligne in lecteur:
        lus += 1
        if len(ligne) <= max(i_nom, i_marques, i_pays) or "en:france" not in ligne[i_pays]:
            continue
        francais += 1
        lp = liste_mots(ligne[i_nom])
        if not lp:
            continue
        mp = frozenset(lp)
        candidats = {j for j in par_mot.get(lp[0], ()) if natures[j][2] == lp[0]}
        meilleurs, taille = [], 0
        for j in candidats:
            m = natures[j][1]
            if m <= mp:
                if len(m) > taille:
                    meilleurs, taille = [j], len(m)
                elif len(m) == taille:
                    meilleurs.append(j)
        if not meilleurs:
            continue
        ranges += 1
        ms = {x.strip() for x in ligne[i_marques].split(",") if x.strip()}
        for j in meilleurs:
            compte[j] += 1
            for m in ms:
                k = cle_marque(m)
                if k:
                    marques[j][k] += 1
        for m in ms:
            graphies[cle_marque(m)][m] += 1
        if lus % 500000 == 0:
            print(f"{lus} lignes, {francais} en France, {ranges} rangées, {time.time() - debut:.0f} s", flush=True)

res = {}
for j, (cle, _, _) in enumerate(natures):
    n = compte.get(j, 0)
    if not n:
        continue
    res[cle] = {
        "n": n,
        "marques": [[graphies[k].most_common(1)[0][0], c] for k, c in marques[j].most_common(40) if c >= 3],
    }
json.dump({"_description": f"Open Food Facts, {time.strftime('%Y-%m-%d')} : {francais} produits vendus en France, "
                           f"{ranges} rangés sous {len(res)} natures du catalogue sur {len(natures)}",
           "natures": res}, open("outils/off/natures_off.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(f"Fini : {lus} lignes, {francais} en France, {ranges} rangées, {len(res)} natures, {time.time() - debut:.0f} s")
print(f"::notice title=Extraction Open Food Facts::{francais} produits en France, {ranges} rangés sous {len(res)} natures sur {len(natures)}")
