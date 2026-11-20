"""Critères d'une recette (20/11/2026, Aristide) : régime, saison, coût, mode de cuisson, occasion.
Première proposition calculée d'après les ingrédients, les étapes et le titre ; à corriger dans la console.
  regimes   : Végétarien, Végétalien, Sans gluten, Sans lactose
  saisons   : Printemps, Été, Automne, Hiver (les quatre = toute l'année)
  cout      : €, €€, €€€
  cuissons  : Sans cuisson, Four, Plaque, Cocotte-minute
  occasions : Quotidien, À l'avance, À recevoir, À emporter"""
import re, unicodedata


def plat(x):
    x = x.lower().replace('œ', 'oe').replace('’', "'")
    return ''.join(c for c in unicodedata.normalize('NFD', x) if unicodedata.category(c) != 'Mn')


def _a(texte, mots):
    return any(re.search(r'\b' + m, texte) for m in mots)


VIANDE = ['poulet', 'boeuf', 'veau', 'porc', 'agneau', 'canard', 'dinde', 'pintade', 'lapin', 'jambon', 'lardon', 'lard\\b',
          'saucisse', 'chorizo', 'bacon', 'rognon', 'magret', 'gigot', 'cote', 'roti de', 'steak', 'hache', 'merguez',
          'poule\\b', 'coq\\b', 'foie gras', 'boudin', 'filet mignon', 'echine', 'epaule', 'travers', 'ribs', 'osso',
          'escalope', 'cordon', 'andouille', 'gelatine', 'bouillon de volaille', 'bouillon de boeuf', 'fond de veau',
          'cervelas', 'chair a saucisse', 'pancetta', 'coppa', 'viande']
POISSON = ['poisson', 'saumon', 'thon', 'cabillaud', 'morue', 'lieu', 'merlu', 'truite', 'daurade', 'dorade', 'sole',
           'lotte', 'maquereau', 'sardine', 'anchois', 'haddock', 'rouget', 'bar\\b', 'colin', 'crevette', 'moule',
           'palourde', 'vongole', 'saint-jacques', 'coquille', 'calamar', 'encornet', 'seiche', 'poulpe', 'fruits de mer',
           'langoustine', 'homard', 'crabe', 'surimi', 'oeufs de lump', 'tarama', 'nuoc', 'sauce poisson']
SANS_LAIT = "(?! de (coco|soja|riz|sesame|marrons|cassis|chataigne)| d'amande| vegetal)"
ANIMAL = ['oeuf', 'lait\\b' + SANS_LAIT, 'beurre(?! de cacahuete)', 'creme' + SANS_LAIT, 'fromage', 'yaourt', 'miel', 'parmesan', 'gruyere', 'comte',
          'mozzarella', 'feta', 'chevre', 'ricotta', 'mascarpone', 'roquefort', 'bleu\\b', 'gorgonzola', 'emmental',
          'reblochon', 'raclette', 'burrata', 'cancoillotte', 'pecorino', 'cheddar', 'brousse', 'petit-suisse',
          'mayonnaise', 'chantilly', 'meringue', 'brioche', 'pate feuilletee', 'pate brisee', 'beaufort', 'tomme']
LAIT = ['lait\\b' + SANS_LAIT, 'beurre(?! de cacahuete)', 'creme' + SANS_LAIT, 'fromage', 'yaourt', 'parmesan', 'gruyere', 'comte', 'mozzarella', 'feta',
        'chevre', 'ricotta', 'mascarpone', 'roquefort', 'bleu\\b', 'gorgonzola', 'emmental', 'reblochon', 'raclette',
        'burrata', 'cancoillotte', 'pecorino', 'cheddar', 'brousse', 'petit-suisse', 'chantilly', 'beaufort', 'tomme',
        'chocolat blanc', 'chocolat au lait', 'pate feuilletee', 'brioche', 'bechamel', 'praline']
