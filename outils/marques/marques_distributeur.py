"""Construit assets/marques_distributeur.json depuis outils/marques/MDD.txt (Aristide, 28/10/2026) :
« Enseigne ; catégorie ; marque » par ligne. Chaque catégorie vise des rayons (« Crèmerie ») ou des secteurs
(« Cave/Vins ») du catalogue ; « * » : tous les secteurs (premier prix, bio, premium…).
Lancer : python3 outils/marques/marques_distributeur.py
"""
import json
import pathlib

ICI = pathlib.Path(__file__).parent
RACINE = ICI.parent.parent

CIBLES = {
    'Petit-déjeuner / Biscuits': ['Petit-déjeuner', 'Biscuits et sucré/Biscuits et gâteaux'],
    'Jus de fruits': ['Eaux et boissons sans alcool/Jus de fruits'],
    'Produits laitiers': ['Crèmerie', 'Fromagerie'],
    'Charcuterie': ['Charcuterie'],
    'Traiteur': ['Traiteur'],
    'Bébé': ['Bébé'],
    'Hygiène / Santé': ['Hygiène', 'Parfumerie et soins', 'Parapharmacie'],
    'Hygiène / Entretien': ['Hygiène', 'Parfumerie et soins', 'Entretien / Droguerie'],
    'Hygiène / Beauté': ['Hygiène', 'Parfumerie et soins'],
    'Entretien': ['Entretien / Droguerie'],
    'Animaux': ['Animaux'],
    'Conserves de légumes': ['Épicerie salée/Conserves'],
    'Café': ['Petit-déjeuner/Café'],
    'Vins': ['Cave/Vins'],
    'Produits du monde': ['Cuisine du monde'],
    'Épicerie salée': ['Épicerie salée'],
    'Premier prix': ['*'],
    'Bio': ['*'],
    'Produits premium': ['*'],
    'Produits régionaux': ['*'],
    'Produits végétaux': ['*'],
    'Produits festifs': ['*'],
}

catalogue = json.loads((RACINE / 'assets/catalogue_type.json').read_text())
rayons = {r['nom'] for r in catalogue['rayons']}
secteurs = {f"{r['nom']}/{s['nom']}" for r in catalogue['rayons'] for s in r['secteurs']}
enseignes: dict[str, list[dict]] = {}
for ligne in (ICI / 'MDD.txt').read_text().splitlines():
    if not ligne.strip():
        continue
    enseigne, categorie, marque = (x.strip() for x in ligne.split(';'))
    cibles = CIBLES[categorie]
    for c in cibles:
        assert c == '*' or c in rayons or c in secteurs, c
    enseignes.setdefault(enseigne, []).append({'marque': marque, 'categorie': categorie, 'cibles': cibles})
(RACINE / 'assets/marques_distributeur.json').write_text(json.dumps({'enseignes': enseignes}, ensure_ascii=False, indent=1) + '\n')
print(len(enseignes), 'enseignes,', sum(len(l) for l in enseignes.values()), 'marques')
