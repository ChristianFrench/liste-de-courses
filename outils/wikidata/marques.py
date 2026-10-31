"""Marques connues de Wikidata pour les secteurs non alimentaires du catalogue.

Pour chaque secteur, quelques notions (en français) : chacune est cherchée dans Wikidata, puis on demande les marques
et entreprises qui la produisent (P1056 « produit ») ou dont c'est le secteur d'activité (P452), avec leurs sous-classes.
Ne sont gardées que celles qui ont un article Wikipédia en français (repère de notoriété en France).
Écrit outils/wikidata/marques_wikidata.json, relu ensuite à la main. Lancé par le workflow « Wikidata - marques »
(l'environnement de Claude n'a pas accès au site)."""
import json, time, urllib.parse, urllib.request

UA = {"User-Agent": "ListeDeCourses/0.7 (catalogue de marques; github.com/ChristianFrench/liste-de-courses)"}
NOTIONS = {
    "Bricolage, auto et jardin/Outillage": ["outil électroportatif", "outil à main", "perceuse"],
    "Bricolage, auto et jardin/Électricité et éclairage": ["lampe électrique", "ampoule électrique", "pile électrique"],
    "Bricolage, auto et jardin/Peinture, colles et mastics": ["peinture", "colle", "mastic"],
    "Bricolage, auto et jardin/Plomberie": ["robinetterie", "plomberie"],
    "Bricolage, auto et jardin/Jardinage et extérieur": ["tondeuse à gazon", "engrais", "outil de jardinage"],
    "Bricolage, auto et jardin/Accessoires automobiles": ["huile moteur", "pneumatique", "essuie-glace", "batterie automobile"],
    "Bricolage, auto et jardin/Bricolage et quincaillerie": ["quincaillerie", "pile électrique"],
    "Cuisine et arts de la table/Arts de la table et cuisine": ["ustensile de cuisine", "batterie de cuisine", "poêle à frire", "coutellerie"],
    "Cuisine et arts de la table/Vaisselle": ["vaisselle", "verrerie", "porcelaine"],
    "Électroménager et décoration/Petit électroménager": ["petit électroménager", "cafetière", "aspirateur", "sèche-cheveux"],
    "Électroménager et décoration/Décoration": ["bougie", "décoration intérieure"],
    "Électroménager et décoration/Rangement": ["boîte de rangement", "mobilier de rangement"],
    "Entretien / Droguerie/Insecticides et antiparasites": ["insecticide", "répulsif"],
    "Entretien / Droguerie/Accessoires de ménage": ["éponge", "balai", "serpillière"],
    "Entretien / Droguerie/Salle de bain et cirage": ["cirage", "désodorisant"],
    "Entretien / Droguerie/Lessives et soin du linge": ["lessive", "adoucissant"],
    "Entretien / Droguerie/Nettoyants ménagers": ["produit d'entretien", "détergent"],
    "Loisirs/Jouets": ["jouet", "jeu de société"],
    "Loisirs/Bagagerie": ["bagage", "valise", "sac à dos"],
    "Loisirs/Papeterie et librairie": ["papeterie", "stylo", "fourniture scolaire"],
    "Textile/Chaussures": ["chaussure"],
    "Textile/Lingerie": ["lingerie", "sous-vêtement", "chaussette"],
    "Textile/Vêtements femme": ["prêt-à-porter", "vêtement"],
    "Textile/Vêtements homme": ["prêt-à-porter", "vêtement"],
    "Textile/Vêtements enfant et bébé": ["vêtement pour enfants"],
    "Textile/Linge de maison": ["linge de maison", "literie"],
    "Textile/Accessoires de mode": ["maroquinerie", "lunettes de soleil", "montre"],
    "Bébé/Puériculture": ["puériculture", "poussette", "biberon"],
    "Saisonnier/Plein air et camping": ["matériel de camping", "tente", "barbecue"],
    "Saisonnier/Chauffage et combustibles": ["radiateur", "chauffage", "allume-feu"],
    "Animaux/Chiens": ["nourriture pour chien", "aliment pour animaux"],
    "Animaux/Chats": ["nourriture pour chat", "litière pour chat"],
}


def get(url):
    for essai in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
                return json.load(r)
        except Exception as e:
            print("nouvel essai", e, flush=True)
            time.sleep(10 * (essai + 1))
    return None


def qid(libelle):
    d = get("https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "wbsearchentities", "search": libelle, "language": "fr", "uselang": "fr", "type": "item", "limit": 1, "format": "json"}))
    return (d or {}).get("search", [{}])[0].get("id") if d and d.get("search") else None


REQUETE = """SELECT DISTINCT ?m ?nom (COUNT(DISTINCT ?lien) AS ?liens) WHERE {
  VALUES ?notion { %s }
  ?classe wdt:P279* ?notion .
  { ?m wdt:P1056 ?classe } UNION { ?m wdt:P452 ?classe } UNION { ?classe wdt:P1716 ?m }
  ?m rdfs:label ?nom . FILTER(LANG(?nom) = "fr")
  ?article schema:about ?m ; schema:isPartOf <https://fr.wikipedia.org/> .
  ?lien schema:about ?m .
} GROUP BY ?m ?nom ORDER BY DESC(?liens) LIMIT 60"""

res, notions = {}, {}
for secteur, libelles in NOTIONS.items():
    ids = []
    for l in libelles:
        if l not in notions:
            notions[l] = qid(l)
            time.sleep(1)
        if notions[l]:
            ids.append(notions[l])
    if not ids:
        continue
    d = get("https://query.wikidata.org/sparql?" + urllib.parse.urlencode(
        {"query": REQUETE % " ".join("wd:" + i for i in ids), "format": "json"}))
    lignes = (d or {}).get("results", {}).get("bindings", [])
    res[secteur] = [[b["nom"]["value"], int(b["liens"]["value"])] for b in lignes]
    print(f"{secteur} : {len(res[secteur])} marques", flush=True)
    time.sleep(2)
json.dump({"_notions": notions, "secteurs": res}, open("outils/wikidata/marques_wikidata.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print(f"::notice title=Wikidata::{sum(len(v) for v in res.values())} marques pour {len(res)} secteurs")
