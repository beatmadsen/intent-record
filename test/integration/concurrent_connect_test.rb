require "test_helper"
require "timeout"

# intent-record is meant to be driven by agents, which run commands whenever they
# finish a piece of work, so two of them arriving at once is ordinary rather than
# exotic. Forks rather than threads, because that is how it actually happens:
# separate processes, each connecting for itself.
class ConcurrentConnectTest < Minitest::Test
  WRITERS = 4

  # The wait is bounded because a change that makes connect! block leaves the
  # children alive forever, and an unbounded wait turns that into the whole run
  # hanging rather than this test failing. It has to fire well inside the
  # mutation lane's own per-mutant timeout, or that is what gives out first and
  # the mutant escapes unjudged. Four children normally finish in well under a
  # second, measured.
  PATIENCE = 2

  Child = Struct.new(:pid, :reader, keyword_init: true)

  def test_processes_connecting_to_a_new_store_at_once_all_succeed
    dir = temp_dir("concurrent")
    File.write(File.join(dir, "config.yml"), YAML.dump("db_path" => File.join(dir, "x.db")))

    failures = run_concurrently(dir) { |config| IntentRecord::Database.connect!(config.db_path) }

    assert_equal [], failures
  end

  def test_processes_writing_to_the_same_store_at_once_all_succeed
    dir = temp_dir("concurrent-write")
    File.write(File.join(dir, "config.yml"), YAML.dump("db_path" => File.join(dir, "x.db")))
    IntentRecord::Database.connect!(IntentRecord::Config.new(config_dir: dir).load!.db_path)
    IntentRecord::Database.disconnect!

    failures = run_concurrently(dir) do |config|
      IntentRecord::Database.connect!(config.db_path)
      record!(config)
    end

    assert_equal [], failures
  end

  private

  # Each child reports its own failure down a pipe, so a failure names what went
  # wrong rather than only that an exit status was not zero.
  def run_concurrently(dir, &work)
    children = WRITERS.times.map { spawn_child(dir, &work) }
    collect(children)
  ensure
    children&.each { |child| reap(child.pid) }
  end

  def spawn_child(dir, &work)
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      run_child(dir, writer, &work)
    end
    writer.close
    Child.new(pid: pid, reader: reader)
  end

  def collect(children)
    Timeout.timeout(PATIENCE) { children.each { |child| Process.waitpid(child.pid) } }
    children.map { |child| child.reader.read.to_s.strip }.reject(&:empty?)
  rescue Timeout::Error
    ["a child was still running after #{PATIENCE}s"]
  end

  def reap(pid)
    Process.kill("KILL", pid)
    Process.waitpid(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def run_child(dir, writer, &work)
    work.call(IntentRecord::Config.new(config_dir: dir).load!)
    writer.close
    exit!(0)
  rescue StandardError => e
    writer.puts "#{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}"
    writer.close
    exit!(1)
  end

  def record!(config)
    streams = IntentRecord::CLI::Streams.new(
      stdin: StringIO.new(JSON.generate("summary" => "concurrent", "body" => "b")),
      stdout: StringIO.new, stderr: StringIO.new
    )
    code = IntentRecord::CLI.new(["record"], config: config, streams: streams).run
    raise "cli exited #{code}: #{streams.stdout.string}" unless code.zero?
  end
end
