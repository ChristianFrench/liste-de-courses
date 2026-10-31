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
]}
ext = json.load(open("outils/off/natures_off.json", encoding="utf-8"))
res = {}
for chemin, v in ext["natures"].items():
    nom = chemin.split("/")[-1]
    marques = [m for m, c in v["marques"] if c >= 3 and cle(m) not in exclues][:10]
    res[nom] = {"n": v["n"], **({"m": marques} if marques else {})}
json.dump({"_description": ext["_description"] + " ; marques d'enseigne retirées (outils/off/natures.py)",
           "natures": dict(sorted(res.items()))}, open("assets/natures_off.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(res), "natures,", sum(1 for x in res.values() if "m" in x), "avec des marques,",
      sum(len(x.get("m", [])) for x in res.values()), "marques en tout")
