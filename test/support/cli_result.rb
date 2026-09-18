require "json"

module IntentRecordDsl
  # Envelope returned by `run_cli`: stdout, stderr and exit code. Never raises.
  Result = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true) do
    def success?
      exit_code.zero?
    end

    def json
      JSON.parse(stdout)
    end

    def error_message
      json["error"]
    end
  end
end
