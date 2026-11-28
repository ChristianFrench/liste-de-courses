"""Convertit les écrans de test/site/ecrans (ECRANS=1 flutter test … test/site/ecrans_site_test.dart) en docs/ecrans/*.webp."""
import glob, os, shutil
from PIL import Image

shutil.rmtree('docs/ecrans', ignore_errors=True)
os.makedirs('docs/ecrans')
for f in sorted(glob.glob('test/site/ecrans/*.png')):
    nom = os.path.splitext(os.path.basename(f))[0]
    Image.open(f).convert('RGB').save(f'docs/ecrans/{nom}.webp', quality=86)
print(len(os.listdir('docs/ecrans')), 'écrans')
