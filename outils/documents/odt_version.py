"""Fiche d'évolution et cahier de tests d'une version (ODT écrits à la main, styles repris du document précédent).
Usage : python3 outils/documents/odt_version.py
Écrit documents/Fiche d'evolution 1.0.odt et documents/Cahier de tests.odt (le précédent reste dans l'historique).
"""
import io, os, zipfile
from xml.sax.saxutils import escape

DOC = 'documents'
NS = ('xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
      'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
      'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
      'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"')
CELL = ('<style:style style:name="CelluleCadre" style:family="table-cell"><style:table-cell-properties fo:border="0.5pt solid #555555" fo:padding="0.08cm"/></style:style>'
        '<style:style style:name="CelluleCadreEntete" style:family="table-cell"><style:table-cell-properties fo:border="0.5pt solid #555555" fo:padding="0.08cm" fo:background-color="#E6E6E6"/></style:style>'
        '<text:list-style style:name="Puces"><text:list-level-style-bullet text:level="1" text:bullet-char="•"><style:list-level-properties text:space-before="0.4cm" text:min-label-width="0.45cm"/></text:list-level-style-bullet></text:list-style>')


def p(t, style='Corps'):
    return f'<text:p text:style-name="{style}">{t}</text:p>'


def h(t):
    return f'<text:h text:outline-level="1" text:style-name="T1">{escape(t)}</text:h>'


def puces(items):  # (gras, suite) ou texte
    out = '<text:list text:style-name="Puces">'
    for it in items:
        t = f'<text:span text:style-name="Gras">{escape(it[0])}</text:span> {escape(it[1])}' if isinstance(it, tuple) else escape(it)
        out += f'<text:list-item>{p(t)}</text:list-item>'
    return out + '</text:list>'


class Tables:
    def __init__(self):
        self.styles, self.n = '', 0

    def table(self, largeurs, entete, lignes):
        self.n += 1
        nom = f'Tab{self.n}'
        self.styles += f'<style:style style:name="{nom}" style:family="table"><style:table-properties style:width="{sum(largeurs):.1f}cm" table:align="left"/></style:style>'
        cols = ''
        for i, l in enumerate(largeurs):
            self.styles += f'<style:style style:name="{nom}C{i}" style:family="table-column"><style:table-column-properties style:column-width="{l}cm"/></style:style>'
            cols += f'<table:table-column table:style-name="{nom}C{i}"/>'

        def ligne(cells, ent=False):
            s = 'CelluleCadreEntete' if ent else 'CelluleCadre'
            return '<table:table-row>' + ''.join(
                f'<table:table-cell table:style-name="{s}">{p(escape(c), "CelluleEntete" if ent else "Cellule")}</table:table-cell>' for c in cells) + '</table:table-row>'
        return f'<table:table table:name="{nom}" table:style-name="{nom}">{cols}{ligne(entete, True)}{"".join(ligne(l) for l in lignes)}</table:table>'


