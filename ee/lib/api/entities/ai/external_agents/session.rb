# frozen_string_literal: true

module API
  module Entities
    module Ai
      module ExternalAgents
        class Session < Grape::Entity
          expose :id, documentation: { type: 'Integer', example: 1 }
          expose :agent_type, documentation: { type: 'String', example: 'claude-code' }
          expose :agent_identity_id, documentation: { type: 'Integer', example: 1 }
          expose :user_id, documentation: { type: 'Integer', example: 1 }
          expose :sync_type, documentation: { type: 'String', example: 'hook' }
          expose :status_name, as: :status, documentation: { type: 'String', example: 'running' }
          expose :goal, documentation: { type: 'String', example: 'Implement the login feature' }
          expose :created_at, documentation: { type: 'String', example: '2026-06-17T00:00:00.000Z' }
          expose :updated_at, documentation: { type: 'String', example: '2026-06-17T00:00:00.000Z' }
        end
      end
    end
  end
end
