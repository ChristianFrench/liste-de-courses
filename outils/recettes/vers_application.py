"""Recettes fournies (console) → assets/recettes/recettes.json, version allégée lue par l'application :
titre, types, ingrédients (« nom », « quantité », « précision »), illustration, et le texte : « pour », étapes,
conseils, source ; puis (20/11/2026) temps de préparation et de cuisson (minutes), difficulté, régimes, saisons,
coût, modes de cuisson et occasions, qui servent aux filtres du choix d'une recette. Le mémo (« memo » : true) est écarté.
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
    if r.get('memo'):
        continue
    ing = [{k: v for k, v in d.items() if k in ('nom', 'quantite', 'precision') and v} for d in r.get('detail') or []]
    if not ing:
        ing = [{'nom': x} for x in r.get('ingredients', [])]
    e = {'titre': r['titre'], 'types': r.get('types', []), 'ingredients': ing}
    # 18/11/2026 (Aristide) : le texte de la recette aussi (sans « remarques » ni « texteOrigine », propres à la console).
    for k in ('pour', 'etapes', 'conseils', 'source', 'difficulte', 'regimes', 'saisons', 'cout', 'cuissons', 'occasions'):
        if r.get(k):
            e[k] = r[k]
    # 20/11/2026 : les temps, 0 compris (0 = sans cuisson) ; absents pour les recettes maison.
    for k in ('tempsPreparation', 'tempsCuisson'):
        if isinstance(r.get(k), int):
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
