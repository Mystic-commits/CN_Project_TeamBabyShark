#!/bin/bash
# Scoped macOS pf anchor; never reloads or flushes the global ruleset.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LAB="$ROOT/.lab"
source "$LAB/network.env"
ACTION=${1:-help}
ANCHOR=com.apple/cn_team_babyshark
case "$ACTION" in
 apply)
  PORT=${2:-}
  [[ "$PORT" = 3001 || "$PORT" = 3002 ]] || { echo 'Usage: bash scripts/isolation.sh apply 3001|3002'; exit 1; }
  IP=$(ipconfig getifaddr en0)
  [ "$IP" = "$M3" ] || [ "$IP" = "$M4" ] || { echo 'This IP does not match a backend in .lab/network.env'; exit 1; }
  sudo pfctl -sr 2>/dev/null | grep -F 'anchor "com.apple/*"' >/dev/null || {
    echo 'Required com.apple/* anchor is not active. Stop and inspect pf configuration; no global rules were changed.'; exit 1;
  }
  [ ! -f "$LAB/pf.token" ] || { echo 'Already applied; restore first.'; exit 1; }
  sudo pfctl -a "$ANCHOR" -sr > "$LAB/pf-anchor-before.txt" 2>/dev/null
  [ ! -s "$LAB/pf-anchor-before.txt" ] || { echo 'Anchor is already occupied; no changes made.'; exit 1; }
  sudo cp /etc/pf.conf "$LAB/pf.conf.backup"
  # Mac 3 is allowed for the upcoming standby edge. Its local traffic may not traverse en0.
  cat > "$LAB/isolation.pf" <<RULES
pass in quick on en0 proto tcp from { $M2, $M3 } to $IP port $PORT
block drop in quick on en0 proto tcp from any to $IP port $PORT
RULES
  sudo pfctl -n -a "$ANCHOR" -f "$LAB/isolation.pf"
  sudo pfctl -a "$ANCHOR" -f "$LAB/isolation.pf"
  ENABLE=$(sudo pfctl -E 2>&1)
  printf '%s\n' "$ENABLE"
  TOKEN=$(printf '%s\n' "$ENABLE" | sed -n 's/.*Token : *//p')
  if [ -z "$TOKEN" ]; then
    sudo pfctl -a "$ANCHOR" -f "$LAB/pf-anchor-before.txt"
    echo 'Could not obtain pf reference token; anchor restored. Inspect pf status.'; exit 1
  fi
  printf '%s\n' "$TOKEN" > "$LAB/pf.token"
  sudo pfctl -a "$ANCHOR" -sr
  echo 'Use fresh connections for tests; existing pf states may retain old permissions.'
  echo 'Allowed: active edge and standby edge. Test blocking from Mac 1.'
  ;;
 restore)
  [ -f "$LAB/pf.token" ] || { echo 'No saved token; no changes made.'; exit 1; }
  sudo pfctl -a "$ANCHOR" -f "$LAB/pf-anchor-before.txt"
  sudo pfctl -X "$(cat "$LAB/pf.token")"
  rm "$LAB/pf.token"
  echo 'Restored this lab anchor and released only this lab enable reference.'
  ;;
 *) echo 'Usage: bash scripts/isolation.sh apply 3001|3002 OR restore' ;;
esac
