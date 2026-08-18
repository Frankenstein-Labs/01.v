# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::GetSavedViewWorkItemsService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:other_work_item) { create(:work_item, :issue, project: project) }

  let(:service) { described_class.new(name: 'get_saved_view_work_items') }
  let(:request) { instance_double(ActionDispatch::Request) }

  before_all do
    group.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
    stub_feature_flags(work_item_planning_view: group)
    stub_licensed_features(
      issuable_health_status: true,
      iterations: true,
      issue_weights: true
    )
  end

  # Helper to execute the service and verify the work items query received the expected variables
  def execute_and_verify_variables(expected_variables)
    allow(GitlabSchema).to receive(:execute).and_call_original

    result = service.execute(request: request, params: { arguments: params_arguments })

    expect(result[:isError]).to be(false)
    expect(GitlabSchema).to have_received(:execute).with(
      a_string_including('GetWorkItemsFull'),
      variables: hash_including(expected_variables),
      context: anything
    )

    result
  end

  describe 'integration with EE filters', :aggregate_failures do
    context 'with healthStatusFilter' do
      let_it_be(:healthy_work_item) do
        create(:work_item, :issue, project: project, health_status: :on_track)
      end

      let_it_be(:saved_view) do
        create(:saved_view,
          namespace: group,
          author: user,
          name: 'On Track items',
          filter_data: { health_status_filter: 'on_track' }
        )
      end

      let(:params_arguments) { { group_id: group.id.to_s, saved_view_id: saved_view.to_global_id.to_s } }

      it 'passes healthStatusFilter to the work items query' do
        result = execute_and_verify_variables(healthStatusFilter: 'onTrack')

        expect(result[:isError]).to be(false)
        iids = result[:structuredContent].dig('workItems', 'nodes').pluck('iid')
        expect(iids).to include(healthy_work_item.iid.to_s)
        expect(iids).not_to include(other_work_item.iid.to_s)
      end

      it 'does not report healthStatusFilter as unsupported' do
        result = service.execute(request: request, params: { arguments: params_arguments })

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]).not_to have_key('warnings')
      end
    end

    context 'with iteration filters' do
      let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
      let_it_be(:iteration) do
        create(:iteration, iterations_cadence: iteration_cadence,
          start_date: 1.week.ago, due_date: 1.week.from_now)
      end

      let_it_be(:iteration_work_item) do
        create(:work_item, :issue, project: project, iteration: iteration)
      end

      let_it_be(:saved_view) do
        create(:saved_view,
          namespace: group,
          author: user,
          name: 'Current iteration',
          filter_data: { iteration_id: [iteration.id.to_s] }
        )
      end

      let(:params_arguments) { { group_id: group.id.to_s, saved_view_id: saved_view.to_global_id.to_s } }

      it 'passes iterationId to the work items query' do
        result = execute_and_verify_variables(iterationId: [iteration.id.to_s])

        expect(result[:isError]).to be(false)
        iids = result[:structuredContent].dig('workItems', 'nodes').pluck('iid')
        expect(iids).to include(iteration_work_item.iid.to_s)
        expect(iids).not_to include(other_work_item.iid.to_s)
      end
    end

    context 'with iterationWildcardId filter' do
      let_it_be(:saved_view) do
        create(:saved_view,
          namespace: group,
          author: user,
          name: 'Current iteration wildcard',
          filter_data: { iteration_wildcard_id: 'CURRENT' }
        )
      end

      let(:params_arguments) { { group_id: group.id.to_s, saved_view_id: saved_view.to_global_id.to_s } }

      it 'passes iterationWildcardId to the work items query' do
        result = execute_and_verify_variables(iterationWildcardId: 'CURRENT')

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent].dig('workItems', 'nodes')).to be_an(Array)
      end
    end

    context 'with weight filter' do
      let_it_be(:weighted_work_item) do
        create(:work_item, :issue, project: project, weight: 3)
      end

      let_it_be(:saved_view) do
        create(:saved_view,
          namespace: group,
          author: user,
          name: 'Weight 3',
          filter_data: { weight: '3' }
        )
      end

      let(:params_arguments) { { group_id: group.id.to_s, saved_view_id: saved_view.to_global_id.to_s } }

      it 'passes weight to the work items query' do
        result = execute_and_verify_variables(weight: '3')

        expect(result[:isError]).to be(false)
        iids = result[:structuredContent].dig('workItems', 'nodes').pluck('iid')
        expect(iids).to include(weighted_work_item.iid.to_s)
        expect(iids).not_to include(other_work_item.iid.to_s)
      end
    end

    context 'with combined CE and EE filters' do
      let_it_be(:label) { create(:group_label, group: group, title: 'bug') }

      let_it_be(:saved_view) do
        create(:saved_view,
          namespace: group,
          author: user,
          name: 'Combined CE+EE',
          filter_data: {
            state: 'opened',
            label_ids: [label.id],
            health_status_filter: 'needs_attention'
          }
        )
      end

      let(:params_arguments) { { group_id: group.id.to_s, saved_view_id: saved_view.to_global_id.to_s } }

      it 'passes both CE and EE filters to the work items query' do
        result = execute_and_verify_variables(
          state: 'opened',
          labelName: [label.title],
          healthStatusFilter: 'needsAttention'
        )

        expect(result[:isError]).to be(false)
        nodes = result[:structuredContent].dig('workItems', 'nodes')
        expect(nodes).to be_an(Array)
      end

      it 'does not report any unsupported filter warnings' do
        result = service.execute(request: request, params: { arguments: params_arguments })

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]).not_to have_key('warnings')
      end
    end
  end
end
