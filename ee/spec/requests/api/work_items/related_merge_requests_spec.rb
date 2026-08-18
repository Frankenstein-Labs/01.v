# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::RelatedMergeRequests, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

  before do
    stub_licensed_features(epics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/related_merge_requests' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{work_item.iid}/related_merge_requests" }

    it_behaves_like 'a group-level work item development feature endpoint returning empty'
  end
end
