# intent-record

Ruby gem: a local, agent-first store for the intent behind code changes, linked to VCS commits and stakeholder systems (Jira, Confluence, Linear, ...). CLI is JSON in, JSON out; a Sinatra GUI reads the same data.

## Stack

- Ruby >= 3.2, ActiveRecord 8 on SQLite (WAL, foreign keys on), migrations in `db/migrate` run on every connect.
- Sinatra 4 + Puma for `serve`, bound to 127.0.0.1 only.
- Minitest, parallel by process; each test gets its own tmpdir, config and database. Rack::Test for web tests.
- `bundle exec rake` runs the suite, then the same suite with every unordered query
  answered backwards (`rake test:chaos`), then rubocop. All three must be green before a commit.

## Layout

- `lib/intent_record/commands/` one class per CLI command; the web routes call the same classes.
- `lib/intent_record/linkers/` find-or-create logic for commits, stakeholder sources and related intents, shared by `record` and `attach`. Reading a payload is separate from writing rows: `AssetVersionSpecs` decides what a payload asks for and needs no database, `AssetVersionLinker` writes it.
- `lib/intent_record/cli/` argv parsing and dispatch. Adding a command means a `run_<name>` method in `Dispatch`, a line in `USAGE`, a README row, and a line in `UnknownArgvTest::ARGUMENTS` giving argv that gets it past its own required positionals. Tests fail if any of the last three are missing.
- `ArgvParser` is constructed around argv and consumes it. It never alters the array it was given, so a caller that forwards its arguments on asks for `remaining`.
- `lib/intent_record/web/routes/` one module per page, registered on `Web::App`.
- `lib/intent_record/seeds.rb` well-known system names, applied idempotently on connect.
- `Formatter.full` reads four associations per record and loads none of them, so any command formatting more than one record passes its scope through `Formatter.preloaded`. A test asserts the query count does not grow with the number of records.

## Invariants

- Every list the CLI or GUI prints has an order named in SQL. A query with no `ORDER BY` is answered in whatever order the plan produces, not insertion order.
- External ids (commit hashes) are treated as globally unique. No repository identity is stored.
- Internal database ids never appear in CLI output or HTML. Intents are addressed by 7-char base58 `global_id`.
- System names are lowercased on input. Sources are unique per (system, uri).
- The CLI never raises to the user: every `IntentRecord::Error` becomes `{"error": ...}` with exit 1.
- Linking is all or nothing. A git id is checked for shape while it is being linked, so a later entry can fail after earlier ones are written; `record` and `attach` both wrap the linking in a transaction for that reason.
- Acceptance tests drive `IntentRecord::CLI` in-process with injected streams and config. Never read `ENV` or the home directory in tests.

## Gotchas

- Puma renames its process title, so `pkill -f intent-record` does not find a running server. Use `lsof -tiTCP:<port> -sTCP:LISTEN`.
- `IntentRecord::Models::IntentRecord` shadows the top-level module inside `Models`. Refer to constants from `Models` with a full path.
