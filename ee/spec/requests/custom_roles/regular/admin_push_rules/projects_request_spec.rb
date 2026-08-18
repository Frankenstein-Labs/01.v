# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_push_rules custom role', feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_push_rules: true) }
  let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

  before do
    stub_licensed_features(custom_roles: true, push_rules: true, commit_committer_check: true,
      commit_committer_name_check: true, reject_unsigned_commits: true, reject_non_dco_commits: true)

    sign_in(user)
  end

  describe Projects::Settings::RepositoryController do
    describe '#show' do
      it 'returns repository settings page' do
        get project_settings_repository_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Push rules')
      end
    end

    describe '#create_deploy_token' do
      context 'when user does not have permission to create a deploy token' do
        let(:params) do
          { deploy_token: { name: 'name', expires_at: 1.day.from_now.to_datetime.to_s, read_repository: '1' } }
        end

        it 'returns 404' do
          expect do
            post create_deploy_token_project_settings_repository_path(project, params: params, format: :json)
          end.not_to change { project.deploy_tokens.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe Projects::PushRulesController do
    describe '#update' do
      let(:push_rule) do
        {
          deny_delete_tag: true, commit_message_regex: 'any',
          commit_message_negative_regex: 'any', branch_name_regex: 'any',
          author_email_regex: 'any',
          file_name_regex: 'any', max_file_size: 0, prevent_secrets: true,
          member_check: true, commit_committer_check: true, commit_committer_name_check: true,
          reject_non_dco_commits: true, reject_unsigned_commits: true
        }
      end

      it 'updates repository settings' do
        patch project_push_rule_path(project, 1, params: { push_rule: push_rule })

        expect(project.reload.push_rule).to have_attributes({
          attributes: hash_including(push_rule.stringify_keys)
        })
      end
    end
  end
end
