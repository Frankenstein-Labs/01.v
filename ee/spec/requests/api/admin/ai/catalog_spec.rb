# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Ai::Catalog, feature_category: :workflow_catalog do
  let_it_be(:default_organization) { create(:organization) }
  let_it_be(:admin) { create(:admin) }

  describe 'POST /admin/ai_catalog/seed_external_agents' do
    let(:path) { '/admin/ai_catalog/seed_external_agents' }

    before do
      allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    end

    it_behaves_like 'authorizing granular token permissions', :create_ai_catalog_third_party_flow do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat) }
    end

    it 'returns 401 for unauthenticated requests' do
      post api(path, nil)

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it 'returns 403 for non-admin requests' do
      post api(path, admin)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'seeds external agents' do
      post api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response).to eq({ 'message' => 'External agents seeded successfully' })
      expect(
        Ai::Catalog::Item
          .with_item_type(Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE)
          .for_verification_level(:gitlab_maintained)
          .exists?
      ).to be true
    end

    it 'returns error if external agents have already been seeded' do
      post api(path, admin, admin_mode: true)

      expect { post api(path, admin, admin_mode: true) }.not_to change { Ai::Catalog::Item.count }
      expect(response).to have_gitlab_http_status(:unprocessable_entity)
      expect(json_response).to eq({ 'message' => 'Error: External agents already seeded' })
    end

    it 'returns any error from Ai::Catalog::Seeder as an error response' do
      allow(Gitlab::Ai::Catalog::ThirdPartyFlows::Seeder).to receive(:run!).and_raise(StandardError, 'My error')

      post api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
      expect(json_response).to eq({ 'message' => 'My error' })
    end
  end
end
