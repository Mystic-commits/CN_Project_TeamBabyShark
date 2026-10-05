# Evidence index

Captures from the 1 Oct 2026 and 5 Oct 2026 lab sessions.

| Task | File | What it shows |
|---|---|---|
| A/B | `task-a/Mac1-TaskA-dnsmasq-listen.png` | dnsmasq started, `dig @10.7.19.196` → `10.7.18.79` |
| B | `task-b/Mac1-TaskB-dnsmasq-config.png` | live `dnsmasq.conf` listen + `address=/app.team1.test/` |
| B | `task-b/Mac1-TaskB-DNS-Resolution.png` | same as listen/resolution on Mac 1 |
| B | `task-b/Mac3-TaskB-nslookup.jpg` | Ishita's Mac uses team DNS, answer `10.7.18.79` |
| B/D/E | `task-b/Mac3-TaskB-dig-via-team-dns.jpg` | dig via `10.7.19.196`, HTTPS 200, A/B load mix |
| C/D/E/F | `task-c/Mac2-TaskC-Direct-Backends.jpg` | HTTPS via mkcert CA; direct A Express; direct B Python |
| D | `task-d/` | copies of the load-balancing terminals |
| E | `task-e/` | HTTPS 200 from nginx 1.31.6 |
| F | `task-f/Mac2-TaskF-Cache-ETag.jpg` | `Cache-Control: max-age=60` and ETag on Backend A |
| G | `task-g/CNPhase1_Wireshark_Capture.pcapng` | packet capture from the Phase 1 session |
| setup | `setup/` | firewall, default nginx.conf, certs directory listing |
