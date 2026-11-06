"""Mini site d'Emplettes (docs/, publié sur GitHub Pages) : quelques pages courtes, même menu fixe en haut,
même bas de page. Ce script écrit docs/<page>.html à partir des contenus ci-dessous.
Usage : python3 outils/site/generer.py
Charte : docs/site.css (palette Sauge, Atkinson Hyperlegible, bandeaux de l'application) ; comportements : docs/site.js.
"""
import json, os

APK = 'https://github.com/ChristianFrench/liste-de-courses/releases/download/derniere-version/Liste-de-courses.apk'
EXE = 'https://github.com/ChristianFrench/liste-de-courses/releases/download/derniere-version/Emplettes-Installation.exe'

PAGES = [  # (fichier, titre du menu)
    ('index.html', 'Accueil'),
    ('decouvrir.html', 'Découvrir'),
    ('telecharger.html', 'Télécharger'),
    ('aide.html', 'Aide'),
    ('essayer.html', 'Essayer'),
]


def entete(fichier, titre, description):
    liens = ''
    for f, t in PAGES:
        classe = ' class="essayer"' if f == 'essayer.html' else ''
        courant = ' aria-current="page"' if f == fichier else ''
        liens += f'<a href="{f}"{classe}{courant}>{t}</a>'
    return f'''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{titre}</title>
<meta name="description" content="{description}">
<link rel="icon" href="images/complet.png">
<link rel="stylesheet" href="site.css">
</head>
<body>
<!-- Page produite par outils/site/generer.py : modifier le script, pas ce fichier. -->
<header class="menu">
  <div class="large">
    <a class="marque" href="index.html"><img src="images/complet.png" alt="">Emplettes</a>
    <button class="burger" aria-label="Menu" aria-expanded="false">
      <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>
    </button>
    <nav id="navigation">{liens}</nav>
  </div>
</header>
'''


def titre_page(image, titre, sous_titre):
    return f'''<div class="titre-page"><div class="large"><img src="{image}" alt=""><div><h1>{titre}</h1><p>{sous_titre}</p></div></div></div>
'''


def bandeau(image, titre):
    return f'<div class="bandeau"><img src="{image}" alt=""><h2>{titre}</h2></div>'


BAS = f'''<footer>
  <div class="large">
    <div>
      <a class="marque" href="index.html"><img src="images/complet.png" alt="">Emplettes</a>
      <p style="margin:0;font-size:14.5px">La liste de courses du foyer, préparée à plusieurs.</p>
    </div>
    <div>
      <h4>L'application</h4>
      <ul>
        <li><a href="decouvrir.html">Découvrir</a></li>
        <li><a href="essayer.html">Essayer</a></li>
        <li><a href="documents/mode-emploi.html">Mode d'emploi</a></li>
        <li><a href="documents/depliant.html">Dépliant</a></li>
      </ul>
    </div>
    <div>
      <h4>Télécharger</h4>
      <ul>
        <li><a href="{APK}">Android (APK)</a></li>
        <li><a href="{EXE}">Windows</a></li>
        <li><a href="web/">Application web</a></li>
        <li><a href="telecharger.html">Installer pas à pas</a></li>
      </ul>
    </div>
    <div>
      <h4>Aide</h4>
      <ul>
        <li><a href="aide.html#questions">Questions fréquentes</a></li>
        <li><a href="aide.html#video">Vidéo</a><span class="a-venir">à venir</span></li>
        <li><a href="aide.html#donnees">Vos données</a></li>
        <li><a href="aide.html#contact">Contact</a><span class="a-venir">à venir</span></li>
      </ul>
    </div>
  </div>
  <div class="bas"><span id="basVersion">Emplettes</span> · Police Atkinson Hyperlegible et icônes Noto 3D, licence SIL OFL</div>
</footer>
<script src="site.js"></script>
</body>
</html>
'''

