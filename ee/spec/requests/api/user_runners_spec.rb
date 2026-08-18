# frozen_string_literal: true

require 'spec_helper'

# NOTE: No cross-organization isolation test for the user-scoped path (`POST /user/runners` /
# `User#ci_available_runners`). Organization filtering on this path was implemented in #591183
# (MR !226892) but reverted in MR !229222 due to a cross-database query incident, so no organization
# boundary is enforced in master today. A boundary test should be added once the filtering is reinstated.
RSpec.describe API::UserRunners, :aggregate_failures, feature_category: :fleet_visibility do
  describe 'POST /user/runners' do
    subject(:request) { post api(path, current_user), params: runner_attrs }

    let_it_be(:group) { create(:group) }
    let_it_be(:group_owner) { create(:user, owner_of: group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:runner_attrs) { { runner_type: 'group_type', group_id: group.id } }
    let(:path) { '/user/runners' }

    shared_examples 'creates a runner' do
      it 'creates a runner and logs an audit event' do
        expect do
          request

          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ci::Runner.count }.by(1)
         .and change { AuditEventReader.count }.by(1)
      end
    end

    context 'when user has sufficient permissions' do
      let(:current_user) { group_owner }

      it_behaves_like 'creates a runner'
    end

    context 'with request authorized with access token' do
      let(:current_user) { nil }
      let(:token_user) { group_owner }
      let(:pat) { create(:personal_access_token, user: token_user, scopes: [scope]) }
      let(:path) { "/user/runners?private_token=#{pat.token}" }
      let(:scope) { :create_runner }

      it_behaves_like 'creates a runner'

      context 'with read_api scope' do
        let(:scope) { :read_api }

        it 'fails with :forbidden code and does not log audit event' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:forbidden)
          end.to not_change { Ci::Runner.count }
            .and not_change { AuditEventReader.count }
        end
      end
    end

    context 'when token expiration parameters are provided', :freeze_time do
      let(:current_user) { group_owner }
      let(:token_expires_at) { 10.days.from_now.iso8601 }
      let(:runner) { Ci::Runner.last }
      let(:runner_attrs) do
        { runner_type: 'project_type', project_id: project.id, token_expires_at: token_expires_at }
      end

      it 'creates a runner with token_expires_at' do
        expect do
          request

          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ci::Runner.count }.by(1)

        expect(runner.token_expires_at).to eq(10.days.from_now)
      end

      context 'when token_expires_at is less than 5 minutes in the future' do
        let(:token_expires_at) { 4.minutes.from_now.iso8601 }

        it 'returns bad_request' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('token_expires_at must be at least')
          end.not_to change { Ci::Runner.count }
        end
      end

      context 'when token_expires_at is more than 15 days in the future' do
        let(:token_expires_at) { 16.days.from_now.iso8601 }

        it 'returns bad_request' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('token_expires_at is too far in the future')
          end.not_to change { Ci::Runner.count }
        end
      end

      context 'when token_rotation_deadline is provided' do
        let(:runner_attrs) do
          {
            runner_type: 'project_type',
            project_id: project.id,
            token_expires_at: token_expires_at,
            token_rotation_deadline: 5.days.from_now.iso8601
          }
        end

        it 'creates a runner with token_rotation_deadline' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:created)
          end.to change { Ci::Runner.count }.by(1)

          expect(runner.token_rotation_deadline).to eq(5.days.from_now)
        end
      end

      context 'when token_rotation_deadline is after token_expires_at' do
        let(:runner_attrs) do
          {
            runner_type: 'project_type',
            project_id: project.id,
            token_expires_at: token_expires_at,
            token_rotation_deadline: 11.days.from_now.iso8601
          }
        end

        it 'returns bad_request' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include(
              'token_rotation_deadline must be less than or equal to token_expires_at'
            )
          end.not_to change { Ci::Runner.count }
        end
      end

      context 'when token_rotation_deadline is in the past' do
        let(:runner_attrs) do
          {
            runner_type: 'project_type',
            project_id: project.id,
            token_expires_at: token_expires_at,
            token_rotation_deadline: 1.minute.ago.iso8601 # gitleaks:allow
          }
        end

        it 'returns bad_request' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('token_rotation_deadline cannot be in the past')
          end.not_to change { Ci::Runner.count }
        end
      end

      context 'when token_rotation_deadline equals token_expires_at' do
        let(:runner_attrs) do
          {
            runner_type: 'project_type',
            project_id: project.id,
            token_expires_at: token_expires_at,
            token_rotation_deadline: token_expires_at
          }
        end

        it 'creates a runner with rotation disabled' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:created)
          end.to change { Ci::Runner.count }.by(1)

          expect(runner.token_rotation_deadline).to eq(10.days.from_now)
        end
      end

      context 'when token_rotation_deadline is provided without token_expires_at' do
        let(:runner_attrs) do
          {
            runner_type: 'project_type',
            project_id: project.id,
            token_rotation_deadline: 5.days.from_now.iso8601
          }
        end

        it 'returns bad_request' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('token_expires_at is required')
          end.not_to change { Ci::Runner.count }
        end
      end
    end
  end
end
