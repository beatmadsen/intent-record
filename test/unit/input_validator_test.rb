require "test_helper"

class InputValidatorTest < Minitest::Test
  V = IntentRecord::InputValidator

  def test_required_string_enforces_max_length
    error = assert_raises(IntentRecord::ValidationError) { V.required_string!({ "s" => "ab" }, "s", max_length: 1) }
    assert_match(/1 characters or fewer/, error.message)
  end

  def test_optional_string_treats_blank_as_absent
    assert_nil V.optional_string!({ "author" => "  " }, "author")
  end

  def test_optional_string_rejects_non_string
    assert_raises(IntentRecord::ValidationError) { V.optional_string!({ "author" => 3 }, "author") }
  end

  def test_array_defaults_to_empty_and_rejects_non_array
    assert_equal [], V.array!({}, "commits")
    assert_raises(IntentRecord::ValidationError) { V.array!({ "commits" => "x" }, "commits") }
  end

  def test_hashes_with_requires_each_named_key
    error = assert_raises(IntentRecord::ValidationError) { V.hashes_with!([{ "uri" => "x" }], "refs", "system", "uri") }
    assert_match(/system is required/, error.message)
  end
end
