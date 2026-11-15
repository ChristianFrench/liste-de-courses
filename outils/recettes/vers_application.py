"""Recettes fournies (console) → assets/recettes/recettes.json, version allégée lue par l'application :
titre, types et ingrédients (« nom », « quantité », « précision »). Usage : python3 outils/recettes/vers_application.py"""
import json
src = json.load(open('outils/recettes/illustrations/recettes-fournies.json', encoding='utf-8'))
out = []
for r in sorted(src['recettes'], key=lambda r: r['titre'].lower()):
    ing = [{k: v for k, v in d.items() if k in ('nom', 'quantite', 'precision') and v} for d in r.get('detail') or []]
    if not ing:
        ing = [{'nom': x} for x in r.get('ingredients', [])]
    out.append({'titre': r['titre'], 'types': r.get('types', []), 'ingredients': ing})
json.dump({'version': src.get('version', 1), 'recettes': out}, open('assets/recettes/recettes.json', 'w', encoding='utf-8'),
          ensure_ascii=False, separators=(',', ':'))
print(len(out), 'recettes')
