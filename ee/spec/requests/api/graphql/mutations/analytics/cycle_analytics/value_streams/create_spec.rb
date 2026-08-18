# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a new value stream', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:mutation_name) { :value_stream_create }
  let(:value_stream_name) { 'New value stream' }
  let(:extra_parameters) { {} } # To be overridden on more specific examples
  let(:value_stream_parameters) do
    {
      namespace_path: namespace.full_path,
      name: value_stream_name
    }
  end

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
      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_value_stream do
        let(:boundary_object) { group }
        let(:user) { create(:user).tap { |u| group.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(:value_stream_create, { namespace_path: group.full_path, name: 'GPAT value stream' },
            'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with a project boundary' do
      let_it_be(:vsc_project) { create(:project, group: group) }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_value_stream do
        let(:boundary_object) { vsc_project }
        let(:user) { create(:user).tap { |u| vsc_project.add_reporter(u) } }
        let(:mutation) do
          graphql_mutation(
            :value_stream_create,
            { namespace_path: vsc_project.project_namespace.full_path, name: 'GPAT value stream' },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end

  shared_examples 'a request to create value streams' do
    context 'when user has permissions to create value streams' do
      before do
        namespace_object.add_reporter(current_user)
      end

      it 'creates a new value stream' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { ::Analytics::CycleAnalytics::ValueStream.count }.by(1)
      end

      it 'returns the created value stream' do
        post_graphql_mutation(mutation, current_user: current_user)

        value_stream = graphql_mutation_response(mutation_name)['valueStream']

        expect(value_stream).to be_present
        expect(value_stream['name']).to eq('New value stream')
      end

      context 'and uses invalid arguments' do
        let(:value_stream_name) { 'no' }

        it 'returns error' do
          post_graphql_mutation(mutation, current_user: current_user)

          result = graphql_mutation_response(mutation_name)['errors']

          expect(result).to include('Name is too short (minimum is 3 characters)')
        end
      end

      context 'when stages argument is present' do
        let_it_be(:start_label) { create(:group_label, group: group) }
        let_it_be(:end_label) { create(:group_label, group: group) }

        let(:stages) do
          [
            { name: 'code', custom: false }, # default stage
            { name: 'Custom 1',
              hidden: true,
              custom: true,
              start_event_identifier: 'ISSUE_CREATED',
              end_event_identifier: 'ISSUE_CLOSED' },
            {
              name: 'Custom 2',
              custom: true,
              start_event_identifier: 'ISSUE_LABEL_ADDED',
              start_event_label_id: start_label.to_global_id.to_s,
              end_event_identifier: 'ISSUE_LABEL_REMOVED',
              end_event_label_id: end_label.to_global_id.to_s
            }
          ]
        end

        let(:extra_parameters) do
          {
            stages: stages
          }
        end

        it 'creates value stream with stages' do
          post_graphql_mutation(mutation, current_user: current_user)

          stages = Analytics::CycleAnalytics::ValueStream.last.stages.order(:name)

          expect(stages.count).to eq(3)
          expect(stages.map(&:name)).to eq(['code', 'Custom 1', 'Custom 2'])
          expect(stages.map(&:hidden)).to eq([false, true, false])
          expect(stages.map(&:start_event_identifier)).to eq(%w[code_stage_start issue_created issue_label_added])
          expect(stages.map(&:end_event_identifier)).to eq(%w[merge_request_created issue_closed
            issue_label_removed])
          expect(stages.map(&:start_event_label_id)).to eq([nil, nil, start_label.id])
        end

        context 'when it has invalid parameters' do
          let(:stages) do
            [
              { name: 'code', custom: false }, # default stage
              {
                name: 'Missing label event id',
                custom: true,
                start_event_identifier: 'ISSUE_LABEL_ADDED',
                end_event_identifier: 'ISSUE_LABEL_REMOVED'
              }
            ]
          end

          it 'returns error' do
            post_graphql_mutation(mutation, current_user: current_user)

            result = graphql_mutation_response(mutation_name)['errors']

            expect(result).to include("Stages[1] start event label can't be blank")
            expect(result).to include("Stages[1] end event label can't be blank")
          end
        end
      end
    end

    context 'when the user does not have permission to create a value stream' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when Value Stream Analytics is not available for the namespace' do
      before do
        namespace_object.add_reporter(current_user)
        stub_licensed_features(cycle_analytics_for_projects: false)
        stub_licensed_features(cycle_analytics_for_groups: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'when namespace is a project' do
    let_it_be(:namespace_object) { create(:project, namespace: group) }
    let(:namespace) { namespace_object.project_namespace }

    it_behaves_like 'a request to create value streams'
  end

  context 'when namespace is a group' do
    let_it_be(:namespace) { group }
    let(:namespace_object) { namespace }

    it_behaves_like 'a request to create value streams'

    context 'when setting argument is present' do
      let_it_be(:project_1) { create(:project, namespace: group) }
      let_it_be(:project_2) { create(:project, namespace: group) }

      let(:extra_parameters) do
        {
          setting: {
            project_ids_filter: [project_1, project_2].map(&:to_global_id)
          }
        }
      end

      before do
        namespace_object.add_reporter(current_user)
      end

      it 'saves project_ids filter' do
        post_graphql_mutation(mutation, current_user: current_user)

        value_stream = Analytics::CycleAnalytics::ValueStream.last

        expect(value_stream.setting.project_ids_filter).to match_array([project_1.id, project_2.id])
      end
    end
  end
end
