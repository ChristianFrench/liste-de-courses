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
    public MarquesParSecteur Marques = new();
    public string? FichierMarques => Dossier is null ? null : Path.Combine(Dossier, "marques", "secteurs.json");

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
            e.ChargerMarques();
        }
        catch (Exception x)
        {
            e.Erreur = x.Message;
        }
        return e;
    }

    public string? FichierBase => Dossier is null ? null : Path.Combine(Dossier, "liste_de_courses.db");

    /// <summary>Gestes en cours (non validés) et étapes validées non publiées, d'après le journal de la console.</summary>
    public int GestesEnCours, EtapesNonPubliees;
    public int? RecettesPubliees;
    bool _baseSauvee;

    SqliteConnection Connexion(bool ecriture)
    {
        var c = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = FichierBase!, Mode = ecriture ? SqliteOpenMode.ReadWrite : SqliteOpenMode.ReadOnly, Pooling = false, DefaultTimeout = 10,
        }.ToString());
        c.Open();
        return c;
    }

    static string? Reglage(SqliteConnection c, string cle)
    {
        using var cmd = c.CreateCommand();
        cmd.CommandText = "SELECT valeur FROM parametre WHERE cle = $c";
        cmd.Parameters.AddWithValue("$c", cle);
        return cmd.ExecuteScalar() as string;
    }

    static void Definir(SqliteConnection c, SqliteTransaction t, string cle, string valeur)
    {
        using var cmd = c.CreateCommand();
        cmd.Transaction = t;
        cmd.CommandText = "INSERT OR REPLACE INTO parametre (cle, valeur) VALUES ($c, $v)";
        cmd.Parameters.AddWithValue("$c", cle);
        cmd.Parameters.AddWithValue("$v", valeur);
        cmd.ExecuteNonQuery();
    }

    void ChargerCatalogue()
    {
        if (!File.Exists(FichierBase)) return;
        using var c = Connexion(false);
        var publie = Reglage(c, "catalogue_commun");
        JsonNode? jp = publie is null ? null : JsonNode.Parse(publie);
        var brouillon = Reglage(c, "catalogue_brouillon");
        Catalogue = brouillon is not null ? Catalogue.Lire(JsonNode.Parse(brouillon), "brouillon en cours")
            : jp is not null ? Catalogue.Lire(jp.DeepClone(), "dernier catalogue publié") : new Catalogue();
        Catalogue.NumeroPublie = (int?)jp?["numero"];
        Catalogue.DatePubliee = (string?)jp?["date"];
        LireJournal(Reglage(c, "catalogue_journal"));
    }

    void LireJournal(string? texte)
    {
        GestesEnCours = EtapesNonPubliees = 0;
        if (string.IsNullOrEmpty(texte)) return;
        try
        {
            var j = JsonNode.Parse(texte);
            GestesEnCours = j?["enCours"]?.AsArray().Count ?? 0;
            EtapesNonPubliees = j?["etapes"]?.AsArray().Count(e => e?["v"] is null && e?["l"] is null) ?? 0;
        }
        catch (JsonException) { }
    }

    /// <summary>
    /// Enregistre le brouillon du catalogue dans la base de la console et note le geste dans son journal (en cours),
    /// en une seule transaction. Une copie de sécurité de la base (.bak) est faite au premier enregistrement.
    /// </summary>
    public void EnregistrerCatalogue(string geste)
    {
        if (!File.Exists(FichierBase)) throw new InvalidOperationException("Base de la console introuvable.");
        if (!_baseSauvee)
        {
            File.Copy(FichierBase!, FichierBase + ".bak", overwrite: true);
            _baseSauvee = true;
        }
        var racine = Catalogue.Racine;
        racine["modifications"] = ((int?)racine["modifications"] ?? 0) + 1;
        using var c = Connexion(true);
        using var t = c.BeginTransaction();
        var journal = JsonNode.Parse(Reglage(c, "catalogue_journal") ?? "{}") as JsonObject ?? new JsonObject();
        if (journal["etapes"] is not JsonArray) journal["etapes"] = new JsonArray();
        if (journal["enCours"] is not JsonArray) journal["enCours"] = new JsonArray();
        journal["enCours"]!.AsArray().Add(new JsonObject
        {
            ["d"] = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss.fff"),
            ["l"] = new JsonArray(JsonValue.Create(geste)),
        });
        Definir(c, t, "catalogue_brouillon", racine.ToJsonString(Options));
        Definir(c, t, "catalogue_journal", journal.ToJsonString(Options));
        t.Commit();
        Catalogue.Origine = "brouillon en cours";
        LireJournal(journal.ToJsonString());
    }

    void ChargerRecettes()
    {
        var f = FichierRecettes!;
        if (!File.Exists(f)) return;
        _racineRecettes = JsonNode.Parse(File.ReadAllText(f))?.AsObject();
        foreach (var r in _racineRecettes?["recettes"]?.AsArray() ?? new JsonArray())
            if (r is JsonObject o) Recettes.Add(Recette.Lire(o));
        RecettesPubliees = (int?)_racineRecettes?["publiee"]?["numero"];
    }

    /// <summary>Marques par secteur ; la première fois, celles livrées avec le logiciel est copiée dans les données.</summary>
    void ChargerMarques()
    {
        var f = FichierMarques!;
        if (!File.Exists(f))
        {
            var livree = Path.Combine(AppContext.BaseDirectory, "marques-secteurs.json");
            if (!File.Exists(livree)) return;
            Directory.CreateDirectory(Path.GetDirectoryName(f)!);
            File.Copy(livree, f);
        }
        if (JsonNode.Parse(File.ReadAllText(f)) is JsonObject o) Marques = new MarquesParSecteur { Racine = o };
    }

    /// <summary>Enregistre les marques par secteur (copie secteurs.json.bak avant).</summary>
    public void EnregistrerMarques()
    {
        var f = FichierMarques ?? throw new InvalidOperationException("Pas de dossier de données.");
        Directory.CreateDirectory(Path.GetDirectoryName(f)!);
        if (File.Exists(f)) File.Copy(f, f + ".bak", overwrite: true);
        var temp = f + ".tmp";
        File.WriteAllText(temp, Marques.Racine.ToJsonString(new JsonSerializerOptions(Options) { WriteIndented = true }));
        File.Move(temp, f, overwrite: true);
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
