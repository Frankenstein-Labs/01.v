# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project.aiCatalogItems', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest_user) { create(:user) }
  let_it_be(:developer_user) { create(:user) }
  let_it_be(:project) { create(:project, developers: developer_user, guests: guest_user) }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:flow) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }

  let_it_be(:private_agent_of_other_project) { create(:ai_catalog_agent, :private, project: other_project) }
  let_it_be(:public_agent_of_other_project) { create(:ai_catalog_agent, :public, project: other_project) }

  let(:current_user) { developer_user }
  let(:args) { {} }

  let(:nodes) { graphql_data_at(:project, :ai_catalog_items, :nodes) }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(
        :ai_catalog_items,
        attributes_to_graphql(args).to_s,
        query_graphql_field(:nodes, {}, all_graphql_fields_for('AiCatalogItem'))
      )
    )
  end

  subject(:execute_query) { post_graphql(query, current_user: current_user) }

  shared_examples 'returns success' do
    it 'returns success' do
      execute_query
      expect(response).to have_gitlab_http_status(:success)
    end
  end

  before do
    enable_ai_catalog
  end

  context 'without filters' do
    it_behaves_like 'returns success'

    it 'returns project items' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(flow),
        a_graphql_entity_for(agent)
      )
    end
  end

  context 'when user is a guest+ of the project' do
    let(:current_user) { guest_user }

    it_behaves_like 'returns success'

    it 'returns only accessible items' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(agent)
      )
    end
  end

  context 'when user has no access to the project' do
    let(:current_user) { create(:user) }

    it_behaves_like 'returns success'

    it 'returns no items' do
      execute_query

      expect(nodes).to be_nil
    end
  end

  context 'when filtering by `item_types`' do
    let(:args) { { item_types: [:AGENT] } }

    it 'returns only agents' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(agent)
      )
    end
  end

  context 'when filtering by `enabled`' do
    let(:args) { { enabled: true } }

    before_all do
      create(:ai_catalog_item_consumer, item: flow, project: project)
    end

    it 'returns enabled items only' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(flow)
      )
    end
  end

  context 'when filtering by `all_available`' do
    let(:args) { { all_available: true } }

    it 'returns all available items including public ones' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(agent),
        a_graphql_entity_for(flow),
        a_graphql_entity_for(public_agent_of_other_project)
      )
    end
  end

  context 'when filtering by `search`' do
    let(:args) { { search: 'triage' } }

    let_it_be(:issue_label_agent) do
      create(:ai_catalog_agent, name: 'Autotriager', project: project)
    end

    let_it_be(:mr_review_flow) do
      create(:ai_catalog_flow, project: project, description: 'Flow to triage issues')
    end

    it 'returns items matching name or description' do
      execute_query

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(issue_label_agent),
        a_graphql_entity_for(mr_review_flow)
      )
    end
  end
end
