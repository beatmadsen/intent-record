require_relative "../input_validator"

module IntentRecord
  module Linkers
    # Reads the asset versions a payload asks for, as [vcs, external_id] pairs.
    # `commits` is git shorthand; `asset_versions` names its own system. Every
    # entry is checked before any is returned, so a payload with a bad entry
    # later in the list never reaches the database.
    module AssetVersionSpecs
      DEFAULT_VCS = "git".freeze

      module_function

      def from(input)
        commits(input).map { |c| [DEFAULT_VCS, c] } + explicit(input).map { |v| [v["vcs"], v["external_id"]] }
      end

      def commits(input)
        InputValidator.non_blank_strings!(InputValidator.array!(input, "commits"), "commit")
      end

      def explicit(input)
        InputValidator.hashes_with!(InputValidator.array!(input, "asset_versions"),
                                    "asset_versions", "vcs", "external_id")
      end

      private_class_method :commits, :explicit
    end
  end
end
