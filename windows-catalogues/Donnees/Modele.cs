using System.Text.Json.Nodes;

namespace EmplettesCatalogues.Donnees;

// Modèle des catalogues, lu dans les mêmes données que la console (même format JSON que l'application Emplettes).

sealed class Produit
{
    public string Nom = "";
    public List<string> Marques = new();
    public List<string> Formats = new();
    public Secteur Secteur = null!;
    public JsonObject Json = new();
}

sealed class Secteur
{
    public string Nom = "";
    public List<Produit> Produits = new();
    public Rayon Rayon = null!;
    public JsonObject Json = new();
}

sealed class Rayon
{
    public string Nom = "";
    public string Domaine = Catalogue.AutresRayons;
    public List<Secteur> Secteurs = new();
    public JsonObject Json = new();
}

/// <summary>
/// Le catalogue des produits (brouillon de l'éditeur). Les objets JSON d'origine sont gardés (<see cref="Racine"/>) et
/// modifiés sur place par les déplacements : les champs que ce logiciel ne connaît pas sont conservés.
/// </summary>
sealed class Catalogue
{
    public const string AutresRayons = "Autres rayons";
    public List<Rayon> Rayons = new();
    public List<string> Domaines = new();
    public JsonObject Racine = new();
    /// <summary>D'où vient le catalogue affiché (brouillon en cours, dernier publié, aucun).</summary>
    public string Origine = "aucun catalogue";
    public int? NumeroPublie;
    public string? DatePubliee;

    public IEnumerable<Produit> TousLesProduits => Rayons.SelectMany(r => r.Secteurs).SelectMany(s => s.Produits);

    public static Catalogue Lire(JsonNode? j, string origine)
    {
        var c = new Catalogue { Origine = origine };
        if (j is not JsonObject racine) return c;
        c.Racine = racine;
        var domaineDuRayon = new Dictionary<string, string>();
        foreach (var u in racine["univers"]?.AsArray() ?? new JsonArray())
        {
            var nom = (string?)u?["nom"];
            if (nom is null) continue;
            c.Domaines.Add(nom);
            foreach (var r in u!["rayons"]?.AsArray() ?? new JsonArray())
                if ((string?)r is { } rn) domaineDuRayon[rn] = nom;
        }
        foreach (var rj in racine["rayons"]?.AsArray() ?? new JsonArray())
        {
            if (rj is not JsonObject ro) continue;
            var r = new Rayon { Nom = (string?)ro["nom"] ?? "", Json = ro };
            r.Domaine = domaineDuRayon.GetValueOrDefault(r.Nom, AutresRayons);
            foreach (var sj in ro["secteurs"]?.AsArray() ?? new JsonArray())
            {
                if (sj is not JsonObject so) continue;
                var s = new Secteur { Nom = (string?)so["nom"] ?? "", Rayon = r, Json = so };
                foreach (var pj in so["produits"]?.AsArray() ?? new JsonArray())
                {
                    if (pj is not JsonObject po) continue;
                    s.Produits.Add(new Produit { Nom = (string?)po["nom"] ?? "", Marques = Textes(po["marques"]), Formats = Textes(po["formats"]), Secteur = s, Json = po });
                }
                r.Secteurs.Add(s);
            }
            c.Rayons.Add(r);
        }
        if (c.Rayons.Any(r => r.Domaine == AutresRayons)) c.Domaines.Add(AutresRayons);
        return c;
    }

