# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog item versions', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:private_item) { create(:ai_catalog_item, :private, project: project).latest_version }
  let_it_be_with_reload(:public_items) do
    create_list(:ai_catalog_item, 2, :public, project: project).map(&:latest_version)
  end

  let(:nodes) { graphql_data_at(:ai_catalog_item_versions, :nodes) }
  let(:args) { {} }

  let(:query) do
    "{ #{query_nodes('AiCatalogItemVersions', max_depth: 3, args: args)} }"
  end

  before do
    enable_ai_catalog
  end

  it 'returns public versions' do
    post_graphql(query)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to match_array(public_items.map { |item| a_graphql_entity_for(item) })
  end

  it 'returns only items in the current organization' do
    create(:ai_catalog_item, :public, organization: create(:organization))

    post_graphql(query)

    expect(nodes).to match_array(public_items.map { |item| a_graphql_entity_for(item) })
  end

  describe 'created_after argument' do
    let(:args) { { created_after: Date.tomorrow } }

    it 'returns the matching versions' do
      new_version = create(:ai_catalog_item_version, item: public_items.first.item, created_at: Date.tomorrow + 1.hour)

      post_graphql(query)

      expect(nodes).to contain_exactly(a_graphql_entity_for(new_version))
    end
  end

  describe 'when selecting items' do
    let(:query) do
      <<~GRAPHQL
        {
          aiCatalogItemVersions {
            nodes {
              item {
                id
              }
            }
          }
        }
      GRAPHQL
    end

    it 'avoids N+1 queries' do
      post_graphql(query) # warm up

      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query)
      end

      create(:ai_catalog_item, :public, project: project)

      expect { post_graphql(query) }.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
    end
  end
end
