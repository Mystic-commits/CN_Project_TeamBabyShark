#!/bin/bash
# Hit a single backend directly so round-robin cannot send If-None-Match
# to the other instance (that was the 1 Oct failure mode).

set -e

URL="${URL:-http://10.7.17.218:3001/api/status}"

echo "=== TASK F: HTTP CACHING TEST ==="
echo "URL: $URL"
echo

RESPONSE=$(curl -s -i "$URL")
echo "$RESPONSE" | grep -E -i "HTTP/|Cache-Control|ETag|X-Backend"

ETAG=$(echo "$RESPONSE" | grep -i "^ETag:" | tr -d '\r' | awk '{print $2}')
echo
echo "Observed ETag: $ETAG"

if [ -z "$ETAG" ]; then
  ETAG='"A-v1"'
fi

echo
echo "Conditional request If-None-Match: $ETAG"
COND_RESPONSE=$(curl -s -i -H "If-None-Match: $ETAG" "$URL")
echo "$COND_RESPONSE" | grep -E -i "HTTP/|ETag|Cache-Control|X-Backend"

STATUS_CODE=$(echo "$COND_RESPONSE" | head -n1 | awk '{print $2}')
if [ "$STATUS_CODE" != "304" ]; then
  echo "[FAIL] expected 304, got $STATUS_CODE"
  echo "If this URL is the nginx VIP, round-robin may land on the other backend."
  exit 1
fi

echo
echo "=== HTTP CACHING TEST PASSED ==="
