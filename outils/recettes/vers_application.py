"""Recettes fournies (console) → assets/recettes/recettes.json, version allégée lue par l'application :
titre, types, ingrédients (« nom », « quantité », « précision »), illustration, et le texte : « pour », étapes,
conseils, source.
Les illustrations sont réduites en 720 × 480 WebP (choix d'Aristide du 17/11/2026) dans assets/recettes/illustrations/.
Usage : python3 outils/recettes/vers_application.py"""
import json, os
from PIL import Image
D = 'outils/recettes/illustrations'
A = 'assets/recettes/illustrations'
src = json.load(open(f'{D}/recettes-fournies.json', encoding='utf-8'))
images = json.load(open(f'{D}/illustrations.json', encoding='utf-8'))
os.makedirs(A, exist_ok=True)
garder = set()
out = []
for r in sorted(src['recettes'], key=lambda r: r['titre'].lower()):
    ing = [{k: v for k, v in d.items() if k in ('nom', 'quantite', 'precision') and v} for d in r.get('detail') or []]
    if not ing:
        ing = [{'nom': x} for x in r.get('ingredients', [])]
    e = {'titre': r['titre'], 'types': r.get('types', []), 'ingredients': ing}
    # 18/11/2026 (Aristide) : le texte de la recette aussi (sans « remarques » ni « texteOrigine », propres à la console).
    for k in ('pour', 'etapes', 'conseils', 'source'):
        if r.get(k):
            e[k] = r[k]
    f = images.get(r.get('id'))
    if f and os.path.exists(f'{D}/{f}'):
        nom = os.path.splitext(f)[0] + '.webp'
        if not os.path.exists(f'{A}/{nom}') or os.path.getmtime(f'{A}/{nom}') < os.path.getmtime(f'{D}/{f}'):
            Image.open(f'{D}/{f}').convert('RGB').resize((720, 480), Image.LANCZOS).save(f'{A}/{nom}', 'WEBP', quality=80, method=6)
        e['image'] = nom
        garder.add(nom)
    out.append(e)
for x in os.listdir(A):
    if x not in garder:
        os.remove(f'{A}/{x}')
json.dump({'version': src.get('version', 1), 'recettes': out}, open('assets/recettes/recettes.json', 'w', encoding='utf-8'),
          ensure_ascii=False, separators=(',', ':'))
print(len(out), 'recettes,', len(garder), 'illustrations')
