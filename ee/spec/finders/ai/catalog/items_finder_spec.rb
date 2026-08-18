# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemsFinder, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:project_guest_access) { create(:project, guests: user) }

  let_it_be_with_reload(:public_flow) { create(:ai_catalog_flow, :public) }
  let_it_be(:public_deleted_flow) { create(:ai_catalog_flow, deleted_at: Time.zone.now) }
  let_it_be(:public_flow_in_other_org) do
    create(:ai_catalog_flow, :public, organization: create(:organization))
  end

  let_it_be(:private_flow) { create(:ai_catalog_flow) }
  let_it_be_with_reload(:public_agent) { create(:ai_catalog_agent, :public) }

  let_it_be_with_reload(:private_flow_guest_access) do
    create(:ai_catalog_flow, project: project_guest_access)
  end

  let_it_be(:private_agent_guest_access) do
    create(:ai_catalog_agent, project: project_guest_access)
  end

  let_it_be_with_reload(:private_third_party_flow_guest_access) do
    create(:ai_catalog_third_party_flow, project: project_guest_access)
  end

  let(:params) { { organization: user.organization } }

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    enable_ai_catalog
  end

  it 'returns items visible to user' do
    is_expected.to contain_exactly(
      public_flow,
      private_third_party_flow_guest_access,
      public_agent,
      private_flow_guest_access,
      private_agent_guest_access
    )
  end

  context 'with restricted items' do
    let_it_be(:restricted_item) { create(:ai_catalog_agent, :restricted) }
    let_it_be(:restricted_item_in_guest_project) do
      create(:ai_catalog_agent, :restricted, project: project_guest_access)
    end

    it 'excludes restricted items from default sort results' do
      expect(results).not_to include(restricted_item)
      expect(results).not_to include(restricted_item_in_guest_project)
    end

    context 'with explicit sort' do
      let(:params) { { organization: user.organization, sort: :star_count_desc } }

      it 'excludes restricted items from sorted results' do
        expect(results).not_to include(restricted_item)
        expect(results).not_to include(restricted_item_in_guest_project)
      end
    end

    it 'both sort paths agree on excluding restricted items' do
      default_sort = described_class.new(user, params: { organization: user.organization }).execute
      explicit_sort = described_class.new(user,
        params: { organization: user.organization, sort: :star_count_desc }).execute

      expect(default_sort).not_to include(restricted_item, restricted_item_in_guest_project)
      expect(explicit_sort).not_to include(restricted_item, restricted_item_in_guest_project)
      expect(default_sort.map(&:id)).to match_array(explicit_sort.map(&:id))
    end
  end

  context 'when filtering by item_type' do
    let(:params) { { organization: user.organization, item_type: 'agent' } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_guest_access
      )
    end
  end

  context 'when filtering by item_types' do
    let(:params) { { organization: user.organization, item_types: %w[third_party_flow agent] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_guest_access,
        private_third_party_flow_guest_access
      )
    end
  end

  context 'when filtering by item_type and item_types' do
    let(:params) { { organization: user.organization, item_types: ['third_party_flow'], item_type: 'agent' } }

    it 'returns items matching both arguments' do
      is_expected.to contain_exactly(
        public_agent,
        private_agent_guest_access,
        private_third_party_flow_guest_access
      )
    end
  end

  context 'when filtering by search' do
    let_it_be(:agent_with_name_match) { create(:ai_catalog_agent, :public, name: 'Autotriager') }
    let_it_be(:flow_with_description_match) do
      create(:ai_catalog_flow, :public, description: 'Flow to triage issues')
    end

    let(:params) { { organization: user.organization, search: 'triage' } }

    it 'returns items that partial match on the name or description' do
      is_expected.to contain_exactly(
        agent_with_name_match,
        flow_with_description_match
      )
    end
  end

  context 'when filtering by organization' do
    context "with user's organization" do
      let(:params) { { organization: user.organization } }

      it 'returns the matching items' do
        is_expected.not_to include(public_flow_in_other_org)
        expect(results.size).to eq(5)
      end
    end

    context "with organization user does not belong to" do
      let(:params) { { organization: public_flow_in_other_org.organization } }

      it 'returns public items in that organization' do
        is_expected.to contain_exactly(public_flow_in_other_org)
      end

      it 'returns the matching items when user is nil' do
        expect(described_class.new(nil, params: params).execute).to contain_exactly(
          public_flow_in_other_org
        )
      end
    end

    context 'when organization and project do not match' do
      let(:params) { { organization: create(:organization), project: project_guest_access } }

      it 'uses the explicit organization parameter and returns no items because organizations do not match' do
        is_expected.to be_empty
      end
    end

    context 'when organization is not provided' do
      let(:params) { {} }

      it 'raises an ArgumentError' do
        expect do
          results
        end.to raise_error(ArgumentError, _('Organization parameter must be specified'))
      end
    end
  end

  context 'when filtering by project' do
    let(:params) { { organization: user.organization, project: [public_flow.project, public_agent.project] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(public_flow, public_agent)
    end
  end

  context 'when filtering by ID' do
    let(:params) { { organization: user.organization, id: [public_flow.id, public_agent.id] } }

    it 'returns the matching items' do
      is_expected.to contain_exactly(public_flow, public_agent)
    end
  end

  context 'when include_foundational_items is set' do
    let(:params) { super().merge(include_foundational_items: true) }

    it 'includes foundational items in the results' do
      expect(results.to_a.pluck(:reference)).to include(*Ai::FoundationalChatAgent.all.select(&:public).map(&:reference))
    end
  end

  context 'when include_foundational_items is not set' do
    it 'excludes foundational items from the results' do
      expect(results.to_a.pluck(:reference)).not_to include(*Ai::FoundationalChatAgent.all.map(&:reference))
    end
  end

  describe 'ordering' do
    # Create additional items in random priority order to ensure ordering is from logic, not creation order
    let_it_be_with_reload(:public_item) { create(:ai_catalog_item, :public, organization: user.organization) }

    let_it_be_with_reload(:foundational_flow) do
      create(:ai_catalog_flow, :with_foundational_flow_reference, :public,
        verification_level: :gitlab_maintained, organization: user.organization)
    end

    let_it_be_with_reload(:foundational_external_agent) do
      create(:ai_catalog_agent, :public, verification_level: :gitlab_maintained, organization: user.organization)
    end

    let(:params) { { organization: user.organization } }

    it 'returns items ordered by priority' do
      result = results.to_a

      # Priority 1: Foundational agents (SaaS only, not applicable here)
      # Priority 2: GitLab-maintained items (foundational flows, external agents)
      # Priority 3: User's project items (guest+ access)
      # Priority 4: Remaining public items
      # Note: Private items of projects user is not a member of are excluded
      expect(result).to eq([
        foundational_external_agent,
        foundational_flow,
        private_third_party_flow_guest_access,
        private_agent_guest_access,
        private_flow_guest_access,
        public_item,
        public_agent,
        public_flow
      ])
    end

    context 'when on SaaS', :saas do
      let_it_be(:foundational_agent) do
        create(:ai_catalog_agent, :public, organization: user.organization)
      end

      before do
        allow(Ai::Catalog::Item).to receive_messages(
          foundational_chat_agent_ids: [foundational_agent.id],
          foundational_external_agent_ids: [foundational_external_agent.id]
        )
        # Foundational external agents on SaaS use hardcoded IDs, making
        # verification_level irrelevant for priority ordering
        foundational_external_agent.update!(verification_level: :unverified)
      end

      it 'returns items ordered by priority with foundational agents first' do
        result = results.to_a

        # Priority 1: Foundational agents (hardcoded IDs)
        # Priority 2: GitLab-maintained items (foundational flows, external agents)
        # Priority 3: User's project items (guest+ access)
        # Priority 4: Remaining public items
        # Note: Private items of projects user is not a member of are excluded
        expect(result).to eq([
          foundational_agent,
          foundational_external_agent,
          foundational_flow,
          private_third_party_flow_guest_access,
          private_agent_guest_access,
          private_flow_guest_access,
          public_item,
          public_agent,
          public_flow
        ])
      end

      context 'with filters applied' do
        it 'maintains priority ordering with item_type filter' do
          result = described_class.new(user, params: params.merge(item_type: 'agent')).execute.to_a

          expect(result).to eq([
            foundational_agent,
            foundational_external_agent,
            private_agent_guest_access,
            public_item,
            public_agent
          ])
        end

        it 'maintains priority ordering with search filter' do
          public_item.update!(name: 'SearchableItem')
          private_third_party_flow_guest_access.update!(name: 'SearchableFlow')
          foundational_external_agent.update!(name: 'SearchableAgent')
          foundational_flow.update!(name: 'SearchableFoundationalFlow')

          result = described_class.new(user, params: params.merge(search: 'Searchable')).execute.to_a

          expect(result).to eq([
            foundational_external_agent,
            foundational_flow,
            private_third_party_flow_guest_access,
            public_item
          ])
        end
      end
    end

    context 'when sort param is provided' do
      before do
        public_flow.update!(last_30_day_usage_count: 50, star_count: 5)
        public_agent.update!(last_30_day_usage_count: 100, star_count: 20)
        public_item.update!(last_30_day_usage_count: 10, star_count: 1)
        private_flow_guest_access.update!(last_30_day_usage_count: 75, star_count: 10)
      end

      context 'with sort: :usage_count_desc' do
        let(:params) { { organization: user.organization, sort: :usage_count_desc } }

        it 'returns items sorted by usage count descending' do
          result = results.to_a

          usage_counts = result.map(&:last_30_day_usage_count)
          expect(usage_counts).to eq(usage_counts.sort.reverse)
        end
      end

      context 'with sort: :usage_count_asc' do
        let(:params) { { organization: user.organization, sort: :usage_count_asc } }

        it 'returns items sorted by usage count ascending' do
          result = results.to_a

          usage_counts = result.map(&:last_30_day_usage_count)
          expect(usage_counts).to eq(usage_counts.sort)
        end
      end

      context 'with sort: :catalog_priority' do
        let(:params) { { organization: user.organization, sort: :catalog_priority } }

        it 'returns items in catalog priority order' do
          result = results.to_a

          expect(result).to eq([
            foundational_external_agent,
            foundational_flow,
            private_third_party_flow_guest_access,
            private_agent_guest_access,
            private_flow_guest_access,
            public_item,
            public_agent,
            public_flow
          ])
        end
      end

      context 'with sort: :star_count_desc' do
        let(:params) { { organization: user.organization, sort: :star_count_desc } }

        it 'returns items sorted by star count descending' do
          result = results.to_a

          star_counts = result.map(&:star_count)
          expect(star_counts).to eq(star_counts.sort.reverse)
        end

        it 'excludes items not visible to user' do
          expect(results).not_to include(private_flow)
        end
      end

      context 'with sort: :star_count_asc' do
        let(:params) { { organization: user.organization, sort: :star_count_asc } }

        it 'returns items sorted by star count ascending' do
          result = results.to_a

          star_counts = result.map(&:star_count)
          expect(star_counts).to eq(star_counts.sort)
        end
      end
    end
  end
end
