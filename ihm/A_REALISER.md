# Ordres de travail du fil IHM

Les ordres les plus récents sont en tête. Le fil de génération exécute l'ordre « À réaliser » quand le maître d'ouvrage écrit « Générer », puis met à jour son statut. Aucun ordre n'est supprimé.

---

## Ordre n° 1 — IHM v0.2 · statut : À réaliser

- **Déposé le :** 9 octobre 2026, par le fil « IHM et ergonomie »
- **Dossier :** [`ihm/v0.2`](v0.2/LISEZMOI.md) — conception validée par le maître d'ouvrage (maquette v0.4, 18 écrans)
- **À faire :**
  1. Lire `ihm/v0.2/LISEZMOI.md`, qui explique le contenu du dossier et l'ordre de priorité des fichiers.
  2. Réaliser la maquette Flutter de cette version : navigation par onglets à icône (Listes, Historique, Magasin, Paramètres), interruption et reprise sans perte, écran de reprise au lancement, promotions choisies sur une ligne pendant la construction, écran Paramètres.
  3. Livrer **Windows d'abord** (fenêtre fixe au format téléphone), puis l'APK, puis l'iPhone, à partir du même code.
  4. Avant de livrer, vérifier les critères de recette de la spécification (`ihm/v0.2/Spécification IHM.odt`, chapitre « Critères de recette »).
  5. Signaler toute contradiction entre les fichiers au maître d'ouvrage plutôt que de trancher seul.
- **Points d'attention :**
  - La promotion est désormais portée par la ligne de liste. C'est un écart avec le modèle de données, détaillé dans le champ `_ecartsModele` de `Données maquette.json`.
  - Les travaux en cours sur l'écran d'essai « Produits réels » (Open Food Facts) ne font pas partie de cette conception. Les conserver ou non relève du maître d'ouvrage : lui poser la question.
- **Réalisé :** _(à compléter par le fil de génération : version de l'application, date)_
