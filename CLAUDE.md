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
- `lib/intent_record/backfill/` the database-free half of `backfill`: `CommitSpecs` reads the payload, `ReferenceScanner` decides which sources a message names, `BackfilledIntent` writes the text a recovered record carries. The command itself writes rows through `Commands::Record`, so linking stays in one place.
- `lib/intent_record/blame/` the database-free half of `blame`: `Spans` reads the payload and collapses neighbouring lines from one change, `Porcelain` reads `git blame --porcelain` into the same payload a person could write by hand. The command itself only looks asset versions up, so the store still knows nothing about git.
- Search is split three ways, because the two ways of matching a term are not interchangeable: `SearchTerm` reads one term a person typed, `SearchMembership` decides which records answer, `SearchRanking` and `SearchSnippet` decide the order and the fragment shown. None of them needs a database to build its SQL.
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
- `backfill` writes one record per commit and chains them oldest to newest, so a test feeding it commits must say which end of the history it is feeding. `git log` prints newest first and that is the default; a fixture in the other order and no `--order` is a test that proves nothing about what a user pipes in.
- FTS5 ranks, it never filters. It tokenises, so it cannot see `ACME-4` inside `ACME-42` and it cannot tell `100%` from `100 percent`; `LikeEscapingTest` refuses both. Substring matching decides membership, and the index only widens it for a term that is plainly a word (`MatchExpression.word?`), which is what makes `retry` find `retried`.
- Linking is all or nothing. A git id is checked for shape while it is being linked, so a later entry can fail after earlier ones are written; `record` and `attach` both wrap the linking in a transaction for that reason.
- Acceptance tests drive `IntentRecord::CLI` in-process with injected streams and config. Never read `ENV` or the home directory in tests.
- A test process cannot reach the real store or leave a server running, and does not rely on remembering not to. `test/support/store_confinement.rb` refuses any store path outside `Dir.tmpdir`, at `Config`, `Database` and `SQLite3::Database`. `test/support/port_confinement.rb` refuses a TCP bind unless the test wraps it in `PortConfinement.binding_a_port`, which only `ServeTest` does. Each fails every test if its own guard is missing.

## Gotchas

- The `Commands:` block of `CLI::USAGE` is parsed by taking the first word of every line, so a command's description must stay on one line. A two-line one advertises a command named after the first word of its second line, and `CommandsAndUsageTest` fails. Anything longer goes in its own section below, as `backfill` and search terms do.
- `bm25()` and `snippet()` only evaluate where SQLite has kept the query's FTS context. The search query groups, and under that a join onto the index, a join onto a subquery over it, and a plain CTE all fail with "unable to use function bm25 in the requested context" because the flattener folds them into the outer query. A correlated subquery keeps the context but is planned as a scan of the whole match set per candidate row: measured, eight seconds for a common word on twenty-five thousand records. The shape that works is a subquery join with `LIMIT -1`, which the flattener leaves alone (the plan says `MATERIALIZE`), so relevance and fragment are computed once per search. `SearchRankingPlanTest` pins that plan; a change that answers identically and costs thirty times as much is one it exists to catch.
- Puma renames its process title, so `pkill -f intent-record` does not find a running server. Use `lsof -tiTCP:<port> -sTCP:LISTEN`. A test that reaches `serve` must stub `Web::App.run!`, or the port confinement refuses the bind.
- To drive the real executable against a scratch store, pass `--config-dir <dir>`. Prefer it to `INTENT_RECORD_CONFIG_DIR`: an environment variable nobody set is indistinguishable from one that is honoured, so a typo in the name sends the command at `~/.intent-record`, whereas a typo in the flag is refused as unknown argv.
- `IntentRecord::Models::IntentRecord` shadows the top-level module inside `Models`. Refer to constants from `Models` with a full path.
