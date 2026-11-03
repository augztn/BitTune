#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This build script must run on Linux." >&2
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

chmod +x ./gradlew
./gradlew --no-daemon :desktop:packageReleaseAppImage

ARTIFACT_DIR="$ROOT/desktop/build/compose/binaries/main-release/appimage"
shopt -s nullglob
artifacts=("$ARTIFACT_DIR"/*.AppImage)
if (( ${#artifacts[@]} != 1 )); then
  echo "Expected one AppImage in $ARTIFACT_DIR; found ${#artifacts[@]}." >&2
  exit 1
fi

chmod +x "${artifacts[0]}"
sha256sum "${artifacts[0]}"
printf 'AppImage created: %s\n' "${artifacts[0]}"