    internal static List<string> Textes(JsonNode? n) =>
        n is JsonArray a ? a.Select(x => (string?)x).Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x!).ToList() : new();

    static JsonArray Tableau(JsonObject o, string cle)
    {
        if (o[cle] is JsonArray a) return a;
        a = new JsonArray();
        o[cle] = a;
        return a;
    }

    // ------------------------------------------------------------ déplacements (rendent la ligne du journal)

    /// <summary>Déplace (ou copie) le produit dans le secteur <paramref name="cible"/>, avant <paramref name="avant"/> s'il est donné.</summary>
    public string? DeplacerProduit(Produit p, Secteur cible, Produit? avant, bool copie)
    {
        if (ReferenceEquals(p, avant)) return null;
        if (cible.Produits.Any(x => !ReferenceEquals(x, p) && string.Equals(x.Nom, p.Nom, StringComparison.CurrentCultureIgnoreCase)))
            throw new InvalidOperationException($"Le secteur « {cible.Nom} » contient déjà « {p.Nom} ».");
        var de = p.Secteur;
        var json = copie ? (JsonObject)p.Json.DeepClone() : p.Json;
        if (!copie)
        {
            Tableau(de.Json, "produits").Remove(p.Json);
            de.Produits.Remove(p);
        }
        var x = copie ? new Produit { Nom = p.Nom, Marques = new(p.Marques), Formats = new(p.Formats), Json = json } : p;
        x.Secteur = cible;
        var i = avant is null ? cible.Produits.Count : cible.Produits.IndexOf(avant);
        if (i < 0) i = cible.Produits.Count;
        cible.Produits.Insert(i, x);
        Tableau(cible.Json, "produits").Insert(i, json);
        return copie
            ? $"Produit « {p.Nom} » copié dans {cible.Rayon.Nom} › {cible.Nom}"
            : (ReferenceEquals(de, cible) ? $"Produit « {p.Nom} » déplacé dans {cible.Nom}" : $"Produit « {p.Nom} » : {de.Rayon.Nom} › {de.Nom} → {cible.Rayon.Nom} › {cible.Nom}");
    }

    public string? DeplacerSecteur(Secteur s, Rayon cible, Secteur? avant)
    {
        if (ReferenceEquals(s, avant)) return null;
        if (cible.Secteurs.Any(x => !ReferenceEquals(x, s) && string.Equals(x.Nom, s.Nom, StringComparison.CurrentCultureIgnoreCase)))
            throw new InvalidOperationException($"Le rayon « {cible.Nom} » contient déjà un secteur « {s.Nom} ».");
        var de = s.Rayon;
        Tableau(de.Json, "secteurs").Remove(s.Json);
        de.Secteurs.Remove(s);
        s.Rayon = cible;
        var i = avant is null ? cible.Secteurs.Count : cible.Secteurs.IndexOf(avant);
        if (i < 0) i = cible.Secteurs.Count;
        cible.Secteurs.Insert(i, s);
        Tableau(cible.Json, "secteurs").Insert(i, s.Json);
        return ReferenceEquals(de, cible) ? $"Secteur « {s.Nom} » déplacé dans {cible.Nom}" : $"Secteur « {s.Nom} » : {de.Nom} → {cible.Nom}";
    }

    public string? DeplacerRayon(Rayon r, string domaine, Rayon? avant)
    {
        if (ReferenceEquals(r, avant)) return null;
        var de = r.Domaine;
        // Ordre des rayons : celui du tableau « rayons ».
        var rayons = Tableau(Racine, "rayons");
        rayons.Remove(r.Json);
        Rayons.Remove(r);
        var i = avant is null ? Rayons.FindLastIndex(x => x.Domaine == domaine) + 1 : Rayons.IndexOf(avant);
        if (i <= 0 && avant is null) i = Rayons.Count;
        Rayons.Insert(i, r);
        rayons.Insert(i, r.Json);
        // Domaine : listes « univers ».
        r.Domaine = domaine;
        var univers = Tableau(Racine, "univers");
        foreach (var u in univers.OfType<JsonObject>())
        {
            var liste = Tableau(u, "rayons");
            foreach (var x in liste.Where(x => (string?)x == r.Nom).ToList()) liste.Remove(x);
        }
        if (domaine != AutresRayons)
        {
            var u = univers.OfType<JsonObject>().FirstOrDefault(x => (string?)x["nom"] == domaine);
            if (u is null) { u = new JsonObject { ["nom"] = domaine, ["rayons"] = new JsonArray() }; univers.Add(u); }
            var liste = Tableau(u, "rayons");
            var ordre = Rayons.Where(x => x.Domaine == domaine).Select(x => x.Nom).ToList();
            liste.Clear();
            foreach (var n in ordre) liste.Add(n);
        }
        if (!Domaines.Contains(domaine)) Domaines.Add(domaine);
        return de == domaine ? $"Rayon « {r.Nom} » déplacé dans {domaine}" : $"Rayon « {r.Nom} » : {de} → {domaine}";
    }
}

