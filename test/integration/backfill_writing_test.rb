require "test_helper"

# Which commits backfill writes a record for, and what that record is linked
# to. The matching rules are ReferenceScanner's, the wording is
# BackfilledIntent's and the dry run's report is Inspection's.
class BackfillWritingTest < Minitest::Test
  include DbTestSetup
  include BackfillDsl

  Intent = IntentRecord::Models::IntentRecord

  def test_a_commit_naming_a_ticket_gets_a_record
    backfill([commit])

    assert_equal 1, Intent.count
  end

  # Not merely unlinked: an intent restating the commit message and naming no
  # ticket adds nothing git does not already hold.
  def test_a_commit_naming_nothing_gets_no_record
    backfill([unmatched_commit])

    assert_equal 0, Intent.count
  end

  def test_the_record_is_linked_to_its_commit
    backfill([commit])

    assert_equal RETRY_HASH, Intent.sole.asset_versions.sole.external_id
  end

  def test_the_record_is_linked_to_the_ticket_the_message_named
    backfill([commit])

    assert_equal TICKET, Intent.sole.stakeholder_sources.sole.uri
  end

  # The ticket is often only in the branch name, never in the message.
  def test_a_ticket_named_only_in_the_ref_is_found
    backfill([commit(message: "Retry flaky fetches", ref: "feature/ACME-42-retry")])

    assert_equal TICKET, Intent.sole.stakeholder_sources.sole.uri
  end

  def test_the_commit_author_is_carried_onto_the_record
    backfill([commit(author: "Dana")])

    assert_equal "Dana", Intent.sole.author
  end

  # Running it again is how a person adds the convention they missed, so it has
  # to be cheap rather than doubling every record.
  def test_running_it_again_writes_nothing_further
    backfill([commit])
    backfill([commit])

    assert_equal 1, Intent.count
  end

  def test_a_commit_that_already_has_an_intent_is_reported_as_skipped
    backfill([commit])

    assert_equal 1, backfill([commit])["skipped"]
  end

  def test_it_reports_what_it_created_and_passed_over
    report = backfill([commit, unmatched_commit])

    assert_equal({ "created" => 1, "skipped" => 1, "failed" => 0 }, report.slice("created", "skipped", "failed"))
  end

  # One malformed hash in a history of thousands must not cost the whole run.
  def test_a_commit_that_cannot_be_written_is_reported_without_losing_the_rest
    report = backfill([commit(hash: "not-a-hash"), commit])

    assert_equal [1, 1], [report["created"], report["failed"]]
    assert_equal 1, Intent.count
  end

  def test_a_failed_commit_is_named_with_its_reason
    failure = backfill([commit(hash: "not-a-hash")])["failures"].sole

    assert_equal "not-a-hash", failure["commit"]
    assert_match(/hex/, failure["error"])
  end

  # The README tells people to run a second pass for the convention the first
  # pattern missed. A commit found by both passes must not gain a second
  # record, and the sources are one per uri however they were found.
  def test_a_second_pass_with_another_pattern_adds_only_what_the_first_missed
    backfill([commit])
    second = IntentRecord::Commands::Backfill.scanning(system: "jira", pattern: 'acme-\d+', uri_prefix: PREFIX)
    second.call({ "commits" => [commit(hash: SECOND_HASH, message: "acme-42 lowercase key")] })

    assert_equal 2, Intent.count
    assert_equal 2, IntentRecord::Models::StakeholderSource.count
  end

  def test_an_order_it_does_not_know_is_refused
    error = assert_raises(IntentRecord::ValidationError) { backfill([commit], order: "sideways") }

    assert_match(/order/, error.message)
  end
end
