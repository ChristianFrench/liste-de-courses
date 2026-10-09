"""Ajuste les fichiers générés par « flutter create » (nom affiché, fenêtre Windows au format téléphone).
Lancé automatiquement par GitHub Actions ; rien à faire à la main."""
import pathlib, re, sys

NOM = "Liste de courses"
LARGEUR, HAUTEUR = 412, 892   # format d'un téléphone courant, en points


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

# iPhone : nom sous l'icône
remplacer("ios/Runner/Info.plist",
          r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
          rf"\g<1>{NOM}\g<2>", regex=True)

# Windows : taille de la fenêtre au format téléphone, ajustée à la hauteur de l'écran
TAILLE_FENETRE = """// Fenetre au format telephone (rapport 412 x 892), ajustee a la hauteur utile de l ecran
  RECT zone;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &zone, 0);
  HDC ecran = GetDC(nullptr);
  double echelle = GetDeviceCaps(ecran, LOGPIXELSY) / 96.0;
  ReleaseDC(nullptr, ecran);
  int hauteur = static_cast<int>((zone.bottom - zone.top) / echelle) - 40;
  if (hauteur > %d) hauteur = %d;
  int largeur = hauteur * %d / %d;
  Win32Window::Size size(largeur, hauteur);""" % (HAUTEUR, HAUTEUR, LARGEUR, HAUTEUR)
remplacer("windows/runner/main.cpp",
          r"Win32Window::Size size\(\d+, \d+\);", lambda m: TAILLE_FENETRE, regex=True)
remplacer("windows/runner/main.cpp",
          r'window\.Create\(L"[^"]*"', f'window.Create(L"{NOM}"', regex=True)
# Windows : taille fixe (ni redimensionnement, ni plein écran)
remplacer("windows/runner/win32_window.cpp",
          r"\bWS_OVERLAPPEDWINDOW\b(?! &)",
          "(WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)", regex=True)