# ------------------------------------------------------------------ Accueil
ACCUEIL = f'''<div class="une">
  <div class="large">
    <div>
      <h1>Emplettes</h1>
      <p class="slogan">La liste de courses du foyer, préparée à plusieurs.</p>
      <p>Chacun ajoute ce qui manque, depuis son téléphone ou son ordinateur. Au magasin, la liste suit l'ordre des rayons, et l'on coche au fil des allées. Sans compte, sans publicité, même sans réseau.</p>
      <div class="boutons">
        <a class="bouton plein" href="essayer.html">Essayer maintenant</a>
        <a class="bouton" href="telecharger.html">Télécharger</a>
      </div>
    </div>
    <div class="scene">
      <img class="anim" id="animation" src="animation.webp" width="310" height="335" alt="La liste s'écrit, le caddie se remplit, les articles se cochent">
      <button class="rejouer" id="rejouer">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>
        Rejouer
      </button>
    </div>
  </div>
</div>
<main>
  <section>
    <div class="large">
      {bandeau('images/liste_crayon.png', "L'essentiel")}
      <div class="cartes">
        <div class="carte"><img src="icones/memo.png" alt=""><h3>Préparer à plusieurs</h3><p>Une liste commune, que chaque membre du foyer complète. On repart d'une liste type ou des courses précédentes.</p></div>
        <div class="carte"><img src="icones/shopping-cart.png" alt=""><h3>Dans l'ordre des rayons</h3><p>L'application apprend votre parcours dans chaque magasin : la liste se range dans l'ordre où vous passez.</p></div>
        <div class="carte"><img src="icones/busts-in-silhouette.png" alt=""><h3>Tout le foyer</h3><p>Un code de foyer suffit, sans compte ni mot de passe. Les données sont chiffrées avec ce code.</p></div>
        <div class="carte"><img src="icones/cloud.png" alt=""><h3>Même sans réseau</h3><p>Tout est enregistré sur l'appareil : au fond du magasin, l'application fonctionne normalement.</p></div>
      </div>
    </div>
  </section>
  <section>
    <div class="large">
      {bandeau('images/liste_chariot.png', 'Comment ça marche')}
      <div class="etapes">
        <div class="etape"><span class="no">1</span><div><b>Je paramètre</b><span>Une fois : le foyer, ses membres, ses magasins.</span></div></div>
        <div class="etape"><span class="no">2</span><div><b>Je prépare ma liste</b><span>Seul ou à plusieurs, en cherchant les articles.</span></div></div>
        <div class="etape"><span class="no">3</span><div><b>Je la valide</b><span>« Liste prête » : elle part dans les courses à faire.</span></div></div>
        <div class="etape"><span class="no">4</span><div><b>Je fais mes courses</b><span>Dans l'ordre des rayons, en cochant au fil des allées.</span></div></div>
      </div>
      <div class="boutons" style="margin-top:20px"><a class="bouton plein" href="decouvrir.html">Découvrir les écrans</a></div>
    </div>
  </section>
</main>
'''

# ------------------------------------------------------------------ Découvrir
VISITE = [  # (capture, titre, texte, points)
    ('01 Accueil', 'L\'accueil', 'Tout ce qui est en cours, d\'un coup d\'œil : les listes en préparation, celles à faire et les courses commencées.',
     ['« Comment ça marche » rappelle les étapes.', 'Touchez une liste pour ce que vous pouvez en faire.']),
    ('02 Preparer', 'Préparer', 'Les listes du foyer en préparation, et celles qui sont prêtes pour les courses.',
     ['« Nouvelle liste » en bas de l\'écran.', 'Glisser une liste à gauche la supprime, à droite la remet en préparation.']),
    ('03 Nouvelle-liste', 'Une nouvelle liste', 'Le magasin, le nom proposé d\'office, puis le point de départ.',
     ['Liste par secteur ou liste simple.', 'Depuis une liste type, une course passée ou un texte collé (mail, message).']),
    ('05 Remplir', 'Remplir la liste', 'On cherche l\'article en tapant trois lettres : il se range sous son secteur, dans l\'ordre du magasin.',
     ['− et + règlent la quantité.', 'Promotion, packaging et consigne s\'affichent sur la ligne.', '« Liste prête » la valide.']),
    ('07 Courses', 'Les courses', 'Les listes à faire, les courses en cours et les courses terminées, avec leur ticket.',
     ['Touchez une liste puis « Faire les courses ».', 'On choisit qui fait les courses et avec quel parcours.']),
    ('08 En-magasin', 'En magasin', 'La liste suit l\'ordre des allées. Un appui coche l\'article quand il est dans le chariot.',
     ['Deux appuis : manquant en rayon.', '« Pause » sans rien perdre, « Terminer » pour le bilan.', 'L\'ordre des coches apprend le parcours.']),
    ('09 Historique', 'L\'historique', 'Les courses passées, avec leur montant et leur ticket de caisse.',
     ['Une course peut redevenir une liste type.', 'Les plus anciennes passent aux archives.']),
    ('11 Magasins', 'Les magasins', 'Les magasins du foyer, et les parcours appris dans chacun.',
     ['Tous partagent le même catalogue.']),
    ('12 Catalogue', 'Le catalogue', 'Plus de 2 000 produits rangés par rayons et secteurs, le même dans tous les magasins.',
     ['On peut ajouter ses produits et ses marques.', 'Un petit + signale ce que le foyer a ajouté.', 'Il s\'améliore pour tous les foyers : sa version s\'affiche dans Gérer.']),
    ('10 Gerer', 'Gérer', 'Ce qui se règle une fois pour toutes : le foyer et ses membres, les magasins, le catalogue, l\'apparence, les sauvegardes.',
     ['Le foyer se partage avec un simple code.']),
]

