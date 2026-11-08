"""Icônes composées des secteurs au comptoir (08/11/2026, Aristide, variante B) : l'icône du secteur libre-service
réduite à 86 % en haut à gauche, et la sonnette de comptoir (🛎) à 52 % en bas à droite, en Noto 3D.
Écrit assets/pictos/noto3d/<clé>.png (96 px) et lib/donnees/pictos_composes.dart.
Usage : python3 outils/icones_comptoir.py <noto-emoji>/3D/png/128
"""
import sys
from PIL import Image

noto = sys.argv[1]
SONNETTE = '1f6ce'
# clé du secteur au comptoir → emoji de son secteur libre-service
COMPOSES = {
    'boucherie--viandes-et-volailles-au-comptoir': '1f969',  # 🥩 Boucherie libre-service
    'poissonnerie--poissonnerie-au-comptoir': '1f364',       # 🍤 Poissonnerie libre-service
    'fromagerie--fromages-au-comptoir': '1f9c0',             # 🧀 Fromages libre-service
    'charcuterie--charcuterie-au-comptoir': '1f953',         # 🥓 Charcuterie libre-service
    'traiteur--traiteur-au-comptoir': '1f96a',               # 🥪 Traiteur frais
    'volaille--rotisserie': '1f414',                         # 🐔 Volaille libre-service
}

def image(code, cote):
    return Image.open(f'{noto}/emoji_u{code}.png').convert('RGBA').resize((cote, cote), Image.LANCZOS)

for cle, code in COMPOSES.items():
    c = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    c.alpha_composite(image(code, int(256 * 0.86)), (0, 0))
    s = int(256 * 0.52)
    c.alpha_composite(image(SONNETTE, s), (256 - s, 256 - s))
    c.resize((96, 96), Image.LANCZOS).save(f'assets/pictos/noto3d/{cle}.png', optimize=True)

with open('lib/donnees/pictos_composes.dart', 'w') as f:
    f.write('// Fichier produit par outils/icones_comptoir.py : ne pas modifier à la main.\n'
            '// Secteurs au comptoir : icône du libre-service + sonnette (assets/pictos/noto3d/<clé>.png).\n\n'
            'const pictosComposes = <String>{\n' + ''.join(f"  '{c}',\n" for c in COMPOSES) + '};\n')
print(len(COMPOSES), 'icônes composées')
