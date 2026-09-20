require_relative "match_expression"

module IntentRecord
  # One term a person typed, read into the fields it asks about and the text to
  # look for in them.
  #
  # A term may name a field, as in `summary:retry`, for the case where a common
  # word appears everywhere and ranking it first is not enough. The hazard that
  # comes with it is that a ticket uri carries a colon too, so only the known
  # names count as a name and anything else before a colon stays part of the term.
  class SearchTerm
    RECORD_FIELDS = { "summary" => "intent_records.summary", "body" => "intent_records.body" }.freeze
    STAKEHOLDER_FIELDS = { "uri" => "stakeholder_sources.uri", "title" => "stakeholder_sources.title" }.freeze
    FIELDS = RECORD_FIELDS.merge(STAKEHOLDER_FIELDS).freeze
    ALL_FIELDS = FIELDS.values.freeze

    NAMED = /\A(#{FIELDS.keys.join("|")}):(.*)\z/m

    attr_reader :text, :fields, :index_column

    def self.parse(raw)
      match = NAMED.match(raw)
      return new(text: raw, fields: ALL_FIELDS, index_column: nil) if match.nil?

      named(match[1], match[2])
    end

    def self.named(name, text)
      raise ValidationError, "#{name}: needs something to look for" if text.strip.empty?

      new(text: text, fields: [FIELDS.fetch(name)], index_column: RECORD_FIELDS.key?(name) ? name : nil)
    end

    def initialize(text:, fields:, index_column:)
      @text = text
      @fields = fields
      @index_column = index_column
      # Named a stakeholder field, which the index does not hold. Distinguished
      # from a plain term, where a nil column means every column of the index.
      @off_index = index_column.nil? && fields != ALL_FIELDS
    end

    # Whether the index may answer this term at all. A term carrying punctuation
    # may not, because the index drops punctuation while tokenising and would
    # match text the person did not ask for.
    def indexable?
      !@off_index && MatchExpression.word?(text)
    end

    private_class_method :named
  end
end
