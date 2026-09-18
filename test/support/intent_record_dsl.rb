require "stringio"
require_relative "db_test_setup"
require_relative "cli_result"

# Acceptance-test DSL. Runs the CLI in-process with injected IO and config.
module IntentRecordDsl
  include DbTestSetup

  BASE58_PATTERN = /\A[1-9A-HJ-NP-Za-km-z]{7}\z/

  def run_cli(*argv, stdin: "")
    stdout = StringIO.new
    stderr = StringIO.new
    in_io = StringIO.new(stdin.is_a?(String) ? stdin : stdin.to_json)
    streams = IntentRecord::CLI::Streams.new(stdin: in_io, stdout: stdout, stderr: stderr)
    code = IntentRecord::CLI.new(argv, config: config, streams: streams).run
    Result.new(stdout: stdout.string, stderr: stderr.string, exit_code: code)
  end

  def run_cli_ok!(*argv, stdin: "")
    result = run_cli(*argv, stdin: stdin)
    assert_cli_ok(result, doing: argv.first(2).join(" "))
    result.json
  end

  def assert_cli_ok(result, doing: "cli")
    assert result.success?, "#{doing} failed (exit=#{result.exit_code}): #{result.stdout}#{result.stderr}"
  end

  def assert_cli_rejected(result, matching: nil)
    refute result.success?, "expected CLI to reject, but it succeeded: #{result.stdout}"
    assert_equal 1, result.exit_code
    Array(matching).each { |pattern| assert_match pattern, result.error_message }
  end

  # intent_id is the public base58 handle and external_id is the commit hash the
  # caller supplied. Any other key ending in _id is a row id from the database,
  # which nothing outside it is allowed to see. Walks the whole response so the
  # rule covers shapes nobody thought to check, including ones added later.
  PUBLIC_ID_KEYS = %w[intent_id external_id].freeze

  def assert_no_internal_ids(node, path = "response")
    case node
    when Hash then assert_no_internal_ids_in_hash(node, path)
    when Array then node.each_with_index { |value, i| assert_no_internal_ids(value, "#{path}[#{i}]") }
    end
  end

  def assert_no_internal_ids_in_hash(node, path)
    node.each do |key, value|
      refute internal_id_key?(key), "#{path} exposes a database id as #{key.inspect}"
      assert_no_internal_ids(value, "#{path}.#{key}")
    end
  end

  def internal_id_key?(key)
    return false if PUBLIC_ID_KEYS.include?(key)

    key == "id" || key.end_with?("_id")
  end

  def assert_global_id(value)
    assert_match BASE58_PATTERN, value.to_s, "expected a 7-character base58 id, got #{value.inspect}"
  end

  def record_intent!(summary: "Test intent", body: "Because reasons.", **extra)
    run_cli_ok!("record", stdin: { "summary" => summary, "body" => body }.merge(extra.transform_keys(&:to_s)))
  end
end
