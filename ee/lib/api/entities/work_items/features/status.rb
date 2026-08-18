# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class Status < Grape::Entity
          class StatusObject < Grape::Entity
            expose :id,
              documentation: { type: 'String',
                               example: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1' },
              expose_nil: true do |status|
                status.to_gid.to_s
              end
            expose :name,
              documentation: { type: 'String', example: 'To do' },
              expose_nil: true
            expose :icon_name,
              documentation: { type: 'String', example: 'status-waiting' },
              expose_nil: true
            expose :color,
              documentation: { type: 'String', example: '#737278' },
              expose_nil: true
            expose :position,
              documentation: { type: 'Integer', example: 0 },
              expose_nil: true
            expose :description,
              documentation: { type: 'String' },
              expose_nil: true
            expose :category,
              documentation: { type: 'String', example: 'to_do' },
              expose_nil: true do |status|
                status.category&.to_s
              end
          end

          expose :status,
            using: ::API::Entities::WorkItems::Features::Status::StatusObject,
            documentation: { type: 'Entities::WorkItems::Features::Status::StatusObject' },
            expose_nil: true do |widget|
              widget.work_item.status_with_fallback
            end
        end
      end
    end
  end
end
