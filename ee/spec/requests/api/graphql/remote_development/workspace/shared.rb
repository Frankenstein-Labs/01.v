# frozen_string_literal: true

require_relative '../shared'

RSpec.shared_context 'with id arg' do
  include_context 'with unauthorized workspace created'

  let_it_be_with_reload(:workspace) { create(:workspace, name: 'matching-workspace') }

  # create workspace with different ID but still owned by the same user, to ensure isn't returned by the query
  let_it_be_with_reload(:non_matching_workspace) do
    create(:workspace, user: workspace.user, name: 'non-matching-workspace')
  end

  let(:id) { workspace.to_global_id.to_s }
  let(:args) { { id: id } }
end

RSpec.shared_context 'for a Query.workspace query' do
  include GraphqlHelpers

  include_context "with authorized user as developer on workspace's project"

  let(:fields) do
    <<~QUERY
      #{all_graphql_fields_for('workspace'.classify, max_depth: 1)}
    QUERY
  end

  let(:query) { graphql_query_for('workspace', args, fields) }

  subject(:actual_workspace) { graphql_data['workspace'] }
end

RSpec.shared_examples 'single workspace query' do |authorized_user_is_admin: false|
  include_context 'in licensed environment'

  context 'when user is authorized' do
    include_context 'with authorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns single workspace'

    unless authorized_user_is_admin
      context 'when the user requests a workspace that they are not authorized for' do
        let(:id) { unauthorized_workspace.to_global_id.to_s }

        it_behaves_like 'query is a working graphql query'
        it_behaves_like 'query returns blank'
      end
    end
  end

  context 'when user is not authorized' do
    include_context 'with unauthorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns blank'
  end

  it_behaves_like 'query in unlicensed environment'
end
