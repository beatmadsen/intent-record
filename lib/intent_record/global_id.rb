module IntentRecord
  module GlobalId
    BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".freeze
    PATTERN = /\A[1-9A-HJ-NP-Za-km-z]{7}\z/
    LENGTH = 7

    def self.generate
      Array.new(LENGTH) { BASE58_ALPHABET[rand(58)] }.join
    end

    def self.valid?(id)
      id.is_a?(String) && PATTERN.match?(id)
    end

    def self.unique_for(model)
      loop do
        candidate = generate
        return candidate unless model.exists?(global_id: candidate)
      end
    end
  end
end
