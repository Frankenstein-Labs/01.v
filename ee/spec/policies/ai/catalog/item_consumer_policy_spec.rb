# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group, developers: user) }

  shared_examples 'restricts all consumer permissions' do
    it { expect_disallowed(:execute_ai_catalog_item) }
    it { expect_disallowed(:read_ai_catalog_item_consumer) }
    it { expect_disallowed(:admin_ai_catalog_item_consumer) }
  end

  shared_examples 'allows all consumer permissions' do
    it { expect_allowed(:execute_ai_catalog_item) }
    it { expect_allowed(:read_ai_catalog_item_consumer) }
    it { expect_allowed(:admin_ai_catalog_item_consumer) }
  end

  shared_examples 'allows execute and read consumer permissions' do
    it { expect_allowed(:execute_ai_catalog_item) }
    it { expect_allowed(:read_ai_catalog_item_consumer) }
  end

  context 'when item consumer belongs to a project' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project: build_stubbed(:project)) }

    subject(:policy) { described_class.new(user, item_consumer) }

    it { is_expected.to delegate_to(::ProjectPolicy) }
  end

  context 'when item consumer belongs to a group' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, group: build_stubbed(:group)) }

    subject(:policy) { described_class.new(user, item_consumer) }

    it { is_expected.to delegate_to(::GroupPolicy) }
  end

  describe 'when item is a custom flow' do
    let_it_be(:flow_group) { create(:group) }
    let_it_be(:flow_project) { create(:project, group: flow_group, developers: user) }
    let_it_be(:flow_item) { create(:ai_catalog_flow, :with_released_version, project: flow_project) }
    let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: flow_project, item: flow_item) }

    let(:flows_available) { false }

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(flow_project, flows: flows_available)
    end

    context 'when StageCheck :ai_catalog_flows is false' do
      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when StageCheck :ai_catalog_flows is true' do
      let(:flows_available) { true }

      it_behaves_like 'allows execute and read consumer permissions'
    end

    describe 'when duo_custom_flows_enabled setting is toggled' do
      let(:flows_available) { true }
      let_it_be(:maintainer) { create(:user, maintainer_of: flow_project) }

      subject(:policy) { described_class.new(maintainer, item_consumer) }

      context 'when duo_custom_flows_enabled is true (default)' do
        it_behaves_like 'allows all consumer permissions'
      end

      context 'when duo_custom_flows_enabled is false' do
        before do
          item_consumer.root_ancestor.namespace_settings.update!(duo_custom_flows_enabled: false)
        end

        it_behaves_like 'restricts all consumer permissions'
      end
    end
  end

  describe 'when item is a third party flow' do
    let_it_be(:tp_group) { create(:group) }
    let_it_be(:tp_project) { create(:project, group: tp_group, developers: user) }
    let_it_be(:tp_item) { create(:ai_catalog_third_party_flow, :with_released_version, project: tp_project) }
    let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: tp_project, item: tp_item) }

    let(:third_party_flows_available) { false }

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(tp_project, third_party_flows: third_party_flows_available)
    end

    context 'when StageCheck :ai_catalog_third_party_flows is false' do
      it { expect_disallowed(:execute_ai_catalog_item) }
    end

    context 'when StageCheck :ai_catalog_third_party_flows is true' do
      let(:third_party_flows_available) { true }

      it_behaves_like 'allows execute and read consumer permissions'
    end

    describe 'when duo_external_agents_enabled setting is toggled' do
      let(:third_party_flows_available) { true }
      let_it_be(:maintainer) { create(:user, maintainer_of: tp_project) }

      subject(:policy) { described_class.new(maintainer, item_consumer) }

      context 'when duo_external_agents_enabled is true (default)' do
        it_behaves_like 'allows all consumer permissions'
      end

      context 'when duo_external_agents_enabled is false' do
        before do
          item_consumer.root_ancestor.namespace_settings.update!(duo_external_agents_enabled: false)
        end

        it_behaves_like 'restricts all consumer permissions'
      end
    end
  end

  describe 'when item is a beta foundational flow' do
    let_it_be(:beta_group, freeze: false) { create(:group) }
    let_it_be(:beta_project) { create(:project, group: beta_group, developers: user) }
    let_it_be(:beta_flow) do
      create(:ai_catalog_flow, :public, :with_released_version, project: beta_project,
        foundational_flow_reference: 'sast_fp_detection/v1')
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: beta_project, item: beta_flow)
    end

    let_it_be(:beta_flow_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: beta_project,
        catalog_item: beta_flow)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      # Stub beta? since no foundational flows are currently in beta.
      # This ensures the beta_foundational_flow condition is exercised.
      allow(::Ai::Catalog::FoundationalFlow).to receive(:beta?).with('sast_fp_detection/v1').and_return(true)
      stub_stage_checks(beta_project, foundational_flows: true)
      # sast_fp_detection is ultimate_only, so an Ultimate license is required for
      # the beta-feature gate to be the only variable under test.
      stub_licensed_features(ai_catalog: true, ai_features: true)
    end

    context 'when beta features are disabled on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        beta_group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when beta features are enabled on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        beta_group.namespace_settings.update!(experiment_features_enabled: true)
      end

      it { expect_allowed(:execute_ai_catalog_item) }
    end

    context 'when beta features are disabled on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_application_setting(instance_level_ai_beta_features_enabled: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when beta features are enabled on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_application_setting(instance_level_ai_beta_features_enabled: true)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when item consumer belongs to a group' do
      let_it_be(:group_consumer) do
        create(:ai_catalog_item_consumer, group: beta_group, item: beta_flow)
      end

      subject(:policy) { described_class.new(user, group_consumer) }

      before do
        stub_stage_checks(beta_group, foundational_flows: true)
        stub_saas_features(gitlab_com_subscriptions: true)
        beta_group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end
  end

  describe 'when item is a GA foundational flow' do
    let_it_be(:ga_group, freeze: false) { create(:group) }
    let_it_be_with_reload(:ga_project) { create(:project, group: ga_group, developers: user) }
    let_it_be(:ga_flow) do
      create(:ai_catalog_flow, :public, :with_released_version, project: ga_project,
        foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: ga_project, item: ga_flow)
    end

    let_it_be(:ga_flow_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: ga_project,
        catalog_item: ga_flow)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      ga_group.namespace_settings.update!(experiment_features_enabled: true)
      stub_stage_checks(ga_project, foundational_flows: true)
    end

    context 'when beta features are disabled on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        ga_group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when beta features are disabled on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_application_setting(instance_level_ai_beta_features_enabled: false)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        ga_project.update!(duo_foundational_flows_enabled: false)
      end

      it { expect_disallowed(:execute_ai_catalog_item) }
    end

    context 'when StageCheck returns false for foundational_flows' do
      before do
        stub_stage_checks(ga_project, foundational_flows: false)
      end

      it { expect_disallowed(:execute_ai_catalog_item) }
    end

    context 'when flow is not in the allow list' do
      before do
        ga_flow_enabled.destroy!
      end

      it { expect_disallowed(:execute_ai_catalog_item) }
    end
  end

  describe 'when item is an ultimate-only foundational flow' do
    let_it_be(:ultimate_flow) do
      create(:ai_catalog_flow, :public, :with_released_version, project: project,
        foundational_flow_reference: 'resolve_sast_vulnerability/v1')
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: project, item: ultimate_flow)
    end

    let_it_be(:ultimate_flow_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: project,
        catalog_item: ultimate_flow)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(project, foundational_flows: true)
    end

    context 'when namespace does not have an AI license' do
      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when namespace has only a Premium license' do
      before do
        stub_licensed_features(ai_catalog: true, ai_features: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when namespace has an Ultimate license' do
      before do
        stub_licensed_features(ai_features: true)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when item consumer belongs to a group without license' do
      let_it_be(:group_consumer) do
        create(:ai_catalog_item_consumer, group: group, item: ultimate_flow)
      end

      subject(:policy) { described_class.new(user, group_consumer) }

      before do
        stub_stage_checks(group, foundational_flows: true)
      end

      it_behaves_like 'restricts all consumer permissions'
    end
  end

  describe 'when item is a non-ultimate foundational flow' do
    let_it_be(:free_flow) do
      create(:ai_catalog_flow, :public, :with_released_version, project: project,
        foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: project, item: free_flow)
    end

    let_it_be(:free_flow_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: project,
        catalog_item: free_flow)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(project, foundational_flows: true)
      stub_licensed_features(ai_catalog: false)
    end

    it_behaves_like 'allows execute and read consumer permissions'
  end

  describe 'when item is a feature-flag-gated foundational flow' do
    let_it_be(:gated_group, freeze: false) { create(:group) }
    let_it_be(:gated_project) { create(:project, group: gated_group, developers: user) }
    let_it_be(:gated_flow) do
      create(:ai_catalog_flow, :public, :with_released_version, project: gated_project,
        foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: gated_project, item: gated_flow)
    end

    let_it_be(:gated_flow_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: gated_project,
        catalog_item: gated_flow)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(gated_project, foundational_flows: true)
    end

    context 'when the feature flag is enabled' do
      before do
        allow(::Ai::Catalog::FoundationalFlow['code_review/v1'])
          .to receive(:blocked_by_feature_flag?).and_return(false)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when the feature flag is disabled' do
      before do
        allow(::Ai::Catalog::FoundationalFlow['code_review/v1'])
          .to receive(:blocked_by_feature_flag?).and_return(true)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when item consumer belongs to a group' do
      let_it_be(:group_consumer) do
        create(:ai_catalog_item_consumer, group: gated_group, item: gated_flow)
      end

      let_it_be(:gated_flow_enabled_for_group) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: gated_group,
          catalog_item: gated_flow)
      end

      before_all do
        gated_group.add_developer(user)
      end

      subject(:policy) { described_class.new(user, group_consumer) }

      before do
        stub_stage_checks(gated_group, foundational_flows: true)
      end

      context 'when the feature flag is enabled' do
        before do
          allow(::Ai::Catalog::FoundationalFlow['code_review/v1'])
            .to receive(:blocked_by_feature_flag?).and_return(false)
        end

        it { expect_allowed(:read_ai_catalog_item_consumer) }

        # execute_ai_catalog_item is only ever granted via a project-level role (see
        # config/authz/roles/*.yml), so a group-level consumer can never execute
        # regardless of the feature flag state.
        it { expect_disallowed(:execute_ai_catalog_item) }
      end

      context 'when the feature flag is disabled' do
        before do
          allow(::Ai::Catalog::FoundationalFlow['code_review/v1'])
            .to receive(:blocked_by_feature_flag?).and_return(true)
        end

        it_behaves_like 'restricts all consumer permissions'
      end
    end
  end

  describe 'when item is an ultimate-only foundational chat agent', :saas do
    # Security Analyst has global_catalog_id: 356 and ultimate_only: true
    let_it_be(:agent_catalog_item) do
      create(:ai_catalog_item, :agent, :public, :with_released_version, id: 356, project: project)
    end

    let_it_be(:item_consumer, freeze: false) do
      create(:ai_catalog_item_consumer, project: project, item: agent_catalog_item)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_saas_features(gitlab_duo_saas_only: true)
      stub_stage_checks(project)
    end

    context 'when namespace does not have an AI license' do
      before do
        stub_licensed_features(ai_features: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when namespace has only a Premium license' do
      before do
        stub_licensed_features(ai_catalog: true, ai_features: false)
      end

      it_behaves_like 'restricts all consumer permissions'
    end

    context 'when namespace has an Ultimate license' do
      before do
        stub_licensed_features(ai_features: true)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when no foundational chat agent is found for the catalog item' do
      before do
        allow(::Ai::FoundationalChatAgent).to receive(:for_catalog_item)
          .with(agent_catalog_item.id).and_return(nil)
      end

      it_behaves_like 'allows execute and read consumer permissions'
    end
  end

  context 'when ai_catalog_restricted_to_group_hierarchy is enabled on the top-level group' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group, developers: user) }
    let!(:item) { create(:ai_catalog_flow, :public, project: item_project) }
    let!(:item_version) { create(:ai_catalog_flow_version, :released, item: item) }

    let(:item_consumer) do
      build(:ai_catalog_item_consumer, project: project, item: item)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    end

    context 'when item belongs to a project within the same top-level group' do
      let_it_be(:item_project) { create(:project, group: group, developers: user) }

      it_behaves_like 'allows execute and read consumer permissions'
    end

    context 'when item belongs to project outside the top-level group' do
      let_it_be(:item_project) { create(:project, developers: user) }

      it_behaves_like 'restricts all consumer permissions'

      context 'when item is foundational' do
        before do
          allow(item).to receive(:foundational?).and_return(true)
        end

        it_behaves_like 'allows execute and read consumer permissions'
      end
    end
  end

  describe 'when item is a custom agent' do
    let_it_be(:agent_group) { create(:group) }
    let_it_be(:agent_project) { create(:project, group: agent_group, developers: user) }
    let_it_be(:agent_item) { create(:ai_catalog_agent, :with_released_version, project: agent_project) }
    let_it_be_with_reload(:item_consumer) do
      create(:ai_catalog_item_consumer, project: agent_project, item: agent_item)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(agent_project)
    end

    describe 'when duo_custom_agents_enabled setting is toggled' do
      let_it_be(:maintainer) { create(:user, maintainer_of: agent_project) }

      subject(:policy) { described_class.new(maintainer, item_consumer) }

      context 'when duo_custom_agents_enabled is true (default)' do
        it_behaves_like 'allows all consumer permissions'
      end

      context 'when duo_custom_agents_enabled is false' do
        before do
          item_consumer.root_ancestor.namespace_settings.update!(duo_custom_agents_enabled: false)
        end

        it_behaves_like 'restricts all consumer permissions'
      end
    end
  end

  describe 'restricted item visibility' do
    let_it_be(:owner_group) { create(:group) }
    let_it_be(:owner_project) { create(:project, group: owner_group) }
    let_it_be(:restricted_item) do
      create(:ai_catalog_agent, :restricted, :with_released_version, project: owner_project)
    end

    let(:item_consumer) do
      build_stubbed(:ai_catalog_item_consumer, project: consumer_project, item: restricted_item)
    end

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      enable_ai_catalog
    end

    context 'when the consumer is in the same TLG hierarchy as the item' do
      let_it_be(:consumer_project) { create(:project, group: owner_group, maintainers: user) }

      it { expect_allowed(:execute_ai_catalog_item) }
      it { expect_allowed(:read_ai_catalog_item_consumer) }
      it { expect_allowed(:admin_ai_catalog_item_consumer) }

      context 'when ai_catalog_internal_visibility feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_internal_visibility: false)
        end

        it { expect_allowed(:execute_ai_catalog_item) }
        it { expect_allowed(:read_ai_catalog_item_consumer) }
        it { expect_allowed(:admin_ai_catalog_item_consumer) }
      end
    end

    context 'when the consumer is outside the TLG hierarchy of the item' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:consumer_project) { create(:project, group: other_group, maintainers: user) }

      it { expect_disallowed(:execute_ai_catalog_item) }
      it { expect_disallowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:admin_ai_catalog_item_consumer) }

      context 'when ai_catalog_internal_visibility feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_internal_visibility: false)
        end

        it { expect_allowed(:execute_ai_catalog_item) }
        it { expect_allowed(:read_ai_catalog_item_consumer) }
        it { expect_allowed(:admin_ai_catalog_item_consumer) }
      end
    end
  end

  describe 'when pinned version is not executable' do
    let_it_be(:pin_group) { create(:group) }
    let_it_be(:pin_project) { create(:project, group: pin_group, developers: user) }
    let_it_be(:pin_item, freeze: false) { create(:ai_catalog_flow, :with_released_version, project: pin_project) }
    let_it_be(:item_consumer, freeze: false) { create(:ai_catalog_item_consumer, project: pin_project, item: pin_item) }

    subject(:policy) { described_class.new(user, item_consumer) }

    before do
      stub_stage_checks(pin_project, flows: true)
    end

    after do
      item_consumer.update!(pinned_version_prefix: nil)
      item_consumer.instance_variable_set(:@pinned_version, nil)
    end

    context 'when pinned_version cannot be resolved' do
      before do
        item_consumer.instance_variable_set(:@pinned_version, nil)
        item_consumer.update!(pinned_version_prefix: "99.99.99")
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it { expect_disallowed(:execute_ai_catalog_item) }
    end

    context 'when pinned_version is in draft state' do
      let(:item_version) do
        create(:ai_catalog_flow_version, :draft, item: pin_item)
      end

      before do
        item_consumer.instance_variable_set(:@pinned_version, nil)
        item_consumer.update!(pinned_version_prefix: item_version.version)
      end

      it { expect_disallowed(:execute_ai_catalog_item) }
    end
  end
end
