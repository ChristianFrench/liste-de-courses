# Étapes récrites des recettes 348 à 397 (plats : volailles, viandes, poissons).
from etapes_lot1 import E, R

OIGNON = "Éplucher l'oignon et l'ail, émincer l'oignon et hacher l'ail."
SERVIR = "Rectifier l'assaisonnement et servir chaud."

# Poulet : colorer, puis mijoter 30 minutes
def poulet(n, prep, colorer, garniture, fin, conseils=(), cuisson=None):
    R(n, [prep, OIGNON,
          f"Dans une cocotte, faire dorer {colorer} 5 minutes dans l'huile d'olive, sur toutes les faces. Saler, poivrer et réserver.",
          "Faire revenir l'oignon et l'ail 3 minutes dans la même cocotte.",
          garniture, fin], conseils, cuisson)

poulet(348, "Laver les figues et les couper en deux.", "les hauts de cuisse",
       "Remettre le poulet, ajouter le bouillon et le romarin. Couvrir et laisser mijoter 20 minutes.",
       "Ajouter les figues et poursuivre la cuisson 10 minutes à découvert. " + SERVIR)
poulet(349, "Couper les filets de poulet en morceaux. Effeuiller et ciseler l'estragon.", "les morceaux de poulet",
       "Verser le vin blanc et laisser réduire 2 minutes. Remettre le poulet, ajouter le bouillon, couvrir et cuire 15 minutes.",
       "Ajouter l'estragon, laisser réduire la sauce 5 minutes à découvert. " + SERVIR, cuisson=25)
poulet(350, "Épépiner les poivrons et les couper en lanières.", "les cuisses de poulet",
       "Ajouter les poivrons et le paprika fumé, remuer 2 minutes. Remettre le poulet, verser le bouillon, couvrir et cuire 30 minutes.",
       SERVIR, cuisson=35)
poulet(351, "Faire dorer les amandes 3 minutes dans une poêle sèche et les réserver.", "les cuisses de poulet",
       "Remettre le poulet, ajouter les pruneaux et le bouillon. Couvrir et laisser mijoter 30 minutes.",
       "Parsemer d'amandes grillées au moment de servir.", cuisson=35)
poulet(352, "Couper les filets de poulet en morceaux. Râper le zeste du citron et presser son jus.", "les morceaux de poulet avec les feuilles de sauge",
       "Remettre le poulet, ajouter le bouillon, le jus et le zeste du citron. Couvrir et cuire 15 minutes.",
       "Laisser réduire la sauce 5 minutes à découvert. " + SERVIR, cuisson=25)
poulet(353, "Égoutter les tomates séchées et les couper en lanières.", "les cuisses de poulet",
       "Remettre le poulet, ajouter les olives, les tomates séchées et le bouillon. Couvrir et laisser mijoter 30 minutes.",
       "Goûter avant de saler (les olives le sont déjà) et servir chaud.", cuisson=35)
poulet(354, "Couper les filets de poulet en morceaux.", "les morceaux de poulet",
       "Remettre le poulet, ajouter le miel et le bouillon et cuire 10 minutes à découvert, en remuant, jusqu'à ce que la sauce nappe le poulet.",
       "Faire griller les graines de sésame à sec 2 minutes et en parsemer le poulet. Servir avec du riz.", cuisson=20)
poulet(355, "Nettoyer les champignons et les émincer.", "les cuisses de poulet",
       "Ajouter les champignons et les faire revenir 5 minutes. Remettre le poulet, verser le cidre et le bouillon, couvrir et laisser mijoter 30 minutes.",
       "Laisser réduire la sauce quelques minutes à découvert si elle est trop liquide. " + SERVIR, cuisson=40)
poulet(356, "Couper les filets de poulet en morceaux et les abricots secs en deux.", "les morceaux de poulet",
       "Ajouter la cannelle et remuer 1 minute. Remettre le poulet, ajouter les abricots et le bouillon, couvrir et cuire 20 minutes.",
       SERVIR + " Servir avec de la semoule.", cuisson=25)
