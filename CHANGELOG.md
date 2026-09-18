# Changelog

Notable changes, one section per released version. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 1.0.0 - 2026-09-18

First release.

- `record`, `attach`, `show`, `lookup`, `search`, `by-source`, `recent`, `systems` and `serve`. JSON in on stdin, JSON out on stdout, exit 1 with `{"error": ...}` on failure. Argv a command does not recognise is refused rather than ignored.
- SQLite store at `~/.intent-record/`, created and migrated on first use. `--config-dir` points one command at another store, `INTENT_RECORD_CONFIG_DIR` points a whole shell at one.
- An intent links to any number of commits, to stakeholder sources such as Jira, Confluence and Linear, and to earlier intents it builds on. Commits can be attached after the fact, which covers rebases and squashes.
- Prefix lookup from four characters for hash-based systems. An id recorded in two systems is reported as ambiguous rather than answered with one of them.
- Every list comes back in an order the query names, in both the CLI and the GUI.
- Local web GUI on 127.0.0.1 with commit, intent, search and stakeholder source pages.
