# 100 recettes Emplettes n° 498 à 597 (21/11/2026, Aristide : « ajouter des recettes à ces 497 »).
# R(type, titre, pour, préparation, cuisson, [(quantité, nom, précision)], [étapes], [conseils])
L = []
def R(type_, titre, pour, prep, cuisson, ing, etapes, conseils=()):
    L.append(dict(type=type_, titre=titre, pour=pour, prep=prep, cuisson=cuisson,
                  ing=[dict(quantite=q, nom=n, precision=p) for q, n, p in ing], etapes=list(etapes), conseils=list(conseils)))

SP = [("au goût", "Sel", ""), ("au goût", "Poivre", "")]

# ---------------------------------------------------------------- Lot 1 : plats du monde
R("Plats", "Poulet tikka masala", 4, 25, 30, [
    ("700 g", "Filets de poulet", ""), ("150 g", "Yaourt nature", ""), ("2 cuillères à soupe", "Pâte de curry tikka", ""),
    ("1", "Oignon", ""), ("2 gousses", "Ail", ""), ("20 g", "Gingembre frais", ""), ("400 g", "Tomates concassées", ""),
    ("15 cl", "Crème liquide", ""), ("2 cuillères à soupe", "Huile", ""), ("1/2 bouquet", "Coriandre", ""), ("au goût", "Sel", "")],
    ["Couper le poulet en cubes et le mélanger avec le yaourt et la moitié de la pâte de curry. Laisser mariner 30 minutes au frais.",
     "Éplucher et hacher l'oignon, l'ail et le gingembre.",
     "Faire dorer le poulet égoutté 5 minutes dans l'huile, dans une sauteuse, puis le réserver.",
     "Faire revenir l'oignon, l'ail et le gingembre 5 minutes, ajouter le reste de la pâte de curry et remuer 1 minute.",
     "Ajouter les tomates, laisser mijoter 10 minutes, puis remettre le poulet et la crème et cuire encore 10 minutes.",
     "Saler, parsemer de coriandre ciselée et servir avec du riz basmati ou des naans."],
    ["La marinade peut se faire la veille."])
R("Plats", "Dal de lentilles corail", 4, 15, 25, [
    ("300 g", "Lentilles corail", ""), ("1", "Oignon", ""), ("2 gousses", "Ail", ""), ("15 g", "Gingembre frais", ""),
    ("1 cuillère à café", "Curcuma", ""), ("1 cuillère à café", "Cumin", ""), ("400 g", "Tomates concassées", ""),
    ("40 cl", "Lait de coco", ""), ("2 cuillères à soupe", "Huile", ""), ("1", "Citron vert", ""), ("au goût", "Sel", "")],
    ["Rincer les lentilles. Éplucher et hacher l'oignon, l'ail et le gingembre.",
     "Faire revenir l'oignon, l'ail et le gingembre 5 minutes dans l'huile, ajouter le curcuma et le cumin et remuer 1 minute.",
     "Ajouter les lentilles, les tomates, le lait de coco et 40 cl d'eau.",
     "Laisser mijoter 20 minutes en remuant souvent, jusqu'à ce que les lentilles se défassent.",
     "Saler, arroser du jus du citron vert et servir avec du riz."])
R("Plats", "Butter chicken", 4, 20, 35, [
    ("700 g", "Hauts de cuisse de poulet", "désossés"), ("125 g", "Yaourt nature", ""), ("2 cuillères à café", "Garam masala", ""),
    ("1", "Oignon", ""), ("2 gousses", "Ail", ""), ("15 g", "Gingembre frais", ""), ("400 g", "Coulis de tomate", ""),
    ("50 g", "Beurre", ""), ("20 cl", "Crème liquide", ""), ("1 cuillère à café", "Sucre", ""), ("au goût", "Sel", "")],
    ["Couper le poulet en morceaux et le mélanger avec le yaourt et la moitié du garam masala. Laisser mariner 30 minutes.",
     "Éplucher et hacher l'oignon, l'ail et le gingembre.",
     "Faire fondre le beurre dans une sauteuse, faire revenir l'oignon, l'ail et le gingembre 5 minutes avec le reste du garam masala.",
     "Ajouter le coulis de tomate et le sucre et laisser mijoter 10 minutes. Mixer la sauce si on la veut lisse.",
     "Ajouter le poulet et la crème, cuire 20 minutes à feu doux. Saler et servir avec du riz basmati."])
