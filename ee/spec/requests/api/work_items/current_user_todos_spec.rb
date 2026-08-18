# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::CurrentUserTodos, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:epic) { create(:work_item, :epic, namespace: group, author: user) }

  let_it_be(:todo) do
    create(:todo, :pending, user: user, group: group, target: epic, target_type: 'WorkItem')
  end

  before do
    stub_licensed_features(epics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/current_user_todos' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{epic.iid}/current_user_todos" }

    it 'returns the current user to-do items on the group-level work item', :aggregate_failures do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to contain_exactly(todo.id)
    end

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { group }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end

    context 'without the epics license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns 404 when the parent is not readable' do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
