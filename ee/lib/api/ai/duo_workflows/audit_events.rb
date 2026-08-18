# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class AuditEvents < ::API::Base
        include APIGuard

        allow_access_with_scope :ai_workflows

        feature_category :audit_events

        before { authenticate! }

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            namespace :workflows do
              route_param :id, type: Integer do
                resource :audit_events do
                  # rubocop:disable API/DescriptionDetail -- internal endpoint, not part of the public API
                  # rubocop:disable API/DescriptionSuccessResponse -- internal endpoint, not part of the public API
                  desc 'Ingest AI audit events from Duo Workflow Service' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  # rubocop:enable API/DescriptionSuccessResponse
                  # rubocop:enable API/DescriptionDetail
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :events, type: Array, allow_blank: false,
                      desc: 'Array of CloudEvents v1.0 envelopes' do
                      requires :id, type: String, desc: 'CloudEvent id (UUID)'
                      requires :type, type: String, desc: 'Event type (e.g., ai_llm_input_sent)'
                      requires :source, type: String, desc: 'CloudEvent source'
                      requires :time, type: DateTime, desc: 'Event timestamp (ISO 8601) from the gateway'
                      optional :data, type: Hash, desc: 'Event-specific payload'
                    end
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_token_auth
                  post do
                    workflow = find_workflow!(params[:id])

                    result = ::Ai::DuoWorkflows::IngestAuditEventsService.new(
                      workflow: workflow,
                      events: params[:events],
                      current_user: current_user
                    ).execute

                    if result.error?
                      render_api_error!(result.message, result.reason || :unprocessable_entity)
                    else
                      status 202
                      result.payload
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
