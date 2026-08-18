# frozen_string_literal: true

require_relative '../shared'

RSpec.shared_context 'with multiple workspace_variables created' do
  include_context 'with unauthorized workspace created'

  let_it_be_with_reload(:workspace) { create(:workspace, name: 'matching-workspace') }

  let(:id) { workspace.to_global_id.to_s }
  let(:args) { { id: id } }

  let_it_be(:workspace_a_internal_variable) do
    create(:workspace_variable,
      workspace_id: workspace.id,
      key: 'GIT_CONFIG_COUNT',
      value: 'internal_var',
      variable_type: 0,
      user_provided: false
    )
  end

  let_it_be(:workspace_user_env_variable) do
    create(:workspace_variable,
      workspace_id: workspace.id,
      key: 'GIT_CONFIG_KEY_1',
      value: 'user_var_1',
      variable_type: 0,
      user_provided: true
    )
  end

  let_it_be(:workspace_user_file_variable) do
    create(:workspace_variable,
      workspace_id: workspace.id,
      key: 'CONFIG_FILE',
      value: 'user_var_1',
      variable_type: 1,
      user_provided: true
    )
  end

  let_it_be(:unauthorized_workspace_variable) do
    create(:workspace_variable,
      workspace_id: unauthorized_workspace.id,
      key: 'OTHER_VAR',
      value: 'other_var',
      variable_type: 0,
      user_provided: true
    )
  end
end

RSpec.shared_context 'for a Query.workspace.workspaceVariables query' do
  include GraphqlHelpers

  include_context 'with multiple workspace_variables created'
  include_context "with authorized user as developer on workspace's project"

  let(:query) do
    fields = all_graphql_fields_for('WorkspaceVariable')

    graphql_query_for(
      :workspace,
      args,
      query_nodes(:workspace_variables, fields)
    )
  end

  subject(:actual_workspace_variables) { graphql_dig_at(graphql_data, :workspace, :workspace_variables, :nodes) }
end

RSpec.shared_examples 'query returns an array containing all non-internal variables associated with a workspace' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it 'includes only the expected workspace_variables', :unlimited_max_formatted_output_length do
    expect(workspace_variable_keys).not_to include(unauthorized_workspace_variable.key)
    expect(workspace_variable_keys).not_to include(workspace_user_file_variable.key)
    expect(workspace_variable_keys).not_to include(workspace_a_internal_variable.key)

    expect(workspace_variable_keys).to include(workspace_user_env_variable.key)
    expect(workspace_variable_values).to include(workspace_user_env_variable.value)
  end

  it 'includes only the correct type of workspace_variables' do
    expect(workspace_variable_types).to include(
      ::RemoteDevelopment::Enums::WorkspaceVariable::WORKSPACE_VARIABLE_TYPES.key(0).to_s.upcase
    )
    expect(workspace_variable_types).not_to include(
      ::RemoteDevelopment::Enums::WorkspaceVariable::WORKSPACE_VARIABLE_TYPES.key(1).to_s.upcase
    )
  end
end

RSpec.shared_examples 'multiple workspace_variables query' do |authorized_user_is_admin: false|
  include_context 'in licensed environment'

  let(:workspace_variable_keys) { subject.pluck("key") }
  let(:workspace_variable_values) { subject.pluck("value") }
  let(:workspace_variable_types) { subject.pluck("variableType") }

  context 'when user is authorized' do
    include_context 'with authorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns an array containing all non-internal variables associated with a workspace'

    unless authorized_user_is_admin
      context 'when the user requests a workspace that they are not authorized for' do
        let(:id) { global_id_of(unauthorized_workspace) }

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
