# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRole, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group).class_name('::Group') }
    it { is_expected.to belong_to(:shared_with_group).class_name('::Group') }
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validations' do
    subject(:user_group_member_role) { build(:user_group_member_role) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(%i[group_id shared_with_group_id]) }
  end

  describe 'uniqueness constraints' do
    let_it_be(:role) { create(:member_role) }

    it 'is unique by user_id and group_id when shared_with_group_id is nil' do
      existing = create(:user_group_member_role)
      unique_attrs = %w[user_id group_id]

      attrs = existing.attributes.slice(*unique_attrs)
      attrs["member_role_id"] = role.id

      expect { described_class.upsert(attrs, unique_by: unique_attrs) }.not_to change { described_class.count }
      expect(existing.reload.member_role_id).to eq role.id
    end

    it 'is unique by user_id, group_id and shared_with_group_id' do
      unique_attrs = %w[user_id group_id shared_with_group_id]
      existing = create(:user_group_member_role, shared_with_group: create(:group))

      attrs = existing.attributes.slice(*unique_attrs)
      attrs["member_role_id"] = role.id

      expect { described_class.upsert(attrs, unique_by: unique_attrs) }.not_to change { described_class.count }
      expect(existing.reload.member_role_id).to eq role.id
    end
  end

  describe '.for_user_in_group_and_shared_groups' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:other_group) { create(:group) }

    # target records
    let_it_be(:user_in_group) { create_record(user, group: group) }
    let_it_be(:user_in_shared_group) { create_record(user, shared_with_group: group) }

    # non-target records
    let_it_be(:user_in_group_shared_with_other_group) do
      create_record(user, group: group, shared_with_group: other_group)
    end

    let_it_be(:user_in_other_group) { create_record(user, group: other_group) }
    let_it_be(:user_in_other_shared_group) { create_record(user, shared_with_group: other_group) }
    let_it_be(:other_user_in_group) { create_record(other_user, group: group) }

    subject(:results) { described_class.for_user_in_group_and_shared_groups(user, group) }

    def create_record(user, group: nil, shared_with_group: nil)
      attrs = { user: user }
      attrs[:group] = group if group
      attrs[:shared_with_group] = shared_with_group if shared_with_group
      create(:user_group_member_role, attrs)
    end

    it 'returns records only for the given user and group' do
      expect(results).to match_array([user_in_group, user_in_shared_group])
    end
  end

  describe '.in_shared_group' do
    let_it_be(:user) { create(:user) }
    let_it_be(:user2) { create(:user) }

    let_it_be(:shared_group) { create(:group) }
    let_it_be(:shared_with_group) { create(:group) }

    let_it_be(:other_shared_group) { create(:group) }
    let_it_be(:other_shared_with_group) { create(:group) }

    # target records
    let_it_be(:user_in_shared_group) do
      create(:user_group_member_role, user: user, group: shared_group, shared_with_group: shared_with_group)
    end

    let_it_be(:user2_in_shared_group) do
      create(:user_group_member_role, user: user2, group: shared_group, shared_with_group: shared_with_group)
    end

    # non-target records
    let_it_be(:user_in_other_shared_group) do
      create(:user_group_member_role, user: user, group: other_shared_group, shared_with_group: shared_with_group)
    end

    let_it_be(:user2_in_shared_group2) do
      create(:user_group_member_role, user: user2, group: shared_group, shared_with_group: other_shared_with_group)
    end

    subject(:results) { described_class.in_shared_group(shared_group, shared_with_group) }

    it 'returns only records that match the given shared_group and shared_with_group' do
      expect(results).to match_array([user_in_shared_group, user2_in_shared_group])
    end
  end

  describe '.with_attrs' do
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:group3) { create(:group) }

    let_it_be(:target1) { create(:user_group_member_role, group: group1, shared_with_group: group2) }
    let_it_be(:target2) { create(:user_group_member_role, group: group1, shared_with_group: group3) }
    let_it_be(:non_target) { create(:user_group_member_role, group: group2, shared_with_group: group3) }

    subject(:results) do
      attrs = [:group_id, :shared_with_group_id]
      values = [[group1.id, group2.id], [group1.id, group3.id]]
      described_class.with_attrs(attrs, values)
    end

    it 'returns only records with attrs matching the given attr values' do
      expect(results).to match_array([target1, target2])
    end
  end
end
