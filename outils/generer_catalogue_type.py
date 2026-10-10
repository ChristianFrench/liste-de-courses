"""Catalogue type d'un magasin français : rayons, secteurs, produits courants, en trois tailles.

Taille : 1 = proximité, 2 = supermarché, 3 = hypermarché. Un secteur ou un produit marqué
d'une taille n'existe qu'à partir de cette taille. Produit suivi de « + » : supermarché et plus ;
de « ++ » : hypermarché seulement.

Sorties (à côté de ce script) :
- catalogue-type.json : le référentiel, pour l'application (« Nouveau magasin à partir d'un modèle »)
- catalogue-type.sql  : trois magasins exemples au format du schéma v2
"""
import json, pathlib, uuid

ICI = pathlib.Path(__file__).parent

# rayon -> [(secteur, taille, "produit; produit+; produit++")]
CATALOGUE = {
    "Fruits et légumes": [
        ("Fruits", 1, "Pommes; Poires; Bananes; Oranges; Clémentines; Citrons; Raisin; Kiwis; Fraises+; Melon+; Pêches+; Abricots+; Ananas+; Mangue++; Avocats; Nectarines; Cerises+; Prunes; Pamplemousse; Mandarines; Figues+; Fruits de la passion+; Citrons verts; Framboises+; Myrtilles+; Kakis+; Pastèque"),
        ("Légumes", 1, "Pommes de terre; Carottes; Oignons; Ail; Échalotes; Tomates; Courgettes; Concombre; Poivrons; Aubergines+; Poireaux; Haricots verts+; Brocoli+; Chou-fleur+; Champignons de Paris; Endives+; Céleri++; Radis+; Betteraves cuites+; Patates douces; Navets; Courge butternut; Potiron+; Épinards; Chou vert; Chou rouge+; Fenouil+; Asperges+; Artichauts+; Panais+; Tomates cerises; Gingembre+"),
        ("Salades et herbes", 1, "Salade verte; Mâche; Roquette+; Persil; Ciboulette+; Basilic+; Coriandre++; Menthe++; Laitue; Batavia; Feuille de chêne; Frisée+; Jeunes pousses d'épinards+; Aneth+; Estragon+; Thym frais+; Romarin frais+; Cerfeuil+"),
        ("Fraîche découpe", 2, "Salade en sachet; Crudités râpées; Fruits découpés++; Légumes pour soupe prêts à cuire++; Poêlée de légumes fraîche; Légumes pour wok; Courgettes en spaghetti; Champignons émincés; Oignons émincés; Haricots verts équeutés; Pommes de terre épluchées"),
        ("Jus de fruits frais", 2, "Jus d'orange frais; Smoothie; Jus de pamplemousse frais; Jus de pomme frais; Jus multifruits frais; Gaspacho; Citronnade; Jus de carotte frais++"),
        ("Fruits secs et graines", 2, "Noix; Amandes; Raisins secs; Pruneaux; Noisettes++; Graines de courge++; Noix de cajou; Abricots secs; Dattes; Figues sèches; Cranberries séchées; Graines de tournesol; Graines de lin++; Mélange étudiant; Noix de pécan++; Pignons de pin"),
    ],
    "Boucherie": [
        ("Boucherie libre-service", 1, "Steak haché; Viande hachée; Rôti de porc+; Côtes de porc; Escalopes de veau++; Bœuf bourguignon+; Saucisses; Merguez+; Chipolatas+; Pavés de bœuf+; Bavette+; Rumsteck+; Bœuf pour pot-au-feu+; Rôti de bœuf+; Filet mignon de porc+; Échine de porc+; Poitrine de porc+; Sauté de porc+; Brochettes de bœuf+; Paupiettes de veau+; Côtelettes d'agneau+"),
        ("Boucherie traditionnelle et Volailles", 3, "Entrecôte; Gigot d'agneau; Côte de bœuf; Blanquette de veau; Faux-filet; Filet de bœuf; Tournedos; Épaule d'agneau; Navarin d'agneau; Jarret de veau; Osso-buco; Tête de veau; Carré d'agneau; Tendrons de veau; Joues de bœuf"),
        ("Produits du terroir", 3, "Foie gras; Confit de canard; Spécialités régionales; Gésiers confits; Magret de canard séché; Escargots; Graisse de canard; Andouillette; Andouille"),
    ],
    "Volaille": [
        ("Volaille libre-service", 1, "Blancs de poulet; Cuisses de poulet; Poulet entier+; Escalopes de dinde; Aiguillettes de poulet+; Pilons de poulet; Ailes de poulet+; Hauts de cuisse de poulet+; Magret de canard+; Cuisses de canard+; Rôti de dinde+; Cordons bleus; Pintade+; Lapin+; Brochettes de poulet+; Sauté de dinde+"),
        ("Rôtisserie", 3, "Poulet rôti; Cuisses de poulet rôties; Pommes de terre rôtisserie; Jarret de porc rôti; Travers de porc rôtis; Pintade rôtie"),
    ],
    "Poissonnerie": [
        ("Poissonnerie libre-service", 2, "Filets de saumon; Filets de cabillaud; Crevettes cuites; Saumon fumé; Surimi; Moules++; Filets de lieu; Truite fumée; Filets de merlu; Crevettes crues; Filets de truite; Harengs marinés; Maquereau fumé; Œufs de lump; Gambas++"),
        ("Poissonnerie traditionnelle", 3, "Poisson du jour; Huîtres; Coquillages; Bar; Daurade; Sole; Lotte; Thon frais; Langoustines; Bulots; Coquilles Saint-Jacques; Tourteau; Encornets; Merlan; Raie"),
    ],
    "Crèmerie": [
        ("Lait", 1, "Lait demi-écrémé; Lait entier; Lait écrémé+; Lait sans lactose+; Boisson végétale avoine+; Boisson soja++; Lait de chèvre+; Lait chocolaté; Boisson amande+; Boisson riz+; Lait fermenté++; Lait de croissance+; Boisson coco++; Lait frais microfiltré+"),
        ("Beurre, œufs, crème", 1, "Beurre doux; Beurre demi-sel; Œufs; Crème fraîche épaisse; Crème liquide; Margarine+; Crème fraîche légère; Crème chantilly; Beurre allégé+; Beurre de baratte+; Crème végétale+; Œufs de caille++; Beurre clarifié++; Blancs d'œufs liquides++"),
        ("Yaourts et desserts", 1, "Yaourts nature; Yaourts aux fruits; Fromage blanc; Petits-suisses+; Crèmes desserts; Compotes en coupelles+; Skyr++; Yaourts à boire+; Yaourts à la grecque; Yaourts au lait de brebis+; Yaourts au soja+; Mousse au chocolat; Riz au lait; Flans; Îles flottantes+; Liégeois; Faisselle; Yaourts allégés; Panna cotta+; Tiramisu+; Gâteau de semoule+; Kéfir+"),
    ],
    "Fromagerie": [
        ("Fromages libre-service", 1, "Emmental râpé; Camembert; Comté; Mozzarella; Chèvre bûche; Raclette+; Roquefort+; Fromage à tartiner; Feta+; Parmesan+; Coulommiers++; Brie; Reblochon; Emmental en tranches; Saint-Nectaire+; Cantal+; Morbier+; Munster+; Tomme de Savoie+; Bleu d'Auvergne+; Mimolette+; Ricotta+; Mascarpone+; Burrata+; Halloumi++; Cheddar en tranches+; Saint-Marcellin+; Gouda+; Chèvre frais+; Fromages en portions"),
        ("Fromages à la coupe", 3, "Fromage à la coupe; Beaufort; Chaource; Pont-l'évêque; Abondance; Ossau-iraty; Époisses; Livarot; Salers; Fourme d'Ambert; Tomme de brebis"),
    ],
    "Charcuterie": [
        ("Charcuterie libre-service", 1, "Jambon blanc; Jambon cru+; Saucisson sec; Pâté; Rillettes+; Chorizo+; Lardons; Allumettes de bacon+; Blanc de poulet tranché+; Jambon de dinde; Boudin noir+; Boudin blanc+; Saucisses de Strasbourg; Mortadelle+; Coppa+; Rosette+; Pancetta+; Poitrine fumée; Salami; Jambon persillé++; Viande des Grisons++; Fromage de tête+"),
        ("Charcuterie à la coupe", 3, "Jambon à la coupe; Saucisson à la coupe; Pâté en croûte; Terrine à la coupe; Jambon de Bayonne; Jambon de Parme; Lomo; Saucisse sèche; Galantine; Tête roulée; Jambon à l'os"),
    ],
    "Traiteur": [
        ("Traiteur frais", 2, "Taboulé; Salade piémontaise; Pizza fraîche; Quiche lorraine; Houmous++; Plats cuisinés frais; Céleri rémoulade; Salade de pâtes; Salade de riz; Tarama; Tzatziki; Guacamole; Sandwichs; Hachis parmentier; Lasagnes fraîches; Nems; Samoussas; Croque-monsieur; Sushis; Accras de morue"),
        ("Pâtes fraîches et pâtes à tarte", 1, "Pâtes fraîches; Raviolis frais+; Gnocchis+; Pâte feuilletée; Pâte brisée; Pâte à pizza; Pâte sablée+; Pâte filo++; Tortellini+; Ravioles du Dauphiné+; Galettes de sarrasin+; Pâte à crêpes prête+"),
        ("Traiteur à la coupe", 3, "Plat du jour traiteur; Salade traiteur; Paella; Choucroute garnie; Couscous royal; Pizza à la part; Bouchées à la reine; Brandade de morue"),
    ],
    "Boulangerie": [
        ("Pain", 1, "Baguette; Pain de campagne+; Pain de mie; Pain complet+; Pains burger+; Wraps+; Pain aux céréales; Pain de seigle+; Ficelle; Baguette tradition; Pain sans gluten+; Pains hot-dog+; Pain pita+; Pain précuit; Bagels+; Pain viennois"),
    ],
    "Viennoiserie et pâtisserie": [
        ("Viennoiserie", 1, "Croissants; Pains au chocolat; Brioche; Pains au lait; Madeleines+; Pains aux raisins; Chaussons aux pommes; Croissants aux amandes+; Muffins+; Donuts+; Gaufres; Pancakes+; Chouquettes+; Galette des rois+"),
        ("Pâtisserie", 3, "Tarte aux fruits; Éclairs; Gâteau d'anniversaire; Flan pâtissier; Millefeuille; Paris-brest; Tarte au citron; Fraisier; Choux à la crème; Macarons; Bûche de Noël; Tropézienne; Religieuse"),
    ],
    "Épicerie salée": [
        ("Pâtes, riz et féculents", 1, "Pâtes spaghetti; Pâtes coquillettes; Pâtes penne; Riz long; Riz basmati+; Semoule; Lentilles+; Quinoa++; Purée en flocons+; Pois chiches+; Pâtes tagliatelles; Pâtes fusilli; Pâtes macaroni; Pâtes à lasagnes; Vermicelles; Pâtes complètes+; Riz rond; Riz thaï; Riz complet+; Riz à risotto+; Boulgour+; Lentilles corail+; Polenta+; Nouilles chinoises+"),
        ("Conserves", 1, "Thon en boîte; Sardines; Haricots verts en boîte; Petits pois carottes; Maïs; Tomates pelées; Concentré de tomate; Ratatouille+; Cassoulet+; Raviolis en boîte+; Maquereaux+; Flageolets; Champignons en boîte; Cœurs de palmier+; Fonds d'artichaut+; Miettes de crabe+; Salsifis+; Épinards en boîte+"),
        ("Sauces et condiments", 1, "Huile de tournesol; Huile d'olive; Vinaigre; Moutarde; Mayonnaise; Ketchup; Sauce tomate; Pesto+; Sauce soja+; Cornichons; Olives+; Vinaigrette+; Huile de colza; Vinaigre balsamique+; Sauce barbecue; Sauce béarnaise; Sauce burger+; Harissa; Câpres+; Sauce bolognaise+; Tapenade+; Sauce samouraï+; Sauce piquante+; Huile de sésame++; Sauce carbonara+; Sauce aigre-douce+; Nuoc-mâm++"),
        ("Sel, épices et aides culinaires", 1, "Sel; Poivre; Bouillon cube; Herbes de Provence; Paprika+; Curry+; Cumin++; Fond de veau++; Levure chimique; Fécule de maïs+; Noix de muscade+; Cannelle; Origan+; Piment d'Espelette+; Ras el hanout+; Curcuma+; Laurier; Quatre-épices+; Fleur de sel+; Fumet de poisson+; Piment de Cayenne+; Roux+"),
        ("Soupes et plats préparés", 2, "Soupe en brique; Soupe déshydratée; Plat cuisiné en conserve; Nouilles instantanées; Croûtons; Chili con carne; Soupe de poisson; Soupe miso++; Plats cuisinés en barquette; Salade composée en boîte; Saucisses lentilles"),
    ],
    "Bio, vrac et terroir": [
        ("Diététique et bio", 2, "Galettes de riz; Produits sans gluten; Lait d'amande++; Graines de chia++; Lait d'avoine; Lait de soja; Boisson au riz; Galettes de maïs; Pâtes sans gluten; Farine sans gluten++; Tofu; Edulcorant; Biscuits sans sucre++"),
        ("Vrac", 3, "Pâtes en vrac; Riz en vrac; Légumineuses en vrac; Fruits secs en vrac; Céréales en vrac; Café en vrac; Bonbons en vrac; Graines en vrac; Farine en vrac; Flocons d'avoine en vrac"),
    ],
    "Apéritif": [
        ("Chips et biscuits apéritif", 1, "Chips; Biscuits apéritif; Tortillas chips+; Crackers; Bretzels; Gressins+; Popcorn; Chips de légumes+; Biscuits soufflés; Toasts apéritif+; Sauce pour chips+"),
        ("Fruits secs salés et olives", 1, "Cacahuètes; Pistaches+; Olives apéritif+; Mélange apéritif++; Amandes grillées; Olives vertes; Olives noires; Olives farcies+; Graines de tournesol salées+; Tomates séchées+; Cornichons apéritif+"),
    ],
    "Cuisine du monde": [
        ("Asie", 3, "Nouilles de riz; Sauce nuoc-mâm; Lait de coco; Riz basmati thaï; Feuilles de riz; Pâte de curry thaï; Wasabi; Riz pour sushi; Algues nori; Gingembre mariné; Nems surgelés; Sauce teriyaki"),
        ("Mexique et Amérique", 3, "Tortillas; Haricots rouges; Sauce salsa; Kit fajitas; Kit tacos; Piments jalapeños; Haricots noirs; Sauce chili; Sirop d'érable; Beurre de cacahuète crunchy"),
        ("Orient et Inde", 3, "Sauce curry; Épices du monde; Couscous préparé; Pâte de curry indienne; Galettes naan; Chutney de mangue; Feuilles de brick; Thé à la menthe"),
        ("Italie", 1, "Sauce tomate basilic; Antipasti+; Risotto+; Ravioles fraîches+; Sauce arrabbiata+; Pâtes fraîches farcies+"),
        ("Espagne", 1, "Paella préparée+; Riz pour paella+; Jambon serrano; Tapas+; Poivrons piquillos++; Fromage manchego++; Pimentón++; Calamars à la romaine+; Turrón++"),
    ],
    "Petit-déjeuner": [
        ("Café", 1, "Café moulu; Café en dosettes; Café soluble+; Café en grains++; Café décaféiné; Capsules de café; Dosettes souples; Chicorée; Filtres à café; Boisson café au lait soluble+"),
        ("Thé et chocolat en poudre", 1, "Thé; Infusion+; Chocolat en poudre; Thé vert; Thé noir; Tisane verveine; Camomille; Rooibos+; Thé earl grey; Chocolat instantané; Infusion menthe; Boisson maltée+"),
        ("Céréales", 1, "Céréales; Muesli+; Flocons d'avoine+; Corn-flakes; Céréales chocolatées; Pétales au miel; Granola; Céréales fourrées; Céréales enfant; Son d'avoine+; Céréales complètes"),
        ("Biscottes et tartines", 1, "Biscottes; Pain grillé+; Tartines craquantes++; Brioche tranchée; Pains suédois+; Biscottes complètes; Biscottes sans sel+; Pain azyme++"),
        ("Confitures et pâtes à tartiner", 1, "Confiture de fraises; Confiture d'abricots+; Miel; Pâte à tartiner chocolat; Beurre de cacahuète++; Confiture de framboises; Confiture de cerises; Confiture d'oranges amères; Confiture de fruits rouges; Gelée de groseilles+; Pâte à tartiner noisette; Crème de marrons; Miel liquide; Pâte de spéculoos+; Confiture allégée en sucre+; Lemon curd++"),
    ],
    "Biscuits et sucré": [
        ("Biscuits et gâteaux", 1, "Biscuits secs; Biscuits au chocolat; Gâteaux moelleux; Barres de céréales+; Pain d'épices+; Crêpes+; Petits-beurre; Sablés; Cookies; Biscuits fourrés; Galettes bretonnes; Boudoirs; Quatre-quarts; Barres chocolatées; Spéculoos; Palmiers; Tartelettes; Biscuits pour le goûter; Cake aux fruits"),
        ("Chocolat et confiserie", 1, "Tablette de chocolat noir; Tablette de chocolat au lait; Bonbons; Chewing-gums; Chocolat pâtissier+; Chocolat blanc; Chocolat aux noisettes; Rochers au chocolat; Bonbons sans sucre; Guimauves; Réglisse; Caramels; Pastilles; Œufs en chocolat+; Truffes au chocolat+; Chocolats de Noël+; Pâtes de fruits+"),
        ("Sucre, farine et pâtisserie", 1, "Sucre en poudre; Sucre en morceaux; Farine; Sucre vanillé+; Préparation pour gâteau+; Levure boulangère++; Sucre roux; Cassonade; Sucre glace; Farine complète+; Poudre d'amande; Arôme vanille; Gousse de vanille+; Pépites de chocolat; Vermicelles colorés+; Préparation pour crêpes; Cacao en poudre non sucré+; Sucre de canne+; Noix de coco râpée; Gélatine+; Pâte à sucre++"),
        ("Compotes et fruits au sirop", 2, "Compote en gourdes; Compote en pot; Fruits au sirop; Compote sans sucre ajouté; Pêches au sirop; Ananas au sirop; Poires au sirop; Cocktail de fruits; Purée de fruits; Abricots au sirop; Mangue en conserve++"),
    ],
    "Surgelés": [
        ("Légumes surgelés", 1, "Petits pois surgelés; Haricots verts surgelés; Épinards surgelés; Poêlée de légumes; Frites surgelées; Mélange pour soupe+; Brocolis surgelés; Haricots plats surgelés+; Choux-fleurs surgelés; Carottes surgelées+; Champignons surgelés+; Ratatouille surgelée+; Herbes surgelées; Oignons surgelés+; Potatoes surgelées; Pommes noisettes; Légumes pour couscous surgelés+; Purée surgelée+; Haricots beurre surgelés+"),
        ("Viandes et poissons surgelés", 1, "Poisson pané; Steaks hachés surgelés; Nuggets de poulet+; Crevettes surgelées+; Filets de cabillaud surgelés+; Filets de saumon surgelés; Moules surgelées+; Calamars surgelés+; Cordons bleus surgelés; Escalopes de poulet surgelées+; Fruits de mer surgelés+; Colin surgelé; Cuisses de poulet surgelées+; Saint-Jacques surgelées+; Pavés de merlu surgelés+"),
        ("Plats et pizzas surgelés", 1, "Pizza surgelée; Plat cuisiné surgelé+; Lasagnes surgelées+; Feuilletés+; Quiche surgelée; Croque-monsieur surgelé; Hachis parmentier surgelé; Gratin surgelé+; Paella surgelée+; Pâte feuilletée surgelée+; Viennoiseries surgelées+; Pain surgelé+; Tartes surgelées+; Burgers surgelés+; Petits fours surgelés+; Samoussas surgelés+; Fruits rouges surgelés"),
    ],
    "Glaces": [
        ("Glaces", 1, "Glace en bac; Cônes glacés; Esquimaux+; Sorbet+; Glace vanille; Glace chocolat; Barres glacées; Glace à l'italienne+; Pots de glace individuels; Glace sans lactose++"),
        ("Desserts glacés", 2, "Bûche glacée++; Vacherin glacé++; Mini-glaces; Profiteroles; Nougat glacé++; Omelette norvégienne++; Tarte glacée++; Macarons glacés++; Mochis glacés++; Coupes glacées; Gâteau glacé"),
    ],
    "Eaux et boissons sans alcool": [
        ("Eaux", 1, "Eau plate; Eau gazeuse; Eau aromatisée+; Eau minérale; Eau de source; Petites bouteilles d'eau; Bonbonne d'eau+; Eau riche en magnésium+"),
        ("Jus de fruits", 1, "Jus d'orange; Jus de pomme+; Jus multifruits+; Jus de pamplemousse; Jus d'ananas; Jus de raisin; Jus de tomate; Nectar d'abricot; Jus de fruits frais+; Nectar de mangue+; Briquettes de jus"),
        ("Sodas et sirops", 1, "Cola; Limonade; Sirop; Thé glacé+; Boisson énergisante++; Cola zéro; Soda à l'orange; Tonic; Ginger ale+; Sirop de menthe; Sirop de grenadine; Sirop de citron; Kombucha+; Sirop d'orgeat+"),
    ],
    "Cave": [
        ("Bières et cidres", 1, "Bière blonde; Bière sans alcool+; Cidre+; Bière ambrée++; Bière blanche; Bière brune+; Bière IPA+; Bière d'abbaye; Panaché; Bière aromatisée+; Cidre doux; Cidre brut; Fût de bière++"),
        ("Vins", 1, "Vin rouge; Vin blanc; Vin rosé; Vin de Bordeaux; Vin de Bourgogne+; Côtes-du-rhône; Muscadet+; Vin en cubi; Vin sans alcool+; Vin moelleux+; Sangria"),
        ("Champagnes et mousseux", 2, "Champagne; Mousseux; Crémant; Prosecco; Cava++; Clairette de Die++; Champagne rosé; Blanquette de Limoux++; Pétillant sans alcool; Asti++"),
        ("Alcools et apéritifs", 2, "Pastis; Whisky; Rhum++; Porto++; Vodka; Gin; Martini blanc; Crème de cassis; Calvados++; Cognac++; Liqueur; Rhum arrangé++; Muscat; Kir; Spritz; Tequila++"),
    ],
    "Bébé": [
        ("Alimentation bébé", 2, "Lait infantile; Petits pots; Céréales bébé; Compotes bébé; Plats bébé; Biscuits bébé; Petits pots légumes; Desserts lactés bébé; Eau pour bébé; Gourdes bébé; Jus bébé++"),
        ("Hygiène bébé", 2, "Couches; Lingettes bébé; Liniment++; Couches-culottes; Coton bébé; Gel lavant bébé; Crème change; Lait de toilette bébé; Shampoing bébé; Mouche-bébé++; Lingettes à l'eau"),
        ("Puériculture", 3, "Biberons; Tétines; Thermomètre de bain; Bavoirs; Tasse d'apprentissage; Couverts bébé; Anneau de dentition; Goupillon; Assiette bébé; Boîte doseuse lait; Coussinets d'allaitement"),
    ],
    "Parfumerie et soins": [
        ("Toilette et soins du corps", 1, "Gel douche; Savon; Déodorant; Crème hydratante+; Coton+; Cotons-tiges+; Savon liquide; Gel hydroalcoolique; Lait corporel+; Gel douche enfant+; Pierre ponce+; Crème pour les pieds+; Gant de toilette+; Huile pour le corps+; Gommage corps+; Talc+"),
        ("Cheveux", 1, "Shampooing; Après-shampooing+; Coloration+; Gel coiffant++; Laque++; Shampooing sec+; Masque capillaire+; Shampooing antipelliculaire+; Shampooing enfant+; Mousse coiffante+; Cire coiffante+; Élastiques à cheveux; Brosse à cheveux+; Peigne; Barrettes+; Lotion anti-poux+"),
        ("Santé dentaire", 1, "Dentifrice; Brosse à dents; Bain de bouche+; Fil dentaire++; Brossettes interdentaires+; Têtes de brosse à dents électrique+; Brosse à dents enfant; Dentifrice enfant; Crème fixative pour appareil dentaire+; Pastilles nettoyantes pour appareil dentaire+; Brosse à dents électrique++; Chewing-gums sans sucre"),
        ("Cosmétiques et parfums", 3, "Maquillage; Démaquillant; Parfum; Vernis à ongles; Mascara; Rouge à lèvres; Fond de teint; Crayon pour les yeux; Dissolvant; Eau micellaire; Crème de jour; Crème de nuit; Masque visage; Eau de toilette; Lime à ongles; Pince à épiler; Disques démaquillants"),
    ],
    "Hygiène": [
        ("Hygiène féminine", 1, "Serviettes hygiéniques; Tampons; Protège-slips+; Serviettes de nuit; Coupe menstruelle+; Culotte menstruelle++; Gel toilette intime+; Lingettes intimes+; Protections pour incontinence+; Test de grossesse+; Préservatifs"),
        ("Rasage", 1, "Rasoirs; Mousse à raser+; Lames de rasoir++; Gel à raser; Après-rasage+; Rasoirs jetables; Rasoirs femme+; Crème dépilatoire+; Bandes de cire+; Blaireau++; Tondeuse à barbe++"),
    ],
    "Parapharmacie": [
        ("Soins et premiers secours", 3, "Pansements; Sérum physiologique; Désinfectant cutané; Thermomètre; Compresses; Bande Velpeau; Sparadrap; Spray nasal; Antiseptique en spray; Pansements ampoules; Alcool à 70°; Eau oxygénée; Tensiomètre"),
        ("Solaires et soins spécifiques", 3, "Crème solaire; Crème mains; Baume à lèvres; Crème solaire enfant; Après-soleil; Huile solaire; Autobronzant; Anti-moustiques; Crème anti-âge; Crème pieds secs; Stick lèvres solaire; Huiles essentielles"),
    ],
    "Entretien / Droguerie": [
        ("Lessives et soin du linge", 1, "Lessive liquide; Lessive en poudre+; Lessive en capsules+; Adoucissant; Détachant+; Blanchissant++; Lessive linge délicat; Lessive noire+; Désinfectant linge+; Parfum de linge+; Spray repassage+; Eau déminéralisée; Lingettes anti-décoloration+; Nettoyant lave-linge+; Teinture textile++; Savon de Marseille; Pinces à linge"),
        ("Produits Vaisselle", 1, "Liquide vaisselle; Tablettes lave-vaisselle; Sel régénérant+; Liquide de rinçage+; Éponges; Liquide vaisselle main; Nettoyant lave-vaisselle+; Lave-vaisselle tout-en-un en gel+; Grattoirs; Brosse vaisselle; Éponges métalliques; Lavettes microfibre; Pastilles désodorisantes lave-vaisselle+"),
        ("Nettoyants ménagers", 1, "Nettoyant multi-usages; Nettoyant sol; Nettoyant vitres+; Détartrant+; Désinfectant+; Javel; Nettoyant WC; Lingettes nettoyantes; Dégraissant cuisine; Vinaigre blanc; Bicarbonate de soude; Cristaux de soude+; Savon noir+; Déboucheur canalisations; Blocs WC; Désodorisant; Insecticide; Nettoyant four+; Nettoyant inox+; Acide citrique+"),
        ("Accessoires de ménage", 1, "Serpillière+; Balai++; Seau++; Gants de ménage+; Balai-brosse+; Pelle et balayette; Balai à franges+; Chiffons microfibre; Plumeau+; Brosse WC; Lingettes sol; Bassine+; Sacs aspirateur+; Seau avec essoreur+"),
        ("Salle de bain et cirage", 2, "Nettoyant salle de bain; Anticalcaire; Cirage++; Nettoyant douche; Anti-moisissures; Brosse à chaussures; Imperméabilisant chaussures; Lacets; Semelles; Rideau de douche++; Tapis de bain++; Ventouses"),
        ("Papier", 1, "Papier toilette; Essuie-tout; Mouchoirs; Serviettes en papier+; Papier toilette humide; Mouchoirs en boîte; Paquets de mouchoirs; Essuie-mains en papier+; Nappe en papier+"),
        ("Emballages et Aluminium etc", 1, "Sacs poubelle; Papier aluminium; Papier cuisson+; Film étirable+; Sacs congélation+; Boîtes alimentaires+; Barquettes aluminium+; Sacs de congélation zip; Film micro-ondes+; Sacs isothermes+; Sacs de conservation; Pochettes sandwich+; Liens pour sacs+; Sacs compostables+; Pots en verre+; Moules en papier+"),
    ],
    "Cuisine et arts de la table": [
        ("Arts de la table et cuisine", 2, "Ustensiles de cuisine++; Poêle++; Casserole++; Couteaux; Planche à découper; Fouet; Spatule; Louche; Économe; Ouvre-boîte; Plat à four; Faitout; Saladier; Passoire; Râpe; Tire-bouchon; Moule à gâteau; Couverts"),
        ("Vaisselle jetable", 2, "Assiettes en carton; Gobelets; Couverts jetables; Gobelets en carton; Pailles; Nappe jetable; Verres en plastique; Bols jetables; Piques apéritif; Plateaux en carton++; Bougies d'anniversaire"),
        ("Vaisselle", 1, "Assiette; Verres; Bols; Tasses+; Mugs+; Assiettes creuses+; Assiettes à dessert+; Verres à vin+; Carafe+; Plat de service++; Coquetiers+"),
    ],
    "Bricolage, auto et jardin": [
        ("Bricolage et quincaillerie", 2, "Piles; Ampoules; Colle; Multiprise++; Petits outils++; Piles bouton; Ampoules LED; Rallonge électrique; Ruban adhésif d'emballage; Scotch double face; Clous; Vis; Chevilles; Crochets adhésifs; Lampe de poche; Tournevis; Mètre ruban; Allume-feu; Allumettes; Briquet"),
        ("Jardinage et extérieur", 3, "Terreau; Engrais; Petits outils de jardin; Plants; Graines de légumes; Graines de fleurs; Bulbes; Gants de jardin; Tuyau d'arrosage; Arrosoir; Pots de fleurs; Charbon de bois; Désherbant; Anti-limaces; Pierres à barbecue; Sécateur"),
        ("Accessoires automobiles", 3, "Liquide lave-glace; Huile moteur; Ampoules auto; Liquide de refroidissement; Liquide de frein; Lingettes voiture; Shampooing auto; Désodorisant voiture; Grattoir à givre; Raclette pare-brise; Balais d'essuie-glace; Nettoyant jantes; Câbles de démarrage; Dégivrant; Gilet jaune"),
    ],
    "Loisirs": [
        ("Papeterie et librairie", 2, "Cahiers; Stylos; Ruban adhésif; Livres++; Magazines++; Crayons de couleur; Crayons à papier; Feutres; Gomme; Taille-crayon; Ramettes de papier; Enveloppes; Timbres; Post-it; Classeurs; Bâton de colle; Ciseaux; Règle; Surligneurs; Agenda; Cartes d'anniversaire; Papier cadeau; Journaux"),
        ("Jouets", 3, "Jeux de société; Jouets enfants; Puzzle; Jeux de cartes; Peluches; Poupées; Petites voitures; Jeux de construction; Pâte à modeler; Ballons; Jouets de plage; Loisirs créatifs; Bulles de savon"),
        ("Bagagerie", 3, "Valises; Sacs de voyage; Sacs à dos; Cartables; Trousses; Sacs de sport; Étiquettes à bagages; Cadenas de valise; Trousse de toilette; Sacs de courses réutilisables; Sac isotherme; Coussin de voyage"),
    ],
    "Électroménager et décoration": [
        ("Petit électroménager", 3, "Bouilloire; Grille-pain; Cafetière; Mixeur; Robot pâtissier; Fer à repasser; Sèche-cheveux; Aspirateur; Micro-ondes; Blender; Machine à café à dosettes; Presse-agrumes; Gaufrier; Appareil à raclette; Friteuse sans huile; Batteur; Ventilateur; Radiateur d'appoint"),
        ("Décoration", 3, "Bougies; Cadres; Boîtes de rangement; Bougies parfumées; Photophores; Vases; Coussins; Plaids; Miroirs; Guirlandes lumineuses; Fleurs artificielles; Diffuseur de parfum; Paniers de rangement; Horloge; Cintres"),
    ],
    "Textile": [
        ("Vêtements et chaussures", 3, "Chaussettes; T-shirts; Chaussons; Pyjamas; Pulls; Jeans; Pantalons; Sweats; Leggings; Baskets; Tongs; Bottes de pluie; Gants; Bonnets; Écharpes; Maillots de bain; Vêtements bébé; Chaussures enfant"),
        ("Lingerie", 3, "Sous-vêtements; Collants; Culottes; Soutiens-gorge; Boxers; Slips; Caleçons; Débardeurs; Chemises de nuit; Bas; Mi-bas; Chaussettes de sport"),
        ("Linge de maison", 3, "Torchons; Serviettes de bain; Parure de lit; Rideaux; Draps housse; Housses de couette; Taies d'oreiller; Oreillers; Couettes; Protège-matelas; Serviettes de toilette; Draps de plage; Nappe; Sets de table; Tabliers de cuisine; Peignoirs; Plaid polaire"),
    ],
    "Animaux": [
        ("Chiens", 2, "Croquettes pour chien; Pâtée pour chien; Friandises pour chien++; Croquettes pour chiot; Os à mâcher; Jouets pour chien++; Sacs à crottes; Laisse++; Collier pour chien++; Gamelle++; Shampooing pour chien++; Antiparasitaire pour chien++; Panier pour chien++; Bâtonnets dentaires pour chien"),
        ("Chats", 1, "Croquettes pour chat; Pâtée pour chat; Litière; Friandises pour chat; Croquettes pour chaton+; Croquettes pour chat stérilisé; Sachets fraîcheur pour chat; Lait pour chat+; Litière végétale+; Litière silice+; Bac à litière++; Griffoir++; Jouets pour chat++; Antiparasitaire pour chat++; Herbe à chat+"),
        ("Autres animaux", 2, "Graines pour oiseaux; Nourriture pour rongeurs; Nourriture pour poissons"),
    ],
}

