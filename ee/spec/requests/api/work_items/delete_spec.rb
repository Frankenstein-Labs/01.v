# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::Delete, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user, owners: owner) }

  before do
    stub_feature_flags(work_item_rest_api: owner)
    stub_licensed_features(epics: true)
  end

  describe 'DELETE /groups/:id/-/work_items/:work_item_iid' do
    let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

    context 'when the work item exists' do
      it 'deletes the work item and returns 204' do
        delete api("/groups/#{group.id}/-/work_items/#{work_item.iid}", owner)

        expect(response).to have_gitlab_http_status(:no_content)
        expect(WorkItem.find_by_id(work_item.id)).to be_nil
      end
    end

    context 'when the user does not have permission to delete' do
      it 'returns 403' do
        stub_feature_flags(work_item_rest_api: user)

        delete api("/groups/#{group.id}/-/work_items/#{work_item.iid}", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_work_item,
      expected_success_status: :no_content do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        delete api("/groups/#{group.id}/-/work_items/#{work_item.iid}", personal_access_token: pat)
      end
    end
  end
end
