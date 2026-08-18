# frozen_string_literal: true

RSpec.shared_context 'group with enterprise users in group members' do
  let(:user_member) { create(:user) }
  let(:enterprise_user_member) { create(:enterprise_user, enterprise_group: group) }

  before do
    group.add_maintainer(user_member)
    group.add_maintainer(enterprise_user_member)
  end
end

RSpec.shared_context 'group with enterprise users from another group in group members' do
  let(:another_group) { create(:group) }
  let(:enterprise_user_member_from_another_group) { create(:enterprise_user, enterprise_group: another_group) }

  before do
    another_group.add_owner(owner)

    group.add_maintainer(enterprise_user_member_from_another_group)
  end
end

RSpec.shared_context 'subgroup with enterprise users in group members' do
  let(:subgroup) { create :group, parent: group }
  let(:user_member_in_subgroup) { create(:user) }
  let(:enterprise_user_member_in_subgroup) { create(:enterprise_user, enterprise_group: group) }

  before do
    subgroup.add_developer(user_member_in_subgroup)
    subgroup.add_developer(enterprise_user_member_in_subgroup)
  end
end

RSpec.shared_context 'project with enterprise users in project members' do
  let(:user_member) { create(:user) }
  let(:enterprise_user_member) { create(:enterprise_user, enterprise_group: group) }

  before do
    project.add_maintainer(user_member)
    project.add_maintainer(enterprise_user_member)
  end
end

RSpec.shared_context 'project with enterprise users from another group in project members' do
  let(:another_group) { create(:group) }
  let(:enterprise_user_member_from_another_group) { create(:enterprise_user, enterprise_group: another_group) }

  before do
    another_group.add_owner(owner)

    project.add_maintainer(enterprise_user_member_from_another_group)
  end
end
