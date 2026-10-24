# PeriPage-APP

A reverse-engineered desktop and mobile app for PeriPage thermal printers, built with Flutter for Android and Windows.

It has three views:
- **Draft:** pick an image or PDF, adjust the settings, print.
- **History:** reprint anything with the exact settings it was printed with.
- **Device:** printer setup, live status with print progress, and printer defaults.

## Setup

```sh
fvm install            # Flutter version pinned in .fvmrc
fvm flutter pub get
fvm flutter test
fvm flutter run -d windows   # or an Android device
```

Requirements:
- **Windows:** Developer Mode (needed for plugin symlinks) and Visual Studio with the *Desktop development with C++* workload.
- **Android:** the Android SDK, and minSdk 24.

The app finds printers in range by itself and pairs them on the first connect. No COM ports or system settings are needed.

## Releases

Pushing any tag creates a GitHub release named after the tag (`.github/workflows/release.yml`):

```sh
git tag v1.0.0
git push origin v1.0.0
```

The workflow analyzes and tests the code, builds both platforms and attaches:
- `PeriPage-<tag>-windows-x64.zip`: unzip it and run `PeriPage.exe`. The exe needs the DLLs and the `data` folder next to it.
- `PeriPage-<tag>.apk`: install it on Android.

Tags like `v1.2.3` or `1.2.3` also set the app version.

### Android signing (one-time)

Android only installs an update over an earlier version if both are signed with the same key. Without signing secrets, the workflow signs with a throwaway debug key and prints a warning. To create a key and store it as repository secrets:

```sh
keytool -genkey -v -keystore peripage-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias peripage
base64 -w0 peripage-release.jks   # PowerShell: [Convert]::ToBase64String([IO.File]::ReadAllBytes("peripage-release.jks"))
```

Add the following under *Settings → Secrets and variables → Actions*:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | output of the base64 command |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `peripage` |
| `ANDROID_KEY_PASSWORD` | key password |

Keep the `.jks` file and its passwords safe and out of the repo. If you lose them, existing installs can't be updated.

## Docs

- [docs/architecture.txt](docs/architecture.txt): layers, file tree, flows
- [docs/protocol.md](docs/protocol.md): printer command reference
- [docs/mockups](docs/mockups): UI mockups (`app.html`, `desktop.html`)
