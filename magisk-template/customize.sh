#!/system/bin/sh

# shellcheck disable=SC2034
SKIPUNZIP=0

if [ "$BOOTMODE" != true ]; then
    ui_print "! Please install in Magisk Manager or KernelSU Manager"
    ui_print "! Install from recovery is NOT supported"
    abort "-----------------------------------------------------------"
fi

. "$MODPATH/settings.sh"

ui_print "==========================================================="
ui_print " Magisk Dropbear"
ui_print " Welcome! Installing Dropbear SSH client for Android."
ui_print "==========================================================="
ui_print "- Module ID  : $MODID"
ui_print "- Version    : v$(grep '^versionCode=' "$MODPATH/module.prop" | cut -d= -f2)"
ui_print "- Author     : suif4599"
ui_print "- Detected arch: $ARCH"
ui_print "-----------------------------------------------------------"

mkdir -p "$MODPATH/system/bin"
mkdir -p "$MODRUNTIME/.ssh"

for file in $MODPATH/bin/*; do
    cp -f $file "$MODPATH/system/bin"
done
set_perm_recursive "$MODPATH/system/bin/" 0 0 0755 0755 "u:object_r:system_file:s0"
set_perm_recursive "$MODPATH/bin/" 0 0 0755 0755 "u:object_r:system_file:s0"

set_perm "$MODPATH/service.sh"  0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/start.sh"    0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/settings.sh" 0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/uninstall.sh" 0 0 0755 "u:object_r:system_file:s0"

genkey() {
    if ! "$MODPATH/system/bin/dropbearkey" -t ed25519 -f "$MODRUNTIME/ed25519_host"; then
        ui_print "! Key generation failed"
        abort "-----------------------------------------------------------"
    fi
}

if [[ -f "$MODRUNTIME/ed25519_host" && -f "$MODRUNTIME/ed25519_host.pub" ]]; then
    ui_print "- Key exists. Skip generating"
elif [[ -f "$MODRUNTIME/ed25519_host" || -f "$MODRUNTIME/ed25519_host.pub" ]]; then
    ui_print "- Key corrupted. Regenerating"
    genkey
else
    ui_print "- Generating key"
    genkey
fi

/system/bin/su -c "chmod 600 $MODRUNTIME/ed25519_host"
/system/bin/su -c "chmod 644 $MODRUNTIME/ed25519_host.pub"

ui_print "-----------------------------------------------------------"
ui_print " Installation complete. NOT auto-started."
ui_print ""
ui_print " Next steps:"
ui_print "   1. Add your public key:"
ui_print "        echo '<ssh-ed25519 AAAA... your@host>' > $AUTHORIZED_KEYS"
ui_print "   2. Reboot — dropbear auto-starts on port $DROPBEAR_PORT"
ui_print "-----------------------------------------------------------"