TAILLES = {1: "Proximité", 2: "Supermarché", 3: "Hypermarché"}


def niveau(nom):
    n = len(nom) - len(nom.rstrip("+"))
    return nom.rstrip("+").strip(), 1 + n


def referentiel():
    rayons, produits = [], {}
    for i, (rayon, secteurs) in enumerate(CATALOGUE.items(), 1):
        rs = []
        for j, (secteur, taille, liste) in enumerate(secteurs, 1):
            ps = []
            for brut in filter(str.strip, liste.split(";")):
                nom, t = niveau(brut.strip())
                ps.append({"nom": nom, "taille": max(t, taille)})
                produits[nom] = produits.get(nom, 0) + 1
            rs.append({"nom": secteur, "ordre": j, "taille": taille, "produits": ps})
        rayons.append({"nom": rayon, "ordre": i, "secteurs": rs})
    doublons = [p for p, n in produits.items() if n > 1]
    assert not doublons, doublons
    return {"_description": "Catalogue type d'un magasin français. taille : 1 proximité, 2 supermarché, 3 hypermarché.",
            "tailles": TAILLES, "rayons": rayons}


def sql(ref):
    q = lambda s: "'" + s.replace("'", "''") + "'"
    lignes = ["-- Catalogue type : trois magasins exemples (schéma v2). Généré par generer_catalogue_type.py.",
              "BEGIN;"]
    ids_produits = {}
    for r in ref["rayons"]:
        for s in r["secteurs"]:
            for p in s["produits"]:
                ids_produits[p["nom"]] = str(uuid.uuid5(uuid.NAMESPACE_URL, "produit/" + p["nom"]))
    for nom, pid in ids_produits.items():
        lignes.append(f"INSERT INTO produit (id, nom) VALUES ({q(pid)}, {q(nom)});")
    for taille, libelle in TAILLES.items():
        mid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"magasin/{taille}"))
        lignes.append(f"INSERT INTO magasin (id, nom) VALUES ({q(mid)}, {q(libelle + ' type')});")
        for r in ref["rayons"]:
            secteurs = [s for s in r["secteurs"] if s["taille"] <= taille]
            if not secteurs:
                continue
            rid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"rayon/{taille}/{r['nom']}"))
            lignes.append(f"INSERT INTO rayon (id, magasin_id, nom, ordre_affichage) VALUES ({q(rid)}, {q(mid)}, {q(r['nom'])}, {r['ordre']});")
            for s in secteurs:
                sid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"secteur/{taille}/{r['nom']}/{s['nom']}"))
                lignes.append(f"INSERT INTO secteur (id, rayon_id, nom, ordre_affichage) VALUES ({q(sid)}, {q(rid)}, {q(s['nom'])}, {s['ordre']});")
                for p in s["produits"]:
                    if p["taille"] <= taille:
                        lignes.append(f"INSERT INTO emplacement (produit_id, magasin_id, secteur_id) VALUES ({q(ids_produits[p['nom']])}, {q(mid)}, {q(sid)});")
    lignes.append("COMMIT;")
    return "\n".join(lignes) + "\n"


if __name__ == "__main__":
    ref = referentiel()
    (ICI / "catalogue-type.json").write_text(json.dumps(ref, ensure_ascii=False, indent=1), encoding="utf-8")
    (ICI / "catalogue-type.sql").write_text(sql(ref), encoding="utf-8")
    for t, libelle in TAILLES.items():
        nr = sum(1 for r in ref["rayons"] if any(s["taille"] <= t for s in r["secteurs"]))
        ns = sum(1 for r in ref["rayons"] for s in r["secteurs"] if s["taille"] <= t)
        np_ = sum(1 for r in ref["rayons"] for s in r["secteurs"] for p in s["produits"] if p["taille"] <= t)
        print(f"{libelle}: {nr} rayons, {ns} secteurs, {np_} produits")
