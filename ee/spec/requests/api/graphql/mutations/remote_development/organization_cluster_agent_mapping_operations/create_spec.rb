# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Mutation.organizationCreateClusterAgentMapping', feature_category: :workspaces do
  include GraphqlHelpers
  include StubFeatureFlags

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project.organization) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:organization) { project.organization }
  let_it_be(:agent_project) { create(:project) }
  let_it_be_with_reload(:agent) { create(:cluster_agent, project: agent_project) }

  let(:mutation) do
    graphql_mutation(:organization_create_cluster_agent_mapping, mutation_args)
  end

  let(:stub_service_payload) { { organization_cluster_agent_mapping: created_mapping } }
  let(:stub_service_response) { ServiceResponse.success(payload: stub_service_payload) }

  let(:created_mapping) do
    instance_double(RemoteDevelopment::OrganizationClusterAgentMapping)
  end

  let(:all_mutation_args) do
    {
      organization_id: organization.to_global_id.to_s,
      cluster_agent_id: agent.to_global_id.to_s
    }
  end

  let(:mutation_args) { all_mutation_args }
  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Create::Main,
      domain_main_class_args: {
        organization: organization,
        agent: agent,
        user: current_user
      }
    }
  end

  # @return [Object]
  def mutation_response
    graphql_mutation_response(:organization_create_cluster_agent_mapping)
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'with granular token authorization' do
    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).and_return(stub_service_response)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cluster_agent_mapping do
      let(:boundary_object) { :instance }
      let(:mutation) do
        graphql_mutation(:organization_create_cluster_agent_mapping, all_mutation_args, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when the params are valid' do
    RSpec.shared_examples 'creates a mapping' do
      it 'creates a mapping', :aggregate_failures do
        expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
          stub_service_response
        end

        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user has owner access to the organization containing the agent' do
      it_behaves_like 'creates a mapping'
    end

    context 'when user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'creates a mapping'
    end
  end

  context 'when a user does not have sufficient permissions' do
    # User is added as an owner of the agent project in the org.
    # Project owners do not have permission to control org mappings.
    let_it_be(:current_user) { create(:user, owner_of: project) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when a service error is returned' do
    let(:stub_service_response) { ::ServiceResponse.error(message: 'some error', reason: :bad_request) }

    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
        stub_service_response
      end
    end

    it_behaves_like 'a mutation that returns errors in the response', errors: ['some error']
  end

  context 'when the required arguments are missing' do
    let(:mutation_args) { all_mutation_args.except(:cluster_agent_id) }

    it 'returns error about required argument' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/provided invalid value for clusterAgentId \(Expected value to not be null\)/)
    end
  end

  context "when the cluster agent doesn't exist" do
    let(:agent) { build_stubbed(:cluster_agent) }

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/are attempting to access does not exist/) }
    end
  end

  context "when the organization doesn't exist" do
    let(:organization) { build_stubbed(:organization) }

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/are attempting to access does not exist/) }
    end
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
