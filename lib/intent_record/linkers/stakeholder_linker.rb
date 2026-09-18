require_relative "../models/stakeholder_system"
require_relative "../models/stakeholder_source"
require_relative "../models/stakeholder_reference"
require_relative "../input_validator"

module IntentRecord
  module Linkers
    # Links an intent record to stakeholder sources given as [{system, uri, title?}].
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
        system = Models::StakeholderSystem.find_or_create_by!(name: ref["system"].strip.downcase) do |s|
          s.created_at = Time.now.utc
        end
        Models::StakeholderSource.find_or_create_by!(stakeholder_system: system, uri: ref["uri"].strip) do |src|
          src.title = InputValidator.optional_string!(ref, "title")
          src.created_at = Time.now.utc
        end
      end
    end
  end
end
