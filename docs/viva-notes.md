# Viva notes — Team Baby Shark

## Yug Johri — DNS
- Authoritative vs recursive: dnsmasq is authoritative for `*.team1.test` from local `address=` lines and recursive for everything else via `8.8.8.8`.
- `.test` vs `.local`: `.local` is mDNS (RFC 6762). Unicast would never see the query.
- UDP vs TCP 53: small answers on UDP; truncated / zone transfer uses TCP.
- TTL 30s: short cache so a DNS cutover is visible in the demo.

## Anshvardhan Badkur — nginx / TLS
- Reverse vs forward proxy: we hide backends and terminate TLS; we do not hide clients.
- TLS termination: private key lives only on Mac 2; backends see HTTP.
- SNI: hostname is in ClientHello so one IP can present the `app.team1.test` cert.
- Round-robin: default nginx upstream; `X-Backend` proves which origin ran.
- `proxy_next_upstream` on 502/503/504: skip a dead backend.

## Ishita Thakur — Backend A
- Bind `0.0.0.0` so Mac 2 can connect; `127.0.0.1` is loopback only.
- ETag + `If-None-Match` → 304 with empty body.
- DHCP: if `en0` changes, nginx must change. Application code does not.

## Aditya Verma — Backend B
- Socket 4-tuple: (src IP, src port, dst IP, dst port).
- Well-known vs ephemeral ports: 53/8443/3002 vs client 49152–65535.
- Independent origin: killing A must leave B answering through nginx.
