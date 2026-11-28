"""Hiérarchie des marques d'Aristide (22/11/2026, groupe › famille › marque) → rangée par SECTEUR du catalogue des
produits (« on ne verra les marques que par rapport au produit d'un secteur »).
Pour chaque marque, dans l'ordre :
1. les secteurs des produits du catalogue qui la portent (assets/catalogue_type.json) ;
2. sinon ses secteurs dans assets/marques_catalogue.json ;
3. sinon une place choisie pour elle (MARQUE ci-dessous) ;
4. sinon le secteur par défaut de sa famille (FAMILLE).
Les marques de distributeur généralistes (tous rayons) restent à part.
Sortie : windows-catalogues/Donnees/marques-secteurs.json et /mnt/project-files/modele/marques-par-secteur.txt
Usage : python3 outils/marques/hierarchie_secteurs.py"""
import json, collections, os
H = json.load(open('outils/marques/hierarchie-aristide-v2.json', encoding='utf-8'))
C = json.load(open('assets/catalogue_type.json', encoding='utf-8'))
MC = json.load(open('assets/marques_catalogue.json', encoding='utf-8'))['secteurs']
DISTRIBUTEURS = 'Marques de distributeurs généralistes (multi-rayons)'

FAMILLE = {
    'Laits, beurres, crèmes et œufs': 'Crèmerie/Beurre, œufs, crème',
    'Fromages': 'Fromagerie/Fromages libre-service',
    'Yaourts, desserts frais et alternatives végétales': 'Crèmerie/Yaourts et desserts',
    'Viandes et volailles': 'Boucherie/Boucherie libre-service',
    'Charcuterie et salaisons': 'Charcuterie/Charcuterie libre-service',
    'Traiteur frais, plats préparés et snacking': 'Traiteur/Traiteur frais',
    'Fruits secs, graines et olives': 'Fruits et légumes/Fruits secs et graines',
    'Poissons, crustacés et produits de la mer (frais, conserves, surgelés)': 'Poissonnerie/Poissonnerie libre-service',
    'Légumes préparés, conserves et surgelés': 'Épicerie salée/Conserves',
    'Pains de mie, brioches et viennoiseries': 'Viennoiserie et pâtisserie/Viennoiserie',
    'Biscuits, gâteaux et pâtisseries': 'Biscuits et sucré/Biscuits et gâteaux',
    'Céréales, confitures, pâtes à tartiner et miel': 'Petit-déjeuner/Confitures et pâtes à tartiner',
    'Cafés, thés, infusions et cacao': 'Petit-déjeuner/Café',
    'Pâtes, riz, semoules et féculents': 'Épicerie salée/Pâtes, riz et féculents',
    'Sauces, condiments, épices et huiles': 'Épicerie salée/Sauces et condiments',
    'Plats cuisinés en conserve et cuisine du monde': 'Épicerie salée/Soupes et plats préparés',
    'Biscuits apéritifs et chips': 'Apéritif/Chips et biscuits apéritif',
    'Chocolats et confiseries': 'Biscuits et sucré/Chocolat et confiserie',
    'Glaces et sorbets': 'Glaces/Glaces',
    'Frites, pommes de terre et plats surgelés': 'Surgelés/Plats et pizzas surgelés',
    'Eaux plates et gazeuses': 'Eaux et boissons sans alcool/Eaux',
    'Jus de fruits, sirops et boissons sans alcool': 'Eaux et boissons sans alcool/Sodas et sirops',
    'Bières, vins et spiritueux': 'Cave/Alcools et apéritifs',
    'Alimentation et soins pour animaux': 'Animaux/Chats',
    'Soins du visage, du corps et parfumerie': 'Parfumerie et soins/Toilette et soins du corps',
    'Soins capillaires et rasage': 'Parfumerie et soins/Cheveux',
    'Hygiène bucco-dentaire': 'Parfumerie et soins/Santé dentaire',
    'Hygiène féminine, bébé et incontinences': 'Hygiène/Hygiène féminine',
    'Lessives et soin du linge': 'Entretien / Droguerie/Lessives et soin du linge',
    'Nettoyants ménagers, vaisselle et insecticides': 'Entretien / Droguerie/Nettoyants ménagers',
    'Essuie-tout, papier toilette, mouchoirs et emballages': 'Entretien / Droguerie/Papier',
    'Arts de la table, cuisson et conservation': 'Cuisine et arts de la table/Arts de la table et cuisine',
    'Accessoires ménagers, petit électroménager et piles': 'Entretien / Droguerie/Accessoires de ménage',
    'Vêtements, sous-vêtements et accessoires': 'Textile/Vêtements femme',
    'Papeterie et fournitures scolaires': 'Loisirs/Papeterie et librairie',
    'Jouets, jeux de société et licences': 'Loisirs/Jouets',
}
M = lambda *s: list(s)
MARQUE = {
    'Candia': M('Crèmerie/Lait'), 'Lactel': M('Crèmerie/Lait'),
    'Bigard': M('Boucherie/Boucherie libre-service'), 'Charal': M('Boucherie/Boucherie libre-service'),
    'Père Dodu': M('Volaille/Volaille libre-service'), 'Maître Coq': M('Volaille/Volaille libre-service'), 'Le Gaulois': M('Volaille/Volaille libre-service'),
    'Labeyrie': M('Traiteur/Traiteur frais'),
    'Iglo': M('Surgelés/Viandes et poissons surgelés'), 'Ocean Sea': M('Surgelés/Viandes et poissons surgelés'),
    'Odyssée': M('Poissonnerie/Poissonnerie libre-service'), 'Petit Navire': M('Épicerie salée/Conserves'), 'Rio Mare': M('Épicerie salée/Conserves'),
    'Saupiquet': M('Épicerie salée/Conserves'), 'Connétable': M('Épicerie salée/Conserves'),
    'Freshona': M('Épicerie salée/Conserves'), 'Saint Eloi': M('Épicerie salée/Conserves'),
    'Brioche Pasquier': M('Viennoiserie et pâtisserie/Viennoiserie'), 'Harry\'s': M('Petit-déjeuner/Biscottes et tartines'),
    'Jacquet': M('Petit-déjeuner/Biscottes et tartines'), 'Chabrior': M('Petit-déjeuner/Biscottes et tartines'),
    'Crownfield': M('Petit-déjeuner/Céréales'), 'Kellogg\'s': M('Petit-déjeuner/Céréales'), 'Jardin Bio étic': M('Bio, vrac et terroir/Diététique et bio'),
    'Lipton': M('Petit-déjeuner/Thé et chocolat en poudre'), 'Nesquik': M('Petit-déjeuner/Thé et chocolat en poudre'),
    'Van Houten': M('Petit-déjeuner/Thé et chocolat en poudre'), 'Éléphant': M('Petit-déjeuner/Thé et chocolat en poudre'),
    'Ducros': M('Épicerie salée/Sel, épices et aides culinaires'), 'Maggi': M('Épicerie salée/Sel, épices et aides culinaires'),
    'Lesieur': M('Épicerie salée/Sauces et condiments'), 'Puget': M('Épicerie salée/Sauces et condiments'),
    'Old El Paso': M('Cuisine du monde/Mexique et Amérique'), 'Buitoni': M('Épicerie salée/Soupes et plats préparés'),
    'Zapetti': M('Cuisine du monde/Italie'), 'Mutti': M('Épicerie salée/Conserves'),
    'Bouton d\'Or': M('Apéritif/Fruits secs salés et olives'), 'Picard': M('Surgelés/Plats et pizzas surgelés'),
    'Findus': M('Surgelés/Légumes surgelés'), 'Épi d\'Or': M('Surgelés/Plats et pizzas surgelés'), 'McCain': M('Surgelés/Plats et pizzas surgelés'),
    'Innocent': M('Eaux et boissons sans alcool/Jus de fruits'), 'Joker': M('Eaux et boissons sans alcool/Jus de fruits'),
    'Tropicana': M('Eaux et boissons sans alcool/Jus de fruits'), 'Solevita': M('Eaux et boissons sans alcool/Jus de fruits'),
    'Paquito': M('Eaux et boissons sans alcool/Jus de fruits'), 'Pulco': M('Eaux et boissons sans alcool/Sodas et sirops'),
    '1664': M('Cave/Bières et cidres'), 'Heineken': M('Cave/Bières et cidres'), 'Kronenbourg': M('Cave/Bières et cidres'), 'Leffe': M('Cave/Bières et cidres'),
    'Saint-Vincent': M('Cave/Vins'), 'Champomy': M('Eaux et boissons sans alcool/Sodas et sirops'),
    'Felix': M('Animaux/Chats'), 'Ultima': M('Animaux/Chiens', 'Animaux/Chats'),
    'Garnier': M('Parfumerie et soins/Cosmétiques et parfums'), 'L\'Oréal': M('Parfumerie et soins/Cosmétiques et parfums'),
    'RoC': M('Parfumerie et soins/Cosmétiques et parfums'), 'SVR': M('Parapharmacie/Solaires et soins spécifiques'),
    'Tahiti': M('Parfumerie et soins/Toilette et soins du corps'),
    'Gillette': M('Hygiène/Rasage'), 'Wilkinson': M('Hygiène/Rasage'),
    'Pampers': M('Bébé/Hygiène bébé'), 'Mots d\'Enfants': M('Bébé/Hygiène bébé'), 'Pommette': M('Bébé/Hygiène bébé'),
    'Vanish': M('Entretien / Droguerie/Lessives et soin du linge'), 'K2r': M('Entretien / Droguerie/Lessives et soin du linge'),
    'Paic': M('Entretien / Droguerie/Produits Vaisselle'), 'Sun': M('Entretien / Droguerie/Produits Vaisselle'),
    'Finish': M('Entretien / Droguerie/Produits Vaisselle'), 'Calgon': M('Entretien / Droguerie/Lessives et soin du linge'),
    'Raid': M('Entretien / Droguerie/Insecticides et antiparasites'), 'Harpic': M('Entretien / Droguerie/Salle de bain et cirage'),
    'WC Net': M('Entretien / Droguerie/Salle de bain et cirage'), 'Destop': M('Entretien / Droguerie/Salle de bain et cirage'),
    'Alfapac': M('Entretien / Droguerie/Emballages et Aluminium etc'), 'Albal': M('Entretien / Droguerie/Emballages et Aluminium etc'),
    'Duralex': M('Cuisine et arts de la table/Vaisselle'), 'Luminarc': M('Cuisine et arts de la table/Vaisselle'), 'Arcopal': M('Cuisine et arts de la table/Vaisselle'),
    'Moulinex': M('Électroménager et décoration/Petit électroménager'), 'Seb': M('Électroménager et décoration/Petit électroménager'),
    'Silvercrest': M('Électroménager et décoration/Petit électroménager'), 'Qilive': M('Électroménager et décoration/Petit électroménager'),
    'Duracell': M('Bricolage, auto et jardin/Électricité et éclairage'), 'Energizer': M('Bricolage, auto et jardin/Électricité et éclairage'),
    'Parkside': M('Bricolage, auto et jardin/Outillage'), 'Livarno Home': M('Électroménager et décoration/Décoration'),
    'Carrefour Home': M('Électroménager et décoration/Rangement'), 'Monoprix Maison': M('Électroménager et décoration/Décoration'),
    'Dim': M('Textile/Lingerie'), 'Playtex': M('Textile/Lingerie'), 'Eminence': M('Textile/Vêtements homme'), 'Athena': M('Textile/Vêtements homme'),
    'Petit Bateau': M('Textile/Vêtements enfant et bébé'), 'Lupilu': M('Textile/Vêtements enfant et bébé'), 'Bout\'chou': M('Textile/Vêtements enfant et bébé'),
    'Le Bourget': M('Textile/Lingerie'), 'Labonal': M('Textile/Accessoires de mode'), 'Olympia': M('Textile/Accessoires de mode'),
    'Livergy': M('Textile/Vêtements homme'), 'Crivit': M('Textile/Vêtements femme', 'Textile/Vêtements homme'),
    'Tex Basic': M('Textile/Vêtements femme'), 'Tissaia': M('Textile/Linge de maison'), 'Pierre Cardin': M('Textile/Accessoires de mode'),
}
secteurs = [f"{r['nom']}/{s['nom']}" for r in C['rayons'] for s in r['secteurs']]
connus = set(secteurs)
produits = collections.defaultdict(set)
for r in C['rayons']:
    for s in r['secteurs']:
        for p in s['produits']:
            for m in (p.get('marques') or []) if isinstance(p, dict) else []:
                produits[m.lower()].add(f"{r['nom']}/{s['nom']}")
