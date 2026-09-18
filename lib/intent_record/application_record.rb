require "active_record"

module IntentRecord
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = ""
  end
end