VISITE_DETAIL = [  # visite détaillée, 20 étapes (04/11/2026, Aristide)
    ('01 Accueil', 'L\'accueil', 'Tout ce qui est en cours, d\'un coup d\'œil : les listes en préparation, celles à faire et les courses commencées.',
     ['« Comment ça marche » rappelle les étapes.', 'Touchez une liste pour ce que vous pouvez en faire.', 'Le nuage en haut à droite indique l\'état du partage avec le foyer.']),
    ('02 Preparer', 'L\'onglet Préparer', 'Les listes du foyer en préparation, puis celles qui sont prêtes pour les courses.',
     ['« Nouvelle liste » en bas de l\'écran.', 'Glisser une liste à gauche la supprime (« Annuler » la rétablit), à droite la remet en préparation.', 'Un appui long ouvre ses actions.']),
    ('03 Nouvelle-liste', 'Une nouvelle liste', 'Le magasin, la date et le nom proposé d\'office, puis le type de liste.',
     ['Par secteur : chaque article se range sous son secteur.', 'Simple : les articles à la suite, sans rayons.', 'Depuis une liste type, une course passée ou un texte collé.']),
    ('03 Liste-type', 'Les listes types', 'Vos listes habituelles, prêtes à reprendre : petit-déjeuner, ménage du mois…',
     ['Une liste type se crée depuis une liste ou une course passée.', 'On repart d\'elle et on la complète.']),
    ('05 Remplir', 'Remplir la liste', 'La liste se présente comme en magasin : les secteurs dans l\'ordre de votre parcours.',
     ['− et + règlent la quantité.', 'Promotion, mesure, lot et consigne s\'affichent sur la ligne.']),
    ('05 Recherche', 'Trois lettres suffisent', 'En tapant « cam », le catalogue propose Camembert, Camembert Président, Camomille…',
     ['Chaque proposition indique son rayon et son secteur.', 'Un produit absent du catalogue se crée sur place.']),
    ('06 Article', 'Le détail d\'un article', 'Un appui sur l\'article ouvre son volet : consigne pour celui qui fait les courses, marque, promotion visée, packaging.',
     ['« Pas trop mûres » s\'affichera en magasin.', '« Nom, rayon, secteur » corrige la fiche du produit.']),
    ('06 Marque', 'Les marques', 'Les marques connues du secteur sont proposées ; « Autre marque… » en ajoute une.',
     ['Choisir une marque crée le produit précis (Camembert Président).', 'Le catalogue des marques se complète au fil des listes.']),
    ('06 Liste-prete', 'Liste prête', 'La liste est validée : un commentaire pour celui qui part, et le mail au foyer si besoin.',
     ['La liste passe dans l\'onglet Courses.', 'Elle peut revenir en préparation à tout moment.']),
    ('07 Partir', 'Partir faire les courses', 'On indique qui fait les courses et dans quel magasin, avec quel parcours.',
     ['« Enregistrer le parcours » l\'apprend dès la première fois.', 'Chacun a son parcours, dans chaque magasin.']),
    ('08 En-magasin', 'En magasin', 'La liste suit l\'ordre des allées. Un appui coche l\'article quand il est dans le chariot.',
     ['Deux appuis : manquant en rayon.', 'L\'ordre des coches apprend le parcours : les rayons nouveaux s\'insèrent à leur place.', '« Pause » sans rien perdre.']),
    ('08 Terminer', 'Le bilan', 'Avant de terminer : les articles manquants et non cochés, le montant, le ticket de caisse.',
     ['Les articles non achetés peuvent partir dans une prochaine liste.', 'Un résumé peut être envoyé au foyer.']),
    ('09 Course-passee', 'Les courses passées', 'Chaque course garde ses articles, son montant et son ticket de caisse.',
     ['« Voir le ticket », « Consulter ».', 'Une course passée peut redevenir une liste ou une liste type.']),
    ('17 Collaboration', 'Le foyer', 'Plusieurs membres, plusieurs appareils, les mêmes listes. On rejoint le foyer avec son code de partage, sans compte ni mot de passe.',
     ['Les données sont chiffrées avec le code du foyer.', 'Les modifications faites sans réseau se partagent au retour.', 'Un message au foyer arrive en notification, même application fermée.', 'Les invitations et les résumés partent par mail.']),
    ('10 Gerer', 'L\'onglet Gérer', 'Ce qui se règle une fois pour toutes : le foyer et ses membres, les magasins, les catalogues, l\'apparence, les données.',
     ['Les réglages sont rangés par rubriques, comme les listes.']),
    ('11 Magasins', 'Les magasins', 'Les magasins du foyer, partagés par tous, avec les parcours appris dans chacun.',
     ['Les grandes enseignes sont proposées d\'office.', 'Le parcours d\'un magasin se recommence ou se corrige.']),
    ('12 Produits', 'Le catalogue des produits', 'Plus de 2 000 produits rangés en rayons et secteurs, le même catalogue dans tous les magasins.',
     ['On ajoute ses produits, on les renomme, on les déplace.', 'Un petit signe distingue ce que le foyer a ajouté ou modifié.', 'Chaque nouvelle version du catalogue s\'ajoute au foyer, sans rien retirer de ce qui lui sert.']),
    ('13 Marques', 'Le catalogue des marques', 'Les marques rangées par secteur : celles proposées dans le volet de l\'article.',
     ['On y ajoute ou retire des marques.', 'Le nombre de marques s\'affiche pour chaque secteur.']),
    ('15 Palettes', 'L\'apparence', '17 palettes de couleurs pour l\'application, une autre pour les promotions et mesures, et un aperçu immédiat.',
     ['Les icônes dans les titres des listes se retirent si on préfère.', 'Grands caractères et police conçue pour la lisibilité.']),
    ('16 Donnees', 'Vos données', 'Tout reste sur l\'appareil, avec des sauvegardes automatiques et une corbeille.',
     ['« Sauvegarder maintenant » donne un fichier à garder ailleurs.', 'Les anciennes courses passent aux archives.']),
]


