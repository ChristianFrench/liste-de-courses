namespace EmplettesCatalogues;

/// <summary>
/// Bannière en haut de la zone de travail (comme le bandeau de la console) : icône et titre du catalogue, ligne des
/// chiffres, et à droite les pastilles du travail en cours.
/// </summary>
sealed class Banniere : Panel
{
    readonly PictureBox _icone = new() { SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(44, 44), Location = new Point(14, 12) };
    readonly Label _titre = new() { AutoSize = true, Location = new Point(68, 10), Font = new Font("Segoe UI", 15f) };
    readonly Label _chiffres = new() { AutoSize = true, Location = new Point(70, 42), ForeColor = Color.FromArgb(90, 90, 90) };
    readonly FlowLayoutPanel _pastilles = new() { Dock = DockStyle.Right, AutoSize = true, FlowDirection = FlowDirection.RightToLeft, WrapContents = false, Padding = new Padding(0, 14, 10, 0) };

    public Banniere()
    {
        Dock = DockStyle.Top;
        Height = 68;
        BackColor = Color.FromArgb(238, 244, 240);
        Controls.AddRange([_pastilles, _icone, _titre, _chiffres]);
        Paint += (_, e) => e.Graphics.DrawLine(SystemPens.ControlLight, 0, Height - 1, Width, Height - 1);
    }

    public void Afficher(Image? icone, string titre, string chiffres, IEnumerable<(string Libelle, string Valeur, bool Fort)> pastilles)
    {
        _icone.Image = icone;
        _titre.Text = titre;
        _chiffres.Text = chiffres;
        _pastilles.SuspendLayout();
        _pastilles.Controls.Clear();
        foreach (var (libelle, valeur, fort) in pastilles.Reverse())
        {
            var p = new Label
            {
                AutoSize = true, Padding = new Padding(10, 5, 10, 5), Margin = new Padding(6, 0, 0, 0),
                Text = $"{libelle}\n{valeur}", BackColor = fort ? Color.FromArgb(214, 234, 221) : Color.White,
                BorderStyle = BorderStyle.FixedSingle,
            };
            _pastilles.Controls.Add(p);
        }
        _pastilles.ResumeLayout();
    }
}
