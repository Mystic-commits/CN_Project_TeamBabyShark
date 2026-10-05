# Network topology

Subnet: campus private Wi-Fi `10.7.0.0/16`, interface `en0` on every node.

```
Client
  |  UDP/53  app.team1.test?
  v
Mac 1  Yug Johri
dnsmasq  10.7.19.196:53
  |  A  10.7.18.79
  v
Mac 2  Anshvardhan Badkur
nginx  10.7.18.79:8080 (HTTP)  :8443 (TLS)
  |                    |
  | HTTP :3001         | HTTP :3002
  v                    v
Mac 3 Ishita         Mac 4 Aditya Verma
10.7.17.218          10.7.31.47
X-Backend: A         X-Backend: B
```

DHCP note: Mac 3 was `10.7.11.99` on 1 Oct and `10.7.17.218` on 5 Oct. Always `ipconfig getifaddr en0` before editing nginx upstreams.

Names:
- `app.team1.test`
- `api.team1.test`

Both A records point at the edge, never at a backend. Clients should not speak to `:3001` / `:3002` in the happy path.
