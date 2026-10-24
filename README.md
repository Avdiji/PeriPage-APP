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

Pair the printer in the system Bluetooth settings first. On Windows, pick the outgoing COM port of the printer.

## Docs

- [docs/architecture.txt](docs/architecture.txt): layers, file tree, flows
- [docs/protocol.md](docs/protocol.md): printer command reference
- [docs/mockups](docs/mockups): UI mockups (`app.html`, `desktop.html`)
