using System.Text.Json.Nodes;

namespace EmplettesCatalogues.Donnees;

/// <summary>
/// Hiérarchie des marques (22/11/2026, fournie par Aristide) : groupe (« rayon » du fichier) › famille de produits ›
/// marques. Fichier marques/hierarchie.json du dossier des données ; la première fois, copie de celui livré avec le
/// logiciel. Les produits d'une marque se lisent dans le catalogue des produits (marques de chaque produit).
/// </summary>
sealed class FamilleMarques
{
    public string Nom = "", Groupe = "";
    public JsonArray Marques = new();
    /// <summary>« Marques à classer » : marques des produits absentes de la hiérarchie (rien n'y est enregistré).</summary>
    public bool AClasser;
    public IEnumerable<JsonObject> Liste => Marques.OfType<JsonObject>();
}

sealed record GroupeMarques(string Nom, List<FamilleMarques> Familles);

sealed record MarqueH(JsonObject Json, FamilleMarques Famille)
{
    public string Nom => (string?)Json["nom"] ?? "";
    public string Source => (string?)Json["source"] ?? "";
    public bool Equals(MarqueH? o) => o is not null && ReferenceEquals(Json, o.Json);
    public override int GetHashCode() => System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(Json);
}

sealed class HierarchieMarques
{
    public JsonObject Racine = new();
    public List<GroupeMarques> Groupes = new();

    public static HierarchieMarques Lire(JsonObject racine)
    {
        var h = new HierarchieMarques { Racine = racine };
        foreach (var (g, gv) in racine["rayons"]?.AsObject() ?? new JsonObject())
        {
            var groupe = new GroupeMarques(g, new());
            foreach (var (f, fv) in gv?["familles"]?.AsObject() ?? new JsonObject())
            {
                var liste = fv?["marques"] as JsonArray;
                if (liste is null && fv is JsonObject fo) fo["marques"] = liste = new JsonArray();
                groupe.Familles.Add(new FamilleMarques { Nom = f, Groupe = g, Marques = liste ?? new JsonArray() });
            }
            h.Groupes.Add(groupe);
        }
        return h;
    }

    public IEnumerable<FamilleMarques> Familles => Groupes.SelectMany(g => g.Familles);

    public bool Contient(string marque) =>
        Familles.Any(f => f.Liste.Any(m => string.Equals((string?)m["nom"], marque, StringComparison.CurrentCultureIgnoreCase)));

    /// <summary>Range <paramref name="m"/> dans <paramref name="vers"/> (avant <paramref name="avant"/>) ; copie : la
    /// marque reste aussi dans sa famille. Renvoie la ligne du geste.</summary>
    public string Deplacer(MarqueH m, FamilleMarques vers, MarqueH? avant, bool copie)
    {
        if (vers.AClasser) throw new InvalidOperationException("« Marques à classer » ne reçoit pas de marque.");
        var deja = vers.Liste.FirstOrDefault(x => string.Equals((string?)x["nom"], m.Nom, StringComparison.CurrentCultureIgnoreCase));
        if (deja is not null && !ReferenceEquals(deja, m.Json))
            throw new InvalidOperationException($"La famille « {vers.Nom} » a déjà la marque « {m.Nom} ».");
        JsonObject j;
        if (copie || m.Famille.AClasser)
            j = m.Famille.AClasser ? new JsonObject { ["nom"] = m.Nom, ["produits"] = 0, ["source"] = "catalogue_produits" } : (JsonObject)m.Json.DeepClone();
        else
        {
            m.Famille.Marques.Remove(m.Json);
            j = m.Json;
        }
        var i = avant is null ? -1 : vers.Marques.IndexOf(avant.Json);
        if (i < 0) vers.Marques.Add(j); else vers.Marques.Insert(i, j);
        Recompter();
        return $"Marque « {m.Nom} » {(copie ? "copiée" : "rangée")} dans {vers.Groupe} › {vers.Nom}";
    }

    /// <summary>Met à jour les nombres du fichier (marques par famille, par groupe, totaux).</summary>
    public void Recompter()
    {
        foreach (var g in Groupes)
        {
            foreach (var f in g.Familles)
                if (Racine["rayons"]?[g.Nom]?["familles"]?[f.Nom] is JsonObject fo) fo["nombre_marques"] = f.Marques.Count;
            if (Racine["rayons"]?[g.Nom] is JsonObject go)
                go["nombre_marques"] = g.Familles.SelectMany(f => f.Liste).Select(m => ((string?)m["nom"] ?? "").ToLowerInvariant()).Distinct().Count();
        }
        if (Racine["meta"] is JsonObject meta)
        {
            meta["total_rayons"] = Groupes.Count;
            meta["total_familles"] = Familles.Count();
            meta["total_marques_uniques"] = Familles.SelectMany(f => f.Liste).Select(m => ((string?)m["nom"] ?? "").ToLowerInvariant()).Distinct().Count();
            meta["date_mise_a_jour"] = DateTime.Now.ToString("yyyy-MM-dd");
        }
    }
}
