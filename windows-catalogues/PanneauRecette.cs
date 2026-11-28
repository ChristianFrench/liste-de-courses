using System.ComponentModel;
using EmplettesCatalogues.Donnees;

namespace EmplettesCatalogues;

/// <summary>
/// La fiche d'une recette, la même pour voir et pour modifier (22/11/2026, Aristide) : trois onglets
/// (Caractéristiques, Ingrédients, Recette) ; les critères en listes déroulantes, les ingrédients et les étapes en
/// lignes modifiables. Enregistrer et Annuler s'activent dès qu'une valeur change.
/// </summary>
sealed class PanneauRecette : UserControl
{
    readonly Entrepot _entrepot;
    Recette? _recette;
    bool _charge, _modifiee;

    readonly Label _titreFiche = new() { Dock = DockStyle.Top, Height = 34, Font = new Font("Segoe UI", 12f, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(8, 0, 0, 0) };
    readonly TabControl _onglets = new() { Dock = DockStyle.Fill };
    readonly Button _enregistrer = new() { Text = "&Enregistrer", AutoSize = true, Enabled = false };
    readonly Button _annuler = new() { Text = "Annuler", AutoSize = true, Enabled = false };

    // Caractéristiques
    readonly PictureBox _image = new() { SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(360, 240), BorderStyle = BorderStyle.FixedSingle, Margin = new Padding(0, 0, 16, 0) };
    readonly TextBox _titre = new() { Width = 360 };
    readonly ListeCochable _types = new(Criteres.Types.Select(t => t.Type)) { Width = 360 };
    readonly FlowLayoutPanel _sousTypes = new() { AutoSize = true, WrapContents = true, MaximumSize = new Size(520, 0), Margin = Padding.Empty };
    readonly Dictionary<string, ComboBox> _choixSousType = new();
    readonly ComboBox _origine = Liste(Criteres.Origines);
    readonly NumericUpDown _preparation = new() { Maximum = 2000, Width = 80 };
    readonly NumericUpDown _cuisson = new() { Maximum = 2000, Width = 80 };
    readonly ComboBox _difficulte = Liste(Criteres.Difficultes);
    readonly ListeCochable _regimes = new(Criteres.Regimes) { Width = 360 };
    readonly ListeCochable _saisons = new(Criteres.Saisons) { Width = 360 };
    readonly ComboBox _cout = Liste(Criteres.Couts);
    readonly ListeCochable _cuissons = new(Criteres.Cuissons) { Width = 360 };
    readonly ListeCochable _occasions = new(Criteres.Occasions) { Width = 360 };
    readonly Label _source = new() { AutoSize = true, Margin = new Padding(3, 6, 3, 3) };

    // Ingrédients
    readonly TextBox _pour = new() { Width = 200 };
    readonly BindingList<Ingredient> _ingredients = new();
    readonly DataGridView _grilleIngredients = Grille();
    readonly TextBox _recherche = new() { Width = 260, PlaceholderText = "Ajouter un produit du catalogue…" };

    // Recette
    readonly BindingList<Etape> _etapes = new();
    readonly DataGridView _grilleEtapes = Grille();
    readonly TextBox _conseils = new() { Multiline = true, ScrollBars = ScrollBars.Vertical, Dock = DockStyle.Fill, AcceptsReturn = true };

    public event EventHandler? Enregistree;

    public PanneauRecette(Entrepot entrepot)
    {
        _entrepot = entrepot;
        Dock = DockStyle.Fill;
        BackColor = SystemColors.Window;

        var pageCar = new TabPage("Caractéristiques") { Padding = new Padding(10), AutoScroll = true, UseVisualStyleBackColor = true };
        var pageIng = new TabPage("Ingrédients") { Padding = new Padding(10), UseVisualStyleBackColor = true };
        var pageRec = new TabPage("Recette") { Padding = new Padding(10), UseVisualStyleBackColor = true };
        _onglets.TabPages.AddRange([pageCar, pageIng, pageRec]);

        ConstruireCaracteristiques(pageCar);
        ConstruireIngredients(pageIng);
        ConstruireRecette(pageRec);

        var bas = new FlowLayoutPanel { Dock = DockStyle.Bottom, FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Padding = new Padding(6) };
        bas.Controls.AddRange([_annuler, _enregistrer]);
        _enregistrer.Click += (_, _) => Enregistrer();
        _annuler.Click += (_, _) => { if (_recette is not null) Afficher(_recette); };

        Controls.Add(_onglets);
        Controls.Add(bas);
        Controls.Add(_titreFiche);
        Enabled = false;
    }

    public bool Modifiee => _modifiee;
    public Recette? Recette => _recette;

    static ComboBox Liste(IEnumerable<string> valeurs)
    {
        var c = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200 };
        c.Items.Add("");
        foreach (var v in valeurs) c.Items.Add(v);
        return c;
    }

