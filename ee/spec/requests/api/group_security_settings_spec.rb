# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupSecuritySettings, :aggregate_failures, feature_category: :security_testing_configuration do
  describe 'PUT /groups/:id/security_settings' do
    let_it_be(:group) { create(:group) }
    let_it_be(:maintainer) { create(:user, maintainer_of: group) }
    let_it_be(:developer) { create(:user, developer_of: group) }
    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group) }
    let(:url) { "/groups/#{group.id}/security_settings" }

    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        put api(url)
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(secret_push_protection: true)
        allow(::Security::Configuration::SetGroupSecretPushProtectionWorker).to receive(:perform_async)
      end

      it 'when user is not a maintainer' do
        put api(url, developer), params: { secret_push_protection_enabled: true }
        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'updates group security settings for users with Maintainer role' do
        put api(url, maintainer), params: { secret_push_protection_enabled: true }

        expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
          .to have_received(:perform_async)
          .with(group.id, true, maintainer.id, nil)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['errors']).to be_empty
        expect(json_response['secret_push_protection_enabled']).to be(true)
      end

      it 'updates group security settings with projects to exclude' do
        put api(url, maintainer),
          params: { secret_push_protection_enabled: true, projects_to_exclude: [project1.id, project2.id] }

        expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
          .to have_received(:perform_async)
          .with(group.id, true, maintainer.id, [project1.id, project2.id])

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['errors']).to be_empty
        expect(json_response['secret_push_protection_enabled']).to be(true)
      end

      it_behaves_like 'authorizing granular token permissions', :update_security_setting do
        let(:boundary_object) { group }
        let(:user) { maintainer }
        let(:request) do
          put api(url, personal_access_token: pat), params: { secret_push_protection_enabled: true }
        end
      end
    end
  end
end