sealed class Ingredient
{
    public string Nom { get; set; } = "";
    public string Quantite { get; set; } = "";
    public string Precision { get; set; } = "";
}

sealed class Etape
{
    public string Texte { get; set; } = "";
}

/// <summary>
/// Une recette. Les champs inconnus de ce logiciel sont gardés tels quels (<see cref="Brut"/>) : rien ne se perd à
/// l'enregistrement.
/// </summary>
sealed class Recette
{
    public JsonObject Brut = new();
    public string Id = "", Titre = "";
    public List<string> Types = new();
    public Dictionary<string, string> SousTypes = new();
    public string? Origine, Pour, Difficulte, Cout, Source, Illustration;
    public int? TempsPreparation, TempsCuisson;
    public List<string> Regimes = new(), Saisons = new(), Cuissons = new(), Occasions = new(), Conseils = new();
    public List<Ingredient> Detail = new();
    public List<Etape> Etapes = new();
    public bool Memo;

    public static Recette Lire(JsonObject j)
    {
        var r = new Recette
        {
            Brut = j,
            Id = (string?)j["id"] ?? "",
            Titre = (string?)j["titre"] ?? "",
            Types = Catalogue.Textes(j["types"]),
            Origine = (string?)j["origine"],
            Pour = (string?)j["pour"],
            Difficulte = (string?)j["difficulte"],
            Cout = (string?)j["cout"],
            Source = (string?)j["source"],
            Illustration = (string?)j["illustration"],
            TempsPreparation = (int?)j["tempsPreparation"],
            TempsCuisson = (int?)j["tempsCuisson"],
            Regimes = Catalogue.Textes(j["regimes"]),
            Saisons = Catalogue.Textes(j["saisons"]),
            Cuissons = Catalogue.Textes(j["cuissons"]),
            Occasions = Catalogue.Textes(j["occasions"]),
            Conseils = Catalogue.Textes(j["conseils"]),
            Etapes = Catalogue.Textes(j["etapes"]).Select(t => new Etape { Texte = t }).ToList(),
            Memo = (bool?)j["memo"] ?? false,
        };
        if (j["sousTypes"] is JsonObject st)
            foreach (var (k, v) in st)
                if ((string?)v is { } s) r.SousTypes[k] = s;
        foreach (var i in j["detail"]?.AsArray() ?? new JsonArray())
            r.Detail.Add(new Ingredient { Nom = (string?)i?["nom"] ?? "", Quantite = (string?)i?["quantite"] ?? "", Precision = (string?)i?["precision"] ?? "" });
        return r;
    }

    static void Mettre(JsonObject j, string cle, JsonNode? valeur)
    {
        if (valeur is null || (valeur is JsonArray a && a.Count == 0) || (valeur is JsonValue v && v.TryGetValue<string>(out var s) && s.Length == 0))
            j.Remove(cle);
        else
            j[cle] = valeur;
    }

    static JsonArray Liste(IEnumerable<string> l) => new(l.Select(x => (JsonNode?)JsonValue.Create(x)).ToArray());

