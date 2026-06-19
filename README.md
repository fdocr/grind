# Grind

Track your golf round to improve your game. Search for a course, post scores and stats on your phone, and request an email summary when you finish. No account required.

Hosted at [grind.fdo.cr](https://grind.fdo.cr). Anyone can self host with the [Once CLI](https://once.com).

## Features

- Mobile first round tracker with gross score and putts per hole
- Custom stats: OOP Tee Shots, 3 Putts, Botched Up/Down, Inside PW/9i
- Offline friendly active round tracking with service worker caching
- Email round stats with Cloudflare Turnstile protection
- SQLite, Solid Queue, Solid Cache, and Solid Cable in production

## Documentation

- [Local development](docs/local-quickstart.md)
- [Self hosting](docs/self-hosting.md)

## Development styleguide

In development, visit `/dev/styleguide` for the design system reference. Build UI with the `app/views/ui/*` partials and `icon` helper only.

## License

MIT
