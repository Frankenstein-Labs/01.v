# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      # Register-once callback endpoints for Duo flow lifecycle events. A client
      # (e.g. AutoFlow) registers its HTTPS endpoint and signing secret here once,
      # then references the returned id via `callback_hook_id` when creating a
      # flow. Backed by Ai::DuoWorkflows::FlowCallbackHook (a WebHook), so the URL
      # and secrets are encrypted at rest and delivery is signed + logged +
      # retried by the existing webhook machinery.
      class FlowCallbacks < ::API::Base
        include PaginationParams
        include APIGuard

        MAX_URL_LENGTH = 8192
        MAX_NAME_LENGTH = 255
        SIGNING_TOKEN_LENGTH = 51 # 'whsec_' (6) + 44 chars of base64(32 bytes) + padding
        MAX_TOKEN_LENGTH = 8192

        feature_category :duo_agent_platform
        urgency :low

        before do
          authenticate!
          set_current_organization
        end

        helpers do
          def current_org
            ::Current.organization
          end

          # Every caller guards with `bad_request!('An organization could not be
          # resolved') unless current_org` first, so current_org is always present here.
          def flow_callback_hooks
            ::Ai::DuoWorkflows::FlowCallbackHook.for_organization(current_org.id)
          end

          def find_flow_callback!(id)
            flow_callback_hooks.find_by_id(id) || not_found!('Flow callback')
          end

          def require_https!(url)
            return if url.to_s.downcase.start_with?('https://') || Gitlab.dev_or_test_env?

            bad_request!('url must be an HTTPS URL')
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resource :flow_callbacks do
              desc 'List registered flow callback endpoints' do
                detail 'Lists the flow callback endpoints registered for your organization. Secrets are not returned.'
                tags ['duo_workflow_flow_callback_hooks']
                success code: 200, model: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
                failure [
                  { code: 400, message: 'Bad request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' }
                ]
              end
              params do
                use :pagination
              end
              route_setting :authorization, permissions: :read_duo_flow_callback_hook, boundary_type: :instance
              get do
                bad_request!('An organization could not be resolved') unless current_org
                authorize! :read_duo_flow_callback_hook, current_org

                present paginate(flow_callback_hooks.recent_first), with: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
              end

              desc 'Register a flow callback endpoint' do
                detail 'Registers an HTTPS endpoint for Duo flow lifecycle callbacks. Reference the returned ' \
                  'id via callback_hook_id when creating a flow. Secrets are never returned.'
                tags ['duo_workflow_flow_callback_hooks']
                success code: 201, model: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' }
                ]
              end
              params do
                requires :url, type: String, limit: MAX_URL_LENGTH, desc: 'HTTPS URL that receives callbacks',
                  documentation: { example: 'https://autoflow.example.com/duo/callbacks' }
                optional :name, type: String, limit: MAX_NAME_LENGTH, desc: 'A label for this endpoint'
                optional :signing_token, type: String, limit: SIGNING_TOKEN_LENGTH,
                  desc: 'HMAC signing secret in whsec_<base64-of-32-bytes> format, used to compute the ' \
                    'webhook-signature header so you can verify payloads. Not returned.'
                optional :token, type: String, limit: MAX_TOKEN_LENGTH,
                  desc: 'Optional shared secret sent verbatim as the X-Gitlab-Token header. Not returned.'
              end
              route_setting :authorization, permissions: :create_duo_flow_callback_hook, boundary_type: :instance
              post do
                bad_request!('An organization could not be resolved') unless current_org
                authorize! :create_duo_flow_callback_hook, current_org

                require_https!(params[:url])

                hook = ::Ai::DuoWorkflows::FlowCallbackHook.new(
                  url: params[:url],
                  name: params[:name].presence || 'Duo Agent flow callback',
                  signing_token: params[:signing_token],
                  token: params[:token],
                  organization: current_org
                )

                bad_request!(hook.errors.full_messages.join(', ')) unless hook.save

                present hook, with: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
              end

              route_param :id, type: Integer, desc: 'The ID of a registered flow callback endpoint' do
                desc 'Get a registered flow callback endpoint' do
                  detail 'Returns a single registered flow callback endpoint. Secrets are not returned.'
                  tags ['duo_workflow_flow_callback_hooks']
                  success code: 200, model: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
                  failure [
                    { code: 400, message: 'Bad request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                end
                route_setting :authorization, permissions: :read_duo_flow_callback_hook, boundary_type: :instance
                get do
                  bad_request!('An organization could not be resolved') unless current_org
                  authorize! :read_duo_flow_callback_hook, current_org

                  present find_flow_callback!(params[:id]), with: ::API::Entities::Ai::DuoWorkflows::FlowCallbackHook
                end

                desc 'Delete a registered flow callback endpoint' do
                  detail 'Deletes a registered flow callback endpoint so it no longer receives deliveries.'
                  tags ['duo_workflow_flow_callback_hooks']
                  success code: 204
                  failure [
                    { code: 400, message: 'Bad request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                end
                route_setting :authorization, permissions: :delete_duo_flow_callback_hook, boundary_type: :instance
                delete do
                  bad_request!('An organization could not be resolved') unless current_org
                  authorize! :delete_duo_flow_callback_hook, current_org

                  find_flow_callback!(params[:id]).destroy!

                  no_content!
                end
              end
            end
          end
        end
      end
    end
  end
end
