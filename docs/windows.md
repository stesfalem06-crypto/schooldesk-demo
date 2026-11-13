# Windows installer

The school computer program is a normal Windows app. The server program can also run on that same PC when a Raspberry Pi is not available.

This repository can build the server `.exe` on Linux. The desktop app `.exe` has to be built on Windows. GitHub Actions does both and then builds `SchoolDesk-Setup.exe`.

## On a Windows PC

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows) (stable) and enable Windows desktop.
2. Install [Go](https://go.dev/dl/) 1.22 or newer.
3. Install [Inno Setup 6](https://jrsoftware.org/isdl.php).
4. In this folder:

```
cd server
go test ./...
set CGO_ENABLED=0
go build -trimpath -ldflags "-s -w" -o ..\dist\schooldesk-server-windows-amd64.exe .\cmd\schooldesk-server

cd ..\app
flutter pub get
flutter build windows --release
mkdir ..\dist\windows-app
xcopy /E /I build\windows\x64\runner\Release ..\dist\windows-app

cd ..
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" packaging\SchoolDesk.iss
```

The installer is `dist\SchoolDesk-Setup.exe`.

It copies the app and the server, starts the server when Windows starts, and keeps the school records in `C:\ProgramData\SchoolDesk`. The Windows PCs do not keep the real records. They talk to the server.

## From GitHub Actions

Push the repository and open the Build workflow. Download the `windows-installer` artifact. That file is `SchoolDesk-Setup.exe`.

## First opening

The server is locked until an unlock code is entered. The lock screen shows a short computer number and a QR picture. After it is unlocked, sign in with the names in `C:\ProgramData\SchoolDesk\FIRST_LOGIN.txt`.
