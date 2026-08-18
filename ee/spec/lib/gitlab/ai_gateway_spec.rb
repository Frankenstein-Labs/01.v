# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::AiGateway, feature_category: :system_access do
  let(:url) { 'http://ai-gateway.example.com:5052' }
  let(:namespace_ids) { [1, 2, 3] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response, namespace_ids: namespace_ids, enablement_type: enablement_type)
  end

  describe '.url' do
    context 'when ai_gateway_url setting is set' do
      before do
        stub_application_setting(ai_gateway_url: url)
      end

      it 'returns the setting value' do
        expect(described_class.url).to eq(url)
      end
    end

    context 'when ai_gateway_url setting is not set' do
      before do
        stub_application_setting(ai_gateway_url: nil)
      end

      context 'when DEVELOPMENT_AI_GATEWAY_URL is set' do
        before do
          stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://dev-gateway.com')
        end

        it 'returns the development url via cloud_connector_url' do
          expect(described_class.url).to eq('http://dev-gateway.com')
        end
      end

      context 'when DEVELOPMENT_AI_GATEWAY_URL is set with a trailing slash' do
        before do
          stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://dev-gateway.com/')
        end

        it 'returns the development url without trailing slash' do
          expect(described_class.url).to eq('http://dev-gateway.com')
        end
      end

      context 'when DEVELOPMENT_AI_GATEWAY_URL is not set' do
        before do
          stub_env('DEVELOPMENT_AI_GATEWAY_URL', nil)
          allow(::CloudConnector::Config).to receive(:base_url).and_return(url)
        end

        it 'returns the cloud connector url' do
          expect(described_class.url).to eq("#{url}/ai")
        end
      end
    end
  end

  describe '.cloud_connector_url' do
    let(:url) { 'http://example.com' }

    context 'when DEVELOPMENT_AI_GATEWAY_URL is set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://dev-gateway.com')
      end

      it 'returns the development url' do
        expect(described_class.cloud_connector_url).to eq('http://dev-gateway.com')
      end
    end

    context 'when DEVELOPMENT_AI_GATEWAY_URL is not set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', nil)
      end

      it 'returns the cloud connector url' do
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

        expect(described_class.cloud_connector_url).to eq("#{url}/ai")
      end
    end
  end

  describe '.self_hosted_url' do
    context 'when ai_gateway_url setting is set' do
      it 'returns the setting value' do
        stub_application_setting(ai_gateway_url: url)

        expect(described_class.self_hosted_url).to eq(url)
      end
    end

    context 'when ai_gateway_url setting has a trailing slash' do
      it 'returns the url without trailing slash' do
        stub_application_setting(ai_gateway_url: "#{url}/")

        expect(described_class.self_hosted_url).to eq(url)
      end
    end

    context 'when ai_gateway_url setting is not set' do
      it 'returns nil' do
        stub_application_setting(ai_gateway_url: nil)

        expect(described_class.self_hosted_url).to be_nil
      end
    end
  end

  describe '.timeout' do
    context 'when ai_gateway_timeout_seconds is set' do
      it 'returns the configured timeout in seconds' do
        stub_application_setting(ai_gateway_timeout_seconds: 120)

        expect(described_class.timeout).to eq(120.seconds)
      end
    end

    context 'when ai_gateway_timeout_seconds is not set' do
      it 'returns the default timeout of 60 seconds' do
        stub_application_setting(ai_gateway_timeout_seconds: nil)

        expect(described_class.timeout).to eq(60.seconds)
      end
    end
  end

  describe '.has_self_hosted_ai_gateway?' do
    subject(:has_self_hosted_ai_gateway) { described_class.has_self_hosted_ai_gateway? }

    context 'when AI Gateway url is set' do
      before do
        stub_application_setting(ai_gateway_url: url)
      end

      it { is_expected.to be(true) }
    end

    context  'when AI Gateway url is not set' do
      before do
        stub_application_setting(ai_gateway_url: nil)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.access_token_url' do
    before do
      stub_application_setting(ai_gateway_url: 'http://local-aigw:5052')
      allow(::CloudConnector::Config).to receive(:base_url).and_return(url)
    end

    let(:cloud_connector_auth_full_url) { "#{url}/auth/v1/code/user_access_token" }
    let(:self_hosted_auth_full_url) { "http://local-aigw:5052/v1/code/user_access_token" }

    context 'when no code_completions_feature_setting is provided' do
      it 'returns the cloud connector auth url' do
        expect(described_class.access_token_url(nil)).to eq(self_hosted_auth_full_url)
      end
    end

    context 'when code_completions_feature_setting is not vendored' do
      it 'returns the self hosted auth url' do
        feature_setting = create(:ai_feature_setting, :code_completions, provider: :self_hosted)

        expect(described_class.access_token_url(feature_setting)).to eq(self_hosted_auth_full_url)
      end
    end

    context 'when code_completions_feature_setting is vendored' do
      it 'returns the cloud connector auth url' do
        feature_setting = create(:ai_feature_setting, :code_completions, provider: :vendored)

        expect(described_class.access_token_url(feature_setting)).to eq(cloud_connector_auth_full_url)
      end
    end
  end

  describe '.cloud_connector_auth_url' do
    context 'when DEVELOPMENT_AI_GATEWAY_URL is set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://dev-gateway.com')
      end

      it 'returns the development url' do
        expect(described_class.cloud_connector_auth_url).to eq('http://dev-gateway.com')
      end
    end

    context 'when DEVELOPMENT_AI_GATEWAY_URL is not set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', nil)
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)
      end

      it 'returns the cloud connector auth url' do
        expect(described_class.cloud_connector_auth_url).to eq("#{url}/auth")
      end
    end
  end

  describe '.push_feature_flag', :request_store do
    before do
      allow(::Feature).to receive(:enabled?).and_return(true)
    end

    context 'when expanded_ai_logging feature flag on self-managed instance' do
      it 'does not push the feature flag' do
        described_class.push_feature_flag('expanded_ai_logging')

        expect(described_class.enabled_feature_flags).to be_empty
      end
    end

    context 'when expanded_ai_logging feature flag on GitLab.com', :saas do
      it 'pushes the feature flag' do
        described_class.push_feature_flag('expanded_ai_logging')

        expect(described_class.enabled_feature_flags).to contain_exactly('expanded_ai_logging')
      end
    end

    it 'push feature flag' do
      described_class.push_feature_flag("feature_a")
      described_class.push_feature_flag("feature_b")
      described_class.push_feature_flag("feature_c")

      expect(described_class.enabled_feature_flags).to match_array(%w[feature_a feature_b feature_c])
    end
  end

  describe '.expanded_ai_logging_on_self_managed?' do
    subject { described_class.expanded_ai_logging_on_self_managed?(feature_name) }

    context 'when feature name is expanded_ai_logging' do
      let(:feature_name) { :expanded_ai_logging }

      context 'when instance is self-managed' do
        it { is_expected.to be true }
      end

      context 'when instance is GitLab.com', :saas do
        it { is_expected.to be false }
      end
    end

    context 'when feature name is not expanded_ai_logging' do
      let(:feature_name) { :some_other_feature }

      context 'when instance is self-managed' do
        it { is_expected.to be false }
      end

      context 'when instance is GitLab.com', :saas do
        it { is_expected.to be false }
      end
    end
  end

  describe '.enabled_feature_flags', :request_store do
    it 'returns empty' do
      expect(described_class.enabled_feature_flags).to eq([])
    end
  end

  describe '.headers', :request_store do
    let(:user) { build(:user, id: 1) }
    let(:token) { 'instance token' }
    let(:ai_feature) { :test_feature }
    let(:unit_primitive_name) { :test_feature_up }
    let(:agent) { nil }
    let(:lsp_version) { nil }
    let(:standard_context) { instance_double(::Gitlab::Tracking::StandardContext) }
    let(:enabled_instance_verbose_ai_logs) { false }
    let(:is_team_member) { false }
    let(:feature_setting) { nil }
    let(:cloud_connector_headers) do
      {
        'x-gitlab-host-name' => 'hostname',
        'x-gitlab-instance-id' => 'ABCDEF',
        'x-gitlab-global-user-id' => '123ABC',
        'x-gitlab-user-id' => '123',
        'x-gitlab-realm' => 'self-managed',
        'x-gitlab-deployment-type' => 'self-managed',
        'x-gitlab-bersion' => '17.1.0',
        'x-gitlab-feature-enabled-by-namespace-ids' => namespace_ids.join(','),
        'x-gitlab-subject-type' => 'human'
      }
    end

    let(:expected_headers) do
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{token}",
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-unit-primitive' => unit_primitive_name.to_s,
        'x-gitlab-feature-enabled-by-namespace-ids' => namespace_ids.join(','),
        'Content-Type' => 'application/json',
        'X-Gitlab-Is-Team-Member' => is_team_member.to_s,
        'X-Request-ID' => an_instance_of(String),
        'X-Gitlab-Rails-Send-Start' => an_instance_of(String),
        'x-gitlab-enabled-feature-flags' => an_instance_of(String),
        'X-Gitlab-Client-Type' => 'ide',
        'X-Gitlab-Client-Version' => '1.0',
        'X-Gitlab-Client-Name' => 'gitlab-extension',
        'X-Gitlab-Interface' => 'vscode',
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'false',
        'x-gitlab-subject-type' => 'human'
      }.merge(cloud_connector_headers)
    end

    subject(:headers) do
      described_class.headers(
        user: user, unit_primitive_name: unit_primitive_name, ai_feature_name: ai_feature,
        agent: agent, lsp_version: lsp_version, feature_setting: feature_setting
      )
    end

    before do
      stub_application_setting(enabled_instance_verbose_ai_logs: enabled_instance_verbose_ai_logs)

      allow(::CloudConnector::Tokens).to receive(:get)
        .with(
          unit_primitive: unit_primitive_name,
          resource: user,
          feature_setting: feature_setting,
          extra_claims: { skip_usage_cutoff: is_team_member })
        .and_return(token)
      allow(user).to receive(:allowed_to_use)
        .with(ai_feature, unit_primitive_name: unit_primitive_name, feature_setting: nil)
        .and_return(auth_response)
      allow(Namespace).to receive(:root_ids_for).with(namespace_ids).and_return(namespace_ids)
      allow(::CloudConnector).to(
        receive(:ai_headers).with(user, namespace_ids: namespace_ids, subject: user).and_return(cloud_connector_headers)
      )
      allow(::Gitlab::Tracking::StandardContext).to receive(:new).and_return(standard_context)
      allow(standard_context).to receive(:gitlab_team_member?).with(user&.id).and_return(is_team_member)

      described_class.current_context[:x_gitlab_client_type] = 'ide'
      described_class.current_context[:x_gitlab_client_version] = '1.0'
      described_class.current_context[:x_gitlab_client_name] = 'gitlab-extension'
      described_class.current_context[:x_gitlab_interface] = 'vscode'
    end

    it { is_expected.to match(expected_headers) }

    context 'when unit_primitive_name supplied as a String, not Symbol' do
      subject(:headers) do
        described_class.headers(
          user: user, unit_primitive_name: unit_primitive_name.to_s, ai_feature_name: ai_feature,
          agent: agent, lsp_version: lsp_version, feature_setting: feature_setting
        )
      end

      it { is_expected.to match(expected_headers) }
    end

    context 'when agent is set' do
      let(:agent) { 'user agent' }

      it { is_expected.to match(expected_headers.merge('User-Agent' => agent)) }
    end

    context 'when lsp_version is set' do
      let(:lsp_version) { '4.21.0' }

      it { is_expected.to match(expected_headers.merge('X-Gitlab-Language-Server-Version' => lsp_version)) }
    end

    context 'when x_gitlab_tracking_context is set in the current context' do
      let(:tracking_context) { '{"distribution":"npm","execution_environment":"CI"}' }

      before do
        described_class.current_context[:x_gitlab_tracking_context] = tracking_context
      end

      it 'forwards the tracking context header' do
        expect(headers).to include('X-Gitlab-Tracking-Context' => tracking_context)
      end
    end

    context 'when Langsmith is enabled' do
      before do
        allow(Langsmith::RunHelpers).to receive(:enabled?).and_return(true)
        allow(Langsmith::RunHelpers).to receive(:to_headers).and_return({
          "langsmith-trace" => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        })
      end

      it 'includes langsmith header' do
        expect(headers).to include(
          'langsmith-trace' => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        )
      end
    end

    context 'when verbose logs are enabled for instance' do
      let(:enabled_instance_verbose_ai_logs) { true }

      it 'updates the header' do
        expect(headers).to include('x-gitlab-enabled-instance-verbose-ai-logs' => "true")
      end
    end

    context 'when feature flag is pushed' do
      before do
        allow(described_class).to receive(:enabled_feature_flags).and_return(%w[feature_a feature_b])
      end

      it 'includes feature flag header' do
        expect(headers).to include(
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b'
        )
      end
    end

    context 'when there is no user' do
      let(:user) { nil }
      let(:namespace_ids) { [] }
      let(:enablement_type) { '' }

      it 'excludes the namespace headers and has an empty x-gitlab-feature-enabled-by-namespace-ids' do
        is_expected.to match(
          expected_headers.except('x-gitlab-namespace-id', 'x-gitlab-root-namespace-id')
          .merge('x-gitlab-feature-enabled-by-namespace-ids' => '')
        )
      end

      it 'sets the correct extra claims' do
        expect(::CloudConnector::Tokens).to receive(:get)
          .with(
            unit_primitive: unit_primitive_name,
            resource: user,
            extra_claims: { skip_usage_cutoff: false },
            feature_setting: nil
          )

        headers
      end
    end

    context 'when a feature setting is passed' do
      let(:feature_setting) { create(:ai_feature_setting, :code_completions, provider: :self_hosted) }

      it 'adds the given feature setting to the token request' do
        expect(::CloudConnector::Tokens).to receive(:get)
          .with(
            unit_primitive: unit_primitive_name,
            resource: user,
            extra_claims: { skip_usage_cutoff: false },
            feature_setting: feature_setting
          )

        headers
      end

      it { is_expected.to match(expected_headers) }
    end

    context 'when user is a GitLab team member' do
      let(:is_team_member) { true }

      it { is_expected.to match(expected_headers) }

      it 'adds extra claims to the cloud connector token' do
        expect(::CloudConnector::Tokens).to receive(:get)
          .with(unit_primitive: unit_primitive_name,
            resource: user,
            extra_claims: { skip_usage_cutoff: true },
            feature_setting: nil
          )

        headers
      end
    end

    context 'when on SaaS', :saas do
      context 'when governing_namespace_id is set' do
        subject(:headers) do
          described_class.headers(
            user: user, unit_primitive_name: unit_primitive_name, ai_feature_name: ai_feature,
            governing_namespace_id: 42, agent: agent, lsp_version: lsp_version, feature_setting: feature_setting
          )
        end

        it 'passes governing_namespace_id as root_namespace_id in extra claims' do
          expect(::CloudConnector::Tokens).to receive(:get)
            .with(
              unit_primitive: unit_primitive_name,
              resource: user,
              feature_setting: nil,
              extra_claims: { skip_usage_cutoff: false, gitlab_root_namespace_id: 42 }
            )
            .and_return(token)

          headers
        end
      end
    end
  end

  describe '.public_headers' do
    let(:user) { build(:user, id: 1) }
    let(:ai_feature) { :test_feature }
    let(:unit_primitive_name) { :test_feature_up }
    let(:namespace_id) { nil }
    let(:governing_namespace_id) { nil }
    let(:project_id) { nil }
    let(:organization_id) { nil }
    let(:enabled_feature_flags) { %w[feature_a feature_b] }
    let(:ai_headers) { { 'x-gitlab-feature-enabled-by-namespace-ids' => '', 'x-gitlab-subject-type' => 'human' } }
    let(:standard_context) { instance_double(::Gitlab::Tracking::StandardContext) }
    let(:is_team_member) { false }
    let(:feature_setting) { nil }

    subject(:public_headers) do
      described_class.public_headers(user: user, ai_feature_name: ai_feature, unit_primitive_name: unit_primitive_name,
        namespace_id: namespace_id, governing_namespace_id: governing_namespace_id, feature_setting: feature_setting,
        project_id: project_id, organization_id: organization_id)
    end

    before do
      stub_application_setting(enabled_instance_verbose_ai_logs: false)

      allow(user).to receive(:allowed_to_use)
        .with(ai_feature, unit_primitive_name: unit_primitive_name, feature_setting: nil)
        .and_return(auth_response)

      allow(described_class).to receive(:enabled_feature_flags)
        .and_return(enabled_feature_flags)

      allow(Namespace).to receive(:root_ids_for).with(namespace_ids).and_return(namespace_ids)

      allow(::CloudConnector).to receive(:ai_headers)
        .with(user, namespace_ids: namespace_ids, subject: user)
        .and_return(ai_headers)

      allow(::Gitlab::Tracking::StandardContext).to receive(:new).and_return(standard_context)
      allow(standard_context).to receive(:gitlab_team_member?).with(user&.id).and_return(is_team_member)
    end

    it 'returns headers with enabled feature flags and AI headers' do
      expected_headers = {
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-unit-primitive' => unit_primitive_name.to_s,
        'x-gitlab-feature-enabled-by-namespace-ids' => '',
        'x-gitlab-subject-type' => 'human',
        'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b',
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'false',
        'X-Gitlab-Is-Team-Member' => 'false'
      }

      expect(public_headers).to eq(expected_headers)
    end

    context 'when there are no enabled feature flags' do
      let(:enabled_feature_flags) { [] }

      it 'returns headers with empty feature flags string' do
        expected_headers = {
          'x-gitlab-feature-enablement-type' => enablement_type,
          'x-gitlab-unit-primitive' => unit_primitive_name.to_s,
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-subject-type' => 'human',
          'x-gitlab-enabled-feature-flags' => '',
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'false',
          'X-Gitlab-Is-Team-Member' => 'false'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end

    context 'when there are duplicate feature flags' do
      let(:enabled_feature_flags) { %w[feature_a feature_a feature_b] }

      it 'returns headers with unique feature flags' do
        expected_headers = {
          'x-gitlab-feature-enablement-type' => enablement_type,
          'x-gitlab-unit-primitive' => unit_primitive_name.to_s,
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-subject-type' => 'human',
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b',
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'false',
          'X-Gitlab-Is-Team-Member' => 'false'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end

    context 'when user is a GitLab team member' do
      let(:is_team_member) { true }

      it 'returns headers with team member set to true' do
        expected_headers = {
          'x-gitlab-feature-enablement-type' => enablement_type,
          'x-gitlab-unit-primitive' => unit_primitive_name.to_s,
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-subject-type' => 'human',
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b',
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'false',
          'X-Gitlab-Is-Team-Member' => 'true'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end

    context 'with root namespace extraction' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let(:namespace_ids) { [subgroup.id] }

      before do
        allow(Namespace).to receive(:root_ids_for).and_call_original
        allow(::CloudConnector).to receive(:ai_headers)
          .with(user, namespace_ids: [root_group.id], subject: user)
          .and_return(ai_headers)
      end

      it 'extracts root namespace IDs and passes them to CloudConnector' do
        public_headers

        expect(::CloudConnector).to have_received(:ai_headers)
          .with(user, namespace_ids: [root_group.id], subject: user)
      end

      context 'with multiple namespaces from same hierarchy' do
        let_it_be(:subgroup_1) { create(:group, parent: root_group) }
        let_it_be(:subgroup_2) { create(:group, parent: root_group) }
        let(:namespace_ids) { [root_group.id, subgroup_1.id, subgroup_2.id] }

        before do
          allow(::CloudConnector).to receive(:ai_headers)
            .with(user, namespace_ids: [root_group.id], subject: user)
            .and_return(ai_headers)
        end

        it 'deduplicates and passes single root namespace ID to CloudConnector' do
          public_headers

          expect(::CloudConnector).to have_received(:ai_headers)
            .with(user, namespace_ids: [root_group.id], subject: user)
        end
      end
    end

    context 'when feature_setting is provided' do
      let_it_be(:model) { create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219') }
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :code_generations, self_hosted_model: model) }

      it 'passes feature_setting to user.allowed_to_use' do
        expect(user).to receive(:allowed_to_use)
          .with(ai_feature, unit_primitive_name: unit_primitive_name, feature_setting: feature_setting)
          .and_return(auth_response)

        public_headers
      end
    end

    context 'when building namespace headers' do
      context 'when governing_namespace_id is provided' do
        let(:namespace_id) { 2 }
        let(:governing_namespace_id) { 3 }

        it 'includes the namespace ids in the headers' do
          expect(public_headers).to include('x-gitlab-namespace-id' => '2', 'x-gitlab-root-namespace-id' => '3')
        end

        context 'when no namespace_id is provided' do
          let(:namespace_id) { nil }

          it "uses the governing_namespace_id as the namespace_id" do
            expect(public_headers).to include('x-gitlab-namespace-id' => '3', 'x-gitlab-root-namespace-id' => '3')
          end
        end
      end

      context 'when governing_namespace_id is not provided' do
        let(:namespace_id) { 4 }

        it 'does not include the namespace headers' do
          expect(public_headers).not_to have_key('x-gitlab-namespace-id')
          expect(public_headers).not_to have_key('x-gitlab-root-namespace-id')
        end
      end
    end

    context 'when project_id is provided' do
      let(:project_id) { 4 }

      it 'includes the project_id in the headers' do
        expect(public_headers).to include('x-gitlab-project-id' => '4')
      end
    end

    context 'with organization id header' do
      let(:organization_id) { 1 }

      it 'includes organization_id in the headers' do
        expect(public_headers).to include('x-gitlab-organization-id' => '1')
      end

      context 'when organization id is absent' do
        let(:organization_id) { nil }

        it 'does not include organization header' do
          expect(public_headers).not_to have_key('x-gitlab-organization-id')
        end
      end
    end
  end
end
