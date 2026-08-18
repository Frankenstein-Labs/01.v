# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Runners, feature_category: :fleet_visibility do
  let_it_be(:organization) { create_default(:organization) }
  let_it_be(:auditor) { create(:user, :auditor) }
  let_it_be(:users) { create_list(:user, 2) }

  let_it_be(:group) { create(:group, owners: users.first) }
  let_it_be(:subgroup) { create(:group, parent: group) }

  let_it_be(:project) do
    create(:project, creator_id: users.first.id, maintainers: users.first, reporters: users.second)
  end

  let_it_be(:project2) { create(:project, creator_id: users.first.id, maintainers: users.first) }

  let_it_be_with_reload(:shared_runner) do
    create(:ci_runner, :instance, :with_runner_manager, description: 'Shared runner')
  end

  let_it_be_with_reload(:project_runner) do
    create(:ci_runner, :project, description: 'Project runner', projects: [project])
  end

  let_it_be(:two_projects_runner) do
    create(:ci_runner, :project, description: 'Two projects runner', projects: [project, project2])
  end

  let_it_be(:group_runner_a) { create(:ci_runner, :group, description: 'Group runner A', groups: [group]) }
  let_it_be(:group_runner_b) { create(:ci_runner, :group, description: 'Group runner B', groups: [subgroup]) }

  describe 'POST /runners/:id/reset_authentication_token', :freeze_time do
    let(:current_user) { users.first }

    subject(:perform_request) { post api("/runners/#{project_runner.id}/reset_authentication_token", current_user) }

    context 'when runner has a token_rotation_deadline' do
      before do
        project_runner.update_columns(token_rotation_deadline: token_rotation_deadline,
          token_expires_at: 10.days.from_now)
      end

      context 'when token_rotation_deadline has passed' do
        let(:token_rotation_deadline) { 1.minute.ago }

        it 'returns forbidden and does not reset the token' do
          expect do
            perform_request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('Token rotation deadline has passed')
          end.not_to change { project_runner.reload.token }
        end
      end

      context 'when token_rotation_deadline is in the future' do
        let(:token_rotation_deadline) { 1.day.from_now }

        it 'resets the token and clears the deadline' do
          expect do
            perform_request

            expect(response).to have_gitlab_http_status(:success)
          end.to change { project_runner.reload.token }

          expect(project_runner.reload.token_rotation_deadline).to be_nil
        end
      end
    end
  end

  # NOTE: No cross-organization isolation test for the admin path (`GET /runners/all`). It is
  # cell-scoped by design (admins and auditors see every runner on the cell, across all
  # organizations), so a second-organization runner is expected to be returned here, not filtered out.
  describe 'GET /runners/all' do
    let(:path) { "/runners/all" }

    subject(:perform_request) { get api(path, current_user) }

    context 'with authorized user' do
      context 'with auditor privileges' do
        let(:current_user) { auditor }

        it 'returns response status and headers' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
        end

        it 'returns all runners' do
          perform_request
          expect(current_user.auditor?).to be_truthy

          expect(json_response).to match_array [
            a_hash_including('description' => 'Project runner', 'is_shared' => false, 'active' => true,
              'paused' => false, 'runner_type' => 'project_type'),
            a_hash_including('description' => 'Two projects runner', 'is_shared' => false,
              'runner_type' => 'project_type'),
            a_hash_including('description' => 'Group runner A',
              'is_shared' => false, 'runner_type' => 'group_type'),
            a_hash_including('description' => 'Group runner B',
              'is_shared' => false, 'runner_type' => 'group_type'),
            a_hash_including('description' => 'Shared runner',
              'is_shared' => true, 'runner_type' => 'instance_type')
          ]
        end
      end
    end

    context 'with unauthorized user' do
      let(:current_user) { users.first }

      context 'without admin or auditor privileges' do
        it 'does not return response status and headers' do
          perform_request
          expect(current_user.admin? || current_user.auditor?).to be_falsey
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
