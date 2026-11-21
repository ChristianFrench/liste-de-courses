# Étapes récrites des recettes 398 à 447 (fruits de mer, plats végétariens, pâtes, risottos, gratins).
from etapes_lot2 import E, R

AIL = "Éplucher l'ail et le hacher."

R(398, ["Râper le zeste d'un citron vert et presser les deux. Ciseler la coriandre. " + AIL,
        "Faire chauffer l'huile d'olive à feu vif dans une grande poêle et faire sauter l'ail 30 secondes.",
        "Ajouter les crevettes et les cuire 3 à 4 minutes, jusqu'à ce qu'elles soient roses.",
        "Arroser du jus de citron vert, ajouter le zeste et la coriandre. Saler, poivrer et servir aussitôt."], cuisson=5)
R(399, ["Couper les encornets en anneaux et les sécher dans du papier absorbant. Hacher le persil. " + AIL,
        "Faire chauffer l'huile d'olive à feu très vif et saisir les encornets 2 à 3 minutes, sans trop remuer.",
        "Ajouter l'ail et le persil et faire sauter 1 minute.",
        "Arroser du jus du citron, saler, poivrer et servir aussitôt."],
    ["Une cuisson courte garde les encornets tendres : au-delà, ils deviennent caoutchouteux."], cuisson=5)
R(400, ["Faire tremper les palourdes 1 heure dans de l'eau froide salée pour les dessabler, puis les rincer. Jeter celles qui sont cassées ou ouvertes.",
        "Hacher le persil. " + AIL,
        "Faire chauffer l'huile d'olive dans une grande sauteuse et faire revenir l'ail 1 minute.",
        "Ajouter les palourdes, couvrir et cuire 5 minutes à feu vif en secouant la sauteuse, jusqu'à ce qu'elles s'ouvrent.",
        "Jeter celles qui restent fermées. Parsemer de persil, poivrer et servir aussitôt avec le jus."], cuisson=6)
R(401, ["Sécher les noix de Saint-Jacques dans du papier absorbant. Râper le zeste du citron et presser son jus. " + AIL,
        "Faire chauffer l'huile d'olive à feu vif et saisir les noix 1 minute 30 par face, sans les toucher. Les réserver au chaud.",
        "Baisser le feu, faire fondre le beurre avec l'ail, puis ajouter le jus et le zeste du citron.",
        "Saler, poivrer et napper les Saint-Jacques de beurre au citron. Servir aussitôt."], cuisson=5)
R(402, ["Retirer les premières feuilles de la citronnelle et émincer finement le cœur des tiges. " + AIL,
        "Faire revenir l'ail et la citronnelle 2 minutes dans l'huile d'olive.",
        "Verser le lait de coco et laisser frémir 5 minutes.",
        "Ajouter les crevettes et cuire 4 minutes, jusqu'à ce qu'elles soient roses.",
        "Saler, poivrer et servir avec du riz."], cuisson=12)
R(403, ["Couper les seiches en lanières. " + AIL,
        "Les faire revenir 5 minutes dans l'huile d'olive avec l'ail.",
        "Ajouter les tomates concassées, saler, poivrer, couvrir et laisser mijoter 40 minutes à feu doux, jusqu'à ce que les seiches soient tendres.",
        "Parsemer de basilic ciselé et servir."], cuisson=45)
R(404, ["Gratter et laver les moules, retirer les filaments. Jeter celles qui sont cassées ou ouvertes.",
        "Émincer finement le fenouil. " + AIL,
        "Dans un grand faitout, faire revenir le fenouil et l'ail 5 minutes dans l'huile d'olive. Ajouter les tomates et cuire 5 minutes.",
        "Ajouter les moules, couvrir et cuire 5 à 6 minutes à feu vif en remuant, jusqu'à ce qu'elles s'ouvrent.",
        "Jeter celles qui restent fermées, poivrer et servir aussitôt."], cuisson=16)
