# Étapes récrites des recettes 298 à 347 (entrées). E[n] = (étapes, conseils, temps de cuisson corrigé ou None)
E = {}
def R(n, etapes, conseils=(), cuisson=None):
    E[n] = dict(etapes=list(etapes), conseils=list(conseils), **({'cuisson': cuisson} if cuisson is not None else {}))

VINAIGRETTE = "Dans un saladier, fouetter l'huile d'olive avec le vinaigre (ou le jus de citron), du sel et du poivre."

R(298, ["Éplucher les betteraves et les couper en dés.",
        "Peler les oranges à vif et prélever les suprêmes au-dessus d'un bol pour garder le jus.",
        VINAIGRETTE + " Ajouter le jus des oranges.",
        "Mélanger les betteraves et les suprêmes d'orange avec la vinaigrette.",
        "Concasser grossièrement les cerneaux de noix et les parsemer au moment de servir."])
R(299, ["Retirer la première couche des fenouils, les couper en deux et les émincer très finement.",
        "Couper les pommes en quartiers, retirer le cœur et les tailler en fines lamelles.",
        "Râper le zeste du citron et presser son jus. Arroser aussitôt les pommes et le fenouil de jus pour qu'ils ne noircissent pas.",
        VINAIGRETTE,
        "Mélanger le fenouil et les pommes avec la vinaigrette, parsemer de zeste et servir frais."])
R(300, ["Rincer le quinoa, puis le cuire 12 minutes dans deux fois son volume d'eau salée. L'égoutter et le laisser refroidir.",
        "Couper la grenade en deux et taper sur le dos de chaque moitié pour faire tomber les grains.",
        "Ciseler les feuilles de menthe.",
        VINAIGRETTE,
        "Mélanger le quinoa, les grains de grenade et la menthe avec la vinaigrette. Servir frais."], cuisson=12)
R(301, ["Laver le concombre, le couper en deux dans la longueur, retirer les graines et le tailler en demi-rondelles.",
        "Équeuter les radis, les laver et les couper en fines rondelles.",
        "Ciseler l'aneth.",
        VINAIGRETTE,
        "Mélanger le concombre, les radis et l'aneth avec la vinaigrette juste avant de servir."],
    ["Saler au dernier moment : le concombre rend de l'eau."])
R(302, ["Rincer et égoutter les haricots blancs.",
        "Éplucher l'oignon rouge et l'émincer finement.",
        "Émietter le thon.",
        VINAIGRETTE,
        "Mélanger les haricots, l'oignon et le thon avec la vinaigrette. Laisser reposer 10 minutes au frais avant de servir."])
R(303, ["Laver et essorer la roquette.",
        "Couper les poires en quartiers, retirer le cœur et les tailler en lamelles.",
        "Faire des copeaux de parmesan avec un économe.",
        VINAIGRETTE,
        "Disposer la roquette et les poires dans les assiettes, arroser de vinaigrette et parsemer de copeaux de parmesan."])
R(304, ["Cuire le boulgour 10 minutes dans deux fois son volume d'eau salée, puis l'égoutter et le laisser refroidir.",
        "Couper les abricots secs en petits dés.",
        "Faire dorer les amandes effilées 2 à 3 minutes dans une poêle sèche.",
        VINAIGRETTE,
        "Mélanger le boulgour et les abricots avec la vinaigrette, parsemer d'amandes et servir."], cuisson=12)
R(305, ["Retirer le trognon du chou rouge et l'émincer très finement.",
        "Couper la pomme en quartiers, retirer le cœur et la tailler en bâtonnets.",
        "Concasser grossièrement les noisettes.",
        VINAIGRETTE,
        "Mélanger le chou et la pomme avec la vinaigrette, laisser reposer 15 minutes, puis parsemer de noisettes."],
    ["Le repos attendrit le chou."])
