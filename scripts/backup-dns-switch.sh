#!/bin/bash
# On Aditya's Mac: bash backup-dns-switch.sh standby OR primary
set -euo pipefail
MODE=${1:-}
[[ "$MODE" = standby || "$MODE" = primary ]] || { echo 'Use standby or primary'; exit 1; }
[ "$(ipconfig getifaddr en0)" = 10.7.12.137 ] || { echo 'This script is for Aditya current Mac only'; exit 1; }
if [ "$(id -u)" != 0 ]; then exec sudo /bin/bash "$0" "$@"; fi
TARGET=10.7.6.136
[ "$MODE" != standby ] || TARGET=10.7.23.11
PIDS=$(pgrep -x dnsmasq || true)
[ "$(printf '%s\n' "$PIDS" | sed '/^$/d' | wc -l | tr -d ' ')" = 1 ] || { echo 'Expected exactly one dnsmasq process. Send process list to Yug.'; exit 1; }
PID=$PIDS
COMMAND=$(ps -p "$PID" -o command=)
case "$COMMAND" in *--conf-file=*) CFG=${COMMAND#*--conf-file=}; CFG=${CFG%% --*};; *) echo 'Cannot identify explicit project config; no changes'; exit 1;; esac
if [[ "$CFG" != /* ]]; then
 CWD=$(lsof -a -p "$PID" -d cwd -Fn | sed -n 's/^n//p' | head -1)
 [ -n "$CWD" ] || { echo 'Could not find dnsmasq working directory'; exit 1; }
 CFG="$CWD/$CFG"
fi
[ -f "$CFG" ] || { echo "Config not found: $CFG"; exit 1; }
grep -F 'address=/app.team1.test/' "$CFG" >/dev/null || { echo 'App record is not in this config; no changes'; exit 1; }
[ -f "$CFG.before-phase2-cutover" ] || cp "$CFG" "$CFG.before-phase2-cutover"
# Update only the two project A record mappings.
/usr/bin/sed -i '' -E "s|^address=/app.team1.test/[0-9.]+$|address=/app.team1.test/$TARGET|; s|^address=/api.team1.test/[0-9.]+$|address=/api.team1.test/$TARGET|" "$CFG"
DNSBIN=/opt/homebrew/sbin/dnsmasq
[ -x "$DNSBIN" ] || DNSBIN=/usr/local/sbin/dnsmasq
"$DNSBIN" --test --conf-file="$CFG"
kill -TERM "$PID"
sleep 1
if ! "$DNSBIN" --conf-file="$CFG" --log-facility=/tmp/cn-backup-dns-cutover.log; then
 cp "$CFG.before-phase2-cutover" "$CFG"
 "$DNSBIN" --conf-file="$CFG" --log-facility=/tmp/cn-backup-dns-cutover.log
 echo 'New start failed; restored original config'; exit 1
fi
printf '%s\n' "$TARGET" > "$(dirname "$CFG")/edge-target"
dig +time=2 +tries=1 @10.7.12.137 app.team1.test
printf 'Backup DNS now points to %s. After the demo run this script with primary.\n' "$TARGET"
