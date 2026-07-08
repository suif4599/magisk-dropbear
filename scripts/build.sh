#!/usr/bin/env bash

# Master build orchestrator for magisk-dropbear.
#
# Runs the full pipeline:
#   1. cross-compile dropbear binaries (via nix develop + build-android.sh)
#   2. reset the dropbear submodule to a clean state
#      (this is the "revert patch" step that used to be manual — patches live
#      in the outer repo, so the submodule must be left pristine between runs)
#   3. package the Magisk module zip (build-magisk.sh)
#
# Usage:
#   scripts/build.sh [--push] [-- build-android.sh args...]
#
# Examples:
#   scripts/build.sh
#   scripts/build.sh --push
#   scripts/build.sh -- --no-clean --quiet

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${DROPBEAR_SRC:-${ROOT}/dropbear}"
cd "$ROOT"

push=0
passthrough=0
android_args=()
for arg in "$@"; do
  if [ "$passthrough" -eq 1 ]; then
    android_args+=("$arg")
  elif [ "$arg" = "--" ]; then
    passthrough=1
  elif [ "$arg" = "--push" ]; then
    push=1
  elif [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
    sed -n '2,^$/p' "$0"
    exit 0
  else
    android_args+=("$arg")
  fi
done

if ! git submodule status -- "$SRC" 2>/dev/null | grep -q '^[+ ]'; then
  echo "ERROR: dropbear submodule not initialized at $SRC" >&2
  echo "       run: git submodule update --init" >&2
  exit 1
fi

echo "### [1/3] cross-compiling dropbear via nix develop"
if [ ${#android_args[@]} -eq 0 ]; then
  nix develop .#cross --impure --command bash scripts/build-android.sh
else
  nix develop .#cross --impure --command bash scripts/build-android.sh "${android_args[@]}"
fi

echo "### [2/3] resetting dropbear submodule to clean state"
# Revert tracked modifications (the applied patch) and drop every untracked
# file (localoptions.h, build outputs, ignored artifacts). -x is intentional:
# upstream's .gitignore lists config.h, obj/, built binaries, etc., all of
# which are stale after a build and must go so the next run starts clean.
git -C "$SRC" checkout -- .
git -C "$SRC" clean -fdxq

echo "### [3/3] packaging magisk module"
if [ "$push" -eq 1 ]; then
  bash scripts/build-magisk.sh --push
else
  bash scripts/build-magisk.sh
fi
