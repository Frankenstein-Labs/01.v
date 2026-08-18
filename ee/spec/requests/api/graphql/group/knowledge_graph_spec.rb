# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Knowledge Graph fields on a group', feature_category: :knowledge_graph do
  include GraphqlHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:current_user) { owner }
  let(:query) do
    graphql_query_for(
      'group',
      { 'fullPath' => group.full_path },
      <<~FIELDS
        knowledgeGraphEnabled
        knowledgeGraphAvailable
      FIELDS
    )
  end

  before_all do
    group.add_owner(owner)
    group.add_maintainer(maintainer)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    stub_licensed_features(orbit: true)
  end

  shared_examples 'a successful Knowledge Graph field query' do
    it 'returns the expected Knowledge Graph field values' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(graphql_data_at(:group)).to include(expected_fields)
    end
  end

  context 'when the namespace is enabled' do
    let(:expected_fields) do
      {
        'knowledgeGraphEnabled' => true,
        'knowledgeGraphAvailable' => true
      }
    end

    before do
      create(:knowledge_graph_enabled_namespace, namespace: group)
    end

    it_behaves_like 'a successful Knowledge Graph field query'
  end

  context 'when the namespace is not enabled' do
    let(:expected_fields) do
      {
        'knowledgeGraphEnabled' => false,
        'knowledgeGraphAvailable' => true
      }
    end

    it_behaves_like 'a successful Knowledge Graph field query'
  end

  context 'when the feature flag is disabled' do
    let(:expected_fields) do
      {
        'knowledgeGraphEnabled' => false,
        'knowledgeGraphAvailable' => false
      }
    end

    before do
      stub_feature_flags(knowledge_graph: false)
      create(:knowledge_graph_enabled_namespace, namespace: group)
    end

    it_behaves_like 'a successful Knowledge Graph field query'
  end

  context 'when the current user cannot update the Knowledge Graph setting' do
    let(:current_user) { maintainer }
    let(:expected_fields) do
      {
        'knowledgeGraphEnabled' => false,
        'knowledgeGraphAvailable' => false
      }
    end

    it_behaves_like 'a successful Knowledge Graph field query'
  end

  context 'when group is not a root namespace' do
    let_it_be(:subgroup) { create(:group, parent: group) }

    let(:query) do
      graphql_query_for(
        'group',
        { 'fullPath' => subgroup.full_path },
        <<~FIELDS
          knowledgeGraphEnabled
          knowledgeGraphAvailable
        FIELDS
      )
    end

    let(:expected_fields) do
      {
        'knowledgeGraphEnabled' => false,
        'knowledgeGraphAvailable' => false
      }
    end

    before_all do
      subgroup.add_owner(owner)
    end

    it_behaves_like 'a successful Knowledge Graph field query'
  end

  context 'when on self-managed' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    context 'when namespace is enrolled and user is an owner' do
      let(:expected_fields) do
        {
          'knowledgeGraphEnabled' => true,
          'knowledgeGraphAvailable' => true
        }
      end

      before do
        create(:knowledge_graph_enabled_namespace, namespace: group)
      end

      it_behaves_like 'a successful Knowledge Graph field query'
    end

    context 'when namespace is not enrolled and user is an owner' do
      let(:expected_fields) do
        {
          'knowledgeGraphEnabled' => false,
          'knowledgeGraphAvailable' => true
        }
      end

      it_behaves_like 'a successful Knowledge Graph field query'
    end

    context 'when user is a maintainer' do
      let(:current_user) { maintainer }
      let(:expected_fields) do
        {
          'knowledgeGraphEnabled' => false,
          'knowledgeGraphAvailable' => false
        }
      end

      it_behaves_like 'a successful Knowledge Graph field query'
    end

    context 'when orbit license is not available' do
      let(:expected_fields) do
        {
          'knowledgeGraphEnabled' => false,
          'knowledgeGraphAvailable' => false
        }
      end

      before do
        stub_licensed_features(orbit: false)
      end

      it_behaves_like 'a successful Knowledge Graph field query'
    end
  end
end
