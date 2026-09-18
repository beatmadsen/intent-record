# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Nothing has been released yet. Everything below describes what the first
release will contain, not changes against a published version.

## Unreleased

### Added

- `record`, `attach`, `show`, `lookup`, `search`, `by-source`, `recent`, `systems` and `serve` commands. JSON in on stdin, JSON out on stdout, exit 1 with `{"error": ...}` on failure. A command given argv it does not recognise says so instead of ignoring it, and a mistyped command lists the commands there are.
- SQLite store at `~/.intent-record/intent-record.db`, created and migrated on first use. The config directory can be moved with `INTENT_RECORD_CONFIG_DIR`. A path that cannot be written reports `{"error": ...}` and exit 1, whether the database file itself is read-only or its directory is not writable.
- Intent records link to any number of asset versions (commits) and stakeholder sources (Jira, Confluence, Linear and others), and to earlier intents they build on.
- Every list in a response comes back in an order the query names. A record's commits, stakeholder references and related intents are in the order they were attached, and the sources `by-source` matched are in the order they were first recorded.
- Prefix lookup for hash-based version control systems, from 4 characters up. Git hashes must be a full SHA-1 or SHA-256 and are stored lowercase. An id recorded in two systems is reported as ambiguous rather than answered with one of them, because ids are unique per system and not across them, so a Perforce changelist and a Subversion revision can spell the same thing. Pass `--vcs` to choose. An id from a case-sensitive system is found with or without `--vcs`.
- Well-known VCS and stakeholder system names are seeded on connect.
- URI normalisation for stakeholder sources: lowercase scheme and host, no trailing slash. A URI with a scheme but no host still has its scheme lowercased, so `MAILTO:a@b.com` and `mailto:a@b.com` are one source rather than two. A bare ticket key such as `ACME-42` is kept exactly as written.
- Leading and trailing whitespace is removed from every string field on input, so an author or a stakeholder title does not keep its padding, and a summary is measured against the 350 character limit after trimming. Ids are trimmed too, on stdin and as command arguments, so an id assembled with a stray space still names the record it names.
- Search covers summary, body and linked stakeholder URIs and titles, case-insensitive for non-ASCII letters.
- Two commands can run at once. SQLite is given a busy timeout, so a write that meets a concurrent one waits rather than failing, and setting up a new store is serialised on a lock file, so two processes reaching one together do not both try to create the tables.
- Local web GUI on 127.0.0.1 with commit, intent, search and stakeholder-source pages. `serve` takes `--port` and refuses a port outside 1 to 65535, one that needs elevated privileges, and one already in use, naming the port in each case.