R("Plats", "Chili de patates douces et haricots rouges", 4, 20, 35, [
    ("600 g", "Patates douces", ""), ("400 g", "Haricots rouges cuits", ""), ("1", "Oignon", ""), ("1", "Poivron rouge", ""),
    ("2 gousses", "Ail", ""), ("400 g", "Tomates concassées", ""), ("1 cuillère à café", "Cumin", ""),
    ("1 cuillère à café", "Paprika fumé", ""), ("2 cuillères à soupe", "Huile d'olive", ""), *SP],
    ["Éplucher les patates douces et les couper en cubes. Émincer l'oignon et le poivron, hacher l'ail.",
     "Faire revenir l'oignon, le poivron et l'ail 5 minutes dans l'huile, dans une cocotte. Ajouter le cumin et le paprika.",
     "Ajouter les patates douces, les tomates et 20 cl d'eau. Couvrir et cuire 20 minutes.",
     "Ajouter les haricots rouges rincés et poursuivre 10 minutes à découvert.",
     "Saler, poivrer et servir avec du riz ou des tortillas."])
R("Plats", "Tacos de poulet aux poivrons", 4, 20, 15, [
    ("500 g", "Filets de poulet", ""), ("2", "Poivrons", ""), ("1", "Oignon rouge", ""), ("8", "Tortillas de maïs", "petites"),
    ("1 cuillère à café", "Cumin", ""), ("1 cuillère à café", "Paprika", ""), ("2", "Citrons verts", ""), ("1", "Avocat", ""),
    ("100 g", "Crème fraîche épaisse", ""), ("1/2 bouquet", "Coriandre", ""), ("2 cuillères à soupe", "Huile", ""), *SP],
    ["Couper le poulet en lanières et l'assaisonner de cumin, de paprika, du jus d'un citron vert, de sel et de poivre.",
     "Émincer les poivrons et l'oignon rouge.",
     "Faire sauter le poulet 6 minutes dans l'huile à feu vif, ajouter les légumes et cuire encore 5 minutes.",
     "Écraser l'avocat avec le jus du second citron vert et une pincée de sel.",
     "Réchauffer les tortillas à la poêle, les garnir de poulet, d'avocat, de crème et de coriandre."])
R("Plats", "Poulet teriyaki", 4, 15, 15, [
    ("600 g", "Hauts de cuisse de poulet", "désossés"), ("6 cuillères à soupe", "Sauce soja", ""), ("3 cuillères à soupe", "Mirin", ""),
    ("2 cuillères à soupe", "Miel", ""), ("1 gousse", "Ail", ""), ("10 g", "Gingembre frais", ""), ("1 cuillère à soupe", "Huile", ""),
    ("1 cuillère à soupe", "Graines de sésame", ""), ("2", "Oignons nouveaux", "")],
    ["Mélanger la sauce soja, le mirin, le miel, l'ail haché et le gingembre râpé.",
     "Couper le poulet en morceaux et le faire dorer 8 minutes dans l'huile, à la poêle.",
     "Verser la sauce et laisser réduire 4 à 5 minutes en remuant, jusqu'à ce que le poulet soit laqué.",
     "Parsemer de sésame et d'oignons nouveaux émincés. Servir avec du riz."])
