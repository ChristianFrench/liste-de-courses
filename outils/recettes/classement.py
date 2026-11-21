"""Classement des recettes (21/11/2026, Aristide) : 9 types, chacun avec ses sous-types, et l'origine.
Première proposition calculée d'après le titre (et, pour la nature d'un plat, les ingrédients) ; les cas
particuliers sont dans PARTICULIERS. Pour corriger : changer une liste ou un cas, puis relancer
python3 outils/recettes/classement.py (augmente la version : la console réapplique à l'ouverture).
Une recette peut avoir plusieurs types ; elle a un sous-type par type (champ sousTypes : {type: sous-type})."""
import json, os, re, sys, unicodedata

TYPES = {
    'Apéritif': ['Amuse-bouche', 'Tartinade et dip', 'Bouchées et feuilletés'],
    'Entrée': ['Soupe et velouté', 'Salade composée', 'Entrée froide', 'Entrée chaude'],
    'Plats': ['Viande', 'Volaille', 'Poisson et fruits de mer', 'Végétarien'],
    'Plats complets': ['Gratin et lasagnes', 'Mijoté complet', 'Tarte salée et pizza', 'Riz et pâtes garnis', 'Bowl et salade-repas'],
    'Plats accompagnement': ['Légumes', 'Féculents', 'Légumineuses'],
    'Sauces': ['Sauce chaude', 'Sauce froide et vinaigrette', 'Condiment', 'Sauce sucrée'],
    'Dessert': ['Gâteau', 'Tarte', 'Crème et mousse', 'Fruits', 'Glace', 'Sauce sucrée'],
    'Petit-déjeuner et goûter': ['Crêpes et gaufres', 'Biscuits et petits gâteaux', 'Brioches et viennoiseries', 'Pains',
                                 'Confitures et pâtes à tartiner'],
    'Bases culinaires': ['Pâtes', 'Fonds et bouillons', 'Crèmes de base', 'Mémos techniques'],
}
ORIGINES = ['France', 'Italie', 'Espagne et Portugal', "Autres pays d'Europe", 'Maghreb et Moyen-Orient', 'Afrique', 'Inde',
            'Asie', 'Amériques']


def n(t):
    t = t.lower().replace('œ', 'oe').replace('’', "'")
    return ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn')


def a(t, *mots):
    """Un des mots (expressions régulières, sans accents) est dans le texte t (déjà normalisé)."""
    return any(re.search(m, t) for m in mots)


