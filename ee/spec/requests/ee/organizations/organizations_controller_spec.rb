# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationsController, feature_category: :artifact_registry do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  before_all do
    create(:organization_user, organization: organization, user: user)
  end

  before do
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:show_request) { get organization_path(organization) }

    it 'pushes the artifact_registry_ui feature flag as enabled to the frontend' do
      show_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to have_pushed_frontend_feature_flags(artifactRegistryUi: true)
    end

    context 'when the artifact_registry_ui feature flag is disabled' do
      before do
        stub_feature_flags(artifact_registry_ui: false)
      end

      it 'pushes the artifact_registry_ui feature flag as disabled to the frontend' do
        show_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_pushed_frontend_feature_flags(artifactRegistryUi: false)
      end
    end
  end
end
