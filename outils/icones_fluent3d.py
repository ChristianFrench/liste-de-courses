"""Icônes Fluent 3D (Microsoft, licence MIT) à la place des Noto : mêmes noms de fichiers dans assets/icones/fluent3d/ (au choix dans Paramètres › Apparence).
Usage : npm pack @lobehub/fluent-emoji-3d @iconify-json/noto, extraire, puis :
  python3 outils/icones_fluent3d.py <fluent-3d>/package/assets <noto>/package/chars.json
"""
import json, os, sys
from PIL import Image

webp, chars = sys.argv[1], json.load(open(sys.argv[2]))
codes = {}
for code, nom in chars.items():
    codes.setdefault(nom, []).append(code)
carte = json.load(open('outils/icones_noto.json'))
fichiers = set(os.listdir(webp))
for nom in sorted(set(carte.values())):
    code = next(c for k in codes[nom] for c in (k, k.replace('-fe0f', ''), k + '-fe0f') if c + '.webp' in fichiers)
    Image.open(os.path.join(webp, code + '.webp')).convert('RGBA').resize((128, 128), Image.LANCZOS).save(f'assets/icones/fluent3d/{nom}.png', optimize=True)
print(len(set(carte.values())), 'icônes')
