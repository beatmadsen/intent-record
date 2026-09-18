require "test_helper"

class ShowTest < Minitest::Test
  include IntentRecordDsl

  HASH = "abc1234abc1234abc1234abc1234abc1234abc12".freeze
  LINEAR = { "system" => "linear", "uri" => "https://linear.app/x/ENG-1" }.freeze

  def test_show_returns_the_summary_body_and_author_as_recorded
    id = record_intent!(summary: "S", body: "B", author: "claude")["intent_id"]

    shown = run_cli_ok!("show", id)

    assert_equal "S", shown["summary"]
    assert_equal "B", shown["body"]
    assert_equal "claude", shown["author"]
  end

  def test_show_returns_the_commits_linked_to_the_intent
    id = record_intent!(commits: [HASH])["intent_id"]

    shown = run_cli_ok!("show", id)

    assert_equal [{ "vcs" => "git", "external_id" => HASH }], shown["asset_versions"]
  end

  def test_show_returns_the_stakeholder_references_linked_to_the_intent
    id = record_intent!(stakeholder_references: [LINEAR])["intent_id"]

    shown = run_cli_ok!("show", id)

    assert_equal "linear", shown["stakeholder_references"].sole["system"]
  end

  def test_show_returns_the_creation_time_as_an_iso_timestamp
    id = record_intent!["intent_id"]

    shown = run_cli_ok!("show", id)

    assert_match(/\A\d{4}-\d{2}-\d{2}T/, shown["created_at"])
  end

  def test_show_unknown_id_is_not_found
    assert_cli_rejected run_cli("show", "zzzzzzz"), matching: /not found/i
  end
end
