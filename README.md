# Spit

Spit is a small Phoenix paste service built for terminal-first sharing. Pipe logs, configs, traces, or notes into `curl`, get back a shareable URL, and view the paste in a clean browser UI.

## Features

* CLI-first paste creation with short `curl` commands
* Browser paste viewer plus raw and download links
* Default 1-day paste TTL, with configurable TTL up to 7 days
* IP-based upload rate limiting for a single Phoenix instance
* Hourly byte-volume limits per client IP
* Periodic cleanup of expired pastes
* PostgreSQL-backed persistence

## Usage

Create a paste from stdin:

```sh
journalctl -u my-app | curl -T- http://localhost:4000
```

The response is a browser URL:

```text
http://localhost:4000/p/abc123xy
```

Set an expiration with `ttl`:

```sh
cat error.log | curl -T- "http://localhost:4000?ttl=30m"
```

Supported TTL examples:

* `?ttl=30m`
* `?ttl=12h`
* `?ttl=1d`
* `?ttl=7d`

Pastes expire after 1 day by default. TTLs longer than 7 days and `ttl=never` are rejected.

The older explicit API endpoint also works:

```sh
cat error.log | curl --data-binary @- http://localhost:4000/api/pastes
```

## Local Development

Install dependencies and prepare the database:

```sh
mix setup
```

Start the app:

```sh
mix phx.server
```

Run checks:

```sh
mix precommit
```

The development and test database configs read these optional local variables:

* `POSTGRES_USER`, defaults to `postgres`
* `POSTGRES_PASSWORD`
* `POSTGRES_HOST`, defaults to `localhost`

## Production Environment

The release requires these environment variables:

* `SECRET_KEY_BASE`
* `DB_HOST`
* `DB_PORT`
* `DB_USER`
* `DB_PASSWORD`
* `DB_NAME`

Optional environment variables:

* `PHX_HOST`, defaults to `example.com`
* `PORT`, defaults to `4000`
* `POOL_SIZE`, defaults to `10`
* `ECTO_IPV6`, set to `true` or `1` to use IPv6 socket options

Generate a production secret with:

```sh
mix phx.gen.secret
```

Run migrations before serving production traffic:

```sh
bin/spit eval "Spit.Release.migrate"
```

## Docker

Build locally:

```sh
docker build -t spit:local .
```

Run the image:

```sh
docker run --rm -p 4000:4000 \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e PHX_HOST="localhost" \
  -e DB_HOST="host.docker.internal" \
  -e DB_PORT="5432" \
  -e DB_USER="postgres" \
  -e DB_PASSWORD="postgres" \
  -e DB_NAME="spit_prod" \
  spit:local
```

The GitHub Actions workflow publishes arm64 images to:

```text
ghcr.io/jamestjw/spit
```

## Operational Notes

Spit uses `conn.remote_ip` for upload rate limiting, so your load balancer or reverse proxy must preserve the real client IP before traffic reaches Phoenix.

Default upload limits are configured in `config/config.exs`:

* `10` uploads per minute per IP
* `100` uploads per day per IP
* `5 MB` per hour per IP

Expired pastes are deleted by a supervised cleanup worker every hour by default.
