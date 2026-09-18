require "test_helper"

class RecordMinimalTest < Minitest::Test
  include IntentRecordDsl

  def test_records_intent_with_summary_and_body
    json = run_cli_ok!("record", stdin: { "summary" => "Add retry to fetcher", "body" => "Network flakes were biting us." })

    assert_global_id json["intent_id"]
    record = IntentRecord::Models::IntentRecord.find_by(global_id: json["intent_id"])
    assert_equal "Add retry to fetcher", record.summary
    assert_equal "Network flakes were biting us.", record.body
  end

  def test_output_contains_no_internal_ids
    json = run_cli_ok!("record", stdin: { "summary" => "s", "body" => "b" })

    refute json.key?("id")
    assert_global_id json["intent_id"]
  end
end
