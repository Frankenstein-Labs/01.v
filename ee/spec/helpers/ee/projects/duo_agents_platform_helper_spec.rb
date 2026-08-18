# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::DuoAgentsPlatformHelper, feature_category: :duo_agent_platform do
  include Rails.application.routes.url_helpers
  include Devise::Test::ControllerHelpers

  let_it_be(:group) { build_stubbed(:group, name: 'Test Group') }
  let_it_be(:project) { build_stubbed(:project, name: 'Test Project', group: group) }
  let_it_be(:user) { build_stubbed(:user) }

  shared_examples 'returns duo settings data for group admin' do
    before do
      allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(true)
    end

    it 'returns duo_settings_path and duo_settings_root_ancestor_name' do
      expect(helper_data).to include(
        duo_settings_path: group.duo_settings_path,
        duo_settings_root_ancestor_name: "Test Group"
      )
    end
  end

  before do
    helper.instance_variable_set(:@project, project)
    allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(true)
    allow(helper).to receive(:current_user).and_return(user)

    allow(group).to receive_messages(
      duo_custom_agents_enabled: true,
      duo_custom_flows_enabled: true,
      duo_external_agents_enabled: true
    )
  end

  describe '#duo_agents_platform_data' do
    subject(:helper_data) { helper.duo_agents_platform_data(project) }

    before do
      allow(helper).to receive(:project_automate_path).with(project).and_return('/test-project/-/automate')
      allow(helper).to receive(:project_analytics_dashboards_path)
                         .with(project, vueroute: 'duo_and_sdlc_trends')
                         .and_return('/test-project/-/analytics/dashboards/duo_and_sdlc_trends')

      # Mock DuoChat to return credits available by default
      allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
        allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
      end

      allow(::Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?).with(user).and_return(true)
    end

    it 'returns the expected data hash', :aggregate_failures do
      expected_data = {
        agents_platform_base_route: '/test-project/-/automate',
        root_group_id: project.root_namespace.id,
        project_path: project.full_path,
        project_id: project.id,
        explore_ai_catalog_agents_path: '/explore/ai-catalog/agents',
        explore_ai_catalog_flows_path: '/explore/ai-catalog/flows',
        ai_impact_dashboard_enabled: 'true',
        credits_available: 'true',
        usage_billing_forbidden: 'false',
        instance_beta_features_enabled: 'true',
        ai_impact_dashboard_path: '/test-project/-/analytics/dashboards/duo_and_sdlc_trends',
        duo_custom_agents_enabled: 'true',
        duo_custom_flows_enabled: 'true',
        duo_external_agents_enabled: 'true',
        duo_settings_path: nil,
        duo_settings_root_ancestor_name: "Test Group",
        user_timezone: nil
      }

      expect(helper_data.except(:timezone_data)).to eq(expected_data)
      expect(helper_data[:timezone_data]).to eq(helper.timezone_data_with_unique_identifiers.to_json)
    end

    it_behaves_like 'returns duo settings data for group admin'

    context 'when beta features are disabled' do
      before do
        allow(::Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?).with(user).and_return(false)
      end

      it 'returns instance_beta_features_enabled as false' do
        expect(helper_data).to include(instance_beta_features_enabled: 'false')
      end
    end

    context 'when project is personal' do
      let_it_be(:project) { build_stubbed(:project, :in_user_namespace) }

      it 'returns root_group_id as nil and correct duo settings fields' do
        expect(helper_data).to include(
          root_group_id: nil,
          project_id: project.id,
          project_path: project.full_path,
          duo_settings_path: nil,
          duo_settings_root_ancestor_name: project.root_ancestor.name
        )
      end
    end

    context 'when AI impact dashboard is not available' do
      before do
        allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(false)
      end

      it 'returns ai_impact_dashboard_enabled as false and ai_impact_dashboard_path as nil' do
        expect(helper_data).to include(
          ai_impact_dashboard_enabled: 'false',
          ai_impact_dashboard_path: nil
        )
      end
    end
  end

  describe '#duo_agents_group_data' do
    subject(:helper_data) { helper.duo_agents_group_data(group) }

    before do
      allow(helper).to receive(:group_automate_path).with(group).and_return('/test-group/-/automate')
      allow(helper).to receive(:group_analytics_dashboards_path)
                         .with(group, vueroute: 'duo_and_sdlc_trends')
                         .and_return('/groups/test_group/-/analytics/dashboards/duo_and_sdlc_trends')

      # Mock DuoChat to return credits available by default
      allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
        allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
      end

      allow(::Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?).with(user).and_return(true)
    end

    it 'returns the expected data hash', :aggregate_failures do
      expected_data = {
        agents_platform_base_route: '/test-group/-/automate',
        group_path: group.full_path,
        group_id: group.id,
        explore_ai_catalog_agents_path: '/explore/ai-catalog/agents',
        explore_ai_catalog_flows_path: '/explore/ai-catalog/flows',
        ai_impact_dashboard_enabled: 'true',
        credits_available: 'true',
        usage_billing_forbidden: 'false',
        instance_beta_features_enabled: 'true',
        ai_impact_dashboard_path: '/groups/test_group/-/analytics/dashboards/duo_and_sdlc_trends',
        duo_custom_agents_enabled: 'true',
        duo_custom_flows_enabled: 'true',
        duo_external_agents_enabled: 'true',
        duo_settings_path: nil,
        duo_settings_root_ancestor_name: "Test Group"
      }

      expect(helper_data).to eq(expected_data)
    end

    it 'omits schedule trigger data, which groups do not expose' do
      expect(helper_data.keys).not_to include(:timezone_data, :user_timezone)
    end

    it_behaves_like 'returns duo settings data for group admin'

    context 'when beta features are disabled' do
      before do
        allow(::Ai::Catalog).to receive(:user_can_access_experimental_and_beta_features?).with(user).and_return(false)
      end

      it 'returns instance_beta_features_enabled as false' do
        expect(helper_data).to include(instance_beta_features_enabled: 'false')
      end
    end

    context 'when AI impact dashboard is not available' do
      before do
        allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(false)
      end

      it 'returns ai_impact_dashboard_enabled as false and ai_impact_dashboard_path as nil' do
        expect(helper_data).to include(
          ai_impact_dashboard_enabled: 'false',
          ai_impact_dashboard_path: nil
        )
      end
    end
  end

  describe '#dap_identity_verification_required?' do
    subject(:dap_identity_verification_required) { helper.dap_identity_verification_required?(group) }

    before do
      allow(user).to receive(:dap_identity_verification_required?).with(group).and_return(true)
    end

    it { is_expected.to be(true) }

    context 'when there is no current user' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#duo_agents_platform_identity_verification_data' do
    subject(:iv_data) { helper.duo_agents_platform_identity_verification_data(group) }

    before do
      allow(user).to receive(:dap_identity_verification_required?).with(group).and_return(required)
    end

    context 'when verification is required' do
      let(:required) { true }

      it 'returns the required flag and the verification path' do
        expect(iv_data).to eq(
          identity_verification_required: 'true',
          identity_verification_path: helper.identity_verification_path
        )
      end
    end

    context 'when verification is not required' do
      let(:required) { false }

      it { expect(iv_data).to include(identity_verification_required: 'false') }
    end

    context 'when there is no current user' do
      let(:required) { true }

      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { expect(iv_data).to include(identity_verification_required: 'false') }
    end
  end

  describe '#credits_available?' do
    context 'when container is a Project' do
      it 'returns true when DuoChat has credits available' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:credits_available?).and_return(true)
        end

        expect(helper.send(:credits_available?, project)).to be true
      end

      it 'returns false when DuoChat has no credits available' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:credits_available?).and_return(false)
        end

        expect(helper.send(:credits_available?, project)).to be false
      end
    end

    context 'when container is a Group' do
      it 'returns true when DuoChat has credits available' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:credits_available?).and_return(true)
        end

        expect(helper.send(:credits_available?, group)).to be true
      end

      it 'returns false when DuoChat has no credits available' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:credits_available?).and_return(false)
        end

        expect(helper.send(:credits_available?, group)).to be false
      end
    end
  end

  describe '#duo_chat_for' do
    it 'creates separate instances for different containers' do
      expect(::Gitlab::Llm::DuoChat).to receive(:new).twice.and_call_original

      helper.send(:duo_chat_for, project)
      helper.send(:duo_chat_for, group)
    end
  end

  describe '#usage_billing_forbidden?' do
    context 'when container is a Project' do
      it 'returns true when DuoChat billing is forbidden' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:usage_billing_forbidden?).and_return(true)
        end

        expect(helper.send(:usage_billing_forbidden?, project)).to be true
      end

      it 'returns false when DuoChat billing is not forbidden' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:usage_billing_forbidden?).and_return(false)
        end

        expect(helper.send(:usage_billing_forbidden?, project)).to be false
      end
    end

    context 'when container is a Group' do
      it 'returns true when DuoChat billing is forbidden' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:usage_billing_forbidden?).and_return(true)
        end

        expect(helper.send(:usage_billing_forbidden?, group)).to be true
      end

      it 'returns false when DuoChat billing is not forbidden' do
        allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
          allow(instance).to receive(:usage_billing_forbidden?).and_return(false)
        end

        expect(helper.send(:usage_billing_forbidden?, group)).to be false
      end
    end
  end
end
