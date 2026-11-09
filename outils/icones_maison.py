"""Icônes « maison » des rayons (08/11/2026, Aristide : 32 images générées dans le style Noto 3D, 256 px).
Les sources sont dans outils/icones_maison/<nom du rayon>.png ; chaque image est rognée de ses marges vides,
centrée dans 96 × 96 (comme les emojis) et écrite dans assets/pictos/maison/<clé>.png. Elles remplacent l'icône
Noto 3D de même clé ; liste dans lib/donnees/pictos_maison.dart.
Usage : python3 outils/icones_maison.py
"""
import glob, os, re, unicodedata
from PIL import Image

def cle(nom):
    t = unicodedata.normalize('NFD', nom.lower().replace('œ', 'oe').replace('æ', 'ae'))
    t = ''.join(c for c in t if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', '-', t).strip('-')

os.makedirs('assets/pictos/maison', exist_ok=True)
cles = []
# Rayons et univers : outils/icones_maison/<nom>.png ; secteurs (08/11/2026, 130 images d'Aristide) :
# outils/icones_maison/secteurs/<clé du rayon>/<clé du secteur>.png → clé « <rayon>--<secteur> ».
sources = [(cle(os.path.basename(f)[:-4]), f) for f in sorted(glob.glob('outils/icones_maison/*.png'))]
for f in sorted(glob.glob('outils/icones_maison/secteurs/*/*.png')):
    r, s = cle(os.path.basename(os.path.dirname(f))), cle(os.path.basename(f)[:-4])
    sources.append((f'{r}--{s}', f))
    # « Entretien / Droguerie » d'origine, « Entretien et Droguerie » depuis la version 2 du catalogue.
    if r == 'entretien-et-droguerie':
        sources.append((f'entretien-droguerie--{s}', f))
for c, f in sources:
    im = Image.open(f).convert('RGBA')
    boite = im.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
    if boite:
        im = im.crop(boite)
    utile = 88
    e = utile / max(im.size)
    im = im.resize((max(1, round(im.width * e)), max(1, round(im.height * e))), Image.LANCZOS)
    carre = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    carre.alpha_composite(im, ((96 - im.width) // 2, (96 - im.height) // 2))
    carre.save(f'assets/pictos/maison/{c}.png', optimize=True)
    cles.append(c)
with open('lib/donnees/pictos_maison.dart', 'w') as f:
    f.write('// Fichier produit par outils/icones_maison.py : ne pas modifier à la main.\n'
            '// Icônes « maison » des rayons (assets/pictos/maison/<clé>.png), prioritaires sur Noto 3D.\n\n'
            'const pictosMaison = <String>{\n' + ''.join(f"  '{c}',\n" for c in cles) + '};\n')
print(len(cles), 'icônes maison :', ', '.join(cles))

# Icônes de l'interface (09/11/2026, 55 images d'Aristide) : outils/icones_maison/ihm/<nom Noto>.png remplacent
# assets/icones/noto3d/<nom>.png (96 × 96, rognées, sans marge comme les Noto). À relancer après outils/icones_3d.py.
n = 0
for f in sorted(glob.glob('outils/icones_maison/ihm/*.png')):
    im = Image.open(f).convert('RGBA')
    boite = im.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
    if boite:
        im = im.crop(boite)
    e = 96 / max(im.size)
    im = im.resize((max(1, round(im.width * e)), max(1, round(im.height * e))), Image.LANCZOS)
    carre = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    carre.alpha_composite(im, ((96 - im.width) // 2, (96 - im.height) // 2))
    carre.save(f'assets/icones/noto3d/{os.path.basename(f)}', optimize=True)
    n += 1
print(n, "icônes de l'interface")
