# Étapes récrites des recettes 448 à 497 (légumes rôtis, sauces, gâteaux, fruits, crèmes dessert).
from etapes_lot3 import E, R

def roti(n, prep, assaisonner, fin, cuisson=35):
    R(n, ["Préchauffer le four à 200 °C.", prep,
          "Les étaler sur une plaque couverte de papier cuisson, sans les superposer. " + assaisonner,
          f"Enfourner {cuisson - 10} à {cuisson} minutes, en les retournant à mi-cuisson, jusqu'à ce qu'ils soient tendres et dorés.",
          fin], (), cuisson)
roti(448, "Éplucher les carottes et les couper en deux dans la longueur.",
     "Arroser d'huile d'olive, saupoudrer de cumin, saler et poivrer.",
     "Napper de miel 5 minutes avant la fin de la cuisson et servir.")
roti(449, "Retirer les premières feuilles des choux de Bruxelles et les couper en deux.",
     "Arroser d'huile d'olive, saler et poivrer.",
     "Arroser de vinaigre balsamique, parsemer de noisettes concassées et servir.", cuisson=30)
roti(450, "Couper la courge en quartiers, retirer les graines et la tailler en tranches épaisses, avec la peau si elle est fine.",
     "Ajouter les gousses d'ail entières, le romarin et l'huile d'olive. Saler, poivrer.",
     "Servir avec l'ail rôti, à écraser sur la courge.")
roti(451, "Éplucher les betteraves et les couper en quartiers.",
     "Arroser d'huile d'olive, ajouter le thym, saler et poivrer.",
     "Arroser de vinaigre balsamique et servir.", cuisson=50)
roti(452, "Éplucher les panais et les couper en bâtonnets. Écraser les gousses d'ail.",
     "Arroser d'huile d'olive, saupoudrer de paprika, ajouter l'ail, saler et poivrer.",
     "Servir chaud.")
roti(453, "Détailler le brocoli en bouquets et couper le pied en rondelles.",
     "Arroser d'huile d'olive, saler et poivrer.",
     "Arroser du jus du citron, parsemer de zeste et de copeaux de parmesan, et servir.", cuisson=25)
roti(454, "Couper les fenouils en quartiers. Râper le zeste de l'orange et presser son jus.",
     "Arroser d'huile d'olive et du jus d'orange, parsemer de graines de fenouil, saler et poivrer.",
     "Parsemer de zeste d'orange et servir.", cuisson=40)
R(455, ["Éplucher les navets et les couper en quartiers.",
        "Les mettre dans une sauteuse avec l'huile d'olive, le miel, le thym, du sel et de l'eau à mi-hauteur.",
        "Couvrir d'un disque de papier cuisson et cuire 20 minutes à feu moyen, jusqu'à ce que l'eau soit évaporée.",
        "Faire rouler les navets dans le jus sirupeux 3 minutes pour les glacer. Poivrer et servir."], cuisson=25)
roti(456, "Laver les patates douces et les couper en quartiers, avec la peau.",
     "Arroser d'huile d'olive, saupoudrer de paprika, saler et poivrer.",
     "Parsemer de sésame grillé et servir.")
roti(457, "Couper les aubergines en deux dans la longueur et quadriller la chair au couteau.",
     "Les poser chair vers le haut, badigeonner largement d'huile d'olive, saler et poivrer.",
     "Napper de mélasse de grenade, parsemer de menthe ciselée et servir.", cuisson=40)

# Sauces
R(458, ["Plonger les tomates 30 secondes dans l'eau bouillante, puis les peler, les épépiner et les couper en petits dés.",
        "Ciseler le basilic.",
        "Faire tiédir l'huile d'olive 2 minutes à feu très doux, sans la faire chauffer.",
        "Mélanger l'huile avec les tomates et le basilic. Saler, poivrer et servir tiède sur un poisson ou des légumes."])
R(459, ["Râper le zeste du citron et presser son jus. Ciseler l'aneth.",
        "Faire chauffer la crème 3 minutes à feu doux.",
        "Ajouter le jus et le zeste du citron et l'aneth. Saler, poivrer.",
        "Servir chaud ou froid, avec un poisson."])
