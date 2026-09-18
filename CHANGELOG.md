# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-18

First release.

### Added

- `record`, `attach`, `show`, `lookup`, `search`, `by-source`, `recent`, `systems` and `serve` commands. JSON in on stdin, JSON out on stdout, exit 1 with `{"error": ...}` on failure.
- SQLite store at `~/.intent-record/intent-record.db`, created and migrated on first use. Config directory can be moved with `INTENT_RECORD_CONFIG_DIR`.
- Intent records link to any number of asset versions (commits) and stakeholder sources (Jira, Confluence, Linear and others), and to earlier intents they build on.
- Well-known VCS and stakeholder system names are seeded on connect.
- Prefix lookup for hash-based VCSs. Git hashes must be full SHA-1 or SHA-256 and are stored lowercase.
- URI normalisation for stakeholder sources: lowercase scheme and host, no trailing slash.
- Search covers summary, body and linked stakeholder URIs and titles, case-insensitive for non-ASCII letters.
- Local web GUI on 127.0.0.1 with commit, intent, search and stakeholder-source pages.

[Unreleased]: https://github.com/beatmadsen/intent-record/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/beatmadsen/intent-record/releases/tag/v0.1.0
