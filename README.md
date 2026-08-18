# Tracedown on Railway

Deploys [Tracedown](https://tracedown.dev) — self-hosted API monitoring — on
[Railway](https://railway.com) as the full per-service stack: all eight JVM
services, PostgreSQL, Redis, and a Caddy edge that serves the dashboard and
routes the API, WebSocket and metrics paths. Eleven services, one `Deploy on
Railway` click.

Nothing here builds Tracedown from source: every Dockerfile fetches the
release artifacts pinned by [`VERSION`](VERSION) (backend) and
[`FRONTEND_VERSION`](FRONTEND_VERSION) (dashboard) from the GitHub releases.
That keeps deploys fast and reproducible — and makes upgrading a one-line
change (see [Updating](#updating)).

## Template composition

All repo-based services use root directory `/` with a per-service Dockerfile
path, so the two version files at the repo root drive every build.

| Service | Source | Public | Notes |
|---|---|---|---|
| `proxy` | `proxy/Dockerfile` | **yes** | Serves the dashboard; routes `/api`, `/ping`, `/ws`, `/metrics`. The only public service. |
| `gateway` | `gateway/Dockerfile` | no | Runs the schema migrator and CA-init before listening (see [Startup ordering](#startup-ordering)). Volume at `/data/bodies`. |
| `probe-scheduler` | `services/probe-scheduler/Dockerfile` | no | |
| `result-ingestor` | `services/result-ingestor/Dockerfile` | no | |
| `notification-dispatcher` | `services/notification-dispatcher/Dockerfile` | no | |
| `email-service` | `services/email-service/Dockerfile` | no | |
| `metrics-service` | `services/metrics-service/Dockerfile` | no | |
| `aggregate-worker` | `services/aggregate-worker/Dockerfile` | no | |
| `realtime-service` | `services/realtime-service/Dockerfile` | no | |
| `Postgres` | Railway's PostgreSQL | no | |
| `Redis` | Railway's Redis | no | |

### Variables — every JVM service

| Variable | Value |
|---|---|
| `DATABASE_URL` | `jdbc:postgresql://${{Postgres.RAILWAY_PRIVATE_DOMAIN}}:5432/${{Postgres.PGDATABASE}}` |
| `DATABASE_USER` | `${{Postgres.PGUSER}}` |
| `DATABASE_PASSWORD` | `${{Postgres.PGPASSWORD}}` |
| `REDIS_A_URL` | `redis://default:${{Redis.REDIS_PASSWORD}}@${{Redis.RAILWAY_PRIVATE_DOMAIN}}:6379` |
| `REDIS_B_URL` | same as `REDIS_A_URL` (one instance serves both roles until volume justifies splitting) |
| `PLATFORM_AES_KEY` | ONE generated secret shared by all services — **exactly 64 hex characters** (256-bit key). Permanent: it encrypts stored secrets and cannot be rotated; losing it orphans that data. Use a Railway shared variable. |
| `DEPLOYMENT_ENV` | `production` — arms the startup guard that refuses placeholder secrets. |

(`email-service` needs only the Redis and deployment variables — it holds no
database.)

### Per-service additions

| Service | Variable | Value |
|---|---|---|
| `gateway` | `JWT_SECRET` | Generated secret (any strong random string). |
| `gateway` | `APP_URL` | `https://${{proxy.RAILWAY_PUBLIC_DOMAIN}}` — base URL for links in outgoing email. |
| `gateway` | `DEMO_USER_EMAIL` / `DEMO_USER_PASSWORD` | The bootstrap admin created on first start against an empty database. Set your own before first deploy. |
| `probe-scheduler` | `GATEWAY_URL` | `http://${{gateway.RAILWAY_PRIVATE_DOMAIN}}:20714` |
| `proxy` | `GATEWAY_HOST` | `${{gateway.RAILWAY_PRIVATE_DOMAIN}}` |
| `proxy` | `REALTIME_HOST` | `${{realtime-service.RAILWAY_PRIVATE_DOMAIN}}` |
| `proxy` | `METRICS_HOST` | `${{metrics-service.RAILWAY_PRIVATE_DOMAIN}}` |

Every other knob (email provider, retention, domain trust, rate limits, …) is
environment-driven — the full reference is at
[tracedown.dev/install/configuration](https://tracedown.dev/install/configuration/).
Without an email provider configured no mail leaves the system; invites and
resets print to the service logs (`EMAIL_PROVIDER=console`).

## Startup ordering

Railway has no one-shot jobs or dependency ordering, so the `gateway`
container sequences the two things everything else waits on: it runs the
dedicated **schema-migrator** to completion, forces the internal **CA** into
existence (the probe-scheduler needs it at startup to mint its client
certificate), and only then starts serving. Every other service simply fails
fast until the schema exists and is restarted by Railway's on-failure policy —
the stack converges within a couple of restart cycles on first deploy, and
upgrades converge the same way.

## Probe agents

**The template deliberately contains no agent.** Agents are identity-bearing
(one-time enrolment, mutual TLS, a certificate bound to their slug) and are
placed where you need probes to run *from* — both are decisions, not
provisioning. Nothing probes until you bootstrap at least one, manually:

1. Mint a bootstrap token — `Settings → Agents` in the dashboard, or the
   gateway CLI.
2. Run the published `tracedown/tracedown-probe-agent` image with it, on a
   host of your choosing.

The one constraint to plan around: the scheduler dials each agent **at a
hostname equal to its slug** (the certificate's identity — on a Docker network
that is a `--network-alias`), and it must be able to reach the agent inbound.
With the scheduler on Railway that means network adjacency where the bare slug
resolves (VPN/tailnet-style), not the open internet. Full flow:
[tracedown.dev/install/agents](https://tracedown.dev/install/agents/).

## Updating

1. **Deployers**: Railway's *updatable templates* watch this repo. When it
   changes (a version bump), Railway offers the update on the deployed
   project — accept, and the services rebuild against the new releases. The
   gateway migrates the schema before anything serves, so the redeploy is the
   whole upgrade. Take a Postgres backup first for anything you care about.
2. **This repo**: a release is adopted by bumping [`VERSION`](VERSION) and/or
   [`FRONTEND_VERSION`](FRONTEND_VERSION) — every Dockerfile reads them at
   build time. One commit per upgrade.
3. **Automation (optional)**: the backend's release workflow can push that
   bump automatically on every release with a cross-repo token; until then it
   is a deliberate one-line commit, which also serves as a smoke-test gate.

## Notes

- Saved response bodies live on the `gateway` volume at `/data/bodies`.
  S3-compatible object storage is supported instead — see the configuration
  reference.
- If private-network connections between services fail on a fresh deploy,
  check Railway's current private-networking address family: the services
  bind IPv4 (`0.0.0.0`) by default.
- First login: the demo credentials you set above. Change them if you ever
  deployed with the defaults.

## License

Apache 2.0 — see [LICENSE](LICENSE).