GLUTEN = ['farine', "pate\\b(?! de (curry|pistache|sesame|amande|coing|fruits?|dattes?))", 'pates\\b', 'pate a', 'pate feuilletee', 'pate brisee', 'pate sablee', 'spaghetti', 'penne',
          'tagliatelle', 'linguine', 'fusilli', 'farfalle', 'rigatoni', 'orecchiette', 'macaroni', 'lasagne', 'gnocchi',
          'nouille', 'vermicelle', 'pain', 'baguette', 'brioche', 'chapelure', 'biscuit', 'boulgour', 'semoule', 'couscous',
          'ble\\b', 'orge', 'seigle', 'epeautre', 'tortilla', 'galette des rois', 'biere', 'sauce soja', 'croute',
          'toast', 'tartine', 'bruschetta', 'crepe', 'gaufre', 'cake', 'madeleine', 'sable', 'cookie', 'muffin',
          'financier', 'crumble', 'quatre-quarts', 'genoise', 'pizza', 'focaccia', 'feuillete', 'chausson', 'tartelette',
          'tarte', 'quiche', 'pissaladiere', 'croque', 'hamburger', 'roux', 'pane', 'chapelure', 'cordon']

PRINTEMPS = ['asperge', 'petits pois', 'radis', 'feve', 'artichaut', 'fraise', 'rhubarbe', 'printanier', 'epinard',
             'carottes nouvelles', 'agneau', 'cerise']
ETE = ['tomate', 'courgette', 'aubergine', 'poivron', 'concombre', 'melon', 'pasteque', 'peche', 'abricot', 'prune',
       'myrtille', 'framboise', 'cerise', 'figue', 'basilic', 'haricots verts', '(?<=\\| )mais\\b', 'gaspacho', 'ratatouille',
       'barbecue', 'plancha', 'fleur', 'pistou', 'fraise', 'tian', 'vierge', 'salade de']
AUTOMNE = ['potiron', 'courge', 'butternut', 'champignon', 'cepe', 'girolle', 'chataigne', 'marron', 'poire', 'pomme',
           'raisin', 'cerneaux de noix', 'noix\\b(?! de (muscade|coco|saint))', 'noisette', 'coing', 'figue', 'patate douce', 'panais', 'betterave', 'chou', 'celeri',
           'fenouil', 'brocoli', 'blette']
HIVER = ['poireau', 'chou', 'navet', 'endive', 'panais', 'topinambour', 'celeri', 'orange', 'clementine', 'mandarine',
         'pamplemousse', 'kiwi', 'pot-au-feu', 'potee', 'raclette', 'fondue', 'tartiflette', 'choucroute', 'cassoulet',
         'daube', 'bourguignon', 'pois casses', 'mijote', 'braise', 'marrons', 'chataigne', 'carbonade', 'poule au pot']

CHER = ['saint-jacques', 'lotte', 'foie gras', 'homard', 'langoustine', 'magret', 'filet mignon', 'gigot', 'sole',
        'bar\\b', 'turbot', 'truffe', 'rumsteck', 'filet de boeuf', 'roti de boeuf', 'veau', 'pignons', 'pistache',
        'safran', 'champignons des bois', 'morille', 'cepe', 'burrata', 'saumon fume', 'truite fumee', 'crevettes',
        'palourde', 'vongole', 'agneau', 'canard', 'rouget', 'daurade', 'dorade', 'bouillabaisse', 'osso']
ECO = ['lentille', 'pois chiche', 'haricot', 'pois casse', 'pomme de terre', 'pommes de terre', 'riz', 'semoule', 'pates',
       'oeuf', 'carotte', 'chou', 'oignon', 'farine', 'pain', 'courgette', 'potiron', 'courge', 'poireau', 'navet',
       'betterave', 'boulgour', 'compote', 'crepe', 'gaufre', 'yaourt', 'lait']

RECEVOIR = ['foie gras', 'saint-jacques', 'lotte', 'homard', 'magret', 'gigot', 'filet mignon', 'bouillabaisse',
            'coq au vin', 'blanquette', 'bourguignon', 'osso buco', 'dinde aux marrons', 'pintade', 'roti', 'paella',
            'couscous', 'tajine', 'charlotte', 'tarte', 'galette des rois', 'tiramisu', 'mousse', 'creme brulee',
            'carpaccio', 'risotto', 'fondue', 'raclette', 'navarin', 'souffle', 'daube', 'cassoulet', 'choucroute',
            'veau marengo', 'poires belle', 'ile flottante', 'oeufs a la neige', 'beurre blanc', 'bearnaise', 'hollandaise']
