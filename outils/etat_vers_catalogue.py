"""Reconstruit assets/catalogue_type.json (catalogue type livré avec l'application et avec
« Gestion du catalogue ») à partir de outils/catalogue-edite.json, l'état de l'éditeur de catalogue.
Marques relevées dans les listes envoyées par mail : outils/marques-listes.json (facultatif).
Formats de vente par secteur et par produit : outils/formats.json (facultatif).
Lancé à la main par le fil de génération ; rien à faire pour le maître d'ouvrage."""
import json, pathlib

ICI = pathlib.Path(__file__).parent
etat = json.loads((ICI / "catalogue-edite.json").read_text(encoding="utf-8"))
f = ICI / "marques-listes.json"
marques = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {}
f = ICI / "formats.json"
formats = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {}

rayons = []
for i, r in enumerate(etat["rayons"], 1):
    secteurs = []
    for j, s in enumerate(r["secteurs"], 1):
        fs = formats.get(r["nom"], {}).get(s["nom"], {})
        produits = []
        for p in s["produits"]:
            q = {"nom": p["nom"], "taille": max(p["taille"], s["taille"])}
            if p.get("listes"): q["listes"] = p["listes"]
            if marques.get(p["nom"]): q["marques"] = marques[p["nom"]]
            if fs.get("produits", {}).get(p["nom"]): q["formats"] = fs["produits"][p["nom"]]
            produits.append(q)
        sec = {"nom": s["nom"], "ordre": j, "taille": s["taille"]}
        if fs.get("formats"): sec["formats"] = fs["formats"]
        sec["produits"] = produits
        secteurs.append(sec)
    rayons.append({"nom": r["nom"], "ordre": i, "secteurs": secteurs})

ref = {"_description": "Catalogue type d'un magasin français. taille : 1 proximité, 2 supermarché, 3 hypermarché. "
                       "listes : nombre de fois où le produit figure dans les listes du foyer. "
                       "formats : formats de vente proposés (packagings).",
       "tailles": {"1": "Proximité", "2": "Supermarché", "3": "Hypermarché"}, "rayons": rayons}
(ICI.parent / "assets" / "catalogue_type.json").write_text(json.dumps(ref, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(rayons), "rayons,", sum(len(r["secteurs"]) for r in rayons), "secteurs,",
      sum(len(s["produits"]) for r in rayons for s in r["secteurs"]), "produits")
