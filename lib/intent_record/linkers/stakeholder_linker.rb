require_relative "../models/stakeholder_system"
require_relative "../models/stakeholder_source"
require_relative "../models/stakeholder_reference"
require_relative "../input_validator"
require_relative "../stakeholder_normalizer"

module IntentRecord
  module Linkers
    # Links an intent record to stakeholder sources given as [{system, uri, title?}].
    # A source is unique per (system, uri), so the same ticket referenced under two
    # systems is two sources.
    #
    # A non-blank title replaces the stored one. A title that is missing, null or
    # blank leaves it alone, which means a title cannot be cleared once stored.
    # Where one payload names the same source twice, the last title in it wins.
    class StakeholderLinker
      def self.call(record, input)
        new(record).call(input)
      end

      def initialize(record)
        @record = record
      end

      def call(input)
        refs = InputValidator.hashes_with!(InputValidator.array!(input, "stakeholder_references"),
                                           "stakeholder_references", "system", "uri")
        refs.map { |ref| link!(ref) }
      end

      private

      def link!(ref)
        source = find_or_create_source(ref)
        Models::StakeholderReference.find_or_create_by!(intent_record: @record, stakeholder_source: source) do |r|
          r.created_at = Time.now.utc
        end
        source
      end

      def find_or_create_source(ref)
        source = initialized_source(ref)
        title = InputValidator.optional_string!(ref, "title")
        source.title = title if title
        source.created_at ||= Time.now.utc
        source.save!
        source
      end

      def initialized_source(ref)
        system = find_or_create_system(StakeholderNormalizer.system_name(ref["system"]))
        Models::StakeholderSource.find_or_initialize_by(stakeholder_system: system,
                                                        uri: StakeholderNormalizer.uri(ref["uri"]))
      end

      def find_or_create_system(name)
        Models::StakeholderSystem.find_or_create_by!(name: name) { |s| s.created_at = Time.now.utc }
      end
    end
  end
end
