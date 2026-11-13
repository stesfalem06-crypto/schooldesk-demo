; Inno Setup script for the Windows school computer.
; Build the two programs first (see docs/windows.md), then compile this with Inno Setup.

#define AppName "SchoolDesk"
#define AppVersion "1.0.0"

[Setup]
AppId={{A7B3E1C4-6D20-4F5A-9B11-0C8E2F4A6D31}}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\SchoolDesk
DefaultGroupName=SchoolDesk
OutputBaseFilename=SchoolDesk-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=yes
SourceDir=..
OutputDir=dist

[Files]
Source: "dist\schooldesk-server-windows-amd64.exe"; DestDir: "{app}"; DestName: "schooldesk-server.exe"
Source: "dist\windows-app\*"; DestDir: "{app}\app"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\SchoolDesk"; Filename: "{app}\app\schooldesk.exe"
Name: "{commondesktop}\SchoolDesk"; Filename: "{app}\app\schooldesk.exe"
Name: "{group}\School server"; Filename: "{app}\schooldesk-server.exe"; Parameters: "--data ""{commonappdata}\SchoolDesk"""

[Run]
Filename: "schtasks"; Parameters: "/Create /F /SC ONSTART /RL HIGHEST /TN SchoolDesk /TR ""\""{app}\schooldesk-server.exe\"" --data \""{commonappdata}\SchoolDesk\"""""; Flags: runhidden
Filename: "{app}\schooldesk-server.exe"; Parameters: "--data ""{commonappdata}\SchoolDesk"""; Flags: nowait postinstall skipifsilent runhidden
Filename: "{app}\app\schooldesk.exe"; Description: "Open SchoolDesk"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /F /TN SchoolDesk"; Flags: runhidden
