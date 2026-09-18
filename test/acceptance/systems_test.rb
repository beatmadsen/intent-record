require "test_helper"

class SystemsTest < Minitest::Test
  include IntentRecordDsl

  def test_well_known_systems_are_seeded_on_first_connect
    json = run_cli_ok!("systems")

    assert_includes json["vcs_systems"], "git"
    assert_includes json["vcs_systems"], "mercurial"
    %w[jira confluence linear github-issues notion slack].each do |name|
      assert_includes json["stakeholder_systems"], name
    end
  end

  def test_reconnecting_does_not_duplicate_the_seeded_vcs_systems
    2.times { IntentRecord::Database.connect!(config.db_path) }

    assert_equal IntentRecord::Seeds::VCS_SYSTEMS.size, IntentRecord::Models::VcsSystem.count
  end

  # The other half of the same rule, and the one that was unpinned: seed! is
  # called once per table, so either call could double up on its own.
  def test_reconnecting_does_not_duplicate_the_seeded_stakeholder_systems
    2.times { IntentRecord::Database.connect!(config.db_path) }

    assert_equal IntentRecord::Seeds::STAKEHOLDER_SYSTEMS.size, IntentRecord::Models::StakeholderSystem.count
  end

  def test_user_added_systems_appear_alongside_seeded_ones
    record_intent!(asset_versions: [{ "vcs" => "my-vcs", "external_id" => "1" }],
                   stakeholder_references: [{ "system" => "my-tracker", "uri" => "x" }])

    json = run_cli_ok!("systems")

    assert_includes json["vcs_systems"], "my-vcs"
    assert_includes json["stakeholder_systems"], "my-tracker"
  end
end
