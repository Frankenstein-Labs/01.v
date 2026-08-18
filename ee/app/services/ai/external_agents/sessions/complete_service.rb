# frozen_string_literal: true

module Ai
  module ExternalAgents
    module Sessions
      class CompleteService
        def initialize(project:, current_user:, session:, params:)
          @project = project
          @current_user = current_user
          @session = session
          @params = params
        end

        def execute
          return ServiceResponse.error(message: 'Unauthorized') unless authorized?
          return ServiceResponse.error(message: 'Session not found') unless session
          return ServiceResponse.error(message: 'Not session owner', reason: :forbidden) unless owner?
          return ServiceResponse.success(payload: { session: session }) if sha256_unchanged?

          begin
            update_session
            ServiceResponse.success(payload: { session: session })
          rescue StateMachines::InvalidTransition, ActiveRecord::RecordInvalid => e
            ServiceResponse.error(message: e.message)
          end
        end

        private

        attr_reader :project, :current_user, :session, :params

        def authorized?
          current_user.can?(:update_ai_agent_session, project)
        end

        def owner?
          session.user_id == current_user.id
        end

        def sha256_unchanged?
          params[:jsonl_sha256].present? &&
            session.jsonl_sha256 == params[:jsonl_sha256] &&
            (session.finished? || session.failed?)
        end

        def status_for_params
          params[:status] == 'completed' ? 'finished' : 'failed'
        end

        def update_session
          session.jsonl_sha256 = params[:jsonl_sha256] if params[:jsonl_sha256].present?

          case params[:status]
          when 'completed'
            session.finish!
          when 'failed'
            session.drop!
          end
        end
      end
    end
  end
end
