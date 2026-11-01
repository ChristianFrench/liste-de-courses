"""Icônes et images de rayons/secteurs en relief, à partir des emojis Noto 3D (Google, SIL OFL) et Fluent 3D (Microsoft, MIT).
- icônes : assets/icones/<famille>/<nom Noto>.png (outils/icones_noto.json) ;
- rayons et secteurs : assets/pictos/<famille>/<clé>.png (outils/pictos_emoji.txt : « clé emoji » par ligne).
Usage : python3 outils/icones_3d.py <noto-emoji>/3D/png/128 <fluent-emoji-3d>/package/assets <iconify-noto>/package/chars.json
(noto-emoji : dépôt github.com/googlefonts/noto-emoji ; fluent : npm @lobehub/fluent-emoji-3d ; chars : npm @iconify-json/noto)
"""
import json, os, sys
from PIL import Image

noto3d, fluent, chars = sys.argv[1], sys.argv[2], json.load(open(sys.argv[3]))
codes = {}
for code, nom in chars.items():
    codes.setdefault(nom, []).append(code)

def source(famille, code):
    """Fichier de l'emoji (code hexadécimal « 1f6d2 » ou « 1f1eb-1f1f7 »)."""
    for c in (code, code.replace('-fe0f', ''), code + '-fe0f'):
        f = os.path.join(noto3d, 'emoji_u' + c.replace('-', '_') + '.png') if famille == 'noto3d' else os.path.join(fluent, c + '.webp')
        if os.path.exists(f):
            return f
    raise SystemExit(f'{famille} : pas d\'image pour {code}')

def ecrire(famille, code, sortie):
    os.makedirs(os.path.dirname(sortie), exist_ok=True)
    Image.open(source(famille, code)).convert('RGBA').resize((96, 96), Image.LANCZOS).save(sortie, optimize=True)

carte = json.load(open('outils/icones_noto.json'))
pictos = [l.split(' ', 1) for l in open('outils/pictos_emoji.txt', encoding='utf8').read().strip().split('\n')]
for famille in ('noto3d', 'fluent3d'):
    for nom in sorted(set(carte.values())):
        ecrire(famille, codes[nom][0], f'assets/icones/{famille}/{nom}.png')
    for cle, emoji in pictos:
        ecrire(famille, '-'.join('%x' % ord(c) for c in emoji if ord(c) != 0xfe0f), f'assets/pictos/{famille}/{cle}.png')
with open('lib/donnees/pictos_emoji.dart', 'w') as f:
    f.write('// Fichier produit par outils/icones_3d.py : ne pas modifier à la main.\n'
            '// Rayons et secteurs qui ont leur emoji dans chaque famille d\'icônes (assets/pictos/<famille>/<clé>.png).\n\n'
            'const pictosEmoji = <String>{\n' + ''.join(f"  '{c}',\n" for c, _ in pictos) + '};\n')
print(len(set(carte.values())), 'icônes,', len(pictos), 'rayons et secteurs')

# Correspondance icône Material → nom de fichier, lue par lib/composants/icone.dart.
with open('lib/composants/icones_noto.dart', 'w') as f:
    f.write('// Fichier produit par outils/icones_3d.py : ne pas modifier à la main.\n'
            "import 'package:flutter/material.dart';\n\n"
            '/// Icône Material → image en couleur (assets/icones/<famille>/<nom>.png).\n'
            'final iconesNoto = <IconData, String>{\n' + ''.join(f'  Icons.{m}: \'{n}\',\n' for m, n in carte.items()) + '};\n')
