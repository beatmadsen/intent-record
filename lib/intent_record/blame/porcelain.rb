module IntentRecord
  module Blame
    # Reads `git blame --porcelain` into the lines the command takes.
    #
    # The JSON shape is the contract and this is a convenience, so that blaming a
    # file from a git repository is one command rather than one command and a
    # converter. Keeping it a separate reader is what stops the store learning
    # anything about git: it produces the same payload a person could have
    # written by hand, and a second version control system earns a second reader
    # rather than a change here.
    module Porcelain
      # "<sha> <line in the original file> <line in this file> [<how many
      # follow>]". The second number is the one a reader is asking about. Content
      # lines are prefixed with a tab, so a file whose own text looks like a
      # header is never read as one.
      HEADER = /\A(?<id>[0-9a-f]{40}|[0-9a-f]{64}) \d+ (?<line>\d+)(?: \d+)?\z/

      module_function

      def lines(text)
        found = text.to_s.lines.filter_map { |line| header(line) }
        raise ValidationError, "No blame headers found. Expected `git blame --porcelain` output." if found.empty?

        found
      end

      def header(line)
        match = HEADER.match(line.chomp)
        return nil if match.nil?

        { "line" => match[:line].to_i, "external_id" => match[:id] }
      end

      private_class_method :header
    end
  end
end
