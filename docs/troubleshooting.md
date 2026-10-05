# Troubleshooting

Walk the stack from the bottom. Do not start at curl.

| Layer | Question | Command | Healthy |
|---|---|---|---|
| L1/L2 | Wi-Fi up, IP on `en0`? | `ifconfig en0 \| grep -E "status\|inet "` | `status: active`, `10.7.x.x` |
| L3 | Peer reachable? | `ping -c 2 10.7.18.79` | 0% loss |
| DNS | Name → edge? | `dig @10.7.19.196 app.team1.test +short` | `10.7.18.79` |
| L4 | Port open? | `nc -zvw3 10.7.18.79 8443` | succeeded |
| TLS | Cert/SNI? | `openssl s_client -connect 10.7.18.79:8443 -servername app.team1.test` | handshake + SAN |
| App | JSON? | `curl -i https://app.team1.test:8443/api/status` | 200 + `X-Backend` |

## Incidents we actually hit

**NXDOMAIN on `dig app.team1.test`**
Client DNS was `8.8.8.8`. Public roots have no `team1.test`. Point Wi-Fi DNS at `10.7.19.196` and flush mDNSResponder.

**dnsmasq listens, other Macs cannot query it**
macOS Application Firewall. `socketfilterfw --add` the dnsmasq binary; confirm `lsof` shows `10.7.19.196:53`.

**All 6 nginx requests return `X-Backend: B`**
Upstream still listed Mac 3 as `10.7.11.99` after DHCP gave Ishita `10.7.17.218`. Direct `curl http://10.7.17.218:3001/api/status` worked. Fix the upstream, `nginx -t`, restart nginx.

**Localhost `:3001` works, LAN curl hangs**
Node allowed on loopback only, or firewall. `lsof` should show `*:3001`, not `127.0.0.1:3001`. Allow incoming for that node binary.

**`If-None-Match` through nginx returns 200**
Round-robin sent the validator to the other backend, whose ETag did not match. Prove 304 against one origin (`http://10.7.17.218:3001/api/status`) first.

**`HTTP 502` from nginx**
Both upstreams down, or stale IPs. `curl` each backend from Mac 2. Check `/opt/homebrew/var/log/nginx/error.log`.

**Wrong port `9443`**
Host is up (ping works) but nothing listens. TCP RST / connection refused is L4, not L3.
