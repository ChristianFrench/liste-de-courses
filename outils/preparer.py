"""Ajuste les fichiers générés par « flutter create » (nom affiché, fenêtre Windows au format téléphone).
Lancé automatiquement par GitHub Actions ; rien à faire à la main."""
import os, pathlib, re, sys

NOM = "Emplettes"
LARGEUR, HAUTEUR = 390, 844   # format de référence de la spécification IHM, en points


def remplacer(chemin, ancien, nouveau, regex=False):
    p = pathlib.Path(chemin)
    if not p.exists():
        return
    t = p.read_text(encoding="utf-8")
    t2 = re.sub(ancien, nouveau, t) if regex else t.replace(ancien, nouveau)
    if t2 == t:
        sys.exit(f"Motif introuvable dans {chemin} : {ancien}")
    p.write_text(t2, encoding="utf-8")
    print(f"ajusté : {chemin}")


# Android : nom sous l'icône
remplacer("android/app/src/main/AndroidManifest.xml",
          r'android:label="[^"]*"', f'android:label="{NOM}"', regex=True)

# Android : autorisation d'accès à internet (Open Food Facts, puis Firebase)
remplacer("android/app/src/main/AndroidManifest.xml",
          r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', regex=True)

# Android : l'application reçoit les tickets de caisse PDF (« Partager » et « Ouvrir avec »).
# Une seule fenêtre de l'application (singleTask) : un PDF partagé rejoint l'application déjà ouverte.
remplacer("android/app/src/main/AndroidManifest.xml",
          'android:launchMode="singleTop"', 'android:launchMode="singleTask"')
remplacer("android/app/src/main/AndroidManifest.xml",
          r"(<category android:name=\"android.intent.category.LAUNCHER\"/>\s*</intent-filter>)",
          r"""\1
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="application/pdf"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="content"/>
                <data android:scheme="file"/>
                <data android:mimeType="application/pdf"/>
            </intent-filter>""", regex=True)
# Android : les tickets rangés dans l'application peuvent être prêtés au lecteur de PDF.
remplacer("android/app/src/main/AndroidManifest.xml",
          r"(\s*</application>)",
          r'''
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.tickets"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/chemins_tickets"/>
        </provider>\1''', regex=True)
chemins = pathlib.Path("android/app/src/main/res/xml/chemins_tickets.xml")
if chemins.parent.parent.exists():
    chemins.parent.mkdir(exist_ok=True)
    chemins.write_text('<?xml version="1.0" encoding="utf-8"?>\n<paths>\n    <files-path name="fichiers" path="."/>\n</paths>\n',
                       encoding="utf-8")
    print(f"créé : {chemins}")
gradle = pathlib.Path("android/app/build.gradle.kts")
if gradle.exists():
    gradle.write_text(gradle.read_text(encoding="utf-8") + '\ndependencies {\n    implementation("androidx.core:core:1.13.1")\n'
                      '    implementation("com.google.firebase:firebase-messaging:24.1.0")\n}\n',
                      encoding="utf-8")
# 12/11/2026 : l'analyse « lint vital » de la version de publication plante dans un module tiers
# (file_selector_android, erreur interne de l'outil lint, sans lien avec le code) ; elle est coupée.
racine = pathlib.Path("android/build.gradle.kts")
if racine.exists():
    racine.write_text(racine.read_text(encoding="utf-8") +
                      '\nsubprojects {\n    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }\n}\n',
                      encoding="utf-8")

# Android : notifications du foyer par Firebase (06/11/2026). Le service qui les affiche, sa petite icône,
# l'autorisation d'Android 13, et la configuration du projet Firebase lue dans le secret GitHub
# GOOGLE_SERVICES_JSON (sans lui, Firebase ne démarre pas et l'application fonctionne sans notifications).
dossier_kotlin = pathlib.Path("android/app/src/main/kotlin/fr/listecourses/liste_de_courses")
if dossier_kotlin.exists():
    (dossier_kotlin / "NotificationsEmplettes.kt").write_text(
        pathlib.Path("outils/android/NotificationsEmplettes.kt").read_text(encoding="utf-8"), encoding="utf-8")
    dessins = pathlib.Path("android/app/src/main/res/drawable")
    dessins.mkdir(exist_ok=True)
    (dessins / "ic_notification.xml").write_text(
        pathlib.Path("outils/android/ic_notification.xml").read_text(encoding="utf-8"), encoding="utf-8")
    remplacer("android/app/src/main/AndroidManifest.xml",
              r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>', regex=True)
    remplacer("android/app/src/main/AndroidManifest.xml",
              r"(\s*</application>)",
              r'''
        <service
            android:name=".NotificationsEmplettes"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT"/>
            </intent-filter>
        </service>\1''', regex=True)
    config = os.environ.get("GOOGLE_SERVICES_JSON", "").strip()
    if config:
        import json
        from xml.sax.saxutils import escape
        j = json.loads(config)
        client = next(c for c in j["client"]
                      if c["client_info"]["android_client_info"]["package_name"] == "fr.listecourses.liste_de_courses")
        valeurs = {
            "google_app_id": client["client_info"]["mobilesdk_app_id"],
            "gcm_defaultSenderId": j["project_info"]["project_number"],
            "google_api_key": client["api_key"][0]["current_key"],
            "project_id": j["project_info"]["project_id"],
        }
        if j["project_info"].get("storage_bucket"):
            valeurs["google_storage_bucket"] = j["project_info"]["storage_bucket"]
        lignes = "".join(f'    <string name="{k}" translatable="false">{escape(v)}</string>\n' for k, v in valeurs.items())
        pathlib.Path("android/app/src/main/res/values/firebase.xml").write_text(
            f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n{lignes}</resources>\n', encoding="utf-8")
        print("créé : android/app/src/main/res/values/firebase.xml (projet " + valeurs["project_id"] + ")")
    else:
        print("GOOGLE_SERVICES_JSON absent : version sans notifications Firebase")
activite = pathlib.Path("android/app/src/main/kotlin/fr/listecourses/liste_de_courses/MainActivity.kt")
if activite.exists():
    activite.write_text(pathlib.Path("outils/android/MainActivity.kt").read_text(encoding="utf-8"), encoding="utf-8")
    print(f"remplacé : {activite}")

# Android : toutes les versions signées avec la même clé (outils/android/debug.keystore),
# pour qu'une nouvelle version s'installe par-dessus l'ancienne en gardant les données
remplacer("android/app/build.gradle.kts",
          """    buildTypes {
        release {""",
          """    signingConfigs {
        create("essai") {
            storeFile = rootProject.file("../outils/android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {""")
remplacer("android/app/build.gradle.kts",
          'signingConfig = signingConfigs.getByName("debug")',
          'signingConfig = signingConfigs.getByName("essai")')

# Windows : taille de la fenêtre au format téléphone, ajustée à la hauteur de l'écran
TAILLE_FENETRE = """// Fenetre au format telephone (rapport %d x %d), ajustee a la hauteur utile de l ecran
  RECT zone;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &zone, 0);
  HDC ecran = GetDC(nullptr);
  double echelle = GetDeviceCaps(ecran, LOGPIXELSY) / 96.0;
  ReleaseDC(nullptr, ecran);
  int hauteur = static_cast<int>((zone.bottom - zone.top) / echelle) - 40;
  if (hauteur > %d) hauteur = %d;
  int largeur = hauteur * %d / %d;
  Win32Window::Size size(largeur, hauteur);""" % (LARGEUR, HAUTEUR, HAUTEUR, HAUTEUR, LARGEUR, HAUTEUR)
remplacer("windows/runner/main.cpp",
          r"Win32Window::Size size\(\d+, \d+\);", lambda m: TAILLE_FENETRE, regex=True)
remplacer("windows/runner/main.cpp",
          r'window\.Create\(L"[^"]*"', f'window.Create(L"{NOM}"', regex=True)
# Windows : taille fixe (ni redimensionnement, ni plein écran)
remplacer("windows/runner/win32_window.cpp",
          r"\bWS_OVERLAPPEDWINDOW\b(?! &)",
          "(WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)", regex=True)

# Web : nom, langue et couleurs (page d'accueil et application installée sur l'écran d'accueil)
remplacer("web/index.html", "<html>", '<html lang="fr">')
remplacer("web/index.html", "<title>liste_de_courses</title>", f"<title>{NOM}</title>")
remplacer("web/index.html", 'content="liste_de_courses"', f'content="{NOM}"')
remplacer("web/index.html", 'content="A new Flutter project."', 'content="Liste de courses partagée du foyer"')
# Nom distinct de l'application Android : sur un téléphone où l'APK est installé, la version web ajoutée à
# l'écran d'accueil (données séparées, celles du navigateur) ne doit pas se confondre avec elle.
remplacer("web/manifest.json", r'"(short_)?name": "liste_de_courses"', lambda m: f'"{m[1] or ""}name": "{NOM} web"', regex=True)
remplacer("web/manifest.json", '"A new Flutter project."', '"Liste de courses partagée du foyer"')
remplacer("web/manifest.json", '"#0175C2"', '"#3F7D5A"')

# Web : écran d'ouverture (12/11/2026). Le moteur de l'application met 2 à 3 secondes à démarrer dans le
# navigateur, la page restait blanche : la fenêtre « Ouverture d'Emplettes » s'affiche tout de suite, l'application
# la retire à sa première image (et montre la même par-dessus son écran). Les fichiers lus au démarrage (polices, sqlite3) sont demandés dès le début
# au lieu d'attendre que le moteur les réclame un par un. La largeur du téléphone est donnée tout de suite
# (sans elle, la fenêtre s'affichait minuscule, à l'échelle d'un écran de PC, jusqu'au démarrage du moteur).
OUVERTURE = """  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="preload" href="sqlite3.wasm" as="fetch" crossorigin>
  <link rel="preload" href="assets/assets/polices/AtkinsonHyperlegible-Regular.ttf" as="fetch" crossorigin>
  <link rel="preload" href="assets/assets/polices/AtkinsonHyperlegible-Bold.ttf" as="fetch" crossorigin>
  <link rel="preload" href="assets/assets/polices/AtkinsonHyperlegible-Italic.ttf" as="fetch" crossorigin>
  <link rel="preload" href="assets/fonts/MaterialIcons-Regular.otf" as="fetch" crossorigin>
  <style>
    html, body { margin: 0; background: #F5F9F6; }
    #ouverture { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center;
      background: rgba(0, 0, 0, 0.13); font-family: system-ui, sans-serif; color: #1f2b25; }
    #ouverture .fenetre { width: 236px; padding: 20px 22px 22px; background: #fff; border-radius: 16px;
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.2); }
    #ouverture .titre { font-size: 17px; font-weight: 700; margin-bottom: 10px; }
    #ouverture .texte { font-size: 14px; margin-bottom: 10px; }
    #ouverture .barre { height: 6px; border-radius: 3px; background: #e2ebe5; overflow: hidden; }
    #ouverture .barre i { display: block; width: 6%; height: 100%; background: #557B66;
      animation: ouverture 2.5s ease-out forwards; }
    @keyframes ouverture { to { width: 20%; } }
  </style>
  <script>
    window.retirerEcranOuverture = function () { var e = document.getElementById('ouverture'); if (e) e.remove(); };
  </script>
</head>"""
ECRAN = """<body>
  <div id="ouverture"><div class="fenetre"><div class="titre">Ouverture d’Emplettes</div>
    <div class="texte">Démarrage</div><div class="barre"><i></i></div></div></div>"""
remplacer("web/index.html", "</head>", OUVERTURE)
remplacer("web/index.html", "<body>", ECRAN)
