# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UserAccess, feature_category: :permissions do
  include ExternalAuthorizationServiceHelpers

  let_it_be_with_reload(:user) { create(:user) }

  subject(:access) { described_class.new(user, container: project) }

  describe '#can_push_to_branch?' do
    describe 'push to empty project' do
      let_it_be_with_reload(:project) { create(:project_empty_repo) }

      it 'returns false when the external service denies access' do
        project.add_maintainer(user)
        external_service_deny_access(user, project)

        expect(access.can_push_to_branch?('master')).to be_falsey
      end
    end
  end

  describe '#can_run_pipeline_on_branch?' do
    let_it_be_with_reload(:project) { create(:project, :small_repo, :in_group) }

    context 'when user is a security policy bot' do
      let_it_be(:user) { create(:user, :security_policy_bot) }

      before_all do
        project.add_guest(user)
      end

      it 'returns true when user has create_bot_pipeline permission' do
        expect(access.can_run_pipeline_on_branch?('master')).to be(true)
      end

      it 'does not change can_update_branch? behavior' do
        expect(access.can_update_branch?('master')).to be(false)
      end

      context 'on a branch with a protected-branch rule' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'protected') }

        it 'allows the security policy bot via :create_bot_pipeline' do
          expect(access.can_run_pipeline_on_branch?('protected')).to be(true)
        end
      end
    end

    context 'when user is a regular guest' do
      before_all do
        project.add_guest(user)
      end

      it 'returns false' do
        expect(access.can_run_pipeline_on_branch?('master')).to be(false)
      end

      context 'on a branch with a protected-branch rule' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'protected') }

        it 'denies a regular guest' do
          expect(access.can_run_pipeline_on_branch?('protected')).to be(false)
        end
      end
    end
  end

  describe '#can_delete_branch?' do
    context 'when a user has custom roles with `admin_protected_branch` assigned' do
      let_it_be_with_reload(:project) { create(:project, :small_repo, :in_group) }

      let_it_be(:role) { create(:member_role, :developer, :admin_protected_branch, namespace: project.group) }
      let_it_be(:project_member) do
        create(:project_member, :developer, member_role: role, user: user, project: project)
      end

      describe 'delete protected branch' do
        let_it_be_with_reload(:branch) { create(:protected_branch, project: project, name: "test") }

        context 'when custom roles is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'returns true' do
            expect(access.can_delete_branch?(branch.name)).to be(true)
          end
        end

        context 'when custom roles is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'returns false' do
            expect(access.can_delete_branch?(branch.name)).to be(false)
          end
        end
      end
    end
  end
end