poulet(357, "Couper les fenouils en quartiers. Presser une orange et couper l'autre en rondelles.", "les cuisses de poulet",
       "Ajouter le fenouil, remettre le poulet, verser le jus d'orange et le bouillon. Couvrir et laisser mijoter 30 minutes.",
       "Ajouter les rondelles d'orange 5 minutes avant la fin. " + SERVIR, cuisson=35)

# Bœuf mijoté : 1 h 30 environ
def mijote(n, prep, garniture, fin, conseils=(), cuisson=90):
    R(n, [prep, OIGNON,
          "Couper le bœuf en gros cubes et les faire dorer dans l'huile, par petites quantités, dans une cocotte. Saler, poivrer et réserver.",
          "Faire revenir l'oignon et l'ail 3 minutes dans la cocotte.",
          garniture, fin], conseils, cuisson)

def saute(n, prep, ajout, fin, conseils=(), cuisson=15):
    R(n, [prep, OIGNON,
          "Faire chauffer l'huile à feu vif dans une grande poêle ou un wok et saisir le bœuf 2 minutes. Le réserver.",
          ajout, fin], conseils, cuisson)

mijote(358, "Nettoyer les champignons et les couper en quartiers.",
       "Verser le porto et le bouillon, remettre la viande, couvrir et laisser mijoter 1 heure à feu doux.",
       "Ajouter les champignons et poursuivre la cuisson 30 minutes. " + SERVIR)
saute(359, "Détailler le brocoli en petits bouquets et les cuire 4 minutes à l'eau bouillante. Éplucher et râper le gingembre.",
      "Faire sauter l'oignon, l'ail et le gingembre 2 minutes, ajouter le brocoli et un peu de bouillon et cuire 3 minutes.",
      "Remettre le bœuf, mélanger 1 minute, saler, poivrer et servir aussitôt avec du riz.")
R(360, ["Ciseler la menthe. Éplucher l'oignon et l'ail et les hacher finement.",
        "Mélanger le bœuf haché avec la moitié de l'oignon et de l'ail, la menthe, le cumin, du sel et du poivre. Former des boulettes.",
        "Les faire dorer 5 minutes dans l'huile, dans une sauteuse, en les retournant.",
        "Ajouter le reste de l'oignon et de l'ail, puis le bouillon. Couvrir et laisser mijoter 15 minutes.",
        "Servir chaud avec de la semoule ou du boulgour."], cuisson=25)
mijote(361, "Égoutter les olives noires.",
       "Ajouter les tomates concassées et le bouillon, remettre la viande, couvrir et laisser mijoter 1 h 15 à feu doux.",
       "Ajouter les olives 15 minutes avant la fin. Goûter avant de saler et servir chaud.")
saute(362, "Écraser légèrement le poivre vert.",
      "Faire revenir l'oignon et l'ail 3 minutes, ajouter le bouillon et le poivre vert et laisser réduire de moitié.",
      "Ajouter la crème, remettre le bœuf et chauffer 2 minutes sans faire bouillir. Saler et servir aussitôt.")
saute(363, "Couper le rumsteck en fines lanières. Épépiner les poivrons et les couper en lanières.",
      "Faire sauter l'oignon, l'ail et les poivrons 5 minutes à feu vif, en ajoutant un peu de bouillon.",
      "Remettre le bœuf, mélanger 1 minute, saler, poivrer et parsemer de sésame grillé.")
mijote(364, "Éplucher les carottes et les couper en rondelles épaisses.",
       "Verser la bière brune et le bouillon, remettre la viande, ajouter les carottes, couvrir et laisser mijoter 1 h 30 à feu doux.",
       SERVIR + " Servir avec des pommes de terre vapeur.", cuisson=100)
R(365, ["Faire tomber les épinards 3 minutes à la poêle, les presser pour retirer l'eau et les hacher. Éplucher l'oignon et l'ail et les hacher.",
        "Mélanger le bœuf haché avec les épinards, le parmesan, la moitié de l'oignon et de l'ail, du sel et du poivre. Former des boulettes.",
        "Les faire dorer 5 minutes dans l'huile, dans une sauteuse, en les retournant.",
        "Ajouter le reste de l'oignon et de l'ail, puis le bouillon. Couvrir et laisser mijoter 15 minutes.",
        "Servir chaud avec des pâtes."], cuisson=25)
