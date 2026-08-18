# frozen_string_literal: true

#-------------------------------------------------
# SHARED CONTEXTS - INDIVIDUAL ARGUMENTS SCENARIOS
#-------------------------------------------------

RSpec.shared_context 'with no arguments' do
  include_context 'with unauthorized workspace created'

  let_it_be_with_reload(:workspace) { create(:workspace, name: 'matching-workspace') }

  # NOTE: Specs including this context must define `non_matching_workspace` as follows:
  #   let_it_be(:non_matching_workspace, freeze: false) { create(:workspace, name: 'non-matching-workspace', ...) }
  # ...or else specify `expected_error_regex` to indicate that no arguments is an error condition

  let(:args) { {} }
end

RSpec.shared_context 'with ids argument' do
  include_context 'with unauthorized workspace created'

  let_it_be_with_reload(:workspace) { create(:workspace, name: 'matching-workspace') }

  # create workspace with different ID but still owned by the same user, to ensure isn't returned by the query
  let_it_be_with_reload(:non_matching_workspace) do
    create(:workspace, user: workspace.user, name: 'non-matching-workspace')
  end

  let(:ids) { [workspace.to_global_id.to_s, unauthorized_workspace.to_global_id.to_s] }
  let(:args) { { ids: ids } }
end

RSpec.shared_context 'with project_ids argument' do
  include_context 'with unauthorized workspace created'

  let_it_be(:project, freeze: false) { create(:project, :public) }
  let_it_be_with_reload(:workspace) { create(:workspace, project_id: project.id, name: 'matching-workspace') }

  # create workspace with different project but still owned by the same user, to ensure isn't returned by the query
  let_it_be_with_reload(:non_matching_workspace) do
    create(:workspace, user: workspace.user, name: 'non-matching-workspace')
  end

  let(:project_ids) { [project.to_global_id.to_s, unauthorized_workspace.project.to_global_id.to_s] }
  let(:args) { { project_ids: project_ids } }
end

RSpec.shared_context 'with agent_ids argument' do
  include_context 'with unauthorized workspace created'

  let_it_be(:agent, freeze: false) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let_it_be_with_reload(:workspace) { create(:workspace, agent: agent, name: 'matching-workspace') }

  include_context 'with non_matching_workspace associated with other agent created'

  let(:agent_ids) { [agent.to_global_id.to_s, unauthorized_workspace.agent.to_global_id.to_s] }
  let(:args) { { agent_ids: agent_ids } }
end

