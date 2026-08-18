# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class HealthStatusDetail < HealthStatus
          class RolledUpHealthStatus < Grape::Entity
            expose :health_status,
              documentation: {
                type: 'String',
                example: 'on_track',
                values: ::WorkItem.health_statuses.keys
              }

            expose :count,
              documentation: { type: 'Integer', example: 4 }
          end

          expose :rolled_up_health_status,
            using: ::API::Entities::WorkItems::Features::HealthStatusDetail::RolledUpHealthStatus,
            documentation: {
              type: 'Entities::WorkItems::Features::HealthStatusDetail::RolledUpHealthStatus',
              is_array: true
            }
        end
      end
    end
  end
end
