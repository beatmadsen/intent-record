require "test_helper"

# The headline use case: a repo adopts intent-record with years of history
# behind it, and wants `lookup` and `by-source` to answer for commits made long
# before adoption. The ticket keys are already in the commit messages, and
# backfill turns them into the rows `record` would have written at the time.
class BackfillTest < Minitest::Test
  include IntentRecordDsl
  include BackfillDsl

  OPTIONS = ["--system", "jira", "--pattern", 'ACME-\d+', "--uri-prefix", BackfillDsl::PREFIX].freeze

  HISTORY = {
    "commits" => [
      { "commit" => BackfillDsl::RETRY_HASH, "author" => "Dana",
        "message" => "#{BackfillDsl::RETRY_SUBJECT}\n\nCI went red three times this week." },
      { "commit" => BackfillDsl::SECOND_HASH, "author" => "Dana", "message" => BackfillDsl::TIMEOUT_SUBJECT },
      { "commit" => BackfillDsl::TYPO_HASH, "author" => "Sam", "message" => "Fix a typo in the README" }
    ]
  }.freeze

  def backfill_history(*extra)
    run_cli_ok!("backfill", *OPTIONS, *extra, stdin: HISTORY)
  end

  def test_ticket_in_a_commit_message_becomes_a_queryable_source
    backfill_history

    found = run_cli_ok!("by-source", TICKET)

    assert_equal [RETRY_HASH, SECOND_HASH].sort, found["asset_versions"].map { |v| v["external_id"] }.sort
  end

  def test_a_backfilled_commit_answers_lookup_with_its_subject_line
    backfill_history

    assert_equal RETRY_SUBJECT, run_cli_ok!("lookup", RETRY_HASH)["intents"].sole["summary"]
  end

  # An agent reading this later needs to know the reasoning was never captured,
  # so it can attach the real one instead of trusting the commit message.
  def test_a_backfilled_record_says_its_reasoning_was_never_recorded
    backfill_history

    body = run_cli_ok!("lookup", RETRY_HASH)["intents"].sole["body"]

    assert_includes body, IntentRecord::Backfill::BackfilledIntent::MARKER
  end

  # Not merely unlinked: never stored at all.
  def test_a_commit_naming_no_ticket_is_left_out_of_the_store_entirely
    backfill_history

    assert_cli_rejected run_cli("lookup", TYPO_HASH), matching: /not found/
  end

  def test_a_dry_run_says_so_and_leaves_the_store_empty
    json = run_cli_ok!("backfill", *OPTIONS, "--dry-run", stdin: HISTORY)

    assert_equal true, json["dry_run"]
    assert_cli_rejected run_cli("lookup", RETRY_HASH), matching: /not found/
  end

  def test_it_reports_what_it_created_and_what_it_passed_over
    json = backfill_history

    assert_equal [2, 1], [json["created"], json["skipped"]]
  end
end
