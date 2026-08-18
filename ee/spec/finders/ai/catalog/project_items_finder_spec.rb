# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ProjectItemsFinder, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, developers: user, group: group) }
  let_it_be(:other_project) { create(:project, developers: user) }
  let_it_be(:sibling_project) { create(:project, group: group, developers: user) }

  let_it_be_with_reload(:public_flow) { create(:ai_catalog_flow, :public, project: project) }
  let_it_be_with_reload(:private_agent) { create(:ai_catalog_agent, :private, project: project) }
  let_it_be_with_reload(:private_third_party_flow) do
    create(:ai_catalog_third_party_flow, project: project)
  end

  let_it_be(:deleted_flow) { create(:ai_catalog_flow, :soft_deleted, project: project) }
  let_it_be(:private_flow_of_other_project) do
    create(:ai_catalog_flow, :private, project: other_project)
  end

  let_it_be(:public_flow_of_other_project) { create(:ai_catalog_flow, :public, project: other_project) }
  let_it_be(:public_flow_of_other_org) do
    create(:ai_catalog_flow, :public, organization: create(:organization))
  end

  let_it_be(:deleted_public_flow_of_other_project) do
    create(:ai_catalog_flow, :public, :soft_deleted, project: other_project)
  end

  let_it_be(:foundational_flow) do
    create(:ai_catalog_flow, :public, verification_level: :gitlab_maintained, organization: project.organization)
  end

  let_it_be(:public_flow_of_sibling_project) do
    create(:ai_catalog_flow, :public, project: sibling_project)
  end

  let_it_be(:private_flow_of_sibling_project) do
    create(:ai_catalog_flow, :private, project: sibling_project)
  end

  let_it_be(:restricted_agent_in_group) do
    create(:ai_catalog_agent, :restricted, project: sibling_project)
  end

  let_it_be(:restricted_agent_outside_group) do
    create(:ai_catalog_agent, :restricted, project: other_project)
  end

  let(:params) { {} }

  subject(:results) { described_class.new(user, project, params: params).execute }

  before do
    enable_ai_catalog
  end

  it 'returns items that are not deleted and belong to the project' do
    is_expected.to contain_exactly(public_flow, private_agent, private_third_party_flow)
  end

  it 'returns items ordered by id desc' do
    is_expected.to eq([private_third_party_flow, private_agent, public_flow])
  end

  context 'when user does not have permission to read the project' do
    let_it_be(:user) { create(:user) }

    it { is_expected.to be_empty }
  end

  context 'when filtering by `item_types`' do
    let(:params) { { item_types: %w[flow third_party_flow] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(public_flow, private_third_party_flow)
    end

    context 'when user cannot read ai catalog flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
      end

      it 'returns non-flow items only' do
        is_expected.to contain_exactly(private_third_party_flow)
      end
    end

    context 'when user cannot read ai catalog third party flows' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
      end

      it 'returns non-third party flow items only' do
        is_expected.to contain_exactly(public_flow)
      end
    end

    context 'when item_types is empty' do
      let(:params) { { item_types: [] } }

      it 'returns all items' do
        is_expected.to contain_exactly(public_flow, private_agent, private_third_party_flow)
      end
    end
  end

  context 'when user cannot read ai catalog flows' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, project).and_return(false)
    end

    it 'returns non-flow items only' do
      is_expected.to contain_exactly(private_agent, private_third_party_flow)
    end
  end

  context 'when user cannot read ai catalog third party flows' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_third_party_flow, project).and_return(false)
    end

    it 'returns non-third party flow items only' do
      is_expected.to contain_exactly(public_flow, private_agent)
    end
  end

  context 'when filtering by `search`' do
    let_it_be(:agent_with_name_match) do
      create(:ai_catalog_agent, name: 'Autotriager', project: project)
    end

    let_it_be(:flow_with_description_match) do
      create(:ai_catalog_flow, project: project, description: 'Flow to triage issues')
    end

    let(:params) { { search: 'triage' } }

    it 'returns items that partial match on the name or description' do
      is_expected.to contain_exactly(
        agent_with_name_match,
        flow_with_description_match
      )
    end
  end

  context 'when `all_available` param is `true`' do
    let(:params) { { all_available: true } }

    before do
      project.namespace.reload
    end

    it 'returns public and restricted items from same TLG, and foundational items, with gitlab_maintained at top' do
      is_expected.to eq([
        foundational_flow,
        restricted_agent_in_group,
        public_flow_of_sibling_project,
        public_flow_of_other_project,
        private_third_party_flow,
        private_agent,
        public_flow
      ])
    end

    context 'when the top-level group restricts the AI Catalog to its hierarchy' do
      before do
        group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: true)
      end

      it 'returns restricted and public items within the hierarchy, and foundational items', :aggregate_failures do
        expect(results).to contain_exactly(
          foundational_flow,
          public_flow,
          private_agent,
          private_third_party_flow,
          public_flow_of_sibling_project,
          restricted_agent_in_group
        )
      end
    end
  end

  context 'when filtering by `enabled`' do
    let(:params) { { enabled: enabled } }

    before_all do
      create(:ai_catalog_item_consumer, item: private_agent, project: project)
      create(:ai_catalog_item_consumer, item: public_flow, project: other_project)
      create(:ai_catalog_item_consumer, item: public_flow_of_other_project, project: other_project)
    end

    context 'when `enabled` is `true`' do
      let(:enabled) { true }

      it 'returns items owned by the project and enabled for the project' do
        is_expected.to contain_exactly(private_agent)
      end
    end

    context 'when `enabled` is `false`' do
      let(:enabled) { false }

      it 'returns only items that have not been enabled for the project' do
        is_expected.to contain_exactly(public_flow, private_third_party_flow)
      end
    end
  end

  context 'when sorting' do
    before do
      public_flow.update!(star_count: 5, last_30_day_usage_count: 10)
      private_agent.update!(star_count: 20, last_30_day_usage_count: 50)
      private_third_party_flow.update!(star_count: 1, last_30_day_usage_count: 30)
    end

    context 'with sort: :star_count_desc' do
      let(:params) { { sort: :star_count_desc } }

      it 'returns items sorted by star count descending' do
        star_counts = results.map(&:star_count)
        expect(star_counts).to eq(star_counts.sort.reverse)
      end
    end

    context 'with sort: :star_count_asc' do
      let(:params) { { sort: :star_count_asc } }

      it 'returns items sorted by star count ascending' do
        star_counts = results.map(&:star_count)
        expect(star_counts).to eq(star_counts.sort)
      end
    end

    context 'with sort: :usage_count_desc' do
      let(:params) { { sort: :usage_count_desc } }

      it 'returns items sorted by usage count descending' do
        usage_counts = results.map(&:last_30_day_usage_count)
        expect(usage_counts).to eq(usage_counts.sort.reverse)
      end
    end

    context 'with sort: :usage_count_asc' do
      let(:params) { { sort: :usage_count_asc } }

      it 'returns items sorted by usage count ascending' do
        usage_counts = results.map(&:last_30_day_usage_count)
        expect(usage_counts).to eq(usage_counts.sort)
      end
    end

    context 'with no sort param' do
      it 'returns items in default order' do
        is_expected.to eq([private_third_party_flow, private_agent, public_flow])
      end
    end
  end
end
