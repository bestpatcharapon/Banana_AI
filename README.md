# Banana MCP API

Banana MCP is a Rails 8.1, API-only service skeleton built on Ruby 3.4.7. It is wired for PostgreSQL, Solid Queue/Cache/Cable, Active Storage, Thruster + Puma, and container-first deployment through Kamal. This document explains how to get the application running locally, run the quality gates, and ship it.

## Stack Highlights
- Ruby 3.4.7 (`.ruby-version`) with Bundler-managed gems (see `Gemfile`)
- Rails API mode (`ApplicationController < ActionController::API`) with CORS hooks ready in `config/initializers/cors.rb`
- PostgreSQL primary database plus Solid Cache/Queue/Cable databases in production (`config/database.yml`)
- Job processing via Solid Queue (`bin/jobs`, `config/queue.yml`), caching via Solid Cache, and Action Cable backed by Solid Cable
- Active Storage configured for local disk in development/test (`config/storage.yml`)
- Kamal + multi-stage `Dockerfile` for containerized deploys with Thruster acting as the HTTP front-end

## Requirements
- Ruby 3.4.7 and Bundler (`gem install bundler` if needed)
- PostgreSQL 13+ running locally or exposed via `DATABASE_URL`
- Build tools for native gems (Xcode CLT on macOS, `build-essential` on Linux)
- A valid `config/master.key` (or `RAILS_MASTER_KEY`) so Rails can decrypt credentials

## Local Setup
1. Install dependencies: `bundle install` (or simply run `bin/setup`).
2. Ensure PostgreSQL is up and reachable. Adjust `config/database.yml` or set `DATABASE_URL` if your connection details differ.
3. Prepare the database: `bin/rails db:prepare`. To rebuild from scratch run `bin/setup --reset`.
4. Seed data lives in `db/seeds.rb`. Execute `bin/rails db:seed` (or `bin/rails db:seed:replant` in test, as CI does) after migrations when required.

`bin/setup` is idempotent: it installs gems, prepares the database, clears logs/tmp, and (unless you pass `--skip-server`) boots the development server so you can start coding immediately.

## Running the App
- **API server:** `bin/dev` wraps `bin/rails server` and serves the API on `http://localhost:3000`.
- **Background jobs:** `bin/jobs` launches the Solid Queue worker defined in `config/queue.yml`. Production runs Solid Queue inside Puma when `SOLID_QUEUE_IN_PUMA=true` (default in `config/deploy.yml`); add dedicated job hosts if needed.
- **Console & tasks:** use `bin/rails console`, `bin/rails dbconsole`, or `bin/rails runner` for scripting.
- **Health check:** `GET /up` hits the built-in Rails health endpoint configured in `config/routes.rb`.
- **CORS:** enable the commented middleware in `config/initializers/cors.rb` and list the allowed frontend origins when you expose the API to browsers.

## Quality & Tests
- Run the suite: `bin/rails test`.
- Static analysis and security checks:
  - `bin/rubocop`
  - `bin/bundler-audit`
  - `bin/brakeman --no-pager`
- Continuous Integration shortcut: `bin/ci` executes the workflow defined in `config/ci.rb` (setup, lint, audits, tests, seed replant).

## Deployment & Operations
- **Docker:** Build the production image via `docker build -t banana_mcp .` and run it with `docker run -d -p 80:80 -e RAILS_MASTER_KEY=... banana_mcp`. The `bin/docker-entrypoint` script automatically runs `bin/rails db:prepare` when the container starts.
- **Kamal:** `config/deploy.yml` ships with a single-host example. Point `servers.web` to your hosts, configure the image registry, and supply secrets (notably `RAILS_MASTER_KEY` and DB credentials) through `.kamal/secrets`. Deploy using `bin/kamal setup` followed by `bin/kamal deploy`.
- **Environment variables:** Production expects `BANANA_MCP_DATABASE_PASSWORD` plus any overrides mentioned in `config/deploy.yml` (`JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `DB_HOST`, etc.). Active Storage files are persisted via the `banana_mcp_storage` volume; change or mount it according to your backup strategy.

## Useful References
- `config/application.rb`: Rails loads defaults for 8.1, autoloads `lib` (skipping `lib/assets` and `lib/tasks`), and sets `config.api_only = true`.
- `config/environments/*`: tweak caching/logging verbosity, enable SSL, set mailer hosts, and control development instrumentation.
- `config/initializers` and `config/storage.yml`: hook up CORS, logging filters, or swap Active Storage services.
- `bin/` scripts: wrappers for RuboCop, Brakeman, Bundler Audit, Solid Queue, Kamal, CI, and the Thruster launcher used in containers.

With Ruby, PostgreSQL, and `RAILS_MASTER_KEY` available, `bin/setup` + `bin/dev` is everything you need to start building APIs. Keep `bin/ci` green before shipping changes.
