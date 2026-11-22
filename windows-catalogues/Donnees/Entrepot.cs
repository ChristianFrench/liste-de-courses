using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Data.Sqlite;

namespace EmplettesCatalogues.Donnees;

/// <summary>
/// Les données : pour cette première version, celles de la console sur ce PC (dossier « editeur » des données
/// d'Emplettes : base liste_de_courses.db pour le brouillon du catalogue, recettes/recettes.json pour les recettes).
/// Elles iront sur le serveur à l'étape 3.
/// </summary>
sealed class Entrepot
{
    public string? Dossier;
    public Catalogue Catalogue = new();
    public List<Recette> Recettes = new();
    public string? Erreur;
    JsonObject? _racineRecettes;

    public string? FichierRecettes => Dossier is null ? null : Path.Combine(Dossier, "recettes", "recettes.json");

    public string? CheminImage(string? nom) =>
        Dossier is null || string.IsNullOrEmpty(nom) ? null : Path.Combine(Dossier, "recettes", nom);

    /// <summary>Le dossier « editeur » le plus récent sous %APPDATA% (le nom de l'éditeur varie selon la compilation).</summary>
    static string? TrouverDossier()
    {
        var appdata = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (!Directory.Exists(appdata)) return null;
        var candidats = new List<string>();
        foreach (var editeur in Directory.EnumerateDirectories(appdata))
        {
            try
            {
                foreach (var produit in Directory.EnumerateDirectories(editeur))
                {
                    var d = Path.Combine(produit, "editeur");
                    if (Directory.Exists(d) && (File.Exists(Path.Combine(d, "liste_de_courses.db")) || Directory.Exists(Path.Combine(d, "recettes"))))
                        candidats.Add(d);
                }
            }
            catch (UnauthorizedAccessException) { }
        }
        return candidats.OrderByDescending(Directory.GetLastWriteTimeUtc).FirstOrDefault();
    }

    public static Entrepot Charger()
    {
        var e = new Entrepot();
        try
        {
            e.Dossier = TrouverDossier();
            if (e.Dossier is null)
            {
                e.Erreur = "Données de la console introuvables sur ce PC (ouvrir une fois la console Emplettes).";
                return e;
            }
            e.ChargerCatalogue();
            e.ChargerRecettes();
        }
        catch (Exception x)
        {
            e.Erreur = x.Message;
        }
        return e;
    }

    void ChargerCatalogue()
    {
        var db = Path.Combine(Dossier!, "liste_de_courses.db");
        if (!File.Exists(db)) return;
        using var c = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = db, Mode = SqliteOpenMode.ReadOnly, Pooling = false }.ToString());
        c.Open();
        string? Reglage(string cle)
        {
            using var cmd = c.CreateCommand();
            cmd.CommandText = "SELECT valeur FROM parametre WHERE cle = $c";
            cmd.Parameters.AddWithValue("$c", cle);
            return cmd.ExecuteScalar() as string;
        }
        var brouillon = Reglage("catalogue_brouillon");
        if (brouillon is not null)
        {
            Catalogue = Catalogue.Lire(JsonNode.Parse(brouillon), "brouillon en cours");
            return;
        }
        var publie = Reglage("catalogue_commun");
        if (publie is not null) Catalogue = Catalogue.Lire(JsonNode.Parse(publie), "dernier catalogue publié");
    }

    void ChargerRecettes()
    {
        var f = FichierRecettes!;
        if (!File.Exists(f)) return;
        _racineRecettes = JsonNode.Parse(File.ReadAllText(f))?.AsObject();
        foreach (var r in _racineRecettes?["recettes"]?.AsArray() ?? new JsonArray())
            if (r is JsonObject o) Recettes.Add(Recette.Lire(o));
    }

    static readonly JsonSerializerOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// Enregistre les recettes (une copie de sécurité recettes.json.bak est faite avant). Les objets JSON des recettes
    /// sont ceux du fichier : les champs que ce logiciel ne connaît pas sont gardés.
    /// </summary>
    public void EnregistrerRecettes()
    {
        var f = FichierRecettes ?? throw new InvalidOperationException("Pas de dossier de données.");
        _racineRecettes ??= new JsonObject();
        var liste = new JsonArray();
        foreach (var r in Recettes)
        {
            r.Brut.Parent?.AsArray().Remove(r.Brut);
            liste.Add(r.Brut);
        }
        _racineRecettes["recettes"] = liste;
        Directory.CreateDirectory(Path.GetDirectoryName(f)!);
        if (File.Exists(f)) File.Copy(f, f + ".bak", overwrite: true);
        var temp = f + ".tmp";
        File.WriteAllText(temp, _racineRecettes.ToJsonString(Options));
        File.Move(temp, f, overwrite: true);
    }
}
