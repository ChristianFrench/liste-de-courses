"""Assemble les images de test/site/images en docs/animation.webp (jouée une fois, fond transparent)."""
import glob, os, shutil
from PIL import Image

images = sorted(glob.glob('test/site/images/*.png'))
cadres = [Image.open(f).convert('RGBA') for f in images]
duree = [50] * len(cadres)  # 20 images par seconde
cadres[0].save('docs/animation.webp', save_all=True, append_images=cadres[1:], duration=duree, loop=1,
               quality=80, method=4, lossless=False)
print(len(cadres), 'images,', os.path.getsize('docs/animation.webp') // 1024, 'Ko')
shutil.rmtree('test/site/images')
