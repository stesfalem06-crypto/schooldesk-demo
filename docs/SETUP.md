# Set up Shamm School Management Systems

This program stays inside the school. It does not use the internet.

You need one school computer. That computer runs the server. Teachers use phones. The admin and the director use a Windows computer.

The school records stay on the school computer. An update does not delete them.

## 1. Put the server on a Windows computer

1. Copy `ShammSchool-Server-Setup.exe` onto the school computer.
2. Double-click it.
3. Click Yes when Windows asks to allow the change.
4. When it finishes, the server starts by itself. It also starts again after a restart.
5. Open the web browser. Go to `http://127.0.0.1:8741`.
6. You should see the school address, a square picture, and a box for the unlock code.
7. Type the unlock code. Click Unlock.
8. The first time, the sample school is ready. The names and 4-digit numbers are in `C:\ProgramData\ShammSchool\FIRST_LOGIN.txt`.

The firewall is opened for the school program only. Port 8741 is the school pages. Port 8742 is how phones find the computer.

## 2. Or put the server on a Raspberry Pi

Use a 64-bit Raspberry Pi.

**One line, if you already have the program file next to the script:**

1. Copy `schooldesk-server-linux-arm64` and `pi-setup.sh` into the same folder.
2. Open a terminal in that folder.
3. Run `sudo sh pi-setup.sh`.
4. On another computer, open `http://` and the Pi's address, then `:8741`. Example: `http://192.168.1.20:8741`.

**Or install the package:**

1. Copy `shamm-school-server_1.0.0_arm64.deb` to the Pi.
2. Run `sudo dpkg -i shamm-school-server_1.0.0_arm64.deb`.
3. The server starts by itself.

The Pi and the Windows computer keep the school records in the same kind of folder. To move the school, copy that folder from one computer to the other, then start the server again.

## 3. Open the program on a phone

1. Copy `app-release.apk` to the phone.
2. Open the file and allow the install.
3. Connect the phone to the school Wi-Fi. Not the mobile data.
4. Open Shamm School Management Systems.
5. Tap Find the school. The phone looks for the school computer.
6. If it does not find it, tap Scan the picture and point the camera at the square picture on the school computer. Or type the numbers under that picture.
7. Tap your name. Type the 4 numbers the admin gave you.

A teacher can enter marks when the phone is away from the school. The phone sends them when it is back on the school Wi-Fi.

## 4. Open the program on a Windows computer

1. Copy `ShammSchool-Client-Setup.exe` to the admin computer or the director's computer.
2. Double-click it and finish the install.
3. Open Shamm School Management Systems from the desktop.
4. Tap Find the school, or type the school address.

## 5. Sign in

1. Tap your name.
2. Type your 4 numbers.
3. Tap Go.

The admin sets those numbers. To change one:

1. Sign in as the admin.
2. Open Logins.
3. Set a new 4-digit number for that person.

## 6. Messages and calls

Messages are for staff only. Students and parents are not in this list.

1. Open Messages.
2. Tap All staff, or tap one person.
3. Type the message. Tap Send.
4. Tap the phone picture next to a name to call that person.

The call uses the school Wi-Fi only. Both people must be on that Wi-Fi. Tap End call when you are done.

## 7. The timetable

The admin or the director builds the week. A teacher only sees their own lessons and their own class.

1. Sign in as the admin or the director.
2. Open Plan week.
3. Build the week.
4. To print, save the PDF for one class or one teacher.

Days and periods start at Monday period 1 on the screen. The file stores them starting at 0. A break after period 4 is stored as break after index 3.

## 8. Update from a USB stick

The person who prepares the update keeps the private key. It is not in this project, and the build never uploads it.

The public key that every school copy trusts is `packaging/sms-update.pub`. It is also built into the server. The matching private key stays with the owner. To let GitHub Actions sign a sample bundle, set the repository secret `SMS_UPDATE_SIGNING_KEY` to that private key. If the secret is missing, the build publishes the programs and does not publish a bundle.

On the computer that prepares the update:

1. Use the private key you were given. Do not generate another key unless you also rebuild every school server with the new public key.
2. Keep the private key somewhere safe. Do not put it in git, and do not upload it as a build artifact.
3. Put the new program files in one folder. The names are `server-windows-amd64.exe`, `server-linux-arm64`, `server-linux-amd64`, `client.apk`, and `client-windows.exe`.
4. Run `go run ./server/cmd/updatekey -key /path/to/keys/update.priv -dir that-folder -version sms-v2 -schema 2 -out shamm-update.smsu`.
5. Copy `shamm-update.smsu` to a USB stick. Copy the bundle only. Do not copy the private key.

On the school computer:

1. Plug in the USB stick. The server looks for a file that ends in `.smsu`.
2. Or open `http://127.0.0.1:8741`, choose the file, and click Update.
3. The server checks the signature, copies the school records to a dated backup, then swaps the program.
4. The school records stay.
5. The next time a phone or a Windows app connects, it says **Update available, install**. Tap Install.

If the new program does not start, the previous program is put back. The school records are not deleted. You can also click **Put the previous program back** on the status page.

## 9. What the sample release is for

The files on the `sms-v1` release are for trying the program. They trust the public key in `packaging/sms-update.pub`. The release does not include a private key. A sample bundle is attached only when the `SMS_UPDATE_SIGNING_KEY` secret is set.