R("Plats", "Bœuf bulgogi", 4, 20, 10, [
    ("600 g", "Bœuf", "faux-filet ou rumsteck, en tranches très fines"), ("5 cuillères à soupe", "Sauce soja", ""),
    ("2 cuillères à soupe", "Sucre roux", ""), ("1", "Poire", ""), ("3 gousses", "Ail", ""), ("1 cuillère à soupe", "Huile de sésame", ""),
    ("1", "Oignon", ""), ("2", "Oignons nouveaux", ""), ("1 cuillère à soupe", "Graines de sésame", ""), ("1 cuillère à soupe", "Huile", "")],
    ["Râper la poire et mélanger avec la sauce soja, le sucre, l'ail haché et l'huile de sésame.",
     "Ajouter le bœuf et l'oignon émincé, mélanger et laisser mariner 30 minutes.",
     "Faire chauffer l'huile à feu très vif et saisir la viande en plusieurs fois, 2 à 3 minutes.",
     "Parsemer d'oignons nouveaux et de sésame. Servir avec du riz et des feuilles de salade."],
    ["Passer la viande 30 minutes au congélateur pour la trancher finement."])
R("Plats", "Poulet yassa", 4, 20, 45, [
    ("1,2 kg", "Cuisses de poulet", ""), ("4", "Oignons", "gros"), ("3", "Citrons", ""), ("2 cuillères à soupe", "Moutarde", ""),
    ("2 gousses", "Ail", ""), ("1", "Piment", "facultatif"), ("3 cuillères à soupe", "Huile", ""), *SP],
    ["Émincer les oignons. Mélanger le jus des citrons, la moutarde, l'ail haché, le piment, du sel et du poivre.",
     "Y mettre le poulet et les oignons à mariner au moins 2 heures.",
     "Égoutter le poulet et le faire dorer dans l'huile, dans une cocotte. Le réserver.",
     "Faire fondre les oignons égouttés 15 minutes à feu moyen, puis ajouter la marinade et le poulet.",
     "Couvrir et laisser mijoter 30 minutes. Servir avec du riz blanc."])
R("Plats", "Mafé de bœuf", 4, 20, 90, [
    ("800 g", "Bœuf à braiser", ""), ("150 g", "Beurre de cacahuète", ""), ("2 cuillères à soupe", "Concentré de tomate", ""),
    ("2", "Oignons", ""), ("2 gousses", "Ail", ""), ("3", "Carottes", ""), ("400 g", "Patate douce", ""),
    ("1", "Cube de bouillon de bœuf", ""), ("2 cuillères à soupe", "Huile", ""), *SP],
    ["Couper le bœuf en cubes et le faire dorer dans l'huile, dans une cocotte. Ajouter les oignons émincés et l'ail haché.",
     "Ajouter le concentré de tomate, le cube de bouillon et 1 litre d'eau. Laisser mijoter 45 minutes.",
     "Délayer le beurre de cacahuète avec une louche de bouillon et l'ajouter.",
     "Ajouter les carottes et la patate douce en morceaux et cuire encore 45 minutes, en remuant de temps en temps.",
     "Saler, poivrer et servir avec du riz."])
R("Plats", "Shawarma de poulet", 4, 20, 25, [
    ("700 g", "Hauts de cuisse de poulet", "désossés"), ("1 cuillère à café", "Cumin", ""), ("1 cuillère à café", "Paprika", ""),
    ("1/2 cuillère à café", "Cannelle", ""), ("1", "Citron", ""), ("2 gousses", "Ail", ""), ("3 cuillères à soupe", "Huile d'olive", ""),
    ("4", "Pains pita", ""), ("150 g", "Yaourt grec", ""), ("2", "Tomates", ""), ("1/2", "Concombre", ""), *SP],
    ["Mélanger le jus du citron, l'huile, l'ail haché, les épices, du sel et du poivre. Y mettre le poulet à mariner 1 heure.",
     "Préchauffer le four à 220 °C. Étaler le poulet sur une plaque et l'enfourner 25 minutes.",
     "Couper le poulet en fines lanières.",
     "Couper les tomates et le concombre en dés. Assaisonner le yaourt de sel.",
     "Garnir les pains pita chauds de poulet, de crudités et de sauce au yaourt."])
