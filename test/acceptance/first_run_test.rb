require "test_helper"

# Deliberately does not include IntentRecordDsl: its setup has already connected
# and migrated, and the whole point here is the very first run against a database
# that does not exist yet.
class FirstRunTest < Minitest::Test
  def setup
    @config_dir = Dir.mktmpdir("intent-record-first-run-")
    @db_path = File.join(@config_dir, "data", "intent-record.db")
    File.write(File.join(@config_dir, "config.yml"), YAML.dump("db_path" => @db_path))
  end

  def teardown
    IntentRecord::Database.disconnect!
    FileUtils.rm_rf(@config_dir)
  end

  def test_first_run_creates_the_database_directory
    first_run

    assert File.exist?(@db_path), "expected #{@db_path} to have been created"
  end

  def test_migrations_say_nothing_on_the_process_stdout
    assert_equal "", first_run.fetch(:process_stdout)
  end

  def test_first_run_still_answers_with_json
    assert_match IntentRecordDsl::BASE58_PATTERN, JSON.parse(first_run.fetch(:stdout))["intent_id"]
  end

  # mkdir_p looks redundant because the sqlite3 adapter creates the directory
  # itself, but it is what turns an unwritable path into the CLI's JSON error
  # instead of an adapter exception escaping to the agent.
  def test_an_unwritable_database_path_is_rejected_as_json
    skip "root can write anywhere" if Process.uid.zero?

    locked = File.join(@config_dir, "locked")
    FileUtils.mkdir_p(locked)
    File.chmod(0o500, locked)
    @db_path = File.join(locked, "data", "intent-record.db")
    File.write(File.join(@config_dir, "config.yml"), YAML.dump("db_path" => @db_path))

    result = first_run

    assert_match(/not writable/, JSON.parse(result.fetch(:stdout))["error"])
  ensure
    File.chmod(0o700, locked) if locked && File.exist?(locked)
  end

  def test_a_read_only_database_file_is_rejected_as_json
    skip "root can write anywhere" if Process.uid.zero?

    FileUtils.mkdir_p(File.dirname(@db_path))
    File.write(@db_path, "")
    File.chmod(0o400, @db_path)

    assert_match(/not writable/, JSON.parse(first_run.fetch(:stdout))["error"])
  end

  def test_a_database_in_an_unwritable_existing_directory_is_rejected_as_json
    skip "root can write anywhere" if Process.uid.zero?

    locked = File.join(@config_dir, "locked")
    FileUtils.mkdir_p(locked)
    @db_path = File.join(locked, "intent-record.db")
    File.write(File.join(@config_dir, "config.yml"), YAML.dump("db_path" => @db_path))
    File.chmod(0o500, locked)

    assert_match(/not writable/, JSON.parse(first_run.fetch(:stdout))["error"])
  ensure
    File.chmod(0o700, locked) if locked && File.exist?(locked)
  end

  private

  # The agent reading this CLI sees one stdout. Anything the migration writes to
  # the process stream lands in the same pipe as the JSON, so capture both.
  def first_run
    stdout = StringIO.new
    streams = IntentRecord::CLI::Streams.new(
      stdin: StringIO.new(JSON.generate("summary" => "First run", "body" => "Because reasons.")),
      stdout: stdout, stderr: StringIO.new
    )
    process_stdout = capture_process_stdout do
      IntentRecord::CLI.new(["record"], config: IntentRecord::Config.new(config_dir: @config_dir),
                                        streams: streams).run
    end
    { stdout: stdout.string, process_stdout: process_stdout }
  end

  def capture_process_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
