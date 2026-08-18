# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ResourceLabelEvents, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }

  before do
    parent.add_developer(user)
  end

  context 'when eventable is an Epic' do
    let_it_be(:parent) { create(:group, :public) }
    let_it_be(:epic) { create(:epic, group: parent, author: user) }
    let_it_be(:label) { create(:group_label, group: parent) }
    let_it_be(:event) { create(:resource_label_event, epic: epic, label: label) }

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'resource_label_events API', 'groups', 'epics', 'id' do
      let(:parent) { create(:group, :public) }
      let(:eventable) { create(:epic, group: parent, author: user) }
      let(:label) { create(:group_label, group: parent) }
    end

    it 'returns resource_type as Epic for list endpoint' do
      get api("/groups/#{parent.id}/epics/#{epic.id}/resource_label_events", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an(Array)
      expect(json_response.first['resource_type']).to eq('Epic')
      expect(json_response.first['resource_id']).to eq(epic.id)
      expect(json_response.first['resource_work_item_id']).to eq(epic.work_item.id)
    end

    it 'returns resource_type as Epic for single event endpoint' do
      get api("/groups/#{parent.id}/epics/#{epic.id}/resource_label_events/#{event.id}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['resource_type']).to eq('Epic')
      expect(json_response['resource_id']).to eq(epic.id)
      expect(json_response['resource_work_item_id']).to eq(epic.work_item.id)
    end
  end

  context 'when eventable is a WorkItem' do
    let_it_be(:issue) { create(:issue, author: user) }
    let_it_be(:parent) { issue.project }
    let_it_be(:label) { create(:label, project: parent) }
    let_it_be(:event) { create(:resource_label_event, issue: issue, label: label) }

    it 'base ResourceLabelEvent entity returns Issue as resource_type' do
      get api("/projects/#{parent.id}/issues/#{issue.iid}/resource_label_events/#{event.id}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['resource_type']).to eq('Issue')
      expect(json_response['resource_id']).to eq(issue.id)
      expect(json_response).not_to have_key('resource_work_item_id')
    end
  end
end