R("Plats", "Kefta de bœuf à la tomate", 4, 20, 30, [
    ("600 g", "Bœuf haché", ""), ("1", "Oignon", ""), ("1/2 bouquet", "Persil", ""), ("1/2 bouquet", "Coriandre", ""),
    ("2 cuillères à café", "Cumin", ""), ("1 cuillère à café", "Paprika", ""), ("800 g", "Tomates concassées", ""),
    ("2 gousses", "Ail", ""), ("4", "Œufs", "facultatif"), ("2 cuillères à soupe", "Huile d'olive", ""), *SP],
    ["Mélanger le bœuf avec l'oignon râpé, la moitié des herbes hachées, le cumin, le paprika, du sel et du poivre. Former des boulettes.",
     "Faire revenir l'ail haché dans l'huile, dans une sauteuse, ajouter les tomates et laisser mijoter 10 minutes.",
     "Déposer les boulettes dans la sauce, couvrir et cuire 15 minutes.",
     "Casser les œufs entre les boulettes, couvrir et cuire 5 minutes, jusqu'à ce que les blancs soient pris.",
     "Parsemer du reste des herbes et servir avec du pain."])
R("Plats", "Poulet au gingembre et citronnelle", 4, 20, 20, [
    ("700 g", "Filets de poulet", ""), ("2 tiges", "Citronnelle", ""), ("30 g", "Gingembre frais", ""), ("2 gousses", "Ail", ""),
    ("3 cuillères à soupe", "Sauce nuoc-mâm", ""), ("1 cuillère à soupe", "Sucre roux", ""), ("1", "Oignon", ""),
    ("2 cuillères à soupe", "Huile", ""), ("1/2 bouquet", "Coriandre", "")],
    ["Émincer finement le cœur de la citronnelle, râper le gingembre, hacher l'ail et émincer l'oignon.",
     "Couper le poulet en lamelles.",
     "Faire sauter la citronnelle, le gingembre, l'ail et l'oignon 2 minutes dans l'huile, à feu vif.",
     "Ajouter le poulet et le cuire 8 minutes. Ajouter la sauce nuoc-mâm, le sucre et 5 cl d'eau, et laisser réduire 3 minutes.",
     "Parsemer de coriandre et servir avec du riz."])
R("Plats", "Bò bún", 4, 30, 15, [
    ("400 g", "Bœuf", "rumsteck"), ("200 g", "Vermicelles de riz", ""), ("4", "Nems", "surgelés"), ("2", "Carottes", ""),
    ("1/2", "Concombre", ""), ("100 g", "Germes de soja", ""), ("1/2 bouquet", "Menthe", ""), ("50 g", "Cacahuètes", "grillées"),
    ("4 cuillères à soupe", "Sauce nuoc-mâm", ""), ("2 cuillères à soupe", "Sucre", ""), ("1", "Citron vert", ""), ("2 gousses", "Ail", ""),
    ("1 cuillère à soupe", "Huile", "")],
    ["Préparer la sauce : mélanger la sauce nuoc-mâm, le sucre, le jus du citron vert, un ail haché et 8 cuillères à soupe d'eau.",
     "Cuire les vermicelles selon le paquet, les rincer à l'eau froide et les égoutter. Cuire les nems au four.",
     "Râper les carottes, tailler le concombre en bâtonnets, effeuiller la menthe.",
     "Couper le bœuf en fines lamelles et le faire sauter 2 minutes à feu vif avec l'autre ail haché dans l'huile.",
     "Répartir dans des bols les vermicelles, les crudités, le bœuf, les nems coupés et les cacahuètes concassées. Arroser de sauce."])
