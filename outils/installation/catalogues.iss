; Programme d'installation et de mise à jour d'« Emplettes · catalogues » (22/11/2026, Aristide) : gestion des
; catalogues (produits, marques, recettes), séparée de la console technique. Logiciel Windows natif (C# WinForms,
; windows-catalogues/, publié autonome win-x64 : rien à installer d'autre) ; installé à part (autre AppId, autre dossier).
; catalogues.ico est provisoire (copie de editeur.ico) : la remplacer par l'icône d'Aristide suffit.

#ifndef Version
  #define Version "0.0.0"
#endif
#ifndef Commit
  #define Commit "local"
#endif
#ifndef Source
  #define Source "..\..\build\windows\x64\runner\Release"
#endif
#ifndef Icone
  #define Icone "catalogues.ico"
#endif
#ifndef Sortie
  #define Sortie "..\..\build"
#endif

[Setup]
AppId={{9DE91D76-E1A6-4820-A3BD-409EFC6A2D6E}
AppName=Emplettes catalogues
AppVersion={#Version} ({#Commit})
AppVerName=Emplettes catalogues {#Version}
VersionInfoVersion={#Version}
AppPublisher=Emplettes
AppPublisherURL=https://christianfrench.github.io/liste-de-courses/
AppSupportURL=https://christianfrench.github.io/liste-de-courses/aide.html
AppUpdatesURL=https://christianfrench.github.io/liste-de-courses/telecharger.html
DefaultDirName={localappdata}\Programs\Emplettes catalogues
DefaultGroupName=Emplettes catalogues
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Sortie}
OutputBaseFilename=Emplettes-Catalogues-Installation
SetupIconFile={#Icone}
UninstallDisplayIcon={app}\catalogues.ico
UninstallDisplayName=Emplettes catalogues
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=force
RestartApplications=no
UsePreviousTasks=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Mettre une icône sur le Bureau"; Flags: checkedonce

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "catalogues.ico"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
; Les fichiers de la version précédente sont remplacés en entier (pas de restes d'une ancienne compilation)
Type: filesandordirs; Name: "{app}\data"
; 22/11/2026 : la première version (Flutter) laissait son programme et ses bibliothèques ; tout ce qui n'est pas du
; nouveau logiciel est retiré avant la copie (les données, dans %APPDATA%, ne sont jamais touchées).
Type: files; Name: "{app}\liste_de_courses.exe"
Type: files; Name: "{app}\flutter_windows.dll"
Type: files; Name: "{app}\*_plugin.dll"
Type: files; Name: "{app}\sqlite3.dll"
Type: files; Name: "{app}\msvcp140.dll"
Type: files; Name: "{app}\vcruntime140.dll"
Type: files; Name: "{app}\vcruntime140_1.dll"
Type: filesandordirs; Name: "{app}\recettes-illustrations"

[Icons]
Name: "{autoprograms}\Emplettes catalogues"; Filename: "{app}\EmplettesCatalogues.exe"; IconFilename: "{app}\catalogues.ico"
Name: "{autodesktop}\Emplettes catalogues"; Filename: "{app}\EmplettesCatalogues.exe"; IconFilename: "{app}\catalogues.ico"; Tasks: bureau

[Run]
Filename: "{app}\EmplettesCatalogues.exe"; Description: "Ouvrir Emplettes · catalogues"; Flags: nowait postinstall skipifsilent
