# Android app

Teachers use the Android app. It can record marks with no network and send them when the phone is on the school Wi-Fi.

## Build a signed apk

Install Flutter stable and the Android SDK. From the `app` folder:

```
keytool -genkeypair -v -keystore schooldesk-release.jks -storepass schooldesk -keypass schooldesk -alias schooldesk -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=SchoolDesk, OU=9 Multimedia and IT Solutions, O=9 Multimedia and IT Solutions, L=Asmara, C=ER"
```

Keep `schooldesk-release.jks` private. Do not commit it.

Create `android/key.properties`:

```
storePassword=schooldesk
keyPassword=schooldesk
keyAlias=schooldesk
storeFile=../../schooldesk-release.jks
```

`android/app/build.gradle.kts` is already set to read that file when it exists. Then:

```
flutter pub get
flutter build apk --release
```

The apk is `build/app/outputs/flutter-apk/app-release.apk`.

Change the store password before a school uses the apk. The sample password above is only so a build can be made.

GitHub Actions builds this apk as the `android-apk` artifact. The keystore it creates is only for that build and is not saved.
