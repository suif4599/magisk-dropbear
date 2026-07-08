#!/system/bin/sh
# Can also be run manually
# su -c '/data/adb/modules/magisk-dropbear/start.sh'

DIR=$(dirname "$(realpath "$0")")
. "$DIR/settings.sh"

# ---- pre-flight checks --------------------------------------------------
if [ ! -x "$DROPBEAR_BIN" ]; then
    log Error "dropbear binary not found or not executable: $DROPBEAR_BIN"
    log Error "did the module install survive reboot? re-flash if needed."
    exit 1
fi

if [ ! -f "$HOSTKEY" ]; then
    log Error "host key missing: $HOSTKEY"
    log Error "reinstall the module or run:"
    log Error "  $MODROOT/system/bin/dropbearkey -t ed25519 -f $HOSTKEY"
    exit 1
fi

if [ ! -s "$AUTHORIZED_KEYS" ]; then
    log Warning "authorized_keys missing or empty: $AUTHORIZED_KEYS"
    log Warning "no client will be able to log in until you add a key:"
    log Warning "  echo '<ssh-ed25519 AAAA... your@host>' > $AUTHORIZED_KEYS"
fi

/system/bin/su -c "chmod 700 $SSH_DIR"
/system/bin/su -c "chmod 600 $AUTHORIZED_KEYS"

if [ -f "$PID_FILE" ]; then
    _pid="$(cat "$PID_FILE" 2>/dev/null)"
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        log Info "dropbear already running (PID $_pid)"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

if [ -f "$MODROOT/module.prop" ]; then
    sed -Ei "s|^description=.*|description=Dropbear SSH server — running on port $DROPBEAR_PORT|" "$MODROOT/module.prop"
fi

log Info "starting dropbear on port $DROPBEAR_PORT"
# -F  run in foreground
# -r  host key path
# -D  authorized-keys directory ($DIR/authorized_keys)
# -p  listen port
"$DROPBEAR_BIN" -F \
    -r "$HOSTKEY" \
    -D "$SSH_DIR" \
    -p "$DROPBEAR_PORT" &
echo $! > "$PID_FILE"
