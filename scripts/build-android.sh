#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${DROPBEAR_SRC:-${ROOT}/dropbear}"
OUT="${ROOT}/build-android"
LOG="${OUT}/build.log"

clean=1
verbose=1
host=""
programs="dropbear dbclient dropbearkey dropbearconvert scp"
extra_configure_flags=()

while [ $# -gt 0 ]; do
  case "$1" in
    --no-clean) clean=0 ;;
    --quiet) verbose=0 ;;
    --host=*) host="${1#--host=}" ;;
    --programs=*) programs="${1#--programs=}" ;;
    --enable-*|--disable-*|--with-*|--without-*) extra_configure_flags+=("$1") ;;
    -h|--help)
      sed -n '2,^$/p' "$0"
      exit 0 ;;
      *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "${CC:-}" ] || [ ! -x "${CC:-}" ]; then
  echo "ERROR: CC is not set or not executable." >&2
  echo "Run this via 'nix develop .#cross --impure --command bash scripts/build-android.sh'." >&2
  exit 1
fi

if [ ! -d "$SRC" ] || [ ! -f "$SRC/configure.ac" ]; then
  echo "ERROR: dropbear source not found at: $SRC" >&2
  echo "       Expected a checkout with a configure.ac file." >&2
  echo "       Set DROPBEAR_SRC to override." >&2
  exit 1
fi

: "${TARGET_TRIPLE:=aarch64-linux-android}"
host="${host:-$TARGET_TRIPLE}"

# Use /dev/ptmx
export CPPFLAGS="${CPPFLAGS:-} -DUSE_DEV_PTMX=1"

echo "==> CC        = $CC"
echo "==> SYSROOT   = ${SYSROOT:-}"
echo "==> SRC       = $SRC"
echo "==> host      = $host"
echo "==> PROGRAMS  = $programs"
echo "==> OUT       = $OUT"
echo "==> CPPFLAGS  = $CPPFLAGS"

cd "$SRC"

if [ "$clean" -eq 1 ]; then
  echo "==> make distclean (ignore errors)"
  make distclean >/dev/null 2>&1 || true
fi

mkdir -p "$OUT"

# Apply local source patches (kept in patches/ at the outer repo so the
# upstream submodule tree stays clean and rebases stay easy). Idempotent —
# `git apply --check` skips ones already applied, so this is safe to run
# repeatedly and with --no-clean.
shopt -s nullglob
for p in "${ROOT}/patches/"*.patch; do
  if git apply --check "$p" 2>/dev/null; then
    echo "==> applying patch: $(basename "$p")"
    git apply "$p"
  else
    echo "==> patch already applied or conflicts, skipping: $(basename "$p")"
  fi
done
shopt -u nullglob

# disable password and PAM
echo "==> writing localoptions.h"
cat > localoptions.h <<'EOF'
/* Android (aarch64-linux-android21) overrides for cross-build. */

/* bionic@API21 lacks crypt(); sysoptions.h #errors if these are both on. */
#undef DROPBEAR_SVR_PASSWORD_AUTH
#define DROPBEAR_SVR_PASSWORD_AUTH 0

#undef DROPBEAR_SVR_PAM_AUTH
#define DROPBEAR_SVR_PAM_AUTH 0

/* bionic has no getpass(); Dropbear's cli-auth.c calls it unconditionally
 * under DROPBEAR_CLI_PASSWORD_AUTH, so the build won't link unless we
 * disable client password auth. dbclient will be pubkey-only. */
#undef DROPBEAR_CLI_PASSWORD_AUTH
#define DROPBEAR_CLI_PASSWORD_AUTH 0

#undef DROPBEAR_CLI_INTERACT_AUTH
#define DROPBEAR_CLI_INTERACT_AUTH 0

/* Dropbear's "sftp" subsystem just execs an external sftp-server binary
 * (default /usr/libexec/sftp-server). Android has no such binary, so
 * disable the subsystem — clients fall back to the legacy SCP protocol
 * via Dropbear's bundled scp. Use `scp -O` from modern OpenSSH clients. */
#undef DROPBEAR_SFTPSERVER
#define DROPBEAR_SFTPSERVER 0

/* svr-chansession.c clearenv()'s the child and hard-sets PATH to this.
 * The default "/usr/sbin:/usr/bin:/sbin:/bin" doesn't exist on Android,
 * so the bundled scp binary (and any other tool we want callable from
 * a session) needs to live somewhere on this list. /system/bin has the
 * toybox tools; /data/local/tmp/ssh is where we push dropbear+scp. */
#undef DEFAULT_ROOT_PATH
#define DEFAULT_ROOT_PATH "/data/local/tmp/ssh:/system/bin:/system/xbin:/vendor/bin"
#undef DEFAULT_PATH
#define DEFAULT_PATH "/data/local/tmp/ssh:/system/bin:/system/xbin:/vendor/bin"
EOF

# Dropbear's bundled libtomcrypt/libtommath builds in-tree; we only need to
# point configure at the cross toolchain. --disable-harden is required because
# the hardening flags include -fPIE which is incompatible with -static.
echo "==> ./configure (log: $LOG)"
./configure \
  --host="$host" \
  --enable-static \
  --disable-harden \
  --disable-zlib \
  --disable-pam \
  --disable-syslog \
  --disable-shadow \
  --disable-openpty \
  --disable-lastlog \
  --disable-utmp \
  --disable-utmpx \
  --disable-wtmp \
  --disable-wtmpx \
  --disable-pututline \
  --disable-pututxline \
  --disable-loginfunc \
  "${extra_configure_flags[@]}" 2>&1 | tee "$LOG"

make_flags=(PROGRAMS="$programs" STATIC=1 V=1)
if [ "$verbose" -eq 1 ]; then
  make_flags+=(-j1)
else
  make_flags+=("-j$(nproc)")
fi

echo "==> make ${make_flags[*]} (log: $LOG)"
if ! make "${make_flags[@]}" 2>&1 | tee -a "$LOG"; then
  echo
  echo "==> make failed; full log at: $LOG"
  echo "==> last 40 lines:"
  tail -n 40 "$LOG"
  exit 1
fi

for p in $programs; do
  if [ -x "$p" ]; then
    cp -f "$p" "$OUT/$p"
    "${STRIP:-strip}" "$OUT/$p" 2>/dev/null || true
    echo "==> built $OUT/$p"
  fi
done

echo "==> file $OUT/dropbear"
file "$OUT/dropbear" 2>/dev/null || true

echo "Done. Artifacts in: $OUT"