R(460, ["Éplucher les échalotes et les ciseler finement.",
        "Les faire fondre 5 minutes à feu doux dans 10 g de beurre.",
        "Verser le vinaigre balsamique et laisser réduire de moitié.",
        "Hors du feu, ajouter le reste du beurre en morceaux en fouettant. Saler, poivrer et servir aussitôt avec une viande."], cuisson=10)
R(461, ["Éplucher l'oignon et le hacher finement.",
        "Le faire fondre 3 minutes dans une casserole avec un filet d'huile.",
        "Ajouter le curry doux et remuer 1 minute.",
        "Verser le lait de coco et laisser épaissir 5 minutes à feu doux. Saler, poivrer."], cuisson=10)
R(462, ["Égoutter les câpres et les hacher grossièrement.",
        "Hacher finement le persil.",
        "Mélanger les câpres et le persil avec l'huile d'olive.",
        "Poivrer, goûter avant de saler (les câpres le sont déjà) et servir avec une viande ou un poisson grillés."], cuisson=0)
R(463, ["Rincer le demi-citron confit, retirer la pulpe et hacher finement l'écorce.",
        "Ciseler la ciboulette.",
        "Faire chauffer la crème 3 minutes à feu doux avec le citron confit.",
        "Ajouter la ciboulette, poivrer, saler peu et servir chaud ou froid."])
R(464, ["Râper le zeste de l'orange et presser son jus.",
        "Faire chauffer la crème avec le safran et le zeste à feu doux.",
        "Ajouter le jus d'orange et laisser réduire 5 minutes, jusqu'à ce que la sauce nappe la cuillère.",
        "Saler, poivrer et servir avec un poisson ou des Saint-Jacques."], cuisson=8)
R(465, ["Faire griller les cerneaux de noix 3 minutes dans une poêle sèche.",
        "Les mixer avec le parmesan, en versant l'huile d'olive petit à petit.",
        "Saler, poivrer et ajouter un peu d'eau si la sauce est trop épaisse.",
        "Servir avec des pâtes ou des légumes rôtis."], cuisson=3)
R(466, ["Ciseler la menthe.",
        "Râper le zeste du citron vert et presser son jus.",
        "Mélanger le yaourt grec avec la menthe, le jus et le zeste.",
        "Saler, poivrer et réserver au frais jusqu'au moment de servir."], cuisson=0)
R(467, ["Préchauffer le four à 220 °C. Poser les poivrons entiers sur une plaque et les rôtir 30 minutes, en les retournant, jusqu'à ce que la peau noircisse.",
        "Les laisser tiédir dans un sac fermé, puis les peler et les épépiner.",
        "Mixer les poivrons avec l'ail et l'huile d'olive.",
        "Saler, poivrer et servir tiède ou froid."], cuisson=30)

# Gâteaux : moule beurré, four à 180 °C
def gateau(n, prep, pate, cuisson=35, moule="un moule à manqué de 24 cm"):
    R(n, [f"Préchauffer le four à 180 °C. Beurrer et fariner {moule}.", prep,
          "Fouetter les œufs avec le sucre jusqu'à ce que le mélange blanchisse.",
          pate,
          f"Verser dans le moule et enfourner {cuisson} minutes environ : la lame d'un couteau doit ressortir sèche. Laisser tiédir avant de démouler."],
      (), cuisson)
gateau(468, "Mélanger la poudre de noisettes, la farine et la levure.",
       "Ajouter le beurre fondu, puis les poudres, et mélanger juste ce qu'il faut pour obtenir une pâte lisse.")
gateau(469, "Faire fondre le chocolat avec le beurre au bain-marie ou au micro-ondes.",
       "Ajouter la crème de marrons, puis le chocolat fondu, et enfin la farine mélangée à la levure.", cuisson=30)
gateau(470, "Éplucher les poires, retirer le cœur et les couper en dés.",
       "Ajouter le beurre fondu, puis la poudre d'amandes, la farine et la levure. Incorporer les poires.",
       cuisson=45, moule="un moule à cake")
gateau(471, "Râper le zeste des oranges et presser leur jus.",
       "Ajouter l'huile d'olive, le beurre fondu, le jus et le zeste des oranges, puis la farine mélangée à la levure.")
gateau(472, "Râper le zeste du citron et presser son jus. Rouler les myrtilles dans 1 cuillère à soupe de farine.",
       "Ajouter le beurre fondu, le jus et le zeste du citron, puis la farine mélangée à la levure. Incorporer délicatement les myrtilles.", cuisson=40)
