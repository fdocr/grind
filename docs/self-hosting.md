# Self hosting

Grind ships as a public Docker image on GitHub Container Registry. Install it with the [Once CLI](https://once.com) on any VPS (DigitalOcean works well).

## Quick install

1. SSH into your server
2. Run `curl https://get.once.com | sh`
3. Choose **Enter a Docker image path**
4. Enter `ghcr.io/<your-github-user>/grind`
5. Enter your hostname (for example `grind.example.com`)

Once provisions SSL, mounts `/rails/storage` for persistent SQLite data, and keeps the image updated from the `latest` tag.

## Cloudflare (recommended)

Place the origin behind Cloudflare orange cloud:

- SSL/TLS mode: **Full (strict)**
- Allow `/up` health checks without caching
- Consider firewall rules so only Cloudflare can reach the origin

Set `APP_HOST` to your public hostname so mailer links and host authorization work.

## Environment variables

Configure in Once → Settings → Environment:

| Variable | Purpose |
|----------|---------|
| `APP_HOST` | Public hostname |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL` | Outbound mail for round stats |
| `CLOUDFLARE_TURNSTILE_SITE_KEY`, `CLOUDFLARE_TURNSTILE_SECRET_KEY` | Captcha on email requests |
| `MISSION_CONTROL_USERNAME`, `MISSION_CONTROL_PASSWORD` | Basic auth for `/jobs` dashboard |
| `HONEYBADGER_API_KEY` | Optional error tracking |
| `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`, `JOB_CONCURRENCY`, `SOLID_QUEUE_THREADS`, `DB_POOL` | Concurrency tuning |

## Import golf courses

Copy your course YAML onto the server (or bake it into a custom image), then:

```bash
bin/rails grind:courses:import[/path/to/courses.yml]
```

Run inside the container with `once exec` or your preferred shell access.

## Backups

The image includes Once hooks for consistent SQLite snapshots under `/rails/storage/backups`. Use Once backups before upgrades.

## Building your own image

Push a `v*` tag to GitHub. The release workflow publishes `ghcr.io/<owner>/grind` with semver tags and `latest`.
