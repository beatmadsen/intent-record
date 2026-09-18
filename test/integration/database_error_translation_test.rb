require "test_helper"
require "minitest/mock"

# connect! relabels sqlite's "cannot open" and "read only" as a DatabaseError so
# the CLI can report them as JSON. Everything else has to keep its own class, or
# a broken migration would be reported to the user as a permissions problem.
class DatabaseErrorTranslationTest < Minitest::Test
  include DbTestSetup

  def test_a_statement_error_from_another_cause_keeps_its_own_class
    boom = ActiveRecord::StatementInvalid.new("near \"nonsense\": syntax error")

    IntentRecord::Seeds.stub(:apply!, -> { raise boom }) do
      assert_raises(ActiveRecord::StatementInvalid) { IntentRecord::Database.connect!(config.db_path) }
    end
  end
end
