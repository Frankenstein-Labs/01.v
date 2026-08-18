# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying groups with Knowledge Graph filters', feature_category: :knowledge_graph do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:enabled_group) { create(:group, :private, name: 'enabled-group') }
  let_it_be(:enabled_parent_group) { create(:group, :private, name: 'enabled-parent-group') }
  let_it_be(:enabled_subgroup) { create(:group, :private, parent: enabled_parent_group) }
  let_it_be(:disabled_group) { create(:group, :private, name: 'disabled-group') }

  let(:filters) do
    {
      allAvailable: false,
      topLevelOnly: true,
      withKnowledgeGraphEnabled: true
    }
  end

  let(:query) do
    graphql_query_for(
      :groups,
      filters,
      <<~FIELDS
        nodes {
          name
          knowledgeGraphEnabled
        }
      FIELDS
    )
  end

  before_all do
    create(:knowledge_graph_enabled_namespace, namespace: enabled_group)
    create(:knowledge_graph_enabled_namespace, namespace: enabled_parent_group)
    enabled_group.add_developer(user)
    enabled_parent_group.add_developer(user)
    enabled_subgroup.add_developer(user)
    disabled_group.add_developer(user)
  end

  it 'returns only top-level member groups with Knowledge Graph enabled' do
    post_graphql(query, current_user: user)

    expect_graphql_errors_to_be_empty
    expect(graphql_data_at(:groups, :nodes)).to contain_exactly(
      a_hash_including(
        'name' => enabled_group.name,
        'knowledgeGraphEnabled' => true
      ),
      a_hash_including(
        'name' => enabled_parent_group.name,
        'knowledgeGraphEnabled' => true
      )
    )
  end

  context 'when the Knowledge Graph feature flag is disabled' do
    before do
      stub_feature_flags(knowledge_graph: false)
    end

    it 'returns no groups' do
      post_graphql(query, current_user: user)

      expect_graphql_errors_to_be_empty
      expect(graphql_data_at(:groups, :nodes)).to be_empty
    end
  end
end
