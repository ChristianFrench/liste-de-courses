"""Ajoute aux recettes fournies avec la console les 100 recettes Emplettes n° 498 à 597 (21/11/2026, Aristide :
« Pouvez-vous ajouter des recettes à ces 497 recettes »), écrites par Claude : cuisines du monde, plats rapides et
végétariens, entrées, accompagnements, sauces, desserts de saison.
Source : outils/recettes/sources/recettes_498_597_lot1..4.py (lot 4 importe les précédents).
Difficulté (difficulte.py) et critères (criteres.py) posés comme pour les autres.
Usage : python3 outils/recettes/nouvelles_498_597.py   (augmente la version : la console réapplique à l'ouverture).
À relancer après nouvelles_298_497.py, qui ne garde que les recettes avant le n° 298."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'sources'))
from difficulte import difficulte
from criteres import criteres
from nouvelles_298_497 import FOURNIES, slug
from recettes_498_597_lot4 import L
from classement import appliquer

PREMIER = 498


def main():
    src = json.load(open(FOURNIES, encoding='utf-8'))
    recettes = [r for r in src['recettes'] if not r.get('numero') or r['numero'] < PREMIER]
    titres = {r['titre'].lower() for r in recettes}
    ids = {r['id'] for r in recettes}
    for n, r in enumerate(L, PREMIER):
        assert r['titre'].lower() not in titres, r['titre']
        rid = f"emplettes-{slug(r['titre'])}"
        if rid in ids:
            rid += f'-{n}'
        ids.add(rid)
        detail = []
        for d in r['ing']:
            x = dict(nom=d['nom'])
            if d['quantite']: x['quantite'] = d['quantite']
            if d['precision']: x['precision'] = d['precision']
            detail.append(x)
        etapes = r['etapes']
        x = dict(id=rid, numero=n, titre=r['titre'], types=[r['type']],
                 ingredients=[' '.join(y for y in (d.get('quantite', ''), d['nom'], f"({d['precision']})" if d.get('precision') else '') if y) for d in detail],
                 titreIngredients='Ingrédients', detail=detail, etapes=etapes,
                 preparation='\n'.join(f'{i + 1}. {e}' for i, e in enumerate(etapes)),
                 photos=[], pour=f"{r['pour']} personne{'s' if r['pour'] > 1 else ''}", source='Emplettes',
                 tempsPreparation=r['prep'], tempsCuisson=r['cuisson'])
        if r['conseils']: x['conseils'] = r['conseils']
        x['difficulte'] = difficulte(x['titre'])
        x.update(criteres(x))
        recettes.append(x)
    appliquer(recettes)  # types, sous-types et origine (classement.py)
    src['recettes'] = recettes
    src['version'] = src.get('version', 1) + 1
    json.dump(src, open(FOURNIES, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f"{len(recettes)} recettes, version {src['version']}")


if __name__ == '__main__':
    main()