gateau(473, "Écraser les bananes à la fourchette. Concasser les noix.",
       "Ajouter le beurre fondu et les bananes, puis la farine mélangée à la levure. Incorporer les noix.",
       cuisson=45, moule="un moule à cake")
gateau(474, "Râper le zeste du citron vert et presser son jus.",
       "Ajouter le beurre fondu, la noix de coco, le jus et le zeste, puis la farine mélangée à la levure.")
gateau(475, "Laver les abricots, les dénoyauter et les couper en quartiers. Concasser les pistaches.",
       "Ajouter le beurre fondu, puis la farine mélangée à la levure. Verser dans le moule, disposer les abricots dessus et parsemer de pistaches.", cuisson=40)
gateau(476, "Couper les dattes en petits morceaux.",
       "Ajouter le beurre fondu, puis la farine mélangée à la levure et à la cannelle. Incorporer les dattes.",
       cuisson=45, moule="un moule à cake")
gateau(477, "Laver les prunes, les dénoyauter et les couper en deux. Fendre la gousse de vanille et gratter les graines.",
       "Ajouter le beurre fondu et les graines de vanille, puis la farine mélangée à la levure. Verser dans le moule et enfoncer les prunes dans la pâte.", cuisson=40)

# Fruits rôtis, poêlés et pochés
def fruits(n, etapes, cuisson=25, **x):
    R(n, etapes, (), cuisson)
    E[n].update(x)
fruits(478, ["Préchauffer le four à 190 °C.",
             "Couper les pêches en deux et retirer les noyaux. Les disposer dans un plat beurré, face coupée vers le haut.",
             "Arroser de miel et de l'eau, saupoudrer de sucre, ajouter le beurre en petits morceaux et le romarin.",
             "Enfourner 20 à 25 minutes, en arrosant les pêches de leur jus à mi-cuisson.",
             "Servir tiède, avec une boule de glace à la vanille."])
fruits(479, ["Porter à ébullition 1 litre d'eau avec le sucre et le bâton de cannelle. Ajouter les sachets de thé et laisser infuser 5 minutes, puis les retirer.",
             "Éplucher les poires en gardant la queue.",
             "Les plonger dans le sirop et les pocher 20 à 25 minutes à petits frémissements, jusqu'à ce que la pointe d'un couteau s'y enfonce sans résistance.",
             "Les retirer, faire réduire le sirop de moitié avec le beurre.",
             "Servir les poires tièdes ou froides, nappées de sirop."], cuisson=30,
       remarques=["Les 3 cuillères à soupe d'eau de la recette d'origine ne suffisent pas pour pocher : prévoir 1 litre d'eau."])
fruits(480, ["Préchauffer le four à 190 °C.",
             "Couper les abricots en deux et retirer les noyaux. Les disposer dans un plat beurré, face coupée vers le haut.",
             "Arroser de miel et de l'eau, saupoudrer de sucre et de lavande, ajouter le beurre en petits morceaux.",
             "Enfourner 20 minutes.",
             "Servir tiède ou froid."], cuisson=20)
fruits(481, ["Éplucher l'ananas, retirer les yeux et le cœur, puis le couper en tranches épaisses.",
             "Râper le zeste d'un citron vert et presser les deux.",
             "Faire fondre le beurre dans une poêle, ajouter la cassonade, le sucre et l'eau et laisser caraméliser 2 minutes.",
             "Ajouter les tranches d'ananas et les dorer 5 minutes par face, en les arrosant de caramel.",
             "Arroser du jus de citron vert, parsemer de zeste et servir tiède."], cuisson=15)
fruits(482, ["Préchauffer le four à 190 °C.",
             "Laver les figues et les entailler en croix sur le dessus, sans aller jusqu'au bout.",
             "Les disposer dans un plat beurré, les arroser de miel et de l'eau, saupoudrer de sucre et parsemer d'amandes effilées.",
             "Enfourner 15 à 20 minutes.",
             "Servir tiède, avec du fromage blanc ou une glace."], cuisson=20)
