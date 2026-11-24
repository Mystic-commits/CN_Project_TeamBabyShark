#!/bin/bash
# Run from any directory: bash scripts/lab.sh ROLE
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LAB="$ROOT/.lab"
mkdir -p "$LAB"
ROLE=${1:-help}
if [ "$ROLE" = help ]; then
  echo 'Roles: configure, dns, dns-stop, backend-a, backend-b, edge, edge-stop, standby, standby-stop, trust, client, demo'
  exit 0
fi
if [ "$ROLE" = configure ] || [ ! -f "$LAB/network.env" ]; then
  echo "This Mac current Wi-Fi IP: $(ipconfig getifaddr en0 || true)"
  echo 'Defaults are historical repo addresses except Mac 1. Confirm/update them.'
  read -r -p 'Mac 1 / Yug [10.7.23.11]: ' M1; M1=${M1:-10.7.23.11}
  read -r -p 'Mac 2 / Ansh [10.7.6.136]: ' M2; M2=${M2:-10.7.6.136}
  read -r -p 'Mac 3 / Ishita [10.7.22.88]: ' M3; M3=${M3:-10.7.22.88}
  read -r -p 'Mac 4 / Aditya [10.7.12.137]: ' M4; M4=${M4:-10.7.12.137}
  for value in "$M1" "$M2" "$M3" "$M4"; do
    if ! [[ "$value" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then echo 'Invalid IPv4 input'; exit 1; fi
    IFS=. read -r a b c d <<< "$value"
    for octet in "$a" "$b" "$c" "$d"; do
      if ((10#$octet > 255)); then echo 'Invalid IPv4 octet'; exit 1; fi
    done
  done
  printf 'M1=%s\nM2=%s\nM3=%s\nM4=%s\n' "$M1" "$M2" "$M3" "$M4" > "$LAB/network.env"
  [ "$ROLE" != configure ] || exit 0
fi
source "$LAB/network.env"
case "$ROLE" in
 dns)
  command -v brew >/dev/null
  brew list dnsmasq >/dev/null 2>&1 || brew install dnsmasq
  PREFIX=$(brew --prefix)
  IP=$(ipconfig getifaddr en0)
  if [ "$IP" != "$M1" ] && [ "$IP" != "$M4" ]; then
    echo "Current IP $IP is not the configured primary or backup. Run configure first."; exit 1
  fi
  if sudo lsof -nP -iUDP:53 -iTCP:53 | tail -n +2 | read -r _; then
    echo 'Port 53 is already in use; inspect the output above before stopping another DNS service.'; exit 1
  fi
  TARGET="$M2"
  if [ -f "$LAB/edge-target" ]; then TARGET=$(cat "$LAB/edge-target"); fi
  cat > "$LAB/dnsmasq.conf" <<CONF
port=53
bind-interfaces
listen-address=127.0.0.1,$IP
no-resolv
server=8.8.8.8
local=/team1.test/
address=/app.team1.test/$TARGET
address=/api.team1.test/$TARGET
local-ttl=30
log-queries
log-facility=-
pid-file=$LAB/dnsmasq.pid
CONF
  "$PREFIX/sbin/dnsmasq" --test --conf-file="$LAB/dnsmasq.conf"
  echo 'DNS foreground service. Leave this terminal open; Ctrl+C stops it.'
  sudo "$PREFIX/sbin/dnsmasq" --keep-in-foreground --conf-file="$LAB/dnsmasq.conf"
  ;;
 dns-stop)
  if [ -f "$LAB/dnsmasq.pid" ]; then
    PID=$(cat "$LAB/dnsmasq.pid")
    ps -p "$PID" -o command=
    read -r -p 'Stop this lab DNS process? [y/N] ' ANSWER
    [ "$ANSWER" != y ] || sudo kill -TERM "$PID"
  else echo 'No lab DNS pid file; use Ctrl+C in its terminal.'; fi
  ;;
 backend-a)
  command -v node >/dev/null || brew install node
  cd "$ROOT/backend-a"
  npm install
  exec npm start
  ;;
 backend-b)
  cd "$ROOT/backend-b"
  python3 -m venv .venv
  .venv/bin/python -m pip install -r requirements.txt
  exec .venv/bin/python app.py
  ;;
 edge|standby)
  brew list nginx >/dev/null 2>&1 || brew install nginx
  brew list mkcert >/dev/null 2>&1 || brew install mkcert
  DIR="$LAB/$ROLE"
  mkdir -p "$DIR/logs" "$DIR/certs"
  if [ ! -f "$DIR/certs/leaf.pem" ]; then
    mkcert -install
    mkcert -cert-file "$DIR/certs/leaf.pem" -key-file "$DIR/certs/leaf-key.pem" app.team1.test api.team1.test
  fi
  cp "$(mkcert -CAROOT)/rootCA.pem" "$LAB/$ROLE-rootCA.pem"
  cat > "$DIR/nginx.conf" <<CONF
