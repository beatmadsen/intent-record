# Contributing

Issues and pull requests are welcome at https://github.com/beatmadsen/intent-record.

Every push and pull request runs `bundle exec rake` on Ruby 3.2, 3.3, 3.4 and 4.0, which is
the oldest version the gem claims to support through the newest one released.

## Setup

```bash
bin/setup          # bundle install
bundle exec rake   # tests, then the chaos lane below, then rubocop; all three must pass
```

Tests run in parallel with one temporary database per test, so nothing touches `~/.intent-record`.

## The chaos lane

```bash
bundle exec rake test:chaos   # the suite again, with every unordered query answered backwards
```

A `SELECT` with no `ORDER BY` promises nothing about the order of its rows, and
SQLite already answers some of them from an index rather than in insertion order.
A test that asserts on such an order agrees with the query plan in force today and
says nothing about the one an added index will produce tomorrow. This lane reverses
the rows of every result whose query did not name an order, which is as legal an
answer as the one SQLite gave, so an assertion that survives both lanes has pinned
the order itself. It reverses rather than shuffles, so it decides the same thing on
every run. See `test/support/unordered_rows.rb`.

A test that fails only in this lane was relying on an order nothing promised it.
The fix belongs in the query, which has to name the order, rather than in the
assertion.

## Mutation testing

```bash
bundle exec rake mutation           # mutineer over lib, fails below the threshold in .mutineer.yml
bundle exec rake mutation:changed   # only the lines you have not committed yet
```

The lane needs Ruby 3.4 or newer, which is what mutineer requires; on 3.2 or 3.3 it
is not in the bundle at all.

The full lane takes around half a minute against two seconds for `rake`, so it is
not part of the default gate; run it before pushing. `mutation:changed` is the
quick version for the edit loop, and a red there is a prompt to look rather than a
verdict, because a handful of mutants is a small enough sample that one equivalent
mutant sinks the score.

A `module_function` method is reported as having no coverage even when the suite
exercises it thoroughly. `module_function` leaves behind a private instance copy
that nothing calls, and that is the copy the lane measures; the callers use the
singleton copy. Check by breaking the method and running the suite before
believing the report.

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
- The changelog records the difference between released versions. Nothing is released yet, so
  `Unreleased` stays empty; once there is a published version to compare against, add a line
  there for anything a user of the gem would notice.

## Releasing

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading and bump `lib/intent_record/version.rb`.
2. `bundle exec rake release` builds the gem, tags `v<version>`, pushes the tag and publishes to rubygems.org. MFA is required.
