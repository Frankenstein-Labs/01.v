# frozen_string_literal: true

require 'grpc'
require 'gitlab/duo_workflow_service'
require 'google/protobuf'
require 'json'

module Ai
  module DuoWorkflow
    module DuoWorkflowService
      class Client
        include Gitlab::Utils::StrongMemoize

        ERROR_SERVICE_URL_NOT_CONFIGURED = 'Duo Workflow service URL is not configured'
        VALIDATE_FLOW_CONFIG_TIMEOUT = 10

        def initialize(
          duo_workflow_service_url:, current_user:, secure:, token: nil, pre_approved_tools: [],
          denied_tools: [])
          @duo_workflow_service_url = duo_workflow_service_url
          @current_user = current_user
          @secure = secure
          @token = token
          @pre_approved_tools = pre_approved_tools
          @denied_tools = denied_tools
        end

        def track_self_hosted_client_event(request_id:, feature_qualified_name:, feature_ai_catalog_item: false)
          stub = ::DuoWorkflowService::DuoWorkflow::Stub.new(
            duo_workflow_service_url,
            channel_credentials
          )

          event = ::DuoWorkflowService::TrackSelfHostedClientEvent.new(
            requestID: request_id,
            workflowID: request_id,
            featureQualifiedName: feature_qualified_name,
            featureAiCatalogItem: feature_ai_catalog_item
          )

          responses = stub.track_self_hosted_execute_workflow([event], metadata: generate_headers)
          responses.first # consume the single ack

          ServiceResponse.success(message: "Billing event tracked")
        rescue StandardError => e
          ServiceResponse.error(message: e.message)
        end

        def generate_gateway_headers
          Gitlab::AiGateway.public_headers(
            user: current_user,
            unit_primitive_name: :duo_agent_platform,
            governing_namespace_id: governing_namespace&.id,
            organization_id: governing_namespace&.organization_id,
            ai_feature_name: :duo_agent_platform
          )
        end

        def generate_headers
          generate_gateway_headers.transform_keys(&:downcase).merge(metadata)
        end

        def generate_token
          return ServiceResponse.error(message: ERROR_SERVICE_URL_NOT_CONFIGURED) if duo_workflow_service_url.blank?

          begin
            request = ::DuoWorkflowService::GenerateTokenRequest.new
            response = grpc_stub.generate_token(request, metadata: generate_headers)
          rescue StandardError => e
            return ServiceResponse.error(message: e.message)
          end

          # Extract capabilities if present (backward compatible)
          server_capabilities = response.respond_to?(:server_capabilities) ? response.server_capabilities.to_a : []

          ServiceResponse.success(
            message: "JWT Generated",
            payload: {
              token: response.token,
              expires_at: response.expiresAt,
              capabilities: server_capabilities
            }
          )
        end

        def validate_flow_config(flow_config:)
          return ServiceResponse.error(message: ERROR_SERVICE_URL_NOT_CONFIGURED) if duo_workflow_service_url.blank?

          begin
            request = ::DuoWorkflowService::ValidateFlowConfigRequest.new(
              flow_config: Google::Protobuf::Struct.decode_json(flow_config.to_json)
            )
            response = grpc_stub.validate_flow_config(
              request,
              metadata: generate_headers,
              deadline: GRPC::Core::TimeConsts.from_relative_time(VALIDATE_FLOW_CONFIG_TIMEOUT)
            )
          rescue StandardError => e
            Gitlab::AppLogger.error("DWS ValidateFlowConfig failed: #{e.message}")
            return ServiceResponse.error(
              message: 'Unable to validate flow configuration. Duo Workflow Service is currently unavailable.'
            )
          end

          if response.valid
            ServiceResponse.success
          else
            ServiceResponse.error(message: response.errors.to_a)
          end
        end

        def list_tools
          return ServiceResponse.error(message: ERROR_SERVICE_URL_NOT_CONFIGURED) if duo_workflow_service_url.blank?

          begin
            response = grpc_stub.list_tools(::DuoWorkflowService::ListToolsRequest.new, metadata: generate_headers)
            data = Gitlab::Json.safe_parse(Google::Protobuf.encode_json(response))
          rescue StandardError => e
            return ServiceResponse.error(message: e.message)
          end

          ServiceResponse.success(
            message: "Tools listed",
            payload: data.slice("tools", "evalDataset")
          )
        end

        def list_capabilities
          return ServiceResponse.error(message: ERROR_SERVICE_URL_NOT_CONFIGURED) if duo_workflow_service_url.blank?

          begin
            response = grpc_stub.list_capabilities(
              ::DuoWorkflowService::ListCapabilitiesRequest.new,
              metadata: generate_headers
            )
          rescue StandardError => e
            return ServiceResponse.error(message: e.message)
          end

          capabilities = response.capabilities.map do |capability|
            {
              name: capability.name,
              metadata: capability.metadata.presence && Gitlab::Json.safe_parse(capability.metadata)
            }
          end

          ServiceResponse.success(
            message: "Capabilities listed",
            payload: { capabilities: capabilities }
          )
        end

        private

        attr_reader :duo_workflow_service_url, :current_user, :token

        def grpc_stub
          ::DuoWorkflowService::DuoWorkflow::Stub.new(
            duo_workflow_service_url,
            channel_credentials
          )
        end
        strong_memoize_attr :grpc_stub

        def governing_namespace
          current_user&.governing_namespace
        end
        strong_memoize_attr :governing_namespace

        def metadata
          {
            "authorization" => "Bearer #{token || cloud_connector_token}",
            "x-gitlab-authentication-type" => "oidc",
            'x-gitlab-instance-id' => ::Gitlab::GlobalAnonymousId.instance_id,
            'x-gitlab-realm' => ::CloudConnector.gitlab_realm,
            'x-gitlab-global-user-id' => ::Gitlab::GlobalAnonymousId.user_id(current_user),
            'x-gitlab-user-id' => current_user&.id&.to_s,
            'x-gitlab-client-type' => 'gitlab-rails',
            'x-gitlab-version' => ::Gitlab.version_info.to_s
          }
        end

        def cloud_connector_token
          Gitlab::AiGateway.cloud_connector_token(
            :duo_agent_platform,
            current_user,
            root_namespace_id: governing_namespace&.id,
            extra_claims: {
              tool_access_policies: { allow: @pre_approved_tools, deny: @denied_tools }.to_json
            }
          )
        end

        def channel_credentials
          if @secure
            GRPC::Core::ChannelCredentials.new(::Gitlab::X509::Certificate.ca_certs_bundle)
          else
            :this_channel_is_insecure
          end
        end
      end
    end
  end
end
