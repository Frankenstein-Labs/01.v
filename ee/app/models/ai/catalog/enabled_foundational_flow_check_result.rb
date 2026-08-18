# frozen_string_literal: true

module Ai
  module Catalog
    class EnabledFoundationalFlowCheckResult < ApplicationRecord
      self.table_name = 'enabled_foundational_flow_check_results'

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :enabled_foundational_flow, class_name: 'Ai::Catalog::EnabledFoundationalFlow'

      enum :status, { failure: 0, success: 1 }

      validates :organization_id, presence: true
      validates :enabled_foundational_flow_id, presence: true
      validates :check_id, presence: true, uniqueness: { scope: :enabled_foundational_flow_id }
      validates :status, presence: true
      validates :message, length: { maximum: 4096 }, allow_nil: true
    end
  end
end
