# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a value stream', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:value_stream) { create(:cycle_analytics_value_stream) }

  let(:mutation_name) { :value_stream_destroy }

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      id: value_stream.to_global_id
    )
  end

  before do
    stub_licensed_features(cycle_analytics_for_groups: true)
  end

  context 'with granular token authorization' do
    context 'with a group boundary' do
      let_it_be(:group_value_stream) { create(:cycle_analytics_value_stream, namespace: create(:group)) }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_value_stream do
        let(:boundary_object) { group_value_stream.namespace }
        let(:user) { create(:user).tap { |u| group_value_stream.namespace.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(:value_stream_destroy, { id: group_value_stream.to_global_id.to_s }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with a project boundary' do
      let_it_be(:vs_project) { create(:project) }
      let_it_be(:project_value_stream) do
        create(:cycle_analytics_value_stream, namespace: vs_project.project_namespace)
      end

      before do
        stub_licensed_features(cycle_analytics_for_groups: true, cycle_analytics_for_projects: true)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_value_stream do
        let(:boundary_object) { vs_project }
        let(:user) { create(:user).tap { |u| vs_project.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(:value_stream_destroy, { id: project_value_stream.to_global_id.to_s }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end

  context 'when user has permissions to delete value streams' do
    before_all do
      value_stream.namespace.add_reporter(current_user)
    end

    it 'deletes value stream' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { ::Analytics::CycleAnalytics::ValueStream.count }.by(-1)
    end

    context 'when an error happens' do
      before do
        allow_next_found_instance_of(::Analytics::CycleAnalytics::ValueStream) do |instance|
          allow(instance).to receive(:destroy).and_return(false)
        end
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_mutation_response(:value_stream_destroy)['errors'])
          .to include('Error deleting the value stream')
      end
    end
  end

  context 'when the user does not have permission to create a value stream' do
    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
