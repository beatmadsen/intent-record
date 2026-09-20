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

    # Case-insensitive, as every other name the tool takes is.
    NAMED = /\A(#{FIELDS.keys.join("|")}):(.*)\z/mi

    # Text the index may be trusted with: letters, digits and the spaces between
    # them, with at least one letter or digit to tokenise. Anything else the
    # index would drop, and dropping punctuation is how `100%` comes to match a
    # record that only ever said `100 percent`.
    WORD = /\A(?=.*[[:alnum:]])[[:alnum:][:space:]]+\z/

    attr_reader :text, :fields, :index_column

    def self.parse(raw)
      match = NAMED.match(raw)
      return new(text: raw, fields: ALL_FIELDS, index_column: nil) if match.nil?

      named(match[1].downcase, match[2])
    end

    # The shell hands `uri: acme-42` over as one word with the space inside,
    # and the space is not part of what is being looked for.
    def self.named(name, text)
      text = text.strip
      raise ValidationError, "#{name}: needs something to look for" if text.empty?

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

    # Whether the index may answer this term at all: not for a field it does
    # not hold, and not for text it would read differently from the person.
    def indexable?
      !@off_index && WORD.match?(text)
    end

    private_class_method :named
  end
end
