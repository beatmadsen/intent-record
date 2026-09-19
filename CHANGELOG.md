# Changelog

Notable changes, one section per released version. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- `backfill` recovers intent records from a history of commit messages, for repos that adopt the tool with years of history already behind them. Commits go in on stdin as JSON, a `--pattern` says what a ticket reference looks like and a `--uri-prefix` turns each match into a stakeholder source, so `lookup` and `by-source` answer for commits made long before adoption.
- Each backfilled record says in its body that the reasoning behind the change was never recorded, which is what an agent looks for when deciding where to attach the real one.
- Commits for one ticket are chained oldest to newest, so `show` on any of them walks back through the others. `--order` says which end of the history the input starts at, defaulting to the newest-first order `git log` prints.
- `--dry-run` writes nothing and reports the sources it would create along with the commit subjects that matched nothing, which is how a pattern gets corrected before it writes anything.

## 1.0.0 - 2026-09-18

First release.

- `record`, `attach`, `show`, `lookup`, `search`, `by-source`, `recent`, `systems` and `serve`. JSON in on stdin, JSON out on stdout, exit 1 with `{"error": ...}` on failure. Argv a command does not recognise is refused rather than ignored.
- SQLite store at `~/.intent-record/`, created and migrated on first use. `--config-dir` points one command at another store, `INTENT_RECORD_CONFIG_DIR` points a whole shell at one.
- An intent links to any number of commits, to stakeholder sources such as Jira, Confluence and Linear, and to earlier intents it builds on. Commits can be attached after the fact, which covers rebases and squashes.
- Prefix lookup from four characters for hash-based systems. An id recorded in two systems is reported as ambiguous rather than answered with one of them.
- Every list comes back in an order the query names, in both the CLI and the GUI.
- Local web GUI on 127.0.0.1 with commit, intent, search and stakeholder source pages.
