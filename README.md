# Private Network Service Platform
## Computer Networks Capstone — Team Baby Shark

**Core principle:** the application stays simple; the network is the project.

Four macOS laptops on campus Wi-Fi (`10.7.0.0/16`) implement private DNS, TLS at the edge, round-robin reverse proxy, and two application origins. Nothing is borrowed from a public cloud or a public DNS registrar.

---

## 1. What a client request does

1. Looks up `app.team1.test` on the team `dnsmasq` (UDP/53).
2. Receives `10.7.18.79` (nginx on Mac 2).
3. Opens TCP `8443`, completes TLS 1.2/1.3 with SNI `app.team1.test`.
4. nginx terminates TLS and forwards HTTP to Backend A (`:3001`) or Backend B (`:3002`).
5. The origin returns JSON plus `X-Backend`, `Cache-Control`, and `ETag`.
6. The same path is captured in Wireshark (`evidence/task-g/`).

---

## 2. Team and machine roles

| Machine | Member | Enrollment | Role | Software | Endpoint |
|:---|:---|:---|:---|:---|:---|
| **Mac 1** | Yug Johri | 2401010520 | Private DNS + test client | dnsmasq 2.93 | `10.7.19.196:53` |
| **Mac 2** | Anshvardhan Badkur | 2401010083 | Reverse proxy, LB, TLS | nginx 1.31.6 | `10.7.18.79:8080` / `:8443` |
| **Mac 3** | Ishita Thakur | — | Backend A | Node.js / Express | `10.7.17.218:3001` |
| **Mac 4** | Aditya Verma | 2401010040 | Backend B | Python HTTP | `10.7.31.47:3002` |