def ecrire(modele, sortie, corps, tables, titre):
    with zipfile.ZipFile(os.path.join(DOC, modele)) as z:
        styles = z.read('styles.xml')
    contenu = (f'<?xml version="1.0" encoding="UTF-8"?><office:document-content {NS} office:version="1.2">'
               f'<office:automatic-styles>{CELL}{tables.styles}</office:automatic-styles><office:body><office:text>{corps}</office:text></office:body></office:document-content>')
    meta = (f'<?xml version="1.0" encoding="UTF-8"?><office:document-meta {NS} office:version="1.2"><office:meta><meta:generator>outils/documents/odt_version.py</meta:generator>'
            f'<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">{escape(titre)}</dc:title></office:meta></office:document-meta>')
    manifest = (f'<?xml version="1.0" encoding="UTF-8"?><manifest:manifest {NS}><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>'
                '<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
                '<manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/></manifest:manifest>')
    tampon = io.BytesIO()
    with zipfile.ZipFile(tampon, 'w') as z:
        z.writestr(zipfile.ZipInfo('mimetype'), 'application/vnd.oasis.opendocument.text', compress_type=zipfile.ZIP_STORED)
        z.writestr('META-INF/manifest.xml', manifest, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr('styles.xml', styles, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr('content.xml', contenu, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr('meta.xml', meta, compress_type=zipfile.ZIP_DEFLATED)
    open(os.path.join(DOC, sortie), 'wb').write(tampon.getvalue())
    print(sortie)


DATE = '28 novembre 2026'

# ------------------------------------------------------------------ Fiche d'évolution 1.0
CONTENU = [
    ('Nom et identité :', 'l\'application s\'appelle Emplettes, avec sa nouvelle icône (chariot et liste cochée sur fond vert), la signature dans l\'en-tête et une photo de fond sous la barre d\'état sur tous les écrans.'),
    ('Onglets :', 'Accueil, Recettes, Préparer, Courses, et Gérer (roue dentée). L\'accueil montre « Comment ça marche » en quatre étapes, de la recette aux courses, les listes en cours et les recettes choisies. La barre des onglets s\'efface en descendant une liste et revient en remontant.'),
    ('Recettes :', '596 recettes illustrées (celles du maître d\'ouvrage, reformulées, et celles écrites pour Emplettes), classées en 9 types et sous-types, avec temps, difficulté, régime, saison, coût, cuisson, occasion et origine ; recherche par titre ou ingrédient et filtres à icône ; fiche avec onglets Ingrédients et Recette, − et + sur le nombre de personnes. « Noter les ingrédients » : la recette va dans les « Recettes choisies » du foyer ; à la préparation, un appui ajoute ses ingrédients dans leurs secteurs avec « pour : la recette » ; ceux à choisir ou à placer restent sous la recette.'),
    ('Préparation :', 'une seule vue condensée ; recherche dès trois lettres (marques comprises) ; « Autres produits » du secteur, les achats habituels d\'abord ; détail de l\'article dans un volet (marque, promotion, mesure, lot, consigne) ; volet Promo à la validation d\'un article trouvé ; nombre à acheter dans le volet Promo ; double appui sur une liste ; liste rectificative ; liste depuis un mail.'),
    ('Courses :', 'la case tourne par appuis rapprochés : cochée, manquant, pas besoin, vide (délai 1,5 s) ; appui long pour le détail ; liste figée pendant les courses ; parcours appris et lissé ; groupe « Terminées » ; bilan avec manquants, pas besoin et non cochés ; résumé au foyer envoyé directement par mail ; fin des courses immédiate.'),
    ('Catalogue commun :', 'un seul catalogue ouvert à tous les foyers, avec ses domaines, rayons et secteurs, environ 2 575 produits et 2 480 marques ; publié signé par la console, numéroté (complément 3.1, majeure 4.0) ; chaque foyer reçoit les nouveautés au lancement (fenêtre de totaux, sans longue liste). Marques à plat, déclinaisons du produit générique, enrichies par l\'usage. Icônes du maître d\'ouvrage pour les domaines, rayons et secteurs.'),
    ('Foyer et partage :', 'serveur Emplettes (OVH, emplettes.eu) pour le partage, les messages et les mails ; état du foyer gardé sur le serveur ; chiffrement par foyer ; messages du foyer en notification Android, même application fermée.'),
    ('Aide :', 'sur chaque écran, un point d\'interrogation : la fonction de l\'écran, « À l\'écran » et « Vous pouvez » en quelques points à icône ; les gestes derrière une icône en haut à droite.'),
    ('Apparence :', 'icônes Noto 3D en couleur et icônes du maître d\'ouvrage, 17 palettes, zones de saisie homogènes (libellé sur le cadre), dates au calendrier, barre d\'état Android toujours visible.'),
    ('Données :', 'sauvegardes automatiques et « Sauvegarder maintenant », corbeille, archives ; index de la base (lenteurs corrigées).'),
    ('Mises à jour :', 'applications servies par le serveur OVH (dépôt d\'essai et dépôt officiel) ; mise à jour proposée dans l\'application (Android : autorisation demandée avant le téléchargement) ; installateur Windows.'),
    ('Démonstration :', 'version web de démonstration (famille Martin) et APK « Emplettes démo » séparée, sans toucher aux vraies données.'),
    ('Console Windows (Emplettes · catalogues) :', 'éditeur des trois catalogues (produits, marques, recettes) aux normes Windows, historique et retour à une étape, publication signée ; installateur à part, protégé.'),
    ('Site emplettes.eu :', 'pages Accueil, Découvrir, Télécharger, Aide, Essayer ; chiffres lus dans le catalogue publié ; vidéo de 89 s ; installation sur iPhone et iPad par Safari ; mode d\'emploi et dépliant en PDF.'),
]
OUVERTS = [
    'Internationalisation : prévue après la 1.0 (textes de l\'interface, puis l\'anglais, puis le catalogue).',
    'Notifications automatiques (étude d\'ensemble des actes déclencheurs) : reportées par le maître d\'ouvrage.',
    'Récupération automatique des promotions des magasins : abandonnée (prospectus en images).',
    'Le site annonce la version 1.0 ; la page Télécharger renvoie l\'iPhone et l\'iPad vers l\'application web complète, à la demande du maître d\'ouvrage (la règle « démonstration seule » du 11 novembre ne vaut plus pour ce cas).',
]
t = Tables()
corps = p('Fiche d\'évolution — version 1.0', 'Titre') + p(f'Emplettes — la liste de courses du foyer, de la recette au chariot — {DATE}', 'SousTitre')
corps += t.table([4, 13], ['Rubrique', 'Contenu'], [
    ['Version', '1.0.0'],
    ['Date', DATE],
    ['Origine', 'Retours et demandes du maître d\'ouvrage du 27 octobre au 28 novembre 2026, traités au fil de l\'eau (environ 170 livraisons), puis « Générer toutes les applications en 1.0 »'],
    ['Plateformes', 'Android (APK et APK de démonstration), Windows (installateur), web (navigateur, iPhone, iPad, PC), console Windows du catalogue.'],
    ['Version précédente', '0.7.0 — 27 octobre 2026'],
])
corps += p('') + h('1. Contenu livré') + puces(CONTENU)
corps += h('2. Contradictions signalées') + p(escape('Aucune contradiction en suspens. Les choix faits au fil des retours ont été validés par le maître d\'ouvrage.'))
corps += h('3. Écarts et points ouverts') + puces(OUVERTS)
ecrire('Fiche d\'evolution 0.7.odt', 'Fiche d\'evolution 1.0.odt', corps, t, 'Fiche d\'évolution 1.0')

# ------------------------------------------------------------------ Cahier de tests 1.0
ESSAIS = [  # (procédure, résultat attendu, auto)
    ('Premier lancement sur un appareil neuf : choisir « Seul ».', 'Catalogue commun, enseignes et listes d\'exemple ; Accueil avec « Comment ça marche ».', 'Oui'),
    ('Premier lancement : « En foyer », créer un foyer ; sur un second appareil, le rejoindre avec son code.', 'Les deux appareils voient les mêmes magasins, listes et recettes choisies ; le nuage passe au vert.', '—'),
    ('Couper le réseau, modifier une liste, rétablir le réseau.', 'La modification passe à l\'autre appareil, sans perte.', '—'),
    ('Onglet Recettes : chercher « quiche », filtrer par saison puis par temps.', 'La liste se réduit ; « Effacer les filtres » la rétablit.', 'Oui'),
    ('Ouvrir une recette, changer le nombre de personnes, passer à l\'onglet Recette.', 'Les quantités suivent ; les étapes sont numérotées.', 'Oui'),
    ('Sur la fiche : cocher des ingrédients, « Noter les ingrédients ».', 'Message « notée » ; la recette apparaît dans les Recettes choisies de l\'accueil et de la préparation.', 'Oui'),
    ('En préparation, toucher la recette choisie, puis « Ajouter à la liste ».', 'Les ingrédients vont dans leurs secteurs avec « pour : la recette » ; ceux à choisir ou à placer restent sous la recette.', 'Partiel'),
    ('Préparer › Nouvelle liste ; taper trois lettres, ajouter un article.', 'L\'article se range sous son secteur, dans l\'ordre du parcours ; volet Promo à la validation.', 'Oui'),
    ('Toucher une ligne : marque, promotion, mesure, lot, consigne.', 'Les choix s\'affichent sur la ligne.', 'Oui'),
    ('« Autres produits » sur un bandeau de secteur.', 'Les achats habituels d\'abord ; cocher les ajoute.', 'Oui'),
    ('Nouvelle liste depuis une liste type, une course passée, un mail collé.', 'La liste est créée et reste modifiable.', 'Oui'),
    ('« Liste prête », puis Courses › « Faire les courses ».', 'Choix du membre, du magasin et du parcours ; la liste suit l\'ordre des allées.', 'Oui'),
    ('En magasin : toucher une case, puis par appuis rapprochés.', 'Cochée, manquant (croix rouge), pas besoin (tiret gris), vide ; après 1,5 s le secteur se range.', 'Oui'),
    ('Pendant les courses, essayer de modifier la liste depuis un autre appareil.', 'La liste en cours ne change pas ; les changements vont dans la préparation du jour.', 'Oui'),
    ('« Terminer » : bilan, montant, résumé au foyer.', 'Manquants, pas besoin et non cochés listés ; le mail part ; la course passe dans Terminées.', 'Partiel'),
    ('Refaire une course dans le même magasin.', 'Le parcours appris range la liste dans l\'ordre des coches précédentes.', 'Oui'),
    ('Toucher « ? » sur plusieurs écrans, puis l\'icône des gestes.', 'L\'aide décrit l\'écran en points à icône ; les gestes s\'affichent.', 'Oui'),
    ('Descendre puis remonter une longue liste.', 'La barre des onglets s\'efface puis revient.', 'Oui'),
    ('Gérer › Foyer › Messages : envoyer un message.', 'Notification sur l\'autre appareil Android, même application fermée.', '—'),
    ('Console : publier une nouvelle version du catalogue.', 'Les appareils affichent la fenêtre des nouveautés (totaux) au lancement.', 'Partiel'),
    ('Gérer › Catalogue des produits et des marques : ajouter un produit, une marque.', 'Trouvés dans la recherche, marqués comme ajoutés par le foyer.', 'Oui'),
    ('Gérer › Apparence : changer de palette.', 'Toute l\'application change de couleurs.', 'Oui'),
    ('Gérer › Données : « Sauvegarder maintenant », puis restaurer ; corbeille et archives.', 'Fichier de sauvegarde obtenu ; éléments restaurés à leur place.', 'Partiel'),
    ('Mise à jour proposée dans l\'application (Android, Windows).', 'Téléchargement après autorisation, installation, données conservées.', '—'),
    ('iPhone ou iPad : Safari › emplettes.eu/web › Partager › « Sur l\'écran d\'accueil ».', 'L\'icône Emplettes s\'ouvre comme une application, même sans réseau.', '—'),
    ('Site emplettes.eu : Accueil (chiffres, vidéo), Découvrir sur téléphone, Essayer.', 'Chiffres à jour ; écran lisible avec son explication ; la démonstration s\'ouvre.', '—'),
]
t = Tables()
corps = p('Cahier de tests — Emplettes', 'Titre') + p(f'Version testée : 1.0 — {DATE}', 'SousTitre')
corps += h('1. Mode d\'emploi')
corps += p(escape('Ce cahier remplace celui de la version 0.7 (conservé dans l\'historique du dépôt). Il reprend les fonctions décrites dans « Fiche d\'evolution 1.0 ».'))
corps += p(escape('Colonne « Auto » : « Oui » = rejoué par GitHub à chaque compilation ; « Partiel » = en partie ; « — » = manuel. Colonnes Windows, Android et Web : « OK » ou « KO ». Les essais de foyer demandent deux appareils.'))
corps += h('2. Essais') + t.table([1.0, 5.4, 5.0, 1.2, 1.5, 1.5, 1.4], ['N°', 'Procédure', 'Résultat attendu', 'Auto', 'Windows', 'Android', 'Web'],
                                  [[f'T{i}', a, b, c, '', '', ''] for i, (a, b, c) in enumerate(ESSAIS, 1)])
corps += h('3. Observations') + t.table([1.4, 2.4, 8.6, 4.6], ['N°', 'Plateforme', 'Constat', 'Suite donnée'], [['', '', '', ''] for _ in range(8)])
ecrire('Cahier de tests.odt', 'Cahier de tests.odt', corps, t, 'Cahier de tests 1.0')
