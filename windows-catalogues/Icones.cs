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

/// <summary>
/// Les icônes des catalogues (celles de l'application : icônes « maison » d'Aristide, puis Noto 3D, puis les images
/// de réserve), livrées avec le logiciel dans le dossier « icones ». Même clé que l'application : nom simplifié du
/// domaine (« univers-… »), du rayon, ou « rayon--secteur ».
/// </summary>
static class IconesCatalogue
{
    static readonly string Dossier = Path.Combine(AppContext.BaseDirectory, "icones");
    static readonly Dictionary<string, Image?> Cache = new();

    static readonly Dictionary<string, string> Alias = new()
    {
        ["frais"] = "cremerie", ["epicerie"] = "epicerie-salee", ["boissons"] = "eaux-et-boissons-sans-alcool",
        ["liquides"] = "eaux-et-boissons-sans-alcool", ["droguerie"] = "entretien-droguerie", ["entretien"] = "entretien-droguerie",
    };

    public static string Simple(string s)
    {
        var b = new System.Text.StringBuilder();
        foreach (var c in s.ToLowerInvariant())
        {
            b.Append(c switch
            {
                'à' or 'â' or 'ä' => "a", 'ç' => "c", 'é' or 'è' or 'ê' or 'ë' => "e", 'î' or 'ï' => "i", 'ô' or 'ö' => "o",
                'ù' or 'û' or 'ü' => "u", 'ÿ' => "y", 'œ' => "oe", 'æ' => "ae", _ => c.ToString(),
            });
        }
        return System.Text.RegularExpressions.Regex.Replace(b.ToString(), "[^a-z0-9]+", "-").Trim('-');
    }

    static Image? Fichier(string cle)
    {
        if (Cache.TryGetValue(cle, out var i)) return i;
        i = null;
        foreach (var sous in new[] { "maison", "noto3d", "png" })
        {
            var f = Path.Combine(Dossier, sous, cle + ".png");
            if (!File.Exists(f)) continue;
            try
            {
                using var flux = File.OpenRead(f);
                using var img = Image.FromStream(flux);
                i = new Bitmap(img);
            }
            catch (Exception) { i = null; }
            break;
        }
        Cache[cle] = i;
        return i;
    }

    static string CleRayon(string rayon) { var s = Simple(rayon); return Alias.GetValueOrDefault(s, s); }

    public static Image? Domaine(string domaine) => Fichier("univers-" + Simple(domaine));
    public static Image? Rayon(string rayon) => Fichier(CleRayon(rayon));
    public static Image? Secteur(string rayon, string secteur) => Fichier($"{CleRayon(rayon)}--{Simple(secteur)}") ?? Rayon(rayon);

    /// <summary>Image d'un type de recette (les mêmes que la console).</summary>
    public static Image? TypeRecette(string type)
    {
        var t = type.ToLowerInvariant();
        var nom = t.StartsWith("dessert") || t.StartsWith("petit") ? "desserts"
            : t.StartsWith("entr") || t.StartsWith("ap") ? "entrees"
            : t.Contains("accompagnement") ? "plats-accompagnement"
            : t.StartsWith("plat") ? "plats-complets"
            : t.StartsWith("sauce") ? "sauces" : "recettes-de-cuisine";
        return Fichier("../recettes/" + nom);
    }

    /// <summary>Copie carrée de l'image à la taille voulue (pour les listes d'images de l'arbre).</summary>
    public static Bitmap Carre(Image? image, int taille, Bitmap? defaut = null)
    {
        var b = new Bitmap(taille, taille);
        using var g = Graphics.FromImage(b);
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
        var src = image ?? defaut;
        if (src is not null) g.DrawImage(src, new Rectangle(0, 0, taille, taille));
        return b;
    }
}
