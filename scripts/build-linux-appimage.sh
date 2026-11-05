#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly APP_VERSION="1.9"
readonly APP_IMAGE_DIR="$ROOT/desktopApp/build/compose/binaries/main/app/BitChord"
readonly OUTPUT_DIR="$ROOT/dist"
readonly OUTPUT="$OUTPUT_DIR/BitTune-${APP_VERSION}-linux-x86_64.AppImage"
readonly TOOLS_DIR="$ROOT/build/tools"
readonly APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

[[ "$(uname -s)" == "Linux" ]] || { echo "Build must run on Linux." >&2; exit 2; }
[[ "$(uname -m)" == "x86_64" ]] || { echo "Only Linux x86_64 is supported." >&2; exit 2; }
command -v java >/dev/null 2>&1 || { echo "JDK 21 is required." >&2; exit 2; }
JAVA_MAJOR="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2; exit}')"
[[ "$JAVA_MAJOR" == "21" ]] || { echo "Expected JDK 21, found ${JAVA_MAJOR:-unknown}." >&2; exit 2; }
for tool in curl file; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Required tool '$tool' is missing." >&2; exit 2; }
done

mkdir -p "$TOOLS_DIR" "$OUTPUT_DIR"
if [[ ! -x "$APPIMAGETOOL" ]]; then
  curl --fail --location --retry 3 --output "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
  chmod +x "$APPIMAGETOOL"
fi

./gradlew --no-daemon -Pbitchord.target=linux -Pbitchord.version="$APP_VERSION" :desktopApp:createDistributable
[[ -x "$APP_IMAGE_DIR/bin/BitChord" ]] || {
  echo "Compose Desktop did not create the expected Linux launcher: $APP_IMAGE_DIR/bin/BitChord" >&2
  exit 1
}

desktopApp/packaging/appimage.sh "$APP_IMAGE_DIR" "$OUTPUT" "$APPIMAGETOOL"
file "$OUTPUT" | grep -q 'ELF 64-bit' || { file "$OUTPUT" >&2; exit 1; }

VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT
(
  cd "$VERIFY_DIR"
  APPIMAGE_EXTRACT_AND_RUN=1 "$OUTPUT" --appimage-extract >/dev/null
  test -x squashfs-root/AppRun
  test -x squashfs-root/usr/bin/BitChord
  test -f squashfs-root/bittune.desktop
)
sha256sum "$OUTPUT" | tee "$OUTPUT.sha256"
ls -lh "$OUTPUT"
echo "Verified Linux AppImage: $OUTPUT"
