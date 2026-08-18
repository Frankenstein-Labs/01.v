# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowContextGenerationService, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:user) { create(:user) }
  let_it_be(:container) { create(:project, namespace: create(:group)) }
  let(:workflow_definition) { 'software_development' }
  let_it_be_with_reload(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let(:service) do
    described_class.new(
      current_user: user,
      organization: container.organization,
      workflow_definition: workflow_definition,
      container: container,
      service_account: service_account
    )
  end

  describe '#generate_oauth_token' do
    let(:oauth_service) { instance_double(Ai::DuoWorkflows::CreateOauthAccessTokenService) }
    let(:oauth_token) { instance_double(OauthAccessToken) }

    before do
      allow(Ai::DuoWorkflows::CreateOauthAccessTokenService).to receive(:new).and_return(oauth_service)
    end

    context 'when token creation succeeds' do
      before do
        allow(oauth_service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { oauth_access_token: oauth_token })
        )
      end

      it 'returns success with oauth access token' do
        result = service.generate_oauth_token

        expect(result).to be_success
        expect(result.payload[:oauth_access_token]).to eq(oauth_token)
      end
    end

    context 'when token creation fails' do
      before do
        allow(oauth_service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Token creation failed')
        )
      end

      it 'returns error with message and http status' do
        result = service.generate_oauth_token

        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end
    end
  end

  describe '#generate_composite_oauth_token' do
    let(:composite_oauth_service) { instance_double(Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService) }
    let(:oauth_token) { instance_double(OauthAccessToken) }

    before do
      allow(Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService).to receive(:new)
                                                                           .and_return(composite_oauth_service)
    end

    context 'when token creation succeeds' do
      before do
        allow(composite_oauth_service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { oauth_access_token: oauth_token })
        )
      end

      it 'returns success with oauth access token' do
        result = service.generate_composite_oauth_token

        expect(result).to be_success
        expect(result.payload[:oauth_access_token]).to eq(oauth_token)
      end

      context 'when passing service_account' do
        let(:service_account) { build(:user, :service_account) }

        let(:service) do
          described_class.new(
            current_user: user,
            organization: container.organization,
            workflow_definition: workflow_definition,
            service_account: service_account,
            container: container
          )
        end

        it 'passes the service_account to CreateCompositeOauthAccessTokenService' do
          expect(Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService)
            .to receive(:new)
            .with(a_hash_including(service_account:))
            .and_return(composite_oauth_service)

          service.generate_composite_oauth_token
        end
      end
    end

    context 'when token creation fails' do
      before do
        allow(composite_oauth_service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Composite token creation failed')
        )
      end

      it 'returns error with message' do
        result = service.generate_composite_oauth_token

        expect(result).to be_error
        expect(result.message).to eq('Composite token creation failed')
      end
    end
  end

  describe '#generate_workflow_token' do
    let(:workflow_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }
    let(:token_data) { { token: 'workflow_token', expires_at: 1.hour.from_now } }

    before do
      allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(workflow_client)
    end

    context 'when token generation succeeds' do
      before do
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'returns success with token data' do
        result = service.generate_workflow_token

        expect(result).to be_success
        expect(result.payload).to include(token_data)
      end
    end

    context 'when token generation fails' do
      before do
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.error(message: 'Workflow token generation failed')
        )
      end

      it 'returns error with message' do
        result = service.generate_workflow_token

        expect(result).to be_error
        expect(result.message).to eq('Workflow token generation failed')
      end
    end

    context 'for duo_workflow_service_url' do
      let(:cloud_connector_url) { 'cloud.staging.gitlab.com:443' }
      let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }
      let(:duo_agent_platform_feature_setting) { nil }

      before do
        allow(Gitlab::DuoWorkflow::Client).to receive_messages(self_hosted_url: self_hosted_url,
          cloud_connected_url: cloud_connector_url)
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: { token: 't', expires_at: 1.hour.from_now })
        )
      end

      shared_examples 'initializes client with expected service url' do
        it 'passes expected duo_workflow_service_url to client' do
          expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
            hash_including(
              duo_workflow_service_url: expected_service_server_url,
              current_user: user,
              secure: ::Gitlab::DuoWorkflow::Client.secure?(
                feature_setting: service.duo_agent_platform_feature_setting
              )
            )
          ).and_return(workflow_client)

          result = service.generate_workflow_token

          expect(result).to be_success
        end
      end

      context 'when self-hosted feature setting exists' do
        let(:expected_service_server_url) { self_hosted_url }

        let_it_be(:model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when instance level model selection exists' do
        let(:expected_service_server_url) { cloud_connector_url }

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when namespace level model selection exists', :saas do
        let(:expected_service_server_url) { cloud_connector_url }

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: container.namespace,
            feature: :duo_agent_platform,
            offered_model_ref: 'claude_sonnet_3_7_20250219')
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when no feature setting exists' do
        let(:expected_service_server_url) { cloud_connector_url }

        it_behaves_like 'initializes client with expected service url'
      end
    end

    context 'when gitlab_duo_governance_settings flag is enabled' do
      before do
        stub_feature_flags(gitlab_duo_governance_settings: true)
        allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.success(payload: { pre_approved_tools: ['read_file'], denied_tools: [] })
          )
        end
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'passes pre_approved and denied tools from resolution service to client' do
        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
          hash_including(pre_approved_tools: ['read_file'], denied_tools: [])
        ).and_return(workflow_client)

        service.generate_workflow_token
      end

      it 'passes the project to ResolutionService when container is a project' do
        expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
          hash_including(project: container)
        ).and_call_original

        allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.success(payload: { pre_approved_tools: [], denied_tools: [] })
          )
        end

        service.generate_workflow_token
      end

      context 'when the workflow environment is ambient (background)' do
        let(:workflow_definition) { 'developer/v1' }

        let(:service) do
          described_class.new(
            current_user: user,
            organization: container.organization,
            workflow_definition: workflow_definition,
            container: container,
            service_account: service_account,
            environment: 'ambient'
          )
        end

        it 'resolves the :background surface when the background-governance flag is enabled' do
          expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
            hash_including(surface: :background)
          ).and_call_original

          service.generate_workflow_token
        end

        it 'resolves the :web surface when the background-governance flag is disabled' do
          stub_feature_flags(duo_workflow_background_tool_governance: false)

          expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
            hash_including(surface: :web)
          ).and_call_original

          service.generate_workflow_token
        end
      end

      context 'when the workflow environment is a local surface' do
        let(:service) do
          described_class.new(
            current_user: user,
            organization: container.organization,
            workflow_definition: workflow_definition,
            container: container,
            service_account: service_account,
            environment: 'ide'
          )
        end

        it 'resolves the :ide surface when the local-governance flag is enabled' do
          expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
            hash_including(surface: :ide)
          ).and_call_original

          service.generate_workflow_token
        end

        it 'resolves the :web surface when the local-governance flag is disabled' do
          stub_feature_flags(duo_workflow_local_tool_governance: false)

          expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
            hash_including(surface: :web)
          ).and_call_original

          service.generate_workflow_token
        end
      end

      it 'resolves the :web surface when no environment is given' do
        expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
          hash_including(surface: :web)
        ).and_call_original

        service.generate_workflow_token
      end
    end

    context 'when gitlab_duo_governance_settings flag is disabled' do
      before do
        stub_feature_flags(gitlab_duo_governance_settings: false)
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'passes empty pre_approved and denied tools to client' do
        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
          hash_including(pre_approved_tools: [], denied_tools: [])
        ).and_return(workflow_client)

        service.generate_workflow_token
      end
    end

    context 'when resolution service fails' do
      before do
        stub_feature_flags(gitlab_duo_governance_settings: true)
        allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(message: 'something went wrong')
          )
        end
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'falls back to empty pre_approved_tools and denied_tools' do
        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
          hash_including(pre_approved_tools: [], denied_tools: [])
        ).and_return(workflow_client)

        service.generate_workflow_token
      end
    end

    context 'when container is nil' do
      subject(:service) do
        described_class.new(
          current_user: user,
          organization: container.organization,
          container: nil
        )
      end

      before do
        stub_feature_flags(gitlab_duo_governance_settings: true)
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'passes empty pre_approved and denied tools to client' do
        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
          hash_including(pre_approved_tools: [], denied_tools: [])
        ).and_return(workflow_client)

        service.generate_workflow_token
      end
    end
  end

  describe '#generate_oauth_token_with_composite_identity_support' do
    context 'when composite identity is enforced on the service account' do
      it 'calls generate_composite_oauth_token' do
        expect(service).to receive(:generate_composite_oauth_token)

        service.generate_oauth_token_with_composite_identity_support
      end
    end

    context 'when service account does not have composite identity enforced' do
      before do
        service_account.update!(composite_identity_enforced: false)
      end

      it 'calls generate_oauth_token' do
        expect(service).to receive(:generate_oauth_token)

        service.generate_oauth_token_with_composite_identity_support
      end
    end
  end

  describe '#already_scoped_for_ai_workflows?' do
    let(:ai_workflow_scopes) { ::Gitlab::Auth::AI_WORKFLOW_SCOPES + [::Gitlab::Auth::MCP_SCOPE] }
    let(:access_token) { instance_double(OauthAccessToken) }

    context 'when access_token is nil' do
      it 'returns false' do
        expect(service.already_scoped_for_ai_workflows?(nil)).to be(false)
      end
    end

    context 'when access_token.scopes returns nil' do
      it 'returns false' do
        allow(access_token).to receive(:scopes).and_return(nil)

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end
    end

    context 'when service account does not have composite identity enforced' do
      before do
        service_account.update!(composite_identity_enforced: false)
      end

      it 'returns true when the token has exactly the AI workflow scopes' do
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes)

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(true)
      end

      it 'returns false when the token has AI workflow scopes plus the dynamic user scope' do
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes + [:"user:#{user.id}"])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end

      it 'returns false when the token has extra scopes' do
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes + [:api])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end

      it 'returns false when the token has no scopes' do
        allow(access_token).to receive(:scopes).and_return([])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end
    end

    context 'when composite identity is enabled' do
      it 'returns true when the token has AI workflow scopes plus the dynamic user scope' do
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes + [:"user:#{user.id}"])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(true)
      end

      it 'returns false when the token has exactly the AI workflow scopes without the dynamic user scope' do
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes)

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end

      it 'returns false when the token has a different user in the dynamic scope' do
        other_user_id = user.id + 1
        allow(access_token).to receive(:scopes).and_return(ai_workflow_scopes + [:"user:#{other_user_id}"])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end

      it 'returns false when the token has no scopes' do
        allow(access_token).to receive(:scopes).and_return([])

        expect(service.already_scoped_for_ai_workflows?(access_token)).to be(false)
      end
    end
  end

  describe '#duo_agent_platform_feature_setting' do
    context 'when workflow definition is secrets_fp_detection/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:secret_fp_detection_feature_setting) do
        create(:ai_feature_setting, :secret_vulnerability_fp_detection, self_hosted_model: model)
      end

      let(:workflow_definition) { 'secrets_fp_detection/v1' }

      it 'returns the secret fp detection feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(secret_fp_detection_feature_setting)
      end
    end

    context 'when workflow definition is resolve_sast_vulnerability/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:sast_vr_feature_setting) do
        create(:ai_feature_setting, :sast_vulnerability_resolution, self_hosted_model: model)
      end

      let(:workflow_definition) { 'resolve_sast_vulnerability/v1' }

      it 'returns the sast vulnerability resolution feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(sast_vr_feature_setting)
      end
    end

    context 'when workflow definition is sast_fp_detection/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:sast_fp_detection_feature_setting) do
        create(:ai_feature_setting, :sast_vulnerability_fp_detection, self_hosted_model: model)
      end

      let(:workflow_definition) { 'sast_fp_detection/v1' }

      it 'returns the sast fp detection feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(sast_fp_detection_feature_setting)
      end
    end

    context 'when workflow definition is code_review/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:review_merge_request_dap_feature_setting) do
        create(:ai_feature_setting, :review_merge_request_dap, self_hosted_model: model)
      end

      let(:workflow_definition) { 'code_review/v1' }

      it 'returns the review_merge_request_dap feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(review_merge_request_dap_feature_setting)
      end
    end

    context 'when workflow definition is security_review/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:security_review_feature_setting) do
        create(:ai_feature_setting, :security_review, self_hosted_model: model)
      end

      let(:workflow_definition) { 'security_review/v1' }

      it 'returns the security_review feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(security_review_feature_setting)
      end
    end

    context 'when workflow definition is resolve_dependency_bump/experimental' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:resolve_dependency_bump_feature_setting) do
        create(:ai_feature_setting, :resolve_dependency_bump, self_hosted_model: model)
      end

      let(:workflow_definition) { 'resolve_dependency_bump/experimental' }

      it 'returns the resolve_dependency_bump feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(resolve_dependency_bump_feature_setting)
      end
    end

    context 'when self-hosted feature setting exists' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it 'returns the self-hosted feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end

    context 'when instance level model selection exists' do
      let_it_be(:duo_agent_platform_feature_setting) do
        create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
      end

      it 'returns the instance level feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end

    context 'when namespace level model selection exists', :saas do
      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: container.namespace,
          feature: :duo_agent_platform,
          offered_model_ref: 'claude_sonnet_3_7_20250219')
      end

      before do
        container.namespace.add_developer(user)
      end

      it 'returns the namespace level feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end
  end
end
