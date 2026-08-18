# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Group, feature_category: :permissions do
  subject(:group_authorization) { described_class.new(user, scope: scope) }

  let(:scope) { ::Group.all }

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:child_group) { create(:group, parent: group) }
  let_it_be(:other_groups) { create_list(:group, 3) }

  let_it_be(:admin_runners_role) do
    create(:member_role, :guest, :read_runners, :admin_runners, namespace: root_group)
  end

  let_it_be(:admin_vulnerability_role) do
    create(:member_role, :guest, :admin_vulnerability, namespace: root_group)
  end

  let_it_be(:read_dependency_role) do
    create(:member_role, :guest, :read_dependency, namespace: root_group)
  end

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { group_authorization.permitted }

    context 'when authorized for different permissions at different levels in the group hierarchy' do
      let_it_be(:memberships) do
        [
          [admin_runners_role, root_group],
          [admin_vulnerability_role, group],
          [read_dependency_role, child_group]
        ]
      end

      before_all do
        memberships.each do |(role, group)|
          create(:group_member, :guest, member_role: role, user: user, source: group)
        end
      end

      it 'includes other groups that the current user is not permitted to' do
        other_groups.each do |other_group|
          is_expected.to include(other_group.id => match_array([]))
        end
      end

      it { is_expected.to include(root_group.id => match_array([:read_runners, :admin_runners])) }

      it 'includes groups in the middle of the hierarchy' do
        is_expected.to include(group.id => match_array([
          :read_runners,
          :admin_runners,
          :admin_vulnerability,
          :read_vulnerability
        ]))
      end

      it 'includes groups at the bottom of the hierarchy' do
        is_expected.to include(child_group.id => match_array([
          :read_runners,
          :admin_runners,
          :admin_vulnerability,
          :read_dependency,
          :read_vulnerability
        ]))
      end
    end
  end
end
