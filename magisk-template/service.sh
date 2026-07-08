#!/system/bin/sh
DIR=$(dirname "$(realpath "$0")")

while [ "$(getprop sys.boot_completed)" != 1 ]; do
    sleep 1
done
# Network / storage can take a moment longer to settle after boot_completed.
sleep 5

"$DIR/start.sh"