worker_processes 1;
pid $DIR/nginx.pid;
error_log $DIR/logs/error.log info;
events { worker_connections 256; }
http {
  log_format lab '\$time_iso8601 client=\$remote_addr status=\$status upstream=\$upstream_addr upstream_status=\$upstream_status';
  access_log $DIR/logs/access.log lab;
  upstream backend_pool {
    server $M3:3001 max_fails=1 fail_timeout=5s;
    server $M4:3002 max_fails=1 fail_timeout=5s;
  }
  server {
    listen 8443 ssl;
    server_name app.team1.test api.team1.test;
    ssl_certificate $DIR/certs/leaf.pem;
    ssl_certificate_key $DIR/certs/leaf-key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    add_header X-Edge $ROLE always;
    location / {
      proxy_pass http://backend_pool;
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto https;
      proxy_connect_timeout 2s;
      proxy_read_timeout 5s;
      proxy_next_upstream error timeout http_502 http_503 http_504;
      proxy_next_upstream_tries 2;
    }
  }
}
CONF
  nginx -p "$DIR/" -c "$DIR/nginx.conf" -t
  echo "Send ONLY $LAB/$ROLE-rootCA.pem to every client. Each client must trust both edge roots for migration."
  echo 'Leave this terminal open; Ctrl+C stops this nginx.'
  nginx -p "$DIR/" -c "$DIR/nginx.conf" -g 'daemon off;'
  ;;
 cutover|restore-edge)
  if [ "$ROLE" = cutover ]; then printf '%s\n' "$M3" > "$LAB/edge-target";
  else printf '%s\n' "$M2" > "$LAB/edge-target"; fi
  echo 'Now Ctrl+C the lab DNS terminal and rerun: bash scripts/lab.sh dns'
  echo 'Do this on BOTH Mac 1 and Mac 4. No client cache flush until the TTL comparison is recorded.'
  ;;
 edge-stop|standby-stop)
  KIND=${ROLE%-stop}
  nginx -p "$LAB/$KIND/" -c "$LAB/$KIND/nginx.conf" -s quit
  ;;
 trust)
  CERT=${2:-}
  [ -f "$CERT" ] || { echo 'Usage: bash scripts/lab.sh trust /absolute/path/to/edge-rootCA.pem'; exit 1; }
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT"
  ;;
 client)
  SERVICE=${2:-Wi-Fi}
  if [ ! -f "$LAB/original-dns.txt" ]; then networksetup -getdnsservers "$SERVICE" > "$LAB/original-dns.txt"; fi
  sudo networksetup -setdnsservers "$SERVICE" "$M1" "$M4"
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  scutil --dns
  ;;
 demo)
  LOG="$LAB/demo-$(date +%Y%m%d-%H%M%S).txt"
  {
    date
    echo 'PRIMARY DNS'; dig +time=2 +tries=1 @"$M1" app.team1.test
    echo 'BACKUP DNS'; dig +time=2 +tries=1 @"$M4" app.team1.test
    echo 'REPEATED HTTPS REQUESTS'
    for i in {1..12}; do
      echo "Request $i"
      curl --max-time 10 -sS -D - -o /dev/null https://app.team1.test:8443/api/status || true
    done
    echo 'CACHE VALIDATION'
    curl --max-time 10 -i https://app.team1.test:8443/api/cached
    curl --max-time 10 -i -H 'If-None-Match: "v1"' https://app.team1.test:8443/api/cached
  } 2>&1 | tee "$LOG"
  echo "Saved: $LOG (inspect results; this script does not declare a pass)"
  ;;
 *) echo "Unknown role: $ROLE"; exit 1 ;;
esac
