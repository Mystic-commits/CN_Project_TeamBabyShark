# Phase 2 implementation and evidence plan

Audit baseline: remote main at 59cc8bb (two original commits: d976ca1 and 59cc8bb).
Source: supplied CN Project Document.pdf, section 7, pages 8-10.
The document defines A-F as mandatory; even though the final demo table offers A/B/E examples, section 7 still requires all six.

The repo contains Phase 1 code, configs, screenshots and a packet capture. README descriptions are plans or claims, not verification of live Phase 2 behavior. No Phase 2 lab has been run by this audit.

| Requirement | Existing material | Work and evidence still needed |
| --- | --- | --- |
| A: Backup DNS | README proposes Mac 4; only Mac 1 listener config exists | Configure a second dnsmasq with identical records and its own LAN listener. Set BOTH resolvers on at least two clients. Stop primary; prove fresh OS-resolver requests use backup with packets/logs; restore primary. |
| B: TTL and cache flush | project.conf.example has local-ttl=30 | Warm the client cache, change records on both DNS servers, restart/reload records correctly, show old cached answer then new answer after expiry; separately show manual cache flush. Save timestamps and DNS packets. |
| C: Backend isolation | README has an illustrative pf rule snippet | Integrate rules in an evaluated pf anchor, back up the original config, syntax-check, allow edge and block other LAN clients to each backend port, prove both results, restore original state. A rule file alone is not an active firewall. |
| D: Backend failover/recovery | nginx template already retries error/timeout/502/503/504 | Make failure thresholds and timeouts explicit if needed. Baseline A+B, stop A, show successful B-only requests, restart A, show A+B again. Explain edge SPOF. |
| E: Standby edge migration | Missing dedicated section/config/evidence | Run standby nginx on Mac 3 or 4 with trusted hostname certificates, working upstream access and compatible isolation rules. Update BOTH DNS records, show cached old edge vs new edge, then restore. |
| F: Injected fault diagnosis | Existing troubleshooting docs | Practise and demonstrate DNS -> TCP -> TLS -> application diagnosis. Record fault, commands, observed layer, correction and recovery. Faculty provides the evaluation fault. |

## Four-machine assignment

Use current LAN addresses, not the October addresses blindly.

- Mac 1 / Yug: primary DNS, test client, evidence coordination.
- Mac 2 / Ansh: active nginx edge, TLS and failover configuration.
- Mac 3 / Ishita: Backend A on 3001; temporary standby edge on 8443 for E.
- Mac 4 / Aditya: Backend B on 3002, backup DNS on 53, test client.

Before work, record IP, interface, subnet mask, gateway and MAC address for all four machines; verify pairwise reachability and LAN client isolation settings. DNS needs UDP and TCP 53. Use Homebrew's actual prefix and network service name on each machine.

## Recommended lab order

1. Reproduce trusted Phase 1 HTTPS, A+B balancing and caching first.
2. Add and verify backup DNS (A).
3. Record baseline, cached record change, expiry and flush (B).
4. Back up, apply and verify backend isolation; exercise rollback (C).
5. Stop and restart A, recording all HTTP statuses and X-Backend values (D).
6. Prepare standby TLS, backend permissions and record rollback; perform edge migration (E).
7. Practise DNS/TCP/TLS/application faults (F), then rehearse the full 11-step final demo.

## Measurement traps

- `dig @DNS_IP name` queries that server directly. It does not prove macOS resolver fallback or the macOS application cache. Use it to inspect server answers; use system-resolver lookups, a fresh curl process and packet capture for client behavior.
- Cached DNS success with the primary stopped is not proof of backup DNS. Flush or expire the entry and capture a new query to the backup. Multiple DNS addresses do not guarantee a fixed primary-first sequence or instant fallback.
- A 30-second DNS TTL does not move existing TCP/TLS connections. Use fresh requests and distinguish DNS cache, browser cache and connection reuse.
- For dnsmasq `address=` edits, use a service restart or otherwise confirm the actual configuration was re-read; do not assume SIGHUP reloads the main config.
- The actual nginx template has no explicit max_fails/fail_timeout values, although README shows a tuned example. Defaults already provide passive failure handling. Passive checks discover failures through traffic; they are not periodic active probes.
- Stopping a process and dropping packets can produce different timing. Capture HTTP failures/timeouts as well as successes; do not claim seamless behavior without measurements.
- Use an external client to test blocked backend access. Mac 4 accessing its own backend locally can bypass the intended LAN ingress test.
- Before cutover, permit the standby edge as well as the active edge through backend isolation, including any necessary local path. Afterward restore the baseline policy. Otherwise DNS migration can succeed while HTTP fails.
- Standby TLS must cover app.team1.test and api.team1.test and be trusted by clients. Create a separate leaf certificate using the trusted local CA; never put the CA private key or leaf private keys in Git.
- OpenSSL s_client output alone is not proof of hostname/trust validation. Use trusted curl without -k for the final demo.

## Evidence to collect

Create evidence/phase2/{a-backup-dns,b-ttl,c-isolation,d-failover,e-cutover,f-diagnosis} only when collecting real results. For each, save a timestamp, machine/IP inventory, configuration revision, exact commands, expected result, actual result, packet capture/screenshots and rollback verification. Do not label unperformed demonstrations complete.

## References

- Assignment: supplied CN Project Document.pdf, section 7 and final demo sequence.
- nginx passive failures: https://nginx.org/en/docs/http/ngx_http_upstream_module.html
- nginx retries: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream
- dnsmasq options and reload semantics: https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