DECOUVRIR = titre_page('icones/mobile-phone.png', 'Découvrir', 'Les écrans d\'Emplettes, un par un, à votre rythme.') + f'''<main>
  <section>
    <div class="large">
      <div class="visite">
        <div class="telephone"><div class="ecran" id="diapos"></div></div>
        <div class="explication">
          <div class="choix-visite" role="tablist">
            <button class="bouton" id="visiteCourte" role="tab">L'essentiel · 10 écrans</button>
            <button class="bouton" id="visiteDetail" role="tab">En détail · 20 écrans</button>
          </div>
          <div class="compteur" id="compteur"></div>
          <h2 id="titreEcran"></h2>
          <p id="texteEcran"></p>
          <ul id="pointsEcran"></ul>
          <div class="navigation-visite">
            <button class="bouton" id="precedent">‹ Précédent</button>
            <button class="bouton plein" id="suivant">Suivant ›</button>
            <label class="auto"><input type="checkbox" id="auto"> Défilement automatique</label>
          </div>
          <div class="points" id="points"></div>
          <div class="boutons" style="margin-top:22px"><a class="bouton" href="essayer.html">Essayer la démonstration</a></div>
        </div>
      </div>
    </div>
  </section>
</main>
<script>window.VISITE = {json.dumps([dict(f=f, t=t, x=x, p=p) for f, t, x, p in VISITE], ensure_ascii=False)};
window.VISITE_DETAIL = {json.dumps([dict(f=f, t=t, x=x, p=p) for f, t, x, p in VISITE_DETAIL], ensure_ascii=False)};</script>
'''

