"""Ajoute aux recettes fournies avec la console les 200 recettes n° 298 à 497 d'Aristide (20/11/2026) et pose la
difficulté de toutes les recettes (outils/recettes/difficulte.py).
Source : outils/recettes/sources/nouvelles-298-497.txt (son fichier, tel quel) ; les étapes récrites recette par
recette, quand elles existent, sont dans outils/recettes/sources/etapes-298-497.json ({numéro: [étapes]}) et
remplacent celles du fichier.
Usage : python3 outils/recettes/nouvelles_298_497.py   (augmente la version : la console réapplique à l'ouverture)"""
import json, os, re, sys, unicodedata
sys.path.insert(0, os.path.dirname(__file__))
from difficulte import difficulte

D = 'outils/recettes'
FOURNIES = f'{D}/illustrations/recettes-fournies.json'
TYPES = {'ENTRÉES': 'Entrée', 'PLATS': 'Plats', 'ACCOMPAGNEMENTS': 'Plats accompagnement', 'SAUCES': 'Sauces',
         'DESSERTS': 'Dessert'}


def slug(t):
    t = ''.join(c for c in unicodedata.normalize('NFD', t.lower().replace('œ', 'oe')) if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', '-', t).strip('-')


def quantite(q):
    q = q.strip()
    if q in ('selon le goût', 'au goût', ''):
        return 'au goût' if q else ''
    def cuill(m):
        n = m[1]
        pl = not re.fullmatch(r'1|1/2|½|0,5', n)
        return f"{n} cuillère{'s' if pl else ''} à {m[2]}"
    return re.sub(r'^(\S+) c\. à (soupe|café)', cuill, q)


def ingredients(lignes):
    out = []
    for nom, q in lignes:
        nom = nom.replace('’', "'").strip()
        q = quantite(q.replace('’', "'"))
        if nom.lower() == 'sel et poivre':
            out += [dict(nom='Sel', quantite='au goût'), dict(nom='Poivre', quantite='au goût')]
            continue
        prec = ''
        m = re.match(r'(.*?) \((.*)\)$', nom)
        if m:
            nom, prec = m[1], m[2]
        d = dict(nom=nom[:1].upper() + nom[1:])
        if q: d['quantite'] = q
        if prec: d['precision'] = prec
        out.append(d)
    return out


def lire(chemin):
    t = open(chemin, encoding='utf-8').read()
    R = []
    for b in re.split(r'\n=+\n', t)[1:]:
        l = b.strip().split('\n')
        m = re.match(r'(\d+)\. (.*)', l[0])
        p = re.search(r'Portions : (\d+) \| Préparation : (\d+) min \| Cuisson : (\d+) min', b)
        ing, et = [], []
        for x in l:
            if x.startswith('  - '):
                a, _, q = x[4:].rpartition(' : ')
                ing.append((a, q) if a else (x[4:], ''))
            mm = re.match(r'  \d+\. (.*)', x)
            if mm: et.append(mm[1].strip().replace('’', "'"))
        R.append(dict(n=int(m[1]), titre=m[2].strip().replace('’', "'"),
                      type=TYPES[re.search(r'Catégorie : (.*)', b)[1].strip()],
                      pour=int(p[1]), prep=int(p[2]), cuisson=int(p[3]), ing=ingredients(ing), etapes=et))
    return R


def main():
    src = json.load(open(FOURNIES, encoding='utf-8'))
    recettes = [r for r in src['recettes'] if not r.get('numero') or r['numero'] < 298]
    ecrites = {}
    if os.path.exists(f'{D}/sources/etapes-298-497.json'):
        ecrites = {int(k): v for k, v in json.load(open(f'{D}/sources/etapes-298-497.json', encoding='utf-8')).items()}
    ids = {r['id'] for r in recettes}
    for r in lire(f'{D}/sources/nouvelles-298-497.txt'):
        etapes = ecrites.get(r['n'], r['etapes'])
        rid = f"emplettes-{slug(r['titre'])}"
        if rid in ids:
            rid += f"-{r['n']}"
        detail = r['ing']
        recettes.append(dict(
            id=rid, numero=r['n'], titre=r['titre'], types=[r['type']],
            ingredients=[' '.join(x for x in (d.get('quantite', ''), d['nom'], f"({d['precision']})" if d.get('precision') else '') if x) for d in detail],
            titreIngredients='Ingrédients', detail=detail, etapes=etapes,
            preparation='\n'.join(f'{i + 1}. {e}' for i, e in enumerate(etapes)),
            photos=[], pour=f"{r['pour']} personnes", source='Emplettes',
            tempsPreparation=r['prep'], tempsCuisson=r['cuisson']))
    for r in recettes:
        if not r.get('memo'):
            r['difficulte'] = difficulte(r['titre'])
    src['recettes'] = recettes
    src['version'] = src.get('version', 1) + 1
    json.dump(src, open(FOURNIES, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f"{len(recettes)} recettes, version {src['version']}")


if __name__ == '__main__':
    main()
