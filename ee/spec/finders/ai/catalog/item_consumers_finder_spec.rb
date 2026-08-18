# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumersFinder, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:parent_group) { create(:group, developers: user) }
  let_it_be(:parent_group_consumers) { create_list(:ai_catalog_item_consumer, 2, group: parent_group) }
  let_it_be(:project) { create(:project, group: parent_group) }
  let_it_be(:project_consumers) { create_list(:ai_catalog_item_consumer, 2, project: project) }
  let_it_be(:another_project) { create(:project, group: parent_group) }
  let_it_be(:another_project_consumer) { create(:ai_catalog_item_consumer, project: another_project) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:group_consumers) { create_list(:ai_catalog_item_consumer, 2, group: group) }
  let_it_be(:foundational_agent) { create(:ai_catalog_item) }
  let_it_be(:foundational_agent2) { create(:ai_catalog_item) }

  let(:foundational_agent_ids) { [foundational_agent.id, foundational_agent2.id] }

  let(:foundational_agents_items_const) do
    [
      {
        id: 2,
        reference: 'duo_planner',
        version: 'experimental',
        name: 'Planner',
        global_catalog_id: foundational_agent.id,
        description: 'desc'
      },
      {
        id: 3,
        reference: 'analytics_agent',
        version: 'experimental',
        name: 'Planner',
        global_catalog_id: foundational_agent2.id,
        description: 'desc'
      }
    ]
  end

  let(:results_without_foundational_agents) do
    results.reject { |consumer| foundational_agent_ids.include?(consumer.ai_catalog_item_id) }
  end

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    allow(Ai::FoundationalChatAgent).to receive(:all).and_return(
      foundational_agents_items_const.map { |item| Ai::FoundationalChatAgent.new(item) }
    )

    allow(Gitlab).to receive(:com_except_jh?).and_return(true)
    enable_ai_catalog
  end

  context 'when project_id is provided' do
    let(:params) { { project_id: project.id, include_foundational_consumers: true } }

    it 'only includes project consumers and foundational consumers' do
      expect(results_without_foundational_agents).to match_array(project_consumers)
      expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
    end

    context 'when item_id is provided' do
      let(:params) { super().merge(item_id: project_consumers[0].ai_catalog_item_id) }

      it { is_expected.to contain_exactly(project_consumers[0]) }
    end

    context 'when item_type is not provided' do
      let(:params) { { project_id: project.id } }

      it 'does not filter by item types' do
        expect(results.to_sql).not_to include('"item"."item_type"')
      end
    end

    context 'when item_type is provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }
      let(:params) { super().merge(item_type: :flow) }

      it { is_expected.to contain_exactly(flow_consumer) }

      it 'filters by item types' do
        expect(results.to_sql).to include('"item"."item_type"')
      end
    end

    context 'when item_types is provided' do
      let_it_be(:flow) { create(:ai_catalog_flow) }
      let_it_be(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let_it_be(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let_it_be(:third_party_flow_consumer) do
        create(:ai_catalog_item_consumer, project: project, item: third_party_flow)
      end

      let(:params) { super().merge(item_types: %i[flow third_party_flow]) }

      it { is_expected.to contain_exactly(flow_consumer, third_party_flow_consumer) }

      context 'when user cannot read flows' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(false)
        end

        it { is_expected.to contain_exactly(third_party_flow_consumer) }

        context 'when item_types is [:flow]' do
          let(:params) { super().merge(item_types: [:flow]) }

          it { is_expected.to be_empty }
        end

        context 'when item_types does not include :agent' do
          let(:params) { super().merge(item_types: [:flow]) }

          it 'does not inject synthesized foundational agent consumers' do
            expect(Ai::FoundationalChatAgent).not_to receive(:all)

            results
          end
        end

        context 'when item_types includes :agent' do
          let(:params) { super().merge(item_types: [:agent, :third_party_flow]) }

          it 'injects synthesized foundational agent consumers' do
            expect(Ai::FoundationalChatAgent).to receive(:all)

            results
          end
        end
      end

      context 'when user cannot read third party flows' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
        end

        it { is_expected.to contain_exactly(flow_consumer) }

        context 'when item_types is [:third_party_flow]' do
          let(:params) { super().merge(item_types: [:third_party_flow]) }

          it { is_expected.to be_empty }
        end
      end

      context 'when item_types is empty' do
        let(:params) { super().merge(item_types: []) }

        it 'includes project_consumers, flow_consumer and third_party_flow_consumer' do
          expect(results_without_foundational_agents).to contain_exactly(
            *project_consumers, flow_consumer, third_party_flow_consumer
          )
          expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
        end
      end
    end

    context 'when item_types and item_type are provided' do
      let(:flow) { create(:ai_catalog_flow) }
      let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      let(:params) { super().merge(item_type: :flow, item_types: [:third_party_flow]) }

      it { is_expected.to contain_exactly(flow_consumer, third_party_flow_consumer) }
    end

    context 'when user cannot read flows' do
      let!(:flow) { create(:ai_catalog_flow) }
      let!(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let!(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let!(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(false)
      end

      it 'includes project_consumers third_party_flow_consumer and foundational consumers' do
        expect(results_without_foundational_agents).to contain_exactly(*project_consumers, third_party_flow_consumer)
        expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
      end
    end

    context 'when user can read foundational flows but not custom flows' do
      let_it_be(:foundational_flow) do
        create(:ai_catalog_flow, :with_foundational_flow_reference)
      end

      let_it_be(:foundational_flow_consumer) do
        create(:ai_catalog_item_consumer, project: project, item: foundational_flow)
      end

      let_it_be(:custom_flow) { create(:ai_catalog_flow) }
      let_it_be(:custom_flow_consumer) do
        create(:ai_catalog_item_consumer, project: project, item: custom_flow)
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(true)
      end

      it 'includes foundational flow consumers' do
        expect(results_without_foundational_agents).to include(foundational_flow_consumer)
      end

      context 'when user also cannot read foundational flows' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(false)
        end

        it 'excludes all flow consumers' do
          expect(results_without_foundational_agents).not_to include(foundational_flow_consumer, custom_flow_consumer)
        end
      end
    end

    context 'when user cannot read third party flows' do
      let!(:flow) { create(:ai_catalog_flow) }
      let!(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

      let!(:third_party_flow) { create(:ai_catalog_third_party_flow) }
      let!(:third_party_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: third_party_flow) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
      end

      it 'includes project_consumers, flow_consumer and foundational consumers' do
        expect(results_without_foundational_agents).to contain_exactly(*project_consumers, flow_consumer)
        expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
      end
    end

    context 'when include_inherited is true' do
      let(:params) { super().merge(include_inherited: true) }

      it 'includes project and parent group consumers' do
        expect(results_without_foundational_agents).to match_array(project_consumers + parent_group_consumers)
      end

      context 'when item_id is also provided' do
        let(:params) { super().merge(item_id: parent_group_consumers[0].ai_catalog_item_id) }

        it { is_expected.to contain_exactly(parent_group_consumers[0]) }
      end

      context 'when item_types is also provided' do
        let(:flow) { create(:ai_catalog_flow) }
        let(:flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }
        let(:parent_flow_consumer) { create(:ai_catalog_item_consumer, group: parent_group, item: flow) }
        let(:params) { super().merge(item_types: [:flow]) }

        it { is_expected.to contain_exactly(flow_consumer, parent_flow_consumer) }
      end
    end

    context 'when project does not exist' do
      let(:params) { super().merge(project_id: non_existing_record_id) }

      it { is_expected.to be_empty }
    end

    context 'with a guest user' do
      let_it_be(:guest_user) { create(:user) }
      let(:params) { { project_id: project.id } }

      before_all do
        project.add_guest(guest_user)
      end

      subject(:results) { described_class.new(guest_user, params: params).execute }

      it 'allows guests to read item consumers in the project' do
        expect(results_without_foundational_agents).to match_array(project_consumers)
      end

      context 'when include_inherited is true' do
        let(:params) { super().merge(include_inherited: true) }

        it 'inherits parent consumers' do
          expect(results_without_foundational_agents).to match_array(project_consumers + parent_group_consumers)
        end
      end
    end

    context 'when Gitlab.com_except_jh? is false' do
      before do
        allow(Gitlab).to receive(:com_except_jh?).and_return(false)
      end

      it 'does not include foundational agent consumers' do
        expect(results.pluck(:ai_catalog_item_id)).not_to include(*foundational_agent_ids)
      end
    end
  end

  context 'when group_id is provided' do
    let(:params) { { group_id: group.id, include_foundational_consumers: true } }

    it 'includes only the group consumers and foundational agent consumers' do
      expect(results_without_foundational_agents).to match_array(group_consumers)
      expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
    end

    context 'when item_id is provided' do
      let(:params) { super().merge(item_id: group_consumers[0].ai_catalog_item_id) }

      it { is_expected.to contain_exactly(group_consumers[0]) }
    end

    context 'when include_inherited is true' do
      let(:params) { super().merge(include_inherited: true) }

      it 'includes only group, parent group and foundational consumers' do
        expect(results_without_foundational_agents).to match_array(group_consumers + parent_group_consumers)
        expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
      end

      context 'when item_id is also provided' do
        let(:params) { super().merge(item_id: parent_group_consumers[0].ai_catalog_item_id) }

        it { is_expected.to contain_exactly(parent_group_consumers[0]) }
      end

      context 'when item_types is also provided' do
        let(:flow) { create(:ai_catalog_flow) }
        let(:flow_consumer) { create(:ai_catalog_item_consumer, group: group, item: flow) }

        let(:parent_flow_consumer) { create(:ai_catalog_item_consumer, group: parent_group, item: flow) }
        let(:params) { super().merge(item_types: [:flow]) }

        it { is_expected.to contain_exactly(flow_consumer, parent_flow_consumer) }
      end
    end

    context 'with a guest user' do
      let_it_be(:guest_user) { create(:user) }
      let(:params) { { group_id: group.id, include_foundational_consumers: true } }

      before_all do
        group.add_guest(guest_user)
      end

      subject(:results) { described_class.new(guest_user, params: params).execute }

      it 'allows guests to read item consumers in the group' do
        expect(results_without_foundational_agents).to match_array(group_consumers)
        expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
      end

      context 'when include_inherited is true' do
        let(:params) { super().merge(include_inherited: true) }

        it 'includes parent consumers' do
          expect(results_without_foundational_agents).to match_array(group_consumers + parent_group_consumers)
        end
      end
    end
  end

  context 'when the top-level group restricts the AI Catalog to its hierarchy' do
    let_it_be_with_refind(:parent_group) { create(:group, developers: user) }
    let_it_be(:project) { create(:project, group: parent_group) }
    let_it_be(:sibling_project) { create(:project, group: parent_group) }

    let_it_be(:project_flow) { create(:ai_catalog_flow, :public, project: project) }
    let_it_be(:sibling_project_flow) { create(:ai_catalog_flow, :public, project: sibling_project) }
    let_it_be(:external_flow) { create(:ai_catalog_flow, :public) }
    let_it_be(:foundational_flow) do
      create(:ai_catalog_flow, :public, verification_level: :gitlab_maintained)
    end

    let_it_be(:project_flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: project_flow)
    end

    let_it_be(:sibling_project_flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: sibling_project_flow)
    end

    let_it_be(:external_flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: external_flow)
    end

    let_it_be(:foundational_flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: foundational_flow)
    end

    let(:params) { { project_id: project.id } }

    context 'when the restriction is enabled' do
      before do
        parent_group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: true)
      end

      it 'returns consumers only for items within the hierarchy and foundational items' do
        expect(results)
          .to contain_exactly(
            project_flow_consumer,
            sibling_project_flow_consumer,
            foundational_flow_consumer
          )
      end
    end

    context 'when the restriction is disabled' do
      it 'returns the consumer for the external item as well' do
        expect(results).to include(external_flow_consumer)
      end
    end
  end

  context 'when both project_id and group_id are provided' do
    let(:params) { { project_id: project.id, group_id: group.id, include_foundational_consumers: true } }

    it 'uses project_id and ignores group_id' do
      expect(results_without_foundational_agents).to match_array(project_consumers)
      expect(results.pluck(:ai_catalog_item_id)).to include(*foundational_agent_ids)
    end
  end

  context 'when neither project_id or group_id are provided' do
    let(:params) { { item_id: project_consumers[0].ai_catalog_item_id } }

    it 'raises an error' do
      expect { results }.to raise_error(ArgumentError, 'Must provide either project_id or group_id param')
    end
  end

  context 'when include_foundational_consumers is not provided' do
    let(:params) { { project_id: project.id } }

    it 'only includes project consumers and not foundational consumers' do
      expect(results).to match_array(project_consumers)
    end
  end

  context 'when include_foundational_consumers is false' do
    let(:params) { { project_id: project.id, include_foundational_consumers: false } }

    it 'only includes project consumers and not foundational consumers' do
      expect(results).to match_array(project_consumers)
    end
  end

  context 'when foundational_flow_reference is provided' do
    let_it_be(:custom_flow) { create(:ai_catalog_flow) }
    let_it_be(:custom_flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: custom_flow)
    end

    let_it_be(:flow_with_ref) do
      create(:ai_catalog_flow, :public, foundational_flow_reference: 'gitlab/foo_maker')
    end

    let_it_be(:flow_consumer) do
      create(:ai_catalog_item_consumer, project: project, item: flow_with_ref)
    end

    let(:params) { { project_id: project.id, foundational_flow_reference: 'gitlab/foo_maker' } }

    it { is_expected.to contain_exactly(flow_consumer) }

    context 'when user is not allowed to read custom flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
      end

      # Custom flows doesn't interfer with foundational flows
      it { is_expected.to contain_exactly(flow_consumer) }
    end

    context 'when user is not allowed to read foundational flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, project).and_return(false)
      end

      it { is_expected.to be_empty }
    end

    context 'when searching for beta foundational flow' do
      let_it_be(:beta_flow) do
        create(:ai_catalog_flow, :public, foundational_flow_reference: 'example_beta_flow/v1')
      end

      let_it_be(:beta_flow_consumer) do
        create(:ai_catalog_item_consumer, project: project, item: beta_flow)
      end

      let(:params) { { project_id: project.id, foundational_flow_reference: 'example_beta_flow/v1' } }

      before do
        allow(::Ai::Catalog::FoundationalFlow).to receive(:beta?)
          .with('example_beta_flow/v1').and_return(true)
      end

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: false)
        end

        it 'does not return beta flow consumers' do
          is_expected.to be_empty
        end
      end

      context 'when beta features are enabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: true)
        end

        it 'returns beta flow consumers' do
          is_expected.to contain_exactly(beta_flow_consumer)
        end
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it 'does not return beta flow consumers' do
          is_expected.to be_empty
        end
      end

      context 'when beta features are enabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: true)
        end

        it 'returns beta flow consumers' do
          is_expected.to contain_exactly(beta_flow_consumer)
        end
      end
    end

    context 'when searching for GA foundational flow' do
      let_it_be(:ga_flow) { create(:ai_catalog_flow, :public, foundational_flow_reference: 'code_review/v1') }
      let_it_be(:ga_flow_consumer) { create(:ai_catalog_item_consumer, project: project, item: ga_flow) }
      let(:params) { { project_id: project.id, foundational_flow_reference: 'code_review/v1' } }

      context 'when beta features are disabled on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          project.root_ancestor.namespace_settings.update!(experiment_features_enabled: false)
        end

        it 'still returns GA flow consumers' do
          is_expected.to contain_exactly(ga_flow_consumer)
        end
      end

      context 'when beta features are disabled on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          stub_application_setting(instance_level_ai_beta_features_enabled: false)
        end

        it 'still returns GA flow consumers' do
          is_expected.to contain_exactly(ga_flow_consumer)
        end
      end
    end

    context 'when no items match the reference' do
      let(:params) { { project_id: project.id, foundational_flow_reference: 'nonexistent/reference' } }

      it { is_expected.to be_empty }
    end

    context 'when other project is provided' do
      let(:params) { { project_id: another_project.id, foundational_flow_reference: 'gitlab/foo_maker' } }

      it { is_expected.to be_empty }
    end
  end

  context 'when configurable_for_project_id is provided' do
    let_it_be(:configurable_for_project) { create(:project, group: parent_group) }
    let_it_be(:public_flow_from_other_project) do
      create(:ai_catalog_flow, :public, project: project)
    end

    let_it_be(:private_agent_owned_by_configurable_for_project) do
      create(:ai_catalog_agent, project: configurable_for_project)
    end

    let_it_be(:public_flow_consumer) do
      create(:ai_catalog_item_consumer, group: parent_group, item: public_flow_from_other_project)
    end

    let_it_be(:private_agent_consumer) do
      create(:ai_catalog_item_consumer, group: parent_group, item: private_agent_owned_by_configurable_for_project)
    end

    let(:params) { { group_id: parent_group.id, configurable_for_project_id: configurable_for_project.id } }

    it { is_expected.to contain_exactly(public_flow_consumer, private_agent_consumer) }

    context 'when configurable project cannot access private items from other projects' do
      let(:params) { { group_id: parent_group.id, configurable_for_project_id: project.id } }

      it { is_expected.to contain_exactly(public_flow_consumer) }
    end

    context 'when item_types is provided' do
      let(:params) { super().merge(item_types: %i[flow]) }

      it { is_expected.to contain_exactly(public_flow_consumer) }
    end
  end

  describe 'ordering' do
    let_it_be(:developer_project) { create(:project, group: parent_group, developers: user) }
    let_it_be(:reporter_project) { create(:project, group: parent_group, reporters: user) }

    # Create items in random priority order to ensure ordering is from logic, not creation order
    let_it_be_with_reload(:foundational_external_agent) do
      create(:ai_catalog_agent, :public, verification_level: :gitlab_maintained)
    end

    let_it_be(:public_item) { create(:ai_catalog_item, :public) }

    let_it_be(:foundational_flow) do
      create(:ai_catalog_flow, :with_foundational_flow_reference, :public,
        verification_level: :gitlab_maintained)
    end

    let_it_be(:private_item_in_developer_project) do
      create(:ai_catalog_item, project: developer_project)
    end

    # Create consumers in random order
    let_it_be(:foundational_external_agent_consumer) do
      create(:ai_catalog_item_consumer, item: foundational_external_agent, project: developer_project)
    end

    let_it_be(:public_item_consumer) do
      create(:ai_catalog_item_consumer, item: public_item, project: developer_project)
    end

    let_it_be(:foundational_flow_consumer) do
      create(:ai_catalog_item_consumer, item: foundational_flow, project: developer_project)
    end

    let_it_be(:private_item_consumer) do
      create(:ai_catalog_item_consumer, item: private_item_in_developer_project, project: developer_project)
    end

    let(:params) { { project_id: developer_project.id, include_foundational_consumers: true } }

    it 'returns consumers ordered by priority' do
      result = results_without_foundational_agents.to_a

      # For Foundational agents item_consumer records are not created
      # Priority 1: GitLab-maintained items (foundational flows, external agents)
      # Priority 2: User's project items
      # Priority 3: Remaining items
      # Note: tie breaker - ID DESC
      expect(result).to eq([
        foundational_flow_consumer,
        foundational_external_agent_consumer,
        private_item_consumer,
        public_item_consumer
      ])
    end

    context 'with filters applied' do
      it 'maintains priority ordering with item_type filter' do
        result = described_class.new(user, params: params.merge(item_types: [:agent, :third_party_flow])).execute.to_a
        result.reject! { |consumer| foundational_agent_ids.include?(consumer.ai_catalog_item_id) }

        expect(result).to eq([
          foundational_external_agent_consumer,
          private_item_consumer,
          public_item_consumer
        ])
      end
    end

    context 'when on SaaS', :saas do
      before do
        allow(Ai::Catalog::Item).to receive(:foundational_external_agent_ids)
          .and_return([foundational_external_agent.id])

        # Foundational external agents on SaaS use hardcoded IDs, making
        # verification_level irrelevant for priority ordering
        foundational_external_agent.update!(verification_level: :unverified)
      end

      it 'returns consumers ordered by priority' do
        all_consumers = results.to_a

        foundational_chat_agent_consumers, other_consumers = all_consumers.partition { |consumer| consumer.id < 0 }

        # Foundational agent item_consumer records are not persisted in the DB; they are dynamically synthesized.
        #
        # Ordering priority:
        # Priority 1: Foundational chat agents
        # Priority 2: Foundational external agents
        # Priority 3: Foundational flows
        # Priority 4: User's project items
        # Priority 5: Remaining items
        expect(all_consumers.first(2)).to match_array(foundational_chat_agent_consumers)

        expect(other_consumers).to eq([
          foundational_external_agent_consumer,
          foundational_flow_consumer,
          private_item_consumer,
          public_item_consumer
        ])
      end
    end
  end

  describe 'exclude_disabled_item_types' do
    let_it_be_with_reload(:finder_project) { create(:project, :in_group, developers: user) }
    let_it_be(:custom_flow) { create(:ai_catalog_flow, project: finder_project) }
    let_it_be(:foundational_flow) do
      create(:ai_catalog_flow, :public, project: finder_project, foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:external_agent) { create(:ai_catalog_third_party_flow, project: finder_project) }
    let_it_be(:agent_item) { create(:ai_catalog_agent, project: finder_project) }
    let_it_be(:custom_flow_consumer) do
      create(:ai_catalog_item_consumer, project: finder_project, item: custom_flow)
    end

    let_it_be(:foundational_flow_consumer) do
      create(:ai_catalog_item_consumer, project: finder_project, item: foundational_flow)
    end

    let_it_be(:external_agent_consumer) do
      create(:ai_catalog_item_consumer, project: finder_project, item: external_agent)
    end

    let_it_be(:agent_consumer) do
      create(:ai_catalog_item_consumer, project: finder_project, item: agent_item)
    end

    let(:params) { { project_id: finder_project.id } }

    subject(:results) { described_class.new(user, params: params).execute }

    before do
      enable_ai_catalog
      allow(Gitlab).to receive(:com_except_jh?).and_return(false)
    end

    context 'when duo_custom_agents_enabled is false' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(duo_custom_agents_enabled: false)
      end

      it 'excludes custom agent consumers but keeps other consumers' do
        expect(results).to contain_exactly(custom_flow_consumer, foundational_flow_consumer, external_agent_consumer)
      end
    end

    context 'when duo_custom_agents_enabled is true (default)' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(duo_custom_agents_enabled: true)
      end

      it 'includes custom agent consumers' do
        expect(results).to include(agent_consumer)
      end
    end

    context 'when duo_custom_flows_enabled is false' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(duo_custom_flows_enabled: false)
      end

      it 'excludes custom flow consumers but keeps foundational flows and external agents' do
        expect(results).to contain_exactly(foundational_flow_consumer, external_agent_consumer, agent_consumer)
      end
    end

    context 'when duo_external_agents_enabled is false' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(duo_external_agents_enabled: false)
      end

      it 'excludes external agent consumers but keeps flows' do
        expect(results).to contain_exactly(custom_flow_consumer, foundational_flow_consumer, agent_consumer)
      end
    end

    context 'when all settings are disabled' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(
          duo_custom_agents_enabled: false,
          duo_custom_flows_enabled: false,
          duo_external_agents_enabled: false
        )
      end

      it 'excludes custom agents, custom flows and external agents but keeps foundational flows' do
        expect(results).to contain_exactly(foundational_flow_consumer)
      end
    end

    context 'when all settings are enabled (default)' do
      before do
        finder_project.root_ancestor.namespace_settings.update!(
          duo_custom_agents_enabled: true,
          duo_custom_flows_enabled: true,
          duo_external_agents_enabled: true
        )
      end

      it 'includes all consumers' do
        expect(results).to contain_exactly(
          custom_flow_consumer, foundational_flow_consumer, external_agent_consumer, agent_consumer
        )
      end
    end

    context 'when namespace_settings record does not exist' do
      before do
        finder_project.root_ancestor.namespace_settings.destroy!
      end

      it 'excludes custom agents, custom flows and external agents but keeps foundational flows' do
        expect(results).to contain_exactly(foundational_flow_consumer)
      end
    end
  end
end
