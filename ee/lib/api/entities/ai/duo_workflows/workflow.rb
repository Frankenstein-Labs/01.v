# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Workflow < Grape::Entity
          expose :id
          expose :project_id
          expose :namespace_id
          expose :agent_privileges
          expose :agent_privileges_names
          expose :pre_approved_agent_privileges
          expose :pre_approved_agent_privileges_names
          expose :workflow_definition
          expose :status_name, as: :status
          expose :summary
          expose :title
          expose :allow_agent_to_request_user
          expose :image
          expose :environment
          expose :ai_catalog_item_version_id

          def agent_privileges_names
            object.agent_privileges.map do |privilege|
              ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
            end
          end

          def pre_approved_agent_privileges_names
            object.pre_approved_agent_privileges.map do |privilege|
              ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
            end
          end

          expose :workload do |_, opts|
            opts[:workload]
          end

          expose :mcp_enabled?, as: :mcp_enabled
          expose :incremental_checkpoints_enabled?, as: :incremental_checkpoints_enabled

          expose :gitlab_url do |_|
            Gitlab.config.gitlab.url
          end
        end
      end
    end
  end
end