R(405, ["Couper les calamars en anneaux et les sécher. Couper le chorizo en rondelles. Épépiner le poivron et le couper en lanières. " + AIL,
        "Faire revenir le chorizo et le poivron 5 minutes dans l'huile d'olive.",
        "Ajouter les calamars et l'ail et faire sauter 3 minutes à feu vif.",
        "Poivrer, goûter avant de saler et servir aussitôt."], cuisson=10)
R(406, ["Éplucher et râper le gingembre. " + AIL,
        "Faire griller les graines de sésame 2 minutes dans un wok sec et les réserver.",
        "Faire chauffer l'huile d'olive dans le wok et faire sauter l'ail et le gingembre 30 secondes.",
        "Ajouter les crevettes et les cuire 3 à 4 minutes à feu vif.",
        "Saler, poivrer, parsemer de sésame et servir avec du riz."], cuisson=6)
R(407, ["Laver les poireaux et les émincer finement. " + AIL,
        "Les faire fondre 15 minutes à feu doux dans 1 cuillère à soupe d'huile d'olive, avec l'ail, à couvert.",
        "Ajouter la crème, saler, poivrer et laisser épaissir 3 minutes.",
        "Sécher les noix de Saint-Jacques et les saisir 1 minute 30 par face dans le reste de l'huile, à feu vif.",
        "Servir les Saint-Jacques posées sur les poireaux fondants."], cuisson=20)

# Plats végétariens
OIGNON = "Éplucher l'oignon et l'ail, émincer l'oignon et hacher l'ail."
R(408, ["Éplucher les patates douces et les couper en cubes. " + OIGNON,
        "Faire revenir l'oignon et l'ail 3 minutes dans l'huile d'olive, dans une cocotte.",
        "Ajouter les patates douces, le bouillon et le lait de coco. Couvrir et cuire 20 minutes.",
        "Ajouter les épinards et les laisser tomber 3 minutes.",
        "Saler, poivrer et servir avec du riz."], ["Ajouter 1 cuillère à café de curry avec l'oignon pour relever le plat."], cuisson=25)
R(409, ["Laver les aubergines et les couper en cubes. Rincer et égoutter les pois chiches. " + OIGNON,
        "Faire dorer les aubergines 10 minutes dans l'huile d'olive, dans une grande sauteuse.",
        "Ajouter l'oignon et l'ail et cuire 3 minutes.",
        "Ajouter les tomates, les pois chiches et le bouillon. Laisser mijoter 15 minutes à découvert.",
        "Saler, poivrer et servir chaud."])
R(410, ["Rincer les lentilles corail. Éplucher les carottes et les râper finement. Ciseler la coriandre. " + OIGNON,
        "Cuire les lentilles 12 minutes dans le bouillon, à feu doux, jusqu'à ce que tout le liquide soit absorbé. Laisser refroidir.",
        "Faire revenir l'oignon et l'ail 3 minutes dans un peu d'huile d'olive.",
        "Écraser les lentilles avec les carottes râpées, l'oignon, l'ail et la coriandre. Saler, poivrer et former 8 galettes.",
        "Les cuire 4 minutes par face dans le reste de l'huile, à feu moyen, jusqu'à ce qu'elles soient dorées."],
    ["Si la pâte est trop molle, ajouter 2 cuillères à soupe de farine."])
R(411, ["Rincer et égoutter les haricots noirs et le maïs. " + OIGNON,
        "Faire revenir l'oignon et l'ail 3 minutes dans l'huile d'olive, dans une cocotte.",
        "Ajouter les tomates, les haricots, le maïs et le bouillon.",
        "Laisser mijoter 25 minutes à découvert, jusqu'à ce que la sauce épaississe.",
        "Saler, poivrer et servir avec du riz."], ["Relever avec du cumin et du piment selon le goût."])
R(412, ["Préchauffer le four à 200 °C.",
        "Éplucher la courge, retirer les graines et la couper en cubes. " + OIGNON,
        "Faire revenir l'oignon et l'ail 3 minutes dans l'huile d'olive.",
        "Mettre la courge, les pois chiches égouttés et l'oignon dans un plat à gratin. Verser le bouillon, saler et poivrer.",
        "Émietter la feta par-dessus et enfourner 30 minutes, jusqu'à ce que la courge soit tendre."])