R(306, ["Rincer les pois cassés et les cuire 30 minutes dans une grande casserole d'eau, sans saler. Ils doivent rester entiers.",
        "Les égoutter et les laisser refroidir.",
        "Couper la feta en dés et ciseler le persil.",
        VINAIGRETTE,
        "Mélanger les pois cassés avec la vinaigrette, ajouter la feta et le persil, et servir."], cuisson=30)
R(307, ["Couper le melon en deux, retirer les graines et la peau, puis le tailler en cubes ou en boules.",
        "Couper le jambon cru en lanières.",
        "Ciseler le basilic.",
        "Fouetter l'huile d'olive avec le vinaigre (ou le jus de citron) et du poivre. Saler peu : le jambon l'est déjà.",
        "Mélanger le melon, le jambon et le basilic avec la sauce et servir bien frais."])

# Tartines et bruschettas
GRILLER = "Faire griller les tranches de pain au four ou au grille-pain, puis les frotter avec la gousse d'ail coupée en deux."
R(308, [GRILLER,
        "Laver les figues et les couper en quartiers.",
        "Tartiner chaque tranche de ricotta.",
        "Disposer les figues dessus, arroser d'un filet d'huile d'olive et poivrer."],
    ["Un filet de miel sur les figues pour servir."])
R(309, ["Nettoyer les champignons et les émincer.",
        "Les faire sauter 6 à 8 minutes dans une poêle avec l'huile d'olive et les feuilles de thym, jusqu'à ce qu'ils soient dorés. Poivrer.",
        GRILLER,
        "Répartir les champignons chauds sur les tranches et servir aussitôt."])
R(310, ["Préchauffer le four à 200 °C.",
        "Badigeonner les tranches de pain d'huile d'olive et les frotter avec la gousse d'ail coupée en deux.",
        "Tartiner le chèvre frais sur le pain et parsemer de noix concassées.",
        "Enfourner 6 à 8 minutes, jusqu'à ce que le pain soit croustillant. Poivrer et servir chaud."],
    ["Un filet de miel au sortir du four."])
R(311, [GRILLER,
        "Retirer l'arête centrale des sardines et les écraser grossièrement à la fourchette avec un filet d'huile d'olive.",
        "Rincer le demi-citron confit, retirer la pulpe et tailler l'écorce en tout petits dés.",
        "Tartiner les sardines sur le pain, parsemer de citron confit et poivrer."])
R(312, ["Laver les courgettes et les couper en fines rondelles.",
        "Les faire dorer 5 minutes à la poêle dans l'huile d'olive. Poivrer.",
        GRILLER,
        "Répartir les courgettes sur les tranches, couvrir de copeaux de parmesan et servir."])
R(313, ["Préchauffer le gril du four. Poser les poivrons entiers sur la plaque et les griller 20 minutes en les retournant, jusqu'à ce que la peau noircisse.",
        "Les laisser tiédir dans un sac fermé, puis les peler, les épépiner et les couper en lanières. Les arroser d'huile d'olive.",
        GRILLER,
        "Disposer les poivrons sur le pain, ajouter la burrata déchirée en morceaux et poivrer."], cuisson=20)
R(314, [GRILLER,
        "Égoutter le maquereau, retirer la peau et les arêtes, puis l'émietter.",
        "Mélanger le maquereau avec le fromage frais et un filet d'huile d'olive. Poivrer.",
        "Tartiner le mélange sur le pain et servir frais."])
R(315, ["Mixer les olives vertes avec l'huile d'olive et la gousse d'ail jusqu'à obtenir une pâte. Poivrer.",
        "Laver les tomates et les couper en fines rondelles.",
        "Faire griller les tranches de pain.",
        "Tartiner la tapenade sur le pain et poser les rondelles de tomate dessus."])
R(316, ["Laver l'aubergine et la couper en dés.",
        "La faire dorer 8 à 10 minutes à la poêle dans l'huile d'olive avec l'ail haché, en remuant. Poivrer.",
        "Faire griller les tranches de pain.",
        "Répartir l'aubergine sur le pain et émietter la feta par-dessus."], cuisson=10)