EMPORTER = ['salade', 'cake', 'quiche', 'tarte', 'feuillete', 'chausson', 'tartelette', 'taboule', 'rillettes', 'houmous',
            'tartinade', 'dip', 'tzatziki', 'caviar', 'sandwich', 'muffin', 'cookie', 'brownie', 'madeleine', 'financier',
            'sable', 'focaccia', 'pissaladiere', 'tortilla', 'wrap', 'fajitas', 'pizza', 'oeufs mimosa', 'galettes de',
            'crumble', 'quatre-quarts', 'marbre', 'gateau']
AVANCE = ['mijote', 'braise', 'daube', 'bourguignon', 'blanquette', 'pot-au-feu', 'tajine', 'cassoulet', 'chili',
          'curry', 'navarin', 'carbonade', 'coq au vin', 'osso', 'veau marengo', 'lasagne', 'moussaka', 'hachis',
          'parmentier', 'gratin', 'soupe', 'veloute', 'gaspacho', 'rillettes', 'terrine', 'tiramisu', 'panna cotta',
          'mousse', 'creme', 'charlotte', 'compote', 'cake', 'salade de lentilles', 'taboule', 'houmous', 'caviar',
          'tartinade', 'dip', 'pralines', 'truffes', 'flan', 'riz au lait', 'foie gras', 'ratatouille', 'sauce']


def criteres(r):
    titre = plat(r['titre'])
    ing = plat(' | '.join(d.get('nom', '') + ' ' + d.get('precision', '') for d in r.get('detail') or []) or
               ' | '.join(r.get('ingredients') or []))
    etapes = plat(' '.join(r.get('etapes') or []) or r.get('preparation', ''))
    tout = titre + ' | ' + ing
    types = r.get('types') or []

    regimes = []
    if not _a(tout, VIANDE) and not _a(tout, POISSON):
        regimes.append('Végétarien')
        if not _a(tout, ANIMAL):
            regimes.append('Végétalien')
    if not _a(tout, GLUTEN):
        regimes.append('Sans gluten')
    if not _a(tout, LAIT):
        regimes.append('Sans lactose')

    # « pomme de terre » n'est pas une pomme ; les herbes et condiments ne donnent pas de saison.
    produits = re.sub(r'pommes? de terre', 'patate', tout)
    saisons = [s for s, mots in (('Printemps', PRINTEMPS), ('Été', ETE), ('Automne', AUTOMNE), ('Hiver', HIVER))
               if _a(produits, mots)]
    if not saisons or 'Sauces' in types:
        saisons = ['Printemps', 'Été', 'Automne', 'Hiver']

    if _a(tout, CHER):
        cout = '€€€'
    elif _a(tout, VIANDE) or _a(tout, POISSON) or not _a(tout, ECO):
        cout = '€€'
    else:
        cout = '€'

    cuissons = []
    if _a(etapes, ['four', 'enfourner', 'gril\\b', 'gratiner']):
        cuissons.append('Four')
    if _a(etapes, ['poele', 'casserole', 'cocotte', 'sauteuse', 'wok', 'faitout', 'plancha', 'bain-marie', 'mijoter',
                   'revenir', 'fondre', 'bouillante', 'porter a ebullition', 'frire', 'saisir', 'dorer', 'cuire']) \
            and not (cuissons and not _a(etapes, ['poele', 'casserole', 'cocotte', 'sauteuse', 'wok', 'faitout', 'plancha',
                                                   'bain-marie', 'bouillante', 'ebullition'])):
        cuissons.append('Plaque')
    if _a(etapes + ' ' + titre, ['cocotte-minute', 'autocuiseur']):
        cuissons.append('Cocotte-minute')
    if r.get('tempsCuisson') == 0 or not cuissons:
        cuissons = ['Sans cuisson']

    occasions = []
    total = (r.get('tempsPreparation') or 0) + (r.get('tempsCuisson') or 0)
    if not _a(titre, RECEVOIR) and (total == 0 or total <= 60) and r.get('difficulte') in (None, 'Facile', 'Moyen'):
        occasions.append('Quotidien')
    if _a(titre, AVANCE) or 'Sauces' in types:
        occasions.append("À l'avance")
    if _a(titre, RECEVOIR) or cout == '€€€' or r.get('difficulte') in ('Difficile', 'Avancé'):
        occasions.append('À recevoir')
    if _a(titre, EMPORTER):
        occasions.append('À emporter')
    if not occasions:
        occasions = ['Quotidien']
    return dict(regimes=regimes, saisons=saisons, cout=cout, cuissons=cuissons, occasions=occasions)
