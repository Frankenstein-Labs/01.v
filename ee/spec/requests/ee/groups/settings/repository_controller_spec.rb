# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::RepositoryController, feature_category: :source_code_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET show' do
    context 'without push rules feature' do
      before do
        stub_licensed_features(push_rules: false)
      end

      context 'when user is group owner' do
        before do
          group.add_owner(user)
        end

        it 'always allows access' do
          get group_settings_repository_path(group)
          expect(response).to have_gitlab_http_status(:ok)
          expect(assigns).to include(:protected_branches)
        end
      end

      context 'when user is not group owner' do
        before do
          group.add_maintainer(user)
        end

        it 'renders 404' do
          get group_settings_repository_path(group)
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with push rules feature' do
      before do
        stub_licensed_features(push_rules: true)
      end

      context 'when user is group maintainer' do
        before do
          group.add_maintainer(user)
        end

        it 'allows access' do
          get group_settings_repository_path(group)
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user is not group maintainer' do
        before do
          group.add_developer(user)
        end

        it 'renders 404' do
          get group_settings_repository_path(group)
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'protected branches' do
      let_it_be(:protected_branch) { create(:protected_branch, project_id: nil, namespace_id: group.id) }

      subject(:protected_branches) { assigns[:protected_branches] }

      before do
        group.add_owner(user)
      end

      it 'assigns group protected branches' do
        get group_settings_repository_path(group)

        expect(protected_branches).to contain_exactly(protected_branch)
      end

      it 'does not protect from deletion' do
        get group_settings_repository_path(group)

        expect(protected_branches.none?(&:protected_from_deletion)).to be(true)
      end

      context 'with blocking policy' do
        let(:service_klass) { Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService }

        before do
          allow(service_klass)
            .to receive(:new).with(group: group,
              current_user: user).and_return(instance_double(service_klass, execute: true))
        end

        it 'protects from deletion' do
          get group_settings_repository_path(group)

          expect(protected_branches.all?(&:protected_from_deletion)).to be(true)
        end
      end
    end
  end

  describe 'push rule variable definition' do
    before do
      stub_licensed_features(push_rules: true)
      group.add_maintainer(user)
    end

    context 'when group has an existing group push rule' do
      let!(:group_push_rule) { create(:group_push_rule, group: group) }

      it 'uses the existing group push rule via GroupPushRuleFinder' do
        get group_settings_repository_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(assigns[:push_rule]).to eq(group_push_rule)
      end
    end

    context 'when group does not have a group push rule' do
      it 'builds a new group push rule for the group' do
        get group_settings_repository_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(assigns[:push_rule]).to be_a(GroupPushRule)
        expect(assigns[:push_rule]).to be_new_record
        expect(assigns[:push_rule].group).to eq(group)
      end

      context 'when instance-level push rule exists' do
        let!(:global_push_rule) do
          create(:organization_push_rule,
            organization: group.organization,
            deny_delete_tag: true,
            member_check: true,
            prevent_secrets: true,
            commit_message_regex: 'Fixes \d+',
            max_file_size: 10
          )
        end

        it 'pre-fills the new group push rule with instance-level settings' do
          get group_settings_repository_path(group)

          push_rule = assigns[:push_rule]
          expect(push_rule).to be_a(GroupPushRule)
          expect(push_rule).to be_new_record
          expect(push_rule.deny_delete_tag).to be(true)
          expect(push_rule.member_check).to be(true)
          expect(push_rule.prevent_secrets).to be(true)
          expect(push_rule.commit_message_regex).to eq('Fixes \d+')
          expect(push_rule.max_file_size).to eq(10)
        end
      end
    end
  end
end
