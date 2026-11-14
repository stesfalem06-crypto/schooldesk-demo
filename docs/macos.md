# Mac disk image

The school office can use a Mac when there is no Windows PC. The disk image holds the office app and the school server.

Opening the app starts the server on this Mac. The records stay in the home folder at `Library/Application Support/SchoolDesk`. The app then uses `http://127.0.0.1:8741`. Phones on the same network can still find the school computer. Choosing "Use a different computer" keeps that choice.

## From GitHub Actions

Push the repository and open the Build workflow. Download the `macos-installer` artifact. That file is `SchoolDesk.dmg`.

## First opening

The disk image is not signed with an Apple certificate. macOS will say it cannot check the developer.

1. Open `SchoolDesk.dmg`.
2. Drag SchoolDesk to Applications, or open it from the disk image.
3. Control-click SchoolDesk and choose Open, then choose Open again.
4. If macOS still blocks it, open System Settings, go to Privacy & Security, and choose Open Anyway.

The server is locked until an unlock code is entered. The lock screen shows a short computer number and a QR picture. After it is unlocked, sign in with the names in `Library/Application Support/SchoolDesk/FIRST_LOGIN.txt`.

## Demo disk image

`SchoolDesk-Demo.dmg` is a separate build. It does not contain a server, it does not use the network, and it does not ask for an unlock code or a password. The production disk image is unchanged and still asks for an unlock code.

The demo opens on Choose who you are. Tap School admin, Director, Homeroom teacher (Samuel, Grade 8A), or Subject teacher (Meron, English). Switch role is in the header. Reset sample data puts the sample school back. Records stay in `Library/Application Support/SchoolDesk Demo`. Reports are written to `Documents/SchoolDesk`.

A download from Drive or the browser is marked with quarantine. On macOS 26, Gatekeeper then refuses an ad-hoc signed app, so a double-click can look like the app is not opening. Use one of these:

1. System Settings, Privacy & Security, scroll to the message about SchoolDesk Demo, choose Open Anyway, then Open.
2. In Terminal: `xattr -dr com.apple.quarantine` on `SchoolDesk Demo.app`, then open it.
3. In the disk image, open `Open SchoolDesk Demo.command`. If macOS stops that file too, Control-click it and choose Open.

The office app in this disk image is built for Apple silicon. The server inside it runs on both Apple silicon and Intel.