# Cas particuliers : titre → {type: sous-type} (remplace le calcul).
PARTICULIERS = {
    'Temps de cuisson à la cocotte-minute': {'Bases culinaires': 'Mémos techniques'},
    'Pâte à pizza': {'Bases culinaires': 'Pâtes'},
    'Pâtes fraîches maison': {'Bases culinaires': 'Pâtes', 'Plats accompagnement': 'Féculents'},
    'Focaccia': {'Petit-déjeuner et goûter': 'Pains', 'Apéritif': 'Amuse-bouche'},
    'Pissaladière': {'Plats complets': 'Tarte salée et pizza', 'Apéritif': 'Bouchées et feuilletés'},
    'Frites maison': {'Plats accompagnement': 'Féculents'},
    'Purée de pommes de terre maison': {'Plats accompagnement': 'Féculents'},
    'Pommes de terre à la grecque': {'Plats accompagnement': 'Féculents'},
    'Châtaignes au Air Fryer': {'Plats accompagnement': 'Féculents'},
    'Gratin dauphinois de Matthias': {'Plats accompagnement': 'Féculents'},
    'Gratin dauphinois maison': {'Plats accompagnement': 'Féculents'},
    'Écrasé de pommes de terre à l\'huile d\'olive': {'Plats accompagnement': 'Féculents'},
    'Galettes de pommes de terre': {'Plats accompagnement': 'Féculents'},
    'Gratin de courgettes': {'Plats accompagnement': 'Légumes'},
    'Riz cantonnais': {'Plats complets': 'Riz et pâtes garnis', 'Plats accompagnement': 'Féculents'},
    'Piments verts grillés': {'Plats accompagnement': 'Légumes'},
    'Ratatouille à ma façon': {'Plats accompagnement': 'Légumes'},
    'Chou-fleur à la béchamel': {'Plats accompagnement': 'Légumes'},
    'Chou-fleur rôti entier au curcuma': {'Plats': 'Végétarien'},
    'Salade de pommes de terre': {'Entrée': 'Salade composée', 'Plats accompagnement': 'Féculents'},
    'Brandade de morue': {'Plats complets': 'Gratin et lasagnes'},
    'Spanakopita': {'Entrée': 'Entrée chaude', 'Apéritif': 'Bouchées et feuilletés'},
    'Tartinade grecque à la feta': {'Apéritif': 'Tartinade et dip'},
    'Tzatziki': {'Apéritif': 'Tartinade et dip', 'Sauces': 'Sauce froide et vinaigrette'},
    'Tapenade noire': {'Apéritif': 'Tartinade et dip', 'Sauces': 'Condiment'},
    'Raïta au concombre': {'Sauces': 'Sauce froide et vinaigrette'},
    'Crevettes au barbecue': {'Plats': 'Poisson et fruits de mer', 'Apéritif': 'Amuse-bouche'},
    'Soupe au pistou': {'Entrée': 'Soupe et velouté', 'Plats complets': 'Mijoté complet'},
    'Soupe de nouilles au poulet et gingembre': {'Plats complets': 'Riz et pâtes garnis', 'Entrée': 'Soupe et velouté'},
    'Soupe à l\'oignon gratinée': {'Entrée': 'Soupe et velouté'},
    'Coquilles Saint-Jacques poêlées': {'Entrée': 'Entrée chaude', 'Plats': 'Poisson et fruits de mer'},
    'Foie gras mi-cuit': {'Entrée': 'Entrée froide'},
    'Accras de morue': {'Apéritif': 'Bouchées et feuilletés'},
    'Beignets de fleurs de courgette': {'Apéritif': 'Bouchées et feuilletés', 'Entrée': 'Entrée chaude'},
    'Bouchées de saumon au concombre': {'Apéritif': 'Bouchées et feuilletés'},
    'Samoussas aux légumes': {'Apéritif': 'Bouchées et feuilletés', 'Entrée': 'Entrée chaude'},
    'Rouleaux de printemps aux crevettes': {'Entrée': 'Entrée froide', 'Apéritif': 'Bouchées et feuilletés'},
    'Cake salé jambon olives': {'Apéritif': 'Bouchées et feuilletés', 'Entrée': 'Entrée froide'},
    'Avocado toast façon Buffalo Grill': {'Entrée': 'Entrée froide', 'Petit-déjeuner et goûter': 'Pains'},
    'Croque-monsieur': {'Plats': 'Viande', 'Entrée': 'Entrée chaude'},
    'Salade niçoise': {'Plats complets': 'Bowl et salade-repas', 'Entrée': 'Salade composée'},
    'Salade César': {'Plats complets': 'Bowl et salade-repas', 'Entrée': 'Salade composée'},
    'Salade de riz': {'Plats complets': 'Bowl et salade-repas', 'Entrée': 'Salade composée'},
    'Salade de pâtes': {'Plats complets': 'Bowl et salade-repas', 'Entrée': 'Salade composée'},
    'Quiche lorraine': {'Plats complets': 'Tarte salée et pizza', 'Entrée': 'Entrée chaude'},
    'Tarte à la tomate et à la moutarde': {'Plats complets': 'Tarte salée et pizza', 'Entrée': 'Entrée chaude'},
    'Tarte aux poireaux': {'Plats complets': 'Tarte salée et pizza', 'Entrée': 'Entrée chaude'},
    'Tarte fine à la tomate et au chèvre': {'Entrée': 'Entrée chaude', 'Apéritif': 'Bouchées et feuilletés'},
    'Bò bún': {'Plats complets': 'Bowl et salade-repas'},
    'Raclette': {'Plats complets': 'Mijoté complet'},
    'Fondue savoyarde': {'Plats complets': 'Mijoté complet'},
    'Choucroute garnie simple': {'Plats complets': 'Mijoté complet'},
    'Galettes de sarrasin complètes': {'Plats complets': 'Tarte salée et pizza'},
    'Okonomiyaki au chou': {'Plats complets': 'Tarte salée et pizza'},
    'Polenta crémeuse aux champignons': {'Plats': 'Végétarien'},
    'Pain perdu': {'Petit-déjeuner et goûter': 'Crêpes et gaufres', 'Dessert': 'Gâteau'},
    'Pudding au pain et aux raisins': {'Dessert': 'Gâteau'},
    'Hachis parmentier': {'Plats complets': 'Gratin et lasagnes'},
    'Lasagnes de courgettes à la mozzarella': {'Plats complets': 'Gratin et lasagnes'},
    'Mac and cheese': {'Plats complets': 'Gratin et lasagnes', 'Plats accompagnement': 'Féculents'},
    'Spaghettis cacio e pepe': {'Plats complets': 'Riz et pâtes garnis', 'Plats accompagnement': 'Féculents'},
    'Pralines': {'Petit-déjeuner et goûter': 'Biscuits et petits gâteaux'},
    'Truffes au chocolat': {'Petit-déjeuner et goûter': 'Biscuits et petits gâteaux'},
    'Galette des rois à la frangipane': {'Dessert': 'Tarte'},
    'Flan pâtissier': {'Dessert': 'Tarte', 'Petit-déjeuner et goûter': 'Biscuits et petits gâteaux'},
    'Far breton': {'Dessert': 'Gâteau'},
    'Riz au lait': {'Dessert': 'Crème et mousse'},
    'Riz au lait à la noix de coco et mangue': {'Dessert': 'Crème et mousse'},
    'Tiramisu': {'Dessert': 'Crème et mousse'},
    'Tiramisu aux fraises': {'Dessert': 'Crème et mousse'},
    'Charlotte aux poires': {'Dessert': 'Gâteau'},
    'Pavlova aux fruits exotiques': {'Dessert': 'Gâteau'},
    'Cheesecake au citron sans cuisson': {'Dessert': 'Gâteau'},
    'Fraises chantilly': {'Dessert': 'Fruits'},
    'Mousse aux fraises': {'Dessert': 'Crème et mousse'},
    'Crème d\'ail': {'Sauces': 'Sauce chaude'},
    'Mayonnaise sans œufs': {'Sauces': 'Sauce froide et vinaigrette'},
    'Sauce Mornay (ou béchamel)': {'Sauces': 'Sauce chaude', 'Bases culinaires': 'Crèmes de base'},
    'Bibeleskaes, sauce échalotes et ciboulette': {'Sauces': 'Sauce froide et vinaigrette', 'Apéritif': 'Tartinade et dip'},
}

