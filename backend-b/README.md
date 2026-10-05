# Mac 4 — Backend B

## Team member
Aditya Verma (`2401010040`)

## Role
Application server instance B. Live lab responses were served by Python (`Server: Werkzeug/3.1.9 Python/3.13.5`). This repo keeps a small stdlib HTTP server with the headers the rubric requires.

## Network
| Field | Value |
|---|---|
| Hostname | `cn-backend-b` |
| Interface | `en0` |
| IPv4 | `10.7.31.47` |
| Port | `3002` |
| Bind | `0.0.0.0:3002` |

## Endpoints
- `GET /`
- `GET /api/status` → `{ "backend": "B", "status": "ok" }`

## Headers
- `X-Backend: B`
- `Cache-Control: max-age=60`
- `ETag: "B-v1"`

## Run
```bash
python3 server.py
```

## Verify
```bash
curl -i http://localhost:3002/api/status
curl -i http://10.7.31.47:3002/api/status
```
