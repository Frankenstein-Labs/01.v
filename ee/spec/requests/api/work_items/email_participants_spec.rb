# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::EmailParticipants, feature_category: :service_desk do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:epic_work_item) { create(:work_item, :epic, namespace: group) }

  before do
    stub_licensed_features(epics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/email_participants' do
    let(:api_request_path) do
      "/groups/#{group.id}/-/work_items/#{epic_work_item.iid}/email_participants"
    end

    it 'returns 404 because epics do not support the email_participants widget' do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it_behaves_like 'authorizing granular token permissions', :read_work_item,
      expected_success_status: :not_found do
      let(:boundary_object) { group }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end

    context 'without the epics license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns 404 when the work item is not readable' do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
