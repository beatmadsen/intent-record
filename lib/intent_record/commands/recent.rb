require_relative "../formatter"
require_relative "../models/intent_record"

module IntentRecord
  module Commands
    class Recent
      DEFAULT_LIMIT = 20

      def initialize(limit: DEFAULT_LIMIT)
        @limit = limit
      end

      def call
        records = Models::IntentRecord.order(created_at: :desc, id: :desc).limit(@limit)
        { "intents" => records.map { |r| Formatter.full(r) } }
      end
    end
  end
end
