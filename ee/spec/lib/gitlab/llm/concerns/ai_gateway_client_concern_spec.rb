# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Concerns::AiGatewayClientConcern, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) } # Root namespace
  let_it_be(:subgroup) { create(:group, parent: group) } # Non-root namespace
  let_it_be(:tracking_context) { { source: 'test' } }

  let(:ai_gateway_client_double) { instance_double(Gitlab::Llm::AiGateway::Client) }

  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Concerns::AiGatewayClientConcern

      def initialize(user, tracking_context, root_namespace_override = nil)
        @user = user
        @tracking_context = tracking_context
        @root_namespace_override = root_namespace_override
      end

      def inputs
        { input: 'test_input' }
      end

      # Override root_namespace when specified
      def root_namespace
        @root_namespace_override
      end

      def execute
        perform_ai_gateway_request!(user: @user, tracking_context: @tracking_context)
      end

      # Test helpers to access private methods
      def test_selected_feature_setting(user)
        selected_feature_setting(user)
      end

      def test_base_url_from_feature_setting(user)
        base_url_from_feature_setting(user)
      end

      def test_prompt_version_or_default(user)
        prompt_version_or_default(user)
      end

      private

      def unit_primitive_name
        'review_merge_request'
      end

      def prompt_name
        'review_merge_request'
      end
    end
  end

  before do
    allow(::Gitlab::Llm::PromptVersions).to receive(:version_for_prompt).and_return('^1.0.0')
    allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_gateway_client_double)
  end

  describe '#perform_ai_gateway_request!' do
    subject(:execute_request) { dummy_class.new(user, tracking_context).execute }

    context 'when handling responses' do
      let(:response) { instance_double(HTTParty::Response, body: body, success?: true) }

      before do
        allow(ai_gateway_client_double).to receive(:complete_prompt).and_return(response)
      end

      context 'when the response is a string' do
        let(:body) { %("completion") }

        it 'returns the string' do
          expect(execute_request).to eq("completion")
        end
      end

      context 'when the response is a hash' do
        let(:body) { %({"content":"completion"}) }

        it 'returns the content of the response' do
          expect(execute_request).to eq("completion")
        end
      end
    end

    context 'with no namespace or self-hosted feature setting' do
      it 'executes the ai gateway request with the default instance level feature setting' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'review_merge_request',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          timeout: Gitlab::AiGateway.timeout,
          model_metadata: {
            provider: 'gitlab',
            feature_setting: 'review_merge_request',
            identifier: nil
          }
        )

        execute_request
      end
    end

    context 'with self-hosted feature setting' do
      let!(:self_hosted_model) { create(:ai_self_hosted_model) }
      let!(:ai_feature_setting) do
        create(:ai_feature_setting,
          feature: 'review_merge_request',
          provider: :self_hosted,
          self_hosted_model: self_hosted_model)
      end

      it 'uses self-hosted configuration' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ai_feature_setting.base_url,
          prompt_name: 'review_merge_request',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          timeout: Gitlab::AiGateway.timeout,
          model_metadata: hash_including(:name)
        )

        execute_request
      end
    end

    context 'with vendored feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      it 'uses vendored configuration' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'review_merge_request',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          timeout: Gitlab::AiGateway.timeout,
          model_metadata: {
            provider: 'gitlab',
            identifier: nil,
            feature_setting: 'review_merge_request'
          }
        )

        execute_request
      end
    end

    context 'when instance is SAAS and namespace feature setting', :saas_gitlab_com_subscriptions do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :self_hosted)
      end

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'review_merge_request',
          offered_model_ref: 'claude_sonnet_3_7')
      end

      before_all do
        group.add_developer(user)
      end

      subject(:execute_request) { dummy_class.new(user, tracking_context, group).execute }

      it 'prioritizes namespace feature setting over standard feature setting' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'review_merge_request',
          inputs: { input: 'test_input' },
          prompt_version: '^1.0.0',
          timeout: Gitlab::AiGateway.timeout,
          model_metadata: hash_including(
            feature_setting: 'review_merge_request',
            identifier: 'claude_sonnet_3_7',
            provider: 'gitlab'
          )
        )

        execute_request
      end
    end

    context 'with overridden prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      subject(:execute_request) { dummy_class_with_version.new(user, tracking_context).execute }

      it 'uses the overridden prompt version' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'review_merge_request',
          inputs: { input: 'test_input' },
          prompt_version: '2.1.0',
          timeout: Gitlab::AiGateway.timeout,
          model_metadata: {
            provider: 'gitlab',
            identifier: nil,
            feature_setting: 'review_merge_request'
          }
        )

        execute_request
      end

      context 'when feature setting is self-hosted' do
        let!(:ai_feature_setting) do
          create(:ai_feature_setting, feature: 'review_merge_request', provider: :self_hosted)
        end

        it 'uses default prompt version for self-hosted (ignores override)' do
          expect(ai_gateway_client_double).to receive(:complete_prompt).with(
            base_url: ai_feature_setting.base_url,
            prompt_name: 'review_merge_request',
            inputs: { input: 'test_input' },
            prompt_version: '^1.0.0',
            timeout: Gitlab::AiGateway.timeout,
            model_metadata: hash_including(:name)
          )

          execute_request
        end
      end
    end

    context 'with overridden ai_gateway_timeout' do
      let(:dummy_class_with_timeout) do
        Class.new(dummy_class) do
          def ai_gateway_timeout
            120.seconds
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      subject(:execute_request) { dummy_class_with_timeout.new(user, tracking_context).execute }

      it 'passes the overridden timeout to complete_prompt' do
        expect(ai_gateway_client_double).to receive(:complete_prompt).with(
          hash_including(timeout: 120.seconds)
        )

        execute_request
      end
    end
  end

  describe '#ai_gateway_timeout' do
    subject(:instance) { dummy_class.new(user, tracking_context) }

    it 'returns the global AI Gateway timeout by default' do
      expect(instance.send(:ai_gateway_timeout)).to eq(Gitlab::AiGateway.timeout)
    end
  end

  describe '#namespace_feature_setting', :saas_gitlab_com_subscriptions do
    subject(:instance) { dummy_class.new(user, tracking_context, group) }

    context 'when namespace feature setting exists' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'review_merge_request',
          offered_model_ref: 'claude_sonnet_3_7')
      end

      before_all do
        group.add_developer(user)
      end

      it 'returns the namespace feature setting' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to eq(namespace_feature_setting)
        expect(result.feature).to eq('review_merge_request')
        expect(result.offered_model_ref).to eq('claude_sonnet_3_7')
      end
    end

    context 'when no namespace feature setting exists' do
      before_all do
        group.add_developer(user)
      end

      it 'initializes a NamespaceFeatureSetting with review_merge_request feature' do
        result = instance.test_selected_feature_setting(user)

        expect(result).to be_a(Ai::ModelSelection::NamespaceFeatureSetting)
        expect(result.feature).to eq("review_merge_request")
      end
    end

    context 'when root_namespace is nil' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      it 'returns nil' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to be_nil
      end
    end

    context 'when namespace is not a root namespace' do
      subject(:instance) { dummy_class.new(user, tracking_context, subgroup) }

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'review_merge_request',
          offered_model_ref: 'claude_sonnet_3_7')
      end

      it 'returns nil' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to be_nil
      end
    end
  end

  describe '#selected_feature_setting' do
    let!(:ai_feature_setting) do
      create(:ai_feature_setting, feature: 'review_merge_request', provider: :self_hosted)
    end

    context 'when user is nil' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      it 'returns nil' do
        result = instance.test_selected_feature_setting(nil)
        expect(result).to be_nil
      end
    end

    context 'when instance is SAAS and a namespace feature setting exists', :saas_gitlab_com_subscriptions do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'review_merge_request',
          offered_model_ref: 'claude_sonnet_3_7')
      end

      before_all do
        group.add_developer(user)
      end

      subject(:instance) { dummy_class.new(user, tracking_context, group) }

      it 'returns namespace feature setting (priority)' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to eq(namespace_feature_setting)
        expect(result).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
      end
    end

    context 'when only standard feature setting exists' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      it 'returns standard feature setting' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to eq(ai_feature_setting)
        expect(result).to be_a(::Ai::FeatureSetting)
      end
    end

    context 'when no feature settings exist' do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      before do
        ai_feature_setting.destroy!
      end

      it 'returns the default instance level feature setting' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to be_a(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
        expect(result.feature).to eq('review_merge_request')
        expect(result.offered_model_ref).to be_nil
      end

      context 'when instance level model selection feature setting exists' do
        let!(:instance_model_selection_feature_setting) do
          create(:instance_model_selection_feature_setting,
            feature: 'review_merge_request',
            offered_model_ref: 'claude-3-7-sonnet-20250219')
        end

        it 'returns the instance level model selection feature setting' do
          result = instance.test_selected_feature_setting(user)
          expect(result).to eq(instance_model_selection_feature_setting)
        end
      end
    end

    context 'when service returns an error', :saas_gitlab_com_subscriptions do
      subject(:instance) { dummy_class.new(user, tracking_context, nil) }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(nil)
        allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group).and_return(true)
      end

      it 'returns nil when service result is not successful' do
        result = instance.test_selected_feature_setting(user)
        expect(result).to be_nil
      end
    end
  end

  describe '#base_url_from_feature_setting' do
    subject(:instance) { dummy_class.new(user, tracking_context, nil) }

    context 'with self-hosted feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :self_hosted)
      end

      it 'returns the base_url from feature setting' do
        result = instance.test_base_url_from_feature_setting(user)
        expect(result).to eq(ai_feature_setting.base_url)
      end
    end

    context 'with vendored feature setting' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      it 'returns default GitLab AiGateway URL' do
        result = instance.test_base_url_from_feature_setting(user)
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end

    context 'when instance is SAAS with namespace feature setting', :saas_gitlab_com_subscriptions do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'review_merge_request',
          offered_model_ref: 'claude_sonnet_3_7')
      end

      subject(:instance) { dummy_class.new(user, tracking_context, group) }

      it 'returns default GitLab AiGateway URL (namespace settings have no base_url)' do
        result = instance.test_base_url_from_feature_setting(user)
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end

    context 'when no feature setting exists' do
      it 'returns default GitLab AiGateway URL' do
        result = instance.test_base_url_from_feature_setting(user)
        expect(result).to eq(::Gitlab::AiGateway.url)
      end
    end
  end

  describe '#prompt_version_or_default' do
    subject(:instance) { dummy_class.new(user, tracking_context, nil) }

    context 'with vendored feature setting and custom prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      subject(:instance) { dummy_class_with_version.new(user, tracking_context, nil) }

      it 'returns the custom prompt version' do
        result = instance.test_prompt_version_or_default(user)
        expect(result).to eq('2.1.0')
      end
    end

    context 'with self-hosted feature setting and custom prompt version' do
      let(:dummy_class_with_version) do
        Class.new(dummy_class) do
          def prompt_version
            '2.1.0'
          end
        end
      end

      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :self_hosted)
      end

      subject(:instance) { dummy_class_with_version.new(user, tracking_context, nil) }

      it 'returns the default version (ignores custom for self-hosted)' do
        result = instance.test_prompt_version_or_default(user)
        expect(result).to eq('^1.0.0')
      end
    end

    context 'with no custom prompt version' do
      let!(:ai_feature_setting) do
        create(:ai_feature_setting, feature: 'review_merge_request', provider: :vendored)
      end

      it 'returns the default version' do
        result = instance.test_prompt_version_or_default(user)
        expect(result).to eq('^1.0.0')
      end
    end
  end

  describe 'method implementations' do
    let(:incomplete_class) do
      Class.new do
        include Gitlab::Llm::Concerns::AiGatewayClientConcern

        def initialize(user, tracking_context)
          @user = user
          @tracking_context = tracking_context
        end

        def execute
          perform_ai_gateway_request!(user: @user, tracking_context: @tracking_context)
        end
      end
    end

    [:unit_primitive_name, :prompt_name, :inputs].each do |method|
      it "raises NotImplementedError when #{method} is not implemented" do
        expect { incomplete_class.new(user, tracking_context).execute }.to raise_error(NotImplementedError)
      end
    end

    context 'when all required methods are implemented' do
      let(:complete_class) do
        Class.new(incomplete_class) do
          def inputs
            { input: 'test' }
          end

          private

          def unit_primitive_name
            'test_up'
          end

          def prompt_name
            'test_prompt'
          end
        end
      end

      it 'does not raise NotImplementedError' do
        expect(ai_gateway_client_double).to receive(:complete_prompt)

        expect { complete_class.new(user, tracking_context).execute }.not_to raise_error
      end
    end
  end

  describe 'default method implementations' do
    subject(:instance) { dummy_class.new(user, tracking_context) }

    describe '#root_namespace' do
      it 'returns nil by default' do
        expect(instance.root_namespace).to be_nil
      end
    end

    describe '#project_id' do
      it 'returns nil by default' do
        expect(instance.project_id).to be_nil
      end
    end

    describe '#namespace_id' do
      it 'returns nil by default' do
        expect(instance.namespace_id).to be_nil
      end
    end
  end

  describe 'context fields forwarded to AiGateway::Client' do
    let(:dummy_class_with_context) do
      Class.new(dummy_class) do
        def project_id
          42
        end

        def namespace_id
          7
        end
      end
    end

    subject(:execute_request) { dummy_class_with_context.new(user, tracking_context, group).execute }

    before do
      allow(ai_gateway_client_double).to receive(:complete_prompt)
    end

    it 'passes namespace_id, project_id, and governing_namespace_id to AiGateway::Client' do
      execute_request

      expect(Gitlab::Llm::AiGateway::Client).to have_received(:new).with(
        user,
        hash_including(
          namespace_id: 7,
          project_id: 42,
          governing_namespace_id: group.id
        )
      )
    end
  end

  describe 'when instance is SAAS with strong memoization', :saas_gitlab_com_subscriptions do
    subject(:instance) { dummy_class.new(user, tracking_context, group) }

    let!(:namespace_feature_setting) do
      create(:ai_namespace_feature_setting,
        namespace: group,
        feature: 'review_merge_request',
        offered_model_ref: 'claude_sonnet_3_7')
    end

    before_all do
      group.add_developer(user)
    end

    it 'memoizes selected_feature_setting' do
      # selected_feature_setting calls namespace_feature_setting internally
      expect(::Ai::ModelSelection::NamespaceFeatureSetting)
        .to receive(:find_or_initialize_by_feature).once.and_call_original

      # Call multiple times
      instance.test_selected_feature_setting(user)
      instance.test_selected_feature_setting(user)
    end
  end
end
