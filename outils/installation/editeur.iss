; Programme d'installation et de mise à jour de l'outil de l'éditeur du catalogue commun (Inno Setup 6).
; Même application compilée avec OUTIL_EDITEUR=true ; installée à part d'Emplettes (autre AppId, autre dossier),
; ses données vont dans le sous-dossier « editeur » du dossier de données (dossier_application.dart).
; Compilé par la CI (job windows) : ISCC /DVersion=0.7.0 /DCommit=abc1234 /DSource=<dossier Release> /DSortie=<dossier>
; - installation pour l'utilisateur seul, sans droits d'administrateur (%LOCALAPPDATA%\Programs\Emplettes editeur) ;
; - relancer un programme plus récent met à jour en place (même AppId) : l'application ouverte est fermée,
;   les fichiers sont remplacés, les données (listes, foyer, sauvegardes, dans %APPDATA%) ne sont pas touchées ;
; - la désinstallation ne retire que les fichiers du programme, jamais les données.

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
  #define Icone "editeur.ico"
#endif
#ifndef Sortie
  #define Sortie "..\..\build"
#endif

[Setup]
AppId={{B4A7E29C-1D63-4F05-8C2E-7A90D4F1E6B3}
AppName=Emplettes éditeur
AppVersion={#Version} ({#Commit})
AppVerName=Emplettes éditeur {#Version}
VersionInfoVersion={#Version}
AppPublisher=Emplettes
AppPublisherURL=https://christianfrench.github.io/liste-de-courses/
AppSupportURL=https://christianfrench.github.io/liste-de-courses/aide.html
AppUpdatesURL=https://christianfrench.github.io/liste-de-courses/telecharger.html
DefaultDirName={localappdata}\Programs\Emplettes editeur
DefaultGroupName=Emplettes éditeur
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Sortie}
OutputBaseFilename=Emplettes-Editeur-Installation
SetupIconFile={#Icone}
UninstallDisplayIcon={app}\editeur.ico
UninstallDisplayName=Emplettes éditeur
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
Source: "editeur.ico"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
; Les fichiers de la version précédente sont remplacés en entier (pas de restes d'une ancienne compilation)
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{autoprograms}\Emplettes éditeur"; Filename: "{app}\liste_de_courses.exe"; IconFilename: "{app}\editeur.ico"
Name: "{autodesktop}\Emplettes éditeur"; Filename: "{app}\liste_de_courses.exe"; IconFilename: "{app}\editeur.ico"; Tasks: bureau

[Run]
Filename: "{app}\liste_de_courses.exe"; Description: "Ouvrir l'éditeur du catalogue"; Flags: nowait postinstall skipifsilent