# ------------------------------------------------------------------ Télécharger
TELECHARGER = titre_page('icones/inbox-tray.png', 'Télécharger', 'Emplettes sur téléphone Android, sur PC Windows ou dans le navigateur.') + f'''<main>
  <section>
    <div class="large">
      <div class="telechargements">
        <div class="telechargement">
          <div class="tete"><img src="icones/mobile-phone.png" alt=""><h3>Android</h3></div>
          <p>Le fichier APK à installer sur le téléphone.</p>
          <ol class="note" style="margin:0;padding-left:18px"><li>Touchez « Télécharger l'APK ».</li><li>Ouvrez le fichier téléchargé.</li><li>Android demande d'autoriser l'installation depuis le navigateur : acceptez.</li><li>Au premier lancement, acceptez les notifications : les messages du foyer arriveront directement.</li></ol>
          <a class="bouton plein" href="{APK}">Télécharger l'APK</a>
        </div>
        <div class="telechargement">
          <div class="tete"><img src="icones/desktop-computer.png" alt=""><h3>Windows</h3></div>
          <p>Un programme d'installation, qui sert aussi aux mises à jour.</p>
          <ol class="note" style="margin:0;padding-left:18px"><li>Téléchargez et ouvrez « Emplettes-Installation.exe ».</li><li>Si Windows affiche « Windows a protégé votre ordinateur » : « Informations complémentaires » › « Exécuter quand même ».</li><li>Pour mettre à jour, refaites la même chose : vos listes et votre foyer sont conservés.</li></ol>
          <a class="bouton plein" href="{EXE}">Télécharger pour Windows</a>
        </div>
        <div class="telechargement">
          <div class="tete"><img src="icones/globe-showing-europe-africa.png" alt=""><h3>iPhone, iPad, navigateur</h3></div>
          <p>Rien à installer : l'application s'ouvre dans le navigateur, même sans réseau ensuite.</p>
          <ol class="note" style="margin:0;padding-left:18px"><li>Ouvrez l'application web.</li><li>iPhone et iPad : Partager › « Sur l'écran d'accueil ».</li><li>Sur Android, préférez l'APK : la version web garde ses propres données, à part de celles de l'application.</li></ol>
          <a class="bouton plein" href="web/">Ouvrir l'application web</a>
        </div>
      </div>
      <p class="note" id="version">Version en essai.</p>
    </div>
  </section>
</main>
'''

# ------------------------------------------------------------------ Aide
QUESTIONS = [
    ('Faut-il créer un compte ?', 'Non. On utilise Emplettes seul sur son appareil, ou en foyer : un code de partage suffit pour rejoindre les autres membres.'),
    ('Mes listes sont-elles envoyées quelque part ?', 'Seul, rien ne quitte l\'appareil. En foyer, les listes passent d\'un appareil à l\'autre par le serveur d\'Emplettes, chiffrées avec le code du foyer : le serveur ne peut pas les lire.'),
    ('L\'application marche-t-elle sans réseau ?', 'Oui. Tout est enregistré sur l\'appareil ; les changements partent vers le foyer dès que le réseau revient.'),
    ('Comment la liste suit-elle l\'ordre du magasin ?', 'Pendant les courses, l\'ordre dans lequel vous cochez les articles apprend votre parcours dans ce magasin. Les fois suivantes, la liste se range dans cet ordre.'),
    ('Comment être prévenu d\'un message du foyer ?', 'Sur Android, acceptez les notifications au premier lancement : les messages arrivent même application fermée. Dans le navigateur : Gérer › Foyer › Messages › « Recevoir les notifications sur cet appareil ».'),
    ('Le catalogue change-t-il ?', 'Oui : il s\'améliore pour tous les foyers. Chaque nouvelle version s\'ajoute à votre catalogue au lancement, sans retirer ce qui sert à vos listes. Sa version s\'affiche dans Gérer.'),
    ('Comment garder mes données en sécurité ?', 'Une copie est faite à chaque étape importante. « Sauvegarder maintenant » (Gérer › Paramètres › Données › Sauvegardes) donne un fichier à garder ailleurs.'),
]
AIDE = titre_page('icones/open-book.png', 'Aide', 'Mode d\'emploi, dépliant, questions fréquentes.') + f'''<main>
  <section id="documents">
    <div class="large">
      {bandeau('icones/open-book.png', 'Documents')}
      <div class="documents">
        <div class="telechargement">
          <div class="apercu" style="background-image:url('ecrans/05 Remplir.webp');background-position:top"></div>
          <h3>Mode d'emploi</h3>
          <p>Chaque écran, ses gestes et ses boutons, illustrés par l'application.</p>
          <div class="boutons"><a class="bouton plein" href="documents/mode-emploi.html">Consulter</a><a class="bouton" href="documents/Emplettes - Mode d'emploi.pdf" download>Télécharger (PDF)</a></div>
        </div>
        <div class="telechargement">
          <div class="apercu" style="background-image:url('documents/depliant-apercu.png')"></div>
          <h3>Dépliant</h3>
          <p>Trois volets à imprimer en A4 paysage, recto verso, pour présenter Emplettes.</p>
          <div class="boutons"><a class="bouton plein" href="documents/depliant.html">Consulter</a><a class="bouton" href="documents/Emplettes - Depliant.pdf" download>Télécharger (PDF)</a></div>
        </div>
      </div>
    </div>
  </section>
  <section id="video">
    <div class="large">
      {bandeau('icones/clapper-board.png', 'Vidéo de démonstration')}
      <div class="video"><div><img src="icones/play-button.png" alt=""><b>Bientôt disponible</b>Quelques minutes pour voir Emplettes en action.</div></div>
    </div>
  </section>
  <section id="questions">
    <div class="large">
      {bandeau('icones/information.png', 'Questions fréquentes')}
      <div class="questions">
        {''.join(f'<details><summary>{q}</summary><p>{r}</p></details>' for q, r in QUESTIONS)}
      </div>
    </div>
  </section>
  <section id="donnees">
    <div class="large">
      {bandeau('icones/key.png', 'Vos données')}
      <p class="intro">Les listes restent sur vos appareils. Dans un foyer, elles passent d'un appareil à l'autre chiffrées avec le code du foyer. Aucune publicité, aucun compte, aucune donnée revendue.</p>
    </div>
  </section>
  <section id="contact">
    <div class="large">
      {bandeau('icones/envelope.png', 'Contact')}
      <p class="intro">Bientôt : une adresse pour vos questions et vos idées.</p>
    </div>
  </section>
</main>
'''