saute(366, "Couper le bœuf en fines lanières. Éplucher les oignons rouges et les couper en lamelles.",
      "Faire fondre les oignons rouges et l'oignon avec l'ail 8 minutes à feu moyen, puis verser le vinaigre balsamique et un peu de bouillon et laisser réduire.",
      "Remettre le bœuf, mélanger 1 minute, saler, poivrer et servir aussitôt.")
mijote(367, "Éplucher les panais et les couper en gros tronçons.",
       "Verser le bouillon, remettre la viande, ajouter le thym, couvrir et laisser mijoter 1 heure à feu doux.",
       "Ajouter les panais et poursuivre la cuisson 30 minutes. " + SERVIR)

# Porc
OIGNON_P = OIGNON
R(368, ["Éplucher les pommes, retirer le cœur et les couper en quartiers. " + OIGNON,
        "Faire dorer le filet mignon entier dans l'huile, dans une cocotte, 5 minutes sur toutes les faces. Saler, poivrer et réserver.",
        "Faire revenir l'oignon, l'ail et les pommes 5 minutes.",
        "Remettre le filet mignon, verser le cidre et le bouillon, couvrir et cuire 25 minutes à feu doux.",
        "Couper le filet en tranches et servir nappé de sauce, avec les pommes."], cuisson=35)
def porc(n, prep, garniture, fin, cuisson=45):
    R(n, [prep, OIGNON,
          "Faire dorer la viande dans l'huile, dans une cocotte, 5 minutes en remuant. Saler, poivrer et réserver.",
          "Faire revenir l'oignon et l'ail 3 minutes.",
          garniture, fin], (), cuisson)
porc(369, "Couper le citron en fines rondelles.",
     "Remettre la viande, ajouter le bouillon et les rondelles de citron, couvrir et laisser mijoter 40 minutes.",
     "Ajouter les olives 10 minutes avant la fin. Goûter avant de saler et servir chaud.")
R(370, ["Éplucher et râper le gingembre. " + OIGNON,
        "Faire chauffer l'huile à feu vif dans un wok et saisir le porc 5 minutes. Le réserver.",
        "Faire sauter l'oignon, l'ail et le gingembre 2 minutes.",
        "Remettre le porc, ajouter le miel et un peu de bouillon et laisser caraméliser 3 minutes en remuant.",
        "Saler, poivrer et servir aussitôt avec du riz."], cuisson=15)
R(371, ["Préchauffer le four à 180 °C. " + OIGNON,
        "Faire dorer le rôti dans l'huile, dans une cocotte allant au four, sur toutes les faces. Saler et poivrer.",
        "Ajouter l'oignon, l'ail, les feuilles de sauge, les pruneaux et le bouillon.",
        "Couvrir et enfourner 50 minutes, en arrosant le rôti de temps en temps.",
        "Laisser reposer 10 minutes, couper en tranches et servir avec les pruneaux et le jus."], cuisson=60)
porc(372, "Nettoyer les champignons et les émincer. Effeuiller et ciseler l'estragon.",
     "Ajouter les champignons, remettre la viande, verser le bouillon, couvrir et laisser mijoter 40 minutes.",
     "Ajouter l'estragon en fin de cuisson. " + SERVIR)
porc(373, "Épépiner les poivrons et les couper en lanières.",
     "Ajouter les poivrons et le piment doux, remettre la viande, verser le bouillon, couvrir et laisser mijoter 40 minutes.",
     SERVIR + " Servir avec du riz.")
R(374, ["Laver les figues et les couper en deux. " + OIGNON,
        "Faire dorer le filet mignon entier dans l'huile, dans une cocotte, 5 minutes sur toutes les faces. Saler, poivrer et réserver.",
        "Faire revenir l'oignon et l'ail 3 minutes, puis déglacer avec le vinaigre balsamique.",
        "Remettre le filet mignon, verser le bouillon, couvrir et cuire 20 minutes. Ajouter les figues et poursuivre 5 minutes.",
        "Couper le filet en tranches et servir avec les figues et la sauce."], cuisson=30)
porc(375, "Émincer finement le chou rouge. Éplucher la pomme et la couper en dés.",
     "Ajouter le chou et la pomme, remettre la viande, verser le bouillon, couvrir et laisser mijoter 45 minutes à feu doux.",
     SERVIR, cuisson=50)
