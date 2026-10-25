"""Ajuste les fichiers générés par « flutter create » (nom affiché, fenêtre Windows au format téléphone).
Lancé automatiquement par GitHub Actions ; rien à faire à la main."""
import pathlib, re, sys

NOM = "Liste de courses"
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
    gradle.write_text(gradle.read_text(encoding="utf-8") + '\ndependencies {\n    implementation("androidx.core:core:1.13.1")\n}\n',
                      encoding="utf-8")
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

# iPhone : nom sous l'icône
remplacer("ios/Runner/Info.plist",
          r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
          rf"\g<1>{NOM}\g<2>", regex=True)

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
remplacer("web/index.html", 'content="A new Flutter project."', f'content="{NOM} partagée du foyer"')
remplacer("web/manifest.json", r'"(short_)?name": "liste_de_courses"', lambda m: f'"{m[1] or ""}name": "{NOM}"', regex=True)
remplacer("web/manifest.json", '"A new Flutter project."', f'"{NOM} partagée du foyer"')
remplacer("web/manifest.json", '"#0175C2"', '"#3F7D5A"')