POISSON = (r'poisson', r'saumon', r'cabillaud', r'thon', r'truite', r'lieu', r'merlu', r'haddock', r'lotte', r'maquereau',
           r'rouget', r'daurade', r'sole', r'morue', r'sardine', r'anchois', r'bar\b', r'crevette', r'moule', r'calamar',
           r'encornet', r'seiche', r'poulpe', r'palourde', r'vongole', r'saint-jacques', r'fruits de mer', r'bouillabaisse',
           r'bourride', r'fish')
VOLAILLE = (r'poulet\b', r'dinde', r'pintade', r'canard', r'\bcoq\b', r'poule\b', r'volaille', r'cordons bleus')
VIANDE = (r'boeuf', r'veau', r'porc', r'agneau', r'lapin', r'saucisse', r'jambon', r'lard', r'chorizo', r'steak', r'ribs',
          r'rognon', r'petit sale', r'boulettes', r'kefta', r'hamburger', r'daube', r'osso', r'bolognaise', r'chili con',
          r'carbonade', r'goulash', r'bulgogi', r'mafe', r'cassoulet', r'chou farci', r'petits farcis', r'pot-au-feu',
          r'navarin', r'gigot', r'blanquette', r'merguez', r'tartiflette', r'carbonara', r'amatriciana')


def nature_plat(r):
    t = n(r['titre'])
    ing = n(' '.join(d['nom'] for d in r.get('detail', [])))
    for liste, nom in ((POISSON, 'Poisson et fruits de mer'), (VOLAILLE, 'Volaille'), (VIANDE, 'Viande')):
        if a(t, *liste): return nom
    if 'Végétarien' in r.get('regimes', []): return 'Végétarien'
    for liste, nom in ((POISSON, 'Poisson et fruits de mer'), (VOLAILLE, 'Volaille'), (VIANDE, 'Viande')):
        if a(ing, *liste): return nom
    return 'Végétarien'


