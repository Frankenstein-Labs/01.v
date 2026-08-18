# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::LinkedResources, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:parent_work_item) { create(:work_item, :epic, namespace: group) }

  before do
    stub_feature_flags(work_item_rest_api: true)
    stub_licensed_features(epics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/linked_resources' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{parent_work_item.iid}/linked_resources" }

    it 'returns an empty list because group-level work items do not support linked resources', :aggregate_failures do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq([])
    end

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { group }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end
  end
end
