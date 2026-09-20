# intent-record

[![Gem Version](https://badge.fury.io/rb/intent-record.svg)](https://badge.fury.io/rb/intent-record)
[![CI](https://github.com/beatmadsen/intent-record/actions/workflows/ci.yml/badge.svg)](https://github.com/beatmadsen/intent-record/actions/workflows/ci.yml)

Local records storage for the intent behind individual code changes.

A commit message says what changed. The intent record says why: what the agent (or person) was trying to achieve, which ticket or design page asked for it, and which earlier change it builds on. intent-record stores that in a local SQLite database, links it to the commit hash, and answers the questions people and agents ask later.

- "Why is this line here?" (`git blame --porcelain f.rb | intent-record blame --format git-porcelain`)
- "What was this commit for?" (`lookup <hash>`)
- "What did we build for this Jira ticket, and why that way?" (`by-source <url-or-key>`)
- "Have we touched retry logic before, and what were we thinking?" (`search retry`)

## Installation

```bash
gem install intent-record
```

On first run a config directory is created at `~/.intent-record/` with the database at `~/.intent-record/intent-record.db`. Edit `~/.intent-record/config.yml` to move the database.

To use a different store for one command, pass `--config-dir <dir>` before or after the command name. `INTENT_RECORD_CONFIG_DIR` does the same for a whole shell, except that a misspelled variable name is ignored without a word while a misspelled flag is refused.

```bash
intent-record --config-dir /tmp/scratch recent
```

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

# Or is staring at one line of a file and wants to know why it is there
git blame --porcelain lib/fetch.rb | intent-record blame --format git-porcelain

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
| `lookup <commit> [--vcs name]` | All intents recorded against a commit. Accepts a full hash or a unique prefix of at least 4 characters. Ids are unique per system, not across them, so an id recorded in two systems is reported as ambiguous; name one with `--vcs` |
| `search <terms...> [--match all]` | Search over summary, body, and linked stakeholder URIs and titles, most relevant first, so a ticket key finds its intents |
| `by-source <uri> [--contains]` | Intents linked to a stakeholder source, plus the distinct commits across them. `--contains` matches a substring such as a ticket key |
| `recent [--limit N]` | Newest intents first |
| `systems` | Known VCS and stakeholder system names |
| `blame <options>` | Intents for the commits a blame output names, answered as spans of lines (JSON via stdin) |
| `backfill` | Recover intent records from a history of commit messages (JSON via stdin) |
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

`record` and `attach` both return the full intent record. A record's commits, stakeholder references and related intents come back in the order they were attached.

An intent can be recorded before the commit exists and linked with `attach` afterwards. This also covers rebases and squashes, where the same intent ends up on a new hash. One commit can carry several intents and one intent can span several commits.

## Searching

Results come back most relevant first, not newest first, with a term in a summary
counting for more than the same term somewhere in a long body. Each result carries
the fragment of the body its terms landed in, so a page of hits is readable without
opening any of them.

```bash
intent-record search retry backoff            # either word
intent-record search retry backoff --match all # both
intent-record search "retry the fetch"         # the words in that order
```

A plain word also matches the other forms of itself, so `retry` finds a record that
said `retried`. A term carrying punctuation is matched as the literal you typed:
`100%` does not match "100 percent", and `ACME-4` still finds `ACME-42` the way a
substring search does. That split is why a ticket key works as a search term.

## Why is this line here

`lookup` answers for a commit, which means finding the commit first. That is three
steps: run blame, copy the hash, look it up. `blame` does the whole thing.

```bash
git blame --porcelain lib/fetch.rb | intent-record blame --format git-porcelain
git blame --porcelain -L 40,60 lib/fetch.rb | intent-record blame --format git-porcelain
```

The answer is one entry per change rather than one per line, because neighbouring
lines from the same change collapse into a span:

```json
{"spans": [
  {"from": 40, "to": 44,
   "asset_version": {"vcs": "git", "external_id": "8f3a1c2d..."},
   "intents": [{"intent_id": "EUt4WMY", "summary": "Retry flaky fetches with backoff", "...": "..."}]},
  {"from": 45, "to": 45,
   "asset_version": {"vcs": "git", "external_id": "b2c4e6f8..."},
   "intents": []},
  {"from": 46, "to": 46,
   "asset_version": {"vcs": "git", "external_id": "0000000000..."},
   "intents": [], "uncommitted": true}
]}
```

A change nothing was recorded against still gets a span, with no intents. Leaving it
out would read as "this line has no history", which is a different answer. A line you
have edited but not committed is marked `uncommitted`, because there was never
anything to record against it.

The same change appearing twice in a file with someone else's edit between is two
spans, not one, so a span never claims a line it does not own.

### Other version control systems

`--format git-porcelain` is a convenience. The contract is JSON, and any tool that
can say which change a line came from can feed it:

```bash
echo '{"vcs": "perforce", "lines": [{"line": 40, "external_id": "12345"}]}' | intent-record blame
```

`vcs` defaults to `git`. Line numbers start at 1, and the same line given twice is
rejected rather than answered from one of the two changes.

## Backfilling an existing repo

A repo that adopts intent-record already has years of history, and `lookup` and `by-source` answer nothing for any of it. That history is usually exactly what someone needs when they open unfamiliar code. The ticket keys are already in the commit messages, so `backfill` reads them and writes the rows `record` would have written at the time.

It recovers the graph, not the reasoning. A commit message says what changed, and only the person who made the change knew why. Every backfilled record says so in its body, so an agent that later touches that code knows the real reasoning is still to be attached.

Commits go in on stdin as JSON, so the tool never shells out to git and the same command works for Perforce or Mercurial:

```bash
git log --format='%H%x00%an%x00%B%x01' | ruby -rjson -e '
  commits = $stdin.read.split("\x01").map(&:strip).reject(&:empty?).map do |entry|
    hash, author, message = entry.split("\x00", 3)
    { "commit" => hash, "author" => author, "message" => message.to_s.strip }
  end
  puts JSON.generate({ "commits" => commits })
' > history.json

intent-record backfill --system jira \
  --pattern 'ACME-\d+' \
  --uri-prefix https://acme.atlassian.net/browse/ \
  --dry-run < history.json
```

Start with `--dry-run`. It writes nothing, and it reports the sources it would create and the first twenty commit subjects nothing matched, which is how you find the second convention your team used before anything is written:

```json
{"created": 128, "linked": 0, "skipped": 41, "failed": 0, "dry_run": true,
 "sources": ["https://acme.atlassian.net/browse/ACME-42"],
 "unmatched": ["Fix a typo in the README", "Bump version to 0.4.1"]}
```

Drop `--dry-run` to write. Each commit that names a ticket gets one record, linked to that commit and to every ticket its message names. A commit naming no ticket is not stored at all.

A history may use more than one convention. Run it once per convention, each with its own system:

```bash
intent-record backfill --system github-issues \
  --pattern '(?<![A-Za-z])#(\d+)' \
  --uri-prefix https://github.com/acme/api/issues/ < history.json
```

A commit the first pass already recorded keeps that record and gains the references this pass finds, so a commit naming both a Jira key and a GitHub issue ends up linked to both. The report counts those as `linked` rather than `created`.

Reruns stay cheap. A pass that finds nothing new to link reports the commit as skipped and writes nothing.

### Options

- `--system <name>` names the stakeholder system the references belong to. Required.
- `--pattern <regex>` says what a reference looks like in a message. Required.
- `--uri-prefix <url>` is prepended to the key to give the source uri. Without it, the whole match is the uri.
- `--dry-run` reports what it would write and writes nothing.
- `--order <newest-first|oldest-first>` says which end of the history the list starts at. Defaults to `newest-first`, which is what `git log` gives you.

A capture group narrows what gets appended to the prefix. `ACME-\d+` with prefix `https://acme.atlassian.net/browse/` appends `ACME-42`; `ENG-(\d+)` with prefix `https://linear.app/acme/issue/ENG-` appends `7`. The source is titled with the matched text either way, so `search ENG-7` finds it.

A pattern matches anywhere in the message, including inside another key. `#(\d+)` finds the `77` in an Azure `AB#77` and links it to GitHub issue 77, which is a different thing entirely. Where a history mixes conventions, anchor the loose one: `(?<![A-Za-z])#(\d+)` matches `closes #123` and `fix (#42)` while leaving `AB#77` alone.

Patterns are case-sensitive, and so are the uris they build. A history that writes `ACME-42` in some commits and `acme-42` in others gives you two sources. `(?i)acme-\d+` matches both, but each uri is still built from what the commit wrote, so the two are not merged.

There is no default pattern per system, because Jira and Linear keys look alike and only you know which one `ABC-123` means.

### What it does with the history

Each entry takes a `commit` and an optional `message`, `author` and `ref`. A commit with no message matches nothing and is skipped rather than failing the run. The ref is the branch name, scanned alongside the message for teams that put the key in the branch and never in the commit.

Commits for the same ticket are chained. Each record links to the most recent earlier record for that ticket, so `show` on any one of them walks back through the others, and the chain continues across separate runs.

The chain is always written oldest to newest, so the later commit builds on the earlier one. That needs to know which end of your list is the old end, which is what `--order` says. `git log` prints newest first and that is the default, so a reversed list (`git log --reverse`) needs `--order oldest-first` or every link points backwards.

Each commit is written in its own transaction. One malformed hash in a history of thousands costs that commit and not the run, and the report names it:

```json
{"created": 3, "linked": 0, "skipped": 1, "failed": 1,
 "failures": [{"commit": "bad-hash", "error": "git commit must be 40 or 64 hex characters, got \"bad-hash\""}]}
```

Those failures come back on every rerun, since a hash that is not a hash can never be written.

Rewriting history changes hashes, and a rerun after a rebase links the new hashes to new records. The old ones stay, pointing at commits that no longer exist.

## Data model

Commit hashes are treated as globally unique, so the store does not track which repository a commit belongs to. VCS and stakeholder system names are lowercased on the way in, and the common ones are seeded on first connect; `intent-record systems` lists them. Unknown names are added on first use.

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

Any agent that can run a process and read stdout can use it. Record after each commit, `lookup` before touching unfamiliar code, `by-source` when picking up a ticket that has history, and `backfill` once when adopting the tool on a repository that already has history.

For Claude Code there is a skill that says when to do each of those and what a usable `body` contains: [intent-record](https://github.com/beatmadsen/claude-skills/tree/main/skills/intent-record), in the [beatmadsen/claude-skills](https://github.com/beatmadsen/claude-skills) collection. Install it for every project you work on:

```bash
git clone https://github.com/beatmadsen/claude-skills.git ~/claude-skills
ln -s ~/claude-skills/skills/intent-record ~/.claude/skills/intent-record
```

Or copy `skills/intent-record` into a single project's `.claude/skills/` and commit it, so everyone working in that repository records the same way.

## Development

```bash
bin/setup
bundle exec rake        # tests, then the same tests with unordered queries reversed, then rubocop
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and release steps, and [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## License

[MIT](LICENSE.txt)
