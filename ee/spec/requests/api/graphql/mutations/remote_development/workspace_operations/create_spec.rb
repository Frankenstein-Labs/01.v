# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Creating a workspace', feature_category: :workspaces do
  include GraphqlHelpers

  include_context "with constant modules"

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:workspace_ancestor_namespace) { create(:group, parent: root_namespace) }
  let_it_be(:workspace_project) do
    create(:project, :public, :repository, developers: user, group: workspace_ancestor_namespace)
      .tap do |project|
      project.add_developer(user)
    end
  end

  let_it_be(:agent_project) do
    create(:project, :public, :repository, developers: user, group: workspace_ancestor_namespace)
      .tap do |project|
      project.add_developer(user)
    end
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be_with_refind(:created_workspace) do
    create(:workspace, user: user, project: workspace_project)
  end

  let(:desired_state) { states_module::RUNNING }
  let(:devfile_path) { '.devfile.yaml' }

  let(:variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT', variable_type: 'ENVIRONMENT' },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT', variable_type: 'ENVIRONMENT' }
    ]
  end

  let(:service_class_expected_variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT', variable_type: 0 },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT', variable_type: 0 }
    ]
  end

  let(:base_mutation_args) do
    {
      desired_state: desired_state,
      editor: 'webide',
      cluster_agent_id: agent.to_global_id.to_s,
      project_id: workspace_project.to_global_id.to_s,
      project_ref: 'main',
      devfile_path: devfile_path,
      workspace_variables: variables
    }
  end

  let(:expected_service_params) do
    params = {
      desired_state: desired_state,
      editor: 'webide',
      project_ref: 'main',
      devfile_path: devfile_path,
      variables: variables
    }

    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    params[:variables] = service_class_expected_variables
    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    params[:agent] = agent
    params[:user] = current_user
    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    params[:project] = workspace_project

    params
  end

  let(:mutation_args) { base_mutation_args }

  let(:mutation) do
    graphql_mutation(:workspace_create, mutation_args)
  end

  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::WorkspaceOperations::Create::Main,
      domain_main_class_args: {
        user: current_user,
        params: expected_service_params,
        vscode_extension_marketplace_metadata: { enabled: true },
        vscode_extension_marketplace: { some_setting: "some-value" }
      }
    }
  end

  let(:stub_service_payload) { { workspace: created_workspace } }
  let(:stub_service_response) do
    ServiceResponse.success(payload: stub_service_payload)
  end

  # @return [Object]
  def mutation_response
    graphql_mutation_response(:workspace_create)
  end

  before do
    stub_licensed_features(remote_development: true)

    allow(WebIde::Settings)
      .to receive(:get).with(
        [:vscode_extension_marketplace_metadata, :vscode_extension_marketplace],
        user: current_user
      ).and_return(
        {
          vscode_extension_marketplace_metadata: { enabled: true },
          vscode_extension_marketplace: { some_setting: "some-value" }
        }
      )

    # reload projects, so any local debugging performed in the tests has the correct state
    workspace_project.reload
    agent_project.reload
  end

  context 'with granular token authorization' do
    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).and_return(stub_service_response)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_workspace do
      let(:user) { current_user }
      let(:boundary_object) { workspace_project }
      let(:mutation) { graphql_mutation(:workspace_create, base_mutation_args, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when correct arguments are provided' do
    shared_examples 'successful create' do
      it 'creates the workspace with expected args' do
        expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
          stub_service_response
        end

        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_be_empty

        expect(mutation_response.fetch('workspace')['name']).to eq(created_workspace['name'])
      end
    end

    context 'when all required arguments are present' do
      it_behaves_like 'successful create'
    end

    describe 'devfile_path behavior' do
      context 'when devfile_path is nil' do
        let(:devfile_path) { nil }

        it_behaves_like 'successful create'
      end

      context 'when devfile_path is not present' do
        let(:devfile_path) { nil }
        let(:mutation_args) { base_mutation_args.except(:devfile_path) }

        it_behaves_like 'successful create'
      end
    end

    context 'when project_ref is not present and devfile_ref is present' do
      let(:mutation_args) do
        base_mutation_args.except(:project_ref).merge(devfile_ref: 'main')
      end

      it_behaves_like 'successful create'
    end

    context 'when project_ref and devfile_ref are both present' do
      let(:mutation_args) { base_mutation_args.merge(devfile_ref: 'main1') }

      it_behaves_like 'successful create'
    end

    describe 'deprecated fields behavior' do
      context 'when project_ref is not present and devfile_ref is present' do
        let(:mutation_args) do
          base_mutation_args.except(:project_ref).merge(devfile_ref: 'main')
        end

        it_behaves_like 'successful create'
      end

      context 'when project_ref and devfile_ref are both present' do
        let(:mutation_args) { base_mutation_args.merge(devfile_ref: 'main1') }

        it_behaves_like 'successful create'
      end

      context 'when workspace_variables is not present and variables is present' do
        let(:mutation_args) { base_mutation_args.except(:workspace_variables).merge(variables: variables) }

        it_behaves_like 'successful create'
      end

      context 'when workspace_variables and variables are both present' do
        let(:mutation_args) { base_mutation_args.merge(variables: variables) }

        it_behaves_like 'successful create'
      end
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
  end

  context 'when required arguments are missing' do
    context 'when validates against GraphQL not allow null behaviour' do
      let(:mutation_args) { base_mutation_args.except(:desired_state) }

      it 'returns error about required argument' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/provided invalid value for desiredState \(Expected value to not be null\)/)
      end
    end

    context 'when both project_ref and devfile_ref not present' do
      let(:mutation_args) { base_mutation_args.except(:project_ref, :devfile_ref) }

      it 'returns error about required argument' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/Either 'project_ref' or deprecated 'devfile_ref' must be provided./)
      end
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
