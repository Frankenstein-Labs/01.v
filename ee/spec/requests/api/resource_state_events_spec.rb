# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ResourceStateEvents, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }

  context 'when eventable is an Epic' do
    before do
      parent.add_developer(user)
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'resource_state_events API', 'groups', 'epics', 'id' do
      let(:parent) { create(:group, :public) }
      let(:eventable) { create(:epic, group: parent, author: user) }
    end

    describe 'legacy Epic event presentation' do
      let(:parent) { create(:group, :public) }
      let(:eventable) { create(:epic, group: parent, author: user) }
      let(:base_path) { "/groups/#{parent.id}/epics/#{eventable.id}" }
      let!(:state_event) { create(:resource_state_event, epic: eventable, state: :closed) }

      context 'for resource state events list' do
        before do
          get api("#{base_path}/resource_state_events", user)
        end

        it 'presents resource_type as Epic and resource_id as Epic ID in collection' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          event_response = json_response.detect { |e| e['id'] == state_event.id }
          expect(event_response['resource_type']).to eq('Epic')
          expect(event_response['resource_id']).to eq(eventable.id)
          expect(event_response['resource_work_item_id']).to eq(eventable.issue_id)
        end
      end

      context 'for single resource state event' do
        before do
          get api("#{base_path}/resource_state_events/#{state_event.id}", user)
        end

        it 'presents resource_type as Epic and resource_id as Epic Id' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['resource_type']).to eq('Epic')
          expect(json_response['resource_id']).to eq(eventable.id)
          expect(json_response['resource_work_item_id']).to eq(eventable.issue_id)
        end
      end
    end
  end

  context 'for non-epic eventables' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:state_event) { create(:resource_state_event, issue: issue, state: :closed) }

    before_all do
      project.add_developer(user)
    end

    it 'does not present resource_work_item_id' do
      get api("/projects/#{project.id}/issues/#{issue.iid}/resource_state_events", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.first).not_to include('resource_work_item_id')
    end
  end
end
