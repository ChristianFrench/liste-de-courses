namespace EmplettesCatalogues;

/// <summary>Aide (F1), raccourcis clavier et À propos.</summary>
static class FormTexte
{
    static Form Fenetre(IWin32Window parent, string titre, Control contenu, int largeur = 720, int hauteur = 560)
    {
        var f = new Form
        {
            Text = titre, Font = new Font("Segoe UI", 9f), StartPosition = FormStartPosition.CenterParent, ShowInTaskbar = false,
            MinimizeBox = false, MaximizeBox = false, Size = new Size(largeur, hauteur), FormBorderStyle = FormBorderStyle.Sizable,
        };
        var fermer = new Button { Text = "Fermer", DialogResult = DialogResult.OK, AutoSize = true };
        var bas = new FlowLayoutPanel { Dock = DockStyle.Bottom, FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Padding = new Padding(8) };
        bas.Controls.Add(fermer);
        contenu.Dock = DockStyle.Fill;
        f.Controls.Add(contenu);
        f.Controls.Add(bas);
        f.AcceptButton = f.CancelButton = fermer;
        return f;
    }

    public static void Aide(IWin32Window parent)
    {
        var t = new RichTextBox { ReadOnly = true, BorderStyle = BorderStyle.None, BackColor = SystemColors.Window, Font = new Font("Segoe UI", 9f) };
        void Titre(string s) { t.SelectionFont = new Font("Segoe UI", 10.5f, FontStyle.Bold); t.AppendText(s + "\n"); }
        void Texte(string s) { t.SelectionFont = new Font("Segoe UI", 9f); t.AppendText(s + "\n\n"); }
        Titre(Infos.Nom);
        Texte("Ce logiciel tient à jour le contenu commun à tous les foyers d'Emplettes : les produits (domaines, rayons, secteurs, produits), les marques et les recettes.");
        Titre("La fenêtre");
        Texte("En haut, la barre de menus et la barre d'outils. Au milieu, l'arbre du catalogue à gauche et la fiche de l'élément choisi à droite (la barre qui les sépare se déplace à la souris). En bas, la barre d'état : dernière action, catalogue affiché, contenu, emplacement des données, version du logiciel.");
        Texte("Les commandes grisées seront branchées dans les prochaines versions.");
        Titre("Changer de catalogue");
        Texte("Menu Affichage, boutons Produits, Marques, Recettes de la barre d'outils, ou Ctrl+1, Ctrl+2, Ctrl+3.");
        Titre("Parcourir et rechercher");
        Texte("Le signe à gauche de chaque titre le déplie ou le replie (ou les flèches droite et gauche du clavier). Tout déplier (Ctrl+Plus) et Tout replier (Ctrl+Moins) agissent sur toute la hiérarchie. Rechercher (Ctrl+F), puis Entrée ou F3 pour le résultat suivant, Maj+F3 pour le précédent.");
        Titre("Les recettes");
        Texte("La fiche est la même pour voir et pour modifier. Caractéristiques : les critères en listes déroulantes. Ingrédients : une ligne par ingrédient (nom, quantité, précision) ; « Ajouter un produit du catalogue » propose les produits au fil de la frappe. Recette : une ligne par étape, avec Insérer une ligne, Supprimer la ligne, Monter, Descendre. Enregistrer (Ctrl+S) et Annuler s'activent dès qu'une valeur change. Double-clic ou Entrée sur une recette : la même fiche dans une fenêtre.");
        Titre("Les données");
        Texte("Cette version travaille sur les données de la console sur ce PC ; n'ouvrez pas les deux logiciels en même temps. Avant chaque enregistrement des recettes, une copie de sécurité recettes.json.bak est faite. Les données iront sur le serveur dans une prochaine version.");
        t.SelectionStart = 0;
        using var f = Fenetre(parent, "Aide", t);
        f.ShowDialog(parent);
    }

    public static void Raccourcis(IWin32Window parent)
    {
        var l = new ListView { View = View.Details, FullRowSelect = true, HeaderStyle = ColumnHeaderStyle.Nonclickable, BorderStyle = BorderStyle.None };
        l.Columns.Add("Touches", 220);
        l.Columns.Add("Commande", 420);
        foreach (var (k, c) in new[]
        {
            ("Ctrl+S", "Enregistrer la fiche"), ("F5", "Recharger les données"), ("Ctrl+1, Ctrl+2, Ctrl+3", "Produits, Marques, Recettes"),
            ("Ctrl+Plus, Ctrl+Moins", "Tout déplier, Tout replier"), ("Ctrl+F", "Rechercher"), ("Entrée ou F3, Maj+F3", "Résultat suivant, précédent"),
            ("Entrée ou double-clic", "Ouvrir la recette dans une fenêtre"), ("F1", "Aide"), ("Alt", "Barre de menus ; Alt + lettre soulignée ouvre un menu"),
            ("Échap", "Fermer une fenêtre"), ("Alt+F4", "Quitter"),
        })
            l.Items.Add(new ListViewItem(new[] { k, c }));
        using var f = Fenetre(parent, "Raccourcis clavier", l, 680, 420);
        f.ShowDialog(parent);
    }

    public static void APropos(IWin32Window parent)
    {
        var p = new Panel { Padding = new Padding(20) };
        var icone = new PictureBox { Image = Icon.ExtractAssociatedIcon(Application.ExecutablePath)?.ToBitmap(), SizeMode = PictureBoxSizeMode.Zoom, Bounds = new Rectangle(20, 20, 64, 64) };
        var texte = new Label
        {
            AutoSize = true, Location = new Point(100, 22),
            Text = $"{Infos.Nom}\nGestion des catalogues d'Emplettes\n\nVersion {Infos.Version}",
        };
        p.Controls.AddRange([icone, texte]);
        using var f = Fenetre(parent, "À propos", p, 440, 220);
        f.ShowDialog(parent);
    }
}
