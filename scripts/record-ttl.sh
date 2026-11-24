#!/bin/bash
# Controlled macOS cache experiment using an isolated temporary project DNS name.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?Evidence directory required}
source "$ROOT/.lab/network.env"
[ "$(id -u)" = 0 ] || { echo 'Run via sudo'; exit 1; }
[ "$(ipconfig getifaddr en0)" = "$M1" ] || exit 1
CFG="$ROOT/.lab/dnsmasq.conf"
ORIGINAL="$ROOT/.lab/dns-before-ttl.conf"
cp "$CFG" "$ORIGINAL"
DNSBIN=/opt/homebrew/sbin/dnsmasq
CAP=''
CACHEPID=''
restart_dns() {
 local PID
 PID=$(cat "$ROOT/.lab/dnsmasq.pid")
 local CMD
 CMD=$(ps -p "$PID" -o command=)
 [[ "$CMD" == *dnsmasq* && "$CMD" == *"$CFG"* ]] || { echo 'Unexpected DNS PID; refusing to stop'; return 1; }
 "$DNSBIN" --test --conf-file="$CFG"
 kill -TERM "$PID"
 sleep 0.4
 "$DNSBIN" --conf-file="$CFG" --log-facility="$ROOT/.lab/dns-ttl.log"
}
restore() {
 cp "$ORIGINAL" "$CFG"
 /usr/bin/sed -i '' "s|^log-facility=.*|log-facility=$ROOT/.lab/dns-active.log|" "$CFG"
 restart_dns || true
 if [ -n "$CACHEPID" ]; then kill -TERM "$CACHEPID" 2>/dev/null || true; fi
 networksetup -setdnsservers Wi-Fi "$M1" "$M4"
 dscacheutil -flushcache
 killall -HUP mDNSResponder || true
 if [ -n "$CAP" ]; then kill -INT "$CAP" 2>/dev/null || true; wait "$CAP" 2>/dev/null || true; CAP=''; fi
 if [ -n "${SUDO_UID:-}" ]; then chown "$SUDO_UID:${SUDO_GID:-20}" "$OUT/dns-ttl.txt" "$OUT/dns-ttl.pcapng" 2>/dev/null || true; fi
}
trap restore EXIT
/usr/bin/sed -i '' "s|^log-facility=.*|log-facility=$ROOT/.lab/dns-active.log|" "$CFG"
exec > >(tee "$OUT/dns-ttl.txt") 2>&1
/Applications/Wireshark.app/Contents/MacOS/dumpcap -i en0 -i lo0 -a duration:70 -w "$OUT/dns-ttl.pcapng" &
CAP=$!
sleep 1
cat > "$ROOT/.lab/client-cache.conf" <<CACHE
port=1053
listen-address=127.0.0.1
bind-interfaces
no-resolv
no-hosts
server=127.0.0.1#53
cache-size=150
pid-file=$ROOT/.lab/client-cache.pid
log-facility=$ROOT/.lab/client-cache.log
CACHE
"$DNSBIN" --conf-file="$ROOT/.lab/client-cache.conf"
CACHEPID=$(cat "$ROOT/.lab/client-cache.pid")
echo 'Client-side caching resolver: 127.0.0.1:1053, upstream primary, distinct process/cache.'
echo 'Temporary test: only primary DNS selected on this client to control resolver choice. Both project DNS servers continue serving app.team1.test.'
networksetup -setdnsservers Wi-Fi "$M1"
printf '\naddress=/ttl.team1.test/%s\n' "$M2" >> "$CFG"
restart_dns
dscacheutil -flushcache
killall -HUP mDNSResponder
query() {
 date -u '+%Y-%m-%dT%H:%M:%SZ'
 dig +noall +answer @127.0.0.1 -p 1053 ttl.team1.test
 /opt/homebrew/bin/python3 -c 'import socket; print("OS resolver:", sorted({x[4][0] for x in socket.getaddrinfo("ttl.team1.test",None,socket.AF_INET)}))'
}
echo 'Warm system cache: expected old edge address'
query
sleep 1
/usr/bin/sed -i '' "s|address=/ttl.team1.test/$M2|address=/ttl.team1.test/$M1|" "$CFG"
restart_dns
echo 'Authoritative query should show new address with TTL 30'
dig +noall +answer @"$M1" ttl.team1.test
echo 'OS cache immediately after record change (record actual behavior)'
query
sleep 5
echo 'After 5 seconds'; query
sleep 10
echo 'After 15 seconds'; query
sleep 18
echo 'After 33 seconds'; query
echo 'If macOS still retained an older answer, explicitly refresh it while authoritative answer is new'
dscacheutil -flushcache
killall -HUP mDNSResponder
sleep 1
query
echo 'Manual flush experiment: server is changed back to old address'
/usr/bin/sed -i '' "s|address=/ttl.team1.test/$M1|address=/ttl.team1.test/$M2|" "$CFG"
restart_dns
echo 'Before manual flush'; query
dscacheutil -flushcache
killall -HUP mDNSResponder
kill -HUP "$CACHEPID"
sleep 1
echo 'After manual flush'; query
echo 'Restoring original project DNS config and dual client DNS configuration'
