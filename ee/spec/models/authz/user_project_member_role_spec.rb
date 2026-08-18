# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRole, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:project).class_name('::Project') }
    it { is_expected.to belong_to(:shared_with_group).class_name('::Group').optional }
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validations' do
    subject(:user_project_member_role) { build(:user_project_member_role) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(%i[project_id shared_with_group_id]) }
  end

  describe '.for_user_shared_with_group' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    # target records
    let_it_be(:user_shared_with_group) { create(:user_project_member_role, user: user, shared_with_group: group) }
    let_it_be(:user_shared_with_group2) { create(:user_project_member_role, user: user, shared_with_group: group) }

    # non-target records
    let_it_be(:user_shared_with_other_group) { create(:user_project_member_role, user: user) }
    let_it_be(:other_user_shared_with_group) { create(:user_project_member_role, shared_with_group: group) }

    subject(:results) { described_class.for_user_shared_with_group(user, group) }

    it 'returns records only for the given user shared with the given group' do
      expect(results).to match_array([user_shared_with_group, user_shared_with_group2])
    end
  end

  describe '.in_project_shared_with_group' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    let_it_be(:targets) do
      create_list(:user_project_member_role, 2, project: project, shared_with_group: group)
    end

    subject(:results) { described_class.in_project_shared_with_group(project, group) }

    before do
      # non-target records
      create(:user_project_member_role, project: project)
      create(:user_project_member_role, shared_with_group: group)
    end

    it 'returns only records that match the given shared_project and shared_with_group' do
      expect(results).to match_array(targets)
    end
  end
end
