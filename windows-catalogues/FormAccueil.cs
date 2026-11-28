namespace EmplettesCatalogues;

/// <summary>Écran d'accueil (splash) : nom, version, pendant le chargement.</summary>
sealed class FormAccueil : Form
{
    public FormAccueil()
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterScreen;
        ShowInTaskbar = false;
        BackColor = Color.White;
        Size = new Size(460, 260);
        Padding = new Padding(1);
        Paint += (_, e) => e.Graphics.DrawRectangle(SystemPens.ControlDark, 0, 0, Width - 1, Height - 1);

        var icone = new PictureBox
        {
            Image = Icon.ExtractAssociatedIcon(Application.ExecutablePath)?.ToBitmap(),
            SizeMode = PictureBoxSizeMode.Zoom,
            Bounds = new Rectangle(36, 50, 72, 72),
        };
        var nom = new Label { Text = "Emplettes", Font = new Font("Segoe UI", 24f, FontStyle.Bold), AutoSize = true, Location = new Point(124, 46), ForeColor = Icones.Vert };
        var sous = new Label { Text = "Gestion des catalogues", Font = new Font("Segoe UI", 12f), AutoSize = true, Location = new Point(128, 94), ForeColor = Color.DimGray };
        var barre = new ProgressBar { Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 25, Bounds = new Rectangle(36, 160, 388, 10) };
        var version = new Label { Text = $"Version {Infos.Version} · chargement des catalogues…", AutoSize = true, Location = new Point(36, 186), ForeColor = Color.DimGray };
        Controls.AddRange([icone, nom, sous, barre, version]);
    }
}
