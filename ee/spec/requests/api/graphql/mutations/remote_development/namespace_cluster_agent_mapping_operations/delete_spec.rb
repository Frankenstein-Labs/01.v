# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Remove existing mapping between a cluster and a group', feature_category: :workspaces do
  include GraphqlHelpers
  include StubFeatureFlags

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:namespace) { create(:group, owners: user) }
  let_it_be_with_reload(:agent) { create(:cluster_agent, project: create(:project, group: namespace)) }

  let(:mutation) do
    graphql_mutation(:namespace_delete_remote_development_cluster_agent_mapping, mutation_args)
  end

  let(:mutation_response) do
    graphql_mutation_response(:namespace_delete_remote_development_cluster_agent_mapping)
  end

  let(:stub_service_payload) { { namespace_cluster_agent_mapping: deleted_mapping } }
  let(:stub_service_response) do
    ServiceResponse.success(payload: stub_service_payload)
  end

  let(:deleted_mapping) do
    create(:namespace_cluster_agent_mapping, namespace: namespace, agent: agent)
  end

  let(:all_mutation_args) do
    {
      namespace_id: namespace.to_global_id.to_s,
      cluster_agent_id: agent.to_global_id.to_s
    }
  end

  let(:mutation_args) { all_mutation_args }

  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Delete::Main,
      domain_main_class_args: {
        namespace: namespace,
        cluster_agent: agent
      }
    }
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'with granular token authorization' do
    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).and_return(stub_service_response)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_cluster_agent_mapping do
      let(:boundary_object) { namespace }
      let(:mutation) do
        graphql_mutation(:namespace_delete_remote_development_cluster_agent_mapping, all_mutation_args, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when the params are valid' do
    shared_examples 'a successful mutation' do
      it 'deletes a mapping' do
        expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
          stub_service_response
        end

        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_be_empty
        expect(mutation_response.dig('namespaceClusterAgentMapping', 'id')).not_to be_empty
      end
    end

    context 'when user has owner access to the group' do
      it_behaves_like 'a successful mutation'
    end

    context 'when user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'a successful mutation'
    end
  end

  context 'when a user does not have sufficient permissions' do
    # User is added as a maintainer as all users with roles
    # Maintainer and below are denied the use of this API
    let_it_be(:current_user) { create(:user, maintainer_of: namespace) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when the namespace being passed is a user namespace' do
    let_it_be(:namespace) { current_user.namespace }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/does not represent an instance of Group/)
    end
  end

  context 'when the namespace being passed is a project namespace' do
    let_it_be(:namespace) { agent.project.project_namespace }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/does not represent an instance of Group/)
    end
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

  context "when the group doesn't exist" do
    let(:namespace) { build_stubbed(:group) }

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
