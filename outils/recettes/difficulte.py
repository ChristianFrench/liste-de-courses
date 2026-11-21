"""Difficulté des recettes sur quatre niveaux : Facile, Moyen, Difficile, Avancé (20/11/2026, Aristide).
Première proposition faite d'après le plat (gestes, temps de cuisson longs, pâtisseries) ; tout ce qui n'est pas cité
ici est « Facile ». Pour corriger : changer le titre de liste, relancer outils/recettes/nouvelles_298_497.py."""
import re

MOYEN = """Accras de morue | Agneau sauce poulette | Beignets de fleurs de courgette | Bourride | Brandade de morue |
Chou farci | Couscous | Crème catalane | Crêpes | Escalopes milanaises | Flan aux œufs | Focaccia | Frites maison |
Lapin à la moutarde | Lasagnes à la bolognaise | Lotte sauce safranée | Ma daube | Moussaka à ma façon | Moussaka |
Mayonnaise | Pâte à pizza | Pâtes carbonara | Paella marinière | Paella | Petits farcis | Pissaladière | Porc au caramel |
Pot-au-feu | Ribs sauce barbecue | Rognons d'agneau sauce moutarde | Soles meunière | Spaghettis alle vongole |
Spanakopita | Steaks au poivre | Tarte aux poireaux | Tartiflette | Truffes au chocolat | Quiche lorraine |
Soupe à l'oignon gratinée | Blanquette de veau | Bœuf bourguignon | Gigot d'agneau rôti | Navarin d'agneau printanier |
Jambon braisé au madère | Cordons bleus maison | Coq au vin | Pintade aux choux |
Cuisses de canard confites aux pommes de terre | Magret de canard au miel | Dinde aux marrons | Poule au pot |
Tajine de poulet aux légumes | Tajine d'agneau aux pruneaux | Carbonade flamande | Rôti de bœuf | Parmentier de canard |
Veau marengo | Osso buco | Hamburgers maison | Lasagnes au saumon et aux épinards | Filets de poisson panés |
Pavés de saumon à l'unilatérale | Gratin de fruits de mer | Brochettes de Saint-Jacques et lard | Fish and chips |
Risotto aux champignons | Risotto aux asperges | Pad thaï | Gratin d'aubergines à la parmesane | Tortilla espagnole |
Galettes de sarrasin complètes | Potée auvergnate | Sauce gribiche | Sauce Mornay (ou béchamel) | Sauce au vin |
Sauce caramel au beurre salé | Mac and cheese | Gratin de macaronis | Tarte aux fraises | Tarte Tatin |
Tarte aux poires amandine | Tarte au chocolat | Crème brûlée | Crème caramel | Tiramisu | Mousse au citron |
Mousse au chocolat | Mousse au chocolat sans jaunes d'œufs | Poires belle-Hélène | Marbré chocolat-vanille | Madeleines |
Financiers | Sablés au beurre | Beignets aux pommes | Mousse aux fraises | Glace à la vanille sans sorbetière |
Coquilles Saint-Jacques poêlées | Daurades aux olives |
Galettes de lentilles corail aux herbes | Aubergines farcies au boulgour | Courgettes farcies au quinoa |
Poivrons farcis au riz et champignons | Cabillaud en croûte d’herbes | Haddock poché aux poireaux |
Saint-Jacques au beurre de citron | Saint-Jacques aux poireaux fondants | Rôti de porc aux pruneaux et sauge |
Porc braisé au chou rouge | Crème au praliné noisette | Crème au café et à la cardamome | Crème au chocolat blanc et citron |
Gâteau à la châtaigne et au chocolat | Poires rôties au chocolat noir | Pommes poêlées au caramel et cannelle"""

DIFFICILE = """Pommes dauphines | Sauce béarnaise | Sauce hollandaise | Beurre blanc | Pralines | Cassoulet |
Pâtes fraîches maison | Tarte au citron meringuée | Œufs à la neige | Île flottante | Galette des rois à la frangipane |
Bugnes"""

AVANCE = """Bouillabaisse | Charlotte aux poires | Foie gras mi-cuit"""

# Modèles de titres : mijotés et braisés longs, risottos (cuisson suivie louche par louche).
MODELES_MOYEN = [r'^(Bœuf|Agneau) (mijoté|braisé)', r'^Risotto', r'^Riz crémeux']


def _liste(t):
    return {x.strip() for x in t.split('|') if x.strip()}


_NIVEAU = {**{t: 'Moyen' for t in _liste(MOYEN)}, **{t: 'Difficile' for t in _liste(DIFFICILE)},
           **{t: 'Avancé' for t in _liste(AVANCE)}}


def difficulte(titre):
    if titre in _NIVEAU:
        return _NIVEAU[titre]
    if any(re.search(m, titre) for m in MODELES_MOYEN):
        return 'Moyen'
    return 'Facile'
