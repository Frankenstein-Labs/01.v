# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsPermission, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:principal_type) { 'User' }
  let(:principal_id) { user.id }

  subject(:permission) do
    described_class.new(
      resource: project,
      principal_type: principal_type,
      principal_id: principal_id,
      actions: %w[write read]
    )
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    provision_project_secrets_manager(secrets_manager, user)
  end

  def link_group_to_resource(resource, group, access_level)
    create(:project_group_link, project: resource, group: group, group_access: access_level)
  end

  it_behaves_like 'a secrets permission'

  describe 'project-specific validations' do
    context 'when there is no active secrets manager' do
      it 'is invalid' do
        deprovision_project_secrets_manager(secrets_manager, user)
        project.reload
        expect(permission).not_to be_valid
        expect(permission.errors[:base]).to include('Project secrets manager is not active.')
      end
    end

    describe 'User principal validation with parent group members' do
      context 'when user is a direct member of the project' do
        it 'is valid' do
          expect(permission).to be_valid
        end
      end

      context 'when user is not a direct member of the project but is a member of the parent group' do
        let(:parent_group) { create(:group) }
        let(:parent_group_user) { create(:user) }
        let(:principal_id) { parent_group_user.id }

        before do
          group.update!(parent: parent_group)
          parent_group.add_reporter(parent_group_user)
        end

        it 'is valid' do
          expect(permission).to be_valid
        end
      end

      context 'when user is a member of an ancestor group (multiple levels up)' do
        let(:root_group) { create(:group) }
        let(:intermediate_group) { create(:group, parent: root_group) }
        let(:ancestor_user) { create(:user) }
        let(:principal_id) { ancestor_user.id }

        before do
          group.update!(parent: intermediate_group)
          root_group.add_developer(ancestor_user)
        end

        it 'is valid' do
          expect(permission).to be_valid
        end
      end

      context 'when user is a member of parent group with Guest role' do
        let(:parent_group) { create(:group) }
        let(:guest_user) { create(:user) }
        let(:principal_id) { guest_user.id }

        before do
          group.update!(parent: parent_group)
          parent_group.add_guest(guest_user)
        end

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('user must have at least Reporter role')
        end
      end

      context 'when user is a member of parent group with Reporter role' do
        let(:parent_group) { create(:group) }
        let(:reporter_user) { create(:user) }
        let(:principal_id) { reporter_user.id }

        before do
          group.update!(parent: parent_group)
          parent_group.add_reporter(reporter_user)
        end

        it 'is valid' do
          expect(permission).to be_valid
        end
      end

      context 'when user is not a member of project or any parent group' do
        let(:unrelated_user) { create(:user) }
        let(:principal_id) { unrelated_user.id }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id].first).to include('user is not a member of the project')
        end
      end

      context 'when user is a member of a sibling group (not ancestor)' do
        let(:parent_group) { create(:group) }
        let(:sibling_group) { create(:group, parent: parent_group) }
        let(:sibling_user) { create(:user) }
        let(:principal_id) { sibling_user.id }

        before do
          group.update!(parent: parent_group)
          sibling_group.add_reporter(sibling_user)
        end

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id].first).to include('user is not a member of the project')
        end
      end
    end

    context 'when principal_type is Group' do
      let(:principal_type) { 'Group' }

      context 'when principal is the same group as project\'s group' do
        let(:principal_id) { group.id }

        it { is_expected.to be_valid }
      end

      context 'when principal is a parent group (ancestor of project\'s group)' do
        let(:parent_group) { create(:group) }
        let(:principal_id) { parent_group.id }

        before do
          group.update!(parent: parent_group)
        end

        it { is_expected.to be_valid }
      end

      context 'when principal is a child group (descendant of project\'s group)' do
        let!(:child_group) { create(:group, parent: group) }
        let(:principal_id) { child_group.id }

        it { is_expected.to be_valid }
      end
    end

    context 'when principal_type is MemberRole' do
      let(:principal_type) { 'MemberRole' }
      let(:principal_id) { member_role.id }

      context 'with a valid member role for the group' do
        let(:member_role) { create(:member_role, namespace: group) }

        it { is_expected.to be_valid }
      end

      context 'with an invalid member role for the group' do
        let(:another_group) { create(:group) }
        let(:member_role) { create(:member_role, namespace: another_group) }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Member Role does not have access to this project')
        end
      end

      context 'with non-existent member role' do
        let(:principal_id) { 999999 }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Member Role does not exist')
        end
      end
    end
  end
end
