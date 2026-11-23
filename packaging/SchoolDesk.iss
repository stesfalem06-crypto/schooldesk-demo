; Installs the Shamm school server as a Windows service.
; The desktop app has its own installer.

#define AppName "Shamm School Management Systems"
#define AppVersion "1.0.0"

[Setup]
AppId={{A7B3E1C4-6D20-4F5A-9B11-0C8E2F4A6D31}}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\ShammSchool
DefaultGroupName=Shamm School
OutputBaseFilename=ShammSchool-Server-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=yes
SourceDir=..
OutputDir=dist
SetupIconFile=app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\schooldesk-server.exe

[Files]
Source: "dist\schooldesk-server-windows-amd64.exe"; DestDir: "{app}"; DestName: "schooldesk-server.exe"

[Icons]
Name: "{group}\School server status"; Filename: "http://127.0.0.1:8741/"
Name: "{commondesktop}\School server status"; Filename: "http://127.0.0.1:8741/"

[Run]
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Shamm School"" dir=in action=allow protocol=TCP localport=8741"; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Shamm School discovery"" dir=in action=allow protocol=UDP localport=8742"; Flags: runhidden
Filename: "{app}\schooldesk-server.exe"; Parameters: "--install-service --data ""{commonappdata}\ShammSchool"""; Flags: runhidden waituntilterminated

[UninstallRun]
Filename: "sc"; Parameters: "stop ShammSchool"; Flags: runhidden
Filename: "sc"; Parameters: "delete ShammSchool"; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Shamm School"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Shamm School discovery"""; Flags: runhidden
