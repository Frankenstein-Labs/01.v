# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap::UsersWithoutAddedMembersFinder, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:invited_group) { create(:group) }
  let_it_be(:invited_group_with_same_user) { create(:group) }

  let_it_be(:user_with_multiple_members) { create(:user, developer_of: [group, project, invited_group]) }
  let_it_be(:user_for_group_and_project) { create(:user, developer_of: [group, project]) }
  let_it_be(:project_developer) { project.add_developer(create(:user)).user }
  let_it_be(:group_guest) { group.add_guest(create(:user)).user }
  let_it_be(:project_guest) { project.add_guest(create(:user)).user }

  let(:users_count) { 5 }
  let(:limit) { users_count + 1 }
  let(:added_member_ids) { [] }

  before_all do
    group.add_maintainer(create(:user, :project_bot))
    project.add_maintainer(create(:user, :project_bot))

    create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
    create(:group_group_link, { shared_with_group: invited_group_with_same_user, shared_group: group })
    create(:project_group_link, project: project, group: invited_group)
  end

  describe '#count' do
    subject(:count) { described_class.new(group, added_member_ids, limit).count }

    context 'when there are no member_ids added' do
      it 'shows unchanged count' do
        expect(count).to eq users_count
      end
    end

    context 'when member_ids includes a member with a user already taking a seat' do
      let!(:added_member_ids) { [invited_group_with_same_user.add_developer(user_with_multiple_members).id] }

      it 'shows unchanged count' do
        expect(count).to eq users_count
      end
    end

    context 'when member_ids includes mix of new and existing users' do
      let!(:added_member_ids) do
        [
          invited_group.add_developer(create(:user)).id,
          invited_group.add_developer(create(:user)).id,
          invited_group_with_same_user.add_developer(user_with_multiple_members).id
        ]
      end

      it 'shows unchanged count' do
        expect(count).to eq users_count
      end
    end
  end

  describe '.count' do
    it 'provides number of users' do
      expect(described_class.count(group, added_member_ids, limit)).to eq users_count
    end

    context 'with limit considerations that affect query invocation' do
      it 'only provides as many as the limit allows' do
        expect(described_class.count(group, added_member_ids, 1)).to eq 1
      end
    end
  end
end
