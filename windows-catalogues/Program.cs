namespace EmplettesCatalogues;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) =>
            MessageBox.Show(e.Exception.Message, Infos.Nom, MessageBoxButtons.OK, MessageBoxIcon.Error);

        // Écran d'accueil pendant le chargement des données.
        using var accueil = new FormAccueil();
        accueil.Show();
        Application.DoEvents();
        var debut = Environment.TickCount64;
        var donnees = Donnees.Entrepot.Charger();
        var reste = 1500 - (int)(Environment.TickCount64 - debut);
        if (reste > 0) Thread.Sleep(reste);
        accueil.Close();

        Application.Run(new FormPrincipale(donnees));
    }
}

/// <summary>Nom et version du logiciel.</summary>
static class Infos
{
    public const string Nom = "Emplettes · catalogues";
    public static string Version =>
        System.Reflection.Assembly.GetExecutingAssembly()
            .GetCustomAttributes(typeof(System.Reflection.AssemblyInformationalVersionAttribute), false)
            .OfType<System.Reflection.AssemblyInformationalVersionAttribute>().FirstOrDefault()?.InformationalVersion ?? "?";
}