fruits(483, ["Éplucher les pommes, retirer le cœur et les couper en quartiers.",
             "Faire fondre le beurre dans une grande poêle, ajouter la cassonade, le sucre et l'eau et laisser caraméliser 2 minutes.",
             "Ajouter les pommes et la cannelle et cuire 10 à 12 minutes à feu moyen, en les retournant, jusqu'à ce qu'elles soient tendres et nappées de caramel.",
             "Servir tiède."], cuisson=15)
fruits(484, ["Préchauffer le four à 180 °C.",
             "Éplucher les poires, les couper en deux et retirer le cœur. Les disposer dans un plat beurré, face coupée vers le bas.",
             "Saupoudrer de sucre, arroser de l'eau et enfourner 25 minutes.",
             "Faire fondre le chocolat avec le beurre. Concasser les amandes.",
             "Napper les poires de chocolat, parsemer d'amandes et servir tiède."])
fruits(485, ["Laver les prunes, les couper en deux et retirer les noyaux.",
             "Fendre la gousse de vanille et gratter les graines.",
             "Mettre les prunes dans une casserole avec le sucre, l'eau, le beurre, la gousse et les graines de vanille.",
             "Cuire 20 à 25 minutes à feu doux, à couvert, en remuant de temps en temps.",
             "Retirer la gousse et servir tiède ou froid."])
fruits(486, ["Éplucher les mangues et couper la chair en cubes.",
             "Éplucher et râper le gingembre. Râper le zeste d'un citron vert et presser les deux.",
             "Faire fondre le beurre dans une poêle avec le sucre, l'eau et le gingembre.",
             "Ajouter la mangue et la faire sauter 3 minutes.",
             "Arroser du jus de citron vert, parsemer de zeste et servir tiède ou froid."], cuisson=5)
fruits(487, ["Peler les oranges à vif et les couper en rondelles. Récupérer le jus.",
             "Couper les dattes en morceaux.",
             "Faire fondre le beurre dans une poêle avec le sucre, l'eau, le jus des oranges et la cannelle et laisser réduire 3 minutes.",
             "Ajouter les dattes, puis verser le sirop sur les oranges.",
             "Servir frais."], cuisson=5)

# Crèmes dessert : 4 ramequins
def creme(n, prep, parfum, fin="", cuisson=10):
    R(n, [prep,
          "Dans une casserole, délayer la fécule avec le sucre et un peu de lait froid.",
          "Ajouter le reste du lait " + parfum + " et porter à ébullition sans cesser de fouetter.",
          "Laisser épaissir 2 minutes à feu doux en fouettant." + (" " + fin if fin else ""),
          "Répartir dans 4 ramequins, laisser refroidir, puis réserver au moins 2 heures au frais."], (), cuisson)
creme(488, "Délayer la pâte de pistache avec un peu de lait.", "et la pâte de pistache")
creme(489, "Bien secouer la boîte de lait de coco avant de l'ouvrir.", "et le lait de coco")
creme(490, "Écraser les gousses de cardamome. Faire chauffer le lait avec la cardamome, laisser infuser 10 minutes à couvert, puis filtrer.",
      "infusé et le café soluble", cuisson=15)
creme(491, "Sortir 4 ramequins.", "", "Hors du feu, ajouter l'eau de fleur d'oranger.")
creme(492, "Fendre la gousse de vanille, gratter les graines et les mettre avec la gousse dans le lait.",
      "vanillé et le miel", "Retirer la gousse.")
creme(493, "Râper le zeste du citron. Hacher le chocolat blanc.", "et le zeste",
      "Hors du feu, ajouter le chocolat blanc et mélanger jusqu'à ce qu'il soit fondu.")
creme(494, "Sortir 4 ramequins.", "et la crème de marrons")
creme(495, "Délayer la purée de sésame noir avec un peu de lait.", "et le sésame noir")
creme(496, "Délayer le praliné avec un peu de lait.", "et le praliné")
creme(497, "Répartir les framboises au fond des 4 ramequins.", "", "Hors du feu, ajouter l'eau de rose.")
E[497]['etapes'][4] = "Verser la crème sur les framboises, laisser refroidir, puis réserver au moins 2 heures au frais."

if __name__ == '__main__':
    import json
    for n, v in E.items():
        v['etapes'] = [' '.join(e.split()).replace('  ', ' ') for e in v['etapes']]
    json.dump({str(k): E[k] for k in sorted(E)}, open('etapes-298-497.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(len(E))
