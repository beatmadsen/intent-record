# intent-record

Local records storage for the intent behind individual code changes.

A commit message says what changed. The intent record says why: what the agent (or person) was trying to achieve, which ticket or design page asked for it, and which earlier change it builds on. intent-record stores that in a local SQLite database, links it to the commit hash, and answers the questions people and agents ask later.

- "What was this commit for?" (`lookup <hash>`)
- "What did we build for this Jira ticket, and why that way?" (`by-source <url-or-key>`)
- "Have we touched retry logic before, and what were we thinking?" (`search retry`)

## Installation

```bash
gem install intent-record
```

On first run a config directory is created at `~/.intent-record/` with the database at `~/.intent-record/intent-record.db`. Edit `~/.intent-record/config.yml` to move the database, or set `INTENT_RECORD_CONFIG_DIR` to point at a different config directory.

## Quick start

```bash
# After committing a change, record why it was made
echo '{
  "summary": "Retry flaky fetches with backoff",
  "body": "CI failed three times this week on transient DNS errors. Retrying 3x with exponential backoff instead of failing the build.",
  "author": "claude",
  "commits": ["8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2"],
  "stakeholder_references": [
    {"system": "jira", "uri": "https://acme.atlassian.net/browse/ACME-42", "title": "Flaky fetch in CI"}
  ]
}' | intent-record record
# => {"intent_id":"EUt4WMY","summary":"Retry flaky fetches with backoff", ... full record ...}

# Later, someone stares at that commit in git blame
intent-record lookup 8f3a1c2

# Or comes at it from the ticket
intent-record by-source ACME-42 --contains

# Or wants to read it in a browser
intent-record serve
```

## Commands

JSON in on stdin where input is needed, JSON out on stdout, exit code 0 on success and 1 with `{"error": "..."}` otherwise.

| Command | Description |
|---|---|
| `record` | Record the intent behind a change (JSON via stdin) |
| `attach <intent_id>` | Link more commits, stakeholder references or related intents to an existing record (JSON via stdin) |
| `show <intent_id>` | Full intent record with commits, stakeholder links and related intents |
| `lookup <commit> [--vcs name]` | All intents recorded against a commit. Accepts a full hash or a unique prefix of at least 4 characters |
| `search <terms...> [--match all]` | Case-insensitive substring search over summary, body, and linked stakeholder URIs and titles, so a ticket key finds its intents |
| `by-source <uri> [--contains]` | Intents linked to a stakeholder source, plus the distinct commits across them. `--contains` matches a substring such as a ticket key |
| `recent [--limit N]` | Newest intents first |
| `systems` | Known VCS and stakeholder system names |
| `serve [--port N]` | Start the web GUI on 127.0.0.1 (default port 4791) |

### Input shape for `record` and `attach`

```json
{
  "summary": "one line, at most 350 characters (record only, required)",
  "body": "the reasoning, as long as it needs to be (record only, required)",
  "author": "optional: agent or person name",
  "commits": ["git hashes; shorthand for asset_versions with vcs git"],
  "asset_versions": [{"vcs": "perforce", "external_id": "12345"}],
  "stakeholder_references": [{"system": "jira", "uri": "https://...", "title": "optional"}],
  "related_intent_ids": ["intent ids this change builds on"]
}
```

Options take either `--name value` or `--name=value`. Unknown options and stray arguments are rejected rather than ignored.

`lookup` without `--vcs` searches every system and prefers an exact id match over a prefix match. Git commits must be full SHA-1 or SHA-256 hashes; they are stored lowercase. Prefix lookup applies to hash-based systems only (git, mercurial, fossil, sapling, pijul, darcs), so a Perforce changelist `1234` never matches `12345`. URIs are normalised (lowercase scheme and host, no trailing slash) and system names are lowercased and hyphenated, so `Jira` and `jira`, or a ticket URL with and without a trailing slash, are one source. A later non-blank `title` for a source replaces the stored one.

`record` and `attach` both return the full intent record.

An intent can be recorded before the commit exists and linked with `attach` afterwards. This also covers rebases and squashes, where the same intent ends up on a new hash. One commit can carry several intents and one intent can span several commits.

## Data model

Commit hashes are treated as globally unique, so the store does not track which repository a commit belongs to. VCS and stakeholder system names are lowercased on the way in, and the common ones are seeded on first connect (git, mercurial, perforce, jira, confluence, linear, github-issues, notion, slack and around forty more; `intent-record systems` lists them). Unknown names are added on first use.

```
vcs_systems            (name)
asset_versions         (vcs_system, external_id)         a commit, changelist, revision
intent_records         (global_id, summary, body, author)
intent_record_asset_versions                             intent <-> asset version, many to many
stakeholder_systems    (name)
stakeholder_sources    (stakeholder_system, uri, title)  a ticket, page, thread
stakeholder_references                                   intent <-> source, many to many
intent_record_links    (source, target)                  intent builds on intent
```

Intent ids are random 7-character base58 strings. Database ids never appear in output.

Related-intent links may form cycles; the store records what it is told and leaves the meaning to the reader. Bodies have no size cap.

## Web GUI

`intent-record serve` binds to localhost only. The home page has one box: paste a commit hash, a ticket URL, or a few words, and it takes you to the right page. Commit pages list every intent for that hash; source pages list every intent and every commit for a ticket.

## Agent integration

Any agent that can run a process and read stdout can use it. Record after each commit, `lookup` before touching unfamiliar code, `by-source` when picking up a ticket that has history.

## Development

```bash
bin/setup
bundle exec rake        # tests, then rubocop
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and release steps, and [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## License

[MIT](LICENSE.txt)