R("Plats", "Porc à l'aigre-douce", 4, 20, 20, [
    ("600 g", "Filet de porc", ""), ("2 cuillères à soupe", "Fécule de maïs", ""), ("1", "Poivron rouge", ""), ("1", "Poivron vert", ""),
    ("1", "Oignon", ""), ("200 g", "Ananas", "en morceaux"), ("4 cuillères à soupe", "Ketchup", ""), ("3 cuillères à soupe", "Vinaigre de riz", ""),
    ("2 cuillères à soupe", "Sucre", ""), ("2 cuillères à soupe", "Sauce soja", ""), ("3 cuillères à soupe", "Huile", "")],
    ["Couper le porc en cubes et le rouler dans la fécule.",
     "Mélanger le ketchup, le vinaigre, le sucre, la sauce soja et 10 cl d'eau.",
     "Faire dorer le porc 6 minutes dans l'huile, à feu vif, puis le réserver.",
     "Faire sauter l'oignon et les poivrons en morceaux 4 minutes, ajouter l'ananas et la sauce et laisser épaissir 2 minutes.",
     "Remettre le porc, mélanger et servir avec du riz."])
R("Plats", "Moussaka libanaise aux pois chiches", 4, 20, 40, [
    ("3", "Aubergines", ""), ("400 g", "Pois chiches cuits", ""), ("2", "Oignons", ""), ("3 gousses", "Ail", ""),
    ("800 g", "Tomates concassées", ""), ("1 cuillère à café", "Cumin", ""), ("6 cuillères à soupe", "Huile d'olive", ""),
    ("1/2 bouquet", "Menthe", ""), *SP],
    ["Couper les aubergines en gros cubes et les faire dorer 10 minutes dans 4 cuillères à soupe d'huile. Les réserver.",
     "Faire revenir les oignons émincés et l'ail haché dans le reste d'huile.",
     "Ajouter les tomates, le cumin, les pois chiches rincés et les aubergines.",
     "Couvrir et laisser mijoter 30 minutes à feu doux.",
     "Saler, poivrer et servir tiède ou froid, parsemé de menthe."],
    ["Encore meilleure le lendemain."])
R("Plats", "Pastilla de poulet", 6, 40, 60, [
    ("1 kg", "Cuisses de poulet", ""), ("3", "Oignons", ""), ("1 cuillère à café", "Cannelle", ""), ("1 cuillère à café", "Gingembre en poudre", ""),
    ("1 pincée", "Safran", ""), ("1/2 bouquet", "Coriandre", ""), ("4", "Œufs", ""), ("150 g", "Amandes émondées", ""),
    ("2 cuillères à soupe", "Sucre glace", ""), ("10 feuilles", "Feuilles de brick", ""), ("80 g", "Beurre", "fondu"), *SP],
    ["Mettre le poulet dans une cocotte avec les oignons émincés, les épices, la coriandre, du sel, du poivre et 30 cl d'eau. Cuire 45 minutes à couvert.",
     "Retirer le poulet, l'effilocher sans peau ni os. Faire réduire la sauce, puis y cuire les œufs battus en remuant, comme des œufs brouillés.",
     "Faire griller les amandes, les mixer grossièrement avec le sucre glace et la moitié de la cannelle.",
     "Préchauffer le four à 180 °C. Beurrer un moule, y disposer 6 feuilles de brick beurrées qui débordent. Étaler les amandes, le poulet, puis les œufs.",
     "Rabattre les feuilles, couvrir des feuilles restantes beurrées et enfourner 25 minutes. Saupoudrer de sucre glace et de cannelle."],
    ["Se prépare à l'avance et se réchauffe au four."])
R("Plats", "Chili sin carne aux lentilles", 4, 15, 35, [
    ("200 g", "Lentilles vertes", ""), ("400 g", "Haricots rouges cuits", ""), ("200 g", "Maïs", ""), ("1", "Oignon", ""),
    ("2 gousses", "Ail", ""), ("800 g", "Tomates concassées", ""), ("2 cuillères à café", "Cumin", ""), ("1 cuillère à café", "Piment doux", ""),
    ("2 cuillères à soupe", "Huile d'olive", ""), *SP],
    ["Rincer les lentilles. Émincer l'oignon et hacher l'ail.",
     "Les faire revenir 5 minutes dans l'huile avec le cumin et le piment.",
     "Ajouter les lentilles, les tomates et 40 cl d'eau. Couvrir et cuire 25 minutes.",
     "Ajouter les haricots rouges et le maïs rincés et poursuivre 5 minutes.",
     "Saler, poivrer et servir avec du riz ou des tortillas."])
