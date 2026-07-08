#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${DROPBEAR_SRC:-${ROOT}/dropbear}"
OUT="${ROOT}/build-android"
TEMPLATE="${ROOT}/magisk-template"
STAGING="${OUT}/staging"
BINARIES="dropbear dbclient dropbearkey dropbearconvert scp"

push=0
while [ $# -gt 0 ]; do
  case "$1" in
    --push) push=1 ;;
    -h|--help)
      sed -n '2,^$/p' "$0"
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# Derive version from upstream's most recent tag, e.g. DROPBEAR_2026.92 -> v2026.92
tag="$(git -C "$SRC" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -z "$tag" ]; then
  echo "ERROR: no git tag found in $SRC" >&2
  exit 1
fi
raw="${tag#DROPBEAR_}"
version="v${raw}"
# versionCode scheme: YYYY*10000 + minor (e.g. 2026.92 -> 20260092)
IFS='.' read -r _major _minor <<<"$raw"
version_code="$((_major * 10000 + _minor))"

zip="${OUT}/magisk-dropbear-${version}.zip"

echo "==> upstream tag : $tag"
echo "==> version      : $version"
echo "==> versionCode  : $version_code"
echo "==> zip          : $zip"

for bin in $BINARIES; do
  if [ ! -x "$OUT/$bin" ]; then
    echo "ERROR: $OUT/$bin not found." >&2
    echo "       Run scripts/build-android.sh first." >&2
    exit 1
  fi
done

rm -f "$zip"
rm -rf "$STAGING"
mkdir -p "$STAGING/bin"

# Copy template tree, then render module.prop with the version placeholders.
cp -r "$TEMPLATE/." "$STAGING/"
sed -e "s/@VERSION@/$version/g" \
    -e "s/@VERSION_CODE@/$version_code/g" \
    "$TEMPLATE/module.prop" > "$STAGING/module.prop"

for bin in $BINARIES; do
  cp -f "$OUT/$bin" "$STAGING/bin/$bin"
done

( cd "$STAGING" && zip -qr "$zip" . )
echo "==> wrote $zip"

if [ "$push" -eq 1 ]; then
  if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: --push requested but adb not found in PATH" >&2
    exit 1
  fi
  adb push "$zip" /sdcard/Download
fi
