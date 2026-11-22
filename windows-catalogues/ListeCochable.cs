namespace EmplettesCatalogues;

/// <summary>
/// Liste déroulante à cases à cocher (plusieurs valeurs) : l'aspect d'une liste déroulante Windows ; un clic ouvre la
/// liste des valeurs, chacune cochable, et le texte affiche les valeurs cochées séparées par des virgules.
/// </summary>
sealed class ListeCochable : ComboBox
{
    readonly ToolStripDropDown _volet = new() { AutoClose = true, Padding = Padding.Empty };
    readonly CheckedListBox _liste = new() { CheckOnClick = true, BorderStyle = BorderStyle.None, IntegralHeight = false };
    bool _ouvert;

    public event EventHandler? CochesChangees;

    public ListeCochable(IEnumerable<string> valeurs)
    {
        DropDownStyle = ComboBoxStyle.DropDownList;
        DropDownHeight = 1;
        foreach (var v in valeurs) _liste.Items.Add(v);
        var hote = new ToolStripControlHost(_liste) { Padding = Padding.Empty, Margin = Padding.Empty, AutoSize = false };
        _volet.Items.Add(hote);
        _volet.Closed += (_, _) => { _ouvert = false; };
        _liste.ItemCheck += (_, _) => BeginInvoke(() => { MajTexte(); CochesChangees?.Invoke(this, EventArgs.Empty); });
        Items.Add("");
        SelectedIndex = 0;
    }

    public List<string> Coches
    {
        get => _liste.CheckedItems.Cast<string>().ToList();
        set
        {
            for (var i = 0; i < _liste.Items.Count; i++) _liste.SetItemChecked(i, value.Contains((string)_liste.Items[i]));
            MajTexte();
        }
    }

    void MajTexte()
    {
        Items[0] = Coches.Count == 0 ? "—" : string.Join(", ", Coches);
        SelectedIndex = 0;
    }

    protected override void OnDropDown(EventArgs e)
    {
        base.OnDropDown(e);
        BeginInvoke(() =>
        {
            DroppedDown = false;
            if (_ouvert) return;
            _ouvert = true;
            var hauteur = Math.Min(_liste.Items.Count, 12) * (_liste.ItemHeight + 2) + 6;
            _liste.Size = new Size(Math.Max(Width, 200), hauteur);
            ((ToolStripControlHost)_volet.Items[0]).Size = _liste.Size;
            _volet.Show(this, new Point(0, Height));
            _liste.Focus();
        });
    }
}
