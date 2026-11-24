#!/bin/bash
# Standalone: bash backend-firewall.sh apply|migration|restore
set -euo pipefail
ACTION=${1:-apply}
IP=$(ipconfig getifaddr en0)
case "$IP" in
 10.7.22.88) PORT=3001 ;;
 10.7.12.137) PORT=3002 ;;
 *) echo "Expected Ishita or Aditya IP; found $IP. No changes made."; exit 1 ;;
esac
STATE="$HOME/Documents/CN-Phase2-firewall"
mkdir -p "$STATE"
ANCHOR=com.apple/cn_team_babyshark
if [ "$ACTION" = restore ]; then
 [ -f "$STATE/before.rules" ] || { echo 'No saved rules; nothing changed.'; exit 1; }
 sudo pfctl -a "$ANCHOR" -f "$STATE/before.rules"
 if [ -f "$STATE/token" ]; then sudo pfctl -X "$(cat "$STATE/token")"; rm "$STATE/token"; fi
 echo 'Lab anchor restored. No global pf flush performed.'
 exit 0
fi
[[ "$ACTION" = apply || "$ACTION" = migration ]] || { echo 'Use apply, migration, or restore'; exit 1; }
sudo pfctl -sr 2>/dev/null | grep -F 'anchor "com.apple/*"' >/dev/null || {
 echo 'Parent anchor missing; no changes made. Send this output to Yug.'; exit 1;
}
if [ ! -f "$STATE/before.rules" ]; then
 sudo pfctl -a "$ANCHOR" -sr > "$STATE/before.rules" 2>/dev/null
 cp /etc/pf.conf "$STATE/pf.conf.backup"
fi
ALLOW=10.7.6.136
if [ "$ACTION" = migration ]; then ALLOW='{ 10.7.6.136, 10.7.23.11 }'; fi
cat > "$STATE/current.rules" <<RULES
pass in quick on en0 proto tcp from $ALLOW to $IP port $PORT
block drop in quick on en0 proto tcp from any to $IP port $PORT
RULES
sudo pfctl -n -a "$ANCHOR" -f "$STATE/current.rules"
sudo pfctl -a "$ANCHOR" -f "$STATE/current.rules"
if [ ! -f "$STATE/token" ]; then
 RESULT=$(sudo pfctl -E 2>&1)
 printf '%s\n' "$RESULT"
 TOKEN=$(printf '%s\n' "$RESULT" | sed -n 's/.*Token : *//p')
 if [ -z "$TOKEN" ]; then
  sudo pfctl -a "$ANCHOR" -f "$STATE/before.rules"
  echo 'Token not found; rules restored. Send output to Yug.'; exit 1
 fi
 printf '%s\n' "$TOKEN" > "$STATE/token"
fi
sudo pfctl -a "$ANCHOR" -sr
printf 'Backend %s:%s, mode %s. Use NEW connections for tests.\n' "$IP" "$PORT" "$ACTION"
