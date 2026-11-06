"""Console d'administration (Windows) : fenêtre large et redimensionnable, au lieu du format téléphone
d'Emplettes. Lancé par GitHub Actions avant la compilation de l'outil de l'éditeur ; rien à faire à la main."""
import pathlib, re, sys

TAILLE = """// Console d administration : 90 % de la zone utile de l ecran (au plus 1600 x 1000)
  RECT zone;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &zone, 0);
  HDC ecran = GetDC(nullptr);
  double echelle = GetDeviceCaps(ecran, LOGPIXELSY) / 96.0;
  ReleaseDC(nullptr, ecran);
  int largeur = static_cast<int>((zone.right - zone.left) / echelle * 0.9);
  int hauteur = static_cast<int>((zone.bottom - zone.top) / echelle * 0.9);
  if (largeur > 1600) largeur = 1600;
  if (hauteur > 1000) hauteur = 1000;
  Win32Window::Size size(largeur, hauteur);"""

main = pathlib.Path("windows/runner/main.cpp")
t = main.read_text(encoding="utf-8")
t2 = re.sub(r"// Fenetre au format telephone.*?Win32Window::Size size\(largeur, hauteur\);", lambda m: TAILLE, t, flags=re.S)
t2 = re.sub(r'window\.Create\(L"[^"]*"', lambda m: 'window.Create(L"Emplettes administration"', t2)
if t2 == t:
    sys.exit("main.cpp : motif introuvable")
main.write_text(t2, encoding="utf-8")

w = pathlib.Path("windows/runner/win32_window.cpp")
t = w.read_text(encoding="utf-8")
t2 = t.replace("(WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)", "WS_OVERLAPPEDWINDOW")
if t2 == t:
    sys.exit("win32_window.cpp : motif introuvable")
w.write_text(t2, encoding="utf-8")
print("fenêtre de la console : large et redimensionnable")
