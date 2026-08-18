# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  include_context 'workhorse headers'

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  describe "GET /projects/:id/repository/archive(.:format)?:sha" do
    let(:route) { "/projects/#{project.id}/repository/archive" }

    subject(:request) { get api(route, user), headers: workhorse_headers }

    shared_examples 'an auditable and successful request' do
      before do
        stub_licensed_features(admin_audit_log: true)
      end

      it 'logs the audit event' do
        expect { request }.to change { AuditEventReader.count }.by(1)
      end

      it 'sends the archive' do
        get api(route, current_user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let_it_be(:project) { create(:project, :public, :repository) }
      let_it_be(:user) { nil }

      it 'does not log audit event' do
        expect { request }.not_to change { AuditEventReader.count }
      end
    end

    context 'when authenticated', 'as a developer' do
      before do
        project.add_developer(user)
      end

      it_behaves_like 'an auditable and successful request' do
        let(:current_user) { user }
      end
    end

    describe 'projects download throttling' do
      before do
        project.add_developer(user)

        allow_next_instance_of(::Users::Abuse::ProjectsDownloadBanCheckService, project, user) do |service|
          allow(service).to receive(:execute).and_return(service_response)
        end

        request
      end

      context 'when user is banned from the project\'s top-level group' do
        let(:service_response) { ServiceResponse.error(message: 'User has been banned') }

        it 'returns forbidden error' do
          expect(response).to have_gitlab_http_status(:forbidden)
          expect(response.body).to match 'You are not allowed to download code from this project.'
        end
      end

      context 'when user is not banned from the project\'s top-level group' do
        let(:service_response) { ServiceResponse.success }

        it 'returns the repository archive' do
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    describe 'download ban runs before the archive cache/conditional-request logic' do
      before do
        project.add_developer(user)
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
      end

      def stub_download_ban(banned)
        allow_next_instance_of(::Users::Abuse::ProjectsDownloadBanCheckService) do |service|
          response = banned ? ServiceResponse.error(message: 'banned') : ServiceResponse.success
          allow(service).to receive(:execute).and_return(response)
        end
      end

      it 'returns 403 instead of 304 when a banned user sends a matching ETag', :aggregate_failures do
        stub_download_ban(false)
        get api(route, user)
        etag = response.headers['ETag']
        expect(etag).to be_present

        stub_download_ban(true)
        get api(route, user), headers: { 'If-None-Match' => etag }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns 403 without public cache headers when a banned user sends a stale ETag', :aggregate_failures do
        stub_download_ban(true)

        get api(route, user), headers: { 'If-None-Match' => '"stale"' }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(response.headers['Cache-Control'].to_s).not_to include('public', 's-maxage')
        expect(response.headers['ETag']).to be_nil
      end
    end

    describe 'download audit fires only for a real transfer' do
      before do
        stub_licensed_features(admin_audit_log: true)
        project.add_developer(user)
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
      end

      it 'audits a real GET download' do
        expect { get api(route, user) }.to change { AuditEventReader.count }.by(1)
      end

      it 'does not audit a conditional GET that returns 304', :aggregate_failures do
        get api(route, user)
        etag = response.headers['ETag']
        expect(etag).to be_present

        expect do
          get api(route, user), headers: { 'If-None-Match' => etag }
        end.not_to change { AuditEventReader.count }

        expect(response).to have_gitlab_http_status(:not_modified)
      end
    end
  end

  describe "HEAD /projects/:id/repository/archive" do
    let(:route) { "/projects/#{project.id}/repository/archive" }

    before do
      project.add_developer(user)
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    describe 'projects download throttling' do
      before do
        allow_next_instance_of(::Users::Abuse::ProjectsDownloadBanCheckService, project, user) do |service|
          allow(service).to receive(:execute).and_return(service_response)
        end

        head api(route, user), headers: workhorse_headers
      end

      context 'when user is banned from the project top-level group' do
        let(:service_response) { ServiceResponse.error(message: 'User has been banned') }

        it 'returns forbidden error' do
          expect(response).to have_gitlab_http_status(:forbidden)
          expect(response.body).to eq('')
        end
      end

      context 'when user is not banned from the projects top-level group' do
        let(:service_response) { ServiceResponse.success }

        it 'returns 200 OK' do
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end
