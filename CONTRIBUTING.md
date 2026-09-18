# Contributing

Issues and pull requests are welcome at https://github.com/beatmadsen/intent-record.

## Setup

```bash
bin/setup          # bundle install
bundle exec rake   # tests, then rubocop; both must pass
```

Tests run in parallel with one temporary database per test, so nothing touches `~/.intent-record`.

## Mutation testing

```bash
bundle exec rake mutation           # mutineer over lib, fails below the threshold in .mutineer.yml
bundle exec rake mutation:changed   # only the lines you have not committed yet
```

The full lane takes around half a minute against two seconds for `rake`, so it is
not part of the default gate; run it before pushing. `mutation:changed` is the
quick version for the edit loop, and a red there is a prompt to look rather than a
verdict, because a handful of mutants is a small enough sample that one equivalent
mutant sinks the score.

`lib/intent_record/web/routes` sits outside the lane. Sinatra captures a route's
body when the module is registered, which happens before mutineer forks, so every
mutant there is reported as surviving when no test could kill it; making the same
edits by hand does turn the web acceptance tests red.

Each surviving mutant is a change to `lib` that no test objected to. Either add the
test that objects, or, when the mutant is equivalent to the original code, say so in
the pull request.

The lane sets `MUTATION_TESTING=1`, which turns off the process-based parallel
executor in `test/test_helper.rb`. Without that, mutineer forks a worker per mutant
and each worker forks the whole parallel suite again, which exhausts memory on a
machine with many cores. Keep the guard in place when changing the test helper.

## Changes

- Add a failing test before the fix or feature, then make it pass.
- Keep the CLI contract: JSON in, JSON out, exit 1 with `{"error": ...}` on failure, no internal ids in output.
- Add a line under `Unreleased` in `CHANGELOG.md`.

## Releasing

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading and bump `lib/intent_record/version.rb`.
2. `bundle exec rake release` builds the gem, tags `v<version>`, pushes the tag and publishes to rubygems.org. MFA is required.
