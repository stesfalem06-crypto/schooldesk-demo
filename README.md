# Shamm School Management Systems

Shamm School Management Systems is the offline school record for one school. It runs on the school network. It does not use the internet.

The setup steps for a school are in [docs/SETUP.md](docs/SETUP.md).

Each school has:

- a small server on a Raspberry Pi, or on a Windows PC if there is no Pi
- a Windows or Mac app for the school admin and the director
- an Android app for teachers

The phone can keep marks when it is away from the school Wi-Fi and send them later.

## Sign in

The first start loads a sample school. The names are also written on the server as `FIRST_LOGIN.txt`.

| Name | Password | Who |
| --- | --- | --- |
| admin | admin1850 | School admin |
| director | director1850 | Director |
| hanna | hanna1850 | Homeroom, Grade 3A |
| samuel | samuel1850 | Homeroom, Grade 8A, and mathematics |
| meron | meron1850 | English |
| dawit | dawit1850 | Homeroom, Grade 11A, and physics |

Change these after the real school is set up. In Settings, the admin can remove the sample students and money. The admin login stays.

## Unlock

The server is locked until an unlock code is entered. The lock screen shows a short computer number and a QR picture. The code is checked on the school computer. It is tied to that computer and to the school name in the code.

See [docs/licensing.md](docs/licensing.md) for the code format. The signing key is not in this repository.

## Run the server

```
cd server
go test ./...
go run ./cmd/schooldesk-server --data ./data --addr :8741
```

Open `http://<school-computer>:8741` for the unlock page. The apps look for a computer named `_schooldesk._tcp` or you type the number once. It is remembered.

The same screens can be opened in a browser with `flutter run -d web-server` from the `app` folder. The supported installs are still the Windows app and the Android app.

## Raspberry Pi

Build the arm64 server, copy it next to `packaging/pi-setup.sh`, and run:

```
sudo sh pi-setup.sh
```

Details are in that script. A USB stick can be the night backup folder.

## Windows installer

The server program for Windows can be built here:

```
sh scripts/build-server.sh
```

The desktop `.exe` installer is built on Windows. The steps are in [docs/windows.md](docs/windows.md). GitHub Actions file `.github/workflows/build.yml` builds `SchoolDesk-Setup.exe` on a Windows runner.

## Mac disk image

The same workflow builds `SchoolDesk.dmg` on a Mac runner. Opening the app starts the bundled server on that Mac. How to open the unsigned app is in [docs/macos.md](docs/macos.md). A separate `macos-demo` artifact, `SchoolDesk-Demo.dmg`, loads a sample school and does not ask for an unlock code. The production builds still do.

## Android apk

Steps and the release keystore are in [docs/android.md](docs/android.md). The same workflow builds a signed apk.

## Guides

- [Teacher](docs/guides/teacher.md)
- [Homeroom teacher](docs/guides/homeroom.md)
- [School admin](docs/guides/admin.md)
- [Director](docs/guides/director.md)

How the numbers are worked out: [docs/calculations.md](docs/calculations.md).

## What is still outside this repository

The private key that signs unlock codes stays with the existing unlocker app. This project only checks codes. A code for a different computer number is rejected. Expiry day 0 means the code never ends. Max devices 0 means unlimited.
