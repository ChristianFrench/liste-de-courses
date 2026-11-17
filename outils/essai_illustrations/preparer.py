# Prépare les illustrations des recettes en trois tailles (WebP, qualité 80) pour l'APK d'essai.
# Source : outils/recettes/illustrations/*.jpg (768 × 512). La taille 1080 est agrandie : elle sert à mesurer
# le poids et le temps, pas la netteté (une image ne peut pas être plus fine que sa source).
import json, os, sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
tailles = {'480': (480, 320), '720': (720, 480), '1080': (1080, 720)}
noms, poids = [], {k: 0 for k in tailles}
for f in sorted(os.listdir(src)):
    if not f.lower().endswith('.jpg'):
        continue
    nom = f[:-4]
    im = Image.open(os.path.join(src, f)).convert('RGB')
    for k, t in tailles.items():
        os.makedirs(os.path.join(dst, 'i' + k), exist_ok=True)
        p = os.path.join(dst, 'i' + k, nom + '.webp')
        im.resize(t, Image.LANCZOS).save(p, 'WEBP', quality=80, method=6)
        poids[k] += os.path.getsize(p)
    noms.append(nom)
json.dump({'noms': noms, 'poids': poids}, open(os.path.join(dst, 'liste.json'), 'w'))
print(len(noms), 'illustrations', {k: f'{v / 1e6:.1f} Mo' for k, v in poids.items()})
