require "test_helper"

# The production store is never named as a path here, only asked about. Naming it
# in a call that a missing guard would let through is how a test comes to open it.
class StoreConfinementTest < Minitest::Test
  PRODUCTION = File.expand_path("~/.intent-record")

  def test_the_production_store_is_not_a_place_a_test_may_touch
    refute StoreConfinement.confined?(PRODUCTION)
  end

  def test_the_production_database_is_not_a_place_a_test_may_touch
    refute StoreConfinement.confined?(File.join(PRODUCTION, "intent-record.db"))
  end

  # check! does no file access at all, so the production store can be named here
  # and refused by name without any risk of a guardless run reaching it.
  def test_the_production_store_is_refused_by_name
    error = assert_raises(StoreConfinement::Escape) { StoreConfinement.check!(PRODUCTION, "config directory") }

    assert_match PRODUCTION, error.message
  end

  def test_the_confinement_is_installed
    assert StoreConfinement.installed?
  end

  def test_a_temporary_directory_is_a_place_a_test_may_touch
    assert StoreConfinement.confined?(temp_dir("confinement"))
  end

  def test_a_config_directory_outside_the_temporary_directory_is_refused
    assert_raises(StoreConfinement::Escape) { IntentRecord::Config.new(config_dir: outside) }
  end

  def test_connecting_a_database_outside_the_temporary_directory_is_refused
    assert_raises(StoreConfinement::Escape) { IntentRecord::Database.connect!(File.join(outside, "x.db")) }
  end

  def test_opening_sqlite_directly_outside_the_temporary_directory_is_refused
    assert_raises(StoreConfinement::Escape) { SQLite3::Database.new(File.join(outside, "x.db")) }
  end

  def test_the_refusal_names_the_path_and_the_only_root_a_test_may_use
    error = assert_raises(StoreConfinement::Escape) { IntentRecord::Config.new(config_dir: outside) }

    assert_match outside, error.message
    assert_match StoreConfinement::ROOT, error.message
  end

  def test_a_config_directory_inside_the_temporary_directory_is_allowed
    dir = temp_dir("confinement")

    assert_equal dir, IntentRecord::Config.new(config_dir: dir).config_dir
  end

  private

  # A real path outside the temporary directory, chosen so that a guard which
  # fails to fire leaves ignored litter in the repo rather than reaching anything.
  def outside
    File.join(Dir.pwd, "tmp", "not-a-temporary-store")
  end
end
