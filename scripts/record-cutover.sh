#!/bin/bash
# Mac 1 controller. Run after TTL test finishes and backend migration exceptions are active.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?Output directory required}
source "$ROOT/.lab/network.env"
[ "$(id -u)" = 0 ] || { echo 'Run via sudo'; exit 1; }
[ "$(ipconfig getifaddr en0)" = "$M1" ] || exit 1
CFG="$ROOT/.lab/dnsmasq.conf"
ORIGINAL="$ROOT/.lab/dns-before-edge-cutover.conf"
TRUST="$ROOT/.lab/demo-trust.pem"
DNSBIN=/opt/homebrew/sbin/dnsmasq
CAP=''
CHANGED=0
cp "$CFG" "$ORIGINAL"
restart_dns() {
 local PID CMD
 PID=$(cat "$ROOT/.lab/dnsmasq.pid")
 CMD=$(ps -p "$PID" -o command=)
 [[ "$CMD" == *dnsmasq* && "$CMD" == *"$CFG"* ]] || return 1
 "$DNSBIN" --test --conf-file="$CFG"
 kill -TERM "$PID"
 sleep 0.5
 "$DNSBIN" --conf-file="$CFG"
}
restore() {
 if [ "$CHANGED" = 1 ]; then
  cp "$ORIGINAL" "$CFG"
  /usr/bin/sed -i '' "s|^log-facility=.*|log-facility=$ROOT/.lab/dns-active.log|" "$CFG"
  restart_dns || true
  printf '%s\n' "$M2" > "$ROOT/.lab/edge-target"
  CHANGED=0
 fi
 networksetup -setdnsservers Wi-Fi "$M1" "$M4"
 dscacheutil -flushcache
 killall -HUP mDNSResponder || true
 if [ -n "$CAP" ]; then kill -INT "$CAP" 2>/dev/null || true; wait "$CAP" 2>/dev/null || true; CAP=''; fi
 if [ -n "${SUDO_UID:-}" ]; then chown "$SUDO_UID:${SUDO_GID:-20}" "$OUT/edge-cutover.txt" "$OUT/edge-cutover.pcapng" 2>/dev/null || true; fi
}
trap restore EXIT
exec > >(tee "$OUT/edge-cutover.txt") 2>&1
date -u
echo 'Preflight: both origins must allow Mac 1 during migration.'
curl -f --connect-timeout 3 --max-time 5 -i "http://$M3:3001/api/status"
curl -f --connect-timeout 3 --max-time 5 -i "http://$M4:3002/api/status"
curl -f --cacert "$TRUST" --resolve "app.team1.test:8443:$M1" --connect-timeout 3 --max-time 8 -i https://app.team1.test:8443/api/status
echo 'READY: waiting up to 5 minutes for Aditya backup DNS to point to Mac 1.'
READY=0
for i in {1..60}; do
 ANSWER=$(dig +time=1 +tries=1 +short @"$M4" app.team1.test 2>/dev/null || true)
 if [ "$ANSWER" = "$M1" ]; then READY=1; break; fi
 sleep 5
done
[ "$READY" = 1 ] || { echo 'Backup not changed; no primary cutover performed.'; exit 1; }
/Applications/Wireshark.app/Contents/MacOS/dumpcap -i en0 -i lo0 -a duration:90 -w "$OUT/edge-cutover.pcapng" 2>"$ROOT/.lab/edge-capture.log" &
CAP=$!
sleep 1
networksetup -setdnsservers Wi-Fi "$M1"
dscacheutil -flushcache
killall -HUP mDNSResponder
sleep 1
echo 'Warm cached old primary answer and show active edge'
curl -f --cacert "$TRUST" --connect-timeout 3 --max-time 10 -i -w '\nremote_ip=%{remote_ip}\n' https://app.team1.test:8443/api/status
/usr/bin/sed -i '' -E "s|^address=/app.team1.test/[0-9.]+$|address=/app.team1.test/$M1|; s|^address=/api.team1.test/[0-9.]+$|address=/api.team1.test/$M1|; s|^log-facility=.*|log-facility=$ROOT/.lab/dns-active.log|" "$CFG"
CHANGED=1
restart_dns
printf '%s\n' "$M1" > "$ROOT/.lab/edge-target"
echo 'Both DNS servers now authoritative for standby edge'
dig +noall +answer @"$M1" app.team1.test
dig +noall +answer @"$M4" app.team1.test
echo 'Immediate cached client observation; measure rather than assume old address'
curl -f --cacert "$TRUST" --connect-timeout 3 --max-time 10 -i -w '\nremote_ip=%{remote_ip}\n' https://app.team1.test:8443/api/status
echo 'Flush cache and demonstrate fresh domain-based traffic to standby'
dscacheutil -flushcache
killall -HUP mDNSResponder
sleep 1
for i in 1 2 3 4; do
 curl -f --cacert "$TRUST" --connect-timeout 3 --max-time 10 -i -w '\nremote_ip=%{remote_ip}\n' https://app.team1.test:8443/api/status
done
echo 'RESTORING PRIMARY RECORDS. Aditya should now run backup-dns-switch.sh primary.'
restore
sleep 1
dig +noall +answer @"$M1" app.team1.test
echo 'Primary restored; backup restoration and firewall baseline restoration still need external confirmation.'
