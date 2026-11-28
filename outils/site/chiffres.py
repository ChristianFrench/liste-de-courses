"""Chiffres du site (27/11/2026, Aristide) : produits du catalogue, marques référencées, recettes.
Lus dans le dernier catalogue commun publié (assets/catalogue_demo.txt, rempli par la CI) et dans les
recettes embarquées (assets/recettes/recettes.json). Écrit docs/chiffres.json, lu par docs/site.js.
Usage : python3 outils/site/chiffres.py [destination]
"""
import base64, gzip, json, sys


def catalogue():
    try:
        t = open('assets/catalogue_demo.txt', encoding='utf8').read().strip()
    except OSError:
        return None
    if not t:
        return None
    if t.startswith('sig:'):
        t = t[t.index(':', 4) + 1:]
    if t.startswith('gz:'):
        t = gzip.decompress(base64.b64decode(t[3:])).decode()
    return json.loads(t)


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else 'docs/chiffres.json'
    c = {}
    j = catalogue()
    if j:
        produits, marques = 0, set()
        for r in j.get('rayons', []):
            for s in r.get('secteurs', []):
                for m in s.get('marques', []) or []:
                    marques.add((m.get('nom') if isinstance(m, dict) else str(m)).strip().lower())
                for p in s.get('produits', []):
                    produits += 1
                    if isinstance(p, dict):
                        for m in p.get('marques', []) or []:
                            marques.add((m.get('nom') if isinstance(m, dict) else str(m)).strip().lower())
        for m in j.get('marques', []) or []:
            marques.add((m.get('nom') if isinstance(m, dict) else str(m)).strip().lower())
        c.update(produits=produits, _marques=sorted(marques), rayons=len(j.get('rayons', [])),
                 secteurs=sum(len(r.get('secteurs', [])) for r in j.get('rayons', [])))
    # Les marques proposées par l'application : celles du catalogue publié, du catalogue des marques par
    # secteur et celles des natures de produits (Open Food Facts).
    marques = set(c.pop('_marques', []))
    try:
        for v in json.load(open('assets/marques_catalogue.json', encoding='utf8'))['secteurs'].values():
            for m in (v if isinstance(v, list) else v.get('marques', [])):
                marques.add((m if isinstance(m, str) else m.get('nom', '')).strip().lower())
        for v in json.load(open('assets/natures_off.json', encoding='utf8'))['natures'].values():
            for m in v.get('m', []):
                marques.add(m.strip().lower())
    except (OSError, KeyError, ValueError):
        pass
    marques.discard('')
    if marques:
        c['marques'] = len(marques)
    try:
        c['recettes'] = len(json.load(open('assets/recettes/recettes.json', encoding='utf8'))['recettes'])
    except (OSError, KeyError, ValueError):
        pass
    if not c:
        print('Chiffres : rien à lire')
        return
    with open(dest, 'w', encoding='utf8') as f:
        json.dump(c, f)
    print('::notice::Chiffres du site ' + json.dumps(c))


main()
