# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::AwardEmoji, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

  let_it_be(:thumbs_up) { create(:award_emoji, awardable: work_item, user: user, name: 'thumbsup') }

  before do
    stub_feature_flags(work_item_rest_api: true)
    stub_licensed_features(epics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/award_emoji' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{work_item.iid}/award_emoji" }

    it 'returns emoji reactions on the group-level work item' do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to contain_exactly(thumbs_up.id)
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
