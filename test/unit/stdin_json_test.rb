require "test_helper"

class StdinJsonTest < Minitest::Test
  Json = IntentRecord::CLI::StdinJson

  def test_an_object_is_parsed
    assert_equal({ "a" => 1 }, Json.read(StringIO.new(%({"a":1}))))
  end

  def test_a_json_array_is_rejected_because_the_input_must_be_an_object
    error = assert_raises(IntentRecord::ValidationError) { Json.read(StringIO.new("[1]")) }

    assert_match(/must be a JSON object/, error.message)
  end

  def test_empty_input_is_rejected
    error = assert_raises(IntentRecord::ValidationError) { Json.read(StringIO.new("  \n")) }

    assert_match(/Empty input/, error.message)
  end

  def test_malformed_json_is_rejected_and_the_parser_reason_is_kept
    error = assert_raises(IntentRecord::ValidationError) { Json.read(StringIO.new("{not json")) }

    assert_match(/Invalid JSON input/, error.message)
  end

  def test_input_that_is_not_valid_utf8_is_rejected_before_it_is_parsed
    error = assert_raises(IntentRecord::ValidationError) do
      Json.read(StringIO.new(%({"summary":"bad \xFF"}).b))
    end

    assert_match(/UTF-8/, error.message)
  end
end
