# frozen_string_literal: true

require 'spec_helper'

# Creation is necessary due to relations and the need to check in the presenter
#
# rubocop:disable RSpec/FactoryBot/AvoidCreate
RSpec.describe MemberPresenter, feature_category: :groups_and_projects do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be_with_reload(:member_root) { create(:group_member, :reporter, group: root_group, user: user) }
  let_it_be_with_reload(:member_subgroup) { create(:group_member, :reporter, group: subgroup, user: user) }
  let(:permissions) { [{ name: 'View repository code', description: match(/.+/) }] }
  let_it_be(:admin_permissions, freeze: false) do
    [{ name: 'Read-only access to admin dashboard', description: match(/.+/) }]
  end

  let(:current_user) { user }

  subject(:presenter) { described_class.new(member_root, current_user: current_user) }

  describe '#human_access' do
    context 'when user has static role' do
      it 'returns human name for access level' do
        access_levels = {
          "Guest" => Gitlab::Access::GUEST,
          "Reporter" => Gitlab::Access::REPORTER,
          "Developer" => Gitlab::Access::DEVELOPER,
          "Maintainer" => Gitlab::Access::MAINTAINER,
          "Owner" => Gitlab::Access::OWNER
        }

        access_levels.each do |human_name, access_level|
          member_root.access_level = access_level
          expect(presenter.human_access).to eq human_name
        end
      end

      context 'when user has a custom role' do
        it 'returns custom roles' do
          member_role = create(:member_role, :guest, name: 'Custom', namespace: root_group)
          member_root.member_role = member_role
          member_root.access_level = Gitlab::Access::GUEST

          expect(presenter.human_access).to eq('Custom')
        end
      end
    end
  end

  describe '#member_role_description' do
    context 'when user has static role' do
      it 'returns member role description for the access level' do
        Gitlab::Access.option_descriptions.each do |access_level, description|
          member_root.access_level = access_level

          expect(presenter.member_role_description).to eq(description)
        end
      end
    end

    context 'when user has a custom role' do
      let(:description) { 'Custom description' }

      it 'returns custom role description' do
        member_role = create(:member_role, :guest, namespace: root_group, description: description)
        member_root.member_role = member_role

        expect(presenter.member_role_description).to eq(description)
      end
    end
  end

  describe '#access_level_for_export' do
    context 'when a member has static role assigned' do
      it 'returns correct label for default role' do
        expect(presenter.access_level_for_export).to eq('Reporter')
      end
    end

    context 'when a member has custom role assigned' do
      it 'returns correct label for custom role' do
        member_role = create(:member_role, :reporter, name: 'Incident Manager')
        member_root.update!(member_role: member_role)

        expect(presenter.access_level_for_export).to eq('Incident Manager (Custom role)')
      end
    end
  end

  describe '#role_type' do
    context 'when a default role is assigned' do
      it "returns 'default'" do
        expect(presenter.role_type).to eq('default')
      end
    end

    context 'when a custom role is assigned' do
      it "returns 'custom'" do
        member_root.member_role = create(:member_role, namespace: root_group)

        expect(presenter.role_type).to eq('custom')
      end
    end
  end

  describe '#valid_member_roles' do
    let_it_be(:member_role_guest) { create(:member_role, :guest, name: 'guest plus', namespace: root_group) }
    let_it_be(:member_role_reporter) do
      create(:member_role, :reporter, name: 'reporter plus', namespace: root_group, description: 'My custom role')
    end

    let_it_be(:member_role_guest_instance) do
      create(:member_role, :guest, :instance, name: 'guest plus (instance-level)')
    end

    let_it_be(:member_role_reporter_instance) do
      create(:member_role, :reporter, :instance, name: 'reporter plus (instance-level)')
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_licensed_features(custom_roles: true)
    end

    shared_examples 'returning all non-admin custom roles' do
      it 'returns all roles for the root group' do
        expect(presenter.valid_member_roles).to match_array(
          [
            {
              base_access_level: Gitlab::Access::REPORTER,
              member_role_id: member_role_reporter.id,
              name: 'reporter plus',
              description: 'My custom role',
              occupies_seat: true,
              permissions: permissions
            },
            {
              base_access_level: Gitlab::Access::GUEST,
              member_role_id: member_role_guest.id,
              name: 'guest plus',
              description: nil,
              occupies_seat: false,
              permissions: permissions
            }
          ]
        )
      end

      it 'returns only roles with higher base_access_level than user highest membership in the hierarchy' do
        expect(described_class.new(member_subgroup, current_user: user).valid_member_roles).to match_array(
          [
            {
              base_access_level: Gitlab::Access::REPORTER,
              member_role_id: member_role_reporter.id,
              name: 'reporter plus',
              description: 'My custom role',
              occupies_seat: true,
              permissions: permissions
            }
          ]
        )
      end
    end

    context 'when the user is a member of root group' do
      before_all do
        root_group.add_guest(user)
      end

      it_behaves_like 'returning all non-admin custom roles'
    end

    context 'when the user is a member of subgroup group' do
      before_all do
        subgroup.add_guest(user)
      end

      it_behaves_like 'returning all non-admin custom roles'
    end

    context 'when on self-managed', :enable_admin_mode do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when getting the roles for a registered user' do
        let(:current_user) { admin }

        it 'returns instance-level roles' do
          expect(presenter.valid_member_roles).to match_array(
            [
              {
                base_access_level: Gitlab::Access::GUEST,
                member_role_id: member_role_guest_instance.id,
                name: 'guest plus (instance-level)',
                description: nil,
                occupies_seat: false,
                permissions: permissions
              },
              {
                base_access_level: Gitlab::Access::REPORTER,
                member_role_id: member_role_reporter_instance.id,
                name: 'reporter plus (instance-level)',
                description: nil,
                occupies_seat: true,
                permissions: permissions
              }
            ]
          )
        end
      end

      context 'when getting the roles for a anonymous user' do
        let(:current_user) { nil }

        it 'does not return any custom roles' do
          expect(presenter.valid_member_roles).to be_empty
        end
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