R(317, ["Plonger les œufs dans l'eau bouillante et les cuire 6 minutes. Les rafraîchir dans l'eau froide, puis les écaler.",
        "Nettoyer les champignons, les émincer et les faire sauter 6 minutes dans l'huile d'olive avec l'ail haché. Poivrer.",
        "Faire griller les tranches de pain.",
        "Répartir les champignons sur le pain, couper les œufs en deux et les poser dessus. Saler et servir aussitôt."], cuisson=12)

# Soupes et veloutés
OIGNON = "Éplucher et émincer l'oignon, puis le faire revenir 3 minutes dans l'huile d'olive, dans une grande casserole."
R(318, ["Éplucher les panais et les pommes de terre, puis les couper en morceaux.",
        OIGNON,
        "Ajouter les légumes et le bouillon. Couvrir et cuire 25 minutes à petits bouillons.",
        "Faire griller les noisettes dans une poêle sèche, puis les concasser.",
        "Mixer finement, saler, poivrer et servir parsemé de noisettes."])
R(319, ["Éplucher la courge, retirer les graines et la couper en cubes. Éplucher et râper le gingembre.",
        OIGNON + " Ajouter le gingembre.",
        "Ajouter la courge et le bouillon. Couvrir et cuire 25 minutes.",
        "Mixer avec le lait de coco, saler, poivrer et servir."])
R(320, [OIGNON,
        "Ajouter les petits pois et le bouillon et cuire 15 minutes.",
        "Ajouter les feuilles de menthe et mixer finement avec la crème.",
        "Saler, poivrer et servir chaud ou froid."], cuisson=15)
R(321, ["Préchauffer le four à 200 °C. Couper les tomates en deux, les poser sur une plaque, arroser d'huile d'olive et rôtir 25 minutes.",
        OIGNON,
        "Ajouter les tomates rôties et le bouillon, et cuire 10 minutes.",
        "Mixer avec la moitié du basilic, saler et poivrer.",
        "Servir avec le reste du basilic ciselé."], cuisson=35)
R(322, ["Éplucher le céleri-rave et les pommes, puis les couper en morceaux.",
        OIGNON,
        "Ajouter le céleri, les pommes et le bouillon. Couvrir et cuire 25 minutes.",
        "Mixer finement avec la crème, saler, poivrer et servir."])
R(323, ["Rincer les pois cassés. Éplucher les carottes et les couper en rondelles.",
        OIGNON + " Ajouter le cumin et remuer 1 minute.",
        "Ajouter les pois cassés, les carottes et le bouillon. Couvrir et cuire 45 minutes, jusqu'à ce que les pois s'écrasent.",
        "Mixer, rallonger d'un peu d'eau si la soupe est trop épaisse, saler et poivrer."], cuisson=45)
R(324, ["Détailler le brocoli en bouquets. Éplucher la pomme de terre et la couper en dés.",
        OIGNON,
        "Ajouter le brocoli, la pomme de terre et le bouillon. Cuire 20 minutes.",
        "Ajouter le bleu en morceaux et mixer finement.",
        "Poivrer, goûter avant de saler (le bleu est salé) et servir."], cuisson=20)
R(325, ["Éplucher les patates douces et les couper en cubes.",
        OIGNON + " Ajouter le paprika fumé et remuer 1 minute.",
        "Ajouter les patates douces et le bouillon. Couvrir et cuire 25 minutes.",
        "Mixer finement, saler, poivrer et servir."])
R(326, ["Éplucher les asperges à l'économe, couper le bout dur et les tailler en tronçons. Garder quelques pointes pour le décor.",
        "Éplucher la pomme de terre et la couper en dés.",
        OIGNON,
        "Ajouter les asperges, la pomme de terre et le bouillon. Cuire 25 minutes.",
        "Mixer finement avec la crème, saler, poivrer et servir avec les pointes réservées."])
