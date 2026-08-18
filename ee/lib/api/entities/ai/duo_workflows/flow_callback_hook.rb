# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class FlowCallbackHook < Grape::Entity
          expose :id, documentation: { type: 'Integer', example: 1 }
          expose :url, documentation: { type: 'String', example: 'https://autoflow.example.com/duo/callbacks' }
          expose :name, documentation: { type: 'String', example: 'AutoFlow' }
          expose :signing_token_set, documentation: { type: 'Boolean', example: true } do |hook|
            hook.signing_token.present?
          end
          expose :token_set, documentation: { type: 'Boolean', example: false } do |hook|
            hook.token.present?
          end
          expose :created_at, documentation: { type: 'DateTime', example: '2026-07-22T11:37:00Z' }
        end
      end
    end
  end
end
