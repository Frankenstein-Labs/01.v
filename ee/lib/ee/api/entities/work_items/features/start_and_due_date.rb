# frozen_string_literal: true

module EE
  module API
    module Entities
      module WorkItems
        module Features
          module StartAndDueDate
            extend ActiveSupport::Concern

            prepended do
              expose :is_fixed, documentation: { type: 'Boolean', example: true } do |widget, _|
                widget.fixed?
              end

              expose :start_date_sourcing_work_item,
                using: ::API::Entities::WorkItems::Features::WorkItemReference,
                documentation: { type: 'Entities::WorkItems::Features::WorkItemReference' },
                expose_nil: true

              expose :start_date_sourcing_milestone,
                using: ::API::Entities::Milestone,
                documentation: { type: 'Entities::Milestone' },
                expose_nil: true

              expose :due_date_sourcing_work_item,
                using: ::API::Entities::WorkItems::Features::WorkItemReference,
                documentation: { type: 'Entities::WorkItems::Features::WorkItemReference' },
                expose_nil: true

              expose :due_date_sourcing_milestone,
                using: ::API::Entities::Milestone,
                documentation: { type: 'Entities::Milestone' },
                expose_nil: true
            end
          end
        end
      end
    end
  end
end
