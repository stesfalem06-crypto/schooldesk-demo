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

`SchoolDesk-Demo.dmg` is a separate build for looking around when there is no school server. It is the `macos-demo` artifact. The production disk image is unchanged and still asks for an unlock code.

Open it the same way as the school app. It starts its own server, loads a sample school, and does not ask for an unlock code. A small DEMO badge stays on the screen. On the sign-in screen, choose Admin, Director, Homeroom teacher, or Subject teacher. The sample records stay in `Library/Application Support/SchoolDesk Demo`.

The office app in this disk image is built for Apple silicon. The server inside it runs on both Apple silicon and Intel.
