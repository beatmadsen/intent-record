require "test_helper"

# Deliberately does not include IntentRecordDsl: its setup has already connected
# and migrated, and the whole point here is the very first run against a database
# that does not exist yet. Each test names the database path it wants, because
# what is under test is largely what happens when that path is awkward.
class FirstRunTest < Minitest::Test
  DB = "intent-record.db".freeze

  Run = Struct.new(:stdout, :process_stdout, keyword_init: true) do
    def json
      JSON.parse(stdout)
    end
  end

  def setup
    @config_dir = Dir.mktmpdir("intent-record-first-run-")
    @locked = []
  end

  def teardown
    IntentRecord::Database.disconnect!
    @locked.each { |dir| File.chmod(0o700, dir) if File.exist?(dir) }
    FileUtils.rm_rf(@config_dir)
  end

  def test_first_run_creates_the_database_directory
    db = File.join(@config_dir, "data", DB)

    first_run(db)

    assert File.exist?(db), "expected #{db} to have been created"
  end

  def test_migrations_say_nothing_on_the_process_stdout
    assert_equal "", first_run(File.join(@config_dir, "data", DB)).process_stdout
  end

  def test_first_run_still_answers_with_json
    assert_match IntentRecordDsl::BASE58_PATTERN, first_run(File.join(@config_dir, "data", DB)).json["intent_id"]
  end

  # mkdir_p looks redundant because the sqlite3 adapter creates the directory
  # itself, but it is what turns an unwritable parent into the CLI's JSON error
  # instead of an adapter exception escaping to the agent.
  def test_a_database_under_an_unwritable_parent_is_rejected_as_json
    db = File.join(unwritable_dir("locked-parent"), "data", DB)

    assert_match(/not writable/, first_run(db).json["error"])
  end

  # Here the directory already exists, so mkdir_p succeeds and sqlite is the one
  # that refuses, through ActiveRecord rather than through an Errno.
  def test_a_database_in_an_unwritable_existing_directory_is_rejected_as_json
    db = File.join(unwritable_dir("locked-dir"), DB)

    assert_match(/not writable/, first_run(db).json["error"])
  end

  def test_a_read_only_database_file_is_rejected_as_json
    db = read_only_file(File.join(@config_dir, "data", DB))

    assert_match(/not writable/, first_run(db).json["error"])
  end

  private

  # The skip lives in the helpers rather than at the top of each test, so a new
  # test that makes something unwritable cannot forget it. Permissions do not
  # stop root, so there is nothing for these to observe there.
  def unwritable_dir(name)
    skip "root can write anywhere" if Process.uid.zero?

    dir = File.join(@config_dir, name)
    FileUtils.mkdir_p(dir)
    File.chmod(0o500, dir)
    @locked << dir
    dir
  end

  def read_only_file(path)
    skip "root can write anywhere" if Process.uid.zero?

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "")
    File.chmod(0o400, path)
    path
  end

  # capture_io rather than an injected stream on purpose: what this asserts is
  # that the migration left the real process stdout alone, since that is the pipe
  # the agent reads the JSON from, and there is no injecting your way to that.
  def first_run(db_path)
    File.write(File.join(@config_dir, "config.yml"), YAML.dump("db_path" => db_path))
    stdout = StringIO.new
    streams = IntentRecord::CLI::Streams.new(
      stdin: StringIO.new(JSON.generate("summary" => "First run", "body" => "Because reasons.")),
      stdout: stdout, stderr: StringIO.new
    )
    process_stdout, = capture_io do
      IntentRecord::CLI.new(["record"], config: IntentRecord::Config.new(config_dir: @config_dir),
                                        streams: streams).run
    end
    Run.new(stdout: stdout.string, process_stdout: process_stdout)
  end
end
