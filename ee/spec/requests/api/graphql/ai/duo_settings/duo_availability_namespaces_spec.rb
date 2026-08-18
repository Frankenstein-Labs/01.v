# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying admin Duo availability namespaces', feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:parent) { create(:group, name: 'parent') }
  let_it_be_with_reload(:child) { create(:group, name: 'child', parent: parent) }

  let(:current_user) { admin }

  let(:query) do
    graphql_query_for(
      :adminDuoAvailabilityNamespaces,
      {},
      "nodes { id fullPath duoAvailability inheritedValue adminLocked lockedByAncestor { fullPath } }"
    )
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  def nodes
    graphql_data.dig('adminDuoAvailabilityNamespaces', 'nodes')
  end

  context 'when the current user is not an admin' do
    let(:current_user) { user }

    it 'returns a null connection' do
      request

      expect(graphql_data['adminDuoAvailabilityNamespaces']).to be_nil
    end
  end

  context 'when the current user is an admin', :enable_admin_mode do
    it 'returns the groups with resolved availability' do
      request

      full_paths = nodes.map { |node| node['fullPath'] }
      expect(full_paths).to include(parent.full_path, child.full_path)
    end

    it 'avoids N+1 queries' do
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      create(:group, name: 'extra', parent: parent)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end
end
