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
# 17/11/2026 (Aristide) : largeur minimum de la fenêtre, donnée par la console (menu déplié ou replié).
MINIMUM = """    case WM_GETMINMAXINFO:
      if (g_largeur_min_console > 0) {
        RECT fenetre, client;
        GetWindowRect(hwnd, &fenetre);
        GetClientRect(hwnd, &client);
        int bord = (fenetre.right - fenetre.left) - (client.right - client.left);
        double echelle = GetDpiForWindow(hwnd) / 96.0;
        auto info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize.x = static_cast<LONG>(g_largeur_min_console * echelle) + bord;
        info->ptMinTrackSize.y = static_cast<LONG>(480 * echelle);
        return 0;
      }
      break;
    case WM_DESTROY:"""
if "case WM_DESTROY:" not in t2:
    sys.exit("win32_window.cpp : WM_DESTROY introuvable")
t2 = t2.replace("case WM_DESTROY:", MINIMUM.strip(), 1)
t2 = t2.replace('#include "win32_window.h"', '#include "win32_window.h"\n\n// Largeur minimum (pixels logiques) imposee par la console.\nint g_largeur_min_console = 0;', 1)
w.write_text(t2, encoding="utf-8")

CANAL = """RegisterPlugins(flutter_controller_->engine());
  // Console : la page Dart donne la largeur minimum ; si la fenetre est plus etroite, elle s elargit.
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> canal_fenetre;
  canal_fenetre = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "emplettes/fenetre",
      &flutter::StandardMethodCodec::GetInstance());
  HWND principale = GetHandle();
  canal_fenetre->SetMethodCallHandler(
      [principale](const flutter::MethodCall<flutter::EncodableValue>& appel,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultat) {
        const auto* valeur = std::get_if<int32_t>(appel.arguments());
        if (appel.method_name() != "largeurMinimum" || valeur == nullptr) {
          resultat->NotImplemented();
          return;
        }
        g_largeur_min_console = *valeur;
        RECT fenetre, client;
        GetWindowRect(principale, &fenetre);
        GetClientRect(principale, &client);
        int bord = (fenetre.right - fenetre.left) - (client.right - client.left);
        int voulue = static_cast<int>(*valeur * (GetDpiForWindow(principale) / 96.0)) + bord;
        if (!IsZoomed(principale) && fenetre.right - fenetre.left < voulue) {
          SetWindowPos(principale, nullptr, 0, 0, voulue, fenetre.bottom - fenetre.top,
                       SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
        resultat->Success();
      });"""
f = pathlib.Path("windows/runner/flutter_window.cpp")
t = f.read_text(encoding="utf-8")
if "RegisterPlugins(flutter_controller_->engine());" not in t:
    sys.exit("flutter_window.cpp : RegisterPlugins introuvable")
t = t.replace("RegisterPlugins(flutter_controller_->engine());", CANAL, 1)
t = t.replace('#include "flutter_window.h"',
              '#include "flutter_window.h"\n\n#include <flutter/method_channel.h>\n#include <flutter/standard_method_codec.h>\n#include <memory>\n#include <variant>\n\nextern int g_largeur_min_console;', 1)
f.write_text(t, encoding="utf-8")
print("fenêtre de la console : large et redimensionnable, largeur minimum")
