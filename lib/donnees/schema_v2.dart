// Généré à partir de documents/schema-v2.sql : ne pas modifier ici.
// ignore_for_file: lines_longer_than_80_chars

const schemaV2 = r'''
-- =====================================================================
--  Application liste de courses — Schéma de la base locale SQLite
--  Version 2 — 10/10/2026
--  Source : version 1 du fil « Modèle de données » (documents « Modèle de
--  données » et « Cahier des charges »), mise en accord avec la maquette 0.6
--  (spécification IHM v0.2). Les modifications sont marquées « [v2] ».
--
--  À l'attention du fil de génération :
--  - Ce script s'exécute tel quel (sqlite3 base.db < "Schema base SQLite.sql").
--  - Chaque table est commentée : rôle, règles de gestion, origine.
--  - Identifiants : TEXT contenant un UUID, générés par l'application.
--    Ils restent identiques sur tous les appareils du foyer, ce qui
--    permet la synchronisation sans renumérotation. [v2] La synchronisation
--    (MQTT, prévue après la bêta) remplace Firebase.
--  - Dates : TEXT au format ISO 8601 ('2026-10-10T09:05:00Z').
--  - Booléens : INTEGER 0/1.
--  - Colonnes de synchronisation présentes partout :
--      cree_le, modifie_le  -> horodatage ; la plus récente gagne en cas de conflit
--      synchro              -> 0 = modifié localement, à envoyer ; 1 = à jour
--      supprime             -> [v2] sur les lignes de liste et les parcours,
--                              seules données effaçables : la suppression est
--                              gardée pour être transmise aux autres appareils
--  - Le catalogue (magasins, produits…) n'est JAMAIS supprimé physiquement :
--    on passe archive = 1. Des déclencheurs l'imposent.
-- =====================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- =====================================================================
--  PARTIE 1 — CATALOGUE COMMUN (partagé entre tous les foyers)
--  Aucune donnée personnelle.
-- =====================================================================

-- Point de vente.
CREATE TABLE magasin (
    id          TEXT PRIMARY KEY,
    nom         TEXT NOT NULL,                 -- « Leclerc Saint-Médard »
    enseigne    TEXT,                          -- « Leclerc »
    adresse     TEXT,
    ville       TEXT,
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,                          -- id du membre créateur (traçabilité)
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Rayon : regroupe des secteurs par catégorie (Épicerie, Frais…).
-- Sert au classement et à l'affichage, PAS à l'ordre de passage.
CREATE TABLE rayon (
    id          TEXT PRIMARY KEY,
    magasin_id  TEXT NOT NULL REFERENCES magasin(id),
    nom         TEXT NOT NULL,
    ordre_affichage INTEGER NOT NULL DEFAULT 0, -- ordre dans les listes déroulantes
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1)),
    UNIQUE (magasin_id, nom)
);

-- Secteur : endroit physique du magasin, à l'intérieur d'un rayon
-- (Épicerie -> « Conserves et pâtes », « Liquides »).
-- Deux secteurs d'un même rayon peuvent être éloignés : l'ordre de passage
-- est porté par le PARCOURS, pas par le secteur.
CREATE TABLE secteur (
    id          TEXT PRIMARY KEY,
    rayon_id    TEXT NOT NULL REFERENCES rayon(id),
    nom         TEXT NOT NULL,
    ordre_affichage INTEGER NOT NULL DEFAULT 0,
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1)),
    UNIQUE (rayon_id, nom)
);

-- Marque. Une marque peut concerner plusieurs produits ;
-- on peut lister tous les produits d'une marque (via produit_marque).
CREATE TABLE marque (
    id          TEXT PRIMARY KEY,
    nom         TEXT NOT NULL UNIQUE COLLATE NOCASE,
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Packaging : conditionnement (« bouteille 1 L », « pack de 6 »).
CREATE TABLE packaging (
    id          TEXT PRIMARY KEY,
    libelle     TEXT NOT NULL,
    quantite    REAL,                          -- 1, 6, 500…
    unite       TEXT,                          -- 'L', 'g', 'pièce'…
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Produit : article générique, commun à tous les magasins (« Lait demi-écrémé »).
-- Son emplacement change d'un magasin à l'autre (table emplacement).
CREATE TABLE produit (
    id              TEXT PRIMARY KEY,
    nom             TEXT NOT NULL,
    image           BLOB,                      -- vignette compressée (~100 Ko max)
    code_barres     TEXT,                      -- EAN ; lien avec l'extrait Open Food Facts
    nb_utilisations INTEGER NOT NULL DEFAULT 0, -- incrémenté à chaque entrée dans une liste ;
                                                -- ne diminue jamais (déclencheurs)
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);
CREATE INDEX idx_produit_nom ON produit(nom COLLATE NOCASE);
CREATE INDEX idx_produit_code_barres ON produit(code_barres);

-- Marques possibles d'un produit (plusieurs à plusieurs).
CREATE TABLE produit_marque (
    produit_id  TEXT NOT NULL REFERENCES produit(id),
    marque_id   TEXT NOT NULL REFERENCES marque(id),
    PRIMARY KEY (produit_id, marque_id)
);
CREATE INDEX idx_produit_marque_marque ON produit_marque(marque_id);

-- Packagings possibles d'un produit (plusieurs à plusieurs).
CREATE TABLE produit_packaging (
    produit_id   TEXT NOT NULL REFERENCES produit(id),
    packaging_id TEXT NOT NULL REFERENCES packaging(id),
    PRIMARY KEY (produit_id, packaging_id)
);

-- Emplacement : dans quel secteur trouver un produit, dans un magasin donné.
-- Un produit a au plus un emplacement par magasin.
CREATE TABLE emplacement (
    produit_id  TEXT NOT NULL REFERENCES produit(id),
    magasin_id  TEXT NOT NULL REFERENCES magasin(id),
    secteur_id  TEXT NOT NULL REFERENCES secteur(id),
    cree_par    TEXT,
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1)),
    PRIMARY KEY (produit_id, magasin_id)
);
CREATE INDEX idx_emplacement_secteur ON emplacement(secteur_id);

-- Types de promotion. Les libellés sont modifiables dans le menu Paramètres.
-- La promotion est un simple choix manuel sur la ligne de liste.
CREATE TABLE type_promotion (
    id          TEXT PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,          -- code court affiché sur l'icône (« LOT », « 2=€ »)
    libelle     TEXT NOT NULL,                 -- modifiable par l'utilisateur
    exemple     TEXT,                          -- [v2] « 3 achetés = 1 offert ; 2e à −50 % »
    parametres  TEXT NOT NULL DEFAULT '[]',    -- [v2] JSON : noms des paramètres attendus,
                                               --      « a|b » = l'un ou l'autre
    ordre_affichage INTEGER NOT NULL DEFAULT 0,
    archive     INTEGER NOT NULL DEFAULT 0 CHECK (archive IN (0, 1)),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- [v2] Identifiants, codes et paramètres repris de la maquette.
INSERT INTO type_promotion (id, code, libelle, exemple, parametres, ordre_affichage) VALUES
    ('lot',              'LOT', 'Lot',               '3 achetés = 1 offert ; 2e à −50 %', '["quantiteAchetee","quantiteOfferte|remiseDernier"]', 1),
    ('prixGlobal',       '2=€', 'Prix global',       '2 pour 5 €',                        '["quantiteMinimale","prixGlobal"]',                  2),
    ('remise',           '−%',  'Remise immédiate',  '−30 % ; −1 €',                      '["pourcentage|montant"]',                            3),
    ('packagingSpecial', 'PK',  'Packaging spécial', '+20 % gratuit ; format promo',      '["packagingId","gain"]',                             4),
    ('fidelite',         'FID', 'Fidélité',          '30 % crédités sur la carte',        '["pourcentage|montant"]',                            5),
    ('autre',            '?',   'Autre',             'Toute nouvelle forme d''offre',     '["libelle"]',                                        6);

-- =====================================================================
--  PARTIE 2 — DONNÉES PRIVÉES DU FOYER
--  Visibles uniquement des membres du foyer (filtrage par foyer_id).
-- =====================================================================

-- Foyer : groupe de personnes qui partagent les listes.
CREATE TABLE foyer (
    id          TEXT PRIMARY KEY,
    nom         TEXT NOT NULL,
    createur_id TEXT,                          -- id du membre qui l'a créé
    preliste_presences_min INTEGER NOT NULL DEFAULT 3, -- [v2] règle de la préliste : un produit y entre
    preliste_sur           INTEGER NOT NULL DEFAULT 6, --      s'il figure N fois sur les M dernières courses
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- [v2] Invitation : code à saisir sur un autre appareil pour rejoindre le foyer.
CREATE TABLE invitation (
    code        TEXT PRIMARY KEY,              -- 6 caractères sans ambiguïté (pas de O/0, I/1)
    foyer_id    TEXT NOT NULL REFERENCES foyer(id),
    expire_le   TEXT NOT NULL,
    cree_par    TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Membre : personne du foyer. [v2] Plus de compte Google : on rejoint le
-- foyer par le code d'invitation. Le membre qui utilise cet appareil est
-- désigné par le paramètre local 'membre_courant'.
CREATE TABLE membre (
    id          TEXT PRIMARY KEY,              -- UUID créé sur l'appareil du membre
    foyer_id    TEXT NOT NULL REFERENCES foyer(id),
    nom_affiche TEXT NOT NULL,
    email       TEXT,
    role        TEXT NOT NULL DEFAULT 'membre' CHECK (role IN ('administrateur', 'membre')),
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Parcours : ordre de passage dans les secteurs, choisi par UN membre
-- pour UN magasin. Chaque membre peut en avoir plusieurs, dont un par défaut.
CREATE TABLE parcours (
    id          TEXT PRIMARY KEY,
    foyer_id    TEXT NOT NULL REFERENCES foyer(id),
    membre_id   TEXT NOT NULL REFERENCES membre(id),
    magasin_id  TEXT NOT NULL REFERENCES magasin(id),
    nom         TEXT NOT NULL,                 -- « Gros produits d'abord »
    par_defaut  INTEGER NOT NULL DEFAULT 0 CHECK (par_defaut IN (0, 1)),
    supprime    INTEGER NOT NULL DEFAULT 0 CHECK (supprime IN (0, 1)), -- [v2]
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);
-- Un seul parcours par défaut par membre et par magasin.
CREATE UNIQUE INDEX idx_parcours_defaut ON parcours(membre_id, magasin_id) WHERE par_defaut = 1 AND supprime = 0;

-- Étapes d'un parcours : un secteur et sa position.
-- Un parcours peut passer d'un rayon à l'autre et y revenir.
CREATE TABLE parcours_etape (
    parcours_id TEXT NOT NULL REFERENCES parcours(id) ON DELETE CASCADE,
    secteur_id  TEXT NOT NULL REFERENCES secteur(id),
    ordre       INTEGER NOT NULL,              -- 1, 2, 3…
    PRIMARY KEY (parcours_id, secteur_id),
    UNIQUE (parcours_id, ordre)
);

-- Liste : une session de courses dans un magasin.
-- statut : 'construction' -> 'prete' -> 'en_cours' -> 'terminee'  (ou 'abandonnee')
-- [v2] 'prete' (maquette) : la liste est finie, en attente des courses.
-- [v2] L'historique des courses = les listes au statut 'terminee'
--      (date_courses, fait_par_id ; nombre d'articles = lignes cochées).
-- Reprise : si l'application est quittée pendant la construction ou les
-- courses, rien n'est perdu ; au relancement, l'application propose de
-- reprendre la liste au statut 'construction' ou 'en_cours', à l'écran
-- et au secteur mémorisés (ecran_reprise, secteur_reprise_id).
CREATE TABLE liste (
    id              TEXT PRIMARY KEY,
    foyer_id        TEXT NOT NULL REFERENCES foyer(id),
    magasin_id      TEXT NOT NULL REFERENCES magasin(id),
    statut          TEXT NOT NULL DEFAULT 'construction'
                    CHECK (statut IN ('construction', 'prete', 'en_cours', 'terminee', 'abandonnee')),
    parcours_id     TEXT REFERENCES parcours(id), -- parcours utilisé pendant les courses
    fait_par_id     TEXT REFERENCES membre(id),   -- qui fait les courses
    libelle         TEXT,                         -- facultatif
    date_courses    TEXT,                         -- renseignée au passage à 'terminee'
    nb_articles     INTEGER,                      -- [v2.1] articles achetés, pour l'historique
    ecran_reprise   TEXT,                         -- ex. 'construction', 'liste_complete', 'secteur', 'non_place'
    rayon_reprise_id   TEXT REFERENCES rayon(id),   -- [v2] position en construction
    secteur_reprise_id TEXT REFERENCES secteur(id), -- position en construction ou étape des courses
    interrompue_le  TEXT,                         -- [v2] posée par « Pause », effacée à la reprise
    cree_par        TEXT REFERENCES membre(id),
    modifie_par     TEXT REFERENCES membre(id),   -- [v2] « modifiée par Paul il y a 5 min »
    cree_le         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro         INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);
CREATE INDEX idx_liste_foyer_statut ON liste(foyer_id, statut);
CREATE INDEX idx_liste_historique ON liste(foyer_id, date_courses);

-- Ligne de liste : un article à acheter.
-- Les colonnes *_copie gardent le nom, la marque et le packaging au moment
-- de l'ajout : modifier le catalogue ne change pas l'historique.
CREATE TABLE ligne_liste (
    id                TEXT PRIMARY KEY,
    liste_id          TEXT NOT NULL REFERENCES liste(id) ON DELETE CASCADE,
    produit_id        TEXT NOT NULL REFERENCES produit(id),
    marque_id         TEXT REFERENCES marque(id),      -- NULL = n'importe quelle marque
    packaging_id      TEXT REFERENCES packaging(id),   -- NULL = indifférent
    quantite          REAL NOT NULL DEFAULT 1 CHECK (quantite > 0),
    type_promotion_id TEXT REFERENCES type_promotion(id), -- choix manuel ; NULL = pas de promo
    promo_parametres  TEXT,                    -- [v2] JSON, ex. {"quantiteAchetee":3,"quantiteOfferte":1}
    promo_libelle     TEXT,                    -- [v2] « 3 achetés = 1 offert »
    ordre             INTEGER NOT NULL DEFAULT 0, -- [v2] ordre de saisie
    note              TEXT,
    cochee            INTEGER NOT NULL DEFAULT 0 CHECK (cochee IN (0, 1)),
    cochee_par        TEXT REFERENCES membre(id),
    cochee_le         TEXT,
    nom_copie         TEXT NOT NULL,
    marque_copie      TEXT,
    packaging_copie   TEXT,
    supprime    INTEGER NOT NULL DEFAULT 0 CHECK (supprime IN (0, 1)), -- [v2]
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);
CREATE INDEX idx_ligne_liste ON ligne_liste(liste_id);
CREATE INDEX idx_ligne_produit ON ligne_liste(produit_id);

-- Ticket de caisse : photo d'une course (ou, plus tard, récupération
-- automatique depuis un compte magasin).
CREATE TABLE ticket (
    id          TEXT PRIMARY KEY,
    foyer_id    TEXT NOT NULL REFERENCES foyer(id),
    liste_id    TEXT REFERENCES liste(id),     -- facultatif : ticket sans liste possible
    magasin_id  TEXT REFERENCES magasin(id),
    date_ticket TEXT,
    montant     REAL,                          -- en euros
    source      TEXT NOT NULL DEFAULT 'photo' CHECK (source IN ('photo', 'compte_magasin')),
    image       BLOB,                          -- photo compressée (~400 Ko max)
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);
CREATE INDEX idx_ticket_liste ON ticket(liste_id);

-- Compte magasin : pour la récupération automatique des tickets (option à étudier).
-- Le MOT DE PASSE n'est JAMAIS stocké ici : il est conservé chiffré par le
-- système (Android Keystore / Trousseau iOS / Gestionnaire d'identification Windows).
CREATE TABLE compte_magasin (
    id          TEXT PRIMARY KEY,
    foyer_id    TEXT NOT NULL REFERENCES foyer(id),
    enseigne    TEXT NOT NULL,
    identifiant TEXT NOT NULL,
    derniere_recuperation TEXT,
    cree_le     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    modifie_le  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synchro     INTEGER NOT NULL DEFAULT 0 CHECK (synchro IN (0, 1))
);

-- Paramètres locaux de l'application (clé / valeur).
CREATE TABLE parametre (
    cle         TEXT PRIMARY KEY,
    valeur      TEXT
);
-- [v2] Autres clés : 'foyer_courant', 'membre_courant' (cet appareil),
--      'mode_demo' (0/1).
INSERT INTO parametre (cle, valeur) VALUES
    ('version_schema', '2'),
    ('delai_maj_catalogue_jours', '7');   -- rafraîchissement de l'extrait Open Food Facts

-- =====================================================================
--  PARTIE 3 — RÈGLES DE GESTION IMPOSÉES PAR LA BASE (déclencheurs)
-- =====================================================================

-- R1 : rien n'est supprimé physiquement dans le catalogue (archive = 1 à la place).
CREATE TRIGGER interdit_suppression_magasin   BEFORE DELETE ON magasin   BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver le magasin'); END;
CREATE TRIGGER interdit_suppression_rayon     BEFORE DELETE ON rayon     BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver le rayon'); END;
CREATE TRIGGER interdit_suppression_secteur   BEFORE DELETE ON secteur   BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver le secteur'); END;
CREATE TRIGGER interdit_suppression_produit   BEFORE DELETE ON produit   BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver le produit'); END;
CREATE TRIGGER interdit_suppression_marque    BEFORE DELETE ON marque    BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver la marque'); END;
CREATE TRIGGER interdit_suppression_packaging BEFORE DELETE ON packaging BEGIN SELECT RAISE(ABORT, 'Suppression interdite : archiver le packaging'); END;

-- R2 : un produit déjà mis dans une liste ne peut pas être archivé.
CREATE TRIGGER interdit_archivage_produit_utilise
BEFORE UPDATE OF archive ON produit
WHEN NEW.archive = 1 AND OLD.nb_utilisations > 0
BEGIN
    SELECT RAISE(ABORT, 'Produit déjà utilisé dans une liste : archivage interdit');
END;

-- R3 : le compteur d'utilisation ne peut que monter.
CREATE TRIGGER compteur_utilisation_croissant
BEFORE UPDATE OF nb_utilisations ON produit
WHEN NEW.nb_utilisations < OLD.nb_utilisations
BEGIN
    SELECT RAISE(ABORT, 'Le compteur d''utilisation ne peut pas diminuer');
END;

-- R4 : chaque ajout d'un produit dans une liste incrémente son compteur.
CREATE TRIGGER incremente_utilisation
AFTER INSERT ON ligne_liste
BEGIN
    UPDATE produit SET nb_utilisations = nb_utilisations + 1,
                       modifie_le = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
                       synchro = 0
    WHERE id = NEW.produit_id;
END;

-- R5 : un parcours ne référence que des secteurs de son magasin.
CREATE TRIGGER controle_secteur_parcours
BEFORE INSERT ON parcours_etape
WHEN (SELECT r.magasin_id FROM secteur s JOIN rayon r ON r.id = s.rayon_id WHERE s.id = NEW.secteur_id)
     <> (SELECT magasin_id FROM parcours WHERE id = NEW.parcours_id)
BEGIN
    SELECT RAISE(ABORT, 'Le secteur n''appartient pas au magasin du parcours');
END;

-- R6 : un emplacement désigne un secteur du même magasin.
CREATE TRIGGER controle_secteur_emplacement
BEFORE INSERT ON emplacement
WHEN (SELECT r.magasin_id FROM secteur s JOIN rayon r ON r.id = s.rayon_id WHERE s.id = NEW.secteur_id)
     <> NEW.magasin_id
BEGIN
    SELECT RAISE(ABORT, 'Le secteur n''appartient pas à ce magasin');
END;

-- R6 bis [v2] : même contrôle quand on déplace un produit.
CREATE TRIGGER controle_secteur_emplacement_maj
BEFORE UPDATE OF secteur_id, magasin_id ON emplacement
WHEN (SELECT r.magasin_id FROM secteur s JOIN rayon r ON r.id = s.rayon_id WHERE s.id = NEW.secteur_id)
     <> NEW.magasin_id
BEGIN
    SELECT RAISE(ABORT, 'Le secteur n''appartient pas à ce magasin');
END;

-- R7 : une liste terminée reçoit sa date de courses si elle est absente.
CREATE TRIGGER date_fin_courses
AFTER UPDATE OF statut ON liste
WHEN NEW.statut = 'terminee' AND NEW.date_courses IS NULL
BEGIN
    UPDATE liste SET date_courses = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = NEW.id;
END;

-- =====================================================================
--  PARTIE 4 — VUES UTILES AUX ÉCRANS
-- =====================================================================

-- Construction : lignes d'une liste classées par rayon puis secteur.
-- Les produits sans emplacement dans ce magasin arrivent en fin (« Non placé »).
CREATE VIEW v_liste_construction AS
SELECT  l.id AS liste_id, ll.id AS ligne_id,
        COALESCE(r.nom, 'Non placé') AS rayon, COALESCE(s.nom, 'Non placé') AS secteur,
        ll.nom_copie AS produit, ll.marque_copie AS marque, ll.packaging_copie AS packaging,
        ll.quantite, tp.code AS promotion_code, tp.libelle AS promotion, ll.cochee,
        (e.secteur_id IS NULL) AS non_place,
        r.ordre_affichage AS ordre_rayon, s.ordre_affichage AS ordre_secteur
FROM liste l
JOIN ligne_liste ll ON ll.liste_id = l.id AND ll.supprime = 0
LEFT JOIN emplacement e ON e.produit_id = ll.produit_id AND e.magasin_id = l.magasin_id
LEFT JOIN secteur s     ON s.id = e.secteur_id
LEFT JOIN rayon r       ON r.id = s.rayon_id
LEFT JOIN type_promotion tp ON tp.id = ll.type_promotion_id;
-- Usage : SELECT * FROM v_liste_construction WHERE liste_id = ?
--         ORDER BY non_place, ordre_rayon, rayon, ordre_secteur, secteur, produit;

-- Courses : lignes d'une liste dans l'ordre du parcours choisi pour cette liste.
-- Secteur absent du parcours ou produit sans emplacement -> « Non placé », en fin.
CREATE VIEW v_liste_courses AS
SELECT  l.id AS liste_id, ll.id AS ligne_id,
        s.id AS secteur_id, COALESCE(s.nom, 'Non placé') AS secteur, r.nom AS rayon,
        pe.ordre AS ordre_parcours,
        ll.nom_copie AS produit, ll.marque_copie AS marque, ll.packaging_copie AS packaging,
        ll.quantite, tp.code AS promotion_code, tp.libelle AS promotion, ll.cochee,
        (pe.ordre IS NULL) AS non_place
FROM liste l
JOIN ligne_liste ll ON ll.liste_id = l.id AND ll.supprime = 0
LEFT JOIN emplacement e     ON e.produit_id = ll.produit_id AND e.magasin_id = l.magasin_id
LEFT JOIN secteur s         ON s.id = e.secteur_id
LEFT JOIN rayon r           ON r.id = s.rayon_id
LEFT JOIN parcours_etape pe ON pe.parcours_id = l.parcours_id AND pe.secteur_id = e.secteur_id
LEFT JOIN type_promotion tp ON tp.id = ll.type_promotion_id;
-- Usage : SELECT * FROM v_liste_courses WHERE liste_id = ?
--         ORDER BY non_place, ordre_parcours, produit;

-- Préliste : produits les plus achetés par le foyer dans un magasin,
-- base de la préliste construite à partir de l'historique (EVO-004).
CREATE VIEW v_produits_frequents AS
SELECT  l.foyer_id, l.magasin_id, ll.produit_id,
        COUNT(*) AS nb_achats, MAX(l.date_courses) AS dernier_achat
FROM liste l
JOIN ligne_liste ll ON ll.liste_id = l.id AND ll.supprime = 0
WHERE l.statut = 'terminee'
GROUP BY l.foyer_id, l.magasin_id, ll.produit_id;
-- Usage : SELECT * FROM v_produits_frequents WHERE foyer_id = ? AND magasin_id = ?
--         ORDER BY nb_achats DESC, dernier_achat DESC;

-- Listes à reprendre au relancement de l'application.
CREATE VIEW v_listes_a_reprendre AS
SELECT id AS liste_id, foyer_id, magasin_id, statut, ecran_reprise, secteur_reprise_id, modifie_le
FROM liste
WHERE statut = 'en_cours' OR (statut = 'construction' AND interrompue_le IS NOT NULL); -- [v2] comme la maquette

-- Fin du script.
''';