def complet(t):
    """Sous-type « Plats complets » d'un titre, ou None."""
    if a(t, r'^gratin', r'lasagne', r'parmentier', r'moussaka', r'tartiflette', r'hachis', r'gratin de pates', r'mac and',
         r'parmesane', r'brandade'):
        return 'Gratin et lasagnes'
    if a(t, r'couscous', r'pot-au-feu', r'potee', r'choucroute', r'cassoulet', r'paella', r'tajine', r'poule au pot',
         r'petit sale', r'saucisses aux lentilles', r'bouillabaisse', r'bourride', r'chili', r'dal\b', r'curry de (legumes|pois|patates)',
         r'lentilles mijotees', r'mafe', r'nasi goreng', r'saucisses au four'):
        return 'Mijoté complet'
    if a(t, r'quiche', r'^tarte', r'pizza', r'pissaladiere', r'galettes de sarrasin'):
        return 'Tarte salée et pizza'
    if a(t, r'^pates', r'spaghetti', r'tagliatelle', r'penne', r'fusilli', r'linguine', r'rigatoni', r'orecchiette', r'farfalle',
         r'tortellini', r'gnocchi', r'risotto', r'riz cremeux', r'^riz ', r'nouilles', r'pad thai', r'wok', r'saumon teriyaki et riz'):
        return 'Riz et pâtes garnis'
    if a(t, r'^bowl', r'^salade'):
        return 'Bowl et salade-repas'
    return None


def entree(t):
    if a(t, r'soupe', r'veloute', r'gaspacho', r'potage'): return 'Soupe et velouté'
    if a(t, r'salade', r'taboule', r'carottes rapees', r'remoulade', r'carpaccio', r'tomates mozzarella', r'chopska'):
        return 'Salade composée'
    if a(t, r'tarte', r'quiche', r'feuillete', r'chausson', r'tartelette', r'croque', r'cocotte', r'beignet', r'chevre chaud',
         r'spanakopita', r'samoussa'):
        return 'Entrée chaude'
    return 'Entrée froide'


def aperitif(t):
    if a(t, r'tartine', r'toast', r'bruschetta'):
        return 'Amuse-bouche'
    if a(t, r'rillettes', r'^dip', r'tartinade', r'^creme d', r'houmous', r'caviar', r'tapenade', r'tzatziki'):
        return 'Tartinade et dip'
    if a(t, r'feuillete', r'chausson', r'tartelette', r'bouchee'):
        return 'Bouchées et feuilletés'
    return None


def accompagnement(t):
    if a(t, r'lentille', r'flageolet', r'haricots (blancs|rouges|noirs)', r'pois chiches', r'pois casses'): return 'Légumineuses'
    if a(t, r'pommes? de terre', r'^riz', r'pates', r'semoule', r'boulgour', r'polenta', r'quinoa', r'macaroni', r'dauphin',
         r'sarladaise', r'boulangere', r'frites', r'chataigne'):
        return 'Féculents'
    return 'Légumes'


def sauce(t):
    if a(t, r'coulis', r'caramel', r'chocolat', r'anglaise'): return 'Sauce sucrée'
    if a(t, r'pesto', r'chimichurri', r'tapenade', r'chien', r'tartinade', r'harissa'): return 'Condiment'
    if a(t, r'mayonnaise', r'aioli', r'vinaigrette', r'tartare', r'cocktail', r'gribiche', r'ranch', r'yaourt', r'blanche',
         r'raita', r'vierge', r'tzatziki', r'citron et a l.aneth'):
        return 'Sauce froide et vinaigrette'
    return 'Sauce chaude'


def dessert(t):
    if a(t, r'glace', r'sorbet'): return 'Glace'
    if a(t, r'^tarte', r'tatin'): return 'Tarte'
    if a(t, r'^creme', r'mousse', r'panna cotta', r'ile flottante', r'oeufs a la neige', r'^flan', r'crumble'):
        return 'Fruits' if 'crumble' in t else 'Crème et mousse'
    if a(t, r'gateau', r'^cake', r'moelleux', r'fondant', r'brownie', r'quatre-quarts', r'marbre', r'clafoutis', r'mug cake',
         r'renverse'):
        return 'Gâteau'
    return 'Fruits'


def gouter(t):
    if a(t, r'crepe', r'gaufre', r'pancake', r'bugne', r'beignets aux pommes'): return 'Crêpes et gaufres'
    if a(t, r'cookie', r'sable', r'madeleine', r'financier', r'muffin'): return 'Biscuits et petits gâteaux'
    return None


