"""Construit assets/correspondances_mails.json : lignes réelles des listes envoyées par mail → produit du catalogue.

Source : /mnt/project-files/modele/listes-mails/correspondance.json (classement des 98 listes de 2025-2026).
Clé : le texte de la ligne normalisé comme dans lib/donnees/import_texte.dart (normaliser).
"""
import json
import re
import sys
import unicodedata


def normaliser(t):
    t = t.lower().replace('œ', 'oe').replace('æ', 'ae')
    t = ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9%]+', ' ', t).strip()


source = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/modele/listes-mails/correspondance.json'
c = json.load(open(source, encoding='utf-8'))
sortie = {}
for brut, v in c.items():
    if not v or not v.get('produit'):
        continue
    k = normaliser(brut)
    if k:
        sortie[k] = [v['produit'], v.get('marque') or '']
json.dump(dict(sorted(sortie.items())), open('assets/correspondances_mails.json', 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(len(sortie), 'correspondances')
