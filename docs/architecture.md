# Architecture

The application is two health endpoints. The project is the path a packet takes across four Macs on `10.7.0.0/16`.

## Nodes
| Node | Person | Software | Address |
|---|---|---|---|
| Mac 1 DNS | Yug Johri | dnsmasq 2.93 | `10.7.19.196:53` |
| Mac 2 Edge | Anshvardhan Badkur | nginx 1.31.6 | `10.7.18.79:8080` / `:8443` |
| Mac 3 App A | Ishita Thakur | Node/Express | `10.7.17.218:3001` |
| Mac 4 App B | Aditya Verma | Python HTTP | `10.7.31.47:3002` |

## Request path
1. Client queries `app.team1.test` over UDP/53 to Mac 1.
2. dnsmasq answers `10.7.18.79`.
3. Client opens TCP to `10.7.18.79:8443` (SYN, SYN-ACK, ACK).
4. TLS 1.2/1.3 handshake with SNI `app.team1.test`.
5. nginx decrypts, picks an upstream with round-robin, proxies HTTP.
6. Backend returns JSON plus `X-Backend`, `ETag`, `Cache-Control`.
7. nginx encrypts the response back to the client.

Cloud equivalents: Route 53 (Mac 1), ALB/TLS terminator (Mac 2), two app instances (Mac 3/4).
