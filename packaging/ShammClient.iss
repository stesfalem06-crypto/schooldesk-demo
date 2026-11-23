; Installs the Windows program for the admin and the director.

#define AppName "Shamm School Management Systems"
#define AppVersion "1.0.0"

[Setup]
AppId={{B8C4F2D5-7E31-4A6B-8C22-1D9F3A5B7E42}}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\ShammSchoolApp
DefaultGroupName=Shamm School
OutputBaseFilename=ShammSchool-Client-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=yes
SourceDir=..
OutputDir=dist
SetupIconFile=app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\schooldesk.exe

[Files]
Source: "dist\windows-app\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Shamm School Management Systems"; Filename: "{app}\schooldesk.exe"
Name: "{commondesktop}\Shamm School Management Systems"; Filename: "{app}\schooldesk.exe"

[Run]
Filename: "{app}\schooldesk.exe"; Description: "Open Shamm School Management Systems"; Flags: nowait postinstall skipifsilent