def classer(r):
    """{type: sous-type} d'une recette."""
    if r['titre'] in PARTICULIERS:
        return dict(PARTICULIERS[r['titre']])
    if r.get('memo'):
        return {'Bases culinaires': 'Mémos techniques'}
    t = n(r['titre'])
    anciens = r['types']
    s = {}
    if 'Dessert' in anciens:
        g = gouter(t)
        if g:
            s['Petit-déjeuner et goûter'] = g
            if a(t, r'crepe', r'gaufre', r'beignet', r'bugne', r'muffin'):
                pass
            return s
        s['Dessert'] = dessert(t)
        if a(t, r'cake au citron', r'cake a la banane', r'quatre-quarts', r'marbre', r'gateau au yaourt'):
            s['Petit-déjeuner et goûter'] = 'Biscuits et petits gâteaux'
        return s
    if 'Sauces' in anciens and 'Plats' not in anciens:
        x = sauce(t)
        s['Sauces'] = x
        if x == 'Sauce sucrée': s['Dessert'] = 'Sauce sucrée'
        return s
    if 'Entrée' in anciens and 'Plats' not in anciens:
        ap = aperitif(t)
        if ap:
            s['Apéritif'] = ap
            if ap == 'Bouchées et feuilletés': s['Entrée'] = 'Entrée chaude'
            return s
        s['Entrée'] = entree(t)
        return s
    if 'Plats' in anciens:
        c = complet(t)
        if c:
            s['Plats complets'] = c
        else:
            s['Plats'] = nature_plat(r)
        if 'Sauces' in anciens: s['Sauces'] = 'Sauce chaude'
        if 'Plats accompagnement' in anciens: s['Plats accompagnement'] = accompagnement(t)
        if 'Entrée' in anciens: s['Entrée'] = entree(t)
        return s
    if 'Plats accompagnement' in anciens:
        return {'Plats accompagnement': accompagnement(t)}
    return {}


