require "test_helper"

class GlobalIdTest < Minitest::Test
  def test_generates_seven_base58_chars
    assert IntentRecord::GlobalId.valid?(IntentRecord::GlobalId.generate)
  end

  def test_rejects_ambiguous_characters_and_wrong_length
    refute IntentRecord::GlobalId.valid?("0OIl000")
    refute IntentRecord::GlobalId.valid?("abcdef")
    refute IntentRecord::GlobalId.valid?(nil)
  end
end
