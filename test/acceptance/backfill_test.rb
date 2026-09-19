require "test_helper"

# The headline use case: a repo adopts intent-record with years of history
# behind it, and wants `by-source` to answer for commits made before adoption.
# The ticket keys are already in the commit messages; backfill turns them into
# the same rows `record` would have written at the time.
class BackfillTest < Minitest::Test
  include IntentRecordDsl

  RETRY_HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze
  TIMEOUT_HASH = "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e".freeze
  TYPO_HASH = "0123456789abcdef0123456789abcdef01234567".freeze

  JIRA_OPTIONS = ["--system", "jira",
                  "--pattern", 'ACME-\d+',
                  "--uri-prefix", "https://acme.atlassian.net/browse/"].freeze

  HISTORY = {
    "commits" => [
      { "commit" => RETRY_HASH, "author" => "Dana",
        "message" => "ACME-42 Retry flaky fetches\n\nCI went red three times this week." },
      { "commit" => TIMEOUT_HASH, "author" => "Dana",
        "message" => "ACME-42 Raise the fetch timeout" },
      { "commit" => TYPO_HASH, "author" => "Sam", "message" => "Fix a typo in the README" }
    ]
  }.freeze

  def test_ticket_in_a_commit_message_becomes_a_queryable_source
    run_cli_ok!("backfill", *JIRA_OPTIONS, stdin: HISTORY)

    found = run_cli_ok!("by-source", "https://acme.atlassian.net/browse/ACME-42")

    assert_equal [RETRY_HASH, TIMEOUT_HASH].sort, found["asset_versions"].map { |c| c["external_id"] }.sort
  end

  def test_backfilled_commit_answers_lookup_with_the_subject_line
    run_cli_ok!("backfill", *JIRA_OPTIONS, stdin: HISTORY)

    found = run_cli_ok!("lookup", RETRY_HASH)

    assert_equal "ACME-42 Retry flaky fetches", found["intents"].sole["summary"]
  end

  # Not merely unlinked: never stored. An intent whose body restates the commit
  # message and names no ticket adds nothing the VCS does not already hold.
  def test_commit_naming_no_ticket_is_left_out_of_the_store_entirely
    run_cli_ok!("backfill", *JIRA_OPTIONS, stdin: HISTORY)

    result = run_cli("lookup", TYPO_HASH)

    assert_cli_rejected result, matching: /not found/
  end

  def test_reports_what_it_created_and_what_it_passed_over
    json = run_cli_ok!("backfill", *JIRA_OPTIONS, stdin: HISTORY)

    assert_equal 2, json["created"]
    assert_equal 1, json["skipped"]
  end
end