R(413, ["Égoutter le tofu, le presser dans du papier absorbant et le couper en cubes. Détailler le brocoli en petits bouquets. " + OIGNON,
        "Faire dorer le tofu 8 minutes dans l'huile d'olive, sur toutes les faces. Le réserver.",
        "Faire revenir l'oignon et l'ail 2 minutes, ajouter le brocoli et le bouillon, couvrir et cuire 6 minutes.",
        "Remettre le tofu, mélanger, saler, poivrer et parsemer de sésame grillé."], cuisson=20)
R(414, ["Préchauffer le four à 200 °C.",
        "Couper les aubergines en deux dans la longueur, quadriller la chair, arroser d'huile d'olive et les cuire 25 minutes au four.",
        "Cuire le boulgour 10 minutes dans le bouillon. " + OIGNON + " Les faire revenir 3 minutes.",
        "Évider les aubergines, hacher la chair et la mélanger au boulgour, à l'oignon et à la feta émiettée. Saler, poivrer.",
        "Garnir les aubergines et les remettre 15 minutes au four."], cuisson=40)
R(415, ["Préchauffer le four à 190 °C.",
        "Couper un chapeau aux courgettes et les évider à la cuillère. Hacher la chair et couper les tomates en dés.",
        "Rincer le quinoa et le cuire 12 minutes dans le bouillon. " + OIGNON,
        "Faire revenir l'oignon, l'ail et la chair des courgettes 5 minutes dans l'huile d'olive, ajouter les tomates et le quinoa. Saler, poivrer.",
        "Garnir les courgettes, poser les chapeaux et enfourner 30 minutes."], cuisson=45)
R(416, ["Rincer les lentilles. " + OIGNON,
        "Faire revenir l'oignon et l'ail 3 minutes dans l'huile d'olive, dans une cocotte.",
        "Ajouter les lentilles, le bouillon et 500 ml d'eau. Couvrir et cuire 25 minutes.",
        "Ajouter le lait de coco et les épinards et cuire encore 5 minutes.",
        "Saler en fin de cuisson, poivrer et servir."])
R(417, ["Préchauffer le four à 190 °C.",
        "Cuire le riz 12 minutes à l'eau salée et l'égoutter. " + OIGNON,
        "Nettoyer les champignons, les hacher et les faire revenir 5 minutes avec l'oignon et l'ail dans l'huile d'olive. Mélanger avec le riz, saler et poivrer.",
        "Couper un chapeau aux poivrons, les épépiner et les garnir du mélange.",
        "Les poser dans un plat, verser le bouillon au fond, couvrir des chapeaux et enfourner 40 minutes."], cuisson=55)

# Pâtes
PATES = "Cuire les pâtes dans une grande casserole d'eau bouillante salée, selon le temps indiqué sur le paquet. Garder une petite tasse d'eau de cuisson avant de les égoutter."
LIER = "Mélanger les pâtes égouttées avec la garniture, en ajoutant un peu d'eau de cuisson pour lier. Poivrer et servir aussitôt."
R(418, [PATES, "Laver les courgettes et les couper en fines rondelles. Râper le zeste du citron et presser son jus. " + AIL,
        "Faire dorer les courgettes 6 minutes dans l'huile d'olive avec l'ail. Saler.",
        "Ajouter le zeste et le jus de citron.", LIER])
R(419, [PATES, "Égoutter les tomates séchées et les couper en lanières. Laver la roquette. " + AIL,
        "Faire chauffer l'huile d'olive avec l'ail 1 minute, ajouter les tomates séchées.",
        LIER.replace("Poivrer", "Ajouter la roquette au dernier moment. Poivrer")])
R(420, [PATES, "Râper le zeste du citron vert et presser son jus. " + AIL,
        "Faire sauter l'ail 30 secondes dans l'huile d'olive, ajouter les crevettes et les cuire 3 à 4 minutes.",
        "Ajouter le jus et le zeste du citron vert. Saler.", LIER])
