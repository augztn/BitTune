#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly APP_NAME="BitWave"
readonly APP_VERSION="1.0.0"
readonly COMPOSE_APP_DIR="$ROOT/desktop/build/compose/binaries/main/app/$APP_NAME"
readonly APPDIR="$ROOT/build/appimage/$APP_NAME.AppDir"
readonly TOOLS_DIR="$ROOT/build/tools"
readonly APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
readonly OUTPUT_DIR="$ROOT/dist"
readonly OUTPUT="$OUTPUT_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
readonly APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This build script must run on Linux." >&2
  exit 2
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "This build currently supports Linux x86_64 only (found $(uname -m))." >&2
  exit 2
fi

if ! command -v java >/dev/null 2>&1; then
  echo "JDK 17 is required. Install a Java 17 runtime and try again." >&2
  exit 2
fi

JAVA_MAJOR="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2; exit}')"
if [[ "$JAVA_MAJOR" != "17" ]]; then
  echo "Expected JDK 17, found ${JAVA_MAJOR:-unknown}." >&2
  exit 2
fi

for tool in curl file; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool '$tool' is missing." >&2
    exit 2
  fi
done

chmod +x ./gradlew
./gradlew --no-daemon :desktop:packageAppImage

if [[ ! -x "$COMPOSE_APP_DIR/bin/$APP_NAME" ]]; then
  echo "Compose Desktop did not create the expected launcher: $COMPOSE_APP_DIR/bin/$APP_NAME" >&2
  find "$ROOT/desktop/build/compose/binaries" -maxdepth 6 -type f -print >&2 || true
  exit 1
fi

if [[ ! -f "$COMPOSE_APP_DIR/lib/$APP_NAME.png" ]]; then
  echo "Expected application icon was not found: $COMPOSE_APP_DIR/lib/$APP_NAME.png" >&2
  exit 1
fi

mkdir -p "$TOOLS_DIR" "$OUTPUT_DIR"
if [[ ! -x "$APPIMAGETOOL" ]]; then
  echo "Downloading official AppImageKit appimagetool..."
  curl --fail --location --retry 3 --output "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
  chmod +x "$APPIMAGETOOL"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/bin"
cp -a "$COMPOSE_APP_DIR" "$APPDIR/usr/lib/$APP_NAME"

ln -s "../lib/$APP_NAME/bin/$APP_NAME" "$APPDIR/usr/bin/$APP_NAME"
cp "$COMPOSE_APP_DIR/lib/$APP_NAME.png" "$APPDIR/$APP_NAME.png"
ln -s "$APP_NAME.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/$APP_NAME.desktop" <<'DESKTOP'
[Desktop Entry]
Name=BitWave
Comment=BitWave music player
Exec=BitWave %U
TryExec=BitWave
Icon=BitWave
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;
StartupNotify=true
DESKTOP

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$HERE/usr/bin/BitWave" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

rm -f "$OUTPUT"
echo "Creating AppImage..."
APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
chmod +x "$OUTPUT"

if ! file "$OUTPUT" | grep -q 'ELF 64-bit'; then
  echo "Generated output is not a 64-bit Linux executable." >&2
  file "$OUTPUT" >&2
  exit 1
fi

VERIFY_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT
(
  cd "$VERIFY_DIR"
  "$OUTPUT" --appimage-extract >/dev/null
  test -x squashfs-root/AppRun
  test -x squashfs-root/usr/bin/$APP_NAME
)

sha256sum "$OUTPUT"
printf 'AppImage created and archive-verified: %s\n' "$OUTPUT"
