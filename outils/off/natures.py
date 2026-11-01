"""Écrit assets/natures_off.json (lu par l'application) à partir de l'extraction Open Food Facts
(outils/off/natures_off.json, écrite par extraire.py) : pour chaque nature du catalogue, sa popularité (nombre de
produits vendus en France) et au plus 10 marques présentes dans au moins 3 produits. Les marques d'enseigne
(U, Carrefour, Marque Repère, Pâturages…) en sont retirées : l'application les propose déjà selon le magasin."""
import json, re, unicodedata


def cle(m):
    return re.sub(r"[^a-z0-9]", "", "".join(c for c in unicodedata.normalize("NFD", m.lower()) if unicodedata.category(c) != "Mn"))


enseignes = json.load(open("assets/marques_distributeur.json", encoding="utf-8"))["enseignes"]
exclues = {cle(e) for e in enseignes} | {cle(m["marque"]) for l in enseignes.values() for m in l}
# Enseignes et marques de distributeur absentes de marques_distributeur.json, et non-marques fréquentes.
exclues |= {cle(x) for x in [
    "U", "U Bio", "Super U", "Hyper U", "Système U", "Carrefour Bio", "Carrefour Classic", "Carrefour Extra", "Carrefour Sensation",
    "Carrefour Selection", "Auchan Bio", "Monoprix Bio", "Monoprix Gourmet", "E.Leclerc", "Leclerc", "Intermarché", "Lidl",
    "Aldi", "Leader Price", "Franprix", "Netto", "Cora", "Match", "Simply", "Casino Bio", "Picard", "Thiriet", "Bio Village",
    "Marque Repère", "Envia", "Délisse", "Pâturages", "Solevita", "Milbona", "Chabrior", "Deliciously Different",
    "Nos Régions ont du Talent", "Reflets de France", "Saveurs de nos régions", "Eco+", "Top Budget", "Tous les jours",
    "Simpl", "Ma Vie Sans Gluten", "Fair", "La Vie Claire", "Biocoop", "Naturalia",
    "Bio c Bon", "Marks & Spencer", "Delhaize", "Belle France", "Grand Jury", "Cmi", "Sans marque", "Generique", "Aucune",
    "Groupe Casino", "Groupe Carrefour", "CMI (Carrefour Marchandises Internationales)", "DLP (Distribution Leader Price)",
    "Milsani", "Milsa", "Prix Mini", "Grand Frais", "Trader Joe's", "Migros", "Hema", "Auchan Production", "Monoprix Gourmet",
    "Casino Délices", "Leader Price Bio", "Cora Bio", "Netto Bio", "Lidl Bio", "Bio Organic", "Combino", "Crownfield",
    "Freshona", "Cien", "Kania", "Belbake", "Gelatelli", "Chef Select", "Deluxe", "Pilos", "Snack Day", "Sondey",
    "Fin Carré", "Lupilu", "W5", "Solent", "Ocean Sea", "Nixe", "Alesto", "Vitasia", "Italiamo", "Duc de Coeur",
    # hors alimentaire (Open Beauty, Products et Pet Food Facts) : marques d'enseigne et groupes industriels
    "Cosmia", "Auchan Baby", "Kids", "Unilever", "Henkel", "Groupe SEB France", "L'Oreal Consumer products", "Up2Fashion",
    "Les Cosmétiques Design Paris", "Better life", "Inventiv", "Nectar of Beauty", "Bio naïa",
]}
# Graphies accentuées perdues par l'extraction du 31/10/2026 (corrigé depuis dans extraire.py).
accents = {"President": "Président", "Cote d'Or": "Côte d'Or", "Nestle": "Nestlé", "Herta": "Herta",
           "kiabi": "Kiabi", "Van|Rysel": "Van Rysel", "royal canin": "Royal Canin", "handy bag": "Handy Bag"}
ext = json.load(open("outils/off/natures_off.json", encoding="utf-8"))
# Bases non alimentaires (extraire.py avec BASE=obf, opf, opff), ajoutées à Open Food Facts.
sources = [ext["natures"]]
for b in ("obf", "opf", "opff"):
    try:
        sources.append(json.load(open(f"outils/off/natures_{b}.json", encoding="utf-8"))["natures"])
    except FileNotFoundError:
        pass
nombres, comptes = {}, {}
for natures in sources:
    for chemin, v in natures.items():
        nom = chemin.split("/")[-1]
        nombres[nom] = nombres.get(nom, 0) + v["n"]
        c = comptes.setdefault(nom, {})
        # Fruits et légumes frais : Open Food Facts n'y trouve presque que des conserves, épices et soupes
        # (« Ail » → Ducros, « Haricots verts » → Bonduelle) ; pas de marques prises (01/11/2026).
        if chemin.startswith("Fruits et légumes/"):
            continue
        for m, k in v["marques"]:
            m = accents.get(m, m)
            c[m] = c.get(m, 0) + k
res = {}
for nom, n in nombres.items():
    marques = [m for m, k in sorted(comptes[nom].items(), key=lambda x: -x[1]) if k >= 3 and cle(m) not in exclues][:10]
    res[nom] = {"n": n, **({"m": marques} if marques else {})}
json.dump({"_description": ext["_description"] + " ; plus Open Beauty, Products et Pet Food Facts ; marques d'enseigne retirées (outils/off/natures.py)",
           "natures": dict(sorted(res.items()))}, open("assets/natures_off.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(res), "natures,", sum(1 for x in res.values() if "m" in x), "avec des marques,",
      sum(len(x.get("m", [])) for x in res.values()), "marques en tout")
