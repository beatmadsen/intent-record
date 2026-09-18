module IntentRecord
  class CLI
    Streams = Struct.new(:stdin, :stdout, :stderr, keyword_init: true) do
      def self.default
        new(stdin: $stdin, stdout: $stdout, stderr: $stderr)
      end
    end
  end
end
