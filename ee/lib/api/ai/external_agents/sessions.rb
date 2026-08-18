# frozen_string_literal: true

module API
  module Ai
    module ExternalAgents
      class Sessions < ::API::Base
        include PaginationParams

        feature_category :software_composition_analysis

        before do
          authenticate!
        end

        resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          before do
            forbidden! unless user_project.licensed_feature_available?(:ai_catalog)
            not_found! unless Feature.enabled?(:ai_agent_session_tracking, user_project)
          end

          namespace ':id/ai_agent/sessions' do
            desc 'Create an external agent session.' do
              detail 'Creates a new external agent session for the current user and project. ' \
                'Returns an existing record if an idempotency_key is provided and a matching ' \
                'session already exists.'
              success ::API::Entities::Ai::ExternalAgents::Session
              failure [
                { code: 400, message: 'Bad request' },
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not found' },
                { code: 429, message: 'Too many requests' }
              ]
              tags %w[projects ai_agent_sessions]
            end
            params do
              requires :agent_type, type: String,
                desc: 'The type of agent.',
                values: ::Ai::ExternalAgents::AgentIdentity::AGENT_TYPES,
                allow_blank: false
              requires :agent_identity_id, type: Integer,
                desc: 'ID of the registered agent identity.'
              requires :sync_type, type: String,
                desc: 'How the session was synced.',
                values: %w[hook fallback manual]
              optional :goal, type: String,
                desc: 'User-provided session description.',
                allow_blank: false
              optional :started_at, type: DateTime,
                desc: 'Session start time, supports backfill.'
              optional :idempotency_key, type: String,
                desc: 'Client-generated UUID for retry safety.',
                allow_blank: false,
                limit: 255
            end
            route_setting :lifecycle, :experiment
            route_setting :authorization, permissions: :create_ai_agent_session, boundary_type: :project
            post do
              authorize! :create_ai_agent_session, user_project
              check_rate_limit!(:ai_agent_session_creation, scope: [current_user, user_project])

              result = ::Ai::ExternalAgents::Sessions::CreateService.new(
                project: user_project,
                current_user: current_user,
                params: declared_params(include_missing: false)
              ).execute

              if result.success?
                status :created
                present result.payload[:session], with: ::API::Entities::Ai::ExternalAgents::Session
              elsif result.reason == :not_found
                not_found!(result.message)
              else
                bad_request!(result.message)
              end
            end

            desc 'Complete or fail an external agent session.' do
              detail 'Marks a session as completed or failed. The authenticated user must be ' \
                'the creator of the session. Returns the existing record unchanged if ' \
                'jsonl_sha256 matches the stored value.'
              success ::API::Entities::Ai::ExternalAgents::Session
              failure [
                { code: 400, message: 'Bad request' },
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not found' }
              ]
              tags %w[projects ai_agent_sessions]
            end
            params do
              requires :session_id, type: Integer, desc: 'The session ID.'
              requires :status, type: String,
                desc: 'Terminal status.',
                values: %w[completed failed]
              optional :jsonl_sha256, type: String,
                desc: 'SHA-256 of the transcript file.',
                allow_blank: false,
                limit: 64,
                regexp: /\A\h{64}\z/
            end
            route_setting :lifecycle, :experiment
            route_setting :authorization, permissions: :update_ai_agent_session, boundary_type: :project
            patch ':session_id' do
              authorize! :update_ai_agent_session, user_project

              session = ::Ai::DuoWorkflows::Workflow.find_external_session(
                project: user_project,
                session_id: params[:session_id]
              )

              not_found! unless session

              result = ::Ai::ExternalAgents::Sessions::CompleteService.new(
                project: user_project,
                current_user: current_user,
                session: session,
                params: declared_params(include_missing: false)
              ).execute

              if result.success?
                present result.payload[:session],
                  with: ::API::Entities::Ai::ExternalAgents::Session
              elsif result.reason == :forbidden
                forbidden!(result.message)
              else
                bad_request!(result.message)
              end
            end

            desc 'List external agent sessions for a project.' do
              detail 'Returns a paginated list of external agent sessions for the project.'
              success ::API::Entities::Ai::ExternalAgents::Session
              failure [
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not found' }
              ]
              tags %w[projects ai_agent_sessions]
            end
            params do
              optional :agent_type, type: String,
                desc: 'Filter by agent type.',
                values: ::Ai::ExternalAgents::AgentIdentity::AGENT_TYPES
              optional :status, type: String,
                desc: 'Filter by status.',
                values: %w[created running finished failed stopped]
              optional :created_after, type: DateTime, desc: 'Filter sessions created after this time.'
              optional :created_before, type: DateTime, desc: 'Filter sessions created before this time.'
              use :pagination
            end
            route_setting :lifecycle, :experiment
            route_setting :authorization, permissions: :read_ai_agent_session, boundary_type: :project
            get do
              authorize! :read_ai_agent_session, user_project

              sessions = ::Ai::DuoWorkflows::Workflow.external.for_project(user_project).for_user(current_user.id).ordered_by_id_desc
              sessions = sessions.for_agent_type(params[:agent_type]) if params[:agent_type].present?
              sessions = sessions.for_status(params[:status]) if params[:status].present?
              sessions = sessions.created_after(params[:created_after]) if params[:created_after].present?
              sessions = sessions.created_before(params[:created_before]) if params[:created_before].present?

              present paginate(sessions),
                with: ::API::Entities::Ai::ExternalAgents::Session
            end
          end
        end
      end
    end
  end
end