    static DataGridView Grille() => new()
    {
        Dock = DockStyle.Fill,
        BackgroundColor = SystemColors.Window,
        BorderStyle = BorderStyle.FixedSingle,
        AutoGenerateColumns = false,
        AllowUserToAddRows = true,
        AllowUserToResizeRows = false,
        RowHeadersWidth = 28,
        SelectionMode = DataGridViewSelectionMode.CellSelect,
        AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCells,
        EditMode = DataGridViewEditMode.EditOnKeystrokeOrF2,
    };

    void Changement(object? _ = null, EventArgs? __ = null)
    {
        if (!_charge) return;
        _modifiee = true;
        _enregistrer.Enabled = _annuler.Enabled = true;
    }

    // ------------------------------------------------------------ Caractéristiques

    void ConstruireCaracteristiques(TabPage page)
    {
        var table = new TableLayoutPanel { AutoSize = true, ColumnCount = 2, Margin = Padding.Empty };
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 130));
        table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        void Ligne(string libelle, Control c)
        {
            table.Controls.Add(new Label { Text = libelle, AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 7, 3, 3) });
            table.Controls.Add(c);
        }
        Ligne("Titre", _titre);
        Ligne("Type", _types);
        Ligne("Sous-type", _sousTypes);
        Ligne("Origine", _origine);
        var temps = new FlowLayoutPanel { AutoSize = true, Margin = Padding.Empty };
        temps.Controls.AddRange([new Label { Text = "Préparation", AutoSize = true, Margin = new Padding(3, 7, 3, 3) }, _preparation,
            new Label { Text = "min      Cuisson", AutoSize = true, Margin = new Padding(3, 7, 3, 3) }, _cuisson, new Label { Text = "min", AutoSize = true, Margin = new Padding(3, 7, 3, 3) }]);
        Ligne("Temps", temps);
        Ligne("Difficulté", _difficulte);
        Ligne("Régime", _regimes);
        Ligne("Saison", _saisons);
        Ligne("Coût", _cout);
        Ligne("Mode de cuisson", _cuissons);
        Ligne("Occasion", _occasions);
        Ligne("Source", _source);

        var rangee = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoScroll = true, WrapContents = true };
        rangee.Controls.Add(_image);
        rangee.Controls.Add(table);
        page.Controls.Add(rangee);

        _titre.TextChanged += Changement;
        _types.CochesChangees += (_, _) => { MajSousTypes(); Changement(); };
        foreach (var c in new[] { _origine, _difficulte, _cout }) c.SelectedIndexChanged += Changement;
        _preparation.ValueChanged += Changement;
        _cuisson.ValueChanged += Changement;
        foreach (var l in new[] { _regimes, _saisons, _cuissons, _occasions }) l.CochesChangees += Changement;
    }

    void MajSousTypes(Dictionary<string, string>? valeurs = null)
    {
        var avant = valeurs ?? _choixSousType.Where(e => e.Value.SelectedIndex > 0).ToDictionary(e => e.Key, e => (string)e.Value.SelectedItem!);
        _sousTypes.SuspendLayout();
        _sousTypes.Controls.Clear();
        _choixSousType.Clear();
        foreach (var t in _types.Coches.OrderBy(Criteres.RangType))
        {
            var c = Liste(Criteres.Types.First(x => x.Type == t).SousTypes);
            c.Width = 180;
            if (avant.TryGetValue(t, out var st) && c.Items.Contains(st)) c.SelectedItem = st; else c.SelectedIndex = 0;
            c.SelectedIndexChanged += Changement;
            _choixSousType[t] = c;
            _sousTypes.Controls.Add(new Label { Text = t, AutoSize = true, Margin = new Padding(3, 7, 3, 3) });
            _sousTypes.Controls.Add(c);
        }
        if (_choixSousType.Count == 0) _sousTypes.Controls.Add(new Label { Text = "—", AutoSize = true, Margin = new Padding(3, 7, 3, 3) });
        _sousTypes.ResumeLayout();
    }

    // ------------------------------------------------------------ Ingrédients

    void ConstruireIngredients(TabPage page)
    {
        _grilleIngredients.Columns.AddRange(
            new DataGridViewTextBoxColumn { HeaderText = "Ingrédient", DataPropertyName = nameof(Ingredient.Nom), AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, FillWeight = 40 },
            new DataGridViewTextBoxColumn { HeaderText = "Quantité", DataPropertyName = nameof(Ingredient.Quantite), AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, FillWeight = 25 },
            new DataGridViewTextBoxColumn { HeaderText = "Précision", DataPropertyName = nameof(Ingredient.Precision), AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, FillWeight = 35 });
        _grilleIngredients.DataSource = _ingredients;
        _grilleIngredients.CellValueChanged += (_, _) => Changement();
        _grilleIngredients.UserDeletedRow += (_, _) => Changement();

        var haut = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(0, 0, 0, 6) };
        haut.Controls.Add(new Label { Text = "Pour", AutoSize = true, Margin = new Padding(3, 7, 3, 3) });
        haut.Controls.Add(_pour);
        _pour.TextChanged += Changement;

        // Ajout d'un ingrédient par recherche dans le catalogue des produits (comme dans l'application).
        var source = new AutoCompleteStringCollection();
        source.AddRange(_entrepot.Catalogue.TousLesProduits.Select(p => p.Nom).Distinct().OrderBy(x => x).ToArray());
        _recherche.AutoCompleteMode = AutoCompleteMode.SuggestAppend;
        _recherche.AutoCompleteSource = AutoCompleteSource.CustomSource;
        _recherche.AutoCompleteCustomSource = source;
        _recherche.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) { AjouterIngredient(); e.SuppressKeyPress = true; } };

        var outils = BarreLignes(_grilleIngredients, _ingredients, () => new Ingredient());
        outils.Items.Insert(0, new ToolStripControlHost(_recherche));
        outils.Items.Insert(1, new ToolStripButton("Ajouter", Icones.Glyphe(Icones.Ajouter, Icones.Vert, 16), (_, _) => AjouterIngredient()) { DisplayStyle = ToolStripItemDisplayStyle.ImageAndText });
        outils.Items.Insert(2, new ToolStripSeparator());

        page.Controls.Add(_grilleIngredients);
        page.Controls.Add(outils);
        page.Controls.Add(haut);
    }

    void AjouterIngredient()
    {
        var nom = _recherche.Text.Trim();
        if (nom.Length == 0) return;
        _grilleIngredients.EndEdit();
        _ingredients.Add(new Ingredient { Nom = nom });
        _recherche.Clear();
        Changement();
        _grilleIngredients.CurrentCell = _grilleIngredients.Rows[_ingredients.Count - 1].Cells[1];
        _grilleIngredients.BeginEdit(true);
    }

    /// <summary>Barre Insérer / Supprimer / Monter / Descendre d'une grille de lignes.</summary>
    ToolStrip BarreLignes<T>(DataGridView grille, BindingList<T> lignes, Func<T> nouvelle)
    {
        int Courante() => grille.CurrentCell?.RowIndex is int i && i < lignes.Count ? i : -1;
        void Deplacer(int de, int vers)
        {
            if (de < 0 || vers < 0 || vers >= lignes.Count) return;
            grille.EndEdit();
            var x = lignes[de];
            lignes.RemoveAt(de);
            lignes.Insert(vers, x);
            grille.CurrentCell = grille.Rows[vers].Cells[grille.CurrentCell?.ColumnIndex ?? 0];
            Changement();
        }
        var barre = new ToolStrip { Dock = DockStyle.Top, GripStyle = ToolStripGripStyle.Hidden, ImageScalingSize = new Size(16, 16), BackColor = SystemColors.Window, RenderMode = ToolStripRenderMode.System };
        barre.Items.Add(new ToolStripButton("Insérer une ligne", Icones.Glyphe(Icones.Inserer, Icones.Bleu, 16), (_, _) =>
        {
            grille.EndEdit();
            var i = Math.Max(Courante(), 0);
            lignes.Insert(Math.Min(i, lignes.Count), nouvelle());
            grille.CurrentCell = grille.Rows[Math.Min(i, lignes.Count - 1)].Cells[grille.Columns.Count > 1 && grille.Columns[0].ReadOnly ? 1 : 0];
            grille.BeginEdit(true);
            Changement();
        }) { DisplayStyle = ToolStripItemDisplayStyle.ImageAndText });
        barre.Items.Add(new ToolStripButton("Supprimer la ligne", Icones.Glyphe(Icones.Supprimer, Icones.Rouge, 16), (_, _) =>
        {
            var i = Courante();
            if (i < 0) return;
            grille.EndEdit();
            lignes.RemoveAt(i);
            Changement();
        }) { DisplayStyle = ToolStripItemDisplayStyle.ImageAndText });
        barre.Items.Add(new ToolStripSeparator());
        barre.Items.Add(new ToolStripButton("Monter", Icones.Glyphe(Icones.Monter, Icones.Gris, 16), (_, _) => Deplacer(Courante(), Courante() - 1)) { DisplayStyle = ToolStripItemDisplayStyle.Image });
        barre.Items.Add(new ToolStripButton("Descendre", Icones.Glyphe(Icones.Descendre, Icones.Gris, 16), (_, _) => Deplacer(Courante(), Courante() + 1)) { DisplayStyle = ToolStripItemDisplayStyle.Image });
        return barre;
    }

    // ------------------------------------------------------------ Recette

    void ConstruireRecette(TabPage page)
    {
        var numero = new DataGridViewTextBoxColumn { HeaderText = "N°", ReadOnly = true, Width = 40, SortMode = DataGridViewColumnSortMode.NotSortable };
        var texte = new DataGridViewTextBoxColumn { HeaderText = "Étape (verbe à l'infinitif)", DataPropertyName = nameof(Etape.Texte), AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill };
        texte.DefaultCellStyle.WrapMode = DataGridViewTriState.True;
        _grilleEtapes.Columns.AddRange(numero, texte);
        _grilleEtapes.DataSource = _etapes;
        _grilleEtapes.CellValueChanged += (_, _) => Changement();
        _grilleEtapes.UserDeletedRow += (_, _) => Changement();
        _grilleEtapes.RowPostPaint += (_, e) =>
        {
            if (e.RowIndex < _etapes.Count) _grilleEtapes.Rows[e.RowIndex].Cells[0].Value = (e.RowIndex + 1).ToString();
        };

        var conseils = new GroupBox { Text = "Conseils (un par ligne)", Dock = DockStyle.Bottom, Height = 110, Padding = new Padding(6) };
        conseils.Controls.Add(_conseils);
        _conseils.TextChanged += Changement;

        page.Controls.Add(_grilleEtapes);
        page.Controls.Add(BarreLignes(_grilleEtapes, _etapes, () => new Etape()));
        page.Controls.Add(conseils);
    }

    // ------------------------------------------------------------ Afficher, enregistrer

    public void Afficher(Recette? r)
    {
        _charge = false;
        _recette = r;
        Enabled = r is not null;
        _titreFiche.Text = r?.Titre ?? "";
        if (r is null) { _charge = true; return; }
        _titre.Text = r.Titre;
        _types.Coches = r.Types;
        MajSousTypes(r.SousTypes);
        Choisir(_origine, r.Origine);
        _preparation.Value = Math.Min(r.TempsPreparation ?? 0, (int)_preparation.Maximum);
        _cuisson.Value = Math.Min(r.TempsCuisson ?? 0, (int)_cuisson.Maximum);
        Choisir(_difficulte, r.Difficulte);
        _regimes.Coches = r.Regimes;
        _saisons.Coches = r.Saisons;
        Choisir(_cout, r.Cout);
        _cuissons.Coches = r.Cuissons;
        _occasions.Coches = r.Occasions;
        _source.Text = r.Source is null ? "Recette maison" : $"Recette {r.Source}";
        var chemin = _entrepot.CheminImage(r.Illustration);
        _image.Image?.Dispose();
        _image.Image = null;
        if (chemin is not null && File.Exists(chemin))
        {
            using var f = File.OpenRead(chemin);
            _image.Image = Image.FromStream(f);
        }
        _pour.Text = r.Pour ?? "";
        _ingredients.Clear();
        foreach (var i in r.Detail) _ingredients.Add(new Ingredient { Nom = i.Nom, Quantite = i.Quantite, Precision = i.Precision });
        _etapes.Clear();
        foreach (var e in r.Etapes) _etapes.Add(new Etape { Texte = e.Texte });
        _conseils.Text = string.Join(Environment.NewLine, r.Conseils);
        _modifiee = false;
        _enregistrer.Enabled = _annuler.Enabled = false;
        _charge = true;
    }

    static void Choisir(ComboBox c, string? v) => c.SelectedIndex = v is not null && c.Items.Contains(v) ? c.Items.IndexOf(v) : 0;

    static string? Valeur(ComboBox c) => c.SelectedIndex > 0 ? (string)c.SelectedItem! : null;

    public bool Enregistrer()
    {
        if (_recette is null) return true;
        _grilleIngredients.EndEdit();
        _grilleEtapes.EndEdit();
        if (_titre.Text.Trim().Length == 0) { MessageBox.Show("Le titre est obligatoire.", Infos.Nom, MessageBoxButtons.OK, MessageBoxIcon.Warning); return false; }
        if (_types.Coches.Count == 0) { MessageBox.Show("Choisissez au moins un type.", Infos.Nom, MessageBoxButtons.OK, MessageBoxIcon.Warning); return false; }
        var r = _recette;
        r.Titre = _titre.Text.Trim();
        r.Types = _types.Coches.OrderBy(Criteres.RangType).ToList();
        r.SousTypes = _choixSousType.Where(e => e.Value.SelectedIndex > 0).ToDictionary(e => e.Key, e => (string)e.Value.SelectedItem!);
        r.Origine = Valeur(_origine);
        r.TempsPreparation = _preparation.Value > 0 ? (int)_preparation.Value : null;
        r.TempsCuisson = _cuisson.Value > 0 ? (int)_cuisson.Value : (r.TempsCuisson == 0 ? 0 : null);
        r.Difficulte = Valeur(_difficulte);
        r.Regimes = _regimes.Coches;
        r.Saisons = _saisons.Coches;
        r.Cout = Valeur(_cout);
        r.Cuissons = _cuissons.Coches;
        r.Occasions = _occasions.Coches;
        r.Pour = _pour.Text.Trim().Length == 0 ? null : _pour.Text.Trim();
        r.Detail = _ingredients.Where(i => i.Nom.Trim().Length > 0).ToList();
        r.Etapes = _etapes.Where(e => e.Texte.Trim().Length > 0).ToList();
        r.Conseils = _conseils.Lines.Where(l => l.Trim().Length > 0).ToList();
        r.Ecrire();
        try
        {
            _entrepot.EnregistrerRecettes();
        }
        catch (Exception x)
        {
            MessageBox.Show($"Enregistrement impossible : {x.Message}", Infos.Nom, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return false;
        }
        Afficher(r);
        Enregistree?.Invoke(this, EventArgs.Empty);
        return true;
    }
}