R("Plats", "Saumon teriyaki et riz", 4, 10, 15, [
    ("4", "Pavés de saumon", ""), ("5 cuillères à soupe", "Sauce soja", ""), ("2 cuillères à soupe", "Mirin", ""),
    ("1 cuillère à soupe", "Miel", ""), ("10 g", "Gingembre frais", ""), ("1 cuillère à soupe", "Huile", ""),
    ("1 cuillère à soupe", "Graines de sésame", ""), ("240 g", "Riz", "japonais ou basmati")],
    ["Cuire le riz selon le paquet.",
     "Mélanger la sauce soja, le mirin, le miel et le gingembre râpé.",
     "Faire dorer les pavés de saumon côté peau 4 minutes dans l'huile, puis les retourner 2 minutes.",
     "Verser la sauce et laisser réduire 2 minutes en arrosant le saumon.",
     "Servir sur le riz, parsemé de sésame."])
R("Plats", "Nasi goreng", 4, 20, 15, [
    ("600 g", "Riz cuit", "de la veille"), ("300 g", "Crevettes décortiquées", ""), ("2", "Œufs", ""), ("1", "Oignon", ""),
    ("2 gousses", "Ail", ""), ("1", "Carotte", ""), ("100 g", "Petits pois", ""), ("3 cuillères à soupe", "Sauce soja sucrée", ""),
    ("1 cuillère à café", "Pâte de piment", "sambal, facultatif"), ("3 cuillères à soupe", "Huile", "")],
    ["Émincer l'oignon, hacher l'ail, couper la carotte en petits dés.",
     "Faire sauter l'oignon, l'ail et la carotte 4 minutes dans l'huile, au wok, à feu vif.",
     "Ajouter les crevettes et les petits pois et cuire 3 minutes.",
     "Ajouter le riz, la sauce soja et la pâte de piment et faire sauter 4 minutes.",
     "Cuire les œufs au plat à part et en couvrir chaque assiette."])
R("Plats", "Goulash de bœuf", 4, 20, 120, [
    ("800 g", "Bœuf à braiser", ""), ("3", "Oignons", ""), ("2 cuillères à soupe", "Paprika doux", ""), ("1", "Poivron rouge", ""),
    ("2 cuillères à soupe", "Concentré de tomate", ""), ("500 g", "Pommes de terre", ""), ("1 cuillère à café", "Carvi", "facultatif"),
    ("1 l", "Bouillon de bœuf", ""), ("2 cuillères à soupe", "Huile", ""), *SP],
    ["Couper le bœuf en cubes et le faire dorer dans l'huile, dans une cocotte. Le réserver.",
     "Faire fondre les oignons émincés 10 minutes, ajouter le paprika, le carvi et le concentré de tomate.",
     "Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 h 15.",
     "Ajouter le poivron et les pommes de terre en morceaux et poursuivre 40 minutes.",
     "Saler, poivrer et servir avec une cuillère de crème aigre."])
