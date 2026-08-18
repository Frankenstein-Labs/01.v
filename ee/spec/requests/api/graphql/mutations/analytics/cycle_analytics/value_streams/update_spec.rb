# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update value stream', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project_1) { create(:project, namespace: group) }
  let_it_be_with_refind(:value_stream) do
    create(
      :cycle_analytics_value_stream,
      name: 'Old name',
      namespace: group,
      setting_attributes: { project_ids_filter: [project_1.id] },
      stages: Array.new(1) do
        create(
          :cycle_analytics_stage,
          namespace: group,
          name: "Issue",
          relative_position: 1,
          start_event_identifier: :issue_created,
          end_event_identifier: :issue_closed
        )
      end
    )
  end

  let(:new_name) { 'New name' }

  let(:mutation_name) { :value_stream_update }
  let(:value_stream_parameters) do
    {
      id: value_stream.to_global_id,
      name: new_name
    }
  end
  let(:extra_parameters) { {} } # To be overridden on more specific examples

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      **value_stream_parameters.merge(extra_parameters)
    )
  end

  before do
    stub_licensed_features(
      cycle_analytics_for_projects: true,
      cycle_analytics_for_groups: true
    )
  end

  context 'with granular token authorization' do
    context 'with a group boundary' do
      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_value_stream do
        let(:boundary_object) { value_stream.namespace }
        let(:user) { create(:user).tap { |u| value_stream.namespace.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(:value_stream_update, { id: value_stream.to_global_id.to_s, name: 'GPAT updated' },
            'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with a project boundary' do
      let_it_be(:vs_project) { create(:project) }
      let_it_be(:project_value_stream) do
        create(:cycle_analytics_value_stream, namespace: vs_project.project_namespace)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_value_stream do
        let(:boundary_object) { vs_project }
        let(:user) { create(:user).tap { |u| vs_project.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(:value_stream_update, { id: project_value_stream.to_global_id.to_s, name: 'GPAT updated' },
            'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end

  context 'when user has permissions to update value streams' do
    before do
      value_stream.namespace.add_reporter(current_user)
    end

    it 'updates the value stream' do
      post_graphql_mutation(mutation, current_user: current_user)

      value_stream = graphql_mutation_response(mutation_name)['valueStream']

      expect(value_stream).to be_present
      expect(value_stream['name']).to eq('New name')
    end

    context 'and uses invalid arguments' do
      let(:new_name) { 'no' }

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        result = graphql_mutation_response(mutation_name)['errors']

        expect(result).to include('Name is too short (minimum is 3 characters)')
      end
    end

    context 'when stages argument is present' do
      let(:stages) do
        [
          { name: 'code', custom: false }, # default stage
          { name: 'Custom 1',
            custom: true,
            start_event_identifier: 'ISSUE_CREATED',
            end_event_identifier: 'ISSUE_CLOSED' }
        ]
      end

      let(:extra_parameters) do
        {
          stages: stages
        }
      end

      it 'updates value stream stages' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { value_stream.stages.count }.from(1).to(2)

        expect(value_stream.reload.stages.map(&:name)).to match_array(['code', 'Custom 1'])
      end

      context 'when id argument is present' do
        let_it_be(:stage_to_update) { value_stream.stages.first }

        let(:extra_parameters) do
          {
            stages: { id: stage_to_update.to_global_id, name: 'new stage name' }
          }
        end

        it 'updates value stream stage attributes' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { stage_to_update.reload.name }.to('new stage name')
        end
      end

      context 'when stages argument has invalid values' do
        let(:stages) do
          [
            { name: 'code', custom: true }
          ]
        end

        it 'returns error' do
          post_graphql_mutation(mutation, current_user: current_user)

          result = graphql_mutation_response(mutation_name)['errors']

          expect(result).to include('Stages[0] name is reserved')
          expect(result).to include("Stages[0] start event identifier can't be blank")
          expect(result).to include("Stages[0] end event identifier can't be blank")
        end
      end
    end

    context 'when setting argument is present' do
      let_it_be(:project_2) { create(:project, group: group) }

      let(:extra_parameters) do
        {
          setting: {
            project_ids_filter: [project_1, project_2].map(&:to_global_id)
          }
        }
      end

      it 'saves project_ids filter' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { value_stream.setting.reload.project_ids_filter.sort }
          .from([project_1.id])
          .to([project_1.id, project_2.id].sort)
      end
    end
  end

  context 'when the user does not have permission to create a value stream' do
    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when Value Stream Analytics is not available for the namespace' do
    before do
      value_stream.namespace.add_reporter(current_user)
      stub_licensed_features(cycle_analytics_for_projects: false)
      stub_licensed_features(cycle_analytics_for_groups: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
