# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'OrbitUpdate mutation', feature_category: :knowledge_graph do
  include GraphqlHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:current_user) { owner }

  let(:mutation) do
    graphql_mutation(:orbit_update, input)
  end

  def mutation_response
    graphql_mutation_response(:orbit_update)
  end

  before_all do
    group.add_owner(owner)
    group.add_developer(developer)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    stub_feature_flags(knowledge_graph: true)
    stub_licensed_features(orbit: true)
    stub_config(knowledge_graph: { 'enabled' => true })
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_knowledge_graph_setting do
    let(:user) { owner }
    let(:boundary_object) { group }
    let(:input) { { group_path: group.full_path, enabled: true } }
    let(:mutation) { graphql_mutation(:orbit_update, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when enabling' do
    let(:input) { { group_path: group.full_path, enabled: true } }

    context 'as an owner' do
      it 'enables the knowledge graph for the group' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(1)

        expect(mutation_response).to include(
          'group' => hash_including('id' => group.to_global_id.to_s),
          'errors' => be_empty
        )
      end
    end

    context 'as a non-owner' do
      let(:current_user) { developer }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when already enabled' do
      before do
        create(:knowledge_graph_enabled_namespace, namespace: group)
      end

      it 'is idempotent' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }

        expect(mutation_response).to include('errors' => be_empty)
      end
    end

    context 'when orbit_enroll_namespace feature flag is disabled' do
      before do
        stub_feature_flags(orbit_enroll_namespace: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not create a record' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }
      end
    end
  end

  context 'when disabling' do
    let(:input) { { group_path: group.full_path, enabled: false } }

    before do
      create(:knowledge_graph_enabled_namespace, namespace: group)
    end

    it 'disables the knowledge graph for the group' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(-1)

      expect(mutation_response).to include(
        'group' => hash_including('id' => group.to_global_id.to_s),
        'errors' => be_empty
      )
    end

    context 'when orbit_enroll_namespace feature flag is disabled' do
      before do
        stub_feature_flags(orbit_enroll_namespace: false)
      end

      it 'still disables the knowledge graph for the group' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(-1)

        expect(mutation_response).to include(
          'group' => hash_including('id' => group.to_global_id.to_s),
          'errors' => be_empty
        )
      end
    end
  end

  context 'when group does not exist' do
    let(:input) { { group_path: 'nonexistent/path', enabled: true } }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when feature flag is disabled' do
    let(:input) { { group_path: group.full_path, enabled: true } }

    before do
      stub_feature_flags(knowledge_graph: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when :orbit licensed feature is not available' do
    let(:input) { { group_path: group.full_path, enabled: true } }

    before do
      stub_licensed_features(orbit: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
