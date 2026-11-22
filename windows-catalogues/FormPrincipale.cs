using System.Globalization;
using System.Text;
using EmplettesCatalogues.Donnees;

namespace EmplettesCatalogues;

enum Vue { Produits, Marques, Recettes }

/// <summary>
/// Fenêtre principale aux normes Windows (22/11/2026, Aristide) : barre de menus, barre d'outils, zone de travail
/// (arbre à gauche, fiche à droite), barre d'état. Police Segoe UI 9 pt partout.
/// </summary>
sealed class FormPrincipale : Form
{
    Entrepot _entrepot;
    Vue _vue = Vue.Produits;

    readonly MenuStrip _menus = new();
    readonly ToolStrip _outils = new() { ImageScalingSize = new Size(20, 20), GripStyle = ToolStripGripStyle.Hidden, Padding = new Padding(4, 2, 4, 2) };
    readonly StatusStrip _etat = new();
    readonly SplitContainer _partage = new() { Dock = DockStyle.Fill, FixedPanel = FixedPanel.None };
    readonly TreeView _arbre = new() { Dock = DockStyle.Fill, HideSelection = false, BorderStyle = BorderStyle.None, ShowLines = true, FullRowSelect = false, ItemHeight = 20 };
    readonly Panel _droite = new() { Dock = DockStyle.Fill, BackColor = SystemColors.Window };
    readonly ListView _proprietes = new() { Dock = DockStyle.Fill, View = View.Details, FullRowSelect = true, HeaderStyle = ColumnHeaderStyle.Nonclickable, BorderStyle = BorderStyle.None };
    readonly Label _titreDroite = new() { Dock = DockStyle.Top, Height = 34, Font = new Font("Segoe UI", 12f, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(8, 0, 0, 0) };
    readonly Panel _panneauProprietes = new() { Dock = DockStyle.Fill };
    PanneauRecette _panneauRecette;

    readonly ToolStripTextBox _recherche = new() { Width = 220, ToolTipText = "Rechercher (Ctrl+F) ; Entrée ou F3 : suivant" };
    readonly ToolStripStatusLabel _message = new() { Spring = true, TextAlign = ContentAlignment.MiddleLeft, Text = "Prêt" };
    readonly ToolStripStatusLabel _etatVue = new() { BorderSides = ToolStripStatusLabelBorderSides.Left };
    readonly ToolStripStatusLabel _etatContenu = new() { BorderSides = ToolStripStatusLabelBorderSides.Left };
    readonly ToolStripStatusLabel _etatDonnees = new() { BorderSides = ToolStripStatusLabelBorderSides.Left };
    readonly ToolStripStatusLabel _etatVersion = new() { BorderSides = ToolStripStatusLabelBorderSides.Left };
    readonly Dictionary<Vue, ToolStripButton> _boutonsVue = new();
    readonly Dictionary<Vue, ToolStripMenuItem> _menusVue = new();
    ToolStripMenuItem _menuBarreOutils = null!, _menuBarreEtat = null!;

    public FormPrincipale(Entrepot entrepot)
    {
        _entrepot = entrepot;
        Text = Infos.Nom;
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        Font = new Font("Segoe UI", 9f);
        StartPosition = FormStartPosition.CenterScreen;
        var ecran = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1280, 800);
        Size = new Size(Math.Min(1500, ecran.Width * 9 / 10), Math.Min(950, ecran.Height * 9 / 10));
        MinimumSize = new Size(900, 560);
        KeyPreview = true;

        _proprietes.Columns.Add("Propriété", 160);
        _proprietes.Columns.Add("Valeur", 600);
        _panneauProprietes.Controls.Add(_proprietes);
        _panneauProprietes.Controls.Add(_titreDroite);
        _panneauRecette = NouveauPanneauRecette();
        _droite.Controls.Add(_panneauProprietes);

        _partage.Panel1.Controls.Add(_arbre);
        _partage.Panel2.Controls.Add(_droite);

        ConstruireMenus();
        ConstruireOutils();
        ConstruireEtat();

        Controls.Add(_partage);
        Controls.Add(_outils);
        Controls.Add(_menus);
        Controls.Add(_etat);
        MainMenuStrip = _menus;

        _arbre.BeforeSelect += (_, e) => { if (!QuitterFicheModifiee()) e.Cancel = true; };
        _arbre.AfterSelect += (_, e) => AfficherSelection(e.Node);
        _arbre.NodeMouseDoubleClick += (_, e) => OuvrirEnFenetre(e.Node);
        _arbre.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) { OuvrirEnFenetre(_arbre.SelectedNode); e.Handled = true; } };
        Load += (_, _) =>
        {
            _partage.SplitterDistance = (int)(_partage.Width * 0.42);
            ChoisirVue(Vue.Produits);
            if (_entrepot.Erreur is not null) Message(_entrepot.Erreur);
        };
        FormClosing += (_, e) => { if (!QuitterFicheModifiee()) e.Cancel = true; };
    }

    PanneauRecette NouveauPanneauRecette()
    {
        var p = new PanneauRecette(_entrepot);
        p.Enregistree += (_, _) => { Message($"Recette « {p.Recette?.Titre} » enregistrée"); RafraichirArbre(garderSelection: true); };
        return p;
    }

    void Message(string texte) => _message.Text = texte;

    // ------------------------------------------------------------ menus

    static ToolStripMenuItem Item(string texte, char? glyphe = null, Color? couleur = null, Keys raccourci = Keys.None, EventHandler? clic = null, string? afficheRaccourci = null)
    {
        var m = new ToolStripMenuItem(texte, glyphe is char g ? Icones.Glyphe(g, couleur ?? Icones.Gris, 16) : null, clic) { ShortcutKeys = raccourci };
        if (afficheRaccourci is not null) m.ShortcutKeyDisplayString = afficheRaccourci;
        if (clic is null) { m.Enabled = false; m.ToolTipText = "À venir"; }
        return m;
    }

    void ConstruireMenus()
    {
        var fichier = new ToolStripMenuItem("&Fichier");
        fichier.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Enregistrer", Icones.Enregistrer, Icones.Bleu, Keys.Control | Keys.S, (_, _) => EnregistrerFiche()),
            Item("&Recharger les données", Icones.Recharger, Icones.Bleu, Keys.F5, (_, _) => Recharger(), "F5"),
            new ToolStripSeparator(),
            Item("&Importer…", Icones.Importer, Icones.Orange, Keys.Control | Keys.I),
            Item("E&xporter…", Icones.Exporter, Icones.Orange, Keys.Control | Keys.E),
            new ToolStripSeparator(),
            Item("&Quitter", null, null, Keys.Alt | Keys.F4, (_, _) => Close()),
        });

        var edition = new ToolStripMenuItem("É&dition");
        edition.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Annuler", Icones.Annuler, Icones.Gris, Keys.Control | Keys.Z),
            Item("&Rétablir", Icones.Retablir, Icones.Gris, Keys.Control | Keys.Y),
            new ToolStripSeparator(),
            Item("Co&uper", Icones.Couper, Icones.Gris, Keys.Control | Keys.X),
            Item("&Copier", Icones.Copier, Icones.Gris, Keys.Control | Keys.C),
            Item("C&oller", Icones.Coller, Icones.Gris, Keys.Control | Keys.V),
            new ToolStripSeparator(),
            Item("Re&nommer", Icones.Renommer, Icones.Gris, Keys.F2),
            Item("&Supprimer", Icones.Supprimer, Icones.Rouge, Keys.Delete),
            new ToolStripSeparator(),
            Item("Rec&hercher", Icones.Rechercher, Icones.Bleu, Keys.Control | Keys.F, (_, _) => { _recherche.Focus(); _recherche.SelectAll(); }),
            Item("Suivan&t", null, null, Keys.F3, (_, _) => Chercher(1)),
            Item("&Précédent", null, null, Keys.Shift | Keys.F3, (_, _) => Chercher(-1)),
        });

        var affichage = new ToolStripMenuItem("&Affichage");
        foreach (var v in Enum.GetValues<Vue>())
        {
            var m = Item(TitreVue(v), GlypheVue(v), Icones.Vert, Keys.Control | (Keys.D1 + (int)v), (_, _) => ChoisirVue(v));
            _menusVue[v] = m;
            affichage.DropDownItems.Add(m);
        }
        _menuBarreOutils = Item("Barre d'&outils", null, null, Keys.None, (_, _) => { _outils.Visible = !_outils.Visible; _menuBarreOutils.Checked = _outils.Visible; });
        _menuBarreEtat = Item("Barre d'&état", null, null, Keys.None, (_, _) => { _etat.Visible = !_etat.Visible; _menuBarreEtat.Checked = _etat.Visible; });
        _menuBarreOutils.Checked = _menuBarreEtat.Checked = true;
        affichage.DropDownItems.AddRange(new ToolStripItem[] {
            new ToolStripSeparator(),
            Item("Tout &déplier", Icones.Deplier, Icones.Gris, Keys.Control | Keys.Add, (_, _) => Plier(true), "Ctrl+Plus"),
            Item("Tout &replier", Icones.Replier, Icones.Gris, Keys.Control | Keys.Subtract, (_, _) => Plier(false), "Ctrl+Moins"),
            new ToolStripSeparator(),
            _menuBarreOutils,
            _menuBarreEtat,
        });

        var insertion = new ToolStripMenuItem("&Insertion");
        insertion.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Nouveau", Icones.Ajouter, Icones.Vert, Keys.Control | Keys.N),
            Item("&Illustration ou icône…", Icones.Image, Icones.Orange),
        });

        var version = new ToolStripMenuItem("&Version");
        version.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Contrôler le catalogue", Icones.Controler, Icones.Vert, Keys.F7),
            Item("&Valider les modifications", Icones.Valider, Icones.Vert, Keys.Control | Keys.Shift | Keys.S),
            Item("&Historique des étapes", Icones.Historique, Icones.Gris),
            new ToolStripSeparator(),
            Item("&Proposer cette version", Icones.Proposer, Icones.Bleu),
            Item("&État des versions"),
        });

        var outils = new ToolStripMenuItem("&Outils");
        outils.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Iconographie", Icones.Image, Icones.Orange),
            Item("&Propositions des foyers"),
            new ToolStripSeparator(),
            Item("&Options…", Icones.Reglages, Icones.Gris),
        });

        var aide = new ToolStripMenuItem("&?");
        aide.DropDownItems.AddRange(new ToolStripItem[] {
            Item("&Aide", Icones.Aide, Icones.Bleu, Keys.F1, (_, _) => FormTexte.Aide(this)),
            Item("&Raccourcis clavier", Icones.Clavier, Icones.Gris, Keys.None, (_, _) => FormTexte.Raccourcis(this)),
            new ToolStripSeparator(),
            Item("À &propos", Icones.Info, Icones.Gris, Keys.None, (_, _) => FormTexte.APropos(this)),
        });

        _menus.Items.AddRange(new ToolStripItem[] {fichier, edition, affichage, insertion, version, outils, aide});
    }

    // ------------------------------------------------------------ barre d'outils

    void ConstruireOutils()
    {
        ToolStripButton Bouton(char glyphe, Color couleur, string bulle, EventHandler? clic = null)
        {
            var b = new ToolStripButton(null, Icones.Glyphe(glyphe, couleur), clic) { ToolTipText = bulle, DisplayStyle = ToolStripItemDisplayStyle.Image };
            if (clic is null) { b.Enabled = false; b.ToolTipText = bulle + " : à venir"; }
            return b;
        }
        _outils.Items.AddRange(new ToolStripItem[] {
            Bouton(Icones.Enregistrer, Icones.Bleu, "Enregistrer (Ctrl+S)", (_, _) => EnregistrerFiche()),
            Bouton(Icones.Recharger, Icones.Bleu, "Recharger les données (F5)", (_, _) => Recharger()),
            new ToolStripSeparator(),
            Bouton(Icones.Annuler, Icones.Gris, "Annuler (Ctrl+Z)"),
            Bouton(Icones.Retablir, Icones.Gris, "Rétablir (Ctrl+Y)"),
            new ToolStripSeparator(),
        });
        foreach (var v in Enum.GetValues<Vue>())
        {
            var b = new ToolStripButton(NomVue(v), Icones.Glyphe(GlypheVue(v), Icones.Vert), (_, _) => ChoisirVue(v))
            {
                ToolTipText = $"{TitreVue(v)} (Ctrl+{(int)v + 1})",
                DisplayStyle = ToolStripItemDisplayStyle.ImageAndText,
            };
            _boutonsVue[v] = b;
            _outils.Items.Add(b);
        }
        var cherche = new ToolStripButton(null, Icones.Glyphe(Icones.Rechercher, Icones.Bleu), (_, _) => Chercher(1)) { ToolTipText = "Suivant (F3)" };
        _recherche.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) { Chercher(e.Shift ? -1 : 1); e.SuppressKeyPress = true; } };
        _outils.Items.AddRange(new ToolStripItem[] {
            new ToolStripSeparator(),
            Bouton(Icones.Deplier, Icones.Gris, "Tout déplier (Ctrl+Plus)", (_, _) => Plier(true)),
            Bouton(Icones.Replier, Icones.Gris, "Tout replier (Ctrl+Moins)", (_, _) => Plier(false)),
            new ToolStripSeparator(),
            Bouton(Icones.Ajouter, Icones.Vert, "Nouveau (Ctrl+N)"),
            Bouton(Icones.Renommer, Icones.Gris, "Renommer (F2)"),
            Bouton(Icones.Supprimer, Icones.Rouge, "Supprimer (Suppr)"),
            new ToolStripSeparator(),
            Bouton(Icones.Controler, Icones.Vert, "Contrôler le catalogue (F7)"),
            Bouton(Icones.Proposer, Icones.Bleu, "Proposer cette version"),
            new ToolStripSeparator(),
            new ToolStripLabel("Rechercher"),
            _recherche,
            cherche,
        });
        var aide = Bouton(Icones.Aide, Icones.Bleu, "Aide (F1)", (_, _) => FormTexte.Aide(this));
        aide.Alignment = ToolStripItemAlignment.Right;
        _outils.Items.Add(aide);
    }

    void ConstruireEtat()
    {
        _etatVersion.Text = $"Version {Infos.Version}";
        _etat.Items.AddRange(new ToolStripItem[] {_message, _etatVue, _etatContenu, _etatDonnees, _etatVersion});
    }

    void MajEtat()
    {
        _etatVue.Text = TitreVue(_vue);
        var c = _entrepot.Catalogue;
        _etatContenu.Text = _vue == Vue.Recettes
            ? $"{_entrepot.Recettes.Count} recettes"
            : $"{c.Rayons.Count} rayons · {c.Rayons.Sum(r => r.Secteurs.Count)} secteurs · {c.TousLesProduits.Count()} produits";
        _etatDonnees.Text = _entrepot.Dossier is null ? "Données introuvables" : $"Données de la console sur ce PC ({c.Origine})";
    }

    // ------------------------------------------------------------ vues et arbre

    static string NomVue(Vue v) => v switch { Vue.Produits => "Produits", Vue.Marques => "Marques", _ => "Recettes" };
    static string TitreVue(Vue v) => $"Catalogue des {NomVue(v).ToLowerInvariant()}";
    static char GlypheVue(Vue v) => v switch { Vue.Produits => Icones.Produits, Vue.Marques => Icones.Marques, _ => Icones.Recettes };

    void ChoisirVue(Vue v)
    {
        if (!QuitterFicheModifiee()) return;
        _vue = v;
        foreach (var (k, b) in _boutonsVue) b.Checked = k == v;
        foreach (var (k, m) in _menusVue) m.Checked = k == v;
        _droite.Controls.Clear();
        _droite.Controls.Add(v == Vue.Recettes ? _panneauRecette : _panneauProprietes);
        _panneauRecette.Afficher(null);
        _proprietes.Items.Clear();
        _titreDroite.Text = "";
        RafraichirArbre();
        MajEtat();
        Message($"{TitreVue(v)} affiché");
    }

    static TreeNode Titre(string texte, object? tag = null) =>
        new(texte) { Tag = tag, NodeFont = new Font("Segoe UI", 9f, FontStyle.Bold) };

    void RafraichirArbre(bool garderSelection = false)
    {
        var avant = garderSelection ? _arbre.SelectedNode?.Tag : null;
        _arbre.BeginUpdate();
        _arbre.Nodes.Clear();
        switch (_vue)
        {
            case Vue.Produits: ArbreProduits(); break;
            case Vue.Marques: ArbreMarques(); break;
            default: ArbreRecettes(); break;
        }
        _arbre.EndUpdate();
        if (avant is not null && Trouver(_arbre.Nodes, n => ReferenceEquals(n.Tag, avant)) is { } n)
        {
            n.EnsureVisible();
            _arbre.SelectedNode = n;
        }
    }

    void ArbreProduits()
    {
        var c = _entrepot.Catalogue;
        foreach (var d in c.Domaines)
        {
            var nd = Titre(d);
            foreach (var r in c.Rayons.Where(r => r.Domaine == d))
            {
                var nr = Titre(r.Nom, r);
                foreach (var s in r.Secteurs)
                {
                    var ns = Titre($"{s.Nom}  ({s.Produits.Count})", s);
                    foreach (var p in s.Produits) ns.Nodes.Add(new TreeNode(p.Nom) { Tag = p });
                    nr.Nodes.Add(ns);
                }
                nd.Nodes.Add(nr);
            }
            _arbre.Nodes.Add(nd);
        }
    }

    sealed record Marque(string Nom, string Domaine, List<Produit> Produits);

    void ArbreMarques()
    {
        var c = _entrepot.Catalogue;
        foreach (var d in c.Domaines)
        {
            var marques = c.Rayons.Where(r => r.Domaine == d).SelectMany(r => r.Secteurs).SelectMany(s => s.Produits)
                .SelectMany(p => p.Marques.Select(m => (m, p)))
                .GroupBy(x => x.m, StringComparer.CurrentCultureIgnoreCase)
                .OrderBy(g => g.Key, StringComparer.CurrentCultureIgnoreCase).ToList();
            if (marques.Count == 0) continue;
            var nd = Titre($"{d}  ({marques.Count})");
            foreach (var g in marques)
            {
                var m = new Marque(g.Key, d, g.Select(x => x.p).ToList());
                var nm = Titre($"{g.Key}  ({m.Produits.Count})", m);
                foreach (var p in m.Produits) nm.Nodes.Add(new TreeNode($"{p.Nom}  —  {p.Secteur.Rayon.Nom} › {p.Secteur.Nom}") { Tag = p });
                nd.Nodes.Add(nm);
            }
            _arbre.Nodes.Add(nd);
        }
    }

    void ArbreRecettes()
    {
        foreach (var (type, sousTypes) in Criteres.Types)
        {
            var dans = _entrepot.Recettes.Where(r => r.Types.Contains(type)).ToList();
            if (dans.Count == 0) continue;
            var nt = Titre($"{type}  ({dans.Count})");
            foreach (var st in sousTypes.Append("Sans sous-type"))
            {
                var liste = dans.Where(r => (r.SousTypes.GetValueOrDefault(type) ?? "Sans sous-type") == st)
                    .OrderBy(r => r.Titre, StringComparer.CurrentCultureIgnoreCase).ToList();
                if (liste.Count == 0) continue;
                var ns = Titre($"{st}  ({liste.Count})");
                foreach (var r in liste) ns.Nodes.Add(new TreeNode(r.Titre) { Tag = r });
                nt.Nodes.Add(ns);
            }
            _arbre.Nodes.Add(nt);
        }
        var sansType = _entrepot.Recettes.Where(r => r.Types.Count == 0).ToList();
        if (sansType.Count > 0)
        {
            var n = Titre($"Sans type  ({sansType.Count})");
            foreach (var r in sansType) n.Nodes.Add(new TreeNode(r.Titre) { Tag = r });
            _arbre.Nodes.Add(n);
        }
    }

    void Plier(bool deplier)
    {
        _arbre.BeginUpdate();
        if (deplier) _arbre.ExpandAll(); else _arbre.CollapseAll();
        _arbre.EndUpdate();
        _arbre.SelectedNode?.EnsureVisible();
        Message(deplier ? "Tout déplié" : "Tout replié");
    }

    // ------------------------------------------------------------ fiche de droite

    void AfficherSelection(TreeNode? n)
    {
        if (_vue == Vue.Recettes)
        {
            _panneauRecette.Afficher(n?.Tag as Recette);
            return;
        }
        _proprietes.BeginUpdate();
        _proprietes.Items.Clear();
        void Ligne(string p, string v) => _proprietes.Items.Add(new ListViewItem(new[] { p, v }));
        switch (n?.Tag)
        {
            case Produit p:
                _titreDroite.Text = p.Nom;
                Ligne("Domaine", p.Secteur.Rayon.Domaine);
                Ligne("Rayon", p.Secteur.Rayon.Nom);
                Ligne("Secteur", p.Secteur.Nom);
                Ligne("Marques", p.Marques.Count == 0 ? "—" : string.Join(", ", p.Marques));
                Ligne("Formats", p.Formats.Count == 0 ? "—" : string.Join(", ", p.Formats));
                break;
            case Secteur s:
                _titreDroite.Text = s.Nom;
                Ligne("Domaine", s.Rayon.Domaine);
                Ligne("Rayon", s.Rayon.Nom);
                Ligne("Produits", s.Produits.Count.ToString());
                break;
            case Rayon r:
                _titreDroite.Text = r.Nom;
                Ligne("Domaine", r.Domaine);
                Ligne("Secteurs", r.Secteurs.Count.ToString());
                Ligne("Produits", r.Secteurs.Sum(s => s.Produits.Count).ToString());
                break;
            case Marque m:
                _titreDroite.Text = m.Nom;
                Ligne("Domaine", m.Domaine);
                Ligne("Produits", m.Produits.Count.ToString());
                foreach (var p in m.Produits) Ligne("", $"{p.Nom}  —  {p.Secteur.Rayon.Nom} › {p.Secteur.Nom}");
                break;
            default:
                _titreDroite.Text = n?.Text ?? "";
                if (n is not null) Ligne("Éléments", n.Nodes.Count.ToString());
                break;
        }
        _proprietes.EndUpdate();
        _proprietes.Columns[1].Width = -2;
    }

    /// <summary>Double-clic ou Entrée sur une recette : la même fiche, dans une fenêtre.</summary>
    void OuvrirEnFenetre(TreeNode? n)
    {
        if (n?.Tag is not Recette r) return;
        if (!QuitterFicheModifiee()) return;
        using var f = new Form
        {
            Text = r.Titre, Font = Font, Icon = Icon, StartPosition = FormStartPosition.CenterParent,
            Size = new Size(Math.Min(1100, Width - 80), Math.Min(800, Height - 80)), MinimizeBox = false, ShowInTaskbar = false,
        };
        var p = NouveauPanneauRecette();
        f.Controls.Add(p);
        p.Afficher(r);
        f.FormClosing += (_, e) =>
        {
            if (!p.Modifiee) return;
            switch (MessageBox.Show(f, "Enregistrer les modifications de la recette ?", Infos.Nom, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question))
            {
                case DialogResult.Yes: if (!p.Enregistrer()) e.Cancel = true; break;
                case DialogResult.Cancel: e.Cancel = true; break;
            }
        };
        f.ShowDialog(this);
        _panneauRecette.Afficher(r);
    }

    void EnregistrerFiche()
    {
        if (_vue == Vue.Recettes && _panneauRecette.Modifiee) _panneauRecette.Enregistrer();
        else Message("Rien à enregistrer");
    }

    /// <summary>Fiche modifiée et non enregistrée : demande Enregistrer, Ne pas enregistrer, Annuler.</summary>
    bool QuitterFicheModifiee()
    {
        if (_panneauRecette?.Modifiee != true) return true;
        switch (MessageBox.Show(this, $"Enregistrer les modifications de « {_panneauRecette.Recette?.Titre} » ?", Infos.Nom, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question))
        {
            case DialogResult.Yes: return _panneauRecette.Enregistrer();
            case DialogResult.No: _panneauRecette.Afficher(_panneauRecette.Recette); return true;
            default: return false;
        }
    }

    void Recharger()
    {
        if (!QuitterFicheModifiee()) return;
        Cursor = Cursors.WaitCursor;
        _entrepot = Entrepot.Charger();
        _droite.Controls.Clear();
        _panneauRecette.Dispose();
        _panneauRecette = NouveauPanneauRecette();
        Cursor = Cursors.Default;
        ChoisirVue(_vue);
        Message(_entrepot.Erreur ?? "Données rechargées");
    }

    // ------------------------------------------------------------ recherche

    static string Simple(string s)
    {
        var d = s.Normalize(NormalizationForm.FormD);
        var b = new StringBuilder(d.Length);
        foreach (var ch in d)
            if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark) b.Append(char.ToLowerInvariant(ch));
        return b.ToString();
    }

    static IEnumerable<TreeNode> Tous(TreeNodeCollection noeuds)
    {
        foreach (TreeNode n in noeuds)
        {
            yield return n;
            foreach (var x in Tous(n.Nodes)) yield return x;
        }
    }

    static TreeNode? Trouver(TreeNodeCollection noeuds, Func<TreeNode, bool> condition) => Tous(noeuds).FirstOrDefault(condition);

    void Chercher(int sens)
    {
        var texte = Simple(_recherche.Text.Trim());
        if (texte.Length < 2) { _recherche.Focus(); return; }
        var tous = Tous(_arbre.Nodes).Where(n => Simple(n.Text).Contains(texte)).ToList();
        if (tous.Count == 0) { Message($"Aucun résultat pour « {_recherche.Text.Trim()} »"); return; }
        var liste = Tous(_arbre.Nodes).ToList();
        var ici = _arbre.SelectedNode is null ? -1 : liste.IndexOf(_arbre.SelectedNode);
        var suivants = sens > 0 ? tous.Where(n => liste.IndexOf(n) > ici).ToList() : tous.Where(n => liste.IndexOf(n) < ici).ToList();
        var cible = sens > 0 ? (suivants.FirstOrDefault() ?? tous[0]) : (suivants.LastOrDefault() ?? tous[^1]);
        cible.EnsureVisible();
        _arbre.SelectedNode = cible;
        Message($"{tous.IndexOf(cible) + 1} / {tous.Count} résultats pour « {_recherche.Text.Trim()} »");
    }
}
