# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_push_rules custom role', feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_push_rules: true) }
  let_it_be(:member) { create(:group_member, :guest, member_role: role, user: user, group: group) }

  before do
    stub_licensed_features(custom_roles: true, push_rules: true, commit_committer_check: true,
      commit_committer_name_check: true, reject_unsigned_commits: true, reject_non_dco_commits: true)

    sign_in(user)
  end

  describe Groups::Settings::RepositoryController do
    describe '#show' do
      it 'returns repository settings page' do
        get group_settings_repository_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Pre-defined push rules')
      end
    end
  end

  describe Groups::PushRulesController do
    describe '#update' do
      subject(:group_push_rule_update) { patch group_push_rules_path(group, params: { push_rule: push_rule }) }

      let(:push_rule) do
        {
          deny_delete_tag: true, commit_message_regex: 'any',
          commit_message_negative_regex: 'any', branch_name_regex: 'any',
          author_email_regex: 'any', file_name_regex: 'any', max_file_size: 0, prevent_secrets: true,
          member_check: true, commit_committer_check: true, commit_committer_name_check: true,
          reject_non_dco_commits: true, reject_unsigned_commits: true
        }
      end

      it 'updates repository settings' do
        group_push_rule_update

        expect(group.reload.group_push_rule).to have_attributes({
          attributes: hash_including(push_rule.stringify_keys)
        })
      end
    end
  end
end
