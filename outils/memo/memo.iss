; Installateur Windows du Mémo Emplettes (19/11/2026). ISCC /DVersion=1.1.0 /DSource=<Release> /DIcone=<ico> /DSortie=<dossier>
#ifndef Version
  #define Version "1.0.0"
#endif
[Setup]
AppId={{9B2E4C71-3D5A-4E8F-B6C2-7A1D0F3E5B92}
AppName=Mémo Emplettes
AppVersion={#Version}
AppPublisher=Emplettes
DefaultDirName={localappdata}\Programs\Memo Emplettes
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Sortie}
OutputBaseFilename=Memo-Emplettes-Installation
SetupIconFile={#Icone}
UninstallDisplayIcon={app}\memo_emplettes.exe
UninstallDisplayName=Mémo Emplettes
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=force
UsePreviousTasks=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "demarrage"; Description: "Ouvrir le Mémo au démarrage de Windows"
Name: "bureau"; Description: "Mettre une icône sur le Bureau"; Flags: unchecked

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Mémo Emplettes"; Filename: "{app}\memo_emplettes.exe"
Name: "{userdesktop}\Mémo Emplettes"; Filename: "{app}\memo_emplettes.exe"; Tasks: bureau
Name: "{userstartup}\Mémo Emplettes"; Filename: "{app}\memo_emplettes.exe"; Tasks: demarrage

[Run]
Filename: "{app}\memo_emplettes.exe"; Description: "Ouvrir le Mémo"; Flags: nowait postinstall skipifsilent
