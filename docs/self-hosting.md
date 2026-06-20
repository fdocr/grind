# Self hosting

Grind ships as a public Docker image on [GitHub Container Registry](https://github.com/features/packages). Install it with the [Once CLI](https://once.com) on any VPS (Ubuntu 22.04+ works well).

## Prerequisites

- A server with SSH access
- A domain name with DNS pointed at your server (or at Cloudflare if you use the orange cloud)

No local toolchain is required. Once handles Docker, SSL, and updates on the server.

## 1. Install Once and Grind

SSH into your server and run:

```bash
curl https://get.once.com | sh
```

When prompted:

1. Choose **Enter a Docker image path**
2. Enter `ghcr.io/fdocr/grind`
3. Enter your hostname (for example `grind.example.com`)

Once pulls the image, provisions Let's Encrypt SSL, mounts `/rails/storage` for persistent SQLite data, and keeps the container updated from the `latest` tag.

## 2. Configure environment variables

Open Once → **Settings** → **Environment** and add the variables below. Once redeploys when you save.

### Required in production

| Variable | Example | Description |
|----------|---------|-------------|
| `APP_HOST` | `grind.example.com` | Public hostname for mailer links and Rails host authorization |
| `MISSION_CONTROL_USERNAME` | `admin` | Username for HTTP basic auth on `/jobs` |
| `MISSION_CONTROL_PASSWORD` | _(strong secret)_ | Password for `/jobs` |

Without `MISSION_CONTROL_USERNAME` and `MISSION_CONTROL_PASSWORD`, the jobs dashboard returns **503 Service Unavailable**.

### Email (optional but recommended)

Round stats emails require SMTP. Turnstile is strongly recommended to reduce spam.

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_ADDRESS` | _(unset)_ | SMTP server hostname. Email is disabled when unset |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USERNAME` | _(unset)_ | SMTP username |
| `SMTP_PASSWORD` | _(unset)_ | SMTP password |
| `SMTP_FROM_EMAIL` | `noreply@grind.fdo.cr` | From address on outbound mail |
| `CLOUDFLARE_TURNSTILE_SITE_KEY` | _(unset)_ | Turnstile site key shown on the round summary page |
| `CLOUDFLARE_TURNSTILE_SECRET_KEY` | _(unset)_ | Turnstile secret for server-side verification. Verification is skipped when unset |

### Error tracking (optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `HONEYBADGER_API_KEY` | _(unset)_ | [Honeybadger](https://www.honeybadger.io/) API key. Reporting is disabled when unset |

### Analytics (optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `PLAUSIBLE_URL` | _(unset)_ | Full URL to the [Plausible](https://plausible.io/) script (for example `https://plausible.io/js/script.js` or a self hosted instance). Analytics are disabled when unset |

The script tag is not hardcoded in the repository, so you can point at Plausible Cloud or your own instance without exposing that URL in the open source repo. When set, page views are tracked against the site's hostname automatically (no separate domain variable needed).

Add the variable in Once → Settings → Environment, then verify:

```bash
docker exec <container_id> printenv PLAUSIBLE_URL
```


Defaults suit a small VPS. Tune on larger machines (see [Concurrency](#concurrency)).

| Variable | Default | Description |
|----------|---------|-------------|
| `WEB_CONCURRENCY` | `1` | Puma worker processes (`preload_app!` when greater than 1) |
| `RAILS_MAX_THREADS` | `3` | Puma threads per worker |
| `JOB_CONCURRENCY` | `1` | Solid Queue worker processes |
| `SOLID_QUEUE_THREADS` | `3` | Solid Queue threads per worker process |
| `SOLID_QUEUE_IN_PUMA` | enabled | Set to `false` to run `bin/jobs` as a separate process instead of the Puma plugin |
| `DB_POOL` | _(auto)_ | Active Record pool size per process. Default: `max(RAILS_MAX_THREADS, SOLID_QUEUE_THREADS + 2)` |

### Logging and runtime (optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `RAILS_LOG_LEVEL` | `info` | Log verbosity (`debug`, `info`, `warn`, `error`) |
| `PORT` | `3000` | Port Puma listens on inside the container. Thruster serves HTTP on port 80 |
| `PIDFILE` | _(unset)_ | Optional Puma PID file path |

### Provided by Once (do not set unless you know why)

| Variable | Description |
|----------|-------------|
| `SECRET_KEY_BASE` | Session signing and CSRF protection. Once generates this automatically |
| `RAILS_ENV` | Set to `production` in the Docker image |

## 3. Import golf courses

The image ships without course data. Copy your course YAML onto the server, then import inside the container:

```bash
once exec bin/rails grind:courses:import FILE=/path/to/courses.yml
```

Or with Docker directly:

```bash
docker exec -it <container_id> bin/rails grind:courses:import FILE=/path/to/courses.yml
```

## Automatic updates

Once checks for new `latest` images and applies updates with zero downtime. Push a `v*` tag to your fork to publish a new image via the GitHub release workflow.

## Backups

Grind includes Once hooks for consistent SQLite snapshots:

- **`hooks/pre-backup`** runs before Once backs up `/rails/storage`. It uses SQLite's online backup API to copy `production.sqlite3`, `production_cache.sqlite3`, `production_queue.sqlite3`, and `production_cable.sqlite3` into `storage/backups/` without stopping the app.
- **`hooks/post-restore`** runs after a restore. It moves the backup copies back to their normal paths before the app boots.

Configure your backup destination in the Once dashboard under your app's settings.

To trigger a backup manually:

```bash
once backup
```

## Useful commands

```bash
once                    # Open the Once dashboard (TUI)
once list               # List installed applications
once update             # Manually check for image updates
once backup             # Trigger a backup
once exec <command>     # Run a command inside the container
docker ps               # Find the container ID
docker logs -f <id>     # Tail application logs
docker exec -it <id> bin/rails console
docker exec -it <id> bin/rails dbconsole
```

## How it works

Grind is a Rails 8 application using SQLite for storage. All persistent data lives under `/rails/storage/`, which Once mounts as a volume:

| File | Purpose |
|------|---------|
| `production.sqlite3` | Primary application data (courses, rounds, deliveries) |
| `production_cache.sqlite3` | Solid Cache |
| `production_queue.sqlite3` | Solid Queue jobs |
| `production_cable.sqlite3` | Solid Cable |

On container boot, `bin/docker-entrypoint` runs `db:create` and `db:migrate`. It does **not** run seeds, so you import courses manually.

The container listens on port **80** via Thruster, which proxies to Puma on port 3000. Solid Queue runs inside Puma by default.

Health checks use `GET /up`. SSL redirects and host authorization exclude this path.

## Concurrency

Set concurrency variables in Once → Settings → Environment.

**Defaults** (1 Puma process, 3 threads, 1 Solid Queue worker) suit a small VPS. On a larger machine (for example 4 CPU / 8 GB RAM), you might try:

```text
WEB_CONCURRENCY=3
RAILS_MAX_THREADS=5
JOB_CONCURRENCY=2
SOLID_QUEUE_THREADS=3
```

That yields roughly **3 × 5 = 15** concurrent web threads and **2 × 3 = 6** job threads. Tune down if you see high memory use or SQLite lock contention.

### Connection pool

Active Record's `pool` is **per Ruby process**, not shared across the machine. Each Puma worker and each Solid Queue worker process gets its own pool. The default size is `max(RAILS_MAX_THREADS, SOLID_QUEUE_THREADS + 2)`. Set `DB_POOL` only if you need a higher explicit ceiling.

### Verify after changing concurrency

```bash
docker exec <container_id> printenv WEB_CONCURRENCY RAILS_MAX_THREADS JOB_CONCURRENCY SOLID_QUEUE_THREADS DB_POOL
```

## Error tracking (Honeybadger)

Honeybadger is optional and disabled when `HONEYBADGER_API_KEY` is unset. Errors are only reported in production.

Add the key in Once → Settings → Environment, then verify:

```bash
docker exec <container_id> printenv HONEYBADGER_API_KEY
```

## Mission Control (`/jobs`)

The Solid Queue dashboard lives at `/jobs` and is protected by HTTP basic auth. Set `MISSION_CONTROL_USERNAME` and `MISSION_CONTROL_PASSWORD` in your Once environment.

In local development only, if those variables are unset, the defaults `development` / `development` apply.

## Cloudflare (orange cloud)

Skip this section if DNS points directly at your server without a proxied CDN.

When traffic flows **Browser → Cloudflare → Once → Grind**:

- Set **SSL/TLS mode** to **Full (strict)**
- Restrict origin access to [Cloudflare IP ranges](https://www.cloudflare.com/ips-v4) at your VPS firewall (for example DigitalOcean cloud firewall) so only Cloudflare can reach the server
- Bypass cache for dynamic routes, especially `GET /up` (health checks)

Set `APP_HOST` to your public hostname so mailer links and host authorization match your domain.

### CDN cache notes

Bypass cache for round tracking pages, form submissions, `/up`, and `/jobs`. Static assets (CSS, JS with digests) can be cached aggressively at the edge.

## Building your own image

Push a `v*` tag to GitHub. The release workflow builds `linux/amd64` and publishes to `ghcr.io/<owner>/grind` with semver tags and `latest`.

```bash
git tag v0.1.0
git push origin v0.1.0
```
