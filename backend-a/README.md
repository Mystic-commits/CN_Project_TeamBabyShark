# Mac 3 — Backend A

## Team member
Ishita Thakur (`ishitathakur`)

## Role
Application server instance A on the private LAN.

## Network
| Field | Value |
|---|---|
| Hostname | `cn-backend-a` |
| Interface | `en0` |
| Live IPv4 (5 Oct 2026) | `10.7.17.218` |
| Earlier IPv4 (1 Oct 2026) | `10.7.11.99` |
| Port | `3001` |
| Bind | `0.0.0.0:3001` |
| Runtime | Node.js + Express |

Campus Wi-Fi DHCP moved this laptop from `10.7.11.99` to `10.7.17.218`. Nginx upstream on Mac 2 must be updated whenever that happens.

## Endpoints
- `GET /` — JSON health object plus service label
- `GET /api/status` — JSON `{ "backend": "A", "status": "ok" }`

## Required headers
- `X-Backend: A`
- `Cache-Control: max-age=60`
- `ETag: "A-v1"`

`If-None-Match: "A-v1"` returns `304 Not Modified`.

## Run
```bash
cd backend-a
npm install
npm start
```

## Verify
```bash
lsof -nP -iTCP:3001 -sTCP:LISTEN
curl -i http://localhost:3001/api/status
curl -i http://10.7.17.218:3001/api/status
```

If LAN clients time out while localhost works, allow Node incoming connections in macOS Application Firewall.