mc = collections.defaultdict(set)
for k, l in MC.items():
    for m in l: mc[m.lower()].add(k)
place = collections.OrderedDict((s, []) for s in secteurs)
distributeurs, origine = [], collections.Counter()
for g, gv in H['rayons'].items():
    for f, fv in gv['familles'].items():
        for m in fv['marques']:
            nom = m['nom']
            if g == DISTRIBUTEURS:
                distributeurs.append({'nom': nom, 'source': m.get('source'), 'gamme': f}); continue
            for qui, l in (('produits', produits.get(nom.lower())), ('marques_catalogue', mc.get(nom.lower())),
                           ('choix', MARQUE.get(nom)), ('famille', [FAMILLE[f]])):
                l = [x for x in (l or []) if x in connus]
                if l: break
            origine[qui] += 1
            for s in sorted(l):
                if not any(x['nom'].lower() == nom.lower() for x in place[s]):
                    place[s].append({'nom': nom, 'source': m.get('source'), 'famille': f})
out = {'meta': {'description': 'Marques par secteur du catalogue des produits (Domaine › Rayon › Secteur › Marques)',
                'date_mise_a_jour': '2026-11-22', 'origine': 'hierarchie-aristide-v2.json rangée par hierarchie_secteurs.py'},
       'secteurs': {s: sorted(l, key=lambda x: x['nom'].lower()) for s, l in place.items() if l},
       'distributeurs': distributeurs}
json.dump(out, open('windows-catalogues/Donnees/marques-secteurs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
L = ['Catalogue des marques — rangé par secteur du catalogue des produits (22/11/2026)', '']
for r in C['rayons']:
    rs = [s for s in r['secteurs'] if place[f"{r['nom']}/{s['nom']}"]]
    if not rs: continue
    L.append(r['nom'])
    for s in rs:
        L.append(f"    {s['nom']} : " + ', '.join(x['nom'] for x in sorted(place[f"{r['nom']}/{s['nom']}"], key=lambda x: x['nom'].lower())))
    L.append('')
L += ['Marques de distributeur (tous rayons)', '    ' + ', '.join(x['nom'] for x in distributeurs)]
os.makedirs('/mnt/project-files/modele', exist_ok=True)
open('/mnt/project-files/modele/marques-par-secteur.txt', 'w', encoding='utf-8').write('\r\n'.join(L))
print(dict(origine), len(out['secteurs']), 'secteurs,', sum(len(l) for l in out['secteurs'].values()), 'placements,', len(distributeurs), 'distributeurs')
