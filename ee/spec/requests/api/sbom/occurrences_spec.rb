# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Sbom::Occurrences, :aggregate_failures, :api, feature_category: :dependency_management do
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence) }
  let(:path) { '/occurrences/vulnerabilities' }

  describe 'GET /occurrences/vulnerabilities' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated but unauthorized' do
      let(:user) { create(:user) }

      it 'returns not found' do
        get api(path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorized' do
      let(:params) { { id: sbom_occurrence.id } }
      let(:user) { create(:admin) }

      before do
        sbom_occurrence.project.add_developer(user)
      end

      subject(:get_occurrences_vulnerabilities) do
        get api(path, user), params: params
      end

      it 'returns success' do
        get_occurrences_vulnerabilities

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when id is nil' do
        let(:params) { { id: nil } }

        it 'returns not found' do
          get_occurrences_vulnerabilities

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_sbom_occurrence do
        let(:boundary_object) { sbom_occurrence.project }
        let(:request) do
          get api(path, personal_access_token: pat), params: params
        end
      end
    end
  end
end
