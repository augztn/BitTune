# BitWave for Linux

This module is the native Compose Desktop entry point and Linux AppImage packaging target.

## Build

Requirements:

- Linux x86_64
- JDK 17
- Internet access for Gradle dependency resolution
- FUSE 2 on the host to run the resulting AppImage on many distributions

From the repository root:

```bash
chmod +x gradlew
./gradlew --no-daemon :desktop:packageReleaseAppImage
```

Or run `./scripts/build-linux-appimage.sh`. The artifact is written to:

`desktop/build/compose/binaries/main-release/appimage/`

The GitHub Actions workflow `.github/workflows/linux-appimage.yml` also builds and uploads the AppImage as a workflow artifact for the `build/linux-appimage` branch.

## Current desktop scope

This is the first native Linux host, not a claim that every Android feature has been ported. The current Android application entry point and much of its runtime depend on Android Activity, Context, Media3, WebView, foreground-service and USB APIs. The Linux host intentionally does not expose those features as working until their platform implementations exist. The desktop player experience can be migrated onto the existing Kotlin shared modules in follow-up work.
