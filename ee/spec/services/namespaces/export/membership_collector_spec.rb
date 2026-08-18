# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::MembershipCollector, feature_category: :system_access do
  include_context 'with group members shared context'

  let(:current_user) { users[0] }
  let(:requested_group) { group }

  subject(:prepare_data) { described_class.new(requested_group, current_user).execute }

  describe '#execute' do
    let(:member_klass) { Namespaces::Export::Member }
    let(:group_member) { member_klass.new(group: group, membership_type: 'direct', username: 'Anna') }

    def init_final_member(group, db_member)
      Namespaces::Export::Member.new(
        group: group, membership_type: 'direct', username: db_member.user.username
      )
    end

    def mock_root_group(members)
      finder = instance_double(GroupMembersFinder)
      members_relation = class_double(GroupMember)

      expect(GroupMembersFinder).to receive(:new).with(group, current_user).and_return(finder)
      expect(finder).to receive(:execute).with(include_relations: [:direct, :shared_from_groups,
        :inherited]).and_return(members_relation)

      expect(members_relation).to receive(:including_source).and_return(members_relation)
      expect(members_relation).to receive(:including_user).and_return(members)
    end

    def mock_group(group, members, _parent_groups)
      finder = instance_double(GroupMembersFinder)
      members_relation = class_double(GroupMember)

      expect(GroupMembersFinder).to receive(:new).with(group, current_user).and_return(finder)
      expect(finder).to receive(:execute).with(include_relations: [:direct, :shared_from_groups])
        .and_return(members_relation)

      expect(members_relation).to receive(:including_source).and_return(members_relation)
      expect(members_relation).to receive(:including_user).and_return(members)

      combinator = instance_double(Namespaces::Export::MembersTypeCombinator)

      expect(Namespaces::Export::MembersTypeCombinator).to receive(:new).with(group).and_return(combinator)
      expect(combinator).to receive(:execute).and_return(members)
    end

    def mock_project(project, members, _parent_groups)
      finder = instance_double(MembersFinder)
      members_relation = class_double(GroupMember)

      expect(MembersFinder).to receive(:new).with(project, current_user).and_return(finder)
      expect(finder).to receive(:execute).with(include_relations: [:direct])
        .and_return(members_relation)

      expect(members_relation).to receive(:including_source).and_return(members_relation)
      expect(members_relation).to receive(:including_user).and_return(members)

      combinator = instance_double(Namespaces::Export::MembersTypeCombinator)

      expect(Namespaces::Export::MembersTypeCombinator).to receive(:new).with(project).and_return(combinator)
      expect(combinator).to receive(:execute).and_return(members)
    end

    it 'returns correct data' do
      mock_root_group([group_owner_1])

      mock_project(group_project_1, [group_project_1_owner_5], [group.id])
      mock_project(group_project_2, [], [group.id])
      mock_group(sub_group_1, [sub_group_1_owner_2], [group.id])
      mock_project(sub_group_1_project, [sub_group_1_project_maintainer_4], [group.id, sub_group_1.id])
      mock_group(sub_sub_group_1, [sub_sub_group_owner_4], [group.id, sub_group_1.id])
      mock_group(sub_sub_sub_group_1, [shared_maintainer_5], [group.id, sub_group_1.id, sub_sub_group_1.id])
      mock_group(sub_group_2, [group_owner_1], [group.id])

      result = prepare_data

      expect(result.count).to eq(7)
      expect(result.map(&:id)).to eq([group_owner_1.id, sub_group_1_owner_2.id,
        group_owner_1.id, sub_sub_group_owner_4.id, shared_maintainer_5.id,
        group_project_1_owner_5.id, sub_group_1_project_maintainer_4.id])
    end

    it 'logs progress' do
      expect(Gitlab::AppLogger).to receive(:info).exactly(17).times

      prepare_data
    end
  end
end
