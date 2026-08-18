# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Updating a workspace', feature_category: :workspaces do
  include GraphqlHelpers

  include_context "with constant modules"

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:project) do
    create(:project, :public, :in_group, :repository, developers: user)
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent,
      :with_existing_workspaces_agent_config).tap { |agent| agent.project.add_developer(user) }
  end

  let_it_be_with_refind(:workspace) do
    create(
      :workspace,
      agent: agent,
      project: project,
      user: user,
      desired_state: states_module::RUNNING
    )
  end

  let(:all_mutation_args) do
    {
      id: workspace.to_global_id.to_s,
      desired_state: states_module::STOPPED
    }
  end

  let(:mutation_args) do
    { id: global_id_of(workspace), desired_state: states_module::STOPPED }
  end

  let(:mutation) { graphql_mutation(:workspace_update, mutation_args) }
  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::WorkspaceOperations::Update::Main,
      domain_main_class_args: {
        user: current_user,
        workspace: workspace,
        params: all_mutation_args.except(:id)
      }
    }
  end

  let(:stub_service_payload) { { workspace: workspace } }
  let(:stub_service_response) do
    ServiceResponse.success(payload: stub_service_payload)
  end

  # @return [String]
  def mutation_response
    graphql_mutation_response(:workspace_update)
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'with granular token authorization' do
    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).and_return(stub_service_response)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_workspace do
      let(:boundary_object) { project }
      let(:mutation) { graphql_mutation(:workspace_update, all_mutation_args, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  it 'updates the workspace' do
    expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
      stub_service_response
    end

    post_graphql_mutation(mutation, current_user: user)

    expect_graphql_errors_to_be_empty

    expect(mutation_response.fetch('workspace')['name']).to eq(workspace['name'])
  end

  context 'when there are service errors' do
    let(:stub_service_response) { ::ServiceResponse.error(message: 'some error', reason: :bad_request) }

    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
        stub_service_response
      end
    end

    it_behaves_like 'a mutation that returns errors in the response', errors: ['some error']
  end

  context 'when some required arguments are missing' do
    let(:mutation_args) { all_mutation_args.except(:desired_state) }

    it 'returns error about required argument' do
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include(/provided invalid value for desiredState \(Expected value to not be null\)/)
    end
  end

  context 'when the user cannot create a workspace for the project' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when remote_development feature is unlicensed' do
    before do
      stub_licensed_features(remote_development: false)
    end

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/'remote_development' licensed feature is not available/) }
    end
  end
end
