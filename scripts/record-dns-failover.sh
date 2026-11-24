#!/bin/bash
# Local Mac 1 only. Stops this project's DNS, tests backup, and restores DNS on exit.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?Provide evidence output directory}
mkdir -p "$OUT"
source "$ROOT/.lab/network.env"
[ "$(id -u)" = 0 ] || { echo 'Run this script through sudo.'; exit 1; }
[ "$(ipconfig getifaddr en0)" = "$M1" ] || { echo 'Mac 1 IP mismatch'; exit 1; }
PID=$(cat "$ROOT/.lab/dnsmasq.pid")
COMMAND=$(ps -p "$PID" -o command=)
[[ "$COMMAND" == *dnsmasq* && "$COMMAND" == *"$ROOT/.lab/dnsmasq.conf"* ]] || { echo 'Unexpected DNS process; no changes made'; exit 1; }
DNSBIN=/opt/homebrew/sbin/dnsmasq
CAP=''
STOPPED=0
restore() {
 if [ "$STOPPED" = 1 ]; then
  "$DNSBIN" --conf-file="$ROOT/.lab/dnsmasq.conf" --log-facility="$ROOT/.lab/dns-resumed.log" || true
  STOPPED=0
 fi
 if [ -n "$CAP" ]; then kill -INT "$CAP" 2>/dev/null || true; wait "$CAP" 2>/dev/null || true; fi
 if [ -n "${SUDO_UID:-}" ]; then chown "$SUDO_UID:${SUDO_GID:-20}" "$OUT/dns-failover.txt" "$OUT/dns-failover.pcapng" 2>/dev/null || true; fi
}
trap restore EXIT
exec > >(tee "$OUT/dns-failover.txt") 2>&1
/Applications/Wireshark.app/Contents/MacOS/dumpcap -i en0 -i lo0 -a duration:40 -w "$OUT/dns-failover.pcapng" &
CAP=$!
sleep 1
date -u
printf 'Before failure: both configured DNS services\n'
networksetup -getdnsservers Wi-Fi
dig +time=2 +tries=1 @"$M1" app.team1.test
dig +time=2 +tries=1 @"$M4" app.team1.test
printf 'Stopping only this project primary DNS PID %s\n' "$PID"
kill -TERM "$PID"
STOPPED=1
sleep 1
dscacheutil -flushcache
killall -HUP mDNSResponder
printf 'Primary explicit query should now fail\n'
dig +time=1 +tries=1 @"$M1" app.team1.test || true
printf 'Fresh system-resolver HTTPS requests while primary is down\n'
for i in 1 2 3; do
 curl --cacert /Users/Mystic/Downloads/edge-rootCA.pem --connect-timeout 5 --max-time 20 -i https://app.team1.test:8443/api/status
done
printf 'Restore primary DNS\n'
restore
sleep 1
dig +time=2 +tries=1 @"$M1" app.team1.test
printf 'DNS failure test finished; inspect capture for backup queries and replies.\n'
