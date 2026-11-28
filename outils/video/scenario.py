"""Vidéo d'Emplettes (1.0, 27/11/2026) : minutage, piste son (voix Piper + musique) et timeline pour video.html.
Usage : python3 outils/video/scenario.py <dossier des voix .wav> <dossier de sortie>
Les écrans viennent de test/video/ecrans (VIDEO=1 flutter test --update-goldens test/video/ecrans_video_test.dart).
"""
import json, os, sys, wave
import numpy as np

VOIX, SORTIE = sys.argv[1], sys.argv[2]
os.makedirs(SORTIE, exist_ok=True)
TAUX = 44100

def lire_wav(nom):
    with wave.open(os.path.join(VOIX, nom + '.wav')) as w:
        n, taux = w.getnframes(), w.getframerate()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768
    # rééchantillonnage simple vers 44,1 kHz
    t = np.linspace(0, len(x) / taux, int(len(x) * TAUX / taux), endpoint=False)
    return np.interp(t, np.arange(len(x)) / taux, x)

def tel(img, gestes=(), images=(), poids=1.0, surligne=None):
    return dict(type='tel', img=img, gestes=list(gestes), images=list(images), poids=poids, surligne=surligne)

def tap(t, x, y, double=False):
    return dict(t=t, type='double' if double else 'tap', x=x, y=y)

# (voix, sous-titre, scènes, durée minimale)
# 27/11/2026 (Aristide : « moins didactique, plus commercial ») : vidéo 1.0, les recettes d'abord, sans parties.
SEGMENTS = [
    ('00', 'Les courses du foyer, de la recette au chariot.', [dict(type='anim', poids=1)], 13.5),
    ('01', 'Près de 600 recettes faciles, chacune avec sa photo.',
     [tel('v21 Recettes', [tap(1.2, 195, 181)], [(1.6, 'v21 Recherche')], poids=1),
      tel('v21 Recherche', [tap(1.0, 195, 417)], [(1.3, 'v22 Fiche')], poids=0.9)], 0),
    ('02', 'On coche ce qui manque. C\'est noté.', [tel('v22 Fiche', [tap(1.4, 195, 704)], [(1.7, 'v22 Notee')])], 4.6),
    ('03', 'Un appui : les ingrédients se rangent tout seuls, rayon par rayon.',
     [tel('v23 Recette-choisie', [tap(1.6, 195, 254)], [(1.9, 'v23 Ingredients')], poids=0.45),
      tel('v23 Ingredients', [tap(1.3, 195, 726)], [(1.6, 'v23 Ajoutes')], poids=0.35),
      tel('v23 Ajoutes', poids=0.2)], 0),
    ('04', 'Trois lettres suffisent : 2\u00a0500 produits, 2\u00a0000 marques.',
     [tel('v03 Remplir', [tap(0.5, 200, 168)], [(1.0, 'v03 Recherche-c'), (1.5, 'v03 Recherche-ca'), (2.0, 'v03 Recherche-cam')], poids=1.3),
      tel('v04 Camembert-range', poids=0.7, surligne=262)], 0),
    ('05', 'Toute la famille, la même liste.',
     [dict(type='deux', g='v07 Yaourts-arrives', d='v07 Yaourts-arrives', lg='Thomas', ld='Claire', surligne_g=262)], 0),
    ('06', 'Au magasin, la liste suit vos allées.',
     [tel('v10 En-magasin', [tap(2.2, 25, 316)], [(2.4, 'v10 En-magasin-coche')])], 0),
    ('07', 'Votre parcours s\'apprend tout seul.', [tel('v16 Parcours')], 0),
    ('08', 'Le ticket est gardé, la recette vous attend.',
     [tel('v13 Terminer', poids=1), tel('v22 Fiche', poids=1)], 0),
    ('09', 'Sans compte, sans publicité, même sans réseau.', [dict(type='mail')], 0),
    ('10', 'Emplettes 1.0 : Android, Windows, iPhone et iPad. emplettes.eu', [dict(type='fin')], 0),
]

AVANT, APRES = 0.5, 1.1  # silence avant et après chaque voix
segments, pistes, t = [], [], 0.0
for voix, st, scenes, mini in SEGMENTS:
    v = lire_wav(voix)
    duree = max(mini, AVANT + len(v) / TAUX + APRES)
    debut_voix = t + (duree - len(v) / TAUX - APRES if voix == '00' else AVANT)
    pistes.append((debut_voix, v))
    segments.append(dict(voix=voix, debut=round(t, 3), duree=round(duree, 3), sousTitre=st, scenes=scenes))
    t += duree
total = t + 0.5

# Musique : nappe douce (accords tenus, Do – La mineur – Fa – Sol), sans droits.
n = int(total * TAUX)
temps = np.arange(n) / TAUX
musique = np.zeros(n, dtype=np.float32)
accords = [[261.63, 329.63, 392.00], [220.00, 261.63, 329.63], [174.61, 220.00, 261.63], [196.00, 246.94, 293.66]]
mesure = 4.0
for i in range(int(total / mesure) + 1):
    a, b = int(i * mesure * TAUX), min(n, int((i + 1) * mesure * TAUX + 1.5 * TAUX))
    if a >= n:
        break
    tt = temps[a:b] - i * mesure
    env = np.minimum(1, tt / 1.2) * np.exp(-np.maximum(0, tt - mesure) / 0.6)
    for f in accords[i % 4]:
        musique[a:b] += env * (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)) / 3
    # une note d'arpège légère
    for k, f in enumerate(accords[i % 4]):
        ta = tt - k * 1.0
        m = ta > 0
        musique[a:b][m] += 0.25 * np.exp(-ta[m] / 0.8) * np.sin(2 * np.pi * 2 * f * ta[m])
musique *= 0.06 / max(1e-6, np.abs(musique).max()) * 3
fondu = np.minimum(1, np.minimum(temps / 2, (total - temps) / 3))
musique *= fondu
voix = np.zeros(n, dtype=np.float32)
for debut, v in pistes:
    a = int(debut * TAUX)
    voix[a:a + len(v)] += v[: max(0, min(len(v), n - a))]
# la musique baisse sous la voix
parle = np.convolve((np.abs(voix) > 0.01).astype(np.float32), np.ones(int(0.4 * TAUX)) / int(0.4 * TAUX), mode='same')
son = voix * 0.9 + musique * (1 - 0.55 * np.minimum(1, parle * 3))
son = np.clip(son, -1, 1)
with wave.open(os.path.join(SORTIE, 'son.wav'), 'w') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(TAUX)
    w.writeframes((son * 32767).astype(np.int16).tobytes())
json.dump(dict(total=round(total, 3), segments=segments), open(os.path.join(SORTIE, 'timeline.json'), 'w'), ensure_ascii=False, indent=1)
print(f'{len(segments)} segments, {total:.1f} s')

# Sous-titres (09/11/2026, Aristide) : le texte dit par la voix, au moment où il est dit → emplettes.vtt,
# proposé comme piste « Français » sur le site (activable par le bouton du lecteur, absent par défaut).
textes = dict(json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'narration.json'))))
def hms(s):
    return f'{int(s // 3600):02d}:{int(s % 3600 // 60):02d}:{s % 60:06.3f}'
with open(os.path.join(SORTIE, 'emplettes.vtt'), 'w') as f:
    f.write('WEBVTT\n\n')
    for i, ((debut, v), seg) in enumerate(zip(pistes, segments), 1):
        texte = textes.get(seg['voix'])
        if texte:
            f.write(f'{i}\n{hms(debut)} --> {hms(debut + len(v) / TAUX + 0.4)}\n{texte}\n\n')
