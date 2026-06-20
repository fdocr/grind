# Local development

## Requirements

- Ruby 3.4.5 (see `.ruby-version`)
- SQLite 3
- Chrome (for system tests)

## Setup

```bash
bundle install
bin/rails db:prepare
cp .env.sample .env
```

Optional: import sample golf courses

```bash
bin/rails grind:courses:import FILE=/path/to/sample_clean_crawl.yml
```

In zsh you can also quote the bracket form:

```bash
bin/rails 'grind:courses:import[/path/to/sample_clean_crawl.yml]'
```

## Run the app

```bash
bin/dev
```

Visit [http://localhost:3000](http://localhost:3000). The styleguide lives at [http://localhost:3000/dev/styleguide](http://localhost:3000/dev/styleguide).

## Tests

```bash
bin/rails test
bin/rails test:system
```

CI runs Brakeman, Bundler Audit, Importmap audit, RuboCop, unit tests, and system tests with screenshot artifacts on failure.

## Environment variables

See `.env.sample` for SMTP, Honeybadger, Cloudflare Turnstile, Mission Control basic auth, and concurrency settings.

## Email previews

Round stats emails open automatically in the browser via `letter_opener` when a delivery is sent in development. Make sure the Solid Queue worker is running (it starts inside `bin/dev` via the Puma plugin).
