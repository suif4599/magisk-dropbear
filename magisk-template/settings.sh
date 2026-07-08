#!/system/bin/sh

# DIR=$(dirname "$(realpath "$0")")
# . "$DIR/settings.sh"

MODID="magisk-dropbear"
MODROOT="/data/adb/modules/$MODID"
MODRUNTIME="/data/adb/dropbear"

DROPBEAR_BIN="$MODROOT/system/bin/dropbear"
HOSTKEY="$MODRUNTIME/ed25519_host"
SSH_DIR="$MODRUNTIME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PID_FILE="$MODRUNTIME/dropbear.pid"

DROPBEAR_PORT=2222

export PATH="$MODROOT/system/bin:/data/adb/magisk:/data/adb/ksu/bin:$PATH"
export HOME="$MODRUNTIME"

_normal="\033[0m"
_red="\033[1;31m"
_green="\033[1;32m"
_yellow="\033[1;33m"
_blue="\033[1;34m"

# log <Info|Success|Warning|Error> message...
log() {
    _lvl="$1"; shift
    case "$_lvl" in
        Info)    _c="$_blue" ;;
        Success) _c="$_green" ;;
        Warning) _c="$_yellow" ;;
        Error)   _c="$_red" ;;
        *)       _c="$_normal"; _lvl="Debug" ;;
    esac
    _msg="[$(date '+%H:%M:%S')] [$_lvl] $*"
    if [ -t 1 ]; then
        printf "%b%s%b\n" "$_c" "$_msg" "$_normal"
    else
        printf "%s\n" "$_msg"
    fi
}
