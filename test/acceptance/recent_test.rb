require "test_helper"

class RecentTest < Minitest::Test
  include IntentRecordDsl

  def test_recent_lists_newest_first_with_limit
    ids = 3.times.map { |i| record_intent!(summary: "s#{i}")["intent_id"] }
    IntentRecord::Models::IntentRecord.find_by!(global_id: ids[2]).update_columns(created_at: Time.utc(2020, 1, 1))

    json = run_cli_ok!("recent", "--limit", "2")

    assert_equal([ids[1], ids[0]], json["intents"].map { |i| i["intent_id"] })
  end

  def test_recent_rejects_non_integer_limit
    assert_cli_rejected run_cli("recent", "--limit", "many"), matching: /integer/
  end
end
