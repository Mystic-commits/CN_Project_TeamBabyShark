#!/bin/bash
set -e

DOMAIN="${DOMAIN:-app.team1.test}"
EXPECTED_IP="${EXPECTED_IP:-10.7.6.136}"
DNS="${DNS:-10.7.23.11}"

echo "=== DNS RESOLUTION TEST ==="
echo "Domain: $DOMAIN"
echo "Expected A record: $EXPECTED_IP via $DNS"
echo

echo "1. Query team DNS directly"
RESOLVED_IP=$(dig +short @"$DNS" "$DOMAIN" | tail -n1)
echo "Resolved: $RESOLVED_IP"

if [ "$RESOLVED_IP" != "$EXPECTED_IP" ]; then
  echo "[FAIL] expected $EXPECTED_IP"
  exit 1
fi
echo "[PASS] authoritative answer from Mac 1"

echo
echo "2. Flags / ANSWER section"
dig @"$DNS" "$DOMAIN" | grep -E -A 2 "ANSWER SECTION|flags:"
echo
echo "=== DNS TEST PASSED ==="
