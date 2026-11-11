"""Vidéo « Emplettes pour les nuls » : minutage, piste son (voix Piper + musique) et timeline pour video.html.
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
SEGMENTS = [
    ('00', 'Emplettes, la liste de courses de tout le foyer.', [dict(type='anim', poids=1)], 14.5),
    ('t1', None, [dict(type='titre', numero='1', texte='Préparer ensemble')], 0),
    ('01', 'Emplettes, la liste de courses de tout le foyer.', [tel('v01 Accueil')], 0),
    ('02', 'Une nouvelle liste : le magasin, et c\'est parti.', [tel('v02 Nouvelle-liste', [tap(1.6, 195, 190)])], 0),
    ('03', 'Trois lettres suffisent pour trouver un produit.',
     [tel('v03 Remplir', [tap(0.6, 200, 168)], [(1.3, 'v03 Recherche-c'), (2.0, 'v03 Recherche-ca'), (2.7, 'v03 Recherche-cam')], poids=1.4),
      tel('v03 Recherche-cam', [tap(0.5, 110, 208)], [(0.9, 'v04 Promo-proposee')], poids=0.6)], 0),
    ('04', 'Chaque article se range tout seul à sa place dans le magasin.',
     [tel('v04 Promo-proposee', [tap(0.6, 195, 727)], [(1.0, 'v04 Camembert-range')], poids=0.4),
      tel('v04 Camembert-range', [tap(2.2, 367, 591)], poids=1, surligne=591)], 0),
    ('05', 'Une marque, une promotion, un mot pour celui qui part.', [tel('v05 Article', [tap(2.0, 195, 555)])], 0),
    ('06', 'Claire complète la liste depuis son téléphone…',
     [dict(type='deux', g='v04 Camembert-range', d='v07 Yaourts-arrives', lg='Thomas', ld='Claire', gestes_d=[tap(1.2, 200, 640)])], 0),
    ('07', '… et Thomas la voit aussitôt.',
     [dict(type='deux', g='v07 Yaourts-arrives', d='v07 Yaourts-arrives', lg='Thomas', ld='Claire', surligne_g=640)], 0),
    ('t2', None, [dict(type='titre', numero='2', texte='Faire les courses')], 0),
    ('08', 'La liste est prête : tout le foyer le sait.', [tel('v08 Liste-prete', [tap(3.2, 195, 726)])], 0),
    ('09', 'Samedi matin, Thomas part avec la liste.', [tel('v09 Partir', [tap(3.0, 195, 646)])], 0),
    ('10', 'Un appui : l\'article est dans le chariot.',
     [tel('v10 En-magasin', [tap(2.0, 120, 291)], [(2.2, 'v10 En-magasin-coche')])], 0),
    ('11', 'Deux appuis : il manquait en rayon.', [tel('v10 En-magasin-coche', [tap(0.6, 120, 346, True)], [(1.0, 'v11 Manquant')])], 3.6),
    ('12', 'Claire suit les courses de la maison, et peut encore ajouter.',
     [dict(type='deux', g='v11 Manquant', d='v12 Courses-suivi', lg='Thomas', ld='Claire')], 0),
    ('13', 'Terminé : le bilan et le ticket sont gardés.', [tel('v13 Terminer', [tap(3.0, 195, 727)])], 0),
    ('t3', None, [dict(type='titre', numero='3', texte='Chaque course rend la suivante plus simple')], 0),
    ('14', 'Repartir d\'une course passée : la liste est presque faite.', [tel('v14 Course-passee', [tap(3.2, 165, 630)])], 0),
    ('15', 'Vos listes habituelles, gardées pour la prochaine fois.', [tel('v15 Listes-types', [tap(3.0, 150, 675)])], 0),
    ('16', 'Le parcours du magasin s\'apprend tout seul, en cochant.', [tel('v16 Magasin')], 0),
    ('17', 'À chaque course, il se complète.', [tel('v16 Parcours')], 0),
    ('18', 'Un catalogue de plus de 2 000 produits, qui s\'enrichit de vos ajouts.', [tel('v18 Catalogue')], 0),
    ('19', 'Et il s\'améliore pour tous les foyers.', [tel('v19 Nouveautes', [tap(3.0, 195, 777)])], 0),
    ('20', 'Inviter un proche : un code, sans compte ni mot de passe.', [dict(type='mail')], 0),
    ('21', 'Un message au foyer, reçu même application fermée.', [dict(type='notif')], 0),
    ('22', 'Emplettes, sur Android et sur Windows. Essayez la démonstration sur emplettes.eu.', [dict(type='fin')], 0),
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
