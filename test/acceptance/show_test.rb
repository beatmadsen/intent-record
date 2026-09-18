require "test_helper"

class ShowTest < Minitest::Test
  include IntentRecordDsl

  def test_show_returns_full_record_with_links
    json = record_intent!(summary: "S", body: "B", author: "claude",
                          commits: ["abc1234abc1234abc1234abc1234abc1234abc12"],
                          stakeholder_references: [{ "system" => "linear", "uri" => "https://linear.app/x/ENG-1" }])

    shown = run_cli_ok!("show", json["intent_id"])

    assert_equal "S", shown["summary"]
    assert_equal "claude", shown["author"]
    assert_equal [{ "vcs" => "git", "external_id" => "abc1234abc1234abc1234abc1234abc1234abc12" }], shown["asset_versions"]
    assert_equal "linear", shown["stakeholder_references"].sole["system"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, shown["created_at"])
  end

  def test_show_unknown_id_is_not_found
    assert_cli_rejected run_cli("show", "zzzzzzz"), matching: /not found/i
  end
end