R(421, ["Éplucher le potiron et le couper en cubes. " + AIL,
        "Cuire le potiron et l'ail 15 minutes dans une casserole d'eau salée, puis les égoutter.",
        PATES,
        "Mixer le potiron avec l'huile d'olive, la moitié du parmesan et un peu d'eau de cuisson des pâtes. Saler, poivrer.",
        "Mélanger les pâtes avec la crème de potiron et servir avec le reste du parmesan."], cuisson=25)
R(422, ["Détailler le brocoli en petits bouquets. " + AIL,
        "Cuire les orecchiette dans une grande casserole d'eau salée ; ajouter le brocoli 5 minutes avant la fin. Garder une tasse d'eau de cuisson.",
        "Faire fondre les anchois dans l'huile d'olive à feu doux, avec l'ail, en les écrasant.",
        "Ajouter les pâtes et le brocoli égouttés et mélanger en ajoutant un peu d'eau de cuisson.",
        "Poivrer, goûter avant de saler et servir aussitôt."])
R(423, [PATES, "Couper les cœurs d'artichauts en quartiers. " + AIL,
        "Faire revenir l'ail et les artichauts 5 minutes dans l'huile d'olive, ajouter les olives noires.", LIER])
R(424, [PATES, "Laver les poireaux et les émincer. " + AIL,
        "Faire fondre les poireaux et l'ail 10 minutes dans l'huile d'olive, à couvert. Saler.",
        "Faire griller les noisettes à sec et les concasser.",
        LIER.replace("Poivrer", "Parsemer de noisettes. Poivrer")])
R(425, [PATES, AIL,
        "Faire tomber les épinards 3 minutes dans l'huile d'olive avec l'ail. Saler.",
        "Ajouter la ricotta et la délayer avec un peu d'eau de cuisson.", LIER])
R(426, [PATES, "Laver les courgettes et les tailler en fins bâtonnets. " + AIL,
        "Faire griller les pignons à sec 2 minutes et les réserver.",
        "Faire sauter les courgettes et l'ail 5 minutes dans l'huile d'olive. Saler.",
        LIER.replace("Poivrer", "Parsemer de pignons. Poivrer")])
R(427, [PATES, "Couper le jambon cru en lanières. " + AIL,
        "Cuire les petits pois 5 minutes à l'eau bouillante, ou les ajouter aux pâtes 5 minutes avant la fin.",
        "Faire revenir l'ail 1 minute dans l'huile d'olive, ajouter les petits pois et le jambon.",
        LIER.replace("Poivrer", "Poivrer, goûter avant de saler")])

# Risottos : même méthode
def risotto(n, prep, avant, fin, conseils=()):
    R(n, [prep + " Éplucher et ciseler l'oignon. Garder le bouillon chaud sur feu doux.",
          "Faire revenir l'oignon 3 minutes dans l'huile d'olive et la moitié du beurre, dans une sauteuse.",
          "Ajouter le riz et le remuer 2 minutes, jusqu'à ce qu'il devienne translucide. Verser le vin blanc et laisser évaporer.",
          "Ajouter le bouillon louche par louche, en remuant, et attendre qu'il soit absorbé avant d'en remettre, pendant 18 minutes environ. " + avant,
          "Hors du feu, ajouter le reste du beurre. " + fin + " Saler, poivrer, couvrir 2 minutes et servir."], conseils)
risotto(428, "Râper le zeste du citron et presser son jus.", "Ajouter les petits pois à mi-cuisson.", "Ajouter le jus et le zeste du citron.")
risotto(429, "Éplucher le potiron et le couper en petits dés. Ciseler la sauge.", "Ajouter le potiron avec la première louche de bouillon.", "Ajouter la sauge.")
risotto(430, "Laver les poireaux, les émincer et les faire fondre 5 minutes avec l'oignon.", "", "Ajouter le parmesan râpé.")
risotto(431, "Éplucher les betteraves et les mixer.", "Ajouter la purée de betterave 5 minutes avant la fin.", "Parsemer de chèvre émietté.")
risotto(432, "Râper le zeste du citron et presser son jus.", "Ajouter les épinards 3 minutes avant la fin.", "Ajouter le jus et le zeste du citron.")
risotto(433, "Couper les tomates confites en morceaux. Ciseler le basilic.", "Ajouter les tomates 5 minutes avant la fin.", "Ajouter le basilic.")
risotto(434, "Émincer finement le fenouil. Râper le zeste de l'orange et presser son jus.", "Faire revenir le fenouil avec l'oignon au début.", "Ajouter le jus et le zeste de l'orange.")
risotto(435, "Laver les courgettes et les couper en petits dés. Ciseler la menthe.", "Ajouter les courgettes à mi-cuisson.", "Ajouter la menthe.")
risotto(436, "Nettoyer les champignons et les faire sauter 5 minutes à feu vif dans une poêle. Griller les noisettes à sec et les concasser.", "Ajouter les champignons 5 minutes avant la fin.", "Parsemer de noisettes.")
risotto(437, "Couper les cœurs d'artichauts en lamelles. Râper le zeste du citron et presser son jus.", "Ajouter les artichauts à mi-cuisson.", "Ajouter le jus et le zeste du citron.")

