# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::LinkedItems, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:project) { create(:project, :private, group: group, reporters: user) }
  let_it_be(:parent_work_item) { create(:work_item, :epic, namespace: group) }
  let_it_be(:related_work_item) { create(:work_item, :issue, project: project) }
  let_it_be(:blocking_work_item) { create(:work_item, :issue, project: project, title: 'Blocking') }

  let_it_be(:related_link) do
    create(:work_item_link, source: parent_work_item, target: related_work_item, link_type: 'relates_to')
  end

  let_it_be(:blocking_link) do
    create(:work_item_link, source: blocking_work_item, target: parent_work_item, link_type: 'blocks')
  end

  before do
    stub_feature_flags(work_item_rest_api: true)
    stub_licensed_features(epics: true, blocked_work_items: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/linked_items' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{parent_work_item.iid}/linked_items" }

    it 'returns linked items across link types', :aggregate_failures do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to contain_exactly(related_work_item.id, blocking_work_item.id)
    end

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { group }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end

    context 'with link_type=is_blocked_by' do
      it 'returns only items blocking the parent and reports inverse link_type', :aggregate_failures do
        get api(api_request_path, user), params: { link_type: 'is_blocked_by' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to contain_exactly(blocking_work_item.id)
        expect(json_response.first).to include('link_type' => 'is_blocked_by')
      end
    end

    context 'with link_type=blocks' do
      let_it_be(:blocked_target) { create(:work_item, :issue, project: project, title: 'Blocked') }
      let_it_be(:blocks_link) do
        create(:work_item_link, source: parent_work_item, target: blocked_target, link_type: 'blocks')
      end

      it 'returns only items the parent blocks and reports forward link_type', :aggregate_failures do
        get api(api_request_path, user), params: { link_type: 'blocks' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to contain_exactly(blocked_target.id)
        expect(json_response.first).to include('link_type' => 'blocks')
      end
    end

    context 'with link_type=relates_to' do
      it 'returns only related items', :aggregate_failures do
        get api(api_request_path, user), params: { link_type: 'relates_to' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to contain_exactly(related_work_item.id)
        expect(json_response.first).to include('link_type' => 'relates_to')
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
