require "test_helper"

class InputShapeTest < Minitest::Test
  include IntentRecordDsl

  def test_a_blank_author_is_stored_as_null
    json = record_intent!(author: "  ")

    assert_nil json["author"]
  end

  def test_a_blank_author_is_still_null_when_read_back
    json = record_intent!(author: "  ")

    assert_nil run_cli_ok!("show", json["intent_id"])["author"]
  end

  def test_a_summary_is_trimmed_and_collapsed_to_one_line
    assert_equal "two lines", record_intent!(summary: "  two\nlines  ")["summary"]
  end

  def test_a_body_is_trimmed
    assert_equal "padded", record_intent!(body: "  padded  ")["body"]
  end

  def test_a_null_link_array_is_treated_as_absent
    assert_cli_ok run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => nil })
  end

  def test_a_link_field_that_is_not_an_array_names_the_field
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("attach", id, stdin: { "related_intent_ids" => "x" }), matching: /must be an array/
  end

  def test_record_answers_with_the_commits_it_linked
    json = record_intent!(commits: ["a" * 40])

    assert_equal(["a" * 40], json["asset_versions"].map { |v| v["external_id"] })
  end

  def test_record_answers_with_the_body_it_stored
    assert_equal "Because reasons.", record_intent!["body"]
  end
end
