require "test_helper"

# Regressions from the first black-box QA round.
class QaLikeEscapingTest < Minitest::Test
  include IntentRecordDsl

  def test_search_matches_literal_percent_and_underscore
    hit = record_intent!(summary: "100% done_now", body: "b")
    record_intent!(summary: "100 percent", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "100%")["intents"].map { |r| r["intent_id"] })
    assert_equal([hit["intent_id"]], run_cli_ok!("search", "done_now")["intents"].map { |r| r["intent_id"] })
  end

  def test_by_source_contains_matches_literal_percent
    hit = record_intent!(stakeholder_references: [{ "system" => "web", "uri" => "https://w/100%25_done" }])
    record_intent!(stakeholder_references: [{ "system" => "web", "uri" => "https://w/100x25xdone" }])

    assert_equal([hit["intent_id"]], run_cli_ok!("by-source", "100%25_", "--contains")["intents"].map do |r|
      r["intent_id"]
    end)
  end
end

class QaHashNormalisationTest < Minitest::Test
  include IntentRecordDsl

  UPPER = "ABCDEF1234567890ABCDEF1234567890ABCDEF12".freeze

  def test_git_hash_case_is_normalised_to_lowercase
    record_intent!(commits: [UPPER])
    record_intent!(commits: [UPPER.downcase])

    assert_equal 1, IntentRecord::Models::AssetVersion.count
    assert_equal 2, run_cli_ok!("lookup", UPPER[0, 12])["intents"].size
  end

  def test_git_hash_must_be_full_sha1_or_sha256_hex
    assert_cli_rejected run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => ["zzz"] }),
                        matching: /40 or 64 hex/
    assert_cli_ok run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => ["a" * 64] })
  end

  def test_prefix_lookup_only_applies_to_hash_based_vcs
    record_intent!(asset_versions: [{ "vcs" => "perforce", "external_id" => "12345" }])

    assert_cli_rejected run_cli("lookup", "1234"), matching: /not found/i
    assert_cli_ok run_cli("lookup", "12345")
  end

  def test_ambiguity_message_counts_all_matches
    3.times { |i| record_intent!(commits: ["abcdef#{i}#{"0" * 33}"]) }

    assert_cli_rejected run_cli("lookup", "abcdef"), matching: /matches 3 asset versions/
  end
end

class QaArgvTest < Minitest::Test
  include IntentRecordDsl

  def test_invalid_utf8_stdin_is_a_json_error
    result = run_cli("record", stdin: "{\"summary\":\"bad \xFF\",\"body\":\"y\"}".b)

    assert_cli_rejected result, matching: /UTF-8/
  end

  def test_equals_form_of_options_is_supported
    3.times { record_intent! }

    assert_equal 2, run_cli_ok!("recent", "--limit=2")["intents"].size
  end

  def test_repeated_option_is_rejected
    assert_cli_rejected run_cli("search", "x", "--match", "all", "--match", "all"),
                        matching: /--match given more than once/
  end

  def test_unknown_options_and_extra_arguments_are_rejected
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("show", id, "--bogus"), matching: /Unexpected argument/
    assert_cli_rejected run_cli("show", id, "extra"), matching: /Unexpected argument/
    assert_cli_rejected run_cli("lookup", "1111", "--vcs"), matching: /Unexpected argument/
    assert_cli_rejected run_cli("systems", "extra"), matching: /Unexpected argument/
  end

  def test_subcommand_help_prints_usage
    result = run_cli("show", "--help")

    assert result.success?
    assert_match(/Usage: intent-record/, result.stderr)
  end

  def test_recent_limit_must_be_positive
    assert_cli_rejected run_cli("recent", "--limit", "0"), matching: /at least 1/
  end
end
