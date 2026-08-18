# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  describe '.url_for' do
    subject(:url) { described_class.url_for(feature_setting: feature_setting, user: user) }

    let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }
    let(:cloud_connector_url) { 'cloud.gitlab.com:443' }

    before do
      stub_application_setting(duo_agent_platform_service_url: self_hosted_url)
      allow(described_class).to receive(:cloud_connected_url).and_return(cloud_connector_url)
    end

    context 'when feature setting is self-hosted' do
      let_it_be(:model) { create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219') }
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model) }

      it 'returns the self-hosted URL' do
        expect(url).to eq(self_hosted_url)
      end
    end

    context 'when feature setting is not self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, provider: :vendored) }

      it 'returns the cloud connector URL' do
        expect(url).to eq(cloud_connector_url)
      end
    end

    context 'when feature setting is nil' do
      let(:feature_setting) { nil }

      it 'returns the cloud connector URL' do
        expect(url).to eq(cloud_connector_url)
      end
    end
  end

  describe '.url' do
    subject(:url) { described_class.url(user: user) }

    it 'returns cloud connector URL' do
      expect(url).to eq("cloud.gitlab.com:443")
    end

    context 'with self-hosted URL' do
      let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }

      context 'when self-hosted URL is set' do
        before do
          stub_application_setting(duo_agent_platform_service_url: self_hosted_url)
        end

        it 'returns self-hosted URL' do
          expect(url).to eq(self_hosted_url)
        end

        context 'when config url is also set' do
          let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

          before do
            allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
          end

          it 'still returns self-hosted URL' do
            expect(url).to eq(self_hosted_url)
          end
        end
      end

      context 'when self-hosted URL is not set' do
        it 'returns cloud connector URL' do
          expect(url).to eq("cloud.gitlab.com:443")
        end
      end
    end

    context 'when url is set in config' do
      let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

      before do
        allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      end

      it 'returns configured url' do
        expect(url).to eq(duo_workflow_service_url)
      end
    end

    context 'when duo_workflow_cloud_connector_url feature flag is disabled' do
      before do
        stub_feature_flags(duo_workflow_cloud_connector_url: false)
      end

      it 'returns url to Duo Workflow Service fleet' do
        expect(url).to eq('duo-workflow-svc.runway.gitlab.net:443')
      end

      context 'when cloud connector url is staging' do
        before do
          allow(::CloudConnector::Config).to receive(:host).and_return('cloud.staging.gitlab.com')
        end

        it 'returns url to staging Duo Workflow Service fleet' do
          expect(url).to eq('duo-workflow-svc.staging.runway.gitlab.net:443')
        end
      end
    end
  end

  describe '.secure?' do
    context 'when feature setting is self-hosted' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it 'returns instance secure setting' do
        stub_application_setting(self_hosted_duo_agent_platform_service_secure: true)
        expect(described_class.secure?(feature_setting: feature_setting)).to be(true)

        stub_application_setting(self_hosted_duo_agent_platform_service_secure: false)
        expect(described_class.secure?(feature_setting: feature_setting)).to be(false)
      end
    end

    context 'when feature setting is not self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, provider: :vendored) }

      it 'returns global secure config' do
        allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
        expect(described_class.secure?(feature_setting: feature_setting)).to be(true)

        allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
        expect(described_class.secure?(feature_setting: feature_setting)).to be(false)

        allow(Gitlab.config.duo_workflow).to receive(:secure).and_return nil
        expect(described_class.secure?(feature_setting: feature_setting)).to be(false)
      end
    end

    context 'when feature setting is nil' do
      it 'returns global secure config' do
        allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
        expect(described_class.secure?(feature_setting: nil)).to be(true)

        allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
        expect(described_class.secure?(feature_setting: nil)).to be(false)
      end
    end
  end

  describe '.cloud_connector_headers' do
    let(:token) { 'duo_workflow_token_123' }

    before do
      allow(::CloudConnector::Tokens).to receive(:get).and_return(token)
      stub_application_setting(enabled_instance_verbose_ai_logs: true)
    end

    it 'returns headers with base URL, authorization, and authentication type' do
      expected_headers = {
        'authorization' => "Bearer #{token}",
        'x-gitlab-authentication-type' => 'oidc',
        'x-gitlab-feature-enabled-by-namespace-ids' => '',
        'x-gitlab-global-user-id' => Gitlab::GlobalAnonymousId.user_id(user),
        'x-gitlab-user-id' => user.id.to_s,
        'x-gitlab-host-name' => 'localhost',
        'x-gitlab-instance-id' => 'uuid-not-set',
        'x-gitlab-is-team-member' => 'false',
        'x-gitlab-realm' => 'self-managed',
        'x-gitlab-deployment-type' => 'self-managed',
        'x-gitlab-version' => Gitlab.version_info.to_s,
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'true',
        'x-gitlab-enabled-feature-flags' => '',
        'x-gitlab-feature-enablement-type' => '',
        'x-gitlab-subject-type' => 'human',
        'x-gitlab-unit-primitive' => 'duo_workflow_execute_workflow'
      }

      expect(described_class.cloud_connector_headers(user: user)).to eq(expected_headers)
    end

    context 'when feature_setting is provided' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it 'passes feature_setting to AiGateway.cloud_connector_token' do
        expect(Gitlab::AiGateway).to receive(:cloud_connector_token).with(
          :duo_agent_platform,
          user,
          feature_setting: duo_agent_platform_feature_setting,
          root_namespace_id: nil,
          extra_claims: { tool_access_policies: '{}' }
        ).and_return(token)

        described_class.cloud_connector_headers(user: user, feature_setting: duo_agent_platform_feature_setting)
      end
    end

    context 'when tool_access_policies is provided' do
      it 'threads tool_access_policies through to AiGateway.cloud_connector_token' do
        tools = ['create_work_item']
        expect(Gitlab::AiGateway).to receive(:cloud_connector_token).with(
          :duo_agent_platform,
          user,
          feature_setting: nil,
          root_namespace_id: nil,
          extra_claims: { tool_access_policies: tools.to_json }
        ).and_return(token)

        described_class.cloud_connector_headers(user: user, tool_access_policies: tools)
      end
    end

    context 'when a subject is provided' do
      let_it_be(:service_account) { create(:user, :service_account) }

      it 'derives x-gitlab-subject-type from the subject while keeping the token keyed to the user',
        :aggregate_failures do
        expect(Gitlab::AiGateway).to receive(:cloud_connector_token).with(
          :duo_agent_platform,
          user,
          feature_setting: nil,
          root_namespace_id: nil,
          extra_claims: { tool_access_policies: '{}' }
        ).and_return(token)

        headers = described_class.cloud_connector_headers(user: user, subject: service_account)

        expect(headers['x-gitlab-subject-type']).to eq('service_account')
        expect(headers['x-gitlab-user-id']).to eq(user.id.to_s)
      end
    end
  end

  describe '.self_hosted_url' do
    subject(:self_hosted_url) { described_class.self_hosted_url }

    context 'when AI setting has duo_agent_platform_service_url configured' do
      let(:service_url) { 'self-hosted-dap-service-url:50052' }

      before do
        stub_application_setting(duo_agent_platform_service_url: service_url)
      end

      it 'returns the configured service URL' do
        expect(self_hosted_url).to eq(service_url)
      end
    end

    context 'when AI setting has empty duo_agent_platform_service_url' do
      before do
        stub_application_setting(duo_agent_platform_service_url: '')
      end

      it 'returns nil' do
        expect(self_hosted_url).to be_nil
      end
    end
  end

  describe '.enable_extended_logging?' do
    subject(:result) { described_class.enable_extended_logging?(user, namespace: namespace) }

    let(:namespace) { nil }

    context 'on a self-hosted Duo instance' do
      before do
        stub_application_setting(duo_agent_platform_service_url: 'localhost:50052')
      end

      context 'when enabled_instance_verbose_ai_logs is true' do
        before do
          stub_application_setting(enabled_instance_verbose_ai_logs: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when enabled_instance_verbose_ai_logs is false' do
        before do
          stub_application_setting(enabled_instance_verbose_ai_logs: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when the duo_workflow_extended_logging feature flag is enabled' do
      it { is_expected.to be(true) }
    end

    context 'when the duo_workflow_extended_logging feature flag is disabled' do
      before do
        stub_feature_flags(duo_workflow_extended_logging: false)
      end

      context 'without a namespace' do
        it { is_expected.to be(false) }
      end

      context 'with a namespace that has ai_usage_data_collection_enabled' do
        let_it_be_with_reload(:namespace) { create(:group) }

        context 'when ai_usage_data_collection_enabled is true' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: true)
          end

          it { is_expected.to be(true) }
        end

        context 'when ai_usage_data_collection_enabled is false' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: false)
          end

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '.metadata' do
    it 'returns workflow related user metadata' do
      stub_feature_flags(duo_workflow_extended_logging: false)

      expect(described_class.metadata(user)).to eq(
        { extended_logging: false, is_team_member: nil, tool_approval_for_session_enabled: false,
          rootNamespaceId: nil }
      )
    end

    context 'for rootNamespaceId' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }

      it 'returns the root namespace id when a root namespace is provided' do
        expect(described_class.metadata(user, namespace: root_group)[:rootNamespaceId]).to eq(root_group.id.to_s)
      end

      it 'returns the root namespace id when a subgroup is provided' do
        expect(described_class.metadata(user, namespace: subgroup)[:rootNamespaceId]).to eq(root_group.id.to_s)
      end

      it 'returns nil when namespace is nil' do
        expect(described_class.metadata(user, namespace: nil)[:rootNamespaceId]).to be_nil
      end
    end

    context 'for extended logging' do
      context 'with namespace context' do
        let_it_be_with_reload(:namespace) { create(:group) }

        context 'when namespace opt-in is enabled' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: true)
          end

          it 'returns true (namespace setting supersedes feature flag)' do
            stub_feature_flags(duo_workflow_extended_logging: false)

            expect(described_class.metadata(user, namespace: namespace)[:extended_logging]).to be(true)
          end
        end

        context 'when namespace opt-in is disabled' do
          before do
            namespace.update!(ai_usage_data_collection_enabled: false)
          end

          it 'returns true (feature flag supersedes namespace setting)' do
            stub_feature_flags(duo_workflow_extended_logging: true)

            expect(described_class.metadata(user, namespace: namespace)[:extended_logging]).to be(true)
          end
        end

        context 'when namespace is nil' do
          it 'returns false when feature flag is disabled' do
            stub_feature_flags(duo_workflow_extended_logging: false)

            expect(described_class.metadata(user, namespace: nil)[:extended_logging]).to be(false)
          end
        end
      end

      context 'without namespace context (feature flag fallback)' do
        context 'when duo_workflow_extended_logging feature flag is disabled' do
          before do
            stub_feature_flags(duo_workflow_extended_logging: false)
          end

          it 'returns false' do
            expect(described_class.metadata(user)[:extended_logging]).to be(false)
          end
        end

        context 'when duo_workflow_extended_logging feature flag is enabled' do
          before do
            stub_feature_flags(duo_workflow_extended_logging: true)
          end

          it 'returns true' do
            expect(described_class.metadata(user)[:extended_logging]).to be(true)
          end
        end
      end
    end

    context 'when user is nil' do
      it 'handles nil user and returns is_team_member: nil' do
        stub_saas_features(gitlab_com_subscriptions: true)
        stub_feature_flags(duo_workflow_extended_logging: false)

        expect(described_class.metadata(nil)).to include(is_team_member: nil)
      end
    end

    context 'for tool_approval_for_session_enabled' do
      let_it_be_with_reload(:namespace) { create(:group) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when namespace is provided and setting is enabled' do
        before do
          namespace.namespace_settings.update!(tool_approval_for_session_enabled: true)
        end

        it 'returns true' do
          expect(described_class.metadata(user, namespace: namespace)[:tool_approval_for_session_enabled]).to be(true)
        end
      end

      context 'when namespace is provided and setting is disabled' do
        before do
          namespace.namespace_settings.update!(tool_approval_for_session_enabled: false)
        end

        it 'returns false' do
          expect(described_class.metadata(user, namespace: namespace)[:tool_approval_for_session_enabled]).to be(false)
        end
      end

      context 'when namespace is nil' do
        it 'returns false' do
          expect(described_class.metadata(user, namespace: nil)[:tool_approval_for_session_enabled]).to be(false)
        end
      end

      context 'when subgroup namespace is passed with setting explicitly disabled' do
        let_it_be_with_reload(:root_group) { create(:group) }
        let_it_be_with_reload(:subgroup) { create(:group, parent: root_group) }

        before do
          root_group.namespace_settings.update!(tool_approval_for_session_enabled: true)
          subgroup.namespace_settings.update!(tool_approval_for_session_enabled: false)
        end

        it 'returns false (subgroup override respected)' do
          expect(described_class.metadata(user, namespace: subgroup)[:tool_approval_for_session_enabled]).to be(false)
        end
      end
    end

    context 'on a self-hosted Duo instance' do
      before do
        stub_application_setting(duo_agent_platform_service_url: 'localhost:50052')
      end

      context 'when enabled_instance_verbose_ai_logs setting is enabled' do
        before do
          stub_application_setting(enabled_instance_verbose_ai_logs: true)
        end

        it 'returns true' do
          expect(described_class.metadata(user)[:extended_logging]).to be(true)
        end
      end

      context 'when enabled_instance_verbose_ai_logs setting is disabled' do
        before do
          stub_application_setting(enabled_instance_verbose_ai_logs: false)
        end

        it 'returns false' do
          expect(described_class.metadata(user)[:extended_logging]).to be(false)
        end
      end
    end
  end
end
