require "test_helper"

class InputValidatorTest < Minitest::Test
  V = IntentRecord::InputValidator

  def test_required_string_rejects_a_missing_key
    error = assert_raises(IntentRecord::ValidationError) { V.required_string!({}, "summary") }
    assert_match(/summary is required/, error.message)
  end

  def test_required_string_rejects_a_non_string
    error = assert_raises(IntentRecord::ValidationError) { V.required_string!({ "summary" => 3 }, "summary") }
    assert_match(/summary must be a string/, error.message)
  end

  def test_required_string_rejects_a_whitespace_only_string
    error = assert_raises(IntentRecord::ValidationError) { V.required_string!({ "summary" => " \t " }, "summary") }
    assert_match(/summary cannot be blank/, error.message)
  end

  def test_required_string_accepts_a_value_of_exactly_max_length
    assert_equal "ab", V.required_string!({ "s" => "ab" }, "s", max_length: 2)
  end

  def test_required_string_enforces_max_length
    error = assert_raises(IntentRecord::ValidationError) { V.required_string!({ "s" => "ab" }, "s", max_length: 1) }
    assert_match(/1 characters or fewer/, error.message)
  end

  def test_required_string_returns_the_value_stripped
    assert_equal "a summary", V.required_string!({ "s" => "  a summary\n" }, "s")
  end

  def test_required_string_measures_max_length_after_stripping
    assert_equal "ab", V.required_string!({ "s" => "  ab  " }, "s", max_length: 2)
  end

  def test_optional_string_treats_blank_as_absent
    assert_nil V.optional_string!({ "author" => "  " }, "author")
  end

  def test_optional_string_treats_a_missing_key_as_absent
    assert_nil V.optional_string!({}, "author")
  end

  def test_optional_string_rejects_non_string
    assert_raises(IntentRecord::ValidationError) { V.optional_string!({ "author" => 3 }, "author") }
  end

  def test_optional_string_returns_the_value_stripped
    assert_equal "Ada", V.optional_string!({ "author" => "  Ada  " }, "author")
  end

  def test_array_defaults_to_empty_when_the_key_is_absent
    assert_equal [], V.array!({}, "commits")
  end

  def test_array_rejects_a_non_array
    error = assert_raises(IntentRecord::ValidationError) { V.array!({ "commits" => "x" }, "commits") }
    assert_match(/commits must be an array/, error.message)
  end

  def test_array_returns_the_given_array
    assert_equal %w[abc], V.array!({ "commits" => %w[abc] }, "commits")
  end

  def test_non_blank_strings_rejects_a_whitespace_only_entry
    error = assert_raises(IntentRecord::ValidationError) { V.non_blank_strings!(["abc", " "], "commit") }
    assert_match(/commit must be a non-empty string/, error.message)
  end

  def test_non_blank_strings_rejects_a_non_string_entry
    error = assert_raises(IntentRecord::ValidationError) { V.non_blank_strings!([3], "commit") }
    assert_match(/commit must be a non-empty string/, error.message)
  end

  # It already judged each entry by its stripped form, so returning the padded
  # one leaves callers holding a value this module has implicitly accepted as
  # equivalent to a shorter one. Every other reader here returns what it trimmed.
  def test_non_blank_strings_returns_the_values_stripped
    assert_equal %w[abc def], V.non_blank_strings!(["  abc  ", "\tdef\n"], "commit")
  end

  def test_non_blank_strings_returns_the_values_when_all_are_non_blank
    assert_equal %w[abc def], V.non_blank_strings!(%w[abc def], "commit")
  end

  def test_hashes_with_rejects_a_non_hash_entry
    error = assert_raises(IntentRecord::ValidationError) { V.hashes_with!(["x"], "refs", "system") }
    assert_match(/refs entries must be objects/, error.message)
  end

  def test_hashes_with_requires_each_named_key
    error = assert_raises(IntentRecord::ValidationError) { V.hashes_with!([{ "uri" => "x" }], "refs", "system", "uri") }
    assert_match(/system is required/, error.message)
  end

  def test_hashes_with_returns_the_values_when_every_entry_has_the_keys
    entries = [{ "system" => "jira", "uri" => "x" }]
    assert_equal entries, V.hashes_with!(entries, "refs", "system", "uri")
  end
end