Repository: [Mystic-commits/CN_Project_TeamBabyShark](https://github.com/Mystic-commits/CN_Project_TeamBabyShark).

---

## 3. Addressing

| Role | Hostname | IPv4 used in the working demo | Notes |
|:---|:---|:---|:---|
| DNS | `cn-dns` | `10.7.19.196` | `en0` |
| Edge | `cn-edge` | `10.7.18.79` | MAC `d6:2c:44:81:38:d2` (lab chat) |
| Backend A | `cn-backend-a` | `10.7.17.218` | was `10.7.11.99` on 1 Oct |
| Backend B | `cn-backend-b` | `10.7.31.47` | stable across both lab days |

- Names: `app.team1.test`, `api.team1.test`
- TLD: `.test` (RFC 2606 / 6761), not `.local`

---

## 4. Topology

```
PRIVATE LAN  10.7.0.0/16
        |
        |  DNS query UDP/53   app.team1.test?
        v
  Mac 1  Yug Johri
  dnsmasq  10.7.19.196
        |
        |  A record  10.7.18.79
        v
  Client  --- TCP 8443, TLS, GET /api/status --->
        |
        v
  Mac 2  Anshvardhan Badkur
  nginx  TLS terminator + round-robin
        |                           |
        | HTTP                      | HTTP
        v                           v
  Mac 3 Ishita                Mac 4 Aditya Verma
  10.7.17.218:3001            10.7.31.47:3002
  X-Backend: A                X-Backend: B
  ETag: "A-v1"                ETag: "B-v1"
  Cache-Control: max-age=60
```

---

## 5. OSI / TCP-IP mapping

| OSI | TCP/IP | In this project | How we showed it |
|:---|:---|:---|:---|
| 7 | Application | DNS `app.team1.test` | `dig @10.7.19.196`, Wireshark `dns` |
| 7 | Application | HTTP `/api/status`, `X-Backend`, ETag | `curl -i` |
| 6 | Application | TLS 1.2/1.3 at nginx | `openssl s_client`, Wireshark `tls` |
| 5 | Application | TLS session / HTTP keep-alive | handshake + `Connection` |
| 4 | Transport | TCP 8080/8443/3001/3002 | Wireshark `tcp.port == 8443` |
| 4 | Transport | UDP 53 | `udp.port == 53` |
| 3 | Internet | IPv4 `10.7.0.0/16`, ICMP | `ping`, `ipconfig getifaddr en0` |
| 2 | Link | Wi-Fi, ARP | `arp -a` |
| 1 | Link | Radio | `ifconfig en0` status active |

---

## 6. Phase 1 tasks

### Task A — Private LAN
Same SSID, ping every role. Success: 0% loss.

```bash
ipconfig getifaddr en0
ping -c 3 10.7.18.79
ping -c 3 10.7.17.218
ping -c 3 10.7.31.47
```

### Task B — Private DNS (Mac 1)
Config in `dns/`. Live `dnsmasq.conf`:

```conf
listen-address=10.7.19.196,127.0.0.1
bind-interfaces
address=/app.team1.test/10.7.18.79
address=/api.team1.test/10.7.18.79
server=8.8.8.8
```

```bash
dig @10.7.19.196 app.team1.test +short
# 10.7.18.79
```

Evidence: `evidence/task-b/`.

### Task C — Two backends
- A: `npm start` in `backend-a/` on `:3001`
- B: `python3 backend-b/server.py` on `:3002`

```bash
curl -i http://10.7.17.218:3001/api/status
curl -i http://10.7.31.47:3002/api/status
```

Evidence: `evidence/task-c/Mac2-TaskC-Direct-Backends.jpg`.

### Task D — nginx load balancer (Mac 2)
Upstream `backend_pool`. HTTP 8080 and HTTPS 8443.

Live mix after fixing Mac 3's DHCP IP (5 Oct):

```
X-Backend: A
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
X-Backend: A
```

```bash
./tests/load-balancing-test.sh
```

Evidence: `evidence/task-d/`.

### Task E — TLS
mkcert SAN certs on Mac 2, protocols TLSv1.2 and TLSv1.3, HTTP/2 on 8443.

```bash
curl -i --cacert "$(mkcert -CAROOT)/rootCA.pem" \
  --resolve app.team1.test:8443:10.7.18.79 \
  https://app.team1.test:8443/api/status
```

Evidence: `evidence/task-e/`.

### Task F — Caching
Origins send `Cache-Control: max-age=60` and a stable ETag. `If-None-Match` against **one** origin returns 304.

Through nginx, a validator for A can land on B and you get 200. That is load balancing, not a broken cache. Demo 304 on `http://10.7.17.218:3001/api/status` (or B's URL).

```bash
./tests/caching-test.sh
```

Evidence: `evidence/task-f/`.

### Task G — Wireshark
File: `evidence/task-g/CNPhase1_Wireshark_Capture.pcapng`

Look for DNS A query/response, TCP three-way handshake to 8443, TLS ClientHello (SNI), Certificate, then encrypted application data.

---

## 7. Failures we induced or hit for real

| Scenario | What happened | Lesson |
|:---|:---|:---|
| Client DNS still `8.8.8.8` | `NXDOMAIN` for `app.team1.test` | Directory service ≠ reachability |
| Firewall on dnsmasq | LAN `dig @10.7.19.196` hangs; localhost works | L3 up, L4/L7 filtered |
| Mac 3 DHCP `10.7.11.99` → `10.7.17.218` | nginx 10/10 to B | Upstream IPs must match `en0` |
| Backend A down | nginx still 200 from B | Origin redundancy |
| Both origins down | DNS and TLS still work; nginx `502` | Edge ≠ app |
| curl to port `9443` | connection refused | L3 ok, no listener |

---

## 8. Phase 2 (hardening)

- Backup dnsmasq on a second Mac; clients get two resolvers.
- `local-ttl=30` and a DNS cutover after cache flush (`dscacheutil`, `killall -HUP mDNSResponder`).
- `pf` so only Mac 2 may open `:3001` / `:3002`.
- `max_fails` / `fail_timeout` on upstreams.
- Honest SPOF: Mac 2 nginx is still a single edge. Production would add a VIP (VRRP) or a second edge name.

---

## 9. Demo runbook

1. Show this README table (four roles).
2. `ping` edge + both backends.
3. `dig @10.7.19.196 app.team1.test +short` → `10.7.18.79`.
4. HTTPS `curl` without `-k` (trusted mkcert CA).
5. `./tests/load-balancing-test.sh`.
6. Open the `.pcapng` (DNS, SYN, ClientHello).
7. `./tests/caching-test.sh` against one origin.
8. Stop Backend A; curl still 200 with `X-Backend: B`.
9. Stop dnsmasq if a backup resolver is configured.
10. Faculty fault: use `docs/troubleshooting.md` bottom-up.
11. Viva: `docs/viva-notes.md`.

---

## 10. Repository layout

```
CN_Project_TeamBabyShark/
├── README.md
├── dns/                 Mac 1 dnsmasq examples
├── edge/                nginx example (8080 + 8443)
├── tls/                 openssl.cnf + mkcert notes
├── backend-a/           Express, port 3001
├── backend-b/           Python, port 3002
├── tests/               dns, https, lb, cache
├── docs/                architecture, setup, viva
├── documentation/       lab-notes pointer
└── evidence/            screenshots + pcapng
```

Private keys are gitignored. Do not add `*.pem` / `*.key`.
