# Contributing

Issues and pull requests are welcome at https://github.com/beatmadsen/intent-record.

## Setup

```bash
bin/setup          # bundle install
bundle exec rake   # tests, then rubocop; both must pass
```

Tests run in parallel with one temporary database per test, so nothing touches `~/.intent-record`.

## Changes

- Add a failing test before the fix or feature, then make it pass.
- Keep the CLI contract: JSON in, JSON out, exit 1 with `{"error": ...}` on failure, no internal ids in output.
- Add a line under `Unreleased` in `CHANGELOG.md`.

## Releasing

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading and bump `lib/intent_record/version.rb`.
2. `bundle exec rake release` builds the gem, tags `v<version>`, pushes the tag and publishes to rubygems.org. MFA is required.