ORIGINE = [
    ('Italie', (r'risotto', r'riz cremeux', r'spaghetti', r'tagliatelle', r'penne', r'fusilli', r'linguine', r'rigatoni',
                r'orecchiette', r'farfalle', r'tortellini', r'gnocchi', r'lasagne', r'carbonara', r'amatriciana', r'cacio',
                r'puttanesca', r'arrabbiata', r'bolognaise', r'pesto\b', r'pates au pesto', r'pizza', r'focaccia', r'osso buco',
                r'tiramisu', r'panna cotta', r'bruschetta', r'carpaccio', r'polenta', r'parmesane', r'vongole', r'tomates mozzarella',
                r'frittata', r'burrata', r'gorgonzola', r'ricotta aux figues')),
    ('Espagne et Portugal', (r'paella', r'tortilla', r'gaspacho', r'chorizo', r'catalane', r'plancha')),
    ("Autres pays d'Europe", (r'goulash', r'carbonade', r'fish and chips', r'crumble', r'chopska', r'grecque', r'moussaka a',
                              r'^moussaka$', r'tzatziki', r'spanakopita', r'cordons bleus', r'pudding', r'cheesecake')),
    ('Maghreb et Moyen-Orient', (r'couscous', r'tajine', r'chakchouka', r'tchoutchouka', r'houmous', r'taboule', r'shawarma',
                                 r'kefta', r'pastilla', r'libanaise', r'melasse de grenade', r'citron confit', r'semoule aux raisins',
                                 r'tahini', r'dattes', r'cumin', r'pois chiches et cumin', r'boulgour aux abricots')),
    ('Afrique', (r'yassa', r'mafe')),
    ('Inde', (r'tikka', r'butter chicken', r'\bdal\b', r'raita', r'samoussa', r'a l.indienne', r'curry de', r'curry et',
              r'au curry doux', r'curry$', r'curcuma')),
    ('Asie', (r'teriyaki', r'bulgogi', r'bo bun', r'rouleaux de printemps', r'pad thai', r'nasi goreng', r'wok', r'nouilles',
              r'cantonnais', r'porc au caramel', r'aigre-douce', r'miso', r'okonomiyaki', r'citronnelle', r'satay',
              r'curry vert', r'riz frit', r'riz saute', r'tofu', r'sesame', r'gingembre et brocoli', r'mangues au citron vert et gingembre')),
    ('Amériques', (r'chili', r'fajitas', r'tacos', r'quesadilla', r'burger', r'mac and cheese', r'ribs', r'barbecue', r'ranch',
                   r'brownie', r'cookie', r'muffin', r'pancake', r'avocado', r'cesar', r'sauce chien', r'accras', r'chimichurri',
                   r'erable', r'haricots noirs', r'pecan', r'cornflakes', r'mug cake')),
]
# L'ordre compte : la première origine reconnue l'emporte ; ces titres sont fixés à la main.
ORIGINE_PARTICULIERE = {
    'Velouté de carottes au cumin': 'France', 'Velouté de lentilles et carottes au cumin': 'France',
    'Carottes rôties au miel et cumin': 'France', 'Tartinade de haricots rouges au cumin': 'France',
    'Soupe de pois cassés au cumin': 'France', 'Boulettes de bœuf à la menthe et cumin': 'Maghreb et Moyen-Orient',
    'Poulet au curry et aux pommes': 'France', 'Velouté de chou-fleur au curry': 'France',
    'Moules au curry': 'France', 'Sauce au curry doux et lait de coco': 'Inde',
    'Curry de poulet au lait de coco': 'Inde', 'Poulet au miel et au sésame': 'Asie',
    'Patates douces rôties au sésame': 'France', 'Bœuf sauté aux poivrons et sésame': 'Asie',
    'Crème au sésame noir': 'Asie', 'Crevettes au gingembre et sésame': 'Asie', 'Porc sauté au gingembre et miel': 'Asie',
    'Moussaka à ma façon': "Autres pays d'Europe", 'Moussaka': "Autres pays d'Europe", 'Salade grecque': "Autres pays d'Europe",
    'Taboulé de chou-fleur': 'France', 'Salade de quinoa, grenade et menthe': 'Maghreb et Moyen-Orient',
    'Boulettes d\'agneau au yaourt citronné': 'Maghreb et Moyen-Orient', 'Agneau aux aubergines et coriandre': 'Maghreb et Moyen-Orient',
    'Caviar d\'aubergine': 'France', 'Crème d\'aubergines au yaourt grec': "Autres pays d'Europe",
    'Gâteau renversé à l\'ananas': 'Amériques', 'Cake à la banane et aux noix': 'Amériques',
    'Cheesecake au citron sans cuisson': 'Amériques', 'Pavlova aux fruits exotiques': "Autres pays d'Europe",
    'Spaghettis à l\'ail et au piment': 'Italie', 'Pâtes carbonara': 'Italie', 'Pâtes à l\'amatriciana': 'Italie',
    'Pâtes au thon et à la tomate': 'France', 'Pâtes à la crème de courgettes': 'France',
    'Poêlée de pois chiches et aubergines': 'Maghreb et Moyen-Orient', 'Croque-monsieur au saumon fumé': 'France',
    'Curry de légumes et pois chiches': 'Inde', 'Curry de patates douces et épinards': 'Inde', 'Curry de pois chiches et épinards': 'Inde',
    'Chou-fleur rôti entier au curcuma': 'Inde', 'Plancha': 'France', 'Calamars grillés à la plancha': 'Espagne et Portugal',
    'Tentacules de poulpe à la plancha': 'Espagne et Portugal', 'Sauce barbecue maison': 'Amériques',
    'Crevettes au barbecue': 'France', 'Pommes de terre à la grecque': "Autres pays d'Europe",
    'Sauce tomate': 'France', 'Spaghettis à la sauce tomate et basilic': 'Italie', 'Gnocchis à la sauce gorgonzola': 'Italie',
    'Riz basmati à l\'indienne': 'Inde', 'Cake aux dattes et aux épices': 'France',
    'Sauce crémeuse au citron confit': 'France', 'Escalopes milanaises': 'Italie', 'Mousse à la mangue': 'France',
}


def origine(r):
    if r['titre'] in ORIGINE_PARTICULIERE: return ORIGINE_PARTICULIERE[r['titre']]
    t = n(r['titre'])
    for o, mots in ORIGINE:
        if a(t, *mots): return o
    return 'France'


def ordonner(s):
    return {k: s[k] for k in TYPES if k in s}


def appliquer(recettes):
    for r in recettes:
        s = ordonner(classer(r))
        assert s, r['titre']
        for k, v in s.items():
            assert v in TYPES[k], (r['titre'], k, v)
        r['types'] = list(s)
        r['sousTypes'] = s
        r['origine'] = origine(r)


def main():
    sys.path.insert(0, os.path.dirname(__file__))
    from nouvelles_298_497 import FOURNIES
    src = json.load(open(FOURNIES, encoding='utf-8'))
    appliquer(src['recettes'])
    src['version'] = src.get('version', 1) + 1
    json.dump(src, open(FOURNIES, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f"{len(src['recettes'])} recettes classées, version {src['version']}")


if __name__ == '__main__':
    main()
