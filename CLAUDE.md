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

## Updating paperless-ngx

Follow these steps exactly. `<old-tag>` is `v` + the current `PAPERLESS_NGX_VERSION` in `.env.example`; `<new-tag>` is the latest release tag.

1. **Bump paperless.** Get `<new-tag>` from `gh release view --repo paperless-ngx/paperless-ngx --json tagName`. Set `PAPERLESS_NGX_VERSION` in `.env.example` to it, without the `v` prefix.
2. **Sync service images.** Fetch upstream's reference compose file at the new tag:
   `gh api "repos/paperless-ngx/paperless-ngx/contents/docker/compose/docker-compose.postgres-tika.yml?ref=<new-tag>" -H "Accept: application/vnd.github.raw"`.
   Compare its valkey, postgres, gotenberg and tika image tags with `VALKEY_VERSION`, `POSTGRES_VERSION`, `GOTENBERG_VERSION` and `TKKA_VERSION` in `.env.example`. Copy every tag that differs into `.env.example`.
3. **Review upstream compose changes.** Make a blobless clone of upstream in a scratch directory `<upstream>`: `git clone --filter=blob:none --no-checkout https://github.com/paperless-ngx/paperless-ngx <upstream>`. Diff with it, not the GitHub compare API: that API returns at most 300 files, sorted by path, so translation churn silently pushes `src/` changes out of the list. List what changed under `docker/compose/`: `git -C <upstream> diff <old-tag> <new-tag> -- docker/compose/`. If a change goes beyond image tags (new or removed services, env vars, volumes, commands, healthchecks), stop and ask the user how to apply it before you touch `docker-compose.yml`.
4. **Review config options.** Find every `PAPERLESS_*` option that was added, changed (default, meaning or format), renamed, deprecated or removed between the two tags. Use these sources:
   - `git -C <upstream> diff <old-tag> <new-tag> -- docs/configuration.md src/paperless/settings/`;
   - the notes of every release in between: `gh release list --repo paperless-ngx/paperless-ngx`, then `gh release view <tag> --json body`.

   Check each change against what this stack sets: `docker-compose.env`, the webserver's `environment:` in `docker-compose.yml`, and `.env.example`. Flag every change that touches an option we set or a feature we use (Caddy and proxy trust, subpath, AI, the exporter used by `backup/`). Propose edits for those, and apply them only after the user agrees.
5. **Validate** as described in "Validating changes".

Done when:
- `.env.example` has the new paperless version and every changed service tag;
- your report lists each version bump (old → new);
- your report lists each upstream compose change beyond image tags, or says there were none;
- your report lists each config-option change, with the ones that affect this stack highlighted, or says there were none.