R("Plats", "Paella végétarienne", 4, 20, 35, [
    ("300 g", "Riz rond", "pour paella"), ("1", "Poivron rouge", ""), ("1", "Courgette", ""), ("150 g", "Haricots verts", ""),
    ("150 g", "Petits pois", ""), ("2", "Tomates", ""), ("1", "Oignon", ""), ("2 gousses", "Ail", ""), ("1 pincée", "Safran", ""),
    ("1 cuillère à café", "Paprika fumé", ""), ("90 cl", "Bouillon de légumes", "chaud"), ("4 cuillères à soupe", "Huile d'olive", ""),
    ("1", "Citron", ""), *SP],
    ["Couper le poivron, la courgette et les haricots en morceaux, les tomates en dés, émincer l'oignon et hacher l'ail.",
     "Dans une grande poêle, faire revenir l'oignon, l'ail et les légumes 8 minutes dans l'huile.",
     "Ajouter les tomates, le paprika et le riz et remuer 2 minutes.",
     "Verser le bouillon avec le safran, saler et cuire 18 minutes sans remuer, à feu moyen. Ajouter les petits pois à mi-cuisson.",
     "Couvrir d'un torchon et laisser reposer 5 minutes. Servir avec des quartiers de citron."])
R("Plats", "Fajitas de bœuf", 4, 20, 10, [
    ("600 g", "Bœuf", "bavette ou rumsteck"), ("2", "Poivrons", ""), ("1", "Oignon rouge", ""), ("8", "Tortillas de blé", ""),
    ("1 cuillère à café", "Cumin", ""), ("1 cuillère à café", "Paprika fumé", ""), ("1", "Citron vert", ""),
    ("150 g", "Fromage râpé", "cheddar"), ("100 g", "Crème fraîche épaisse", ""), ("2 cuillères à soupe", "Huile", ""), *SP],
    ["Couper le bœuf en fines lanières et l'assaisonner de cumin, de paprika, du jus du citron vert, de sel et de poivre.",
     "Émincer les poivrons et l'oignon.",
     "Saisir le bœuf 3 minutes à feu très vif dans l'huile, le réserver, puis faire sauter les légumes 5 minutes.",
     "Remettre le bœuf et mélanger.",
     "Réchauffer les tortillas et les garnir de viande, de légumes, de fromage et de crème."])
R("Plats", "Poulet au curry vert thaï", 4, 15, 20, [
    ("600 g", "Filets de poulet", ""), ("2 cuillères à soupe", "Pâte de curry vert", ""), ("40 cl", "Lait de coco", ""),
    ("1", "Courgette", ""), ("150 g", "Haricots verts", ""), ("2 cuillères à soupe", "Sauce nuoc-mâm", ""),
    ("1 cuillère à café", "Sucre roux", ""), ("1/2 bouquet", "Basilic thaï", "ou coriandre"), ("1 cuillère à soupe", "Huile", "")],
    ["Couper le poulet en lamelles, la courgette en demi-rondelles et les haricots en tronçons.",
     "Faire revenir la pâte de curry 1 minute dans l'huile, ajouter la moitié du lait de coco et laisser frémir 2 minutes.",
     "Ajouter le poulet et cuire 5 minutes.",
     "Ajouter le reste du lait de coco, les légumes, la sauce nuoc-mâm et le sucre, et cuire 10 minutes.",
     "Parsemer de basilic et servir avec du riz parfumé."])
R("Plats", "Okonomiyaki au chou", 4, 20, 20, [
    ("300 g", "Chou blanc", ""), ("150 g", "Farine", ""), ("3", "Œufs", ""), ("15 cl", "Bouillon de légumes", ""),
    ("150 g", "Lardons", "ou crevettes"), ("2", "Oignons nouveaux", ""), ("4 cuillères à soupe", "Mayonnaise", ""),
    ("4 cuillères à soupe", "Sauce barbecue", "ou sauce okonomiyaki"), ("2 cuillères à soupe", "Huile", "")],
    ["Émincer très finement le chou et les oignons nouveaux.",
     "Mélanger la farine, les œufs et le bouillon, puis le chou, les oignons et les lardons.",
     "Faire chauffer l'huile dans une poêle, y verser le quart de la pâte en galette épaisse.",
     "Cuire 5 minutes par face à feu moyen, à couvert. Recommencer avec le reste.",
     "Napper de sauce et de mayonnaise et servir chaud."])

if __name__ == '__main__':
    print(len(L))
