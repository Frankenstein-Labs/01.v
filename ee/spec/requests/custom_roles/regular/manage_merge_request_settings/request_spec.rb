# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_merge_request_settings custom role', feature_category: :code_review_workflow do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be_with_reload(:role) { create(:member_role, :guest, :manage_merge_request_settings, namespace: group) }
  let_it_be(:membership) { create(:group_member, :guest, user: user, source: group, member_role: role) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe 'group merge request settings' do
    before do
      stub_licensed_features(custom_roles: true, group_level_merge_checks_setting: true)
    end

    describe GroupsController do
      describe '#edit' do
        it 'user has access via a custom role' do
          get edit_group_path(group)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_text(_('Merge requests'))
        end
      end

      it 'cannot update the group', :aggregate_failures do
        expect do
          put group_path(group), params: { group: { name: 'new-name' } }

          expect(response).to have_gitlab_http_status(:not_found)
        end.to not_change { group.reload.name }
      end
    end

    describe Groups::Settings::MergeRequestsController do
      describe '#update' do
        it 'user has access via a custom role' do
          patch group_settings_merge_requests_path(group, namespace_setting: { allow_merge_on_skipped_pipeline: true })

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(edit_group_path(group, anchor: 'js-merge-requests-settings'))

          expect(group.reload.namespace_settings.allow_merge_on_skipped_pipeline).to be(true)
        end
      end
    end

    describe API::MergeRequestApprovalSettings do
      before do
        stub_licensed_features(custom_roles: true, merge_request_approvers: true)
      end

      let_it_be(:url) { "/groups/#{group.id}/merge_request_approval_setting" }

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
        end
      end

      describe 'PUT' do
        it 'user has access via a custom role' do
          put api(url, user), params: { allow_author_approval: true, allow_committer_approval: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')

          expect(group.group_merge_request_approval_setting.allow_author_approval).to be(true)
          expect(group.group_merge_request_approval_setting.allow_committer_approval).to be(true)
        end
      end
    end
  end

  describe 'project repository settings' do
    describe Projects::Settings::RepositoryController do
      describe '#show' do
        it 'user has access via a custom role' do
          get project_settings_repository_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when user does not have the custom role' do
          let_it_be(:plain_guest) { create(:user) }

          before_all do
            project.add_guest(plain_guest)
          end

          before do
            sign_in(plain_guest)
          end

          it 'user does not have access' do
            get project_settings_repository_path(project)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end

  describe 'project merge request settings' do
    describe Projects::Settings::MergeRequestsController do
      describe '#show' do
        it 'user has access via a custom role' do
          get project_settings_merge_requests_path(project)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_text(_('Merge requests'))
        end
      end

      describe '#update' do
        it 'user has access via a custom role' do
          patch project_settings_merge_requests_path(project, project: { allow_merge_on_skipped_pipeline: true })

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(project_settings_merge_requests_path(project))

          expect(project.reload.allow_merge_on_skipped_pipeline).to be(true)
        end
      end
    end

    describe Projects::TargetBranchRulesController do
      before do
        stub_licensed_features(custom_roles: true, target_branch_rules: true)
      end

      describe '#create' do
        it 'user has access via a custom role' do
          params = { projects_target_branch_rule: attributes_for(:target_branch_rule) }

          expect do
            post project_target_branch_rules_path(project), params: params
          end.to change { Projects::TargetBranchRule.count }.by(1)

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(project_settings_merge_requests_path(project, anchor: 'target-branch-rules'))
          expect(flash[:notice]).to eq('Branch target created.')
        end
      end

      describe '#destroy' do
        let_it_be(:rule) { create(:target_branch_rule, project: project) }

        it 'user has access via a custom role' do
          expect do
            delete project_target_branch_rule_path(project, rule)
          end.to change { Projects::TargetBranchRule.count }.by(-1)

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(project_settings_merge_requests_path(project, anchor: 'target-branch-rules'))
          expect(flash[:notice]).to eq('Branch target deleted.')
        end
      end
    end

    describe API::ProjectApprovalRules do
      let_it_be(:url) { "/projects/#{project.id}/approval_rules" }
      let_it_be(:approval_rule) { create(:approval_project_rule, project: project, approvals_required: 2) }

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['approvals_required']).to eq(approval_rule.approvals_required)
        end
      end

      describe 'POST' do
        it 'user has access via a custom role' do
          expect do
            post api(url, user), params: { name: 'new rule', approvals_required: 10 }
          end.to change { ApprovalProjectRule.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      describe 'PUT' do
        it 'user has access via a custom role' do
          put api("#{url}/#{approval_rule.id}", user), params: { approvals_required: 5 }

          expect(response).to have_gitlab_http_status(:ok)
          expect(approval_rule.reload.approvals_required).to eq(5)
        end
      end

      describe 'DELETE' do
        it 'user has access via a custom role' do
          expect do
            delete api("#{url}/#{approval_rule.id}", user)
          end.to change { ApprovalProjectRule.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    describe API::StatusChecks do
      let_it_be(:url) { "/projects/#{project.id}/external_status_checks" }
      let_it_be(:external_status_check) { create(:external_status_check, project: project) }

      before do
        stub_licensed_features(custom_roles: true, external_status_checks: true)
      end

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
        end
      end

      describe 'POST' do
        it 'user has access via a custom role' do
          expect do
            post api(url, user), params: attributes_for(:external_status_check)
          end.to change { MergeRequests::ExternalStatusCheck.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      describe 'PUT' do
        it 'user has access via a custom role' do
          put api("#{url}/#{external_status_check.id}", user), params: { name: 'new name' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(external_status_check.reload.name).to eq('new name')
        end
      end

      describe 'DELETE' do
        it 'user has access via a custom role' do
          expect do
            delete api("#{url}/#{external_status_check.id}", user)
          end.to change { MergeRequests::ExternalStatusCheck.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    describe API::MergeRequestApprovalSettings do
      before do
        stub_licensed_features(custom_roles: true, merge_request_approvers: true)
      end

      let_it_be(:url) { "/projects/#{project.id}/merge_request_approval_setting" }

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
        end
      end

      describe 'PUT' do
        it 'user has access via a custom role' do
          put api(url, user), params: { allow_author_approval: true, allow_committer_approval: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')

          project.reload

          expect(project.merge_requests_author_approval).to be(true)
          expect(project.merge_requests_disable_committers_approval).to be(false)
        end
      end
    end

    describe API::Branches do
      let_it_be(:url) { "/projects/#{project.id}/repository/branches" }

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/branches')
        end
      end
    end

    describe API::ProtectedBranches do
      let_it_be(:url) { "/projects/#{project.id}/protected_branches" }

      describe 'GET' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('protected_branches')
        end
      end
    end

    describe 'Querying CI/CD Settings' do
      let(:query) do
        %(
          query {
            project(fullPath: "#{project.full_path}") {
              ciCdSettings {
                mergePipelinesEnabled
                mergeTrainsEnabled
              }
            }
          }
        )
      end

      it 'returns the CI/CD settings' do
        result = GitlabSchema.execute(query, context: { current_user: user }).as_json
        settings = result.dig('data', 'project', 'ciCdSettings')
        expect(settings).to eq('mergePipelinesEnabled' => false, 'mergeTrainsEnabled' => false)
      end
    end
  end
end
