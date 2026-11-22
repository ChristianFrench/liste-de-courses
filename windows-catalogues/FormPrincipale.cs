using System.Text.Json.Nodes;
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
    readonly ToolStrip _outils = new() { ImageScalingSize = new Size(32, 32), GripStyle = ToolStripGripStyle.Hidden, Padding = new Padding(6, 4, 6, 4) };
    readonly Banniere _banniere = new();
    readonly ImageList _images = new() { ImageSize = new Size(24, 24), ColorDepth = ColorDepth.Depth32Bit };
    readonly ContextMenuStrip _menuArbre = new();
    readonly PictureBox _iconeDroite = new() { SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(64, 64), Location = new Point(12, 10) };
    readonly StatusStrip _etat = new();
    readonly SplitContainer _partage = new() { Dock = DockStyle.Fill, FixedPanel = FixedPanel.None };
    readonly TreeView _arbre = new()
    {
        Dock = DockStyle.Fill, HideSelection = false, BorderStyle = BorderStyle.None, ShowLines = false, FullRowSelect = true,
        ItemHeight = 30, Indent = 22, AllowDrop = true, ShowNodeToolTips = true,
    };
    readonly Panel _droite = new() { Dock = DockStyle.Fill, BackColor = SystemColors.Window };
    readonly ListView _proprietes = new() { Dock = DockStyle.Fill, View = View.Details, FullRowSelect = true, HeaderStyle = ColumnHeaderStyle.Nonclickable, BorderStyle = BorderStyle.None };
    readonly Label _titreDroite = new() { AutoSize = true, Location = new Point(88, 16), Font = new Font("Segoe UI", 15f) };
    readonly Label _sousTitreDroite = new() { AutoSize = true, Location = new Point(90, 50), ForeColor = Color.FromArgb(90, 90, 90) };
    readonly Panel _enteteDroite = new() { Dock = DockStyle.Top, Height = 86 };
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

        _proprietes.Columns.Add("Caractéristique", 170);
        _proprietes.Columns.Add("Valeur", 600);
        _enteteDroite.Controls.AddRange([_iconeDroite, _titreDroite, _sousTitreDroite]);
        _panneauProprietes.Controls.Add(_proprietes);
        _panneauProprietes.Controls.Add(_enteteDroite);
        _panneauProprietes.Padding = new Padding(8, 0, 8, 8);
        _panneauRecette = NouveauPanneauRecette();

        _arbre.ImageList = _images;
        _arbre.HandleCreated += (_, _) => Natif.ThemeExplorateur(_arbre.Handle);
        _partage.Panel1.Controls.Add(_arbre);
        _partage.Panel2.Controls.Add(_droite);

        ConstruireMenus();
        ConstruireOutils();
        ConstruireEtat();
        ConstruireMenuArbre();

        var zone = new Panel { Dock = DockStyle.Fill };
        zone.Controls.Add(_partage);
        zone.Controls.Add(_banniere);
        Controls.Add(zone);
        Controls.Add(_outils);
        Controls.Add(_menus);
        Controls.Add(_etat);
        MainMenuStrip = _menus;

        _arbre.BeforeSelect += (_, e) => { if (!QuitterFicheModifiee()) e.Cancel = true; };
        _arbre.AfterSelect += (_, e) => AfficherSelection(e.Node);
        _arbre.NodeMouseDoubleClick += (_, e) => OuvrirEnFenetre(e.Node);
        _arbre.KeyDown += ToucheArbre;
        _arbre.ItemDrag += (_, e) => { if (e.Item is TreeNode n && Deplacable(n)) DoDragDrop(n, DragDropEffects.Move | DragDropEffects.Copy); };
        _arbre.DragOver += SurvolGlisser;
        _arbre.DragDrop += Deposer;
        _arbre.NodeMouseClick += (_, e) => { if (e.Button == MouseButtons.Right) _arbre.SelectedNode = e.Node; };
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
            Item("Co&uper", Icones.Couper, Icones.Gris, Keys.None, (_, _) => Couper(false), "Ctrl+X"),
            Item("&Copier", Icones.Copier, Icones.Gris, Keys.None, (_, _) => Couper(true), "Ctrl+C"),
            Item("C&oller", Icones.Coller, Icones.Gris, Keys.None, (_, _) => Coller(), "Ctrl+V"),
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
        // 22/11/2026 (Aristide : « agrandir la barre d'outils ») : icônes de 32 pixels, libellé dessous.
        ToolStripButton Bouton(char glyphe, Color couleur, string texte, string bulle, EventHandler? clic = null)
        {
            var b = new ToolStripButton(texte, Icones.Glyphe(glyphe, couleur, 32), clic)
            {
                ToolTipText = bulle, DisplayStyle = ToolStripItemDisplayStyle.ImageAndText,
                TextImageRelation = TextImageRelation.ImageAboveText, AutoSize = true, Padding = new Padding(4, 0, 4, 0),
            };
            if (clic is null) { b.Enabled = false; b.ToolTipText = bulle + " : à venir"; }
            return b;
        }
        _outils.Items.AddRange(new ToolStripItem[] {
            Bouton(Icones.Enregistrer, Icones.Bleu, "Enregistrer", "Enregistrer (Ctrl+S)", (_, _) => EnregistrerFiche()),
            Bouton(Icones.Recharger, Icones.Bleu, "Recharger", "Recharger les données (F5)", (_, _) => Recharger()),
            new ToolStripSeparator(),
            Bouton(Icones.Annuler, Icones.Gris, "Annuler", "Annuler (Ctrl+Z)"),
            Bouton(Icones.Retablir, Icones.Gris, "Rétablir", "Rétablir (Ctrl+Y)"),
            new ToolStripSeparator(),
            Bouton(Icones.Couper, Icones.Gris, "Couper", "Couper (Ctrl+X)", (_, _) => Couper(false)),
            Bouton(Icones.Copier, Icones.Gris, "Copier", "Copier (Ctrl+C)", (_, _) => Couper(true)),
            Bouton(Icones.Coller, Icones.Gris, "Coller", "Coller (Ctrl+V)", (_, _) => Coller()),
            new ToolStripSeparator(),
        });
        foreach (var v in Enum.GetValues<Vue>())
        {
            var b = Bouton(GlypheVue(v), Icones.Vert, NomVue(v), $"{TitreVue(v)} (Ctrl+{(int)v + 1})", (_, _) => ChoisirVue(v));
            _boutonsVue[v] = b;
            _outils.Items.Add(b);
        }
        var cherche = new ToolStripButton(null, Icones.Glyphe(Icones.Rechercher, Icones.Bleu, 24), (_, _) => Chercher(1)) { ToolTipText = "Suivant (F3)" };
        _recherche.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) { Chercher(e.Shift ? -1 : 1); e.SuppressKeyPress = true; } };
        _recherche.Font = new Font("Segoe UI", 10f);
        _outils.Items.AddRange(new ToolStripItem[] {
            new ToolStripSeparator(),
            Bouton(Icones.Deplier, Icones.Gris, "Déplier", "Tout déplier (Ctrl+Plus)", (_, _) => Plier(true)),
            Bouton(Icones.Replier, Icones.Gris, "Replier", "Tout replier (Ctrl+Moins)", (_, _) => Plier(false)),
            new ToolStripSeparator(),
            Bouton(Icones.Ajouter, Icones.Vert, "Nouveau", "Nouveau (Ctrl+N)"),
            Bouton(Icones.Renommer, Icones.Gris, "Renommer", "Renommer (F2)"),
            Bouton(Icones.Supprimer, Icones.Rouge, "Supprimer", "Supprimer (Suppr)"),
            new ToolStripSeparator(),
            Bouton(Icones.Controler, Icones.Vert, "Contrôler", "Contrôler le catalogue (F7)"),
            Bouton(Icones.Proposer, Icones.Bleu, "Proposer", "Proposer cette version"),
            new ToolStripSeparator(),
            _recherche,
            cherche,
        });
        var aide = Bouton(Icones.Aide, Icones.Bleu, "Aide", "Aide (F1)", (_, _) => FormTexte.Aide(this));
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
        _panneauRecette.Afficher(null);
        RafraichirArbre();
        MajEtat();
        MajBanniere();
        Message($"{TitreVue(v)} affiché");
    }

    void MajBanniere()
    {
        var c = _entrepot.Catalogue;
        var publie = c.NumeroPublie is int n
            ? $"Version publiée n° {n}{(c.DatePubliee is { Length: >= 10 } d ? $" du {d[8..10]}/{d[5..7]}/{d[..4]}" : "")}"
            : "Aucune version publiée";
        var travail = new List<(string, string, bool)>
        {
            ("En cours", _entrepot.GestesEnCours == 0 ? "rien" : $"{_entrepot.GestesEnCours} geste{(_entrepot.GestesEnCours > 1 ? "s" : "")}", _entrepot.GestesEnCours > 0),
            ("Étapes validées", _entrepot.EtapesNonPubliees == 0 ? "aucune à proposer" : $"{_entrepot.EtapesNonPubliees} à proposer", _entrepot.EtapesNonPubliees > 0),
        };
        switch (_vue)
        {
            case Vue.Produits:
                _banniere.Afficher(Icones.Glyphe(Icones.Produits, Icones.Vert, 44), TitreVue(_vue),
                    $"{publie} · {c.Domaines.Count} domaines · {c.Rayons.Count} rayons · {c.Rayons.Sum(r => r.Secteurs.Count)} secteurs · {c.TousLesProduits.Count()} produits", travail);
                break;
            case Vue.Marques:
                var h = _entrepot.Marques;
                var uniques = h.Familles.SelectMany(f => f.Liste).Select(m => ((string?)m["nom"] ?? "").ToLowerInvariant()).Distinct().Count();
                var aClasser = MarquesAClasser().Count;
                _banniere.Afficher(Icones.Glyphe(Icones.Marques, Icones.Vert, 44), TitreVue(_vue),
                    $"{h.Groupes.Count} groupes · {h.Familles.Count()} familles · {uniques} marques · {c.TousLesProduits.Sum(p => p.Marques.Count)} déclinaisons de produits",
                    new[] { ("À classer", aClasser == 0 ? "aucune" : $"{aClasser} marque{(aClasser > 1 ? "s" : "")}", aClasser > 0) });
                break;
            default:
                var r = _entrepot.Recettes;
                _banniere.Afficher(Icones.Glyphe(Icones.Recettes, Icones.Vert, 44), TitreVue(_vue),
                    $"{(_entrepot.RecettesPubliees is int rp ? $"Version publiée n° {rp}" : "Aucune version publiée")} · {r.Count} recettes · {r.Count(x => x.Illustration is not null)} illustrées",
                    new[] { ("Retouchées", $"{r.Count(x => (bool?)x.Brut["retouchee"] == true)}", false) });
                break;
        }
    }

    // ------------------------------------------------------------ arbre (façon Explorateur)

    /// <summary>Index de l'image <paramref name="cle"/> dans la liste de l'arbre (créée au premier besoin).</summary>
    string Vignette(string cle, Func<Image?> fabrique, char glyphe)
    {
        if (!_images.Images.ContainsKey(cle))
            _images.Images.Add(cle, IconesCatalogue.Carre(fabrique(), 24, Icones.Glyphe(glyphe, Icones.Gris, 24)));
        return cle;
    }

    TreeNode Noeud(string texte, object? tag, string image) =>
        new(texte) { Tag = tag, ImageKey = image, SelectedImageKey = image };

    sealed record Domaine(string Nom);
    sealed record TypeRecette(string Type);
    sealed record SousType(string Type, string? Nom);

    void RafraichirArbre(bool garderSelection = false)
    {
        var avant = garderSelection ? _arbre.SelectedNode?.Tag : null;
        var ouverts = Tous(_arbre.Nodes).Where(n => n.IsExpanded).Select(n => n.FullPath).ToHashSet();
        _arbre.BeginUpdate();
        _arbre.Nodes.Clear();
        switch (_vue)
        {
            case Vue.Produits: ArbreProduits(); break;
            case Vue.Marques: ArbreMarques(); break;
            default: ArbreRecettes(); break;
        }
        if (garderSelection)
            foreach (var n in Tous(_arbre.Nodes).Where(n => ouverts.Contains(n.FullPath)).ToList()) n.Expand();
        _arbre.EndUpdate();
        if (avant is not null && Trouver(_arbre.Nodes, n => Equals(n.Tag, avant)) is { } trouve)
        {
            trouve.EnsureVisible();
            _arbre.SelectedNode = trouve;
        }
        else if (!garderSelection) AfficherSelection(null);
    }

    void ArbreProduits()
    {
        var c = _entrepot.Catalogue;
        foreach (var d in c.Domaines)
        {
            var nd = Noeud(d, new Domaine(d), Vignette("d:" + d, () => IconesCatalogue.Domaine(d), Icones.Produits));
            foreach (var r in c.Rayons.Where(r => r.Domaine == d))
            {
                var nr = Noeud(r.Nom, r, Vignette("r:" + r.Nom, () => IconesCatalogue.Rayon(r.Nom), Icones.Produits));
                foreach (var s in r.Secteurs)
                {
                    var ns = Noeud(s.Nom, s, Vignette($"s:{r.Nom}/{s.Nom}", () => IconesCatalogue.Secteur(r.Nom, s.Nom), Icones.Produits));
                    ns.ToolTipText = $"{s.Produits.Count} produits";
                    var ip = Vignette("produit", () => null, Icones.Produits);
                    foreach (var p in s.Produits) ns.Nodes.Add(Noeud(p.Nom, p, ip));
                    nr.Nodes.Add(ns);
                }
                nd.Nodes.Add(nr);
            }
            _arbre.Nodes.Add(nd);
        }
    }

    sealed record GroupeM(string Nom);

    /// <summary>Produits du catalogue déclinés dans la marque <paramref name="nom"/>.</summary>
    List<Produit> ProduitsDe(string nom) =>
        _entrepot.Catalogue.TousLesProduits.Where(p => p.Marques.Contains(nom, StringComparer.CurrentCultureIgnoreCase)).ToList();

    /// <summary>Marques des produits du catalogue absentes de la hiérarchie des marques.</summary>
    List<string> MarquesAClasser() =>
        _entrepot.Catalogue.TousLesProduits.SelectMany(p => p.Marques).Distinct(StringComparer.CurrentCultureIgnoreCase)
            .Where(m => !_entrepot.Marques.Contient(m)).OrderBy(m => m, StringComparer.CurrentCultureIgnoreCase).ToList();

    void ArbreMarques()
    {
        var im = Vignette("marque", () => Icones.Glyphe(Icones.Marques, Icones.Orange, 24), Icones.Marques);
        var ig = Vignette("groupe-marques", () => Icones.Glyphe(Icones.Produits, Icones.Vert, 24), Icones.Produits);
        var idossier = Vignette("sous-type", () => Icones.Glyphe('\uE8B7', Icones.Orange, 24), '\uE8B7');
        TreeNode NoeudMarque(MarqueH m)
        {
            var produits = ProduitsDe(m.Nom);
            var nm = Noeud(m.Nom, m, im);
            nm.ToolTipText = $"{produits.Count} produit{(produits.Count > 1 ? "s" : "")}{(m.Source.Length > 0 ? " · " + m.Source : "")}";
            foreach (var p in produits)
                nm.Nodes.Add(Noeud($"{p.Nom}  —  {p.Secteur.Rayon.Nom} › {p.Secteur.Nom}", p,
                    Vignette($"s:{p.Secteur.Rayon.Nom}/{p.Secteur.Nom}", () => IconesCatalogue.Secteur(p.Secteur.Rayon.Nom, p.Secteur.Nom), Icones.Produits)));
            return nm;
        }
        foreach (var g in _entrepot.Marques.Groupes)
        {
            var ng = Noeud(g.Nom, new GroupeM(g.Nom), ig);
            ng.ToolTipText = $"{g.Familles.Count} familles";
            foreach (var f in g.Familles)
            {
                var nf = Noeud(f.Nom, f, idossier);
                nf.ToolTipText = $"{f.Marques.Count} marques";
                foreach (var m in f.Liste.OrderBy(x => (string?)x["nom"], StringComparer.CurrentCultureIgnoreCase))
                    nf.Nodes.Add(NoeudMarque(new MarqueH(m, f)));
                ng.Nodes.Add(nf);
            }
            _arbre.Nodes.Add(ng);
        }
        var reste = MarquesAClasser();
        if (reste.Count > 0)
        {
            var fa = new FamilleMarques { Nom = "Marques à classer", Groupe = "", AClasser = true };
            foreach (var m in reste) fa.Marques.Add(new JsonObject { ["nom"] = m });
            var na = Noeud($"Marques à classer ({reste.Count})", fa, Vignette("a-classer", () => Icones.Glyphe(Icones.Controler, Icones.Rouge, 24), Icones.Controler));
            na.ToolTipText = "Marques des produits du catalogue absentes de la hiérarchie : les glisser dans leur famille";
            foreach (var m in fa.Liste) na.Nodes.Add(NoeudMarque(new MarqueH(m, fa)));
            _arbre.Nodes.Add(na);
        }
    }

    void ArbreRecettes()
    {
        var idossier = Vignette("sous-type", () => Icones.Glyphe('', Icones.Orange, 24), '');
        var irecette = Vignette("recette", () => Icones.Glyphe(Icones.Recettes, Icones.Vert, 24), Icones.Recettes);
        foreach (var (type, sousTypes) in Criteres.Types)
        {
            var dans = _entrepot.Recettes.Where(r => r.Types.Contains(type)).ToList();
            var nt = Noeud(type, new TypeRecette(type), Vignette("t:" + type, () => IconesCatalogue.TypeRecette(type), Icones.Recettes));
            nt.ToolTipText = $"{dans.Count} recettes";
            foreach (var st in sousTypes.Cast<string?>().Append(null))
            {
                var liste = dans.Where(r => r.SousTypes.GetValueOrDefault(type) == st)
                    .OrderBy(r => r.Titre, StringComparer.CurrentCultureIgnoreCase).ToList();
                if (liste.Count == 0 && st is null) continue;
                var ns = Noeud(st ?? "Sans sous-type", new SousType(type, st),
                    st is null ? idossier : Vignette($"st:{type}/{st}", () => IconesCatalogue.SousTypeRecette(type, st), '\uE8B7'));
                ns.ToolTipText = $"{liste.Count} recettes";
                foreach (var r in liste) ns.Nodes.Add(Noeud(r.Titre, r, irecette));
                nt.Nodes.Add(ns);
            }
            _arbre.Nodes.Add(nt);
        }
        var sansType = _entrepot.Recettes.Where(r => r.Types.Count == 0).ToList();
        if (sansType.Count > 0)
        {
            var n = Noeud("Sans type", null, idossier);
            foreach (var r in sansType) n.Nodes.Add(Noeud(r.Titre, r, irecette));
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
        _droite.SuspendLayout();
        _droite.Controls.Clear();
        if (n is null) { _droite.ResumeLayout(); return; }
        if (_vue == Vue.Recettes)
        {
            if (n.Tag is Recette r)
            {
                _droite.Controls.Add(_panneauRecette);
                _panneauRecette.Afficher(r);
            }
            else
            {
                AfficherProprietes(n);
                _droite.Controls.Add(_panneauProprietes);
            }
            _droite.ResumeLayout();
            return;
        }
        AfficherProprietes(n);
        _droite.Controls.Add(_panneauProprietes);
        _droite.ResumeLayout();
    }

    void AfficherProprietes(TreeNode n)
    {
        _proprietes.BeginUpdate();
        _proprietes.Items.Clear();
        void Ligne(string p, string v) => _proprietes.Items.Add(new ListViewItem(new[] { p, v }));
        Image? icone = null;
        string sous = "";
        switch (n.Tag)
        {
            case Produit p:
                icone = IconesCatalogue.Secteur(p.Secteur.Rayon.Nom, p.Secteur.Nom);
                sous = "Produit";
                Ligne("Domaine", p.Secteur.Rayon.Domaine);
                Ligne("Rayon", p.Secteur.Rayon.Nom);
                Ligne("Secteur", p.Secteur.Nom);
                Ligne("Marques", p.Marques.Count == 0 ? "—" : string.Join(", ", p.Marques));
                Ligne("Formats de vente", p.Formats.Count == 0 ? "—" : string.Join(", ", p.Formats));
                break;
            case Secteur s:
                icone = IconesCatalogue.Secteur(s.Rayon.Nom, s.Nom);
                sous = "Secteur";
                Ligne("Domaine", s.Rayon.Domaine);
                Ligne("Rayon", s.Rayon.Nom);
                Ligne("Produits", s.Produits.Count.ToString());
                Ligne("Produits avec marques", s.Produits.Count(x => x.Marques.Count > 0).ToString());
                Ligne("Formats proposés", Catalogue.Textes(s.Json["formats"]) is { Count: > 0 } f ? string.Join(", ", f) : "—");
                break;
            case Rayon r:
                icone = IconesCatalogue.Rayon(r.Nom);
                sous = "Rayon";
                Ligne("Domaine", r.Domaine);
                Ligne("Secteurs", r.Secteurs.Count.ToString());
                Ligne("Produits", r.Secteurs.Sum(s => s.Produits.Count).ToString());
                break;
            case Domaine d:
                icone = IconesCatalogue.Domaine(d.Nom);
                sous = "Domaine";
                var rayons = _entrepot.Catalogue.Rayons.Where(r => r.Domaine == d.Nom).ToList();
                Ligne("Rayons", rayons.Count.ToString());
                Ligne("Secteurs", rayons.Sum(r => r.Secteurs.Count).ToString());
                Ligne("Produits", rayons.Sum(r => r.Secteurs.Sum(s => s.Produits.Count)).ToString());
                break;
            case MarqueH m:
                icone = Icones.Glyphe(Icones.Marques, Icones.Orange, 64);
                sous = m.Famille.AClasser ? "Marque à classer" : $"Marque · {m.Famille.Groupe} › {m.Famille.Nom}";
                var autres = _entrepot.Marques.Familles.Where(x0 => x0 != m.Famille && x0.Liste.Any(x => string.Equals((string?)x["nom"], m.Nom, StringComparison.CurrentCultureIgnoreCase))).ToList();
                if (autres.Count > 0) Ligne("Aussi dans", string.Join(" ; ", autres.Select(x1 => $"{x1.Groupe} › {x1.Nom}")));
                Ligne("Origine", m.Source switch
                {
                    "catalogue_initial" => "Catalogue initial", "ajout_catalogue" => "Ajout au catalogue", "ajout_mdd" => "Marque de distributeur",
                    "catalogue_produits" => "Reprise des produits", "" => "—", var s => s,
                });
                var pm = ProduitsDe(m.Nom);
                Ligne("Produits", pm.Count.ToString());
                foreach (var p in pm) Ligne("", $"{p.Nom}  —  {p.Secteur.Rayon.Nom} › {p.Secteur.Nom}");
                break;
            case FamilleMarques fam:
                icone = Icones.Glyphe('\uE8B7', Icones.Orange, 64);
                sous = fam.AClasser ? "Marques des produits absentes de la hiérarchie" : $"Famille de produits · {fam.Groupe}";
                Ligne("Marques", fam.Marques.Count.ToString());
                Ligne("Marques avec produits", fam.Liste.Count(x => ProduitsDe((string?)x["nom"] ?? "").Count > 0).ToString());
                break;
            case GroupeM g:
                icone = Icones.Glyphe(Icones.Produits, Icones.Vert, 64);
                sous = "Groupe de marques";
                var gr = _entrepot.Marques.Groupes.First(x => x.Nom == g.Nom);
                Ligne("Familles", gr.Familles.Count.ToString());
                foreach (var fg in gr.Familles) Ligne(fg.Nom, $"{fg.Marques.Count} marques");
                break;
            case TypeRecette t:
                icone = IconesCatalogue.TypeRecette(t.Type);
                sous = "Type de recettes";
                var dans = _entrepot.Recettes.Where(r => r.Types.Contains(t.Type)).ToList();
                Ligne("Recettes", dans.Count.ToString());
                foreach (var st in Criteres.Types.First(x => x.Type == t.Type).SousTypes)
                    Ligne(st, dans.Count(r => r.SousTypes.GetValueOrDefault(t.Type) == st).ToString());
                break;
            case SousType st:
                icone = IconesCatalogue.SousTypeRecette(st.Type, st.Nom);
                sous = $"Sous-type de {st.Type}";
                Ligne("Recettes", _entrepot.Recettes.Count(r => r.Types.Contains(st.Type) && r.SousTypes.GetValueOrDefault(st.Type) == st.Nom).ToString());
                break;
            default:
                Ligne("Éléments", n.Nodes.Count.ToString());
                break;
        }
        _iconeDroite.Image = icone ?? Icones.Glyphe(GlypheVue(_vue), Icones.Vert, 64);
        _titreDroite.Text = n.Tag is MarqueH mm ? mm.Nom : n.Tag is FamilleMarques fm ? fm.Nom : n.Text;
        _sousTitreDroite.Text = sous;
        _proprietes.EndUpdate();
        _proprietes.Columns[1].Width = -2;
    }

    // ------------------------------------------------------------ couper, copier, coller, glisser-déposer

    TreeNode? _presse;
    bool _presseCopie;

    static bool Deplacable(TreeNode n) => n.Tag is MarqueH || (n.Tag is Produit or Secteur or Rayon or Recette && n.Parent?.Tag is not MarqueH);

    void ConstruireMenuArbre()
    {
        var couper = new ToolStripMenuItem("Co&uper", Icones.Glyphe(Icones.Couper, Icones.Gris, 16), (_, _) => Couper(false)) { ShortcutKeyDisplayString = "Ctrl+X" };
        var copier = new ToolStripMenuItem("&Copier", Icones.Glyphe(Icones.Copier, Icones.Gris, 16), (_, _) => Couper(true)) { ShortcutKeyDisplayString = "Ctrl+C" };
        var coller = new ToolStripMenuItem("C&oller", Icones.Glyphe(Icones.Coller, Icones.Gris, 16), (_, _) => Coller()) { ShortcutKeyDisplayString = "Ctrl+V" };
        var ouvrir = new ToolStripMenuItem("&Ouvrir dans une fenêtre", null, (_, _) => OuvrirEnFenetre(_arbre.SelectedNode)) { ShortcutKeyDisplayString = "Entrée" };
        _menuArbre.Items.AddRange(new ToolStripItem[] { couper, copier, coller, new ToolStripSeparator(), ouvrir });
        _menuArbre.Opening += (_, e) =>
        {
            var n = _arbre.SelectedNode;
            if (n is null) { e.Cancel = true; return; }
            couper.Enabled = n.Tag is not null && Deplacable(n);
            copier.Enabled = n.Tag is Produit or Recette or MarqueH && Deplacable(n);
            coller.Enabled = _presse is not null && Cible(_presse, n, _presseCopie) is not null;
            ouvrir.Visible = n.Tag is Recette;
        };
        _arbre.ContextMenuStrip = _menuArbre;
    }

    void ToucheArbre(object? sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter) { OuvrirEnFenetre(_arbre.SelectedNode); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.X) { Couper(false); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.C) { Couper(true); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.V) { Coller(); e.Handled = true; }
    }

    void Couper(bool copie)
    {
        var n = _arbre.SelectedNode;
        if (n is null || !Deplacable(n) || (copie && n.Tag is not (Produit or Recette or MarqueH))) { Message(copie ? "Seuls un produit, une marque ou une recette se copient" : "Cet élément ne se déplace pas"); return; }
        _presse = n;
        _presseCopie = copie;
        Message($"« {n.Text} » {(copie ? "copié" : "coupé")} : choisir où le coller (Ctrl+V)");
    }

    void Coller()
    {
        if (_presse is null || _arbre.SelectedNode is null) { Message("Rien à coller"); return; }
        if (Executer(_presse, _arbre.SelectedNode, _presseCopie) && !_presseCopie) _presse = null;
    }

    void SurvolGlisser(object? sender, DragEventArgs e)
    {
        var source = e.Data?.GetData(typeof(TreeNode)) as TreeNode;
        var ici = _arbre.GetNodeAt(_arbre.PointToClient(new Point(e.X, e.Y)));
        var copie = (e.KeyState & 8) != 0; // Ctrl : copier
        if (source is null || ici is null || Cible(source, ici, copie) is null) { e.Effect = DragDropEffects.None; return; }
        e.Effect = copie ? DragDropEffects.Copy : DragDropEffects.Move;
        if (!ici.IsExpanded && ici.Nodes.Count > 0 && ici.Tag is not (Produit or Recette)) ici.Expand();
    }

    void Deposer(object? sender, DragEventArgs e)
    {
        var source = e.Data?.GetData(typeof(TreeNode)) as TreeNode;
        var ici = _arbre.GetNodeAt(_arbre.PointToClient(new Point(e.X, e.Y)));
        if (source is not null && ici is not null) Executer(source, ici, (e.KeyState & 8) != 0);
    }

    /// <summary>Où va <paramref name="source"/> déposé sur <paramref name="ici"/> : (parent, avant), ou null si refusé.</summary>
    static (object Parent, object? Avant)? Cible(TreeNode source, TreeNode ici, bool copie)
    {
        if (ReferenceEquals(source, ici)) return null;
        switch (source.Tag)
        {
            case Produit when ici.Tag is Secteur s: return (s, null);
            case Produit when ici.Tag is Produit p && ici.Parent?.Tag is Secteur: return (p.Secteur, p);
            case Secteur when copie: return null;
            case Secteur when ici.Tag is Rayon r: return (r, null);
            case Secteur when ici.Tag is Secteur s2: return (s2.Rayon, s2);
            case Rayon when copie: return null;
            case Rayon when ici.Tag is Domaine d: return (d, null);
            case Rayon when ici.Tag is Rayon r2: return (new Domaine(r2.Domaine), r2);
            case MarqueH when ici.Tag is FamilleMarques f && !f.AClasser: return (f, null);
            case MarqueH when ici.Tag is MarqueH m2 && !m2.Famille.AClasser: return (m2.Famille, m2);
            case Recette when ici.Tag is SousType st: return (st, null);
            case Recette when ici.Tag is TypeRecette t: return (new SousType(t.Type, null), null);
            case Recette when ici.Tag is Recette && ici.Parent?.Tag is SousType st2: return (st2, null);
        }
        return null;
    }

    bool Executer(TreeNode source, TreeNode ici, bool copie)
    {
        if (Cible(source, ici, copie) is not var (parent, avant)) { Message("Déplacement impossible ici"); return false; }
        if (_vue == Vue.Recettes && _panneauRecette.Modifiee && !QuitterFicheModifiee()) return false;
        try
        {
            if (source.Tag is Recette r)
            {
                var st = (SousType)parent;
                var de = (source.Parent?.Tag as SousType)?.Type;
                if (copie || de is null) { if (!r.Types.Contains(st.Type)) r.Types.Add(st.Type); }
                else if (de != st.Type) { r.Types[r.Types.IndexOf(de)] = st.Type; r.SousTypes.Remove(de); }
                r.Types = r.Types.Distinct().OrderBy(Criteres.RangType).ToList();
                if (st.Nom is null) r.SousTypes.Remove(st.Type); else r.SousTypes[st.Type] = st.Nom;
                r.Ecrire();
                _entrepot.EnregistrerRecettes();
                Message(copie ? $"« {r.Titre} » ajoutée à {st.Type}" : $"« {r.Titre} » rangée dans {st.Type} › {st.Nom ?? "Sans sous-type"}");
                RafraichirArbre(garderSelection: true);
                return true;
            }
            if (source.Tag is MarqueH mh)
            {
                var ligne = _entrepot.Marques.Deplacer(mh, (FamilleMarques)parent, avant as MarqueH, copie);
                _entrepot.EnregistrerMarques();
                Message(ligne);
                RafraichirArbre(garderSelection: true);
                MajBanniere();
                return true;
            }
            var c = _entrepot.Catalogue;
            var geste = source.Tag switch
            {
                Produit p => c.DeplacerProduit(p, (Secteur)parent, avant as Produit, copie),
                Secteur s => c.DeplacerSecteur(s, (Rayon)parent, avant as Secteur),
                Rayon ra => c.DeplacerRayon(ra, ((Domaine)parent).Nom, avant as Rayon),
                _ => null,
            };
            if (geste is null) return false;
            _entrepot.EnregistrerCatalogue(geste);
            Message(geste);
            RafraichirArbre(garderSelection: true);
            MajBanniere();
            MajEtat();
            return true;
        }
        catch (Exception x)
        {
            MessageBox.Show(this, x.Message, Infos.Nom, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            Recharger();
            return false;
        }
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

/// <summary>Apparence de l'Explorateur de fichiers pour l'arbre (survol, sélection, chevrons).</summary>
static class Natif
{
    [System.Runtime.InteropServices.DllImport("uxtheme.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    static extern int SetWindowTheme(IntPtr h, string app, string? id);

    public static void ThemeExplorateur(IntPtr h) => SetWindowTheme(h, "Explorer", null);
}
