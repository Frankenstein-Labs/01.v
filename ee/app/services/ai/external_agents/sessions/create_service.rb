# frozen_string_literal: true

module Ai
  module ExternalAgents
    module Sessions
      class CreateService
        def initialize(project:, current_user:, params:)
          @project = project
          @current_user = current_user
          @params = params
        end

        def execute
          return ServiceResponse.error(message: 'Unauthorized') unless authorized?
          return ServiceResponse.error(message: 'Agent identity not found', reason: :not_found) unless valid_identity?

          if params[:started_at].present? && params[:started_at].future?
            return ServiceResponse.error(message: 'started_at cannot be in the future')
          end

          if params[:started_at].present? && params[:started_at] < 30.days.ago
            return ServiceResponse.error(message: 'started_at cannot be more than 30 days in the past')
          end

          session = find_or_build_session
          return ServiceResponse.success(payload: { session: session }) if session.persisted?

          begin
            session.start!
            ServiceResponse.success(payload: { session: session })
          rescue ActiveRecord::RecordNotUnique
            existing = existing_session
            ServiceResponse.success(payload: { session: existing }) if existing
          rescue StateMachines::InvalidTransition, ActiveRecord::RecordInvalid => e
            ServiceResponse.error(message: e.message)
          end
        end

        private

        attr_reader :project, :current_user, :params

        def authorized?
          current_user.can?(:create_ai_agent_session, project)
        end

        def find_or_build_session
          return existing_session if params[:idempotency_key].present? && existing_session

          ::Ai::DuoWorkflows::Workflow.new(
            user: current_user,
            project: project,
            environment: :external,
            workflow_definition: 'external_agent',
            agent_type: params[:agent_type],
            agent_identity_id: params[:agent_identity_id],
            sync_type: params[:sync_type],
            goal: params[:goal],
            created_at: params[:started_at],
            idempotency_key: params[:idempotency_key]
          )
        end

        def existing_session
          @existing_session ||= ::Ai::DuoWorkflows::Workflow
            .find_external_session_by_idempotency_key(
              project: project,
              user_id: current_user.id,
              idempotency_key: params[:idempotency_key]
            )
        end

        def valid_identity?
          return true unless params[:agent_identity_id].present?

          ::Ai::ExternalAgents::AgentIdentity.owned_by?(
            id: params[:agent_identity_id],
            user: current_user,
            project: project,
            agent_type: params[:agent_type]
          )
        end
      end
    end
  end
end