R(327, ["Laver les courgettes et les couper en rondelles, sans les éplucher.",
        OIGNON,
        "Ajouter les courgettes et le bouillon. Cuire 15 minutes.",
        "Mixer avec le fromage frais et le basilic.",
        "Saler, poivrer et servir chaud ou froid."], cuisson=15)

# Feuilletés, chaussons et tartelettes : four à 200 °C
DORER = "Battre l'œuf et en badigeonner la pâte."
R(328, ["Préchauffer le four à 200 °C.",
        "Faire tomber les épinards 3 minutes dans une poêle avec l'huile d'olive. Les égoutter en les pressant bien, puis les hacher.",
        "Mélanger les épinards avec la feta émiettée. Poivrer, saler peu.",
        "Découper la pâte en 8 carrés. Garnir la moitié de chaque carré et la replier en triangle. Souder les bords à la fourchette.",
        DORER + " Enfourner 20 à 25 minutes, jusqu'à ce que les feuilletés soient dorés."])
R(329, ["Préchauffer le four à 200 °C.",
        "Laver les poireaux, les émincer et les faire fondre 10 minutes dans l'huile d'olive. Poivrer.",
        "Couper le saumon fumé en lanières et le mélanger aux poireaux tièdes.",
        "Découper 8 disques dans la pâte. Garnir une moitié de chaque disque, refermer en chausson et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])
R(330, ["Préchauffer le four à 200 °C.",
        "Éplucher les oignons rouges, les émincer et les faire fondre 10 minutes à feu doux dans l'huile d'olive. Saler, poivrer.",
        "Découper la pâte en 6 disques et les poser sur une plaque couverte de papier cuisson. Piquer le centre à la fourchette en laissant un bord de 1 cm.",
        "Répartir les oignons, puis le chèvre en rondelles.",
        "Badigeonner les bords d'œuf battu et enfourner 20 minutes."])
R(331, ["Préchauffer le four à 200 °C.",
        "Nettoyer les champignons, les émincer et les faire sauter dans l'huile d'olive jusqu'à ce que leur eau soit évaporée. Saler, poivrer.",
        "Laisser tiédir et mélanger avec le comté.",
        "Découper la pâte en 8 carrés, garnir, replier en triangle et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])
R(332, ["Préchauffer le four à 200 °C.",
        "Découper la pâte en 6 disques et les poser sur une plaque couverte de papier cuisson. Piquer le centre en laissant un bord de 1 cm.",
        "Assaisonner la ricotta de sel et de poivre et l'étaler au centre des disques.",
        "Couper les tomates cerises en deux et les disposer sur la ricotta. Arroser d'un filet d'huile d'olive.",
        "Badigeonner les bords d'œuf battu et enfourner 20 minutes."])
R(333, ["Préchauffer le four à 200 °C.",
        "Épépiner le poivron, le couper en petits dés et le faire revenir 8 minutes dans l'huile d'olive.",
        "Mélanger le poivron avec le thon émietté. Saler, poivrer.",
        "Découper 8 disques dans la pâte, garnir une moitié, refermer en chausson et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])
R(334, ["Préchauffer le four à 200 °C.",
        "Éplucher le potiron, le couper en petits dés et le cuire 10 minutes à la poêle dans l'huile d'olive, à couvert. Poivrer.",
        "Laisser tiédir et mélanger avec le bleu émietté.",
        "Découper la pâte en 8 carrés, garnir, replier en triangle et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])
R(335, ["Préchauffer le four à 200 °C.",
        "Laver les courgettes et les couper en très fines rondelles.",
        "Découper la pâte en 6 disques et les poser sur une plaque couverte de papier cuisson. Piquer le centre en laissant un bord de 1 cm.",
        "Disposer les courgettes en rosace, arroser d'huile d'olive, saler et poivrer.",
        "Badigeonner les bords d'œuf battu et enfourner 20 minutes. Parsemer de menthe ciselée en sortant du four."])
R(336, ["Préchauffer le four à 200 °C.",
        "Laver les blettes, séparer les côtes des feuilles et les émincer. Cuire les côtes 5 minutes dans l'huile d'olive, puis ajouter les feuilles 3 minutes.",
        "Égoutter, presser et assaisonner. Ajouter les pignons grillés à sec.",
        "Découper 8 disques dans la pâte, garnir une moitié, refermer en chausson et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])
R(337, ["Préchauffer le four à 200 °C.",
        "Éplucher les poires, retirer le cœur et les couper en dés.",
        "Mélanger les poires avec le roquefort émietté et poivrer.",
        "Découper la pâte en 8 carrés, garnir, replier en triangle et souder les bords.",
        DORER + " Enfourner 20 à 25 minutes."])

# Rillettes, crèmes et dips à tartiner
SERVIR = "Servir frais avec du pain grillé ou des bâtonnets de légumes."
R(338, ["Retirer la peau et les arêtes du maquereau et l'émietter à la fourchette.",
        "Ajouter le fromage frais, la moutarde, l'huile d'olive et le jus de citron, et écraser pour obtenir une texture grossière.",
        "Saler peu, poivrer et réserver 30 minutes au frais.",
        SERVIR])
R(339, ["Râper le zeste du citron.",
        "Mixer les petits pois avec le yaourt grec, l'huile d'olive et le jus de citron.",
        "Ajouter le zeste, saler et poivrer.",
        SERVIR])
R(340, ["Rincer et égoutter les lentilles.",
        "Les mixer avec la purée de sésame, l'huile d'olive, le jus de citron et le paprika. Ajouter un peu d'eau si la crème est trop épaisse.",
        "Saler, poivrer et saupoudrer d'un peu de paprika.",
        SERVIR])
R(341, ["Éplucher les betteraves et les couper en morceaux.",
        "Les mixer avec le chèvre frais, l'huile d'olive et le jus de citron.",
        "Saler, poivrer et réserver au frais.",
        SERVIR])
R(342, ["Retirer la peau de la truite fumée et l'émietter.",
        "Ciseler l'aneth.",
        "Mélanger la truite avec le fromage blanc, l'huile d'olive, le jus de citron et l'aneth.",
        "Poivrer, saler peu et réserver 30 minutes au frais.",
        SERVIR])
R(343, ["Égoutter les cœurs d'artichauts.",
        "Râper le zeste du citron.",
        "Mixer les artichauts avec le parmesan, l'huile d'olive et le jus de citron.",
        "Ajouter le zeste, saler et poivrer.",
        SERVIR])
R(344, ["Rincer et égoutter les haricots rouges.",
        "Les mixer avec le cumin, l'huile d'olive et le jus du citron vert. Ajouter un peu d'eau si la crème est trop épaisse.",
        "Saler et poivrer.",
        SERVIR])
R(345, ["Préchauffer le four à 200 °C.",
        "Éplucher les carottes, les couper en tronçons, les arroser d'huile d'olive et les rôtir 30 minutes, jusqu'à ce qu'elles soient tendres.",
        "Laisser tiédir, puis mixer avec le tahini et le jus de citron.",
        "Saler, poivrer et servir frais avec du pain pita ou des bâtonnets de légumes."], cuisson=30)
R(346, ["Effilocher le poulet à la fourchette.",
        "Ciseler la ciboulette.",
        "Mélanger le poulet avec le fromage frais, l'huile d'olive, le jus de citron et la ciboulette.",
        "Saler, poivrer et réserver 30 minutes au frais.",
        SERVIR])
R(347, ["Préchauffer le four à 220 °C. Piquer les aubergines à la fourchette et les rôtir entières 40 minutes, jusqu'à ce qu'elles soient très tendres.",
        "Les ouvrir, récupérer la chair à la cuillère et la laisser égoutter 10 minutes.",
        "Écraser la chair avec le yaourt grec, l'huile d'olive et le jus de citron.",
        "Saler, poivrer et servir frais."], cuisson=40)