# ------------------------------------------------------------------ Essayer
ESSAYER = titre_page('icones/check-mark-button.png', 'Essayer', 'La démonstration : un foyer d\'exemple déjà rempli, rien n\'est envoyé ni partagé.') + '''<main>
  <section>
    <div class="large">
      <p class="intro">La démonstration ouvre la dernière version d'Emplettes avec la famille Martin : quatre membres, trois magasins, deux mois de courses. Vous pouvez tout essayer.</p>
      <div class="grand-ecran-seulement">
        <p class="intro"><b>Où voulez-vous l'ouvrir ?</b></p>
        <div class="choix">
          <div class="telechargement">
            <div class="tete"><img src="icones/mobile-phone.png" alt=""><h3>Dans cette page</h3></div>
            <p>Dans un cadre à la taille d'un téléphone, sous cette question.</p>
            <button class="bouton plein" id="dansLaPage">Ouvrir ici</button>
          </div>
          <div class="telechargement">
            <div class="tete"><img src="icones/desktop-computer.png" alt=""><h3>Dans une fenêtre à part</h3></div>
            <p>Une petite fenêtre détachée, que l'on place où l'on veut à côté de cette page.</p>
            <button class="bouton plein" id="fenetre">Ouvrir une fenêtre</button>
          </div>
        </div>
        <div id="zoneCadre"><div class="telephone"><div class="ecran" id="cadre"></div></div></div>
      </div>
      <div class="petit-ecran-seulement">
        <div class="boutons">
          <a class="bouton plein" href="demo/">Ouvrir la démonstration</a>
          <a class="bouton" href="web/">Ouvrir l'application</a>
        </div>
      </div>
    </div>
  </section>
</main>
'''

CONTENUS = {
    'index.html': ('Emplettes', 'Emplettes : la liste de courses du foyer, préparée à plusieurs, faite dans l\'ordre des rayons.', ACCUEIL),
    'decouvrir.html': ('Découvrir · Emplettes', 'Les écrans d\'Emplettes, un par un.', DECOUVRIR),
    'telecharger.html': ('Télécharger · Emplettes', 'Emplettes pour Android, Windows et navigateur.', TELECHARGER),
    'aide.html': ('Aide · Emplettes', 'Mode d\'emploi, dépliant et questions fréquentes.', AIDE),
    'essayer.html': ('Essayer · Emplettes', 'La démonstration d\'Emplettes.', ESSAYER),
}

for fichier, (titre, description, corps) in CONTENUS.items():
    with open(os.path.join('docs', fichier), 'w', encoding='utf8') as f:
        f.write(entete(fichier, titre, description) + corps + BAS)
print(len(CONTENUS), 'pages')
