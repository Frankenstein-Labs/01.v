# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Workflows endpoints with cascading settings', :saas, feature_category: :duo_agent_platform do
  include WorkhorseHelpers

  let_it_be_with_reload(:root_group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: root_group) }
  let_it_be(:user) { create(:user) }

  let(:subgroup) { create(:group, parent: root_group) }
  let(:headers) { workhorse_headers }

  include_context 'workhorse headers'

  before_all do
    root_group.add_owner(user)
    project.add_maintainer(user)
  end

  before do
    subgroup.add_owner(user)

    stub_licensed_features(ai_workflows: true)
    stub_ee_application_setting(duo_features_enabled: true)

    allow(::CloudConnector::Tokens).to receive(:get).and_return('test_token')
  end

  describe 'GET /api/v4/ai/duo_workflows/ws' do
    def parsed_grpc_headers
      ::Gitlab::Json.safe_parse(response.body).dig('DuoWorkflow', 'Service', 'Headers')
    end

    context 'when root is "Off by default" and subgroup is "On by default"' do
      before do
        root_group.namespace_settings.update!(
          duo_features_enabled: false,
          lock_duo_features_enabled: false
        )
        subgroup.namespace_settings.update!(duo_features_enabled: true)
      end

      it 'allows WebSocket connection from subgroup context and returns subgroup-resolved headers',
        :aggregate_failures do
        subgroup.namespace_settings.update!(model_prompt_cache_enabled: true)

        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

        json_response = ::Gitlab::Json.safe_parse(response.body)
        expect(json_response).to have_key('DuoWorkflow')
        expect(json_response['DuoWorkflow']).to have_key('Service')
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('true')
      end

      it 'allows WebSocket connection from project context', :aggregate_failures do
        subgroup.namespace_settings.update!(model_prompt_cache_enabled: true)

        get api('/ai/duo_workflows/ws', user),
          params: { project_id: project.id, namespace_id: root_group.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

        json_response = ::Gitlab::Json.safe_parse(response.body)
        expect(json_response).to have_key('DuoWorkflow')
      end

      it 'uses subgroup namespace for cascading settings checks' do
        subgroup.namespace_settings.update!(model_prompt_cache_enabled: true)

        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('true')
      end
    end

    context 'when root locks Duo to "Never on"' do
      before do
        root_group.namespace_settings.update!(
          duo_features_enabled: false,
          lock_duo_features_enabled: true,
          model_prompt_cache_enabled: false,
          lock_model_prompt_cache_enabled: true
        )
        subgroup.namespace_settings.update_columns(model_prompt_cache_enabled: true)
      end

      it 'surfaces the cascaded (locked) value on the most specific namespace', :aggregate_failures do
        expect(subgroup.duo_features_enabled).to be_falsey

        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('false')
      end
    end

    context 'when subgroup overrides model_prompt_cache_enabled' do
      before do
        root_group.namespace_settings.update!(
          model_prompt_cache_enabled: false,
          lock_model_prompt_cache_enabled: false
        )
        subgroup.namespace_settings.update!(model_prompt_cache_enabled: true)
      end

      it 'uses the subgroup override rather than the root value' do
        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('true')
      end
    end

    context 'when root locks model_prompt_cache_enabled' do
      before do
        root_group.namespace_settings.update!(
          model_prompt_cache_enabled: true,
          lock_model_prompt_cache_enabled: true
        )
        subgroup.namespace_settings.update_columns(model_prompt_cache_enabled: false)
      end

      it 'surfaces the locked root value on the subgroup' do
        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('true')
      end
    end

    context 'when model_prompt_cache_enabled cannot be resolved from the namespace' do
      context 'when the most-specific namespace has no namespace_settings record' do
        before do
          subgroup_id = subgroup.id
          allow_next_found_instance_of(Group) do |group|
            allow(group).to receive(:namespace_settings).and_wrap_original do |original|
              group.id == subgroup_id ? nil : original.call
            end
          end
        end

        it 'falls back to the root namespace value (application-setting default of true)' do
          get api('/ai/duo_workflows/ws', user),
            params: { namespace_id: subgroup.id },
            headers: headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('true')
        end
      end

      context 'when model_prompt_cache_enabled is explicitly false on the namespace' do
        before do
          subgroup.namespace_settings.update!(model_prompt_cache_enabled: false)
        end

        it 'sets the model_prompt_cache_enabled header to "false"' do
          get api('/ai/duo_workflows/ws', user),
            params: { namespace_id: subgroup.id },
            headers: headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('false')
        end
      end
    end

    context 'when root is "On by default" and subgroup inherits' do
      before do
        root_group.namespace_settings.update!(
          duo_features_enabled: true,
          lock_duo_features_enabled: false
        )
      end

      it 'allows WebSocket connection (inherits from root)', :aggregate_failures do
        expect(subgroup.duo_features_enabled).to be_truthy

        get api('/ai/duo_workflows/ws', user),
          params: { namespace_id: subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
      end
    end

    context 'when namespace_id belongs to a different root than root_namespace_id' do
      let_it_be(:other_root) { create(:group) }
      let_it_be_with_reload(:other_subgroup) { create(:group, parent: other_root) }

      before_all do
        other_root.add_owner(user)
        other_subgroup.add_owner(user)
      end

      it 'rejects the request with forbidden when contexts disagree' do
        get api('/ai/duo_workflows/ws', user),
          params: { root_namespace_id: root_group.id, namespace_id: other_subgroup.id },
          headers: headers

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'uses the header namespace when root_namespace_id points to a different root', :aggregate_failures do
        other_subgroup.namespace_settings.update!(model_prompt_cache_enabled: false)

        get api('/ai/duo_workflows/ws', user),
          params: { root_namespace_id: root_group.id },
          headers: headers.merge('X-Gitlab-Namespace-Id' => other_subgroup.id.to_s)

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_grpc_headers['x-gitlab-model-prompt-cache-enabled']).to eq('false')
      end
    end
  end

  describe 'POST /api/v4/ai/duo_workflows/direct_access' do
    let(:dws_capabilities) { %w[tool_call_approval approve_for_session] }

    before do
      allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
        allow(client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: {
            token: 'duo_workflow_token',
            expires_at: 1.hour.from_now.to_i,
            capabilities: dws_capabilities
          })
        )
      end
      allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(false)

      allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
      allow_next_instance_of(::Ai::UsageQuotaService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: {
            oauth_access_token: instance_double(
              Doorkeeper::AccessToken,
              plaintext_token: 'oauth_token',
              expires_at: 2.hours.from_now.to_i
            )
          })
        )
      end
    end

    context 'when subgroup overrides tool_approval_for_session_enabled to false' do
      before do
        root_group.namespace_settings.update!(tool_approval_for_session_enabled: true)
        subgroup.namespace_settings.update!(tool_approval_for_session_enabled: false)
      end

      it 'filters tool_call_approval out of server_capabilities using the subgroup setting' do
        post api('/ai/duo_workflows/direct_access', user),
          params: { root_namespace_id: root_group.id },
          headers: { 'X-Gitlab-Namespace-Id' => subgroup.id.to_s }

        expect(response).to have_gitlab_http_status(:created)
        json_response = ::Gitlab::Json.safe_parse(response.body)
        expect(json_response['server_capabilities']).to include('approve_for_session', 'job_trace_pagination')
        expect(json_response['server_capabilities']).not_to include('tool_call_approval')
      end
    end

    context 'when subgroup overrides tool_approval_for_session_enabled to true while root is false' do
      before do
        root_group.namespace_settings.update!(tool_approval_for_session_enabled: false)
        subgroup.namespace_settings.update!(tool_approval_for_session_enabled: true)
      end

      it 'keeps tool_call_approval because the subgroup override is honored' do
        post api('/ai/duo_workflows/direct_access', user),
          params: { root_namespace_id: root_group.id },
          headers: { 'X-Gitlab-Namespace-Id' => subgroup.id.to_s }

        expect(response).to have_gitlab_http_status(:created)
        json_response = ::Gitlab::Json.safe_parse(response.body)
        expect(json_response['server_capabilities']).to include('tool_call_approval')
      end
    end
  end
end
