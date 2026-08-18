# frozen_string_literal: true

module API
  module Entities
    module Govern
      class Policy < Grape::Entity
        expose :id, documentation: { type: 'Integer', example: 1 }
        expose :organization_id, documentation: { type: 'Integer', example: 1 }
        expose :namespace_id, documentation: { type: 'Integer', example: 42 }
        expose :name, documentation: { type: 'String', example: 'Block deployments on critical findings' }
        expose :description, documentation: { type: 'String', example: 'Blocks a deployment on a critical finding' }
        expose :version, documentation: { type: 'Integer', example: 1 }
        expose :trigger_type, documentation: { type: 'String', example: 'deployment_requested' }
        expose :rules, documentation: { type: 'Array' }
        expose :actions, documentation: { type: 'Array' }
        expose :policy_scope, documentation: { type: 'Hash' }
        expose :scope_rego, documentation: { type: 'String', example: 'package gitlab.scope' }
        expose :mode, documentation: { type: 'String', example: 'enforce' }
        expose :lifecycle_state, documentation: { type: 'String', example: 'active' }
        expose :created_at, documentation: { type: 'String', example: '2026-08-07T13:56:32.985Z' }
        expose :updated_at, documentation: { type: 'String', example: '2026-08-07T13:56:32.985Z' }
      end
    end
  end
end
