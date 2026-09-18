require "test_helper"

class AttachTest < Minitest::Test
  include IntentRecordDsl

  HASH = "abc1234abc1234abc1234abc1234abc1234abc12".freeze
  LINEAR = { "system" => "linear", "uri" => "https://l/ENG-9" }.freeze

  def test_attach_adds_commit_after_the_fact
    id = record_intent!["intent_id"]

    run_cli_ok!("attach", id, stdin: { "commits" => [HASH] })

    assert_equal([HASH], run_cli_ok!("show", id)["asset_versions"].map { |v| v["external_id"] })
  end

  def test_attach_adds_a_stakeholder_reference_after_the_fact
    id = record_intent!["intent_id"]

    run_cli_ok!("attach", id, stdin: { "stakeholder_references" => [LINEAR] })

    assert_equal LINEAR["uri"], run_cli_ok!("show", id)["stakeholder_references"].sole["uri"]
  end

  def test_attach_relates_an_earlier_intent_to_this_one
    earlier = record_intent!["intent_id"]
    id = record_intent!["intent_id"]

    run_cli_ok!("attach", id, stdin: { "related_intent_ids" => [earlier] })

    assert_equal([earlier], run_cli_ok!("show", id)["related_intents"].map { |r| r["intent_id"] })
  end

  def test_the_earlier_intent_sees_the_relation_from_its_own_side
    earlier = record_intent!["intent_id"]
    id = record_intent!["intent_id"]

    run_cli_ok!("attach", id, stdin: { "related_intent_ids" => [earlier] })

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
