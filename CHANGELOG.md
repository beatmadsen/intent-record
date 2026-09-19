# Changelog

Notable changes, one section per released version. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.1.0 - 2026-09-19

### Added

- `backfill`, which recovers intent records from a repository's commit history. Commits go in on stdin as JSON, `--pattern` says what a ticket reference looks like and `--uri-prefix` turns each match into a stakeholder source. Afterwards `lookup` and `by-source` answer for commits made before the tool was adopted.
- A backfilled record says in its body that the reasoning was never recorded, so an agent can tell where the real reasoning still needs attaching.
- Commits for one ticket are chained oldest to newest. `--order` says which end of the input is the old end and defaults to newest-first, the order `git log` prints.
- A later pass with a different pattern adds its references to the records an earlier pass created and reports them as `linked`. A pass that finds nothing new writes nothing.
- `--dry-run` writes nothing and reports the sources it would create and the commit subjects nothing matched.

## 1.0.0 - 2026-09-18

First release.

- `record`, `attach`, `show`, `lookup`, `search`, `by-source`, `recent`, `systems` and `serve`. JSON in on stdin, JSON out on stdout, exit 1 with `{"error": ...}` on failure. Argv a command does not recognise is refused rather than ignored.
- SQLite store at `~/.intent-record/`, created and migrated on first use. `--config-dir` points one command at another store, `INTENT_RECORD_CONFIG_DIR` points a whole shell at one.
- An intent links to any number of commits, to stakeholder sources such as Jira, Confluence and Linear, and to earlier intents it builds on. Commits can be attached after the fact, which covers rebases and squashes.
- Prefix lookup from four characters for hash-based systems. An id recorded in two systems is reported as ambiguous rather than answered with one of them.
- Every list comes back in an order the query names, in both the CLI and the GUI.
- Local web GUI on 127.0.0.1 with commit, intent, search and stakeholder source pages.
