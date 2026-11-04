; Programme d'installation et de mise à jour d'Emplettes pour Windows (Inno Setup 6).
; Compilé par la CI (job windows) : ISCC /DVersion=0.7.0 /DCommit=abc1234 /DSource=<dossier Release> /DIcone=<app_icon.ico> /DSortie=<dossier>
; - installation pour l'utilisateur seul, sans droits d'administrateur (%LOCALAPPDATA%\Programs\Emplettes) ;
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
  #define Icone "..\..\windows\runner\resources\app_icon.ico"
#endif
#ifndef Sortie
  #define Sortie "..\..\build"
#endif

[Setup]
AppId={{6E5B1C2A-4F7D-4B8E-9A31-E3D0C7B25F41}
AppName=Emplettes
AppVersion={#Version} ({#Commit})
AppVerName=Emplettes {#Version}
VersionInfoVersion={#Version}
AppPublisher=Emplettes
AppPublisherURL=https://christianfrench.github.io/liste-de-courses/
AppSupportURL=https://christianfrench.github.io/liste-de-courses/aide.html
AppUpdatesURL=https://christianfrench.github.io/liste-de-courses/telecharger.html
DefaultDirName={localappdata}\Programs\Emplettes
DefaultGroupName=Emplettes
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Sortie}
OutputBaseFilename=Emplettes-Installation
SetupIconFile={#Icone}
UninstallDisplayIcon={app}\liste_de_courses.exe
UninstallDisplayName=Emplettes
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=force
RestartApplications=no
UsePreviousTasks=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Mettre une icône sur le Bureau"; Flags: unchecked

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Les fichiers de la version précédente sont remplacés en entier (pas de restes d'une ancienne compilation)
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{autoprograms}\Emplettes"; Filename: "{app}\liste_de_courses.exe"
Name: "{autodesktop}\Emplettes"; Filename: "{app}\liste_de_courses.exe"; Tasks: bureau

[Run]
Filename: "{app}\liste_de_courses.exe"; Description: "Ouvrir Emplettes"; Flags: nowait postinstall skipifsilent