RSpec.shared_context 'with actual_states argument' do
  let_it_be(:matching_actual_state, freeze: false) { ::RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED }

  include_context 'with unauthorized workspace created'

  let_it_be_with_reload(:workspace) do
    create(:workspace, actual_state: matching_actual_state, name: 'matching-workspace')
  end

  # create workspace with non-matching actual state, to ensure it is not returned by the query
  let_it_be(:non_matching_actual_state, freeze: false) { ::RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let_it_be_with_reload(:non_matching_workspace) do
    create(:workspace, actual_state: non_matching_actual_state, user: workspace.user, name: 'non-matching-workspace')
  end

  let(:args) { { actual_states: [matching_actual_state] } }

  before do
    unauthorized_workspace.update!(actual_state: matching_actual_state)
  end
end

#------------------------------------------------
# SHARED EXAMPLES - MAIN ENTRY POINTS FOR TESTING
#------------------------------------------------

RSpec.shared_examples 'multiple workspaces query' do |authorized_user_is_admin: false, expected_error_regex: nil|
  include_context 'in licensed environment'

  let(:workspace_names) { subject.pluck("name") }

  context 'when user is authorized' do
    include_context 'with authorized user as current user'

    if expected_error_regex
      it_behaves_like 'query returns blank'
      it_behaves_like 'query includes graphql error', expected_error_regex
    else
      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns workspaces array containing only expected workspace'
    end

    unless authorized_user_is_admin
      context 'when the user requests a workspace that they are not authorized for' do
        before do
          post_graphql(query, current_user: current_user)
        end

        it 'does not return the unauthorized workspace' do
          expect(workspace_names).not_to include(unauthorized_workspace.name)
        end

        it 'still returns the authorized workspace' do
          expect(workspace_names).to include(workspace.name)
        end
      end
    end
  end

  context 'when user is not authorized' do
    include_context 'with unauthorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns blank' unless authorized_user_is_admin
  end

  it_behaves_like 'query in unlicensed environment'
end

#----------------------------------
# SHARED CONTEXTS - BUILDING BLOCKS
#----------------------------------

RSpec.shared_context 'with authorized user as current user' do
  let_it_be(:current_user, freeze: false) { authorized_user }
end

RSpec.shared_context "with authorized user as developer on workspace's project" do
  # NOTE: Currently, the :read_workspace ability will only be enabled if the user has developer access to the
  #       workspace's project. This will be revisited as part of https://gitlab.com/groups/gitlab-org/-/epics/10272
  before do
    workspace.project.add_developer(authorized_user)
  end
end

RSpec.shared_context 'with unauthorized user as current user' do
  let_it_be(:current_user, freeze: false) { unauthorized_user }
end

RSpec.shared_context 'with other workspace created' do
  # This workspace will only be accessible by admins
  let_it_be(:other_workspace, freeze: false) { create(:workspace, name: 'other-workspace') }
end

RSpec.shared_context 'with non_matching_workspace associated with same agent' do
  before do
    # Ensure the non-matching workspace is also associated with the same agent
    non_matching_workspace.update!(agent: agent)
    non_matching_workspace.reload
  end
end

RSpec.shared_context 'with non_matching_workspace associated with other agent created' do
  # create workspace associated with different agent but owned by same user, to ensure isn't returned by the query
  let_it_be(:other_agent, freeze: false) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let_it_be_with_reload(:non_matching_workspace) do
    create(:workspace, agent: other_agent, user: workspace.user, name: 'non-matching-workspace')
  end
end

RSpec.shared_context 'with unauthorized workspace created' do
  # The authorized_user will not be authorized to see the `other-workspace`. We don't name it
  # `unauthorized-workspace`, because the admin is still authorized to see it.
  include_context 'with other workspace created'

  let_it_be(:unauthorized_workspace, freeze: false) { other_workspace }
end

RSpec.shared_context 'in licensed environment' do
  before do
    stub_licensed_features(remote_development: true)
  end
end

RSpec.shared_context 'in unlicensed environment' do
  before do
    stub_licensed_features(remote_development: false)
  end
end

#----------------------------------
# SHARED EXAMPLES - BUILDING BLOCKS
#----------------------------------

RSpec.shared_examples 'query is a working graphql query' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it_behaves_like 'a working graphql query'
end

RSpec.shared_examples 'query returns single workspace' do
  include GraphqlHelpers

  before do
    post_graphql(query, current_user: current_user)
  end

  it { expect(subject['name']).to eq(workspace.name) }
end

RSpec.shared_examples 'query returns workspaces array containing only expected workspace' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it 'includes only the expected workspace', :unlimited_max_formatted_output_length do
    expect(workspace_names).not_to include(non_matching_workspace.name)
    expect(workspace_names).to include(workspace.name)
  end
end

RSpec.shared_examples 'query returns blank' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it { is_expected.to be_blank }
end

RSpec.shared_examples 'query has empty graphql errors' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it 'has empty graphql errors' do
    expect_graphql_errors_to_be_empty
  end
end

RSpec.shared_examples 'query includes graphql error' do |regexes_to_match|
  before do
    post_graphql(query, current_user: current_user)
  end

  it 'includes a graphql error' do
    expect_graphql_errors_to_include(regexes_to_match)
  end
end

RSpec.shared_examples 'query in unlicensed environment' do
  context 'when remote_development feature is unlicensed' do
    include_context 'in unlicensed environment'

    context 'when user is authorized' do
      include_context 'with authorized user as current user'

      it_behaves_like 'query returns blank'
      it_behaves_like 'query includes graphql error', /'remote_development' licensed feature is not available/
    end
  end
end