porc(376, "Couper les abricots secs en deux.",
     "Ajouter le cumin, remettre la viande, ajouter les abricots et le bouillon, couvrir et laisser mijoter 40 minutes.",
     SERVIR + " Servir avec de la semoule.")
R(377, ["Râper le zeste d'une orange et presser les deux. " + OIGNON,
        "Couper le filet de porc en médaillons et les faire dorer dans l'huile 3 minutes par face. Saler, poivrer et réserver.",
        "Faire revenir l'oignon et l'ail 3 minutes.",
        "Verser le jus d'orange et le bouillon, ajouter le romarin et le zeste, remettre la viande, couvrir et cuire 15 minutes.",
        "Laisser réduire la sauce 5 minutes à découvert et servir chaud."], cuisson=25)

# Agneau mijoté : 1 h 15 environ
def agneau(n, prep, garniture, fin, cuisson=80):
    R(n, [prep, OIGNON,
          "Couper l'agneau en cubes si besoin et le faire dorer dans l'huile d'olive, dans une cocotte, par petites quantités. Saler, poivrer et réserver.",
          "Faire revenir l'oignon et l'ail 3 minutes.",
          garniture, fin], (), cuisson)
agneau(378, "Rincer et égoutter les pois chiches.",
       "Ajouter le cumin et remuer 1 minute. Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les pois chiches et poursuivre la cuisson 15 minutes. " + SERVIR)
agneau(379, "Couper les cœurs d'artichauts en quartiers.",
       "Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les artichauts et les petits pois et poursuivre la cuisson 15 minutes. " + SERVIR)
agneau(380, "Rincer le citron confit, le couper en quartiers et retirer les pépins.",
       "Remettre la viande, ajouter le citron confit et le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les olives et poursuivre la cuisson 15 minutes. Goûter avant de saler et servir chaud.")
R(381, ["Râper le zeste du citron et presser son jus. " + OIGNON,
        "Mélanger l'agneau haché avec la moitié de l'oignon et de l'ail, du sel et du poivre. Former des boulettes.",
        "Les faire dorer 5 minutes dans l'huile d'olive, puis ajouter le reste de l'oignon et le bouillon. Couvrir et cuire 15 minutes.",
        "Mélanger le yaourt grec avec le jus et le zeste du citron, saler et poivrer.",
        "Servir les boulettes chaudes avec la sauce au yaourt."], cuisson=25)
agneau(382, "Laver les aubergines et les couper en cubes. Ciseler la coriandre.",
       "Ajouter les aubergines et les faire revenir 5 minutes. Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 h 15.",
       "Parsemer de coriandre au moment de servir.")
agneau(383, "Faire dorer les amandes 3 minutes dans une poêle sèche et les réserver.",
       "Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les dattes et poursuivre la cuisson 15 minutes. Parsemer d'amandes et servir avec de la semoule.")
agneau(384, "Couper les fenouils en quartiers. Couper les tomates en morceaux.",
       "Remettre la viande, ajouter les tomates et le bouillon, couvrir et laisser mijoter 45 minutes.",
       "Ajouter les fenouils et poursuivre la cuisson 30 minutes. " + SERVIR)
agneau(385, "Laver les courgettes et les couper en rondelles épaisses. Ciseler la menthe.",
       "Remettre la viande, verser le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les courgettes et poursuivre la cuisson 15 minutes. Parsemer de menthe et servir.")
agneau(386, "Effeuiller le thym.",
       "Remettre la viande, ajouter le miel, le thym et le bouillon, couvrir et laisser mijoter 1 h 15 à feu doux.",
       "Laisser réduire la sauce à découvert jusqu'à ce qu'elle nappe la viande. " + SERVIR)
agneau(387, "Rincer et égoutter les haricots blancs.",
       "Remettre la viande, ajouter le romarin et le bouillon, couvrir et laisser mijoter 1 heure.",
       "Ajouter les haricots et poursuivre la cuisson 15 minutes. " + SERVIR)

