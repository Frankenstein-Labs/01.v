# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::CustomAbility, feature_category: :permissions do
  describe '.allowed?', :request_store, :enable_admin_mode do
    using RSpec::Parameterized::TableSyntax

    subject(:custom_ability) { described_class }

    let_it_be_with_reload(:user) { create(:user) }

    context 'with admin abilities' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      admin_abilities = Gitlab::CustomRoles::Definition.admin

      admin_abilities.each_key do |ability|
        context "with #{ability}" do
          let_it_be(:role) { create(:member_role, ability) }
          let_it_be(:user_member_role) { create(:user_member_role, member_role: role, user: user) }

          it { is_expected.to be_allowed(user, ability) }
        end
      end
    end

    context 'with standard abilities' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: root_group) }
      let_it_be(:child_group) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:child_project) { create(:project, group: child_group) }

      standard_abilities = Gitlab::CustomRoles::Definition.standard

      where(:source, :ability, :resource, :expected) do
        standard_abilities.each do |(name, attrs)|
          ref(:root_group) | name | ref(:root_group) | attrs[:group_ability]
          ref(:root_group) | name | ref(:group) | attrs[:group_ability]
          ref(:root_group) | name | ref(:child_group) | attrs[:group_ability]
          ref(:root_group) | name | ref(:project) | attrs[:project_ability]
          ref(:root_group) | name | ref(:child_project) | attrs[:project_ability]

          ref(:group) | name | ref(:group) | attrs[:group_ability]
          ref(:group) | name | ref(:child_group) | attrs[:group_ability]
          ref(:group) | name | ref(:project) | attrs[:project_ability]
          ref(:group) | name | ref(:child_project) | attrs[:project_ability]

          ref(:child_group) | name | ref(:child_group) | attrs[:group_ability]
          ref(:child_group) | name | ref(:child_project) | attrs[:project_ability]

          ref(:project) | name | ref(:project) | attrs[:project_ability]

          ref(:child_project) | name | ref(:child_project) | attrs[:project_ability]
        end

        nil | nil | nil | false
      end

      with_them do
        let!(:role) { create(:member_role, :guest, ability, namespace: root_group) if ability }
        let!(:membership_type) { source.is_a?(Project) ? :project_member : :group_member }
        let!(:membership) { create(membership_type, :guest, member_role: role, user: user, source: source) if source }

        before do
          stub_licensed_features(custom_roles: true)
        end

        if params[:expected]
          it { is_expected.to be_allowed(user, ability, resource) }
        else
          it { is_expected.not_to be_allowed(user, ability, resource) }
        end
      end

      context 'with `custom_roles` enabled' do
        let_it_be(:ability) { :admin_runners }
        let_it_be(:role) { create(:member_role, :guest, ability, namespace: root_group) }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.not_to be_allowed(user, ability, root_group) }

        context 'with a membership on `group`' do
          let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

          it { is_expected.not_to be_allowed(user, ability, root_group) }
        end

        context 'with a membership on `child_group`' do
          let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: child_group) }

          it { is_expected.not_to be_allowed(user, ability, root_group) }
          it { is_expected.not_to be_allowed(user, ability, group) }
          it { is_expected.not_to be_allowed(user, ability, project) }
        end

        context 'with a membership on `project`' do
          let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, source: project) }

          it { is_expected.not_to be_allowed(user, ability, root_group) }
          it { is_expected.not_to be_allowed(user, ability, group) }
          it { is_expected.not_to be_allowed(user, ability, child_group) }
          it { is_expected.not_to be_allowed(user, ability, child_project) }
        end

        context 'with a membership on `child_project`' do
          let_it_be(:membership) do
            create(:project_member, :guest, member_role: role, user: user, source: child_project)
          end

          it { is_expected.not_to be_allowed(user, ability, root_group) }
          it { is_expected.not_to be_allowed(user, ability, group) }
          it { is_expected.not_to be_allowed(user, ability, child_group) }
          it { is_expected.not_to be_allowed(user, ability, project) }
        end

        context 'with a user assigned to an admin custom role' do
          let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

          it { is_expected.to be_allowed(user, :read_admin_users) }
        end

        context 'with a nil user' do
          it { is_expected.not_to be_allowed(nil, ability, root_group) }
        end

        context 'with an unknown ability' do
          let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: root_group) }

          it { is_expected.not_to be_allowed(user, :unknown, project) }
        end
      end

      context 'with `custom_roles` disabled' do
        let_it_be(:ability) { :admin_runners }
        let_it_be(:role) { create(:member_role, :guest, ability, namespace: root_group) }
        let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: root_group) }

        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.not_to be_allowed(user, ability, root_group) }

        context 'with a user assigned to an admin custom role' do
          let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

          it { is_expected.not_to be_allowed(user, :read_admin_users) }
        end
      end
    end
  end
end
