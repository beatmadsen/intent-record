require "test_helper"

# What a dry run tells a person before they let it write. Which subjects and
# sources a report may hold is Inspection's, and InspectionTest decides it;
# what is left here is that a dry run writes nothing and offers only what it
# really would have created.
class BackfillDryRunTest < Minitest::Test
  include DbTestSetup
  include BackfillDsl

  Intent = IntentRecord::Models::IntentRecord

  def dry_run(commits)
    backfill(commits, dry_run: true)
  end

  def test_a_dry_run_writes_nothing
    dry_run([commit])

    assert_equal 0, Intent.count
  end

  def test_a_dry_run_counts_what_it_would_create
    assert_equal 1, dry_run([commit])["created"]
  end

  # The pattern is never right the first time, and the subjects it missed are
  # how a person finds the second convention their team used.
  def test_a_dry_run_shows_the_subjects_that_matched_nothing
    report = dry_run([commit, unmatched_commit(message: "Fix a typo\n\nbody")])

    assert_equal ["Fix a typo"], report["unmatched"]
  end

  def test_a_dry_run_shows_the_sources_it_would_create
    assert_equal [TICKET], dry_run([commit])["sources"]
  end

  # A commit that already has a record matched the pattern, so it is not an
  # example of the pattern missing.
  def test_an_already_recorded_commit_is_not_offered_as_unmatched
    backfill([commit])

    assert_empty dry_run([commit])["unmatched"]
  end

  # Offering a source it would not in fact create sends someone looking for a
  # row that never appears.
  def test_a_dry_run_does_not_offer_sources_for_commits_it_would_skip
    backfill([commit])

    assert_empty dry_run([commit])["sources"]
  end

  # A write run is not an inspection, and the lists would drown the counts.
  def test_a_write_run_carries_no_inspection
    report = backfill([unmatched_commit])

    refute report.key?("unmatched")
    refute report["dry_run"]
  end

  # The report describes the run it was asked about, not every run the object
  # has seen. The CLI builds a fresh command each time, so nothing today
  # notices, but a report that depends on who held the object before is a trap.
  def test_a_second_call_reports_only_that_call
    command = backfill_command(dry_run: true)
    history = { "commits" => [commit, unmatched_commit, unmatched_commit(hash: SECOND_HASH, message: "nor here")] }

    first = command.call(history).transform_values(&:dup)

    assert_equal first, command.call(history)
  end
end
