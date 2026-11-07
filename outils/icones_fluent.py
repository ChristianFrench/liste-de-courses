"""Bibliothèque Fluent 3D (Microsoft, licence MIT), en plus de la bibliothèque Noto 3D (07/11/2026, Aristide :
« des icônes en libre droit du même style, d'origines diverses »).
Retient, comme pour Noto 3D, les emojis des groupes Alimentation, Animaux et nature, Objets, Activités, Lieux dont le nom
français croise le catalogue type (tous ceux de l'alimentation), et les écrit en WebP 96 px :
assets/pictos/fluent3d/<nom>.webp, clé « fluent--<nom> » ; liste dans lib/donnees/pictos_fluent.dart.
Usage : python3 outils/icones_fluent.py <fluent-emoji-3d>/package/assets <cldr>
(fluent : npm @lobehub/fluent-emoji-3d ; cldr : annotations_fr.xml, derived_fr.xml et emoji-test.txt d'Unicode)
"""
import json, os, re, sys, unicodedata, xml.etree.ElementTree as ET
from PIL import Image

FLUENT, CLDR = sys.argv[1], sys.argv[2]

def norm(t):
    t = unicodedata.normalize('NFD', t.lower().replace('œ', 'oe').replace('æ', 'ae'))
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')

def sing(w):
    if len(w) > 3 and w.endswith('x') and w[-2] in 'au': return w[:-1]
    if len(w) > 3 and w.endswith('s'): return w[:-1]
    return w

STOP = set('de du des la le les un une et a au aux en pour avec sans d l par sur ou petit petite grand grande moyen blanc blanche noir noire rouge vert verte bleu bleue jaune rose violet marron gris plein haut bas autre autres'.split())
def mots(t): return [sing(w) for w in re.findall(r'[a-z0-9]+', norm(t)) if w not in STOP and len(w) > 2]
def slug(t): return re.sub(r'[^a-z0-9]+', '-', norm(t)).strip('-')

noms = {}
for f in ('annotations_fr.xml', 'derived_fr.xml'):
    for a in ET.parse(os.path.join(CLDR, f)).getroot().iter('annotation'):
        if a.get('type') == 'tts' and a.text: noms[a.get('cp')] = a.text

cat = json.load(open('assets/catalogue_type.json'))
termes = set()
for r in cat['rayons']:
    termes.update(mots(r['nom']))
    for s in r.get('secteurs', []):
        termes.update(mots(s['nom']))
        for p in s.get('produits', []):
            termes.update(mots(p['nom'])[:1])

GARDES = ('Food & Drink', 'Animals & Nature', 'Objects', 'Activities', 'Travel & Places')
presents = {f[:-5] for f in os.listdir(FLUENT) if f.endswith('.webp')}
sortie = 'assets/pictos/fluent3d'
os.makedirs(sortie, exist_ok=True)
cles, g = [], ''
for l in open(os.path.join(CLDR, 'emoji-test.txt'), encoding='utf-8'):
    if l.startswith('# group:'): g = l.split(':', 1)[1].strip()
    if l.startswith('#') or 'fully-qualified' not in l or g not in GARDES: continue
    code = '-'.join(x.lower() for x in l.split(';')[0].split())
    cp = ''.join(chr(int(x, 16)) for x in code.split('-'))
    fichier = code if code in presents else code.replace('-fe0f', '')
    nom = noms.get(cp) or noms.get(cp.replace('️', ''))
    if fichier not in presents or not nom: continue
    if g != 'Food & Drink' and not set(mots(nom)) & termes: continue
    cle = slug(nom)
    if cle in cles: continue
    cles.append(cle)
    Image.open(os.path.join(FLUENT, fichier + '.webp')).convert('RGBA').resize((96, 96), Image.LANCZOS) \
        .save(os.path.join(sortie, cle + '.webp'), 'WEBP', quality=88, method=6)
with open('lib/donnees/pictos_fluent.dart', 'w') as f:
    f.write('// Fichier produit par outils/icones_fluent.py : ne pas modifier à la main.\n'
            '// Bibliothèque Fluent 3D (Microsoft, licence MIT) : assets/pictos/fluent3d/<nom>.webp, clé « fluent--<nom> ».\n\n'
            'const pictosFluent = <String>{\n' + ''.join(f"  'fluent--{c}',\n" for c in sorted(cles)) + '};\n')
print(len(cles), 'images Fluent 3D')
