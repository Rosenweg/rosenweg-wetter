; SPDX-License-Identifier: GPL-3.0-or-later
; Inno-Setup-Skript fuer Rosenweg Wetter (Windows-Installer, .exe), aus der
; App-Vorlage von rosenweg-basis (Muster: rosenweg-salz, rosenweg-vm).
;
;   iscc /DVersion=1.0.0 /DQuelle=build\windows\x64\runner\Release windows\installer\rosenweg-wetter.iss
;
; Warum Inno Setup und nicht MSIX: MSIX verlangt ein Signierzertifikat, dem
; der Rechner vertraut (sonst laesst Windows es gar nicht installieren); das
; Haus hat (noch) keines. Ein Inno-Installer laeuft auch unsigniert (SmartScreen
; fragt dann einmal nach), installiert ohne Adminrechte fuer die Person
; (%LOCALAPPDATA%\Programs) und bringt eine saubere Deinstallation mit.
; Mit Zertifikat: Secrets WINDOWS_ZERTIFIKAT_PFX/-PASSWORT setzen, dann signiert
; der Release-Workflow (rosenweg-basis .github/workflows/app.yml) Installer und App.
;
; Ergebnis: build\windows-installer\Rosenweg-Wetter-<Version>-Setup.exe

#ifndef Version
  #define Version "0.0.0"
#endif
#ifndef Quelle
  #define Quelle "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; Feste Kennung je App (neue-app.sh setzt eine neue): Updates ersetzen die
; vorhandene Installation. Nie aendern, sonst liegen zwei Installationen nebeneinander.
AppId={{20830488-E072-4086-8B61-CE69BDFC7474}
AppName=Rosenweg Wetter
AppVersion={#Version}
AppVerName=Rosenweg Wetter {#Version}
AppPublisher=Rosenweg
AppPublisherURL=https://www.rosenweg4303.ch/apps
DefaultDirName={autopf}\Rosenweg Wetter
DefaultGroupName=Rosenweg
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\windows-installer
OutputBaseFilename=Rosenweg-Wetter-{#Version}-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rosenweg_wetter.exe
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Quelle}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Rosenweg Wetter"; Filename: "{app}\rosenweg_wetter.exe"
Name: "{autodesktop}\Rosenweg Wetter"; Filename: "{app}\rosenweg_wetter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\rosenweg_wetter.exe"; Description: "{cm:LaunchProgram,Rosenweg Wetter}"; Flags: nowait postinstall skipifsilent
