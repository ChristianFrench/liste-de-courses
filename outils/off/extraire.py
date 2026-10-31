"""Marques des produits Open Food Facts vendus en France, pour chaque nature (produit générique) du catalogue.

Lit l'export complet d'Open Food Facts (CSV, environ 1 Go compressé, lu au fil de l'eau), garde les produits
vendus en France, et range chacun sous la nature du catalogue la plus précise dont tous les mots sont dans son nom
(« Pâte à tartiner chocolat noisette » va à « Pâte à tartiner chocolat », pas à « Pâte »), à condition que le nom
commence comme la nature (« Yaourt à la fraise » n'est pas une fraise, « Jambon -25 % de sel » n'est pas du sel).
Ensuite, parmi les produits d'une nature, on garde ceux de sa catégorie Open Food Facts dominante (la plus précise
que portent au moins 40 % d'entre eux) : « Fraises Tagada » (bonbons) quittent les fraises, les pâtes quittent le pâté. Pour chaque nature :
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

ranges_par_nature = collections.defaultdict(list)  # nature → [(catégories, marques)]
frequence_categories = collections.Counter()  # catégorie → nombre de produits vendus en France
graphies = collections.defaultdict(collections.Counter)  # clé de marque → graphies
# Produits sans nature : regroupés par leurs 1 et 2 premiers mots, pour proposer des natures nouvelles.
orphelins = collections.Counter()  # préfixe → nombre de produits
orph_cats = collections.defaultdict(collections.Counter)  # préfixe → catégories
orph_marques = collections.defaultdict(collections.Counter)  # préfixe → marques
orph_graphies = collections.defaultdict(collections.Counter)  # préfixe → noms tels qu'écrits
orph_debut_marque = collections.Counter()  # préfixe → produits dont le nom commence par la marque
lus = francais = ranges = 0
debut = time.time()
csv.field_size_limit(1 << 30)
req = urllib.request.Request(EXPORT, headers={"User-Agent": "ListeDeCourses/0.7 (catalogue)"})
with urllib.request.urlopen(req, timeout=300) as flux:
    texte = io.TextIOWrapper(gzip.GzipFile(fileobj=flux), encoding="utf-8", errors="replace", newline="")
    lecteur = csv.reader(texte, delimiter="\t", quoting=csv.QUOTE_NONE)
    entete = next(lecteur)
    col = {n: i for i, n in enumerate(entete)}
    i_nom, i_marques, i_pays, i_cat = col["product_name"], col["brands"], col["countries_tags"], col["categories_tags"]
    for ligne in lecteur:
        lus += 1
        if len(ligne) <= max(i_nom, i_marques, i_pays, i_cat) or "en:france" not in ligne[i_pays]:
            continue
        francais += 1
        cats = tuple(sorted({c for c in ligne[i_cat].split(",") if c}))
        frequence_categories.update(cats)
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
            ms = {x.strip() for x in ligne[i_marques].split(",") if x.strip()}
            cles_m = {cle_marque(m) for m in ms}
            brut = [m for m in re.split(r"[^\w'-]+", ligne[i_nom].lower()) if m]
            for k in (1, 2):
                if len(lp) < k:
                    break
                pre = " ".join(lp[:k])
                orphelins[pre] += 1
                orph_cats[pre].update(cats)
                orph_marques[pre].update(cle_marque(m) for m in ms)
                if cle_marque(" ".join(lp[:k])) in cles_m or cle_marque(lp[0]) in cles_m:
                    orph_debut_marque[pre] += 1
                if len(orph_graphies[pre]) < 200 or " ".join(brut[:k + 2]) in orph_graphies[pre]:
                    orph_graphies[pre][" ".join(brut[:k + 2])] += 1
            for m in ms:
                graphies[cle_marque(m)][m] += 1
            continue
        ranges += 1
        ms = {x.strip() for x in ligne[i_marques].split(",") if x.strip()}
        cles = tuple({cle_marque(m) for m in ms} - {""})
        for j in meilleurs:
            ranges_par_nature[j].append((cats, cles))
        for m in ms:
            graphies[cle_marque(m)][m] += 1
        if lus % 500000 == 0:
            print(f"{lus} lignes, {francais} en France, {ranges} rangées, {time.time() - debut:.0f} s", flush=True)

res = {}
for j, (cle, _, _) in enumerate(natures):
    produits = ranges_par_nature.get(j)
    if not produits:
        continue
    # Catégorie dominante : portée par au moins 40 % des produits classés ; la plus précise (la plus rare en France).
    avec = [p for p in produits if p[0]]
    parts = collections.Counter(c for p in avec for c in p[0])
    dominantes = [c for c, k in parts.items() if avec and k >= 0.4 * len(avec)]
    categorie = min(dominantes, key=lambda c: frequence_categories[c]) if dominantes else None
    if categorie:
        produits = [p for p in produits if not p[0] or categorie in p[0]]
    marques = collections.Counter(k for p in produits for k in p[1])
    res[cle] = {
        "n": len(produits),
        "categorie": categorie,
        "marques": [[graphies[k].most_common(1)[0][0], c] for k, c in marques.most_common(40) if c >= 3],
    }
json.dump({"_description": f"Open Food Facts, {time.strftime('%Y-%m-%d')} : {francais} produits vendus en France, "
                           f"{ranges} rangés sous {len(res)} natures du catalogue sur {len(natures)}",
           "natures": res}, open("outils/off/natures_off.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
# Catégorie de chaque nature rangée, pour proposer un rayon et un secteur aux natures nouvelles.
secteur_par_categorie = collections.defaultdict(collections.Counter)
for cle, v in res.items():
    if v["categorie"]:
        secteur_par_categorie[v["categorie"]]["/".join(cle.split("/")[:2])] += v["n"]
candidats = {}
for pre, n in orphelins.items():
    if n < 200:
        continue
    cats = orph_cats[pre]
    # catégorie la plus précise portée par au moins 30 % des produits
    dom = [c for c, k in cats.items() if k >= 0.3 * n]
    categorie = min(dom, key=lambda c: frequence_categories[c]) if dom else None
    secteurs = collections.Counter()
    for c, k in cats.most_common(30):
        for sec, w in secteur_par_categorie.get(c, {}).items():
            secteurs[sec] += k * w / max(1, frequence_categories[c])
    candidats[pre] = {
        "n": n,
        "noms": [g for g, _ in orph_graphies[pre].most_common(3)],
        "categorie": categorie,
        "categories": [[c, k] for c, k in cats.most_common(4)],
        "secteur": secteurs.most_common(1)[0][0] if secteurs else None,
        "marques": [graphies[k].most_common(1)[0][0] for k, _ in orph_marques[pre].most_common(6) if k and graphies[k]],
        "part_marque": round(orph_debut_marque[pre] / n, 2),
    }
json.dump(candidats, open("outils/off/candidats_off.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(f"::notice title=Natures candidates::{len(candidats)} groupes d'au moins 200 produits sans nature")
print(f"Fini : {lus} lignes, {francais} en France, {ranges} rangées, {len(res)} natures, {time.time() - debut:.0f} s")
print(f"::notice title=Extraction Open Food Facts::{francais} produits en France, {ranges} rangés sous {len(res)} natures sur {len(natures)}")
