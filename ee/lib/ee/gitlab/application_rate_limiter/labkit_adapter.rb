# frozen_string_literal: true

module EE
  module Gitlab
    module ApplicationRateLimiter
      module LabkitAdapter
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :ar_characteristic_types
          def ar_characteristic_types
            super.merge(::Ai::DuoWorkflows::Workflow => :duo_workflow).freeze
          end
        end
      end
    end
  end
end
