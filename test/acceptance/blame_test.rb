require "test_helper"

# "Why is this line here" is the question the store exists to answer, and until
# now answering it took three steps: run blame, copy the hash out of it, look the
# hash up. Most people stop after the first and read the commit subject instead.
class BlameTest < Minitest::Test
  include IntentRecordDsl

  FIRST = ("a" * 40).freeze
  SECOND = ("b" * 40).freeze

  def lines(*pairs)
    pairs.map { |line, id| { "line" => line, "external_id" => id } }
  end

  def blame(*pairs, **extra)
    run_cli_ok!("blame", stdin: { "lines" => lines(*pairs) }.merge(extra.transform_keys(&:to_s)))
  end

  def test_a_line_is_answered_with_the_intent_recorded_against_its_commit
    intent = record_intent!(summary: "Retry flaky fetches", commits: [FIRST])

    span = blame([40, FIRST]).fetch("spans").sole

    assert_equal([intent["intent_id"]], span["intents"].map { |i| i["intent_id"] })
  end

  # A reader asked about a range, so the answer is about the range: one entry per
  # change rather than one per line, or the useful part is buried in repetition.
  def test_neighbouring_lines_from_one_commit_are_answered_once_as_a_span
    record_intent!(commits: [FIRST])

    span = blame([40, FIRST], [41, FIRST], [42, FIRST]).fetch("spans").sole

    assert_equal({ "from" => 40, "to" => 42 }, span.slice("from", "to"))
  end

  def test_spans_are_answered_in_file_order
    spans = blame([12, SECOND], [10, FIRST], [11, FIRST]).fetch("spans")

    assert_equal([10, 12], spans.map { |s| s["from"] })
  end

  # The same commit either side of someone else's edit is two places in the file,
  # and collapsing them would claim a span that covers a line it does not own.
  def test_a_commit_returning_later_in_the_file_is_a_second_span
    spans = blame([10, FIRST], [11, SECOND], [12, FIRST]).fetch("spans")

    assert_equal([[10, 10], [11, 11], [12, 12]], spans.map { |s| [s["from"], s["to"]] })
  end

  # A gap in what is recorded is the thing a reader most needs to see. Leaving
  # the span out would read as "this line has no history".
  def test_a_commit_with_nothing_recorded_against_it_is_still_answered
    span = blame([40, FIRST]).fetch("spans").sole

    assert_empty span["intents"]
    assert_equal FIRST, span.dig("asset_version", "external_id")
  end

  def test_the_version_control_system_defaults_to_git
    assert_equal "git", blame([40, FIRST]).fetch("spans").sole.dig("asset_version", "vcs")
  end

  def test_another_version_control_system_can_be_named
    span = blame([40, "12345"], vcs: "perforce").fetch("spans").sole

    assert_equal "perforce", span.dig("asset_version", "vcs")
  end
end
