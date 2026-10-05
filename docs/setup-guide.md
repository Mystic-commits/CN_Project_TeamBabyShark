# Setup guide

All four laptops on the same Wi-Fi. Homebrew on each Mac.

## Mac 1 — DNS (Yug)
See `dns/Readme.md`. Install dnsmasq, copy the example configs, start with `sudo brew services start dnsmasq`, open firewall for dnsmasq.

## Mac 3 — Backend A (Ishita)
```bash
cd backend-a
npm install
npm start
curl -i http://localhost:3001/api/status
```
Allow Node in Application Firewall so Mac 2 can reach `:3001`.

## Mac 4 — Backend B (Aditya Verma)
```bash
python3 backend-b/server.py
curl -i http://10.7.31.47:3002/api/status
```

## Mac 2 — Edge (Ansh)
```bash
brew install nginx mkcert
mkcert -install
sudo mkdir -p /opt/homebrew/etc/nginx/certs
cd /opt/homebrew/etc/nginx/certs
mkcert app.team1.test api.team1.test
```
Put current backend IPs in `nginx.conf` / `servers/team1.conf`, then:

```bash
nginx -t
brew services restart nginx
```

## Every client
```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.19.196
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## Smoke
```bash
./tests/dns-test.sh
./tests/https-test.sh
./tests/load-balancing-test.sh
./tests/caching-test.sh
```
