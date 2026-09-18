require "test_helper"

class AttachTest < Minitest::Test
  include IntentRecordDsl

  HASH = "abc1234abc1234abc1234abc1234abc1234abc12".freeze

  def test_attach_adds_commit_after_the_fact
    id = record_intent!["intent_id"]

    run_cli_ok!("attach", id, stdin: { "commits" => [HASH] })

    assert_equal([HASH], run_cli_ok!("show", id)["asset_versions"].map { |v| v["external_id"] })
  end

  def test_attach_adds_stakeholder_reference_and_related_intent
    earlier = record_intent!["intent_id"]
    id = record_intent!["intent_id"]

    payload = { "stakeholder_references" => [{ "system" => "linear", "uri" => "https://l/ENG-9" }],
                "related_intent_ids" => [earlier] }
    run_cli_ok!("attach", id, stdin: payload)

    shown = run_cli_ok!("show", id)
    assert_equal "https://l/ENG-9", shown["stakeholder_references"].sole["uri"]
    assert_equal([earlier], shown["related_intents"].map { |r| r["intent_id"] })
    assert_equal([id], run_cli_ok!("show", earlier)["related_by_intents"].map { |r| r["intent_id"] })
  end

  def test_attach_with_nothing_to_attach_is_rejected
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("attach", id, stdin: {}), matching: /nothing to attach/i
  end

  def test_attach_to_unknown_intent_is_not_found
    assert_cli_rejected run_cli("attach", "zzzzzzz", stdin: { "commits" => [HASH] }), matching: /not found/i
  end

  def test_attach_relating_an_intent_to_itself_is_rejected
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("attach", id, stdin: { "related_intent_ids" => [id] }),
                        matching: /cannot link to itself/i
  end

  def test_attach_relating_an_unknown_intent_is_not_found
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("attach", id, stdin: { "related_intent_ids" => ["zzzzzzz"] }),
                        matching: /related intent record not found/i
  end

  def test_attach_same_commit_twice_is_idempotent
    id = record_intent!(commits: [HASH])["intent_id"]

    run_cli_ok!("attach", id, stdin: { "commits" => [HASH] })

    assert_equal 1, run_cli_ok!("show", id)["asset_versions"].size
  end
end
