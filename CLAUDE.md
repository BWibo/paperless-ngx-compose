# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker Compose deployment of paperless-ngx (v3) with PostgreSQL, Valkey (broker), Gotenberg, Tika and an optional bundled Caddy reverse proxy, plus restic backup scripts. There is no application code, build or test suite — changes are to compose/env config and shell scripts.

## Validating changes

```bash
# Validates interpolation; every ${VAR:?...} must be set. The CADDY_TLS warning is expected.
docker compose --env-file .env.example config --quiet
# Mode B (no Caddy): should list every service except caddy
COMPOSE_PROFILES= docker compose --env-file .env.example config --services
```

## Configuration layering

Three sources feed the stack, and where a variable goes matters:

- **`.env`** (from `.env.example`, gitignored): compose interpolation — image versions, secrets, network subnets, Caddy/TLS settings, proxy trust, AI backend. Most required vars use `${VAR:?VAR not set}`, so a missing entry fails `docker compose` outright. When adding a variable to `docker-compose.yml`, add it (with explanatory comment) to `.env.example` too.
- **`docker-compose.env`** (tracked, no secrets): passed via `env_file` to the webserver only — OCR, consumer, cron, filename format and other paperless behaviour settings.
- **`environment:` in `docker-compose.yml`**: paperless settings derived from `.env` (DB credentials, secret key, trusted proxies, AI settings), wired explicitly so secrets never live in tracked files.

Version bumps happen in `.env.example` (`PAPERLESS_NGX_VERSION`, `POSTGRES_VERSION`, `GOTENBERG_VERSION`, `VALKEY_VERSION`, `TKKA_VERSION`); commits are typically just the version number. Note `TKKA_VERSION` is the Tika image tag — the misspelling is the established variable name, don't "fix" it without updating every deployed `.env`.

## Architecture

**Proxy modes**, switched by `COMPOSE_PROFILES` in `.env`:
- Mode A (`local-proxy`): bundled Caddy (`caddy/Caddyfile`, configured entirely via `TLS_DOMAINS`/`ADMIN_EMAIL`/`CADDY_TLS` env) terminates TLS and proxies to `webserver:8000`.
- Mode B (empty): Caddy isn't started; an external proxy hits the webserver's published port (`PAPERLESS_WEBSERVER_BIND` / `_V6`).

**Two dual-stack networks** (security-motivated; read the comments in `docker-compose.yml` and `.env.example` before touching them):
- `frontend`: Caddy + webserver, has egress. Caddy gets fixed `CADDY_IP`/`CADDY_IP_V6` outside `FRONTEND_IP_RANGE` so they can be listed in `PAPERLESS_TRUSTED_PROXIES`.
- `backend` (`internal: true`, no egress): db, broker, gotenberg, tika — so document parsers can't call home. The webserver is the only service on both.
- Subnets must not overlap any host/LAN/VPN network: an overlap with the host's LAN once cut a host off its network entirely.

**Proxy-trust gotcha**: `PAPERLESS_ALLAUTH_TRUSTED_PROXY_COUNT` counts proxy *hops*, not addresses. Listing one dual-stack proxy under two IPs in `PAPERLESS_TRUSTED_PROXIES` would otherwise make every login return 500, so it's pinned to 1. In mode B, the trusted address is the frontend network's gateway (first address of the ip_range), not the proxy's real IP.

**Postgres 18**: `PGDATA` is pinned to `/var/lib/postgresql/data` so pre-18 volumes keep working.

The header comment block in `docker-compose.yml` is from upstream and partly stale (e.g. superuser is now created from `PAPERLESS_ADMIN_*`, not `createsuperuser`).

## Backups (`backup/`)

`paperless_backup_restic.sh` runs `document_exporter` inside the `paperless-webserver-1` container (depends on `COMPOSE_PROJECT_NAME=paperless`), then snapshots the paths in `include.txt` to a local and an Azure restic repo and applies the forget policy. `paperless_backup_restic_prune.sh` prunes and checks both repos. All config comes from `PAPERLESS_*` env vars (see `backup/README.md`); note the backup script reads `PAPERLESS_LOGFILE` while the prune script reads `PAPERLESS_BACKUP_LOGFILE`. The cron `logger -t` tags are matched by alert rules in a separate monitoring repo — keep them in sync.

## Deployment

Deployed hosts run this repo from a git checkout with their own `.env` and some intentional local drift in `docker-compose.yml` (external volumes, host bind paths). Hosts update via `git pull --rebase`, so keep changes to tracked files minimal and additive to avoid conflicts with that drift. Never edit files on the server directly.

## Updating to new paperless versions

**Exactly follow this workflow, when updating to a new paperless-ngx version.**

1. Determine the latest paperless-ngx release version from the Github repo: <https://github.com/paperless-ngx/paperless-ngx/releases/latest> and adapt the version `.env.example`
2. Check the online deployment example file for changes: <https://github.com/paperless-ngx/paperless-ngx/blob/{{LATEST_VERSION}}/docker/compose/docker-compose.postgres-tika.yml>. If there a version updates vor services, add them to `.env.example` and report them. If there are other significant changes to the `docker-compose.yml` file since the last release, report them and ask me what to do about them.