# Gratins : four à 200 °C
def gratin(n, prep, montage, conseils=(), cuisson=None, sans=None, remarques=None):
    R(n, ["Préchauffer le four à 200 °C. Frotter un plat à gratin avec la gousse d'ail coupée en deux.",
          prep, montage,
          "Enfourner 30 à 35 minutes, jusqu'à ce que le dessus soit bien doré."], conseils, cuisson)
    if sans: E[n]['sans'] = sans
    if remarques: E[n]['remarques'] = remarques
CREME = "Mélanger la crème et le lait avec la muscade, du sel et du poivre, et verser sur les légumes."
gratin(438, "Couper les fenouils en quartiers et les cuire 10 minutes à l'eau bouillante salée. Les égoutter et les disposer dans le plat.",
       CREME + " Couvrir de parmesan râpé.", cuisson=45)
gratin(439, "Laver les blettes, émincer les côtes et les feuilles, les cuire 8 minutes à l'eau salée et les égoutter en les pressant.",
       "Mélanger la ricotta avec le lait, la muscade, du sel et du poivre, puis avec les blettes. Verser dans le plat et couvrir de parmesan.", cuisson=45)
gratin(440, "Éplucher les patates douces et les couper en fines rondelles. Les disposer dans le plat en couches, en parsemant de thym.",
       CREME, cuisson=45)
gratin(441, "Laver les poireaux, les couper en tronçons et les cuire 10 minutes à l'eau salée. Les égoutter et les disposer dans le plat.",
       "Mélanger le lait avec la moutarde, la muscade, du sel et du poivre, verser sur les poireaux et couvrir de comté râpé.", cuisson=45)
gratin(442, "Détailler le brocoli en bouquets, les cuire 5 minutes à l'eau salée et les disposer dans le plat.",
       CREME + " Parsemer d'amandes effilées.", cuisson=35)
gratin(443, "Éplucher la courge, retirer les graines, la couper en fines tranches et les disposer dans le plat.",
       CREME + " Émietter le bleu par-dessus.", cuisson=40)
gratin(444, "Éplucher les panais et les pommes de terre et les couper en fines rondelles. Les disposer dans le plat en les alternant.",
       CREME, cuisson=50)
gratin(445, "Couper les tomates en rondelles épaisses et les disposer dans le plat. Saler, poivrer et ajouter une pincée de muscade.",
       "Mélanger la chapelure et le parmesan râpé, en couvrir les tomates et arroser d'un filet d'huile d'olive.", cuisson=30,
       sans=['Lait'], remarques=["Le lait de la recette d'origine a été retiré : il n'a pas d'usage dans ce gratin. Ajouter 2 cuillères à soupe d'huile d'olive."])
gratin(446, "Éplucher le céleri-rave, le couper en fines tranches et les cuire 8 minutes à l'eau salée. Les égoutter et les disposer dans le plat.",
       CREME + " Couvrir de comté râpé.", cuisson=45)
gratin(447, "Retirer le pied amer des endives, les couper en deux dans la longueur et les cuire 10 minutes à l'eau salée. Les égoutter en les pressant et les disposer dans le plat.",
       CREME + " Poser le chèvre en rondelles par-dessus.", cuisson=45)
