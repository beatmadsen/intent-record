require_relative "../formatter"
require_relative "../models/intent_record"

module IntentRecord
  module Commands
    class Show
      def initialize(intent_id:)
        @intent_id = intent_id
      end

      def call
        record = Formatter.preloaded(Models::IntentRecord).find_by(global_id: @intent_id)
        raise NotFoundError, "Intent record not found: #{@intent_id}" unless record

        Formatter.full(record)
      end
    end
  end
end
