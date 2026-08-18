# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog custom and foundational items', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:deleted_catalog_item) { create(:ai_catalog_item, :public, project: project, deleted_at: 1.day.ago) }
  let(:nodes) { graphql_data_at(:ai_catalog_custom_and_foundational_items, :nodes) }
  let(:custom_items_nodes) { nodes&.reject { |n| n['id']&.include?('FoundationalChatAgent') } }
  let(:foundational_items_nodes) { nodes&.select { |n| n['id']&.include?('FoundationalChatAgent') } }
  let(:current_user) { nil }
  let(:args) { {} }

  let(:item_fields) do
    <<~FIELDS
      ... on AiCatalogItem { id }
      ... on AiFoundationalChatAgent { id }
    FIELDS
  end

  let(:query) do
    "{ #{query_nodes('aiCatalogCustomAndFoundationalItems', item_fields, args: args)} }"
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'a successful query' do
    it 'returns not deleted AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(custom_items_nodes).to match_array(catalog_items.map { |item| a_graphql_entity_for(item) })

      foundational_agent_global_ids = Ai::FoundationalChatAgent.all.select(&:public).map do |foundational_agent|
        Gitlab::GlobalId.as_global_id(foundational_agent.to_global_id, model_name: "Ai::FoundationalChatAgent").to_s
      end

      expect(foundational_items_nodes.pluck('id')).to match_array(foundational_agent_global_ids)
    end
  end

  context 'with public catalog items' do
    let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2, :public, project: project) }

    it_behaves_like 'a successful query'
  end

  context 'with private catalog items' do
    let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2, project: project) }

    context 'when guest' do
      let(:current_user) do
        create(:user).tap { |user| project.add_guest(user) }
      end

      it_behaves_like 'a successful query'
    end

    context 'when not a member' do
      let(:current_user) { create(:user) }

      it 'returns only foundational AI catalog items' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(custom_items_nodes).to be_empty
        expect(foundational_items_nodes).not_to be_empty
      end
    end

    context 'when anonymous' do
      let(:current_user) { nil }

      it 'returns only foundational AI catalog items' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(custom_items_nodes).to be_empty
        expect(foundational_items_nodes).not_to be_empty
      end
    end
  end

  context 'when selecting versions and their created by users' do
    let(:version_fields) do
      <<~FIELDS
        versions {
          nodes {
            createdBy { username }
          }
        }
        latestVersion {
          createdBy { username }
        }
      FIELDS
    end

    let(:query) do
      <<~GRAPHQL
        {
          aiCatalogCustomAndFoundationalItems {
            nodes {
              ... on AiCatalogItem { #{version_fields} }
            }
          }
        }
      GRAPHQL
    end

    it 'avoids N+1 database queries' do
      catalog_item_1, catalog_item_2 = create_list(:ai_catalog_item, 2, :public, project: project)
      catalog_item_1.latest_version.update!(created_by: create(:user))

      post_graphql(query, current_user: nil) # Warm up

      expect(graphql_data_at(:ai_catalog_custom_and_foundational_items, :nodes, :versions, :nodes).size).to eq(2)

      control_count = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: nil)
      end

      create(:ai_catalog_item_version, item: catalog_item_1, version: '1.0.1', created_by: create(:user))
      create(:ai_catalog_item_version, item: catalog_item_2, version: '1.0.1', created_by: create(:user))

      expect do
        post_graphql(query, current_user: nil)
      end.not_to exceed_query_limit(control_count)

      expect(graphql_data_at(:ai_catalog_custom_and_foundational_items, :nodes, :versions, :nodes).size).to eq(4)
      expect(graphql_data_at(:ai_catalog_custom_and_foundational_items, :nodes, :latest_version).compact.size).to eq(2)
    end
  end

  describe 'item_types argument' do
    let_it_be(:agent_type_item) { create(:ai_catalog_item, :public, item_type: :agent, project: project) }
    let_it_be(:flow_type_item) { create(:ai_catalog_item, :public, item_type: :flow, project: project) }
    let_it_be(:third_party_flow_type_item) do
      create(:ai_catalog_item, :public, item_type: :third_party_flow, project: project)
    end

    context 'when not provided' do
      it 'returns all catalog items' do
        post_graphql(query, current_user: current_user)

        expect(custom_items_nodes).to contain_exactly(
          a_graphql_entity_for(agent_type_item),
          a_graphql_entity_for(flow_type_item),
          a_graphql_entity_for(third_party_flow_type_item)
        )
      end
    end

    context 'when flow AND third_party_flow' do
      let(:args) { { item_types: %i[FLOW THIRD_PARTY_FLOW] } }

      it 'returns only flows and third party flows' do
        post_graphql(query, current_user: current_user)

        expect(nodes).to contain_exactly(
          a_graphql_entity_for(flow_type_item), a_graphql_entity_for(third_party_flow_type_item)
        )
      end
    end
  end

  it 'returns only items in the current organization' do
    item = create(:ai_catalog_item, :public, organization: current_organization)
    create(:ai_catalog_item, :public, organization: create(:organization))

    post_graphql(query, current_user: nil)

    expect(custom_items_nodes).to contain_exactly(a_graphql_entity_for(item))
  end

  describe 'search argument' do
    let_it_be(:issue_label_agent) { create(:ai_catalog_agent, :public, name: 'Autotriager', project: project) }
    let_it_be(:mr_review_flow) { create(:ai_catalog_flow, :public, description: 'MR reviewer', project: project) }

    context 'when matches part of an item name' do
      let(:args) { { search: 'triage' } }

      it 'returns the matching items' do
        post_graphql(query, current_user: current_user)

        expect(custom_items_nodes).to contain_exactly(a_graphql_entity_for(issue_label_agent))
      end
    end

    context 'when matches part of an item description' do
      let(:args) { { search: 'review' } }

      it 'returns the matching items' do
        post_graphql(query, current_user: current_user)

        expect(custom_items_nodes).to contain_exactly(a_graphql_entity_for(mr_review_flow))
      end
    end
  end

  context 'when isEnabledInManagedByProject field call limit is exceeded' do
    let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2, :public, project: project) }

    let(:query) do
      <<~GRAPHQL
      {
        aiCatalogCustomAndFoundationalItems {
          nodes {
            ... on AiCatalogItem {
              id
              isEnabledInManagedByProject
            }
          }
        }
      }
      GRAPHQL
    end

    it 'returns nil items for all but one, when isEnabledInManagedByProject field call limit is exceeded' do
      post_graphql(query, current_user: nil)
      nodes = graphql_data_at(:ai_catalog_custom_and_foundational_items, :nodes)

      values = nodes.map do |node|
        next if node.nil?

        node['isEnabledInManagedByProject']
      end

      # Expect at least one of the nodes to have the field nulled out once limit: 1 is exceeded
      expect(values.compact.size).to eq(1)
      expect(values).to include(nil)
      expect_graphql_errors_to_include(
        '"isEnabledInManagedByProject" field can be requested only for 1 AiCatalogItem(s) at a time.'
      )
    end
  end
end