# Poissons
R(388, ["Préchauffer le four à 200 °C.",
        "Disposer les filets de lieu noir dans un plat huilé. Saler et poivrer.",
        "Arroser du jus du citron et du vin blanc (ou du bouillon), répartir les câpres.",
        "Enfourner 15 à 20 minutes, jusqu'à ce que la chair se détache en lamelles.",
        "Servir arrosé du jus de cuisson."])
R(389, ["Couper les fenouils en fines lamelles et les tomates en morceaux.",
        "Faire revenir le fenouil 10 minutes dans l'huile d'olive, dans une sauteuse. Ajouter les tomates et le vin blanc (ou le bouillon) et cuire 10 minutes.",
        "Saler et poivrer les filets de merlu et les poser sur les légumes.",
        "Couvrir et cuire 8 à 10 minutes à feu doux.",
        "Servir aussitôt."], cuisson=30)
R(390, ["Préchauffer le four à 200 °C.",
        "Laver les poireaux et les émincer finement. Les faire fondre 10 minutes dans l'huile d'olive.",
        "Découper 4 grandes feuilles de papier cuisson. Répartir les poireaux, poser un filet de truite, saler, poivrer et ajouter une rondelle de citron et un peu de vin blanc (ou de bouillon).",
        "Fermer les papillotes et enfourner 15 minutes.",
        "Servir dans les papillotes."], cuisson=25)
R(391, ["Préchauffer le four à 200 °C.",
        "Hacher le persil et le mélanger avec la chapelure, l'huile d'olive, du sel et du poivre.",
        "Disposer les dos de cabillaud dans un plat, verser le vin blanc (ou le bouillon) au fond.",
        "Couvrir le dessus des poissons du mélange aux herbes en le tassant.",
        "Enfourner 15 à 20 minutes, jusqu'à ce que la croûte soit dorée."])
R(392, ["Préchauffer le four à 200 °C.",
        "Mélanger le sirop d'érable avec la moutarde et l'huile d'olive.",
        "Disposer les pavés de saumon dans un plat, verser le vin blanc (ou le bouillon) au fond. Saler et poivrer.",
        "Badigeonner les pavés du mélange à l'érable.",
        "Enfourner 12 à 15 minutes : le cœur doit rester légèrement rosé."], cuisson=15)
R(393, ["Préchauffer le four à 200 °C.",
        "Couper le fenouil en fines lamelles et le citron en rondelles.",
        "Répartir le fenouil dans un plat huilé. Poser les daurades dessus, glisser quelques rondelles de citron dans le ventre et sur le dessus.",
        "Saler, poivrer, arroser d'huile d'olive et de vin blanc (ou de bouillon).",
        "Enfourner 25 minutes."], cuisson=25)
R(394, ["Laver les poireaux et les émincer. Les faire fondre 10 minutes dans l'huile d'olive, à couvert, avec le vin blanc (ou le bouillon).",
        "Couper le haddock en 4 morceaux.",
        "Porter le lait à frémissement, y plonger le haddock et le pocher 8 minutes sans faire bouillir.",
        "Égoutter le poisson. Poivrer les poireaux (le haddock est salé).",
        "Servir le haddock sur les poireaux fondus."])
R(395, ["Couper la lotte en médaillons épais. Saler et poivrer.",
        "Les faire dorer 2 minutes par face dans l'huile d'olive, dans une sauteuse.",
        "Ajouter les tomates cerises et le vin blanc (ou le bouillon), couvrir et cuire 10 minutes.",
        "Parsemer de basilic ciselé et servir aussitôt."], cuisson=15)
R(396, ["Préchauffer le four à 200 °C.",
        "Rincer les maquereaux, les sécher et faire 3 entailles sur chaque face.",
        "Les badigeonner de moutarde à l'ancienne, saler et poivrer.",
        "Les disposer dans un plat huilé avec des rondelles de citron et le vin blanc (ou le bouillon).",
        "Enfourner 20 minutes."])
R(397, ["Préchauffer le four à 200 °C.",
        "Couper les tomates en rondelles et les disposer dans un plat huilé. Saler et poivrer.",
        "Poser les filets de rouget dessus, peau vers le haut, et répartir les olives noires.",
        "Arroser d'huile d'olive et de vin blanc (ou de bouillon).",
        "Enfourner 12 à 15 minutes."], cuisson=15)
