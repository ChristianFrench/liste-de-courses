"""Construit assets/marques_catalogue.json depuis outils/marques/marques.txt (liste d'Aristide, 28/10/2026).

Le fichier a ses propres rayons et secteurs ; chacun est rangé dans le secteur le plus proche du catalogue
(CORRESPONDANCE ci-dessous). Lancer : python3 outils/marques/marques_catalogue.py
"""
import json
import pathlib

ICI = pathlib.Path(__file__).parent
RACINE = ICI.parent.parent

# Secteur de la liste → « Rayon/Secteur » du catalogue
CORRESPONDANCE = {
    'Pâtes, Riz, Céréales': ['Épicerie salée/Pâtes, riz et féculents'],
    'Conserves': ['Épicerie salée/Conserves'],
    'Huiles et Vinaigres': ['Épicerie salée/Sauces et condiments'],
    'Sauces et Condiments': ['Épicerie salée/Sauces et condiments'],
    'Apéritif Salé': ['Apéritif/Chips et biscuits apéritif', 'Apéritif/Fruits secs salés et olives'],
    'Biscuits': ['Biscuits et sucré/Biscuits et gâteaux'],
    'Chocolats': ['Biscuits et sucré/Chocolat et confiserie'],
    'Confiseries': ['Biscuits et sucré/Chocolat et confiserie'],
    'Petit-déjeuner': ['Petit-déjeuner/Céréales'],
    'Confitures': ['Petit-déjeuner/Confitures et pâtes à tartiner'],
    'Pâtes à Tartiner': ['Petit-déjeuner/Confitures et pâtes à tartiner'],
    'Eaux': ['Eaux et boissons sans alcool/Eaux'],
    'Sodas': ['Eaux et boissons sans alcool/Sodas et sirops'],
    'Jus de Fruits': ['Eaux et boissons sans alcool/Jus de fruits'],
    'Cafés': ['Petit-déjeuner/Café'],
    'Thés et Infusions': ['Petit-déjeuner/Thé et chocolat en poudre'],
    'Laits': ['Crèmerie/Lait'],
    'Yaourts': ['Crèmerie/Yaourts et desserts'],
    'Desserts Lactés': ['Crèmerie/Yaourts et desserts'],
    'Beurres': ['Crèmerie/Beurre, œufs, crème'],
    'Fromages': ['Fromagerie/Fromages libre-service'],
    'Charcuteries': ['Charcuterie/Charcuterie libre-service'],
    'Produits Festifs': ['Traiteur/Traiteur frais'],
    'Poulet': ['Volaille/Volaille libre-service'],
    'Canard': ['Volaille/Volaille libre-service'],
    'Viandes': ['Boucherie/Boucherie libre-service'],
    'Produits de la Mer': ['Poissonnerie/Poissonnerie libre-service'],
    'Légumes': ['Surgelés/Légumes surgelés'],
    'Plats Cuisinés': ['Surgelés/Plats et pizzas surgelés'],
    'Pommes Frites': ['Surgelés/Légumes surgelés'],
    'Poissons Surgelés': ['Surgelés/Viandes et poissons surgelés'],
    'Pain de Mie': ['Boulangerie/Pain'],
    'Pains Spéciaux': ['Boulangerie/Pain'],
    'Hygiène Corporelle': ['Parfumerie et soins/Toilette et soins du corps'],
    'Shampooings': ['Parfumerie et soins/Cheveux'],
    'Dentifrices': ['Parfumerie et soins/Santé dentaire'],
    'Déodorants': ['Parfumerie et soins/Toilette et soins du corps'],
    'Lessives': ['Entretien / Droguerie/Lessives et soin du linge'],
    'Nettoyants': ['Entretien / Droguerie/Nettoyants ménagers'],
    'Vaisselle': ['Entretien / Droguerie/Produits Vaisselle'],
    'Chat': ['Animaux/Chats'],
    'Chien': ['Animaux/Chiens'],
    'Couches': ['Bébé/Hygiène bébé'],
    'Alimentation Bébé': ['Bébé/Alimentation bébé'],
    'Produits Bio': ['Bio, vrac et terroir/Diététique et bio'],
}

catalogue = json.loads((RACINE / 'assets/catalogue_type.json').read_text())
connus = {f"{r['nom']}/{s['nom']}" for r in catalogue['rayons'] for s in r['secteurs']}
sortie: dict[str, list[str]] = {}
secteur = None
for ligne in (ICI / 'marques.txt').read_text().splitlines():
    t = ligne.strip()
    if not t or t.startswith('RAYON '):
        continue
    if t.startswith('SECTEUR '):
        secteur = t[len('SECTEUR '):]
        assert secteur in CORRESPONDANCE, secteur
        continue
    for cle in CORRESPONDANCE[secteur]:
        assert cle in connus, cle
        l = sortie.setdefault(cle, [])
        if t.lower() not in (x.lower() for x in l):
            l.append(t)
for l in sortie.values():
    l.sort(key=str.lower)
(RACINE / 'assets/marques_catalogue.json').write_text(json.dumps({'secteurs': sortie}, ensure_ascii=False, indent=1) + '\n')
print(len(sortie), 'secteurs,', sum(len(l) for l in sortie.values()), 'marques placées')
