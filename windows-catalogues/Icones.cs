using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace EmplettesCatalogues;

/// <summary>
/// Icônes de la barre d'outils et des menus : glyphes de la police d'icônes de Windows (Segoe Fluent Icons sous
/// Windows 11, Segoe MDL2 Assets sous Windows 10), dessinés en couleur, comme dans les applications Windows.
/// </summary>
static class Icones
{
    static readonly string Police = new InstalledFontCollection().Families.Any(f => f.Name == "Segoe Fluent Icons")
        ? "Segoe Fluent Icons" : "Segoe MDL2 Assets";

    // Couleurs de la charte (proches de l'exemple d'Aristide : orange, rouge, bleu, gris).
    public static readonly Color Orange = Color.FromArgb(232, 140, 30);
    public static readonly Color Rouge = Color.FromArgb(200, 50, 50);
    public static readonly Color Bleu = Color.FromArgb(0, 103, 192);
    public static readonly Color Vert = Color.FromArgb(63, 125, 90);
    public static readonly Color Gris = Color.FromArgb(90, 90, 90);

    // Codes des glyphes (communs aux deux polices).
    public const char Enregistrer = '', Recharger = '', Importer = '', Exporter = '',
        Annuler = '', Retablir = '', Couper = '', Copier = '', Coller = '',
        Renommer = '', Supprimer = '', Rechercher = '', Deplier = '', Replier = '',
        Ajouter = '', Image = '', Controler = '', Valider = '', Historique = '',
        Proposer = '', Aide = '', Produits = '', Marques = '', Recettes = '',
        Reglages = '', Monter = '', Descendre = '', Inserer = '', Clavier = '',
        Info = '', Quitter = '';

    static readonly Dictionary<(char, int, int), Bitmap> Cache = new();

    /// <summary>Le glyphe <paramref name="c"/> en couleur, carré de <paramref name="taille"/> pixels.</summary>
    public static Bitmap Glyphe(char c, Color couleur, int taille = 20)
    {
        var cle = (c, couleur.ToArgb(), taille);
        if (Cache.TryGetValue(cle, out var b)) return b;
        b = new Bitmap(taille, taille);
        using (var g = Graphics.FromImage(b))
        using (var f = new Font(Police, taille * 0.62f, GraphicsUnit.Pixel))
        using (var pinceau = new SolidBrush(couleur))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            g.DrawString(c.ToString(), f, pinceau, new RectangleF(0, 0, taille, taille), format);
        }
        Cache[cle] = b;
        return b;
    }
}
