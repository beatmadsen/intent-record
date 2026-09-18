# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `lookup` finds an id from a case-sensitive VCS when no `--vcs` is given. The id was lowercased before the search, so a Perforce changelist stored as `ABC123` resolved with `--vcs perforce` and not at all without it.
- A database path that cannot be written reports `{"error": ...}` and exit 1. A read-only database file, or a database in a directory that exists but is not writable, let a Ruby exception escape instead.
- `serve` reports a bad `--port` as `{"error": ...}` instead of letting a Ruby exception escape. A port above 65535 failed with a socket resolution error that never mentioned ports, and a port needing elevated privileges, such as 80, failed with a bare permission error.
- A stakeholder URI with a scheme but no host has its scheme lowercased, so `MAILTO:a@b.com` and `mailto:a@b.com` are one source rather than two. A bare ticket key such as `ACME-42` is still kept exactly as written.

### Changed

- Leading and trailing whitespace is removed from every string field on input, so an author or a stakeholder title no longer keeps its padding. A summary is measured against the 350 character limit after trimming rather than before.

## [1.0.0] - 2026-09-18

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

[Unreleased]: https://github.com/beatmadsen/intent-record/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/beatmadsen/intent-record/releases/tag/v1.0.0