    /// <summary>Recopie les champs dans <see cref="Brut"/>, marque la recette retouchée et datée.</summary>
    public void Ecrire()
    {
        var j = Brut;
        j["titre"] = Titre;
        j["types"] = Liste(Types);
        Mettre(j, "sousTypes", SousTypes.Count == 0 ? null : new JsonObject(SousTypes.Select(e => KeyValuePair.Create(e.Key, (JsonNode?)JsonValue.Create(e.Value)))));
        Mettre(j, "origine", Origine);
        Mettre(j, "pour", Pour);
        Mettre(j, "difficulte", Difficulte);
        Mettre(j, "cout", Cout);
        Mettre(j, "tempsPreparation", TempsPreparation);
        Mettre(j, "tempsCuisson", TempsCuisson);
        Mettre(j, "regimes", Liste(Regimes));
        Mettre(j, "saisons", Liste(Saisons));
        Mettre(j, "cuissons", Liste(Cuissons));
        Mettre(j, "occasions", Liste(Occasions));
        Mettre(j, "conseils", Liste(Conseils.Where(c => c.Trim().Length > 0)));
        var detail = Detail.Where(i => i.Nom.Trim().Length > 0).ToList();
        var d = new JsonArray();
        foreach (var i in detail)
        {
            var o = new JsonObject { ["nom"] = i.Nom.Trim() };
            if (i.Quantite.Trim().Length > 0) o["quantite"] = i.Quantite.Trim();
            if (i.Precision.Trim().Length > 0) o["precision"] = i.Precision.Trim();
            d.Add(o);
        }
        Mettre(j, "detail", d);
        // Texte des ingrédients (ancien format, lu par les versions précédentes) : « 3 gousses Ail (écrasé) ».
        j["ingredients"] = Liste(detail.Select(i => string.Join(" ", new[] { i.Quantite.Trim(), i.Nom.Trim() }.Where(x => x.Length > 0))
            + (i.Precision.Trim().Length > 0 ? $" ({i.Precision.Trim()})" : "")));
        var etapes = Etapes.Select(e => e.Texte.Trim()).Where(t => t.Length > 0).ToList();
        Mettre(j, "etapes", Liste(etapes));
        j["preparation"] = string.Join("\n", etapes.Select((t, n) => $"{n + 1}. {t}"));
        j["retouchee"] = true;
        j["modifieeLe"] = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss.fff");
    }
}

/// <summary>Valeurs des critères (les mêmes que dans la console et l'application).</summary>
static class Criteres
{
    public static readonly (string Type, string[] SousTypes)[] Types =
    [
        ("Apéritif", ["Amuse-bouche", "Tartinade et dip", "Bouchées et feuilletés"]),
        ("Entrée", ["Soupe et velouté", "Salade composée", "Entrée froide", "Entrée chaude"]),
        ("Plats", ["Viande", "Volaille", "Poisson et fruits de mer", "Végétarien"]),
        ("Plats complets", ["Gratin et lasagnes", "Mijoté complet", "Tarte salée et pizza", "Riz et pâtes garnis", "Bowl et salade-repas"]),
        ("Plats accompagnement", ["Légumes", "Féculents", "Légumineuses"]),
        ("Sauces", ["Sauce chaude", "Sauce froide et vinaigrette", "Condiment", "Sauce sucrée"]),
        ("Dessert", ["Gâteau", "Tarte", "Crème et mousse", "Fruits", "Glace", "Sauce sucrée"]),
        ("Petit-déjeuner et goûter", ["Crêpes et gaufres", "Biscuits et petits gâteaux", "Brioches et viennoiseries", "Pains", "Confitures et pâtes à tartiner"]),
        ("Bases culinaires", ["Pâtes", "Fonds et bouillons", "Crèmes de base", "Mémos techniques"]),
    ];
    public static readonly string[] Origines = ["France", "Italie", "Espagne et Portugal", "Autres pays d'Europe", "Maghreb et Moyen-Orient", "Afrique", "Inde", "Asie", "Amériques"];
    public static readonly string[] Difficultes = ["Facile", "Moyen", "Difficile", "Avancé"];
    public static readonly string[] Regimes = ["Végétarien", "Végétalien", "Sans gluten", "Sans lactose"];
    public static readonly string[] Saisons = ["Printemps", "Été", "Automne", "Hiver"];
    public static readonly string[] Couts = ["€", "€€", "€€€"];
    public static readonly string[] Cuissons = ["Sans cuisson", "Four", "Plaque", "Cocotte-minute"];
    public static readonly string[] Occasions = ["Quotidien", "À l'avance", "À recevoir", "À emporter"];

    public static int RangType(string t) => Array.FindIndex(Types, x => x.Type == t) is var i and >= 0 ? i : 99;

    public static string Duree(int minutes) => minutes < 60 ? $"{minutes} min" : (minutes % 60 == 0 ? $"{minutes / 60} h" : $"{minutes / 60} h {minutes % 60:00}");
}
