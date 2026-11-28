using System.Text.Json.Nodes;

namespace EmplettesCatalogues.Donnees;

/// <summary>
/// Marques par secteur du catalogue des produits (22/11/2026, Aristide : « on ne verra les marques que par rapport au
/// produit d'un secteur ») : clé « Rayon/Secteur » → marques {nom, source, famille}. Fichier marques/secteurs.json du
/// dossier des données ; la première fois, copie de celui livré (outils/marques/hierarchie_secteurs.py, rangé depuis
/// la hiérarchie d'Aristide). Les marques des produits d'un secteur s'y ajoutent d'elles-mêmes à l'affichage.
/// </summary>
sealed record MarqueS(JsonObject Json, string Cle, bool DesProduits)
{
    public string Nom => (string?)Json["nom"] ?? "";
    public string Source => (string?)Json["source"] ?? (DesProduits ? "produits" : "");
    public string Famille => (string?)Json["famille"] ?? (string?)Json["gamme"] ?? "";
    public bool Distributeur => Cle == MarquesParSecteur.Distributeurs;
    public bool Equals(MarqueS? o) => o is not null && (DesProduits ? o.DesProduits && o.Cle == Cle && o.Nom == Nom : ReferenceEquals(Json, o.Json));
    public override int GetHashCode() => DesProduits ? HashCode.Combine(Cle, Nom) : System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(Json);
}

sealed class MarquesParSecteur
{
    public const string Distributeurs = "*distributeurs";
    public JsonObject Racine = new() { ["secteurs"] = new JsonObject(), ["distributeurs"] = new JsonArray() };

    public static string Cle(Secteur s) => $"{s.Rayon.Nom}/{s.Nom}";

    JsonArray Tableau(string cle, bool creer)
    {
        if (cle == Distributeurs) return Racine["distributeurs"] as JsonArray ?? (JsonArray)(Racine["distributeurs"] = new JsonArray());
        var sec = Racine["secteurs"] as JsonObject ?? (JsonObject)(Racine["secteurs"] = new JsonObject());
        if (sec[cle] is JsonArray a) return a;
        var n = new JsonArray();
        if (creer) sec[cle] = n;
        return n;
    }

    public IEnumerable<string> Cles => (Racine["secteurs"] as JsonObject ?? new JsonObject()).Select(e => e.Key);

    /// <summary>Marques du secteur : celles du fichier, puis celles de ses produits qui n'y sont pas.</summary>
    public List<MarqueS> DuSecteur(Secteur s)
    {
        var cle = Cle(s);
        var l = Tableau(cle, false).OfType<JsonObject>().Select(j => new MarqueS(j, cle, false)).ToList();
        foreach (var m in s.Produits.SelectMany(p => p.Marques).Distinct(StringComparer.CurrentCultureIgnoreCase))
            if (!l.Any(x => string.Equals(x.Nom, m, StringComparison.CurrentCultureIgnoreCase)))
                l.Add(new MarqueS(new JsonObject { ["nom"] = m }, cle, true));
        return l.OrderBy(x => x.Nom, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    public List<MarqueS> DuCle(string cle) => Tableau(cle, false).OfType<JsonObject>().Select(j => new MarqueS(j, cle, false))
        .OrderBy(x => x.Nom, StringComparer.CurrentCultureIgnoreCase).ToList();

    /// <summary>Range la marque dans le secteur <paramref name="vers"/> ; copie (ou marque venue des produits) : elle
    /// reste aussi où elle était. Renvoie la ligne du geste.</summary>
    public string Deplacer(MarqueS m, string vers, MarqueS? avant, bool copie)
    {
        if (vers == m.Cle && !m.DesProduits && avant is null) throw new InvalidOperationException("La marque est déjà dans ce secteur.");
        var cible = Tableau(vers, true);
        var deja = cible.OfType<JsonObject>().FirstOrDefault(x => string.Equals((string?)x["nom"], m.Nom, StringComparison.CurrentCultureIgnoreCase));
        if (deja is not null && !ReferenceEquals(deja, m.Json))
            throw new InvalidOperationException($"Le secteur « {vers} » a déjà la marque « {m.Nom} ».");
        JsonObject j;
        if (m.DesProduits) j = new JsonObject { ["nom"] = m.Nom, ["source"] = "produits" };
        else if (copie) j = (JsonObject)m.Json.DeepClone();
        else
        {
            Tableau(m.Cle, false).Remove(m.Json);
            if (m.Cle != Distributeurs && Tableau(m.Cle, false).Count == 0) (Racine["secteurs"] as JsonObject)?.Remove(m.Cle);
            j = m.Json;
        }
        var i = avant is null || avant.DesProduits ? -1 : cible.IndexOf(avant.Json);
        if (i < 0) cible.Add(j); else cible.Insert(i, j);
        if (Racine["meta"] is JsonObject meta) meta["date_mise_a_jour"] = DateTime.Now.ToString("yyyy-MM-dd");
        return $"Marque « {m.Nom} » {(copie || m.DesProduits ? "ajoutée à" : "rangée dans")} {vers.Replace("/", " › ")}";
    }
}
